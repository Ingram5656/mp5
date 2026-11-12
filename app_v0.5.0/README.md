# MP5 app v0.5.0 (Godot 4.7)

v0.5.0 adds **achievements** for the carrot game (Rocking Challenge, Level A). Everything else is the same as v0.4.1.

## Run
- Whole app: open `app_v0.5.0/main.tscn` and press F6. After the entry test, the game selection page has an
  **Achievements** button under "Sensor check" (it also shows how many are unlocked).
- Carrot game only: open `app_v0.5.0/carrot_game.tscn` and press F6. Achievements are recorded here too.

## What is new
- **20 achievements** for the carrot game, defined in `scripts/achievement_defs.gd`
  (same content as `design/成就列表.xlsx`; keep the two in sync).
- **Local database** `scripts/achievement_db.gd`: achievement state, play statistics (wins per difficulty,
  Master win streak, fail streak, …) and a history of rounds, saved to
  `user://mp5_data/mp5_db.json` (Windows: `%APPDATA%\Godot\app_userdata\MP5\mp5_data\`).
  It is loaded at start and saved after every round, so nothing resets when the game is closed.
  Saves go through a temporary file and keep the previous copy as `.bak`.
- **Pop-ups** (`scripts/achievement_toast_host.gd`): top-right, icon + "Achievement unlocked" + name + flavour text,
  4 s each, up to 3 at once. Two achievements ("Inside Voice, Please", "Other Left") pop up during the round;
  the rest when the round ends. The result panel also lists what was unlocked this round.
- **Achievements page** (`main.gd`): summary and progress bar, All / Unlocked / Locked filter, one row per
  achievement grouped by difficulty — icon, name, condition, flavour text, and on the right the unlock date,
  a progress bar for counted achievements, or "Locked". Hidden achievements show "?" until unlocked.
- **Icons**: every icon is a 🦷 placeholder for now. Put drawn icons in `res://assets/achievements/<id>.png`
  (names listed in `assets/achievements/README.md`) and they replace the placeholder automatically.

## Design
Follows `design/设计方案_v1.1.md`: porcelain background, rows separated by hairlines (no cards, shadows or
gradients), colour only for state (target green = unlocked, with the word "Unlocked" so it does not rely on colour),
rounded corners only on buttons, type scale 13 / 16 / 20 / 25, no entrance animation on pop-ups.

Moment ranges and achievement thresholds are placeholders for testing, not validated values.
See `版本记录.md` in the project root for the change history.
