# MP5 app v0.4.0 (Godot 4.7)

Same flow and design as v0.3.1 (sensor connection -> "How it works" -> entry test -> game selection, EN / 中文 switch),
plus the first playable game: **Rocking Challenge, Level A — the carrot game (拔萝卜)**.

## Run
- Whole app: open `app_v0.4.0/main.tscn` and press F6. Finish the entry test, pick **Rocking Challenge**, choose a difficulty, press **Start**.
- Carrot game only: open `app_v0.4.0/carrot_game.tscn` and press F6 (Trainee Dentist, Chinese text).

Art is read from `res://assets/carrot_game/` (see the README there for coordinates). Fonts from `res://fonts/`.
Missing images are replaced by flat colour blocks and listed in the Output panel.

## Carrot game rules
- Only the target-axis moment is used. Positive moment tilts the carrot right, negative tilts it left
  (same sign as Q / E in the entry test).
- One half-rock = push into the green sector, hold 0.5 s, return to centre. Sides must alternate.
  Left + right = one rock. 6 rocks pull the carrot out.
- Moment above the limit = one "too hard" mistake (crack on the carrot); return to centre to continue.
  More mistakes than the difficulty allows snaps the carrot and the level is lost.
- Off-axis moment or pull force over the limit only gives a warning (soil shakes, rabbit covers its ears)
  and pauses the hold timer. Only available once a real sensor is connected (or hold S on the keyboard).

| Difficulty | Hints | Timer | Mistakes allowed |
|---|---|---|---|
| Intern | text + green sectors | none | 5 |
| Trainee Dentist | green sectors only | 90 s | 3 |
| Master Dentist | none (flash on success only) | 90 s | 0 |

## Keyboard (simulated sensor)
Left / A / Q = tilt left, Right / D / E = tilt right; release to return to centre.
Hold Shift = too hard. Hold S = off-axis warning. F3 = live numbers. Esc = back to game selection.

## Data log
Each round writes a CSV to `user://carrot_logs/` (Windows: `%APPDATA%\Godot\app_userdata\MP5\carrot_logs\`):
one header line with the settings, then one row per frame (time, moment, off-axis, pull, phase, hold time,
half-rocks, rocks, mistakes, event).

Moment ranges (green 0.15–0.30 N·m, limit 0.40 N·m, centre < 0.05 N·m) are placeholders for testing,
not validated or clinical values. See `版本记录.md` in the project root for the change history.
