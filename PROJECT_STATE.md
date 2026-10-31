# Project State & Developer Handoff — Electric Flow: Circuit Connect

Updated: 2026-10-31. This is a comprehensive architecture and state snapshot for subsequent agents.

---

## 1. Project Overview & Identity

- **Game Name**: Electric Flow — Circuit Connect
- **Engine**: Godot Engine 4.7.2-stable (Win64 / Android)
- **Target Platform**: Android (`arm64-v8a`, `armeabi-v7a`), exported as Google Play Release App Bundle (`.aab`)
- **Package ID**: `com.electicflow.connectgame`
- **Main Entry Scene**: `scenes/splash.tscn` -> `scenes/menu.tscn` -> `scenes/electric_flow.tscn`
- **Git Repository**: `https://github.com/tafaisalkhan/electric_flow_godot.git` (branch `main`)
- **Godot Executable Path**: `C:\Users\Supreme Traders\Downloads\Godot_Engine\Godot_v4.7.2-stable_win64.exe`

---

## 2. Core Gameplay Architecture

The game is a tactile, physics-inspired circuit puzzle where players rotate conduit tiles to connect power sources (Batteries, Solar Panels) to electrical loads (Bulbs, Fans, Heaters, Cottages, Villas, Vacuum Tubes, Tesla Coils, Metropolis Skyscrapers).

### Procedural Generation & Grid Scaling (`scripts/electric_levels.gd`)
- Generates 100% board-filling Hamiltonian / Serpentine circuits with **zero empty tiles or dead ends**.
- Grid dimensions scale progressively:
  - **Levels 1–3**: 2x2 (4 tiles) — Solar Panel / Battery to Bulb / Fan.
  - **Levels 4–7**: 3x3 (9 tiles) — Introduces Small House, Resistors, and 3-Way T-Junctions.
  - **Levels 8–14**: 3x4 (12 tiles) — Introduces Big Houses and Multi-Target networks.
  - **Levels 15–24**: 4x4 (16 tiles) — Introduces 4-Way Crossings and Dual Sources.
  - **Levels 25–38**: 4x5 (20 tiles)
  - **Levels 39–58**: 5x5 (25 tiles)
  - **Levels 59–85**: 5x6 (30 tiles)
  - **Levels 86+**: 6x6 (36 tiles, capped for optimal touch readability on mobile screens).

### Progressive Challenge Mechanics
1. **3-Way T-Junctions (`WIRE_TEE`)**:
   - Introduced at Level 6+.
   - Base ports: `DIR_UP | DIR_RIGHT | DIR_DOWN`. Exactly 2 rotations conduct the required path; the other 2 break the circuit.
2. **Fixed / Locked Obstacles (Immovable Pins)**:
   - Level 12+ has 1 locked wire; Level 30+ has 2 locked wires.
   - `rotatable = false` and `is_locked = true` at solved orientation.
   - Drawn with industrial brass corner brackets and padlock icons. Tapping triggers a tactile horizontal shake.
3. **Multi-Target Networks (Levels 14–19)**:
   - Intermediate consumers (Small House, Fan, Bulb) placed along the circuit.
   - BFS traverses through intermediate targets to downstream components.
   - All targets must be powered simultaneously for victory.
4. **Dual-Source Networks (Levels 20+)**:
   - Simultaneous Battery (Circuit 1) + Solar Panel (Circuit 2) feeding independent sections of the board.
   - Visualized with dual glowing color streams into multiple landmarks.
5. **4-Way Crossings (`WIRE_CROSS`)**:
   - Introduced at Level 18+. Connects all 4 sides.
6. **Move Budget & Par System**:
   - **Levels 1–5**: Unlimited practice moves (`max_moves = 0`).
   - **Levels 6+**: $\text{max\_moves} = \text{min\_moves} + 6 + \lfloor \text{total\_tiles} \times 0.35 \rfloor$.
   - Displays `"Moves: X / Y | Par: Z"`.
   - "Out of Moves" modal offers **"↺ RETRY"** or **"+5 MOVES"**.

### Daily Challenge Mode
- Unlimited sequential progression (`scripts/electric_levels.gd::get_daily_challenge(daily_index)`).
- Deterministic daily seed based on the index.
- Victory screen features **"NEXT DAILY ▶"** to allow uninterrupted daily puzzle solving.

---

## 3. UI, Audio & Visual Polish

- **Star Counts**: Completely hidden across all screens (Main HUD, Settings, Menus, Header) per user requirement.
- **Landmark Illumination (`scripts/electric_landmark.gd`)**:
  - Dynamically displays glowing 2.5D landmark structures (Solar arrays, Cottages, High-rise buildings) that light up in real-time as targets are powered.
