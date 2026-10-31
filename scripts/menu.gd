extends Control

const UISuiteScene = preload("res://scenes/ui_suite.tscn")
const Palette = preload("res://scripts/ui_palette.gd")
const PrivacyDialogScene = preload("res://scenes/privacy_dialog.tscn")

var ui: GameUISuite
var _reward_callback: Callable
var _unavailable_callback: Callable
var _ad_pending := false

func _ready() -> void:
	AdManager.hide_banner_top()
	AdManager.show_banner_bottom()
	ui = UISuiteScene.instantiate()
	ui.game_title = "ELECTRIC FLOW"
	ui.tagline = "CONNECT THE CIRCUITS"
	ui.score_title = "LEVELS UNLOCKED"
	add_child(ui)
	ui.play_requested.connect(_play)
	ui.daily_challenge_requested.connect(_daily_challenge)
	ui.daily_reward_requested.connect(_daily_reward)
	ui.rewarded_coins_requested.connect(_watch_reward_ad)
	ui.setting_changed.connect(_setting_changed)
	ui.settings_action_requested.connect(_settings_action)
	ui.shop_action_requested.connect(_shop_action)
	ui.purchase_requested.connect(_purchase_requested)
	ui.mission_claim_requested.connect(_claim_mission)
	ui.leaderboard_signin_requested.connect(_leaderboard_signin)
	ui.leaderboard_full_requested.connect(_on_leaderboard_full)
	ui.privacy_requested.connect(_open_privacy)
	PlayGamesManager.sign_in_status_changed.connect(func(_signed_in: bool): _refresh_ui())
	PlayGamesManager.cloud_load_completed.connect(func(_ok: bool, _merged: bool): _refresh_ui())
	_refresh_ui()
	if not GameState.privacy_accepted or GameState.show_privacy_on_start:
		_open_privacy()

func _open_privacy() -> void:
	var privacy := PrivacyDialogScene.instantiate()
	add_child(privacy)

func _refresh_ui() -> void:
	ui.set_background_tint(Palette.color_for(GameState.selected_theme))
	var themed_items: Array = []
	for theme_data in Palette.THEMES:
		var theme_id := str(theme_data["id"])
		themed_items.append({
			"id": theme_id,
			"name": theme_id,
			"category": "Themes",
			"icon": "◆",
			"color": theme_data["color"],
			"cost": theme_data["price"],
			"owned": GameState.owned_themes.has(theme_id),
			"equipped": GameState.selected_theme == theme_id
		})
	var mission_data: Array = []
	for definition in [
		{"id": "play_one", "name": "Complete 1 level", "target": 1, "reward": 15},
		{"id": "earn_three_stars", "name": "Earn 3 stars", "target": 3, "reward": 20},
		{"id": "play_three", "name": "Complete 3 levels", "target": 3, "reward": 25}
	]:
		var progress := GameState.daily_mission_progress(str(definition["id"]))
		mission_data.append({
			"id": definition["id"],
			"name": definition["name"],
			"target": definition["target"],
			"reward": definition["reward"],
			"progress": progress,
			"complete": progress >= int(definition["target"]),
			"claimed": GameState.claimed_missions.has(str(definition["id"]))
		})
	ui.update_data({
		"coins": GameState.coins,
		"stars": GameState.total_stars,
		"best_score": maxi(0, GameState.highest_level - 1),
		"daily_reward_available": GameState.can_claim_daily_reward(),
		"daily_reward_amount": 10,
		"show_daily_challenge": true,
		"rewarded_label": "▶  Watch Ad · Get 100 Coins",
		"settings_options": [
			{"id": "music", "label": "Music", "enabled": GameState.music_enabled},
			{"id": "sound", "label": "Sound Effects", "enabled": GameState.sfx_enabled}
		],
		"settings_actions": [{"id": "advanced", "label": "Difficulty & More Options"}],
		"shop_items": themed_items,
		"store_products": [
			{"id": "coins_500", "name": "Pouch of Coins", "description": "500 coins", "price": "Price in Google Play"},
			{"id": "coins_1200", "name": "Starter Bundle", "description": "1,200 coins", "price": "Price in Google Play"},
			{"id": "coins_3000", "name": "Bag of Coins", "description": "3,000 coins", "price": "Price in Google Play"}
		],
		"missions": mission_data,
		"leaderboard_signed_in": PlayGamesManager.is_signed_in,
		"leaderboard_user": {
			"rank": 1,
			"name": PlayGamesManager.player_name,
			"score": "%d Levels" % GameState.highest_level,
			"reward": "⭐ %d" % GameState.total_stars
		} if PlayGamesManager.is_signed_in else {},
		"leaderboard_rows": [
			{"name": PlayGamesManager.player_name if PlayGamesManager.is_signed_in else "You", "score": "%d Levels" % GameState.highest_level, "reward": "⭐ %d" % GameState.total_stars},
			{"name": "CircuitMaster", "score": "98 Levels", "reward": "⭐ 280"},
			{"name": "VoltRunner", "score": "75 Levels", "reward": "⭐ 210"},
			{"name": "NeonSpark", "score": "52 Levels", "reward": "⭐ 150"}
		]
	})

