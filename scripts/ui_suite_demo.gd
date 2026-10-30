extends "res://scripts/ui_suite.gd"

func _ready() -> void:
	game_title = "JUMPUP BALL"
	tagline = "RISE ABOVE"
	score_title = "BEST HEIGHT"
	score_unit = " m"
	super._ready()
	update_data({
		"coins": 435,
		"best_score": 8227,
		"daily_reward_available": true,
		"rewarded_label": "▶  Watch Ad · Get 3 Boosts",
		"shop_items": [
			{"id": "crimson", "name": "Crimson", "category": "Balls", "icon": "●", "color": Color("#d92d32"), "cost": 0, "owned": true, "equipped": false},
			{"id": "charcoal", "name": "Charcoal", "category": "Balls", "icon": "●", "color": Color("#343434"), "cost": 0, "owned": true, "equipped": true},
			{"id": "ocean_ball", "name": "Ocean", "category": "Balls", "icon": "●", "color": Color("#92cfe1"), "cost": 300},
			{"id": "mint", "name": "Mint", "category": "Balls", "icon": "●", "color": Color("#80c8ae"), "cost": 450},
			{"id": "violet", "name": "Violet", "category": "Balls", "icon": "●", "color": Color("#b987ce"), "cost": 600},
			{"id": "solar", "name": "Solar", "category": "Balls", "icon": "●", "color": Color("#edc96d"), "cost": 1000},
			{"id": "sunset_sky", "name": "Sunset", "category": "Themes", "icon": "◆", "color": Color("#e69d75"), "cost": 500},
			{"id": "shield", "name": "Shield", "category": "Boosts", "icon": "⬡", "color": Color("#77b6e2"), "cost": 150}
		],
		"store_products": [
			{"id": "pouch", "name": "Pouch of Coins", "description": "500 coins", "price": "Rs 270.00"},
			{"id": "starter", "name": "Starter Bundle", "description": "1,200 coins + boosts", "price": "Rs 550.00"},
			{"id": "bag", "name": "Bag of Coins", "description": "3,000 coins", "price": "Rs 1,400.00"},
			{"id": "chest", "name": "Chest of Coins", "description": "7,000 coins", "price": "Rs 2,750.00"},
			{"id": "boost", "name": "Boost Pack", "description": "5 boosts of each type", "price": "Rs 700.00"}
		],
		"missions": [
			{"id": "height", "name": "Reach 100m", "target": 100, "progress": 100, "reward": 18, "complete": true},
			{"id": "powerup", "name": "Use a power-up", "target": 1, "progress": 1, "reward": 18, "complete": true},
			{"id": "games", "name": "Play 3 games", "target": 3, "progress": 1, "reward": 18},
			{"id": "platforms", "name": "Land on 25 platforms", "target": 25, "progress": 25, "reward": 24, "complete": true}
		],
		"leaderboard_signed_in": true,
		"leaderboard_user": {"rank": 10, "name": "FancyPants", "score": "8.2K", "reward": ""},
		"leaderboard_rows": [
			{"name": "Player One", "score": "137.4K", "reward": "● 10K"},
			{"name": "Player Two", "score": "60.4K", "reward": "● 5K"},
			{"name": "Player Three", "score": "31.1K", "reward": "● 3K"},
			{"name": "Player Four", "score": "19.7K", "reward": "● 1.5K"},
			{"name": "Player Five", "score": "18.5K", "reward": "● 1.5K"}
		]
	})
	play_requested.connect(_demo_action)
	daily_challenge_requested.connect(_demo_action)
	daily_reward_requested.connect(_demo_reward)
	rewarded_coins_requested.connect(_demo_reward)
	shop_action_requested.connect(_demo_item)
	purchase_requested.connect(_demo_item)
	mission_claim_requested.connect(_demo_item)
	leaderboard_signin_requested.connect(_demo_action)
	leaderboard_full_requested.connect(_demo_action)

func _demo_action() -> void:
	show_reward("Preview Screen", 0, "Connect this button to your game adapter.")

func _demo_reward() -> void:
	show_reward("Daily Reward", 10, "Preview animation")

func _demo_item(_id: String) -> void:
	show_reward("Preview Screen", 0, "Connect this item to your game data.")
