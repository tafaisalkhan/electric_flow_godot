# play_games_manager.gd
# Google Play Games Services & Cloud Save Manager for Electric Flow
extends Node

signal sign_in_status_changed(signed_in: bool)
signal sign_in_succeeded(user_id: String, display_name: String)
signal sign_in_failed(error_message: String)
signal cloud_save_succeeded
signal cloud_save_failed(error_message: String)
signal cloud_load_completed(success: bool, conflict_resolved: bool)

const SNAPSHOT_NAME := "electric_flow_cloud_save"
const SNAPSHOT_DESCRIPTION := "Electric Flow Cloud Progress & Coins"

var _pgs: Object = null
var is_available: bool = false
var is_signed_in: bool = false
var player_id: String = ""
var player_name: String = "Player"
var is_syncing: bool = false
var auto_sync_enabled: bool = true

func _ready() -> void:
	_init_plugin()
	if is_available:
		# Attempt silent sign-in on launch
		silent_sign_in()
	else:
		# In desktop/editor or non-Android environment, initialize ready state
		print("[PlayGamesManager] Running in standalone/editor mode. Cloud Save mock enabled.")

func _init_plugin() -> void:
	if Engine.has_singleton("GodotPlayGamesServices"):
		_pgs = Engine.get_singleton("GodotPlayGamesServices")
	elif Engine.has_singleton("PlayGamesServices"):
		_pgs = Engine.get_singleton("PlayGamesServices")
		
	if _pgs != null:
		is_available = true
		_connect_signals()
		print("[PlayGamesManager] Native Google Play Games Services plugin found.")
	else:
		is_available = false

func _connect_signals() -> void:
	if _pgs == null:
		return
	# Bind standard Google Play Games signals
	if _pgs.has_signal("sign_in_successful"):
		_pgs.connect("sign_in_successful", Callable(self, "_on_native_sign_in_success"))
	if _pgs.has_signal("sign_in_failed"):
		_pgs.connect("sign_in_failed", Callable(self, "_on_native_sign_in_failed"))
	if _pgs.has_signal("snapshot_saved"):
		_pgs.connect("snapshot_saved", Callable(self, "_on_native_snapshot_saved"))
	if _pgs.has_signal("snapshot_loaded"):
		_pgs.connect("snapshot_loaded", Callable(self, "_on_native_snapshot_loaded"))
	if _pgs.has_signal("snapshot_conflict"):
		_pgs.connect("snapshot_conflict", Callable(self, "_on_native_snapshot_conflict"))

# -------------------------------------------------------------
# SIGN IN & PROFILE
# -------------------------------------------------------------
func silent_sign_in() -> void:
	if not is_available:
		return
	if _pgs.has_method("silent_sign_in"):
		_pgs.silent_sign_in()
	elif _pgs.has_method("sign_in"):
		_pgs.sign_in()

func sign_in() -> void:
	if not is_available:
		# Emulate sign in for testing
		is_signed_in = true
		player_name = "Player (Offline/Local)"
		sign_in_status_changed.emit(true)
		sign_in_succeeded.emit("local_user", player_name)
		load_from_cloud()
		return
		
	if _pgs.has_method("sign_in"):
		_pgs.sign_in()
	elif _pgs.has_method("show_sign_in"):
		_pgs.show_sign_in()

func sign_out() -> void:
	is_signed_in = false
	player_id = ""
	player_name = ""
	if is_available and _pgs.has_method("sign_out"):
		_pgs.sign_out()
	sign_in_status_changed.emit(false)

func _on_native_sign_in_success(account_id: String, display_name: String = "") -> void:
	is_signed_in = true
	player_id = account_id
	player_name = display_name if display_name != "" else "Player"
	print("[PlayGamesManager] Signed in as: ", player_name, " (", player_id, ")")
	sign_in_status_changed.emit(true)
	sign_in_succeeded.emit(player_id, player_name)
	
	# Automatically retrieve Cloud Save when signed in
	load_from_cloud()

func _on_native_sign_in_failed(error_code: int = 0) -> void:
	is_signed_in = false
	print("[PlayGamesManager] Sign-in failed with code: ", error_code)
	sign_in_status_changed.emit(false)
	sign_in_failed.emit("Sign in failed (code: %d)" % error_code)

