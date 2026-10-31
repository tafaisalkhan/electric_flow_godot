extends Node

const SAVE_PATH := "user://math_mind_progress.cfg"
const SAVE_VERSION := 2

var highest_level: int = 1
var highest_levels: Array[int] = [1, 0, 0, 0]
var last_selected_levels: Array[int] = [1, 1, 1, 1]
var coins: int = 0
var total_stars: int = 0
var win_streak: int = 0
var games_played: int = 0
var selected_theme: String = "Classic"
var owned_themes: Array[String] = ["Classic"]
var last_daily_reward_date: String = ""
var daily_activity_date: String = ""
var daily_games_played: int = 0
var daily_stars_earned: int = 0
var claimed_missions: Array[String] = []
var game_mode: String = "continue"
var requested_level: int = 1
var music_volume: float = 0.8
var sfx_volume: float = 0.9
var music_enabled: bool = true
var sfx_enabled: bool = true
var multiply_symbol: String = "×"
var divide_symbol: String = "÷"
var ads_removed: bool = false
var daily_notifications: bool = true
var privacy_accepted: bool = false
var show_privacy_on_start: bool = false
var difficulty_index: int = 0
var hints: int = 3

func _ready() -> void:
	load_progress()

func load_progress() -> void:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		save_progress()
		return
	var saved_version := int(config.get_value("progress", "save_version", 0))
	if saved_version < SAVE_VERSION:
		highest_level = 1
		total_stars = 0
		win_streak = 0
		games_played = 0
		save_progress()
		return
	highest_level = int(config.get_value("progress", "highest_level", 1))
	coins = int(config.get_value("progress", "coins", 0))
	hints = int(config.get_value("progress", "hints", 3))
	total_stars = int(config.get_value("progress", "total_stars", 0))
	win_streak = int(config.get_value("progress", "win_streak", 0))
	games_played = int(config.get_value("progress", "games_played", 0))
	selected_theme = str(config.get_value("progress", "theme", "Classic"))
	owned_themes.clear()
	for theme_name in config.get_value("progress", "owned_themes", ["Classic"]):
		var theme_id := str(theme_name)
		if not owned_themes.has(theme_id):
			owned_themes.append(theme_id)
	if not owned_themes.has("Classic"):
		owned_themes.append("Classic")
	if not owned_themes.has(selected_theme):
		selected_theme = "Classic"
	last_daily_reward_date = str(config.get_value("progress", "last_daily_reward_date", ""))
	daily_activity_date = str(config.get_value("progress", "daily_activity_date", ""))
	daily_games_played = int(config.get_value("progress", "daily_games_played", 0))
	daily_stars_earned = int(config.get_value("progress", "daily_stars_earned", 0))
	claimed_missions.clear()
	for mission_id in config.get_value("progress", "claimed_missions", []):
		claimed_missions.append(str(mission_id))
	_refresh_daily_activity()
	music_volume = float(config.get_value("settings", "music_volume", 0.8))
	sfx_volume = float(config.get_value("settings", "sfx_volume", 0.9))
	music_enabled = bool(config.get_value("settings", "music_enabled", true))
	sfx_enabled = bool(config.get_value("settings", "sfx_enabled", true))
	multiply_symbol = str(config.get_value("settings", "multiply_symbol", "×"))
	divide_symbol = str(config.get_value("settings", "divide_symbol", "÷"))
	ads_removed = bool(config.get_value("settings", "ads_removed", false))
	daily_notifications = bool(config.get_value("settings", "daily_notifications", true))
	privacy_accepted = bool(config.get_value("privacy", "accepted", false))
	show_privacy_on_start = bool(config.get_value("privacy", "show_on_start", false))
	difficulty_index = clampi(int(config.get_value("settings", "difficulty_index", 0)), 0, 3)
	highest_levels = [
		int(config.get_value("progress", "highest_easy", highest_level)),
		int(config.get_value("progress", "highest_medium", 0)),
		int(config.get_value("progress", "highest_hard", 0)),
		int(config.get_value("progress", "highest_expert", 0))
	]
	last_selected_levels = [
		int(config.get_value("progress", "last_easy", 1)),
		int(config.get_value("progress", "last_medium", 1)),
		int(config.get_value("progress", "last_hard", 1)),
		int(config.get_value("progress", "last_expert", 1))
	]
	if not is_difficulty_unlocked(difficulty_index):
		difficulty_index = 0
	highest_level = maxi(1, highest_levels[difficulty_index])
	requested_level = clampi(last_selected_levels[difficulty_index], 1, highest_level)

