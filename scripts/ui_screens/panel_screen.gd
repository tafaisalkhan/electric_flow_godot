extends Control

signal close_requested
signal setting_changed(id: String, enabled: bool)
signal settings_action_requested(id: String)
signal shop_action_requested(id: String)
signal purchase_requested(id: String)
signal mission_claim_requested(id: String)
signal leaderboard_signin_requested
signal leaderboard_full_requested
signal privacy_requested

@export_enum("settings", "shop", "store", "missions", "leaderboard") var screen_kind := "settings"
@export var item_scene: PackedScene
@export var active_tab_style: StyleBox
@export var inactive_tab_style: StyleBox
@export var compact_leaderboard_height := 450.0
@export var expanded_leaderboard_height := 820.0
@export var leaderboard_with_user_height := 940.0

var _data: Dictionary = {}
var _shop_category := ""

func _ready() -> void:
	%BackButton.pressed.connect(func(): close_requested.emit())
	%AboutButton.pressed.connect(func(): privacy_requested.emit())
	%SignInButton.pressed.connect(func(): leaderboard_signin_requested.emit())
	var full_button := get_node_or_null("%FullLeaderboardButton") as Button
	if full_button != null:
		full_button.pressed.connect(func(): leaderboard_full_requested.emit())
	%Tab1.pressed.connect(_select_tab.bind(0))
	%Tab2.pressed.connect(_select_tab.bind(1))
	%Tab3.pressed.connect(_select_tab.bind(2))
	%Tabs.visible = screen_kind == "shop"
	%AboutButton.visible = screen_kind == "settings"
	%BalanceLabel.visible = screen_kind in ["shop", "store"]
	%SignInBox.visible = false
	%Items.columns = 3 if screen_kind == "shop" else 1

func set_data(data: Dictionary) -> void:
	_data = data
	if is_node_ready():
		_render()

func _render() -> void:
	if not is_node_ready() or item_scene == null:
		return
	%BalanceLabel.text = "●  %d" % int(_data.get("coins", 0))
	for child in %Items.get_children():
		child.queue_free()
	%Items.visible = true
	%SignInBox.visible = false
	match screen_kind:
		"settings":
			for option in _data.get("settings_options", []):
				var row := item_scene.instantiate()
				%Items.add_child(row)
				row.set_data(option)
				row.changed.connect(func(id: String, enabled: bool): setting_changed.emit(id, enabled))
				row.activated.connect(func(id: String): settings_action_requested.emit(id))
			for action in _data.get("settings_actions", []):
				var row := item_scene.instantiate()
				%Items.add_child(row)
				var action_data: Dictionary = action.duplicate()
				action_data["action"] = true
				row.set_data(action_data)
				row.activated.connect(func(id: String): settings_action_requested.emit(id))
		"shop":
			_render_shop()
		"store":
			for product in _data.get("store_products", []):
				var row := item_scene.instantiate()
				%Items.add_child(row)
				row.set_data(product)
				row.activated.connect(func(id: String): purchase_requested.emit(id))
		"missions":
			for mission in _data.get("missions", []):
				var row := item_scene.instantiate()
				%Items.add_child(row)
				row.set_data(mission)
				row.activated.connect(func(id: String): mission_claim_requested.emit(id))
		"leaderboard":
			var signed_in := bool(_data.get("leaderboard_signed_in", false))
			%FullLeaderboardButton.disabled = not signed_in
			%FullLeaderboardButton.modulate = Color.WHITE if signed_in else Color(1, 1, 1, 0.55)
			var user_data: Dictionary = _data.get("leaderboard_user", {})
			%YourRankLabel.visible = false
			%YourRankSlot.visible = false
			for old_row in %YourRankSlot.get_children():
				old_row.queue_free()
			%BoardHeaders.visible = signed_in
			$Center/FrameBox/Panel/Layout/Scroll.visible = signed_in
			var frame_box := $Center/FrameBox as Control
			frame_box.custom_minimum_size.y = (leaderboard_with_user_height if not user_data.is_empty() else expanded_leaderboard_height) if signed_in else compact_leaderboard_height
			if not signed_in:
				%Items.visible = false
				%SignInBox.visible = true
			else:
				var rank := 1
				for player in _data.get("leaderboard_rows", []):
					var row := item_scene.instantiate()
					%Items.add_child(row)
					row.set_data(rank, player)
					rank += 1
				if not user_data.is_empty():
					var user_row := item_scene.instantiate()
					%YourRankSlot.add_child(user_row)
					var display_data: Dictionary = user_data.duplicate()
					display_data["is_user"] = true
					user_row.set_data(int(display_data.get("rank", rank)), display_data)
					%YourRankLabel.visible = true
					%YourRankSlot.visible = true

func _render_shop() -> void:
	var categories: Array[String] = []
	for item in _data.get("shop_items", []):
		var category := str(item.get("category", "Themes"))
		if not categories.has(category):
			categories.append(category)
	if categories.is_empty():
		categories.append("Themes")
	if not categories.has(_shop_category):
		_shop_category = categories[0]
	for index in range(3):
		var tab: Button = [%Tab1, %Tab2, %Tab3][index]
		tab.visible = index < categories.size()
		if tab.visible:
			tab.text = categories[index].to_upper()
			var active := categories[index] == _shop_category
			tab.set_pressed_no_signal(active)
			tab.add_theme_color_override("font_color", Color.WHITE if active else Color("#22364a"))
			tab.add_theme_color_override("font_pressed_color", Color.WHITE if active else Color("#22364a"))
			if active_tab_style != null and inactive_tab_style != null:
				var style := active_tab_style if active else inactive_tab_style
				tab.add_theme_stylebox_override("normal", style)
				tab.add_theme_stylebox_override("pressed", style)
	for item in _data.get("shop_items", []):
		if str(item.get("category", "Themes")) != _shop_category:
			continue
		var row := item_scene.instantiate()
		%Items.add_child(row)
		row.set_data(item)
		row.activated.connect(func(id: String): shop_action_requested.emit(id))

func _select_tab(index: int) -> void:
	var categories: Array[String] = []
	for item in _data.get("shop_items", []):
		var category := str(item.get("category", "Themes"))
		if not categories.has(category):
			categories.append(category)
	if index >= categories.size():
		return
	_shop_category = categories[index]
	_render()
