extends Control

signal activated(id: String)

var item_id := ""

func set_data(data: Dictionary) -> void:
	item_id = str(data.get("id", ""))
	%NameLabel.text = str(data.get("name", "Coin Pack"))
	%DetailLabel.text = str(data.get("description", ""))
	%PriceLabel.text = str(data.get("price", "Price in store"))

func _ready() -> void:
	%ActionButton.pressed.connect(func(): activated.emit(item_id))
