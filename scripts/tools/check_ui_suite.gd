extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var ui: GameUISuite = load("res://scenes/ui_suite.tscn").instantiate()
	root.add_child(ui)
	await process_frame
	ui.update_data({
		"coins": 435,
		"best_score": 82,
		"shop_items": [{"id": "ocean", "name": "Ocean", "category": "Themes", "cost": 300, "color": Color.SKY_BLUE}],
		"store_products": [{"id": "coins", "name": "Pouch of Coins", "description": "500 coins", "price": "Rs 270"}],
		"missions": [{"id": "play", "name": "Play 3 games", "target": 3, "progress": 1, "reward": 18}],
		"leaderboard_signed_in": true,
		"leaderboard_rows": [{"name": "Player", "score": 82}]
	})
	assert(ui._home.name == "HomeUI")
	for screen in ["settings", "shop", "store", "missions", "leaderboard"]:
		ui.open_screen(screen)
		await process_frame
		assert(ui._panel != null and ui._panel.screen_kind == screen)
	ui.show_reward("Level Complete", 10, "Great work", 2)
	await process_frame
	assert(ui._panel.name == "RewardUI")
	ui.open_screen("settings")
	await process_frame
	assert(ui._home.name == "HomeUI" and ui._panel.name == "SettingsUI")
	print("UI_SUITE_OK")
	quit()
