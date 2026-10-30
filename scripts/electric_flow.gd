# electric_flow.gd
# Main Game Controller for Electric Flow puzzle game.
extends Control

const ElectricTileScene = preload("res://scenes/electric_tile.tscn")
const ConfettiCannonsScript = preload("res://scripts/confetti_cannons.gd")
const ElectricEnums = preload("res://scripts/electric_enums.gd")
const ElectricLevels = preload("res://scripts/electric_levels.gd")

# Node references (Game screen: Back, Level No, Coins)
@onready var back_btn: Button = %BackButton
@onready var header_level_label: Button = %LevelLabel
@onready var header_coins_pill: PanelContainer = %HeaderCoinsPill
@onready var header_coins_label: Label = %HeaderCoinsLabel
@onready var settings_btn: Button = get_node_or_null("%SettingsButton")
@onready var prev_level_pill_btn: Button = get_node_or_null("%PrevLevelPillBtn")
@onready var next_level_pill_btn: Button = get_node_or_null("%NextLevelPillBtn")
@onready var hint_btn: Button = get_node_or_null("%HintButton")
@onready var header_stars_label: Label = get_node_or_null("%HeaderStarsLabel")
@onready var restart_btn: Button = get_node_or_null("%RestartButton")
@onready var moves_label: Label = get_node_or_null("%MovesLabel")
@onready var bottom_hint_btn: Button = get_node_or_null("%BottomHintBtn")
@onready var shop_btn: Button = get_node_or_null("%ShopButton")
@onready var daily_btn: Button = get_node_or_null("%DailyButton")
@onready var leaderboard_btn: Button = get_node_or_null("%LeaderboardButton")
@onready var learn_btn: Button = get_node_or_null("%LearnButton")

@onready var board_container: CenterContainer = %BoardCenter
@onready var board_panel: Control = %BoardPanel
@onready var victory_layer: Control = %VictoryLayer
@onready var victory_card: Control = %VictoryCard
@onready var victory_banner: Control = %VictoryBanner
@onready var banner_label: Label = %BannerLabel
@onready var victory_shine_rays: Control = %VictoryShineRays
@onready var next_button: Button = %NextButton
@onready var restart_victory_btn: Button = %RestartVictoryButton
@onready var star1: TextureRect = %Star1
@onready var star2: TextureRect = %Star2
@onready var star3: TextureRect = %Star3
@onready var victory_summary: Label = %VictorySummary
@onready var reward_coins_label: Label = %RewardCoinsLabel
@onready var fact_title: Label = %FactTitle
@onready var fact_text: Label = %FactText
@onready var confetti: Control = %ConfettiCannons
@onready var landmark_display: Control = %LandmarkDisplay

@onready var shop_layer: Control = %ShopLayer
@onready var shop_card: Control = %ShopCard
@onready var shop_coins_value: Label = %ShopCoinsValue
@onready var skins_container: VBoxContainer = %SkinsContainer
@onready var shop_close_btn: Button = %ShopCloseBtn
@onready var tab_skins_btn: Button = %TabSkinsBtn
@onready var tab_coins_btn: Button = %TabCoinsBtn
@onready var coin_packs_container: VBoxContainer = %CoinPacksContainer

@onready var leaderboard_layer: Control = %LeaderboardLayer
@onready var leaderboard_card: Control = %LeaderboardCard
@onready var leaderboard_rows_container: VBoxContainer = %LeaderboardRowsContainer
@onready var leaderboard_close_btn: Button = %LeaderboardCloseBtn
@onready var play_games_btn: Button = %PlayGamesBtn
@onready var user_stats_label: Label = %UserStatsLabel

const GAME_FONT: Font = preload("res://assets/fonts/LuckiestGuy-Regular.ttf")
const SUB_FONT: Font = preload("res://assets/fonts/Fredoka-Variable.ttf")

# Electronics Handbook Codex references
@onready var codex_layer: Control = %CodexLayer
@onready var codex_card: Control = %CodexCard
@onready var codex_index: Label = %CodexIndexLabel
@onready var codex_name: Label = %CodexName
@onready var codex_category: Label = %CodexCategory
@onready var codex_purpose: Label = %CodexPurpose
@onready var codex_science: Label = %CodexScience
@onready var codex_fact: Label = %CodexFact
@onready var codex_prev_btn: Button = %CodexPrevBtn
@onready var codex_close_btn: Button = %CodexCloseBtn
@onready var codex_next_btn: Button = %CodexNextBtn

var codex_components: Array[int] = [
	ElectricEnums.TileType.RESISTOR,
	ElectricEnums.TileType.CAPACITOR,
	ElectricEnums.TileType.BULB,
	ElectricEnums.TileType.HEATER,
	ElectricEnums.TileType.FAN,
	ElectricEnums.TileType.VACUUM_TUBE,
	ElectricEnums.TileType.TESLA_COIL,
	ElectricEnums.TileType.BATTERY,
	ElectricEnums.TileType.SOLAR
]
var current_codex_index: int = 0

var current_level_num: int = 1
var is_daily_mode: bool = false
var board_rows: int = 3
var board_cols: int = 3
var grid_tiles: Dictionary = {} # Vector2i -> ElectricTile
var targets_in_level: Array[Control] = [] # Bulbs, Heaters, and Capacitors to power

var is_level_completed: bool = false
var is_evaluating: bool = false
var is_coin_animation_playing: bool = false
var audio_tones_player: AudioStreamPlayer
var audio_applause_player: AudioStreamPlayer
var cached_applause_sfx: AudioStreamWAV = null

# Moves & Stars tracking
var player_moves: int = 0
var current_min_moves: int = 1
var levels_completed_count: int = 0
var victory_stars_box: HBoxContainer = null
var victory_star_labels: Array[Label] = []
var victory_summary_label: Label = null

func _ready() -> void:
	# Audio setup
	audio_tones_player = AudioStreamPlayer.new()
	audio_tones_player.volume_db = -5.0
	add_child(audio_tones_player)
	
	audio_applause_player = AudioStreamPlayer.new()
	audio_applause_player.volume_db = -2.0
	add_child(audio_applause_player)
	
	# Connect UI buttons
	if back_btn:
		back_btn.pressed.connect(_on_back_pressed)
	if settings_btn:
		settings_btn.pressed.connect(_on_settings_pressed)
	if prev_level_pill_btn:
		prev_level_pill_btn.pressed.connect(_on_prev_quick_pressed)
	if header_level_label:
		header_level_label.pressed.connect(_open_level_select_dialog)
	if next_level_pill_btn:
		next_level_pill_btn.pressed.connect(_on_next_quick_pressed)
	if hint_btn:
		hint_btn.pressed.connect(_on_hint_pressed)
	if bottom_hint_btn:
		bottom_hint_btn.pressed.connect(_on_hint_pressed)
	if restart_btn:
		restart_btn.pressed.connect(_on_restart_pressed)
	if shop_btn:
		shop_btn.pressed.connect(_on_shop_pressed)
	if leaderboard_btn:
		leaderboard_btn.pressed.connect(_on_leaderboard_pressed)
	if daily_btn:
		daily_btn.pressed.connect(_on_daily_pressed)
	if learn_btn:
		learn_btn.pressed.connect(_on_learn_pressed)
	if next_button:
		next_button.pressed.connect(_on_next_level_pressed)
	if restart_victory_btn:
		restart_victory_btn.pressed.connect(_on_restart_pressed)
	if codex_close_btn:
		codex_close_btn.pressed.connect(_close_codex)
	if codex_prev_btn:
		codex_prev_btn.pressed.connect(_prev_codex)
	if codex_next_btn:
		codex_next_btn.pressed.connect(_next_codex)
	if shop_close_btn:
		shop_close_btn.pressed.connect(_close_shop)
	if tab_skins_btn:
		tab_skins_btn.pressed.connect(func(): _select_shop_tab(0))
	if tab_coins_btn:
		tab_coins_btn.pressed.connect(func(): _select_shop_tab(1))
	if leaderboard_close_btn:
		leaderboard_close_btn.pressed.connect(_close_leaderboard)
	if play_games_btn:
		play_games_btn.pressed.connect(_on_play_games_btn_pressed)
	var shop_backdrop := get_node_or_null("%ShopBackdrop")
	if shop_backdrop:
		shop_backdrop.gui_input.connect(func(ev: InputEvent):
			if ev is InputEventMouseButton and ev.pressed:
				_close_shop()
		)
	var lb_backdrop := get_node_or_null("%LeaderboardBackdrop")
	if lb_backdrop:
		lb_backdrop.gui_input.connect(func(ev: InputEvent):
			if ev is InputEventMouseButton and ev.pressed:
				_close_leaderboard()
		)
	_update_header_coins()
	_update_hint_display()
		
	# Setup victory screen stars & summary cards
	_setup_victory_ui_elements()
	
	# Pick level from GameState if set, otherwise default to Level 1
	if GameState.requested_level > 0:
		current_level_num = GameState.requested_level
	else:
		current_level_num = 1
		
	victory_layer.visible = false
	victory_layer.modulate.a = 0.0
	
	load_level(current_level_num)
	get_viewport().size_changed.connect(_on_viewport_resized)

func _on_viewport_resized() -> void:
	_layout_board()

func load_daily_challenge() -> void:
	is_daily_mode = true
	is_level_completed = false
	player_moves = 0
	
	var data := ElectricLevels.get_daily_challenge()
	current_min_moves = int(data.get("min_moves", 4))
	_update_moves_display()
	_update_header_coins()
	
	_update_level_nav()
	
	# Hide victory UI
	victory_layer.visible = false
	victory_layer.modulate.a = 0.0
	confetti.stop()
	
	# Banner control during gameplay: hide top banner, show bottom banner
	AdManager.hide_banner_top()
	AdManager.show_banner_bottom()
	
	_build_board_from_data(data)

