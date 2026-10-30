# Project state — Math Mind

Updated: 2026-10-23. This is a handoff snapshot for the next agent. Recheck it against the files before making changes.

## What this project is

- A Godot 4.7 project for a portrait Android math crossword game named **Math Mind**. The project root is this folder; open `project.godot` in Godot.
- The app starts at `scenes/splash.tscn`, then opens `scenes/menu.tscn`. `scripts/menu.gd` connects the reusable UI suite to Math Mind. Gameplay is in `scenes/main.tscn` and `scripts/main.gd`.
- `BASE_GAME_GUIDE.md` explains how to copy this project for another game. `docs/UI_SUITE.md` documents the reusable screens, signals, and data contract.

## Main code and data

| Area | Files | Role |
| --- | --- | --- |
| Player state | `scripts/game_state.gd` | Autoload; saves progress, coins, stars, daily activity, themes, and settings to `user://math_mind_progress.cfg`. |
| Sound and ads | `scripts/audio_manager.gd`, `scripts/ad_manager.gd` | Autoloads; the AdMob plugin is under `addons/admob/`. |
| Levels | `scripts/level_data.gd`, `assets/data/*_levels.json` | Loads easy, medium, hard, and expert banks. Each JSON bank currently has 1,000 levels. Procedural fallback handles missing or invalid bank entries. |
| UI suite | `scenes/ui_suite.tscn`, `scripts/ui_suite.gd`, `scenes/ui_screens/`, `scenes/ui_items/`, `resources/ui_*` | Home, settings, shop, store, missions, leaderboard, and reward screens. |
| UI example | `scenes/ui_suite_demo.tscn`, `scripts/ui_suite_demo.gd` | Standalone preview with sample content. |
| Artwork | `assets/generated/`, `assets/fonts/` | Game images and Nunito font. |
| Android | `export_presets.cfg`, `android/` | Android export preset and Gradle template. |

## Current integration boundaries

- `scripts/menu.gd` is the production adapter for the UI suite. Read it and `docs/UI_SUITE.md` before changing UI signals or data keys.
- The coin store and leaderboard screens expose UI and sample data, but `scripts/menu.gd` handles purchase and sign-in requests as unavailable. Connect verified billing and a ranking service before offering those features as live services.
- `scripts/ad_manager.gd` and `project.godot` currently contain Google test AdMob IDs. Replace and validate the production configuration for a release.
- `export_presets.cfg` currently identifies the Android app as `com.mathmind.game`, version code `2`, version name `1.0.1`, with an arm64 Gradle export path of `build/mathmind-debug.apk`.
- `docs/privacy-policy.html` needs a real contact address and release-specific wording before publication; see `docs/README.md`.
- The guide mentions `assets/audio/`, but that folder is absent in this snapshot. Check actual asset references before assuming audio files exist.

## How to inspect and verify

1. Open `project.godot` in a compatible Godot 4 editor and run the main scene to follow splash → menu → gameplay.
2. Open `scenes/ui_suite_demo.tscn` for the reusable UI preview.
3. Run the UI smoke script with a Godot CLI, for example: `godot --headless --path . --script res://scripts/tools/check_ui_suite.gd`. It prints `UI_SUITE_OK` on success.
4. Exercise all four difficulties and the ad flows on Android before release. The supplied JSON banks and native ad plugin need more than the UI smoke check.

No runtime test was run while writing this snapshot: `godot` was not found on `PATH` in this shell. This folder also has no `.git` directory, so there is no repository status to report here.

## Next-agent starting point

Read the user's latest request first, then `BASE_GAME_GUIDE.md` and the relevant files above. Treat this document as context, not as a new feature request or a claim that release testing is complete. Update it when architecture, integrations, or known limitations change.
