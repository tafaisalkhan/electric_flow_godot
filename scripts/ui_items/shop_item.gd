extends Control

signal activated(id: String)

var item_id := ""

func set_data(data: Dictionary) -> void:
	item_id = str(data.get("id", ""))
	%NameLabel.text = str(data.get("name", "ITEM")).to_upper()
	%IconLabel.text = str(data.get("icon", "◆"))
	%IconLabel.add_theme_color_override("font_color", data.get("color", Color("#398ccb")))
	var icon_ball := get_node_or_null("%IconBall") as Panel
	if icon_ball != null:
		icon_ball.visible = str(data.get("category", "")) == "Balls"
		icon_ball.self_modulate = data.get("color", Color.WHITE)
		%IconLabel.visible = not icon_ball.visible
	%ActionButton.text = "Equipped" if bool(data.get("equipped", false)) else ("Select" if bool(data.get("owned", false)) else "● %d" % int(data.get("cost", 0)))
	%ActionButton.disabled = false
	%ActionButton.mouse_filter = Control.MOUSE_FILTER_IGNORE if bool(data.get("equipped", false)) else Control.MOUSE_FILTER_STOP

func _ready() -> void:
	%ActionButton.pressed.connect(func(): activated.emit(item_id))