func load_level(level_idx: int) -> void:
	is_daily_mode = false
	current_level_num = clampi(level_idx, 1, ElectricLevels.get_total_levels())
	GameState.requested_level = current_level_num
	is_level_completed = false
	player_moves = 0
	
	var data := ElectricLevels.get_level(current_level_num)
	current_min_moves = int(data.get("min_moves", 2))
	_update_moves_display()
	_update_header_coins()
	
	_update_level_nav()
	
	# Hide victory UI
	victory_layer.visible = false
	victory_layer.modulate.a = 0.0
	confetti.stop()
	
	# Banner control during gameplay: hide top banner, show bottom banner
	AdManager.hide_banner_top()
	AdManager.show_banner_bottom()
	
	# Progressive component discovery announcement
	var newly_unlocked: int = ElectricComponentData.is_newly_unlocked_at_level(current_level_num)
	if newly_unlocked != -1:
		_show_discovery_toast(newly_unlocked)
	
	_build_board_from_data(data)

func _build_board_from_data(data: Dictionary) -> void:
	# Clear old tiles
	for tile in grid_tiles.values():
		tile.queue_free()
	grid_tiles.clear()
	targets_in_level.clear()
	
	board_rows = int(data.get("rows", 3))
	board_cols = int(data.get("cols", 3))
	var tiles_data: Array = data.get("tiles", [])
	
	if landmark_display:
		landmark_display.configure_level(current_level_num if not is_daily_mode else 100, board_rows, board_cols)
	
	# Create tiles
	for r in range(board_rows):
		for c in range(board_cols):
			var idx := r * board_cols + c
			var t_data: Dictionary = tiles_data[idx] if idx < tiles_data.size() else {"type": ElectricEnums.TileType.EMPTY}
			
			var tile: Control = ElectricTileScene.instantiate()
			board_panel.add_child(tile)
			tile.configure(r, c, t_data, 100.0)
			tile.tile_clicked.connect(_on_tile_clicked)
			grid_tiles[Vector2i(r, c)] = tile
			
			var t_type: int = int(t_data.get("type", 0))
			if t_type in [
				ElectricEnums.TileType.BULB,
				ElectricEnums.TileType.HEATER,
				ElectricEnums.TileType.FAN,
				ElectricEnums.TileType.VACUUM_TUBE,
				ElectricEnums.TileType.TESLA_COIL
			]:
				targets_in_level.append(tile)
	
	_layout_board()
	_evaluate_circuit(false)

func _layout_board() -> void:
	if not is_instance_valid(board_panel):
		return
		
	var tray_padding := 14.0
	var spacing := 6.0
	
	var avail_w := size.x * 0.92 - (tray_padding * 2.0)
	var avail_h := size.y * 0.54 - (tray_padding * 2.0)
	
	var max_tile_w := avail_w / float(board_cols)
	var max_tile_h := avail_h / float(board_rows)
	var tile_size := clampf(minf(max_tile_w, max_tile_h), 56.0, 136.0)
	
	if board_panel.has_method("configure_tray"):
		board_panel.configure_tray(board_rows, board_cols, tile_size, spacing, tray_padding)
	else:
		var total_w := board_cols * tile_size + (board_cols - 1) * spacing
		var total_h := board_rows * tile_size + (board_rows - 1) * spacing
		board_panel.custom_minimum_size = Vector2(total_w, total_h)
		board_panel.size = Vector2(total_w, total_h)
	
	for r in range(board_rows):
		for c in range(board_cols):
			var tile: Control = grid_tiles.get(Vector2i(r, c))
			if tile:
				tile.tile_size = tile_size
				tile.custom_minimum_size = Vector2(tile_size, tile_size)
				tile.size = Vector2(tile_size, tile_size)
				tile.position = Vector2(tray_padding + c * (tile_size + spacing), tray_padding + r * (tile_size + spacing))
				tile.queue_redraw()

func _on_tile_clicked(r: int, c: int) -> void:
	if is_level_completed:
		return
	var tile: Control = grid_tiles.get(Vector2i(r, c))
	if tile and tile.is_rotatable:
		player_moves += 1
		_update_moves_display()
	_play_click_sfx()
	# Circuit evaluation with small delay to align with rotation tween
	get_tree().create_timer(0.08).timeout.connect(func():
		_evaluate_circuit(true)
	)

func _update_moves_display() -> void:
	if not is_instance_valid(moves_label):
		return
	moves_label.text = "Moves: %d  |  Par: %d" % [player_moves, current_min_moves]
	if player_moves <= current_min_moves:
		# Optimal / 3 stars
		moves_label.add_theme_color_override("font_color", Color(0.2, 0.95, 0.85, 1.0))
	elif player_moves <= current_min_moves + 2:
		# 2 stars
		moves_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35, 1.0))
	else:
		# 1 star
		moves_label.add_theme_color_override("font_color", Color(0.9, 0.6, 0.6, 1.0))

func _evaluate_circuit(play_sfx: bool = true) -> void:
	# 1. Multi-source BFS starting from each battery and solar panel to find circuit paths & distance hops
	var queue: Array[Dictionary] = [] # {"pos": Vector2i, "channel": int, "step": int}
	var visited: Dictionary = {} # Vector2i -> Array[int] of channels visited
	var powered_results: Dictionary = {} # Vector2i -> {"channel": int, "step": int}
	var max_wave_step := 0
	
	for pos in grid_tiles.keys():
		var tile: Control = grid_tiles[pos]
		if tile.tile_type == ElectricEnums.TileType.BATTERY or tile.tile_type == ElectricEnums.TileType.SOLAR:
			queue.append({"pos": pos, "channel": tile.channel, "step": 0})
			visited[pos] = [tile.channel]
			powered_results[pos] = {"channel": tile.channel, "step": 0}
	
	var newly_lit_element := false
	var max_new_target_step := 0
	
	while not queue.is_empty():
		var current: Dictionary = queue.pop_front()
		var curr_pos: Vector2i = current["pos"]
		var curr_ch: int = current["channel"]
		var curr_step: int = current["step"]
		var curr_tile: Control = grid_tiles[curr_pos]
		var curr_ports: int = curr_tile.get_connected_ports()
		
		# Check all 4 orthogonal directions
		var dirs := [
			ElectricEnums.DIR_UP,
			ElectricEnums.DIR_RIGHT,
			ElectricEnums.DIR_DOWN,
			ElectricEnums.DIR_LEFT
		]
		
		for d in dirs:
			if (curr_ports & d) != 0:
				var offset := ElectricEnums.get_dir_offset(d)
				var neighbor_pos := curr_pos + offset
				
				if not grid_tiles.has(neighbor_pos):
					continue
				
				var neighbor_tile: Control = grid_tiles[neighbor_pos]
				if neighbor_tile.tile_type == ElectricEnums.TileType.EMPTY:
					continue
				
				var opp_dir := ElectricEnums.get_opposite_dir(d)
				var neighbor_ports: int = neighbor_tile.get_connected_ports()
				
				# Check if neighbor has an open port facing this tile
				if (neighbor_ports & opp_dir) != 0:
					var next_step: int = curr_step + 1
					if next_step > max_wave_step:
						max_wave_step = next_step
						
					# Check tile type
					if neighbor_tile.tile_type == ElectricEnums.TileType.BULB:
						if neighbor_tile.channel == ElectricEnums.Channel.NONE or neighbor_tile.channel == curr_ch:
							if not neighbor_tile.is_powered:
								newly_lit_element = true
								max_new_target_step = maxi(max_new_target_step, next_step)
							if not powered_results.has(neighbor_pos):
								powered_results[neighbor_pos] = {"channel": curr_ch, "step": next_step, "inlet": opp_dir}
					elif neighbor_tile.tile_type in [
						ElectricEnums.TileType.HEATER,
						ElectricEnums.TileType.FAN,
						ElectricEnums.TileType.VACUUM_TUBE,
						ElectricEnums.TileType.TESLA_COIL
					]:
						if neighbor_tile.channel == ElectricEnums.Channel.NONE or neighbor_tile.channel == curr_ch:
							if not neighbor_tile.is_powered:
								newly_lit_element = true
								max_new_target_step = maxi(max_new_target_step, next_step)
							if not powered_results.has(neighbor_pos):
								powered_results[neighbor_pos] = {"channel": curr_ch, "step": next_step, "inlet": opp_dir}
							var visited_channels: Array = visited.get(neighbor_pos, [])
							if not visited_channels.has(curr_ch):
								visited_channels.append(curr_ch)
								visited[neighbor_pos] = visited_channels
								queue.append({"pos": neighbor_pos, "channel": curr_ch, "step": next_step})
					elif neighbor_tile.tile_type != ElectricEnums.TileType.BATTERY and neighbor_tile.tile_type != ElectricEnums.TileType.SOLAR:
						var visited_channels: Array = visited.get(neighbor_pos, [])
						if not visited_channels.has(curr_ch):
							visited_channels.append(curr_ch)
							visited[neighbor_pos] = visited_channels
							if not powered_results.has(neighbor_pos):
								powered_results[neighbor_pos] = {"channel": curr_ch, "step": next_step, "inlet": opp_dir}
							queue.append({"pos": neighbor_pos, "channel": curr_ch, "step": next_step})

	# 2. Apply power state with progressive point-to-point current propagation flow
	var step_interval := 0.22
	var current_flowed := false
	for pos in grid_tiles.keys():
		var tile: Control = grid_tiles[pos]
		if powered_results.has(pos):
			var res: Dictionary = powered_results[pos]
			var step: int = res["step"]
			# If this tile was NOT already powered, flow delay according to step distance from power source:
			var delay: float = 0.0
			if play_sfx and not tile.is_powered:
				delay = float(maxi(0, step - 1)) * step_interval
				current_flowed = true
			tile.set_power_state(true, res["channel"], delay, res.get("inlet", 0), play_sfx)
		else:
			if tile.tile_type != ElectricEnums.TileType.BATTERY and tile.tile_type != ElectricEnums.TileType.SOLAR:
				tile.set_power_state(false, ElectricEnums.Channel.NONE, 0.0, 0, play_sfx)

	# Play electric flow sound when electric current surges through the circuit
	if play_sfx and (current_flowed or newly_lit_element):
		AudioManager.play_electric_flow()

	# 3. SFX triggers timed with current arriving at target
	if play_sfx and newly_lit_element:
		var sfx_delay := float(maxi(1, max_new_target_step)) * step_interval + 0.05
		get_tree().create_timer(sfx_delay).timeout.connect(func():
			_play_bulb_sfx()
		)
	
	# 4. Check victory condition & update landmark building status
	var all_targets_lit := true
	var lit_count := 0
	for target in targets_in_level:
		if target.is_powered:
			lit_count += 1
		else:
			all_targets_lit = false
			
	if landmark_display:
		landmark_display.set_circuit_status(lit_count, targets_in_level.size(), all_targets_lit)
	if is_instance_valid(board_panel) and board_panel.has_method("set_powered"):
		board_panel.set_powered(all_targets_lit)
	
	# Victory can only be triggered by an active player move (play_sfx is true).
	# Delay victory to allow the electric current wave to finish visibly surging into all targets!
	if all_targets_lit and not targets_in_level.is_empty() and not is_level_completed and play_sfx:
		var wave_finish_time := float(max_wave_step) * step_interval + 0.35
		get_tree().create_timer(wave_finish_time).timeout.connect(func():
			if not is_level_completed:
				_trigger_victory()
		)

