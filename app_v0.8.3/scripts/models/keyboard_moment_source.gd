extends RefCounted
## Model (input source) — simulated moment for the carrot game when no real sensor is connected (v0.5.4;
## v0.8.3: key combinations, see keyboard_keys.gd). Unlike sim_sensor.gd it springs back to centre on
## release, like a relaxing hand.
##   ← / A / Q  = push left (negative moment)    → / D / E = push right (positive moment)
##   v0.8.3:
##   Z / X (Ctrl) = push and return slower / faster
##   hold 1–5 with a direction = how hard: 1 too light (never reaches the green zone) · 2 low edge of the
##     zone · 3 middle · 4 high edge · 5 past the zone but not yet too hard
##   F = automatic rocking: push to one side, hold, back to centre, other side, and so on.
##     Combines with Z / X, 1–5, G / H, S, P, Shift; R while F is held keeps pushing the same side.
##   Shift = push too hard   G / H = tremor   S = off-axis   P = pulling too hard

const Keys := preload("res://app_v0.8.3/scripts/models/keyboard_keys.gd")

const RATE := 0.9 ## N·m per second
const AUTO_HOLD := 0.7 ## s held in place by the automatic rocking (the game needs 0.5 s)
const AUTO_REST := 0.3 ## s at centre between pushes
const TREMOR := [0.0, 0.02, 0.06] ## N·m: none, G, H

var band_min := 0.15
var band_max := 0.30
var band_mid := 0.225
var overload := 0.40
var offaxis_limit := 0.30
var pull_limit := 30.0
var _kb := 0.0
var _t := 0.0
var active := PackedStringArray()   ## what is in effect this frame (keyboard_keys.gd codes)
# automatic rocking
var _auto_side := 1
var _auto_phase := 0   # 0 push, 1 hold, 2 return, 3 rest
var _auto_t := 0.0


func _init(mid := 0.225, over := 0.40, off_limit := 0.30, b_min := 0.15, b_max := 0.30, pull_lim := 30.0) -> void:
	band_mid = mid
	overload = over
	offaxis_limit = off_limit
	band_min = b_min
	band_max = b_max
	pull_limit = pull_lim


## How hard a push goes for a held 1–5 key (N·m).
func magnitude(level: int) -> float:
	match level:
		1:
			return band_min * 0.5
		2:
			return band_min + 0.01
		4:
			return band_max - 0.01
		5:
			return (band_max + overload) / 2.0
	return band_mid


## Same keys as read() of a real source: moment_nm, offaxis_nm, pull_n.
func read(delta: float) -> Dictionary:
	_t += delta
	var st := Keys.state()
	active = Keys.active(st)
	var mag := magnitude(int(st["level"]))
	if st["over"]:
		mag = overload * 1.15
	var rate: float = RATE * float(st["speed"])
	var target := 0.0
	var manual: bool = st["right"] or st["left"]
	if st["right"]:
		target += mag
	if st["left"]:
		target -= mag
	if not manual and st["auto"]:
		target = _auto_step(delta, mag, bool(st["same"]))
	elif not st["auto"]:
		_auto_phase = 0
		_auto_t = 0.0
	_kb = move_toward(_kb, target, rate * delta)
	var m := _kb + Keys.tremor(_t, float(TREMOR[int(st["wobble"])]))
	return {
		"moment_nm": m + sin(Time.get_ticks_msec() * 0.007) * 0.004,
		"offaxis_nm": offaxis_limit * 1.5 if st["offaxis"] else 0.0,
		"pull_n": pull_limit * 1.5 if st["pull"] else 0.0,
	}


## Automatic rocking: where the moment should go now.
func _auto_step(delta: float, mag: float, same_side: bool) -> float:
	var aim := float(_auto_side) * mag
	match _auto_phase:
		0:
			if absf(_kb - aim) < 0.005:
				_auto_phase = 1
				_auto_t = 0.0
			return aim
		1:
			_auto_t += delta
			if _auto_t >= AUTO_HOLD:
				_auto_phase = 2
			return aim
		2:
			if absf(_kb) < 0.005:
				_auto_phase = 3
				_auto_t = 0.0
			return 0.0
		_:
			_auto_t += delta
			if _auto_t >= AUTO_REST:
				_auto_phase = 0
				if not same_side:
					_auto_side = -_auto_side
			return 0.0
