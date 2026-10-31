extends Control

const PrivacyDialogScene = preload("res://scenes/privacy_dialog.tscn")
const Palette = preload("res://scripts/ui_palette.gd")
const GAME_FONT: Font = preload("res://assets/fonts/LuckiestGuy-Regular.ttf")
const BODY_FONT: Font = preload("res://assets/fonts/Fredoka-Variable.ttf")

@onready var settings_panel: PanelContainer = $Margin/VBox/Panel
@onready var back_button: Button = $Margin/VBox/Header/BackButton
@onready var music_toggle: CheckButton = $Margin/VBox/Panel/Scroll/Content/MusicToggle
@onready var sfx_toggle: CheckButton = $Margin/VBox/Panel/Scroll/Content/SfxToggle
@onready var notification_toggle: CheckButton = $Margin/VBox/Panel/Scroll/Content/NotificationToggle
@onready var privacy_toggle: CheckButton = $Margin/VBox/Panel/Scroll/Content/PrivacyToggle
@onready var remove_ads_button: Button = $Margin/VBox/Panel/Scroll/Content/RemoveAdsButton
@onready var purchase_status: Label = $Margin/VBox/Panel/Scroll/Content/PurchaseStatus
@onready var restore_purchases_button: Button = get_node_or_null("Margin/VBox/Panel/Scroll/Content/RestorePurchasesButton")

func _ready() -> void:
	_apply_safe_area()
	get_viewport().size_changed.connect(_apply_safe_area)
	Palette.apply_background($Background, GameState.selected_theme)
	_apply_popup_style()
	music_toggle.button_pressed = GameState.music_enabled
	sfx_toggle.button_pressed = GameState.sfx_enabled
	notification_toggle.button_pressed = GameState.daily_notifications
	privacy_toggle.button_pressed = GameState.show_privacy_on_start
	_update_purchase_status()
	back_button.pressed.connect(_go_back)
	music_toggle.toggled.connect(_on_music_toggled)
	sfx_toggle.toggled.connect(_on_sfx_toggled)
	notification_toggle.toggled.connect(_on_notifications_toggled)
	privacy_toggle.toggled.connect(_on_privacy_toggled)
	remove_ads_button.pressed.connect(_on_remove_ads_pressed)
	if restore_purchases_button:
		restore_purchases_button.pressed.connect(_on_restore_purchases_pressed)
	if IAPManager:
		IAPManager.purchase_succeeded.connect(_on_purchase_succeeded)
		IAPManager.purchase_failed.connect(_on_purchase_failed)
		IAPManager.purchase_restored.connect(_on_purchase_restored)
		IAPManager.ads_removed_changed.connect(func(_rem: bool): _update_purchase_status())
	_setup_cloud_save_ui()

