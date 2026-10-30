# Math Mind Base Game

This folder is a reusable, independent Godot project. It contains the gameplay code, scenes, AdMob plugin, Android Gradle template, and supporting assets needed to build another game.

## Create a new game

1. Copy the entire base_gameUI folder and rename the copy.
2. Open the copied project.godot in Godot 4.7.2 or a compatible Godot 4 release.
3. Update the app name in project.godot.
4. Update package/unique_name, version, and signing options in export_presets.cfg.
5. Replace the artwork under assets/generated/ while keeping filenames and dimensions when possible.
6. Replace easy_levels.json, medium_levels.json, hard_levels.json, and expert_levels.json under assets/data/.
7. Test every difficulty, rewarded-ad flow, interstitial schedule, and bottom banner before publishing.

## JSON contract

Each bank contains a top-level levels array. Each level needs level_num, difficulty, title, rows, cols, cells, and bank.

Fixed cell example: {"r":0,"c":0,"type":"fixed","val":"5"}
Answer cell example: {"r":0,"c":2,"type":"empty","target":"6"}

The bank array must contain every draggable target required to solve the board. Supported arithmetic symbols are +, -, ×, and ÷.

## Replaceable content

- Launcher and splash assets: assets/generated/app-icon-*
- Backgrounds and UI artwork: assets/generated/
- Level data: assets/data/
- Audio: assets/audio/

If filenames change, update their references in scenes, scripts, project.godot, and export_presets.cfg.

## Shared player screens

- `scenes/ui_suite.tscn` and `scripts/ui_suite.gd`: portable UI controller for home, settings, shop, coin store, missions, leaderboard, and reward. The screen and item scenes are in `scenes/ui_screens/` and `scenes/ui_items/`. Give the suite data with `update_data()` and connect its signals to the new game's systems. See `docs/UI_SUITE.md` for the edit points.
- `scenes/ui_suite_demo.tscn` and `scripts/ui_suite_demo.gd`: preview with sample data matching the supplied screen references. Open this scene in Godot to inspect each panel. The listed products and prices are preview content.
- `scenes/menu.tscn` and `scripts/menu.gd`: Math Mind adapter for the shared UI suite. It connects play, daily challenges, rewarded ads, cosmetic themes, missions, settings, and privacy.
- `scripts/ui_palette.gd`: Math Mind's example cosmetic theme catalog.
- `scenes/settings.tscn` and `scripts/settings.gd`: older standalone Math Mind settings scene, kept for projects that use its options.
- `scenes/main.tscn` and `scripts/main.gd`: level completion dialog with star bursts, coin flight, and rewarded coin action.
- `scripts/game_state.gd`: persistent balances, owned themes, and selected theme. Copy its save and purchase logic together with the screens.

For a new game, copy the UI suite, its screen and item scenes, the `resources/ui_*` styles, and `assets/fonts/Nunito-Variable.ttf`. Make a small adapter like `menu.gd` to provide player data and handle button signals. Change the home ball through `ui_ball.tres` and `ui_ball_glint.tres`, and edit colors and StyleBox resources in the UI scenes. Replace the title, tagline, score label, and product catalog. The sample coin store emits `purchase_requested`; connect it to verified platform billing before enabling fulfillment. The leaderboard emits `leaderboard_signin_requested`; connect a real ranking service before showing player rows. Math Mind's adapter displays an unavailable message for these unconnected services.

## Ads

The template uses the Poing Studios Godot AdMob plugin. Debug builds use Google's test ad unit IDs. Before release, replace the production IDs and verify the AdMob application ID in the Android export configuration.

## Intentionally excluded

- .godot/ imported-editor cache
- Root build/ APK/output files
- android/build/.gradle/
- android/build/build/ generated Gradle output
- android/build/local.properties machine-specific SDK path

Godot and Gradle regenerate these files on the new development machine.