func save_progress() -> void:
	var config := ConfigFile.new()
	config.set_value("progress", "save_version", SAVE_VERSION)
	highest_levels[difficulty_index] = maxi(highest_levels[difficulty_index], highest_level)
	config.set_value("progress", "highest_level", highest_level)
	config.set_value("progress", "highest_easy", highest_levels[0])
	config.set_value("progress", "highest_medium", highest_levels[1])
	config.set_value("progress", "highest_hard", highest_levels[2])
	config.set_value("progress", "highest_expert", highest_levels[3])
	config.set_value("progress", "last_easy", last_selected_levels[0])
	config.set_value("progress", "last_medium", last_selected_levels[1])
	config.set_value("progress", "last_hard", last_selected_levels[2])
	config.set_value("progress", "last_expert", last_selected_levels[3])
	config.set_value("progress", "coins", coins)
	config.set_value("progress", "hints", hints)
	config.set_value("progress", "total_stars", total_stars)
	config.set_value("progress", "win_streak", win_streak)
	config.set_value("progress", "games_played", games_played)
	config.set_value("progress", "theme", selected_theme)
	config.set_value("progress", "owned_themes", owned_themes)
	config.set_value("progress", "last_daily_reward_date", last_daily_reward_date)
	config.set_value("progress", "daily_activity_date", daily_activity_date)
	config.set_value("progress", "daily_games_played", daily_games_played)
	config.set_value("progress", "daily_stars_earned", daily_stars_earned)
	config.set_value("progress", "claimed_missions", claimed_missions)
	config.set_value("settings", "music_volume", music_volume)
	config.set_value("settings", "sfx_volume", sfx_volume)
	config.set_value("settings", "music_enabled", music_enabled)
	config.set_value("settings", "sfx_enabled", sfx_enabled)
	config.set_value("settings", "multiply_symbol", multiply_symbol)
	config.set_value("settings", "divide_symbol", divide_symbol)
	config.set_value("settings", "ads_removed", ads_removed)
	config.set_value("settings", "daily_notifications", daily_notifications)
	config.set_value("privacy", "accepted", privacy_accepted)
	config.set_value("privacy", "show_on_start", show_privacy_on_start)
	config.set_value("settings", "difficulty_index", difficulty_index)
	config.save(SAVE_PATH)
	var pgm = get_node_or_null("/root/PlayGamesManager")
	if pgm != null and pgm.has_method("save_to_cloud"):
		pgm.save_to_cloud()

func to_cloud_dict() -> Dictionary:
	return {
		"save_version": SAVE_VERSION,
		"timestamp": Time.get_unix_time_from_system(),
		"highest_level": highest_level,
		"highest_levels": highest_levels,
		"last_selected_levels": last_selected_levels,
		"coins": coins,
		"hints": hints,
		"total_stars": total_stars,
		"win_streak": win_streak,
		"games_played": games_played,
		"selected_theme": selected_theme,
		"owned_themes": owned_themes,
		"difficulty_index": difficulty_index,
		"claimed_missions": claimed_missions,
		"ads_removed": ads_removed
	}

func merge_from_cloud_dict(dict: Dictionary) -> bool:
	var changed: bool = false
	var cloud_coins: int = int(dict.get("coins", 0))
	if cloud_coins > coins:
		coins = cloud_coins
		changed = true

	var cloud_hints: int = int(dict.get("hints", 3))
	if cloud_hints > hints:
		hints = cloud_hints
		changed = true
		
	var cloud_highest: int = int(dict.get("highest_level", 1))
	if cloud_highest > highest_level:
		highest_level = cloud_highest
		changed = true
		
	var cloud_stars: int = int(dict.get("total_stars", 0))
	if cloud_stars > total_stars:
		total_stars = cloud_stars
		changed = true
		
	var cloud_themes: Array = dict.get("owned_themes", ["Classic"])
	for t in cloud_themes:
		var tid: String = str(t)
		if not owned_themes.has(tid):
			owned_themes.append(tid)
			changed = true
			
	var cloud_ads_removed: bool = bool(dict.get("ads_removed", false))
	if cloud_ads_removed and not ads_removed:
		ads_removed = true
		changed = true
		
	var cloud_highest_levels: Array = dict.get("highest_levels", [highest_level, 0, 0, 0])
	for i in range(mini(highest_levels.size(), cloud_highest_levels.size())):
		var val := int(cloud_highest_levels[i])
		if val > highest_levels[i]:
			highest_levels[i] = val
			changed = true
			
	if changed:
		# Save merged progress locally
		var config := ConfigFile.new()
		config.set_value("progress", "save_version", SAVE_VERSION)
		config.set_value("progress", "highest_level", highest_level)
		config.set_value("progress", "coins", coins)
		config.set_value("progress", "hints", hints)
		config.set_value("progress", "total_stars", total_stars)
		config.set_value("progress", "owned_themes", owned_themes)
		config.set_value("settings", "ads_removed", ads_removed)
		config.save(SAVE_PATH)
		
	return changed

