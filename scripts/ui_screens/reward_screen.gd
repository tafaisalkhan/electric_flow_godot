extends Control

signal collect_requested

func _ready() -> void:
	%CollectButton.pressed.connect(_collect)

func set_data(title: String, coins: int, detail: String, stars: int) -> void:
	%TitleLabel.text = title
	%DetailLabel.text = detail
	%AmountLabel.text = "+%d  ●" % coins
	%AmountLabel.visible = coins > 0
	%Stars.visible = stars > 0
	for index in range(3):
		var star: Control = [%Star1, %Star2, %Star3][index]
		star.modulate = Color.WHITE if index < stars else Color(0.25, 0.32, 0.45, 0.4)
		if index < stars:
			star.scale = Vector2(0.35, 0.35)
			create_tween().tween_property(star, "scale", Vector2.ONE, 0.35).set_delay(index * 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if coins > 0:
		%AmountLabel.scale = Vector2(0.45, 0.45)
		create_tween().tween_property(%AmountLabel, "scale", Vector2.ONE, 0.42).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _collect() -> void:
	%CollectButton.disabled = true
	var tween := create_tween()
	tween.tween_property(%AmountLabel, "modulate:a", 0.0, 0.23)
	tween.tween_callback(func(): collect_requested.emit())
