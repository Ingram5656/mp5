# Entry test prototype (Godot 4.7)

Sensor connection -> "How it works" popup -> three locks (Direction, Force, Moment) -> "Connection successful" popup.
English UI. Uses a simulated sensor until the USB acquisition layer exists.

## Run
1. Open the `mp-5` project in Godot.
2. In the FileSystem panel open `entry_test/entry_test.tscn`.
3. Press **F6** (Run Current Scene). No project setting is changed by these files.

## Simulated input (keyboard)
- Left / Right: force direction
- Up / Down: force magnitude
- Q / E: moment

Hold each pointer in its green zone for 1 s to open that lock.

## Files
- `entry_test.tscn` - scene (root Control + main script)
- `scripts/entry_test.gd` - screens, popups, lock logic, placeholder targets
- `scripts/direction_gauge.gd`, `force_gauge.gd`, `moment_gauge.gd` - the three displays
- `scripts/sim_sensor.gd` - keyboard-driven simulated sensor

Target ranges (45 +/- 15 deg, 8-12 N, 0.15-0.25 N·m) are placeholders for testing the interface only.
They are not validated or clinical values.
