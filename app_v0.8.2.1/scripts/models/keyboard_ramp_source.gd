extends RefCounted
## Model (input source) — simulated moment for the balloon game when no real sensor is connected (v0.6.0).
## The balloon needs slow, gradual force, so keys change the moment at a steady rate and it stays where
## it is when no key is held (unlike the carrot game's spring-back keyboard input).
##   → / D / E (or ↑ / W) = add force slowly      ← / A / Q (or ↓) = let go (faster)
##   hold Shift = push too hard                    hold S = off-axis warning

const UP_RATE := 0.10   ## N·m per second while adding force
const DOWN_RATE := 0.30 ## N·m per second while letting go

var overload := 0.40
var offaxis_limit := 0.30
var _m := 0.0


func _init(over := 0.40, off_limit := 0.30) -> void:
	overload = over
	offaxis_limit = off_limit


func read(delta: float) -> Dictionary:
	var up := Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_E) \
		or Input.is_key_pressed(KEY_UP) or Input.is_key_pressed(KEY_W)
	var down := Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_Q) \
		or Input.is_key_pressed(KEY_DOWN)
	if up and not down:
		_m += UP_RATE * delta
	elif down and not up:
		_m = maxf(0.0, _m - DOWN_RATE * delta)
	_m = clampf(_m, 0.0, overload * 1.2)
	var shown := _m
	if Input.is_key_pressed(KEY_SHIFT):
		shown = overload * 1.15
	return {
		"moment_nm": shown + sin(Time.get_ticks_msec() * 0.007) * 0.003,
		"offaxis_nm": offaxis_limit * 1.5 if Input.is_key_pressed(KEY_S) else 0.0,
		"pull_n": 0.0,
	}
