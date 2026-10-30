extends Control

signal activated(id: String)

@export var ready_style: StyleBox
@export var normal_style: StyleBox

var item_id := ""

func set_data(data: Dictionary) -> void:
	item_id = str(data.get("id", ""))
	%NameLabel.text = str(data.get("name", "Mission"))
	var target := maxi(1, int(data.get("target", 1)))
	var progress := clampi(int(data.get("progress", 0)), 0, target)
	var claimed := bool(data.get("claimed", false))
	var complete := bool(data.get("complete", false))
	%DetailLabel.text = "Claimed" if claimed else ("✓ Complete — claim reward" if complete else "%d/%d" % [progress, target])
	%DetailLabel.add_theme_color_override("font_color", Color("#8a5c12") if complete else Color("#6e7d8b"))
	%Progress.max_value = target
	%Progress.value = progress
	%ActionButton.text = "+%d" % int(data.get("reward", 0))
	%ActionButton.visible = complete and not claimed
	if ready_style != null and normal_style != null:
		$Panel.add_theme_stylebox_override("panel", ready_style if complete else normal_style)

func _ready() -> void:
	%ActionButton.pressed.connect(func(): activated.emit(item_id))
