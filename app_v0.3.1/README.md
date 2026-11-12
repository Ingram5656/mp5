# MP5 app v0.3.1 (Godot 4.7)

Visual design following `design/设计方案_v1.1.md` (deeper target-zone green than v0.3.0). Flow and features are the same as v0.2.1:
sensor connection -> "How it works" -> entry test (three locks) -> "Connection successful" -> game selection,
with the EN / 中文 switch at the top right.

## Run
Open `app_v0.3.1/main.tscn` in Godot and press F6.
Fonts are read from `res://fonts/` (Atkinson Hyperlegible Next + Noto Sans SC, SIL OFL).
If they are missing the app still runs with Godot's default font.

## Files
- `scripts/palette.gd` - colours, type scale (design tokens)
- `scripts/main.gd` - pages, popups, lock logic, language switch
- `scripts/strings.gd` - all on-screen text, English and Chinese
- `scripts/direction_gauge.gd`, `force_gauge.gd`, `moment_gauge.gd` - the three displays
- `scripts/sim_sensor.gd` - keyboard-driven simulated sensor

## Simulated input (keyboard)
Left / Right = direction, Up / Down = force, Q / E = moment.

Target ranges are placeholders for interface testing only, not validated or clinical values.
See `版本记录.md` in the project root for the change history.