func _play() -> void:
	GameState.game_mode = "continue"
	GameState.requested_level = GameState.highest_level
	get_tree().change_scene_to_file("res://scenes/electric_flow.tscn")

func _daily_challenge() -> void:
	GameState.start_mode("daily")
	get_tree().change_scene_to_file("res://scenes/electric_flow.tscn")

func _daily_reward() -> void:
	if GameState.claim_daily_reward(10):
		_refresh_ui()
		AudioManager.play_coin()
		ui.show_reward("Daily Reward", 10, "Come back tomorrow for another reward.")

func _watch_reward_ad() -> void:
	if _ad_pending:
		return
	_ad_pending = true
	_reward_callback = Callable(self, "_grant_ad_reward")
	_unavailable_callback = Callable(self, "_ad_unavailable")
	AdManager.rewarded_video_completed.connect(_reward_callback, CONNECT_ONE_SHOT)
	AdManager.rewarded_video_unavailable.connect(_unavailable_callback, CONNECT_ONE_SHOT)
	AdManager.show_rewarded_video()

func _grant_ad_reward() -> void:
	_ad_pending = false
	if AdManager.rewarded_video_unavailable.is_connected(_unavailable_callback):
		AdManager.rewarded_video_unavailable.disconnect(_unavailable_callback)
	GameState.coins += 100
	GameState.save_progress()
	_refresh_ui()
	ui.show_reward("Bonus Coins", 100, "Thanks for watching!")

func _ad_unavailable(message: String) -> void:
	_ad_pending = false
	if AdManager.rewarded_video_completed.is_connected(_reward_callback):
		AdManager.rewarded_video_completed.disconnect(_reward_callback)
	ui.show_message(message)

func _setting_changed(id: String, enabled: bool) -> void:
	match id:
		"music":
			GameState.music_enabled = enabled
			AudioManager.set_music_enabled(enabled)
		"sound": GameState.sfx_enabled = enabled
	GameState.save_progress()

func _settings_action(id: String) -> void:
	if id == "advanced":
		get_tree().change_scene_to_file("res://scenes/settings.tscn")

func _shop_action(id: String) -> void:
	var cost := -1
	for theme_data in Palette.THEMES:
		if str(theme_data["id"]) == id:
			cost = int(theme_data["price"])
			break
	if cost < 0:
		return
	if GameState.owned_themes.has(id):
		GameState.equip_theme(id)
		ui.show_message("%s equipped" % id)
	elif GameState.buy_theme(id, cost):
		AudioManager.play_win()
		ui.show_reward("New Theme", 0, "%s unlocked!" % id)
	else:
		AudioManager.play_lose()
		ui.show_reward("Not Enough Coins", 0, "Earn more coins to unlock %s." % id)
	_refresh_ui()

func _purchase_requested(_id: String) -> void:
	ui.show_reward("Store Unavailable", 0, "Google Play Billing is not connected yet.")

func _claim_mission(id: String) -> void:
	var definitions := {
		"play_one": [1, 15],
		"earn_three_stars": [3, 20],
		"play_three": [3, 25]
	}
	if not definitions.has(id):
		return
	var definition: Array = definitions[id]
	if GameState.claim_daily_mission(id, int(definition[0]), int(definition[1])):
		_refresh_ui()
		AudioManager.play_coin()
		ui.show_reward("Mission Complete", int(definition[1]))

func _leaderboard_signin() -> void:
	if not PlayGamesManager.is_signed_in:
		ui.show_message("Connecting to Google Play Games...")
		PlayGamesManager.sign_in()
	else:
		PlayGamesManager.show_all_leaderboards()

func _on_leaderboard_full() -> void:
	if PlayGamesManager.is_signed_in:
		PlayGamesManager.show_all_leaderboards()
	else:
		PlayGamesManager.sign_in()

func _exit_tree() -> void:
	if _reward_callback.is_valid() and AdManager.rewarded_video_completed.is_connected(_reward_callback):
		AdManager.rewarded_video_completed.disconnect(_reward_callback)
	if _unavailable_callback.is_valid() and AdManager.rewarded_video_unavailable.is_connected(_unavailable_callback):
		AdManager.rewarded_video_unavailable.disconnect(_unavailable_callback)
