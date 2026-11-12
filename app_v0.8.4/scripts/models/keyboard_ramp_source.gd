extends RefCounted
## Model (input source) — simulated moment for the balloon game when no real sensor is connected (v0.6.0;
## v0.8.3: key combinations, see keyboard_keys.gd).
## The balloon needs slow, gradual force, so keys change the moment at a steady rate and it stays where
## it is when no key is held (unlike the carrot game's spring-back keyboard input).
##   → / D / E (or ↑ / W) = add force      ← / A / Q (or ↓) = let go (faster)
##   v0.8.3: adding force runs at the standard ramp speed of the current balloon (target ÷ ramp time),
##   Z / X (Ctrl) make it slower / faster. Hold 1–5 and the moment moves by itself to that strength,
##   relative to the current target T and tolerance tol:
##     1 = T × 0.4 (too light)  2 = T − 1.5·tol, at least T × 0.6 (low)  3 = T  4 = T + 1.5·tol (high)
##     5 = above the safe line and T + 3·tol (stretch marks, but no pop)
##   F = automatic: follows the standard ramp to the target (or to the 1–5 strength), holds, lets go
##   when the balloon is tied, then starts the next one. Combines with Z / X, 1–5, G / H, S, P, Shift.
##   Shift = too hard (pops)   G / H = tremor   S = off-axis   P = pulling too hard
## The presenter tells it about the current balloon each frame with set_context().

const Keys := preload("res://app_v0.8.4/scripts/models/keyboard_keys.gd")

const UP_RATE := 0.10   ## N·m per second while adding force, when no balloon is known yet
const DOWN_RATE := 0.30 ## N·m per second while letting go
const TREMOR := [0.0, 0.6, 2.0]   ## tremor amplitude in units of tol: none, G, H

var overload := 0.40
var safe_max := 0.34
var offaxis_limit := 0.30
var pull_limit := 30.0
var _m := 0.0
var _t := 0.0
# context from the model (set_context)
var _inflating := false
var _target := 0.2
var _ramp := 3.0
var _tol := 0.04
var active := PackedStringArray()   ## what is in effect this frame (keyboard_keys.gd codes)


func _init(over := 0.40, off_limit := 0.30, safe := 0.34, pull_lim := 30.0) -> void:
	overload = over
	offaxis_limit = off_limit
	safe_max = safe
	pull_limit = pull_lim


## v0.8.3: the balloon being inflated now (inflating = false between balloons).
func set_context(inflating: bool, target: float, ramp_time: float, tol: float) -> void:
	_inflating = inflating
	_target = target
	_ramp = maxf(ramp_time, 0.1)
	_tol = tol


## Strength for a held 1–5 key (N·m).
func level_value(level: int) -> float:
	match level:
		1:
			return _target * 0.4
		2:
			return maxf(_target - 1.5 * _tol, _target * 0.6)
		4:
			return _target + 1.5 * _tol
		5:
			# above the safe line and clearly above the target, but below the pop
			return minf(maxf((safe_max + overload) / 2.0, _target + 3.0 * _tol), overload - 0.01)
	return _target


func read(delta: float) -> Dictionary:
	_t += delta
	var st := Keys.state()
	active = Keys.active(st)
	var level: int = st["level"]
	var speed: float = st["speed"]
	var up_rate := (_target / _ramp if _target > 0.0 else UP_RATE) * speed
	var down_rate := DOWN_RATE * maxf(speed, 1.0)
	var up: bool = st["right"] or st["up"]
	var down: bool = st["left"] or st["down"]
	if up and not down:
		_m += up_rate * delta
	elif down and not up:
		_m = maxf(0.0, _m - down_rate * delta)
	elif st["auto"]:
		# automatic: to the target (or the chosen strength) at the standard speed, back to 0 between balloons
		var aim := level_value(level) if _inflating else 0.0
		_m = move_toward(_m, aim, (up_rate if aim > _m else down_rate) * delta)
	elif level > 0:
		var aim2 := level_value(level)
		_m = move_toward(_m, aim2, (up_rate if aim2 > _m else down_rate) * delta)
	_m = clampf(_m, 0.0, overload * 1.2)
	var shown := _m
	if st["over"]:
		shown = overload * 1.15
	shown += Keys.tremor(_t, float(TREMOR[int(st["wobble"])]) * _tol)
	shown += sin(Time.get_ticks_msec() * 0.007) * 0.003
	return {
		"moment_nm": maxf(shown, 0.0),
		"offaxis_nm": offaxis_limit * 1.5 if st["offaxis"] else 0.0,
		"pull_n": pull_limit * 1.5 if st["pull"] else 0.0,
	}