func _trigger_victory() -> void:
	is_level_completed = true
	
	# Star award logic based on moves:
	# - <= min_moves: 3 stars
	# - <= min_moves + 2: 2 stars
	# - more moves: 1 star
	var stars_earned := 1
	if player_moves <= current_min_moves:
		stars_earned = 3
	elif player_moves <= current_min_moves + 2:
		stars_earned = 2
	else:
		stars_earned = 1
		
	# Coin reward rule from user specification:
	# Perfect / 3 Stars = 10 coins, 2 Stars = 5 coins, Else (1 Star) = 2 coins.
	# Daily Challenge grants 25 coins bonus!
	var reward_coins := 2
	if is_daily_mode:
		reward_coins = 25
	elif stars_earned == 3:
		reward_coins = 10
	elif stars_earned == 2:
		reward_coins = 5
	else:
		reward_coins = 2
		
	var prev_coins: int = GameState.coins
	GameState.register_win(current_level_num if not is_daily_mode else 0, stars_earned, reward_coins)
	if is_instance_valid(header_coins_label):
		header_coins_label.text = str(prev_coins)
	
	_play_victory_fanfare()
	_play_applause_sfx()
	
	# Wait brief moment for the last bulb ignition to register
	await get_tree().create_timer(0.35).timeout
	
	levels_completed_count += 1
	
	# Banner control on level completion: hide bottom banner to not block next button, show top banner
	AdManager.hide_banner_bottom()
	AdManager.show_banner_top()
	
	victory_layer.visible = true
	victory_layer.modulate.a = 0.0
	confetti.burst(160)
	
	# Update banner title based on stars
	if banner_label:
		if is_daily_mode:
			banner_label.text = "DAILY SOLVED !"
		elif stars_earned == 3:
			banner_label.text = "PERFECT !"
		elif stars_earned == 2:
			banner_label.text = "AWESOME !"
		else:
			banner_label.text = "CLEARED !"
			
	# Update reward coins label with LuckiestGuy font & bouncy pop-in
	if reward_coins_label:
		reward_coins_label.add_theme_font_override("font", GAME_FONT)
		reward_coins_label.scale = Vector2.ZERO
		reward_coins_label.pivot_offset = reward_coins_label.size * 0.5
		reward_coins_label.text = "+%d COINS" % reward_coins
		var coin_badge_tw := create_tween()
		coin_badge_tw.tween_interval(1.1)
		coin_badge_tw.tween_property(reward_coins_label, "scale", Vector2(1.3, 1.3), 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		coin_badge_tw.tween_property(reward_coins_label, "scale", Vector2.ONE, 0.16)
		coin_badge_tw.tween_callback(func():
			if GameState.sfx_enabled:
				_play_tone_sfx(987.77, 0.18, 0.65)
			_spawn_flying_coins_flow(reward_coins, prev_coins)
		)
		
	# Update moves summary
	if victory_summary:
		if is_daily_mode:
			victory_summary.text = "Daily Challenge completed in %d moves! (Par: %d)" % [player_moves, current_min_moves]
		elif stars_earned == 3:
			victory_summary.text = "Optimal solve in %d moves! (Par: %d)" % [player_moves, current_min_moves]
		elif stars_earned == 2:
			victory_summary.text = "Solved in %d moves (Par: %d)" % [player_moves, current_min_moves]
		else:
			victory_summary.text = "Cleared in %d moves (Par: %d)" % [player_moves, current_min_moves]

	# Update educational fact card in victory modal
	var primary_t := ElectricComponentData.get_primary_component_for_level(current_level_num)
	var comp_info := ElectricComponentData.get_component_info(primary_t)
	if fact_title:
		fact_title.text = "⚡ %s SCIENCE FACT:" % str(comp_info.get("name", "ELECTRONICS")).to_upper()
	if fact_text:
		fact_text.text = str(comp_info.get("fun_fact", ""))

	# Animate Shine Rays expanding & rotating
	if victory_shine_rays:
		victory_shine_rays.scale = Vector2.ZERO
		var shine_tw := create_tween()
		shine_tw.tween_property(victory_shine_rays, "scale", Vector2.ONE, 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	# Animate victory card modal entrance
	if victory_card:
		victory_card.scale = Vector2(0.35, 0.35)
		victory_card.modulate.a = 0.0
		var card_tw := create_tween().set_parallel(true)
		card_tw.tween_property(victory_layer, "modulate:a", 1.0, 0.25)
		card_tw.tween_property(victory_card, "modulate:a", 1.0, 0.25)
		card_tw.tween_property(victory_card, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	# Staggered pop-in for 2D stars from assets
	_animate_victory_stars(stars_earned)

	# Next button starts locked & dimmed until coin collection animation finishes
	is_coin_animation_playing = true
	if next_button:
		next_button.disabled = true
		next_button.modulate.a = 0.45
		next_button.scale = Vector2(0.85, 0.85)

func _setup_victory_ui_elements() -> void:
	# Initial reset of victory elements
	is_coin_animation_playing = false
	if is_instance_valid(victory_layer):
		victory_layer.visible = false
		victory_layer.modulate.a = 0.0
	if is_instance_valid(next_button):
		next_button.disabled = false
		next_button.modulate.a = 1.0
		next_button.scale = Vector2.ONE

func _animate_victory_stars(stars_earned: int) -> void:
	var stars: Array[TextureRect] = [star1, star2, star3]
	var pitches: Array[float] = [523.25, 659.25, 783.99]
	for i in range(stars.size()):
		var star_rect := stars[i]
		if not is_instance_valid(star_rect):
			continue
			
		var is_active := (i < stars_earned)
		star_rect.pivot_offset = star_rect.size * 0.5
		if is_active:
			star_rect.modulate = Color.WHITE
			star_rect.scale = Vector2.ZERO
			star_rect.rotation = -0.35
			var delay := 0.35 + float(i) * 0.26
			var star_tw := create_tween()
			star_tw.tween_interval(delay)
			star_tw.tween_property(star_rect, "scale", Vector2(1.35, 1.35), 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			star_tw.parallel().tween_property(star_rect, "rotation", 0.08, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			star_tw.tween_property(star_rect, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
			star_tw.parallel().tween_property(star_rect, "rotation", 0.0, 0.16)
			
			star_tw.tween_callback(func():
				if GameState.sfx_enabled:
					AudioManager.play_star(1.0 + float(i) * 0.15)
			)
		else:
			# Dimmed inactive silhouette for missing stars
			star_rect.modulate = Color(0.22, 0.28, 0.40, 0.45)
			star_rect.scale = Vector2.ONE
			star_rect.rotation = 0.0

func _spawn_flying_coins_flow(reward_coins: int, base_coins: int) -> void:
	if not is_instance_valid(reward_coins_label) or not is_instance_valid(header_coins_pill):
		_update_header_coins()
		is_coin_animation_playing = false
		if is_instance_valid(next_button):
			next_button.disabled = false
			next_button.modulate.a = 1.0
			next_button.scale = Vector2.ONE
		return
		
	var start_pos := reward_coins_label.global_position + reward_coins_label.size * 0.5
	var target_pos := header_coins_pill.global_position + header_coins_pill.size * 0.5
	
	var coin_count := clampi(reward_coins, 5, 10)
	var coin_val_step := float(reward_coins) / float(coin_count)
	var coin_texture: Texture2D = preload("res://assets/generated/reward-coin.png")
	
	for i in range(coin_count):
		var coin_spr := TextureRect.new()
		coin_spr.texture = coin_texture
		coin_spr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		coin_spr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		coin_spr.custom_minimum_size = Vector2(28, 28)
		coin_spr.size = Vector2(28, 28)
		coin_spr.pivot_offset = Vector2(14, 14)
		coin_spr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		coin_spr.top_level = true
		add_child(coin_spr)
		
		coin_spr.global_position = start_pos - Vector2(14, 14)
		coin_spr.scale = Vector2.ZERO
		
		var angle := randf_range(-PI * 0.85, -PI * 0.15)
		var burst_dist := randf_range(40.0, 90.0)
		var burst_offset := Vector2(cos(angle), sin(angle)) * burst_dist
		var midpoint := start_pos + burst_offset
		
		var fly_delay := float(i) * 0.065
		var tw := create_tween()
		tw.tween_interval(fly_delay)
		tw.tween_property(coin_spr, "scale", Vector2(1.25, 1.25), 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(coin_spr, "global_position", midpoint - Vector2(14, 14), 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(coin_spr, "global_position", target_pos - Vector2(14, 14), 0.38).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.parallel().tween_property(coin_spr, "scale", Vector2(0.85, 0.85), 0.38)
		
		var is_last := (i == coin_count - 1)
		var current_step_coins := base_coins + int(round(coin_val_step * float(i + 1)))
		tw.tween_callback(func():
			if is_instance_valid(coin_spr):
				coin_spr.queue_free()
			if GameState.sfx_enabled:
				AudioManager.play_coin(1.0 + float(i % 5) * 0.05)
			if is_instance_valid(header_coins_pill):
				header_coins_pill.pivot_offset = header_coins_pill.size * 0.5
				var punch_tw := create_tween()
				punch_tw.tween_property(header_coins_pill, "scale", Vector2(1.18, 1.18), 0.06)
				punch_tw.tween_property(header_coins_pill, "scale", Vector2.ONE, 0.08)
			if is_instance_valid(header_coins_label):
				if is_last:
					header_coins_label.text = str(GameState.coins)
					is_coin_animation_playing = false
					# Unlock Next button with a punchy bounce & unlock chime!
					if is_instance_valid(next_button):
						next_button.disabled = false
						var nxt_tw := create_tween()
						nxt_tw.tween_property(next_button, "modulate:a", 1.0, 0.15)
						nxt_tw.parallel().tween_property(next_button, "scale", Vector2(1.18, 1.18), 0.20).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
						nxt_tw.tween_property(next_button, "scale", Vector2.ONE, 0.12)
						if GameState.sfx_enabled:
							AudioManager.play_coin(1.25)
				else:
					header_coins_label.text = str(current_step_coins)
		)

# -------------------------------------------------------------
# ELECTRONICS COMPONENT HANDBOOK (CODEX)
# -------------------------------------------------------------
func _on_learn_pressed() -> void:
	_play_click_sfx()
	var feat_type := ElectricComponentData.get_primary_component_for_level(current_level_num)
	var idx := codex_components.find(feat_type)
	if idx >= 0:
		current_codex_index = idx
	_show_codex()

func _show_codex() -> void:
	_update_codex_view()
	codex_layer.visible = true
	codex_layer.modulate.a = 0.0
	codex_card.scale = Vector2(0.85, 0.85)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(codex_layer, "modulate:a", 1.0, 0.2)
	tw.tween_property(codex_card, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _close_codex() -> void:
	_play_click_sfx()
	var tw := create_tween()
	tw.tween_property(codex_layer, "modulate:a", 0.0, 0.18)
	await tw.finished
	codex_layer.visible = false

func _prev_codex() -> void:
	_play_click_sfx()
	current_codex_index = (current_codex_index - 1 + codex_components.size()) % codex_components.size()
	_update_codex_view()

func _next_codex() -> void:
	_play_click_sfx()
	current_codex_index = (current_codex_index + 1) % codex_components.size()
	_update_codex_view()

func _update_codex_view() -> void:
	var t_type := codex_components[current_codex_index]
	var info := ElectricComponentData.get_component_info(t_type)
	var unlock_lvl := ElectricComponentData.get_unlock_level(t_type)
	var is_unlocked := (current_level_num >= unlock_lvl or GameState.highest_level >= unlock_lvl)
	
	if codex_index:
		codex_index.text = "%d / %d" % [current_codex_index + 1, codex_components.size()]
		
	if is_unlocked:
		if codex_name:
			codex_name.text = str(info.get("name", "")).to_upper()
			codex_name.add_theme_color_override("font_color", Color(1, 0.88, 0.35, 1))
		if codex_category:
			codex_category.text = "%s • %s • %s" % [info.get("symbol", ""), info.get("category", ""), info.get("unit", "")]
		if codex_purpose:
			codex_purpose.text = str(info.get("short_purpose", ""))
		if codex_science:
			codex_science.text = str(info.get("how_it_works", ""))
		if codex_fact:
			codex_fact.text = str(info.get("fun_fact", ""))
	else:
		if codex_name:
			codex_name.text = "🔒 LOCKED (LEVEL %d)" % unlock_lvl
			codex_name.add_theme_color_override("font_color", Color(0.65, 0.72, 0.8, 0.85))
		if codex_category:
			codex_category.text = "Discovered at Level %d" % unlock_lvl
		if codex_purpose:
			codex_purpose.text = "Keep solving circuit puzzles to unlock and study this component at Level %d!" % unlock_lvl
		if codex_science:
			codex_science.text = "This electronic component will be introduced after you become familiar with the circuit basics."
		if codex_fact:
			codex_fact.text = "Master the early levels to become familiar with current flow first!"

var discovery_toast: PanelContainer = null
var discovery_label: Label = null

func _show_discovery_toast(tile_type: int) -> void:
	var info := ElectricComponentData.get_component_info(tile_type)
	var comp_name: String = str(info.get("name", "Component"))
	var purpose: String = str(info.get("short_purpose", ""))
	
	if discovery_toast == null:
		discovery_toast = PanelContainer.new()
		discovery_toast.custom_minimum_size = Vector2(440, 52)
		discovery_toast.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
		discovery_toast.offset_top = 100.0
		discovery_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
		discovery_toast.z_index = 30
		
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.04, 0.12, 0.24, 0.95)
		style.border_color = Color(0.0, 0.85, 1.0, 0.9)
		style.set_border_width_all(2)
		style.set_corner_radius_all(16)
		style.shadow_color = Color(0, 0, 0, 0.5)
		style.shadow_size = 8
		discovery_toast.add_theme_stylebox_override("panel", style)
		
		discovery_label = Label.new()
		discovery_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		discovery_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		discovery_label.add_theme_font_override("font", GAME_FONT)
		discovery_label.add_theme_font_size_override("font_size", 14)
		discovery_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4, 1.0))
		discovery_toast.add_child(discovery_label)
		add_child(discovery_toast)
		
	discovery_label.text = "⚡ NEW COMPONENT: %s!\n%s" % [comp_name, purpose]
	discovery_toast.visible = true
	discovery_toast.modulate.a = 0.0
	discovery_toast.scale = Vector2(0.85, 0.85)
	discovery_toast.pivot_offset = Vector2(220, 26)
	
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(discovery_toast, "modulate:a", 1.0, 0.3)
	tw.tween_property(discovery_toast, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.chain().tween_interval(3.5)
	tw.chain().tween_property(discovery_toast, "modulate:a", 0.0, 0.4)
	tw.tween_callback(func(): discovery_toast.visible = false)

func _on_next_level_pressed() -> void:
	if is_coin_animation_playing:
		return
	_play_click_sfx()
	if (levels_completed_count > 0 and levels_completed_count % 3 == 0) or (current_level_num % 3 == 0 and not is_daily_mode):
		AdManager.show_interstitial()
	var next_idx := current_level_num + 1
	if next_idx > ElectricLevels.get_total_levels():
		next_idx = 1 # Loop or back to level 1
	load_level(next_idx)

func _on_restart_pressed() -> void:
	_play_click_sfx()
	if GameState.sfx_enabled:
		AudioManager.play_lose()
	_show_restart_toast()
	if is_daily_mode:
		load_daily_challenge()
	else:
		load_level(current_level_num)

func _on_prev_quick_pressed() -> void:
	_play_click_sfx()
	if current_level_num > 1:
		load_level(current_level_num - 1)
	else:
		load_level(ElectricLevels.get_total_levels())

func _on_next_quick_pressed() -> void:
	_play_click_sfx()
	if current_level_num < ElectricLevels.get_total_levels():
		load_level(current_level_num + 1)
	else:
		load_level(1)

func _on_level_label_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_play_click_sfx()
		_open_level_select_dialog()

var level_select_layer: Control = null
var level_select_page: int = 0

func _create_level_select_dialog() -> void:
	if level_select_layer != null:
		return
		
	level_select_layer = Control.new()
	level_select_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	level_select_layer.visible = false
	level_select_layer.modulate.a = 0.0
	level_select_layer.z_index = 50
	add_child(level_select_layer)
	
	# Backdrop
	var backdrop := ColorRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.02, 0.04, 0.08, 0.85)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	backdrop.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed:
			_close_level_select_dialog()
	)
	level_select_layer.add_child(backdrop)
	
	# Center card panel
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	level_select_layer.add_child(center)
	
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(460, 680)
	var card_style := StyleBoxFlat.new()
	card_style.bg_color = Color(0.08, 0.13, 0.22, 0.98)
	card_style.border_width_left = 2
	card_style.border_width_top = 2
	card_style.border_width_right = 2
	card_style.border_width_bottom = 2
	card_style.border_color = Color(0.25, 0.45, 0.75, 1.0)
	card_style.set_corner_radius_all(20)
	card_style.shadow_color = Color(0, 0, 0, 0.5)
	card_style.shadow_size = 16
	card.add_theme_stylebox_override("panel", card_style)
	center.add_child(card)
	
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	card.add_child(margin)
	
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)
	
	# Top bar with Title and Close button
	var top_bar := HBoxContainer.new()
	vbox.add_child(top_bar)
	
	var title_lbl := Label.new()
	title_lbl.text = "SELECT LEVEL (1-%d)" % ElectricLevels.get_total_levels()
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_lbl.add_theme_font_override("font", GAME_FONT)
	title_lbl.add_theme_font_size_override("font_size", 20)
	title_lbl.add_theme_color_override("font_color", Color(1, 0.9, 0.4, 1))
	top_bar.add_child(title_lbl)
	
	var close_btn := Button.new()
	close_btn.text = "✕"
	close_btn.custom_minimum_size = Vector2(40, 40)
	close_btn.add_theme_font_override("font", GAME_FONT)
	close_btn.pressed.connect(_close_level_select_dialog)
	top_bar.add_child(close_btn)
	
	# Quick Jump Row
	var jump_row := HBoxContainer.new()
	jump_row.add_theme_constant_override("separation", 8)
	vbox.add_child(jump_row)
	
	var jump_lbl := Label.new()
	jump_lbl.text = "Go to Level:"
	jump_lbl.add_theme_font_override("font", SUB_FONT)
	jump_lbl.add_theme_font_size_override("font_size", 14)
	jump_row.add_child(jump_lbl)
	
	var jump_input := LineEdit.new()
	jump_input.placeholder_text = "e.g. 50"
	jump_input.text = str(current_level_num)
	jump_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	jump_input.add_theme_font_override("font", GAME_FONT)
	jump_row.add_child(jump_input)
	
	var jump_go_btn := Button.new()
	jump_go_btn.text = "GO"
	jump_go_btn.add_theme_font_override("font", GAME_FONT)
	jump_go_btn.custom_minimum_size = Vector2(60, 36)
	jump_go_btn.pressed.connect(func():
		var target := int(jump_input.text)
		if target >= 1 and target <= 1000:
			_play_click_sfx()
			load_level(target)
			_close_level_select_dialog()
	)
	jump_row.add_child(jump_go_btn)
	
	# Scroll container for levels
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)
	
	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	scroll.add_child(grid)
	
	# Bottom Page Nav Row
	var page_nav := HBoxContainer.new()
	page_nav.add_theme_constant_override("separation", 10)
	vbox.add_child(page_nav)
	
	var prev_page_btn := Button.new()
	prev_page_btn.text = "◀ Prev 30"
	prev_page_btn.add_theme_font_override("font", GAME_FONT)
	prev_page_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page_nav.add_child(prev_page_btn)
	
	var page_lbl := Label.new()
	page_lbl.text = "Page 1 / 34"
	page_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	page_lbl.add_theme_font_override("font", GAME_FONT)
	page_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page_nav.add_child(page_lbl)
	
	var next_page_btn := Button.new()
	next_page_btn.text = "Next 30 ▶"
	next_page_btn.add_theme_font_override("font", GAME_FONT)
	next_page_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page_nav.add_child(next_page_btn)
	
	# Start on page containing current_level_num
	level_select_page = clampi(int(float(current_level_num - 1) / 30.0), 0, 33)
	
	var update_page := func():
		_populate_level_page(grid, level_select_page)
		page_lbl.text = "Page %d / 34" % (level_select_page + 1)
		prev_page_btn.disabled = (level_select_page == 0)
		next_page_btn.disabled = (level_select_page >= 33)
	
	prev_page_btn.pressed.connect(func():
		_play_click_sfx()
		if level_select_page > 0:
			level_select_page -= 1
			update_page.call()
	)
	
	next_page_btn.pressed.connect(func():
		_play_click_sfx()
		if level_select_page < 33:
			level_select_page += 1
			update_page.call()
	)
	
	update_page.call()

func _populate_level_page(grid: GridContainer, page: int) -> void:
	for c in grid.get_children():
		c.queue_free()
		
	var page_size := 30
	var start_lvl := page * page_size + 1
	var end_lvl := mini(start_lvl + page_size - 1, 1000)
	
	for i in range(start_lvl, end_lvl + 1):
		var lvl_data := ElectricLevels.get_level(i)
		var lvl_btn := Button.new()
		lvl_btn.custom_minimum_size = Vector2(196, 46)
		lvl_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lvl_btn.add_theme_font_override("font", GAME_FONT)
		lvl_btn.add_theme_font_size_override("font_size", 13)
		
		var title: String = lvl_data.get("title", "Level %d" % i)
		var is_cur := (i == current_level_num)
		lvl_btn.text = ("▶ " if is_cur else "") + "Lvl %d: %s" % [i, title]
		lvl_btn.clip_text = true
		
		var btn_style := StyleBoxFlat.new()
		btn_style.bg_color = Color(0.18, 0.42, 0.75, 1.0) if is_cur else Color(0.12, 0.18, 0.3, 0.9)
		btn_style.border_width_left = 2
		btn_style.border_width_top = 2
		btn_style.border_width_right = 2
		btn_style.border_width_bottom = 2
		btn_style.border_color = Color(0.4, 0.75, 1.0, 1.0) if is_cur else Color(0.2, 0.3, 0.45, 0.8)
		btn_style.set_corner_radius_all(10)
		lvl_btn.add_theme_stylebox_override("normal", btn_style)
		
		var target_lvl := i
		lvl_btn.pressed.connect(func():
			_play_click_sfx()
			load_level(target_lvl)
			_close_level_select_dialog()
		)
		grid.add_child(lvl_btn)

func _open_level_select_dialog() -> void:
	if level_select_layer:
		level_select_layer.queue_free()
		level_select_layer = null
	_create_level_select_dialog()
	level_select_layer.visible = true
	var tw := create_tween()
	tw.tween_property(level_select_layer, "modulate:a", 1.0, 0.2)

func _close_level_select_dialog() -> void:
	if level_select_layer and level_select_layer.visible:
		var tw := create_tween()
		tw.tween_property(level_select_layer, "modulate:a", 0.0, 0.15)
		tw.finished.connect(func():
			if level_select_layer:
				level_select_layer.visible = false
		)
	_play_click_sfx()
	if current_level_num < ElectricLevels.get_total_levels():
		load_level(current_level_num + 1)

func _on_settings_pressed() -> void:
	_play_click_sfx()
	# Toggle sound effects / music or return to menu
	get_tree().change_scene_to_file("res://scenes/menu.tscn")

# -------------------------------------------------------------
# AUDIO PROCEDURAL SOUND GENERATOR
# -------------------------------------------------------------
func _play_click_sfx() -> void:
	if not GameState.sfx_enabled:
		return
	audio_tones_player.stream = _generate_tone(420.0, 0.05, 0.8)
	audio_tones_player.play()

func _play_bulb_sfx() -> void:
	if not GameState.sfx_enabled:
		return
	AudioManager.play_right()

func _play_victory_fanfare() -> void:
	if not GameState.sfx_enabled:
		return
	AudioManager.play_level_complete()

func _play_chord_sequence(freqs: Array) -> void:
	var total_dur := 0.18 * freqs.size() + 0.3
	var sample_rate := 22050
	var frames := int(sample_rate * total_dur)
	var data := PackedByteArray()
	data.resize(frames * 2)
	
	var note_dur_frames := int(sample_rate * 0.15)
	for i in range(frames):
		var note_idx := clampi(i / note_dur_frames, 0, freqs.size() - 1)
		var freq: float = freqs[note_idx]
		var t := float(i) / float(sample_rate)
		var note_time := float(i % note_dur_frames) / float(sample_rate)
		var env := exp(-note_time * 7.0)
		var sample := sin(TAU * freq * t) * env * 0.7
		var val := int(clampf(sample, -1.0, 1.0) * 32767.0)
		data.encode_s16(i * 2, val)
	
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = sample_rate
	wav.stereo = false
	wav.data = data
	audio_tones_player.stream = wav
	audio_tones_player.play()

func _generate_tone(freq: float, duration: float, volume: float) -> AudioStreamWAV:
	var sample_rate := 22050
	var frames := int(sample_rate * duration)
	var data := PackedByteArray()
	data.resize(frames * 2)
	
	for i in range(frames):
		var t := float(i) / float(sample_rate)
		var env := exp(-t * (1.0 / duration) * 3.5)
		var sample := sin(TAU * freq * t) * env * volume
		var val := int(clampf(sample, -1.0, 1.0) * 32767.0)
		data.encode_s16(i * 2, val)
	
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = sample_rate
	wav.stereo = false
	wav.data = data
	return wav

func _play_tone_sfx(freq: float, duration: float, volume: float) -> void:
	if not GameState.sfx_enabled:
		return
	audio_tones_player.stream = _generate_tone(freq, duration, volume)
	audio_tones_player.play()

func _play_applause_sfx() -> void:
	if not GameState.sfx_enabled:
		return
	if cached_applause_sfx == null:
		cached_applause_sfx = _generate_applause_sfx()
	if audio_applause_player == null:
		audio_applause_player = AudioStreamPlayer.new()
		audio_applause_player.volume_db = -2.0
		add_child(audio_applause_player)
	audio_applause_player.stream = cached_applause_sfx
	audio_applause_player.play()

func _generate_applause_sfx() -> AudioStreamWAV:
	var sample_rate := 22050
	var duration := 1.8
	var total_samples := int(sample_rate * duration)
	var float_buf := PackedFloat32Array()
	float_buf.resize(total_samples)
	float_buf.fill(0.0)
	
	# Generate 34 staggered clap events
	var claps: Array[Dictionary] = []
	var t := 0.05
	for c in range(34):
		t += 0.03 + (sin(c * 17.3) * 0.5 + 0.5) * 0.05
		if t > duration - 0.1:
			break
		var clap_dur := 0.035 + (sin(c * 23.7) * 0.5 + 0.5) * 0.025
		var clap_freq := 650.0 + (sin(c * 41.1) * 0.5 + 0.5) * 550.0
		var clap_vol := 0.25 + (sin(c * 13.9) * 0.5 + 0.5) * 0.35
		claps.append({"start": t, "dur": clap_dur, "freq": clap_freq, "vol": clap_vol})
		
	# Synthesize claps into buffer
	for clap in claps:
		var start_sample := int(clap["start"] * sample_rate)
		var dur_samples := int(clap["dur"] * sample_rate)
		var freq: float = clap["freq"]
		var vol: float = clap["vol"]
		
		for i in range(dur_samples):
			var idx := start_sample + i
			if idx >= total_samples:
				break
			var ct := float(i) / float(sample_rate)
			var attack := minf(1.0, ct / 0.002)
			var decay := exp(-ct * 65.0)
			var env := attack * decay
			# Fast pseudo-noise + slap tone resonance
			var noise := (fmod(sin(float(start_sample + i) * 8931.23) * 43758.5453, 1.0)) * 2.0 - 1.0
			var tone := sin(TAU * freq * ct)
			var sample := (noise * 0.7 + tone * 0.3) * env * vol
			float_buf[idx] += sample
			
	# Peak normalization
	var peak := 0.0001
	for i in range(total_samples):
		var a := absf(float_buf[i])
		if a > peak:
			peak = a
			
	var norm := 0.95 / peak if peak > 0.95 else 1.0
	var byte_data := PackedByteArray()
	byte_data.resize(total_samples * 2)
	for i in range(total_samples):
		var s := clampf(float_buf[i] * norm, -1.0, 1.0)
		var val := int(s * 32767.0)
		byte_data.encode_s16(i * 2, val)
		
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = sample_rate
	wav.stereo = false
	wav.data = byte_data
	return wav

# -------------------------------------------------------------
# RESTART TOAST NOTIFICATION
# -------------------------------------------------------------
var restart_toast: PanelContainer = null
var restart_toast_label: Label = null

func _show_restart_toast() -> void:
	if restart_toast == null:
		restart_toast = PanelContainer.new()
		restart_toast.custom_minimum_size = Vector2(280, 48)
		restart_toast.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
		restart_toast.offset_top = 100.0
		restart_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
		restart_toast.z_index = 40
		
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.04, 0.12, 0.25, 0.96)
		style.border_color = Color(0.15, 0.75, 1.0, 0.95)
		style.set_border_width_all(2)
		style.set_corner_radius_all(16)
		style.shadow_color = Color(0, 0, 0, 0.5)
		style.shadow_size = 10
		restart_toast.add_theme_stylebox_override("panel", style)
		
		restart_toast_label = Label.new()
		restart_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		restart_toast_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		restart_toast_label.add_theme_font_override("font", GAME_FONT)
		restart_toast_label.add_theme_font_size_override("font_size", 16)
		restart_toast_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.3, 1.0))
		restart_toast.add_child(restart_toast_label)
		add_child(restart_toast)
		
	restart_toast_label.text = "↺ LEVEL RESTARTED"
	restart_toast.visible = true
	restart_toast.modulate.a = 0.0
	restart_toast.scale = Vector2(0.85, 0.85)
	restart_toast.pivot_offset = Vector2(140, 24)
	
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(restart_toast, "modulate:a", 1.0, 0.18)
	tw.tween_property(restart_toast, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.chain().tween_interval(1.1)
	tw.chain().tween_property(restart_toast, "modulate:a", 0.0, 0.25)
	tw.tween_callback(func():
		if is_instance_valid(restart_toast):
			restart_toast.visible = false
	)

func _update_header_coins() -> void:
	if is_instance_valid(header_coins_label):
		header_coins_label.text = str(GameState.coins)
	if is_instance_valid(header_stars_label):
		header_stars_label.text = str(GameState.total_stars)

func _on_daily_pressed() -> void:
	_play_click_sfx()
	load_daily_challenge()

# -------------------------------------------------------------
# ENERGY SKINS STORE & COLOR CUSTOMIZATION
# -------------------------------------------------------------
const SKINS_DATA: Array[Dictionary] = [
	{
		"id": "Classic",
		"name": "CLASSIC CYAN",
		"subtitle": "Pure neon cyan luminescence & standard circuit wire",
		"color": Color(0.0, 0.88, 1.0, 1.0),
		"cost": 0
	},
	{
		"id": "SolarGold",
		"name": "SOLAR GOLD",
		"subtitle": "Radiant solar filament glow & warm golden cables",
		"color": Color(1.0, 0.86, 0.18, 1.0),
		"cost": 30
	},
	{
		"id": "PlasmaPink",
		"name": "PLASMA PINK",
		"subtitle": "High-frequency vibrant magenta plasma discharge",
		"color": Color(1.0, 0.25, 0.85, 1.0),
		"cost": 50
	},
	{
		"id": "EmeraldMatrix",
		"name": "EMERALD MATRIX",
		"subtitle": "Cybernetic jade energy flow & green phosphor light",
		"color": Color(0.2, 0.95, 0.45, 1.0),
		"cost": 75
	},
	{
		"id": "InfernoOrange",
		"name": "INFERNO ORANGE",
		"subtitle": "High-temperature incandescent blazing thermals",
		"color": Color(1.0, 0.55, 0.15, 1.0),
		"cost": 100
	},
	{
		"id": "HyperViolet",
		"name": "HYPER VIOLET",
		"subtitle": "Deep cosmic ultraviolet aura & electric purple beams",
		"color": Color(0.72, 0.35, 1.0, 1.0),
		"cost": 150
	}
]

func _on_shop_pressed() -> void:
	_play_click_sfx()
	_show_shop()

func _show_shop() -> void:
	_populate_skins_shop()
	if is_instance_valid(shop_layer):
		shop_layer.visible = true
		shop_layer.modulate.a = 0.0
		if is_instance_valid(shop_card):
			shop_card.scale = Vector2(0.85, 0.85)
			shop_card.pivot_offset = shop_card.size * 0.5
			var tw := create_tween().set_parallel(true)
			tw.tween_property(shop_layer, "modulate:a", 1.0, 0.2)
			tw.tween_property(shop_card, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _close_shop() -> void:
	_play_click_sfx()
	if is_instance_valid(shop_layer):
		var tw := create_tween()
		tw.tween_property(shop_layer, "modulate:a", 0.0, 0.18)
		await tw.finished
		shop_layer.visible = false

func _refresh_all_tiles_theme() -> void:
	for tile in grid_tiles.values():
		if is_instance_valid(tile):
			tile.queue_redraw()

func _populate_skins_shop() -> void:
	if not is_instance_valid(skins_container):
		return
		
	if is_instance_valid(shop_coins_value):
		shop_coins_value.text = str(GameState.coins)
	_update_header_coins()
	
	for child in skins_container.get_children():
		child.queue_free()
		
	var cur_theme: String = GameState.selected_theme
	var owned: Array[String] = GameState.owned_themes
	
	for s_info in SKINS_DATA:
		var skin_id: String = s_info["id"]
		var skin_name: String = s_info["name"]
		var skin_sub: String = s_info["subtitle"]
		var skin_color: Color = s_info["color"]
		var skin_cost: int = s_info["cost"]
		var is_equipped: bool = (cur_theme == skin_id)
		var is_owned: bool = owned.has(skin_id) or (skin_cost == 0)
		
		# Row Panel
		var row := PanelContainer.new()
		row.custom_minimum_size = Vector2(0, 68)
		var row_style := StyleBoxFlat.new()
		if is_equipped:
			row_style.bg_color = Color(0.08, 0.18, 0.32, 0.95)
			row_style.border_color = skin_color
			row_style.set_border_width_all(2)
		else:
			row_style.bg_color = Color(0.05, 0.10, 0.18, 0.85)
			row_style.border_color = Color(0.18, 0.28, 0.42, 0.7)
			row_style.set_border_width_all(1)
		row_style.set_corner_radius_all(12)
		row.add_theme_stylebox_override("panel", row_style)
		
		var margin := MarginContainer.new()
		margin.add_theme_constant_override("margin_left", 12)
		margin.add_theme_constant_override("margin_right", 12)
		margin.add_theme_constant_override("margin_top", 8)
		margin.add_theme_constant_override("margin_bottom", 8)
		row.add_child(margin)
		
		var hbox := HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 12)
		margin.add_child(hbox)
		
		# Glowing Color Swatch
		var swatch := Panel.new()
		swatch.custom_minimum_size = Vector2(46, 46)
		var sw_style := StyleBoxFlat.new()
		sw_style.bg_color = skin_color
		sw_style.set_corner_radius_all(23)
		sw_style.shadow_color = skin_color * Color(1, 1, 1, 0.6)
		sw_style.shadow_size = 8
		swatch.add_theme_stylebox_override("panel", sw_style)
		
		var swatch_icon := Label.new()
		swatch_icon.text = "⚡"
		swatch_icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		swatch_icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		swatch_icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		swatch_icon.add_theme_font_size_override("font_size", 18)
		swatch_icon.add_theme_color_override("font_color", Color.WHITE)
		swatch.add_child(swatch_icon)
		hbox.add_child(swatch)
		
		# Info VBox
		var info_vbox := VBoxContainer.new()
		info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		info_vbox.add_theme_constant_override("separation", 2)
		hbox.add_child(info_vbox)
		
		var name_lbl := Label.new()
		name_lbl.text = skin_name
		name_lbl.add_theme_font_override("font", GAME_FONT)
		name_lbl.add_theme_font_size_override("font_size", 15)
		name_lbl.add_theme_color_override("font_color", skin_color)
		info_vbox.add_child(name_lbl)
		
		var sub_lbl := Label.new()
		sub_lbl.text = skin_sub
		sub_lbl.add_theme_font_override("font", SUB_FONT)
		sub_lbl.add_theme_font_size_override("font_size", 11)
		sub_lbl.add_theme_color_override("font_color", Color(0.72, 0.80, 0.90, 0.85))
		info_vbox.add_child(sub_lbl)
		
		# Action Button
		var act_btn := Button.new()
		act_btn.custom_minimum_size = Vector2(104, 38)
		act_btn.add_theme_font_override("font", GAME_FONT)
		act_btn.add_theme_font_size_override("font_size", 13)
		
		var btn_style := StyleBoxFlat.new()
		btn_style.set_corner_radius_all(10)
		
		if is_equipped:
			act_btn.text = "EQUIPPED"
			act_btn.disabled = true
			btn_style.bg_color = Color(0.12, 0.45, 0.32, 0.9)
			btn_style.border_color = Color(0.3, 0.95, 0.55, 1.0)
			btn_style.set_border_width_all(2)
		elif is_owned:
			act_btn.text = "EQUIP"
			btn_style.bg_color = Color(0.15, 0.35, 0.65, 0.9)
			btn_style.border_color = Color(0.4, 0.75, 1.0, 1.0)
			btn_style.set_border_width_all(2)
			act_btn.pressed.connect(func():
				_on_equip_skin(skin_id)
			)
		else:
			act_btn.text = "🪙 %d" % skin_cost
			var can_afford := (GameState.coins >= skin_cost)
			if can_afford:
				btn_style.bg_color = Color(0.65, 0.45, 0.08, 0.95)
				btn_style.border_color = Color(1.0, 0.82, 0.25, 1.0)
				btn_style.set_border_width_all(2)
				act_btn.pressed.connect(func():
					_on_buy_skin(skin_id, skin_cost)
				)
			else:
				act_btn.disabled = true
				btn_style.bg_color = Color(0.2, 0.22, 0.28, 0.7)
				btn_style.border_color = Color(0.35, 0.38, 0.45, 0.6)
				btn_style.set_border_width_all(1)
				
		act_btn.add_theme_stylebox_override("normal", btn_style)
		hbox.add_child(act_btn)
		
		skins_container.add_child(row)

func _on_buy_skin(skin_id: String, cost: int) -> void:
	if GameState.buy_theme(skin_id, cost):
		_play_tone_sfx(880.0, 0.15, 0.8)
		get_tree().create_timer(0.12).timeout.connect(func():
			_play_tone_sfx(1174.66, 0.25, 0.9)
		)
		_refresh_all_tiles_theme()
		_populate_skins_shop()

func _on_equip_skin(skin_id: String) -> void:
	if GameState.equip_theme(skin_id):
		_play_click_sfx()
		_refresh_all_tiles_theme()
		_populate_skins_shop()

# -------------------------------------------------------------
# SHOP TABS & COIN PACKS
# -------------------------------------------------------------
var current_shop_tab: int = 0

func _select_shop_tab(tab_idx: int) -> void:
	current_shop_tab = tab_idx
	_play_click_sfx()
	if is_instance_valid(skins_container) and is_instance_valid(coin_packs_container):
		skins_container.visible = (tab_idx == 0)
		coin_packs_container.visible = (tab_idx == 1)
	if is_instance_valid(tab_skins_btn) and is_instance_valid(tab_coins_btn):
		tab_skins_btn.modulate = Color(1.0, 1.0, 1.0, 1.0) if tab_idx == 0 else Color(0.65, 0.75, 0.85, 0.7)
		tab_coins_btn.modulate = Color(1.0, 1.0, 1.0, 1.0) if tab_idx == 1 else Color(0.65, 0.75, 0.85, 0.7)
	if tab_idx == 0:
		_populate_skins_shop()
	else:
		_populate_coin_packs()

func _populate_coin_packs() -> void:
	if not is_instance_valid(coin_packs_container):
		return
	for child in coin_packs_container.get_children():
		child.queue_free()
		
	var packs := [
		{"id": "coins_500", "name": "Pouch of Energy Coins", "coins": 500, "price": "$0.99", "icon": "🪙"},
		{"id": "coins_1200", "name": "Starter Power Bundle", "coins": 1200, "price": "$1.99", "icon": "⚡"},
		{"id": "coins_3000", "name": "Vault of Supercharges", "coins": 3000, "price": "$4.99", "icon": "💎"}
	]
	
	for pack in packs:
		var row := PanelContainer.new()
		row.custom_minimum_size = Vector2(0, 68)
		var row_style := StyleBoxFlat.new()
		row_style.bg_color = Color(0.06, 0.12, 0.22, 0.9)
		row_style.border_color = Color(0.2, 0.75, 0.95, 0.7)
		row_style.set_border_width_all(1)
		row_style.set_corner_radius_all(12)
		row.add_theme_stylebox_override("panel", row_style)
		
		var margin := MarginContainer.new()
		margin.add_theme_constant_override("margin_left", 12)
		margin.add_theme_constant_override("margin_right", 12)
		margin.add_theme_constant_override("margin_top", 8)
		margin.add_theme_constant_override("margin_bottom", 8)
		row.add_child(margin)
		
		var hbox := HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 12)
		margin.add_child(hbox)
		
		var icon_lbl := Label.new()
		icon_lbl.text = pack["icon"]
		icon_lbl.custom_minimum_size = Vector2(44, 44)
		icon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		icon_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		icon_lbl.add_theme_font_size_override("font_size", 24)
		hbox.add_child(icon_lbl)
		
		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.alignment = BoxContainer.ALIGNMENT_CENTER
		hbox.add_child(info)
		
		var title := Label.new()
		title.text = pack["name"]
		title.add_theme_font_override("font", GAME_FONT)
		title.add_theme_font_size_override("font_size", 15)
		title.add_theme_color_override("font_color", Color(1.0, 0.88, 0.35, 1.0))
		info.add_child(title)
		
		var sub := Label.new()
		sub.text = "+%d Coins" % int(pack["coins"])
		sub.add_theme_font_override("font", SUB_FONT)
		sub.add_theme_font_size_override("font_size", 12)
		sub.add_theme_color_override("font_color", Color(0.75, 0.88, 1.0, 0.9))
		info.add_child(sub)
		
		var buy_btn := Button.new()
		buy_btn.text = pack["price"]
		buy_btn.custom_minimum_size = Vector2(104, 38)
		buy_btn.add_theme_font_override("font", GAME_FONT)
		buy_btn.add_theme_font_size_override("font_size", 13)
		var btn_style := StyleBoxFlat.new()
		btn_style.bg_color = Color(0.65, 0.45, 0.08, 0.95)
		btn_style.border_color = Color(1.0, 0.85, 0.3, 1.0)
		btn_style.set_border_width_all(2)
		btn_style.set_corner_radius_all(10)
		buy_btn.add_theme_stylebox_override("normal", btn_style)
		
		var coins_to_add: int = int(pack["coins"])
		buy_btn.pressed.connect(func():
			GameState.coins += coins_to_add
			GameState.save_progress()
			_play_tone_sfx(900.0, 0.15, 0.8)
			_update_header_coins()
			if is_instance_valid(shop_coins_value):
				shop_coins_value.text = str(GameState.coins)
		)
		hbox.add_child(buy_btn)
		coin_packs_container.add_child(row)

