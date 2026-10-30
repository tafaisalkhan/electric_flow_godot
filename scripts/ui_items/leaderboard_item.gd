extends Control

@export var first_style: StyleBox
@export var normal_style: StyleBox
@export var user_style: StyleBox

func set_data(rank: int, data: Dictionary) -> void:
	%RankLabel.text = str(rank)
	%NameLabel.text = str(data.get("name", "Player"))
	%ScoreLabel.text = str(data.get("score", 0))
	%RewardLabel.text = str(data.get("reward", ""))
	var is_user := bool(data.get("is_user", false))
	if first_style != null and normal_style != null:
		$Panel.add_theme_stylebox_override("panel", user_style if is_user and user_style != null else (first_style if rank == 1 else normal_style))