func use_hint() -> bool:
	if hints > 0:
		hints -= 1
		save_progress()
		return true
	return false

func add_hints(amount: int) -> void:
	if amount > 0:
		hints += amount
		save_progress()

func unlocked_chapter() -> int:
	return maxi(1, int((highest_level - 1) / 10) + 1)

func daily_level() -> int:
	var date := Time.get_date_dict_from_system()
	return 1000 + int(date.year) * 372 + int(date.month) * 31 + int(date.day)

func start_mode(mode: String) -> void:
	game_mode = mode
	match mode:
		"daily": requested_level = daily_level()
		"endless": requested_level = maxi(highest_level, 11)
		_: requested_level = clampi(last_selected_levels[difficulty_index], 1, highest_level)

func start_game_type(type_index: int) -> void:
	game_mode = "selected"
	var start_levels := [1, 101, 201, 301]
	requested_level = start_levels[clampi(type_index, 0, start_levels.size() - 1)]
func start_selected_level(level: int) -> void:
	game_mode = "selected"
	if level > highest_level:
		return
	requested_level = clampi(level, 1, 99999)
	last_selected_levels[difficulty_index] = requested_level
	save_progress()
func is_difficulty_unlocked(_index: int) -> bool:
	return true

func set_difficulty(index: int) -> bool:
	index = clampi(index, 0, 3)
	if not is_difficulty_unlocked(index):
		return false
	highest_levels[difficulty_index] = maxi(highest_levels[difficulty_index], highest_level)
	difficulty_index = index
	highest_level = maxi(1, highest_levels[index])
	requested_level = clampi(last_selected_levels[index], 1, highest_level)
	save_progress()
	return true

func remember_level(level: int) -> void:
	requested_level = clampi(level, 1, 99999)
	last_selected_levels[difficulty_index] = requested_level
	save_progress()

func register_win(level: int, stars: int, reward: int) -> void:
	_refresh_daily_activity()
	# Only the next sequential level can be unlocked by a win.
	if level <= highest_level:
		highest_level = maxi(highest_level, level + 1)
		highest_levels[difficulty_index] = highest_level
	coins += reward
	total_stars += stars
	win_streak += 1
	games_played += 1
	daily_games_played += 1
	daily_stars_earned += stars
	save_progress()

func _today_key() -> String:
	var date := Time.get_date_dict_from_system()
	return "%04d-%02d-%02d" % [date.year, date.month, date.day]

func _refresh_daily_activity() -> void:
	var today := _today_key()
	if daily_activity_date == today:
		return
	daily_activity_date = today
	daily_games_played = 0
	daily_stars_earned = 0
	claimed_missions.clear()

func can_claim_daily_reward() -> bool:
	return last_daily_reward_date != _today_key()

func claim_daily_reward(amount: int = 10) -> bool:
	if amount <= 0 or not can_claim_daily_reward():
		return false
	last_daily_reward_date = _today_key()
	coins += amount
	save_progress()
	return true

func daily_mission_progress(id: String) -> int:
	_refresh_daily_activity()
	match id:
		"play_one": return daily_games_played
		"earn_three_stars": return daily_stars_earned
		"play_three": return daily_games_played
	return 0

func claim_daily_mission(id: String, target: int, reward: int) -> bool:
	_refresh_daily_activity()
	if claimed_missions.has(id) or daily_mission_progress(id) < target or reward <= 0:
		return false
	claimed_missions.append(id)
	coins += reward
	save_progress()
	return true

func buy_theme(theme_id: String, cost: int) -> bool:
	if cost < 0 or coins < cost or owned_themes.has(theme_id):
		return false
	coins -= cost
	owned_themes.append(theme_id)
	selected_theme = theme_id
	save_progress()
	return true

func equip_theme(theme_id: String) -> bool:
	if not owned_themes.has(theme_id):
		return false
	selected_theme = theme_id
	save_progress()
	return true