# -------------------------------------------------------------
# GLOBAL LEADERBOARD SCREEN
# -------------------------------------------------------------
func _on_leaderboard_pressed() -> void:
	_play_click_sfx()
	_show_leaderboard()

func _show_leaderboard() -> void:
	_populate_leaderboard()
	if is_instance_valid(leaderboard_layer):
		leaderboard_layer.visible = true
		leaderboard_layer.modulate.a = 0.0
		if is_instance_valid(leaderboard_card):
			leaderboard_card.scale = Vector2(0.85, 0.85)
			leaderboard_card.pivot_offset = leaderboard_card.size * 0.5
			var tw := create_tween().set_parallel(true)
			tw.tween_property(leaderboard_layer, "modulate:a", 1.0, 0.2)
			tw.tween_property(leaderboard_card, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _close_leaderboard() -> void:
	_play_click_sfx()
	if is_instance_valid(leaderboard_layer):
		var tw := create_tween()
		tw.tween_property(leaderboard_layer, "modulate:a", 0.0, 0.18)
		await tw.finished
		leaderboard_layer.visible = false

func _on_play_games_btn_pressed() -> void:
	_play_click_sfx()
	if PlayGamesManager.is_signed_in:
		PlayGamesManager.show_all_leaderboards()
	else:
		PlayGamesManager.sign_in()

func _populate_leaderboard() -> void:
	if not is_instance_valid(leaderboard_rows_container):
		return
		
	if is_instance_valid(user_stats_label):
		user_stats_label.text = "Lvl %d • ⭐ %d" % [GameState.highest_level, GameState.total_stars]
		
	if is_instance_valid(play_games_btn):
		if PlayGamesManager.is_signed_in:
			play_games_btn.text = "🌐 VIEW GOOGLE PLAY FULL LEADERBOARDS"
		else:
			play_games_btn.text = "🎮 SIGN IN WITH GOOGLE PLAY"
			
	for child in leaderboard_rows_container.get_children():
		child.queue_free()
		
	var player_display_name := PlayGamesManager.player_name if PlayGamesManager.is_signed_in else "You (Player)"
	
	var board_data := [
		{"rank": 1, "name": "Nikola Tesla", "level": 9999, "stars": 29997, "is_user": false, "medal": "🥇"},
		{"rank": 2, "name": "Thomas Edison", "level": 8420, "stars": 25260, "is_user": false, "medal": "🥈"},
		{"rank": 3, "name": "Michael Faraday", "level": 6180, "stars": 18540, "is_user": false, "medal": "🥉"},
		{"rank": 4, "name": "James Maxwell", "level": 4520, "stars": 13560, "is_user": false, "medal": "#4"},
		{"rank": 5, "name": "VoltRunner", "level": 2310, "stars": 6930, "is_user": false, "medal": "#5"},
		{"rank": 6, "name": player_display_name, "level": GameState.highest_level, "stars": GameState.total_stars, "is_user": true, "medal": "#6"},
		{"rank": 7, "name": "NeonSpark", "level": 1420, "stars": 4260, "is_user": false, "medal": "#7"}
	]
	
	for row_data in board_data:
		var row := PanelContainer.new()
		row.custom_minimum_size = Vector2(0, 48)
		var row_style := StyleBoxFlat.new()
		if row_data["is_user"]:
			row_style.bg_color = Color(0.12, 0.28, 0.48, 0.95)
			row_style.border_color = Color(0.0, 0.88, 1.0, 1.0)
			row_style.set_border_width_all(2)
		else:
			row_style.bg_color = Color(0.05, 0.10, 0.18, 0.85)
			row_style.border_color = Color(0.18, 0.28, 0.42, 0.6)
			row_style.set_border_width_all(1)
		row_style.set_corner_radius_all(10)
		row.add_theme_stylebox_override("panel", row_style)
		
		var margin := MarginContainer.new()
		margin.add_theme_constant_override("margin_left", 12)
		margin.add_theme_constant_override("margin_right", 12)
		margin.add_theme_constant_override("margin_top", 4)
		margin.add_theme_constant_override("margin_bottom", 4)
		row.add_child(margin)
		
		var hbox := HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 10)
		margin.add_child(hbox)
		
		var rank_lbl := Label.new()
		rank_lbl.text = str(row_data["medal"])
		rank_lbl.custom_minimum_size = Vector2(36, 0)
		rank_lbl.add_theme_font_override("font", GAME_FONT)
		rank_lbl.add_theme_font_size_override("font_size", 14)
		rank_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.25, 1.0) if int(row_data["rank"]) <= 3 else Color.WHITE)
		hbox.add_child(rank_lbl)
		
		var name_lbl := Label.new()
		name_lbl.text = str(row_data["name"])
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_lbl.add_theme_font_override("font", GAME_FONT if row_data["is_user"] else SUB_FONT)
		name_lbl.add_theme_font_size_override("font_size", 14)
		name_lbl.add_theme_color_override("font_color", Color(0.2, 0.95, 0.85, 1.0) if row_data["is_user"] else Color.WHITE)
		hbox.add_child(name_lbl)
		
		var score_lbl := Label.new()
		score_lbl.text = "Lvl %d · ⭐ %d" % [int(row_data["level"]), int(row_data["stars"])]
		score_lbl.add_theme_font_override("font", GAME_FONT)
		score_lbl.add_theme_font_size_override("font_size", 13)
		score_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.35, 1.0))
		hbox.add_child(score_lbl)
		
		leaderboard_rows_container.add_child(row)