func _apply_popup_style() -> void:
	var title_node = get_node_or_null("Margin/VBox/Header/Title")
	if title_node:
		title_node.add_theme_font_override("font", GAME_FONT)
	if back_button:
		back_button.add_theme_font_override("font", GAME_FONT)
	if remove_ads_button:
		remove_ads_button.add_theme_font_override("font", GAME_FONT)
	if purchase_status:
		purchase_status.add_theme_font_override("font", BODY_FONT)
	for toggle in [music_toggle, sfx_toggle, notification_toggle, privacy_toggle]:
		if toggle:
			toggle.add_theme_font_override("font", BODY_FONT)
			toggle.add_theme_color_override("font_color", Color.BLACK)
			toggle.add_theme_color_override("font_hover_color", Color("#222222"))
			toggle.add_theme_color_override("font_pressed_color", Color.BLACK)
			toggle.add_theme_stylebox_override("normal", _button_style(Color("#fff8d9"), Color("#d7b348")))
			toggle.add_theme_stylebox_override("hover", _button_style(Color("#fffdf0"), Color("#f0c94d")))
			toggle.add_theme_stylebox_override("pressed", _pressed_button_style(Color("#f5edc8"), Color("#14865f")))
			toggle.add_theme_constant_override("outline_size", 1)

	remove_ads_button.add_theme_stylebox_override("normal", _button_style(Color("#ff8a3d"), Color("#b94716")))
	remove_ads_button.add_theme_stylebox_override("hover", _button_style(Color("#ffa14f"), Color("#b94716")))
	remove_ads_button.add_theme_stylebox_override("pressed", _pressed_button_style(Color("#df6f2c"), Color("#8f3110")))
	remove_ads_button.add_theme_color_override("font_color", Color.WHITE)
	if restore_purchases_button:
		restore_purchases_button.add_theme_font_override("font", BODY_FONT)
		restore_purchases_button.add_theme_stylebox_override("normal", _button_style(Color("#205f96"), Color("#0f385c")))
		restore_purchases_button.add_theme_stylebox_override("hover", _button_style(Color("#2c77b8"), Color("#0f385c")))
		restore_purchases_button.add_theme_stylebox_override("pressed", _pressed_button_style(Color("#15456f"), Color("#0a253d")))
		restore_purchases_button.add_theme_color_override("font_color", Color.WHITE)

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color("#fff1b8")
	panel_style.border_color = Color("#14865f")
	panel_style.set_border_width_all(4)
	panel_style.set_corner_radius_all(24)
	panel_style.content_margin_left = 18
	panel_style.content_margin_right = 18
	panel_style.content_margin_top = 16
	panel_style.content_margin_bottom = 16
	panel_style.shadow_color = Color(0.02, 0.08, 0.05, 0.65)
	panel_style.shadow_size = 18
	panel_style.shadow_offset = Vector2(0, 9)
	settings_panel.add_theme_stylebox_override("panel", panel_style)
	back_button.add_theme_stylebox_override("normal", _button_style(Color("#e94f45"), Color("#8f211d")))
	back_button.add_theme_stylebox_override("hover", _button_style(Color("#ff665b"), Color("#8f211d")))
	back_button.add_theme_stylebox_override("pressed", _pressed_button_style(Color("#cc3932"), Color("#701613")))
	back_button.add_theme_color_override("font_color", Color.WHITE)
	back_button.add_theme_font_size_override("font_size", 28)
	settings_panel.modulate.a = 0.0
	settings_panel.scale = Vector2(0.92, 0.92)
	settings_panel.pivot_offset = settings_panel.size * 0.5
	var tween := create_tween().set_parallel(true)
	tween.tween_property(settings_panel, "modulate:a", 1.0, 0.22)
	tween.tween_property(settings_panel, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _button_style(fill: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(5)
	style.set_corner_radius_all(20)
	style.shadow_color = Color(0.02, 0.08, 0.05, 0.55)
	style.shadow_size = 8
	style.shadow_offset = Vector2(0, 6)
	return style

func _pressed_button_style(fill: Color, border: Color) -> StyleBoxFlat:
	var style := _button_style(fill, border)
	style.shadow_size = 3
	style.shadow_offset = Vector2(0, 2)
	return style

func _go_back() -> void:
	if back_button.disabled:
		return
	back_button.disabled = true
	GameState.save_progress()
	get_tree().call_deferred("change_scene_to_file", "res://scenes/menu.tscn")

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_go_back()

func _on_music_toggled(enabled: bool) -> void:
	GameState.music_enabled = enabled
	AudioManager.set_music_enabled(enabled)
	GameState.save_progress()

func _on_sfx_toggled(enabled: bool) -> void:
	GameState.sfx_enabled = enabled
	GameState.save_progress()

func _on_notifications_toggled(enabled: bool) -> void:
	GameState.daily_notifications = enabled
	GameState.save_progress()
	if enabled and OS.get_name() == "Android":
		OS.request_permissions()

func _on_privacy_toggled(enabled: bool) -> void:
	GameState.show_privacy_on_start = enabled
	GameState.save_progress()
	if enabled:
		var dialog := PrivacyDialogScene.instantiate()
		add_child(dialog)

func _on_remove_ads_pressed() -> void:
	if GameState.ads_removed:
		return
	purchase_status.text = "Contacting store..."
	if IAPManager:
		IAPManager.purchase_product("remove_ads")
	else:
		GameState.ads_removed = true
		GameState.save_progress()
		if AdManager:
			AdManager.remove_all_ads()
		_update_purchase_status()

func _on_restore_purchases_pressed() -> void:
	if GameState.ads_removed:
		purchase_status.text = "✓ Ads are already removed on this device!"
		return
	purchase_status.text = "Checking store for past purchases..."
	if IAPManager:
		IAPManager.restore_purchases()
	await get_tree().create_timer(1.2).timeout
	if GameState.ads_removed:
		_update_purchase_status()
	else:
		purchase_status.text = "No previous remove_ads purchase found."

func _on_purchase_succeeded(product_id: String) -> void:
	if product_id == "remove_ads":
		_update_purchase_status()
		AudioManager.play_coin()

func _on_purchase_failed(_product_id: String, reason: String) -> void:
	purchase_status.text = "Purchase cancelled or failed: " + reason

func _on_purchase_restored(product_id: String) -> void:
	if product_id == "remove_ads":
		_update_purchase_status()
		AudioManager.play_coin()

func _update_purchase_status() -> void:
	if GameState.ads_removed:
		remove_ads_button.text = "✓ ADS REMOVED"
		remove_ads_button.disabled = true
		remove_ads_button.add_theme_stylebox_override("disabled", _button_style(Color("#1d8a64"), Color("#0e4b36")))
		remove_ads_button.add_theme_color_override("font_disabled_color", Color("#d5f7ea"))
		purchase_status.text = "✓ Ads permanently removed! Thank you for supporting Electric Flow!"
		purchase_status.add_theme_color_override("font_color", Color("#0e724a"))
		if restore_purchases_button:
			restore_purchases_button.visible = false
	else:
		remove_ads_button.text = "🚫 REMOVE ADS • $4.99"
		remove_ads_button.disabled = false
		purchase_status.text = "One-time purchase • Removes all banner & interstitial ads"
		purchase_status.add_theme_color_override("font_color", Color(0.34, 0.3, 0.24, 1))
		if restore_purchases_button:
			restore_purchases_button.visible = true

var cloud_button: Button
var cloud_status_label: Label

func _setup_cloud_save_ui() -> void:
	var content := $Margin/VBox/Panel/Scroll/Content
	if not content:
		return
	cloud_button = Button.new()
	cloud_button.custom_minimum_size = Vector2(0, 64)
	cloud_button.text = "☁ Google Play Cloud Save (Sync)"
	cloud_button.add_theme_font_override("font", GAME_FONT)
	cloud_button.add_theme_stylebox_override("normal", _button_style(Color("#2b74c9"), Color("#12488a")))
	cloud_button.add_theme_stylebox_override("hover", _button_style(Color("#3d8be8"), Color("#12488a")))
	cloud_button.add_theme_stylebox_override("pressed", _pressed_button_style(Color("#1d5294"), Color("#0c305c")))
	cloud_button.add_theme_color_override("font_color", Color.WHITE)
	cloud_button.pressed.connect(_on_cloud_sync_pressed)
	content.add_child(cloud_button)
	
	cloud_status_label = Label.new()
	cloud_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cloud_status_label.add_theme_font_override("font", BODY_FONT)
	content.add_child(cloud_status_label)
	_update_cloud_status()
	
	PlayGamesManager.sign_in_status_changed.connect(func(_signed_in: bool): _update_cloud_status())
	PlayGamesManager.cloud_load_completed.connect(func(_ok: bool, _merged: bool): _update_cloud_status())

func _update_cloud_status() -> void:
	if not is_instance_valid(cloud_status_label):
		return
	if PlayGamesManager.is_signed_in:
		cloud_status_label.text = "✓ Cloud Save Active: %s (Auto-Syncing)" % PlayGamesManager.player_name
		cloud_status_label.add_theme_color_override("font_color", Color("#117a42"))
		if is_instance_valid(cloud_button):
			cloud_button.text = "☁ Sync Cloud Save Now"
	else:
		cloud_status_label.text = "Cloud Save Offline - Tap to Connect"
		cloud_status_label.add_theme_color_override("font_color", Color("#7a4211"))
		if is_instance_valid(cloud_button):
			cloud_button.text = "☁ Connect Google Play Games"

func _on_cloud_sync_pressed() -> void:
	if not PlayGamesManager.is_signed_in:
		PlayGamesManager.sign_in()
	else:
		cloud_status_label.text = "Syncing with Google Play Cloud..."
		PlayGamesManager.load_from_cloud()
		PlayGamesManager.save_to_cloud()

func _apply_safe_area() -> void:
	var safe_top := 0.0
	if DisplayServer.has_method("get_display_safe_area"):
		var safe_rect := DisplayServer.get_display_safe_area()
		var window_size := DisplayServer.window_get_size()
		if window_size.y > 0:
			var viewport_size := Vector2(get_viewport().get_visible_rect().size)
			var scale_factor := viewport_size.y / float(window_size.y)
			safe_top = float(safe_rect.position.y) * scale_factor

	var is_mobile := OS.has_feature("mobile") or OS.get_name() == "Android" or OS.get_name() == "iOS"
	var min_top := 44.0 if is_mobile else 26.0
	var top_inset := maxf(safe_top + (6.0 if safe_top > 0.0 else 0.0), min_top)
	var margin_node: MarginContainer = get_node_or_null("Margin")
	if is_instance_valid(margin_node):
		margin_node.offset_top = top_inset
