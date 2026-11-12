extends RefCounted
## Model (input source) — simulated moment for the carrot game when no real sensor is connected (v0.5.4;
## behaviour unchanged from carrot_game.gd v0.5.3). Unlike sim_sensor.gd it springs back to centre on release,
## like a relaxing hand.
##   ← / A / Q  = push left (negative moment)    → / D / E = push right (positive moment)
##   hold Shift  = push too hard                  hold S    = off-axis warning

const RATE := 0.9 ## N·m per second

var band_mid := 0.225
var overload := 0.40
var offaxis_limit := 0.30
var _kb := 0.0
var _t := 0.0


func _init(mid := 0.225, over := 0.40, off_limit := 0.30) -> void:
	band_mid = mid
	overload = over
	offaxis_limit = off_limit


## Same keys as read() of a real source: moment_nm, offaxis_nm, pull_n.
func read(delta: float) -> Dictionary:
	_t += delta
	var mag := band_mid
	if Input.is_key_pressed(KEY_SHIFT):
		mag = overload * 1.15
	var target := 0.0
	if Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_E):
		target += mag
	if Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_Q):
		target -= mag
	_kb = move_toward(_kb, target, RATE * delta)
	return {
		"moment_nm": _kb + sin(Time.get_ticks_msec() * 0.007) * 0.004,
		"offaxis_nm": offaxis_limit * 1.5 if Input.is_key_pressed(KEY_S) else 0.0,
		"pull_n": 0.0,
	}