# -------------------------------------------------------------
# LEVEL NAVIGATOR (1, 2, 3...) & BACK BUTTON
# -------------------------------------------------------------
func _on_back_pressed() -> void:
	_play_click_sfx()
	AdManager.hide_banner_top()
	GameState.save_progress()
	get_tree().change_scene_to_file("res://scenes/menu.tscn")

func _update_level_nav() -> void:
	_update_hint_display()
	_update_header_coins()
	if is_daily_mode:
		if is_instance_valid(prev_level_pill_btn):
			prev_level_pill_btn.visible = false
		if is_instance_valid(next_level_pill_btn):
			next_level_pill_btn.visible = false
		if is_instance_valid(header_level_label):
			header_level_label.text = "DAILY"
		return
		
	if is_instance_valid(prev_level_pill_btn):
		prev_level_pill_btn.visible = true
		var prev_idx := current_level_num - 1
		if prev_idx >= 1:
			prev_level_pill_btn.text = "< %d" % prev_idx
			prev_level_pill_btn.disabled = false
		else:
			prev_level_pill_btn.text = "<"
			prev_level_pill_btn.disabled = true
			
	if is_instance_valid(header_level_label):
		header_level_label.text = "Level %d" % current_level_num
		
	if is_instance_valid(next_level_pill_btn):
		next_level_pill_btn.visible = true
		var next_idx := current_level_num + 1
		if next_idx <= ElectricLevels.get_total_levels():
			next_level_pill_btn.text = "%d >" % next_idx
			next_level_pill_btn.disabled = false
		else:
			next_level_pill_btn.text = ">"
			next_level_pill_btn.disabled = true

