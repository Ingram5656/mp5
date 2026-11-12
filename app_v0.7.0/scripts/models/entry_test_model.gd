extends RefCounted
## Model — entry test "three locks" (v0.5.4; rules unchanged from v0.3.x main.gd).
## Each lock (0 direction, 1 force, 2 moment) opens after its value stays in the target zone for HOLD_TIME s.
## Target ranges are PLACEHOLDERS for the prototype, not validated or clinical values.

const DIR_TARGET := 45.0
const DIR_TOL := 15.0
const FORCE_MIN := 8.0
const FORCE_MAX := 12.0
const MOMENT_MIN := 0.15
const MOMENT_MAX := 0.25
const HOLD_TIME := 1.0

var hold := [0.0, 0.0, 0.0]
var unlocked := [false, false, false]


func reset() -> void:
	hold = [0.0, 0.0, 0.0]
	unlocked = [false, false, false]


static func in_zone(sample: Dictionary) -> Array:
	var dir: float = sample["direction_deg"]
	var force: float = sample["force_n"]
	var mom: float = sample["moment_nm"]
	return [
		absf(angle_difference(deg_to_rad(dir), deg_to_rad(DIR_TARGET))) <= deg_to_rad(DIR_TOL),
		force >= FORCE_MIN and force <= FORCE_MAX,
		mom >= MOMENT_MIN and mom <= MOMENT_MAX,
	]


## Advance the holds. While `paused` (a dialog is open) nothing changes.
## Returns the indices of locks that opened during this step.
func step(delta: float, sample: Dictionary, paused: bool) -> Array:
	var opened: Array = []
	var zone := in_zone(sample)
	for i in range(3):
		if not unlocked[i] and not paused:
			hold[i] = hold[i] + delta if zone[i] else 0.0
			if hold[i] >= HOLD_TIME:
				unlocked[i] = true
				opened.append(i)
	return opened


func all_unlocked() -> bool:
	return unlocked[0] and unlocked[1] and unlocked[2]


## 0..1 per lock: how far the hold has gone (1 when unlocked).
func progress(i: int) -> float:
	return 1.0 if unlocked[i] else hold[i] / HOLD_TIME
