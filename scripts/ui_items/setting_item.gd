extends Control

signal changed(id: String, enabled: bool)
signal activated(id: String)

var item_id := ""

func set_data(data: Dictionary) -> void:
	item_id = str(data.get("id", ""))
	%NameLabel.text = str(data.get("label", item_id))
	%Toggle.set_pressed_no_signal(bool(data.get("enabled", false)))
	_update_knob(bool(data.get("enabled", false)))
	var is_action := bool(data.get("action", false))
	%Toggle.visible = not is_action
	%ActionButton.visible = is_action

func _ready() -> void:
	%Toggle.toggled.connect(_on_toggled)
	%ActionButton.pressed.connect(func(): activated.emit(item_id))

func _on_toggled(enabled: bool) -> void:
	_update_knob(enabled)
	changed.emit(item_id, enabled)

func _update_knob(enabled: bool) -> void:
	%Knob.position.x = 35.0 if enabled else 3.0
