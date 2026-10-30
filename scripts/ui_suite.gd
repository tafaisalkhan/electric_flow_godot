class_name GameUISuite
extends Control

signal play_requested
signal daily_challenge_requested
signal daily_reward_requested
signal rewarded_coins_requested
signal setting_changed(id: String, enabled: bool)
signal settings_action_requested(id: String)
signal shop_action_requested(id: String)
signal purchase_requested(id: String)
signal mission_claim_requested(id: String)
signal leaderboard_signin_requested
signal leaderboard_full_requested
signal privacy_requested

@export var game_title := "YOUR GAME"
@export var tagline := "PLAY YOUR WAY"
@export var score_title := "BEST SCORE"
@export var score_unit := ""
@export_group("Screen scenes")
@export var home_ui_scene: PackedScene
@export var settings_ui_scene: PackedScene
@export var shop_ui_scene: PackedScene
@export var store_ui_scene: PackedScene
@export var missions_ui_scene: PackedScene
@export var leaderboard_ui_scene: PackedScene
@export var reward_ui_scene: PackedScene

var _data: Dictionary = {
	"settings_options": [
		{"id": "sound", "label": "Sound Effects", "enabled": true},
		{"id": "vibration", "label": "Vibration", "enabled": true}
	]
}
var _home: Control
var _panel: Control
var _active_screen := ""
var _background_tint := Color.WHITE

func _ready() -> void:
	_show_home()

func update_data(data: Dictionary) -> void:
	_data.merge(data, true)
	if is_instance_valid(_home):
		_home.set_data(_data, game_title, tagline, score_title, score_unit)
	if is_instance_valid(_panel) and _active_screen != "reward":
		_panel.set_data(_data)

func set_background_tint(tint: Color) -> void:
	_background_tint = tint
	if is_instance_valid(_home):
		_home.set_background_tint(tint)

func show_message(message: String) -> void:
	if is_instance_valid(_home):
		_home.show_message(message)

func open_screen(screen: String) -> void:
	var scene := _scene_for(screen)
	if scene == null:
		return
	_close_panel()
	_active_screen = screen
	_panel = scene.instantiate()
	add_child(_panel)
	_panel.set_data(_data)
	_panel.connect("close_requested", Callable(self, "_close_panel"))
	_panel.connect("setting_changed", Callable(self, "_on_setting_changed"))
	_panel.connect("settings_action_requested", Callable(self, "_relay_settings_action"))
	_panel.connect("shop_action_requested", Callable(self, "_relay_shop_action"))
	_panel.connect("purchase_requested", Callable(self, "_relay_purchase"))
	_panel.connect("mission_claim_requested", Callable(self, "_relay_mission_claim"))
	_panel.connect("leaderboard_signin_requested", Callable(self, "_relay_leaderboard_signin"))
	_panel.connect("leaderboard_full_requested", Callable(self, "_relay_leaderboard_full"))
	_panel.connect("privacy_requested", Callable(self, "_relay_privacy"))

func show_reward(title: String, coins: int, detail := "", stars: int = 0) -> void:
	var scene := _scene_for("reward")
	if scene == null:
		return
	_close_panel()
	_active_screen = "reward"
	_panel = scene.instantiate()
	add_child(_panel)
	_panel.set_data(title, coins, detail, stars)
	_panel.connect("collect_requested", Callable(self, "_close_panel"))

func _show_home() -> void:
	if is_instance_valid(_home):
		_home.queue_free()
	var scene := _scene_for("home")
	if scene == null:
		push_error("UI suite home scene is not assigned.")
		return
	_home = scene.instantiate()
	add_child(_home)
	move_child(_home, 0)
	_home.set_data(_data, game_title, tagline, score_title, score_unit)
	_home.set_background_tint(_background_tint)
	_home.connect("screen_requested", Callable(self, "open_screen"))
	_home.connect("play_requested", Callable(self, "_relay_play"))
	_home.connect("daily_challenge_requested", Callable(self, "_relay_daily_challenge"))
	_home.connect("daily_reward_requested", Callable(self, "_relay_daily_reward"))
	_home.connect("rewarded_coins_requested", Callable(self, "_relay_rewarded_coins"))

func _scene_for(screen: String) -> PackedScene:
	match screen:
		"home": return home_ui_scene
		"settings": return settings_ui_scene
		"shop": return shop_ui_scene
		"store": return store_ui_scene
		"missions": return missions_ui_scene
		"leaderboard": return leaderboard_ui_scene
		"reward": return reward_ui_scene
	return null

func _close_panel() -> void:
	if is_instance_valid(_panel):
		_panel.queue_free()
	_panel = null
	_active_screen = ""

func _on_setting_changed(id: String, enabled: bool) -> void:
	var options: Array = _data.get("settings_options", [])
	for option in options:
		if str(option.get("id", "")) == id:
			option["enabled"] = enabled
	setting_changed.emit(id, enabled)

func _relay_play() -> void:
	play_requested.emit()

func _relay_daily_challenge() -> void:
	daily_challenge_requested.emit()

func _relay_daily_reward() -> void:
	daily_reward_requested.emit()

func _relay_rewarded_coins() -> void:
	rewarded_coins_requested.emit()

func _relay_settings_action(id: String) -> void:
	settings_action_requested.emit(id)

func _relay_shop_action(id: String) -> void:
	shop_action_requested.emit(id)

func _relay_purchase(id: String) -> void:
	purchase_requested.emit(id)

func _relay_mission_claim(id: String) -> void:
	mission_claim_requested.emit(id)

func _relay_leaderboard_signin() -> void:
	leaderboard_signin_requested.emit()

func _relay_leaderboard_full() -> void:
	leaderboard_full_requested.emit()

func _relay_privacy() -> void:
	privacy_requested.emit()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and _active_screen != "":
		_close_panel()