func _update_hint_display() -> void:
	var h_count: int = GameState.hints
	if is_instance_valid(hint_btn):
		hint_btn.text = "HINT: %d" % h_count
	if is_instance_valid(bottom_hint_btn):
		bottom_hint_btn.text = "HINT: %d" % h_count

# -------------------------------------------------------------
# HINT SOLVER SYSTEM
# -------------------------------------------------------------
func _on_hint_pressed() -> void:
	_play_click_sfx()
	if is_level_completed:
		return
		
	if GameState.hints <= 0:
		_show_hint_depleted_dialog()
		return
		
	var target_tile: Control = null
	var correct_rot: int = 0
	
	# 1. Check rotatable tiles with a known target_rot
	for pos in grid_tiles.keys():
		var tile: Control = grid_tiles[pos]
		if tile.is_rotatable and tile.tile_type != ElectricEnums.TileType.EMPTY:
			var t_rot: int = tile.target_rot
			if t_rot != -1:
				if tile.tile_type in [ElectricEnums.TileType.WIRE_STRAIGHT, ElectricEnums.TileType.RESISTOR, ElectricEnums.TileType.CAPACITOR]:
					if (tile.current_rotation_step % 2) != (t_rot % 2):
						target_tile = tile
						correct_rot = t_rot
						break
				elif tile.current_rotation_step != t_rot:
					target_tile = tile
					correct_rot = t_rot
					break
					
	# 2. Fallback: select first unpowered rotatable tile
	if target_tile == null:
		for pos in grid_tiles.keys():
			var tile: Control = grid_tiles[pos]
			if tile.is_rotatable and not tile.is_powered:
				target_tile = tile
				correct_rot = (tile.current_rotation_step + 1) % 4
				break
				
	if target_tile != null:
		GameState.use_hint()
		_update_hint_display()
		if AudioManager:
			AudioManager.play_hint()
		target_tile.apply_hint_rotation(correct_rot)
		get_tree().create_timer(0.28).timeout.connect(func():
			_evaluate_circuit(true)
		)

