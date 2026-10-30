# Reusable game screens

Open `res://scenes/ui_suite_demo.tscn` in Godot for a Jumpup Ball example. `res://scenes/ui_suite.tscn` is the reusable UI scene. The ball and game name in the demo are examples; the Math Mind adapter uses its own data.

## Edit the visuals

Each screen is a separate scene in `res://scenes/ui_screens/`: `home_ui.tscn`, `settings_ui.tscn`, `shop_ui.tscn`, `store_ui.tscn`, `missions_ui.tscn`, `leaderboard_ui.tscn`, and `reward_ui.tscn`. Open a scene in Godot to edit its text, color, spacing, and controls. The home ball is a `LogoGlyph` Panel; its appearance comes from `ui_ball.tres` and its highlight from `ui_ball_glint.tres`.

Repeated cards and rows are separate scenes in `res://scenes/ui_items/`: setting, shop, store, mission, and leaderboard items. Typography uses three shared Nunito resources: `ui_body_font.tres` (body text), `ui_bold_font.tres` (buttons, labels, and item names), and `ui_heading_font.tres` (titles and large numbers). `ui_suite_theme.tres` applies them across the suite. Font sizes and text colors remain editable on the scene nodes. Panel and button styles are in `res://resources/ui_*.tres`, including the sky shader materials. Layout, wording, and button placement are editable scene nodes.

The screen scene references are exported on `ui_suite.tscn`, so a new game can replace any screen without changing the controller script.

## Connect a game

Instantiate `ui_suite.tscn`, set `game_title`, `tagline`, `score_title`, and `score_unit` before adding it to the tree, then connect its signals. `scripts/menu.gd` is a working Math Mind adapter.

```gdscript
var ui = preload("res://scenes/ui_suite.tscn").instantiate()
ui.game_title = "MY GAME"
ui.score_title = "BEST SCORE"
add_child(ui)
ui.play_requested.connect(_start_game)
ui.purchase_requested.connect(_start_verified_purchase)
ui.update_data({"coins": player_coins, "best_score": best_score})
```

The suite emits `play_requested`, `daily_challenge_requested`, `daily_reward_requested`, `rewarded_coins_requested`, `setting_changed(id, enabled)`, `settings_action_requested(id)`, `shop_action_requested(id)`, `purchase_requested(id)`, `mission_claim_requested(id)`, `leaderboard_signin_requested`, `leaderboard_full_requested`, and `privacy_requested`.

`update_data()` accepts `coins`, `stars`, `best_score`, `daily_reward_available`, `daily_reward_amount`, `show_daily_challenge`, `rewarded_label`, `settings_options`, `settings_actions`, `shop_items`, `store_products`, `missions`, `leaderboard_rows`, `leaderboard_user`, and `leaderboard_signed_in`. Missing keys retain their current values. Shop items use `id`, `name`, `category`, `icon`, `color`, `cost`, `owned`, and `equipped`. Store products use `id`, `name`, `description`, and `price`. Missions use `id`, `name`, `target`, `progress`, `reward`, `complete`, and `claimed`. Leaderboard rows use `name`, `score`, and `reward`; the optional user row also uses `rank`.

Call `show_reward(title, coins, detail, stars)` after the game saves a reward. The popup animates stars and coins but does not change the balance. Connect purchase and leaderboard signals to the new game's services. Demo prices and rankings are sample data.