# -------------------------------------------------------------
# CLOUD SAVE & RESTORE (SAVED GAMES)
# -------------------------------------------------------------
func save_to_cloud() -> void:
	if not auto_sync_enabled:
		return
	if is_syncing:
		return
		
	var save_data: Dictionary = GameState.to_cloud_dict()
	var json_str := JSON.stringify(save_data)
	var byte_data := json_str.to_utf8_buffer()
	
	if not is_available:
		# Save simulated cloud backup locally in user://
		var sim_file := FileAccess.open("user://cloud_save_simulation.json", FileAccess.WRITE)
		if sim_file:
			sim_file.store_string(json_str)
			sim_file.close()
		cloud_save_succeeded.emit()
		return
		
	if not is_signed_in:
		return
		
	is_syncing = true
	if _pgs.has_method("save_snapshot"):
		_pgs.save_snapshot(SNAPSHOT_NAME, byte_data, SNAPSHOT_DESCRIPTION)
	elif _pgs.has_method("saveSnapshot"):
		_pgs.saveSnapshot(SNAPSHOT_NAME, byte_data, SNAPSHOT_DESCRIPTION)

func load_from_cloud() -> void:
	if is_syncing:
		return
	is_syncing = true
	
	if not is_available:
		# Check simulated cloud file
		if FileAccess.file_exists("user://cloud_save_simulation.json"):
			var file := FileAccess.open("user://cloud_save_simulation.json", FileAccess.READ)
			if file:
				var content := file.get_as_text()
				file.close()
				var json := JSON.new()
				if json.parse(content) == OK and json.data is Dictionary:
					var merged: bool = GameState.merge_from_cloud_dict(json.data)
					is_syncing = false
					cloud_load_completed.emit(true, merged)
					return
		is_syncing = false
		cloud_load_completed.emit(true, false)
		return
		
	if not is_signed_in:
		is_syncing = false
		cloud_load_completed.emit(false, false)
		return
		
	if _pgs.has_method("load_snapshot"):
		_pgs.load_snapshot(SNAPSHOT_NAME)
	elif _pgs.has_method("loadSnapshot"):
		_pgs.loadSnapshot(SNAPSHOT_NAME)

func _on_native_snapshot_saved(_success: bool) -> void:
	is_syncing = false
	print("[PlayGamesManager] Cloud Save snapshot uploaded successfully.")
	cloud_save_succeeded.emit()

func _on_native_snapshot_loaded(snapshot_bytes: PackedByteArray) -> void:
	is_syncing = false
	if snapshot_bytes.is_empty():
		print("[PlayGamesManager] Snapshot empty. Performing initial cloud backup.")
		save_to_cloud()
		cloud_load_completed.emit(true, false)
		return
		
	var json_str := snapshot_bytes.get_string_from_utf8()
	var json := JSON.new()
	var err := json.parse(json_str)
	if err == OK and json.data is Dictionary:
		var merged: bool = GameState.merge_from_cloud_dict(json.data)
		print("[PlayGamesManager] Cloud save merged. Merged changes: ", merged)
		cloud_load_completed.emit(true, merged)
		if merged:
			# Push merged resolution back to cloud
			save_to_cloud()
	else:
		print("[PlayGamesManager] Could not parse cloud snapshot json.")
		cloud_load_completed.emit(false, false)

func _on_native_snapshot_conflict(server_data: PackedByteArray, _metadata: Dictionary = {}) -> void:
	# Intelligent automated merge on conflict
	_on_native_snapshot_loaded(server_data)

# -------------------------------------------------------------
# LEADERBOARDS & ACHIEVEMENTS
# -------------------------------------------------------------
func submit_score(leaderboard_id: String, score: int) -> void:
	if not is_available or not is_signed_in or leaderboard_id.is_empty():
		return
	if _pgs.has_method("submit_score"):
		_pgs.submit_score(leaderboard_id, score)

func show_leaderboard(leaderboard_id: String) -> void:
	if not is_available or not is_signed_in:
		return
	if _pgs.has_method("show_leaderboard"):
		_pgs.show_leaderboard(leaderboard_id)

func show_all_leaderboards() -> void:
	if not is_available or not is_signed_in:
		return
	if _pgs.has_method("show_all_leaderboards"):
		_pgs.show_all_leaderboards()

func unlock_achievement(achievement_id: String) -> void:
	if not is_available or not is_signed_in or achievement_id.is_empty():
		return
	if _pgs.has_method("unlock_achievement"):
		_pgs.unlock_achievement(achievement_id)

func show_achievements() -> void:
	if not is_available or not is_signed_in:
		return
	if _pgs.has_method("show_achievements"):
		_pgs.show_achievements()