- **Sound & Haptics (`scripts/audio_manager.gd`, `scripts/electric_flow.gd`)**:
  - Procedural polyphonic synthesizer tones for circuit clicks, current propagation waves, bulb ignition, and fanfare.
  - Fallback audio players generate clean audio buffers in memory without external audio asset dependencies.

---

## 4. Monetization & AdMob Integration

- **Ad Manager (`scripts/ad_manager.gd`)**:
  - Integrated via Poing Studios AdMob Godot plugin.
  - **Live Production AdMob IDs**:
    - Application ID: `ca-app-pub-4933939316656461~2313627038`
    - Banner Ad ID: `ca-app-pub-4933939316656461/8873499719`
    - Interstitial Ad ID: `ca-app-pub-4933939316656461/7086851608`
    - Rewarded Ad ID: `ca-app-pub-4933939316656461/5258671607`
  - Test ad fallbacks removed; live ads trigger in Android release builds.
  - Bottom banner displays during gameplay; top banner displays on victory screen.
- **In-App Purchases (`scripts/iap_manager.gd`, `scripts/settings.gd`)**:
  - "$4.99 Remove Ads" SKU (`remove_ads`) accessible in Settings.

---

## 5. Key File Locations & Roles

| File Path | Role |
| --- | --- |
| `scripts/electric_levels.gd` | Procedural level generator, Hamiltonian path solver, puzzle validator, daily challenge generator. |
| `scripts/electric_flow.gd` | Core gameplay controller, BFS circuit solver, wave propagation animator, move counter, victory modal. |
| `scripts/electric_tile.gd` | High-fidelity procedural vector rendering for all 16 component types, locked plates, terminals, wire glow. |
| `scripts/electric_landmark.gd` | 2.5D visual display of powered buildings/houses/solar arrays at the top of the play screen. |
| `scripts/electric_enums.gd` | Enums for `TileType`, `Direction` bitmasks, channel colors, and port rotation helpers. |
| `scripts/electric_component_data.gd` | Component codex database with educational facts and unlock milestones. |
| `scripts/game_state.gd` | Autoload managing persistent save data (`user://electric_flow_save.dat`), coins, unlocks, and settings. |
| `scripts/ad_manager.gd` | Autoload managing live AdMob banners, interstitials, and rewarded ads. |
| `scripts/iap_manager.gd` | Autoload handling Google Play Billing and the "Remove Ads" purchase. |
| `scripts/settings.gd` | Clean settings screen with audio/haptics toggles, Remove Ads button, and privacy policy. |
| `scripts/test_electric_flow.gd` | Comprehensive headless Godot test suite for levels 1–10,000+, mechanics, and daily challenges. |
| `check_compile_errors.js` | Fast local node script performing static parsing and bracket/type audit across all `.gd` scripts. |

---

## 6. How to Verify & Build

### 1. Static Script Compilation Audit
Run from workspace root:
```powershell
node check_compile_errors.js
```
*Expected output: `FINAL RESULT: 0 ERRORS, 0 WARNINGS`.*

### 2. Full Engine Headless Test Suite
Run via Godot executable with sandbox bypass:
```powershell
& "C:\Users\Supreme Traders\Downloads\Godot_Engine\Godot_v4.7.2-stable_win64.exe" --headless --script res://scripts/test_electric_flow.gd
```
*Expected output: `--- ALL ELECTRIC FLOW TESTS PASSED SUCCESSFULLY! ---`.*

### 3. Release Android AAB Export
To build the signed release bundle:
```powershell
& "C:\Users\Supreme Traders\Downloads\Godot_Engine\Godot_v4.7.2-stable_win64.exe" --headless --export-release "Android" "build/electricflow.aab"
```
*Output artifact: `build/electricflow.aab` (~77.7 MB).*

---

## 7. Critical Git Commit & Exclusion Rules

When committing or pushing to GitHub:
1. **Strictly Exclude Assets**: Never add or commit `assets/` or `**/assets/`.
2. **Strictly Exclude JSON**: Never add or commit `*.json`.
3. **Strictly Exclude Keystores**: Never add or commit `*.keystore` or `*.jks`.
4. **Strictly Exclude Builds**: Never add or commit `build/`, `.godot/`, or temporary files.
5. **Windows Git Lock Fix**: If `index.lock` blocks git:
   ```powershell
   if (Test-Path .git/index.lock) { Remove-Item .git/index.lock -Force }
   ```
