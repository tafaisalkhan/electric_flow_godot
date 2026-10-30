extends Control

signal screen_requested(screen: String)
signal play_requested
signal daily_challenge_requested
signal daily_reward_requested
signal rewarded_coins_requested

func _ready() -> void:
	%SettingsButton.pressed.connect(func(): screen_requested.emit("settings"))
	%ScoreLink.pressed.connect(func(): screen_requested.emit("leaderboard"))
	%PlayButton.pressed.connect(func(): play_requested.emit())
	%DailyChallengeButton.pressed.connect(func(): daily_challenge_requested.emit())
	%DailyRewardButton.pressed.connect(func(): daily_reward_requested.emit())
	%RewardedButton.pressed.connect(func(): rewarded_coins_requested.emit())
	%ShopButton.pressed.connect(func(): screen_requested.emit("shop"))
	%StoreButton.pressed.connect(func(): screen_requested.emit("store"))
	%MissionsButton.pressed.connect(func(): screen_requested.emit("missions"))
	%ScoreButton.pressed.connect(func(): screen_requested.emit("leaderboard"))

func set_data(data: Dictionary, title: String, tagline: String, score_title: String, score_unit: String) -> void:
	%TitleLabel.text = title
	%TaglineLabel.text = tagline
	%ScoreCaption.text = score_title
	%ScoreLabel.text = "%d" % int(data.get("best_score", 0))
	%ScoreUnit.text = score_unit.strip_edges()
	%ScoreUnit.visible = not score_unit.strip_edges().is_empty()
	%CoinLabel.text = "●  %d" % int(data.get("coins", 0))
	%StarLabel.text = "★  %d" % int(data.get("stars", 0))
	var ready := bool(data.get("daily_reward_available", true))
	%RewardIcon.text = "🎁" if ready else "✓"
	%RewardTitle.text = "Daily Reward Ready" if ready else "Reward Claimed"
	%RewardSubtitle.text = "Claim %d coins now" % int(data.get("daily_reward_amount", 10)) if ready else "Come back tomorrow"
	%RewardArrow.visible = ready
	%DailyRewardButton.tooltip_text = "Claim today's daily reward" if ready else "Daily reward already claimed"
	%DailyRewardButton.disabled = not ready
	%DailyChallengeButton.visible = bool(data.get("show_daily_challenge", false))
	%RewardedButton.visible = false
	%ShopButton.visible = false
	%MissionsButton.visible = false
	if has_node("%Nav"):
		%Nav.visible = false
	if has_node("%MessageLabel"):
		%MessageLabel.visible = false
	%RewardedButton.text = str(data.get("rewarded_label", "▶  Watch Ad · Get 3 Boosts"))

func show_message(message: String) -> void:
	%MessageLabel.text = message

func set_background_tint(tint: Color) -> void:
	if %Background is ColorRect:
		%Background.color = tint
