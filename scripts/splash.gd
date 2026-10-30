extends Control

@onready var logo: Control = $Center/LogoPanel
@onready var icon_rect: TextureRect = $Center/LogoPanel/VBox/Icon
@onready var title: Label = $Center/LogoPanel/VBox/Title
@onready var subtitle: Label = $Center/LogoPanel/VBox/Subtitle
@onready var progress: ProgressBar = $Bottom/Loader/ProgressBar
@onready var loading_label: Label = $Bottom/Loader/LoadingLabel

var _has_transitioned: bool = false

func _ready() -> void:
	_style_loader()
	logo.modulate.a = 0.0
	logo.scale = Vector2(0.8, 0.8)
	logo.pivot_offset = Vector2(200, 240)
	progress.value = 0.0

	# Smooth entrance animation
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(logo, "modulate:a", 1.0, 0.45)
	tween.tween_property(logo, "scale", Vector2.ONE, 0.65).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(progress, "value", 100.0, 1.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	# Icon subtle continuous breathing scale
	var icon_pulse := create_tween().set_loops()
	icon_pulse.tween_property(icon_rect, "scale", Vector2(1.04, 1.04), 0.8).set_trans(Tween.TRANS_SINE)
	icon_pulse.tween_property(icon_rect, "scale", Vector2.ONE, 0.8).set_trans(Tween.TRANS_SINE)
	icon_rect.pivot_offset = Vector2(125, 125)

	# Transition after progress fills
	tween.finished.connect(_on_loading_complete)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_transition_to_game()
	elif event is InputEventScreenTouch and event.pressed:
		_transition_to_game()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		_transition_to_game()

func _on_loading_complete() -> void:
	if _has_transitioned:
		return
	var flash_tween := create_tween()
	flash_tween.tween_property(subtitle, "modulate:a", 0.4, 0.15)
	flash_tween.tween_property(subtitle, "modulate:a", 1.0, 0.15)
	await flash_tween.finished
	await get_tree().create_timer(0.2).timeout
	_transition_to_game()

func _transition_to_game() -> void:
	if _has_transitioned:
		return
	_has_transitioned = true
	var exit_tw := create_tween()
	exit_tw.tween_property(self, "modulate:a", 0.0, 0.35)
	await exit_tw.finished
	get_tree().change_scene_to_file("res://scenes/menu.tscn")

func _style_loader() -> void:
	# Cyber high-tech progress track
	var background := StyleBoxFlat.new()
	background.bg_color = Color(0.04, 0.10, 0.20, 0.85)
	background.border_color = Color(0.0, 0.70, 0.95, 0.75)
	background.set_border_width_all(3)
	background.set_corner_radius_all(18)
	background.shadow_color = Color(0.0, 0.3, 0.6, 0.35)
	background.shadow_size = 12
	background.content_margin_left = 4
	background.content_margin_right = 4
	background.content_margin_top = 4
	background.content_margin_bottom = 4
	progress.add_theme_stylebox_override("background", background)

	# Glowing neon cyan fill
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.0, 0.85, 1.0, 1.0)
	fill.border_color = Color(0.8, 0.98, 1.0, 1.0)
	fill.set_border_width_all(2)
	fill.set_corner_radius_all(14)
	fill.shadow_color = Color(0.0, 0.9, 1.0, 0.6)
	fill.shadow_size = 8
	progress.add_theme_stylebox_override("fill", fill)

	# Label neon glow pulse
	var label_pulse := create_tween().set_loops()
	label_pulse.tween_property(loading_label, "modulate", Color(1.2, 1.2, 1.4, 1.0), 0.5).set_trans(Tween.TRANS_SINE)
	label_pulse.tween_property(loading_label, "modulate", Color.WHITE, 0.5).set_trans(Tween.TRANS_SINE)