var hint_dialog_layer: Control = null

func _show_hint_depleted_dialog() -> void:
	if hint_dialog_layer != null:
		hint_dialog_layer.visible = true
		return
		
	hint_dialog_layer = Control.new()
	hint_dialog_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hint_dialog_layer.z_index = 60
	add_child(hint_dialog_layer)
	
	var backdrop := ColorRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.01, 0.03, 0.08, 0.85)
	backdrop.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed:
			hint_dialog_layer.visible = false
	)
	hint_dialog_layer.add_child(backdrop)
	
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hint_dialog_layer.add_child(center)
	
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(420, 260)
	var card_style := StyleBoxFlat.new()
	card_style.bg_color = Color(0.08, 0.14, 0.24, 0.98)
	card_style.border_color = Color(1.0, 0.85, 0.25, 1.0)
	card_style.set_border_width_all(2)
	card_style.set_corner_radius_all(18)
	card.add_theme_stylebox_override("panel", card_style)
	center.add_child(card)
	
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_bottom", 18)
	card.add_child(margin)
	
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	margin.add_child(vbox)
	
	var title := Label.new()
	title.text = "💡 NEED MORE HINTS?"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", GAME_FONT)
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(1.0, 0.88, 0.35, 1.0))
	vbox.add_child(title)
	
	var desc := Label.new()
	desc.text = "You are out of hints! Exchange 15 coins for +3 hints."
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.add_theme_font_override("font", SUB_FONT)
	desc.add_theme_font_size_override("font_size", 13)
	desc.add_theme_color_override("font_color", Color(0.8, 0.9, 1.0, 0.9))
	vbox.add_child(desc)
	
	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 10)
	vbox.add_child(btn_row)
	
	var coin_btn := Button.new()
	coin_btn.text = "🪙 15 COINS (+3)"
	coin_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	coin_btn.custom_minimum_size = Vector2(0, 44)
	coin_btn.add_theme_font_override("font", GAME_FONT)
	coin_btn.add_theme_font_size_override("font_size", 14)
	var coin_style := StyleBoxFlat.new()
	coin_style.bg_color = Color(0.65, 0.45, 0.08, 0.95)
	coin_style.border_color = Color(1.0, 0.85, 0.3, 1.0)
	coin_style.set_border_width_all(2)
	coin_style.set_corner_radius_all(10)
	coin_btn.add_theme_stylebox_override("normal", coin_style)
	coin_btn.pressed.connect(func():
		if GameState.coins >= 15:
			GameState.coins -= 15
			GameState.add_hints(3)
			_update_header_coins()
			_update_hint_display()
			hint_dialog_layer.visible = false
		else:
			_show_shop()
			hint_dialog_layer.visible = false
	)
	btn_row.add_child(coin_btn)
	
	var close_btn := Button.new()
	close_btn.text = "CANCEL"
	close_btn.custom_minimum_size = Vector2(100, 36)
	close_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close_btn.add_theme_font_override("font", GAME_FONT)
	close_btn.pressed.connect(func(): hint_dialog_layer.visible = false)
	vbox.add_child(close_btn)
