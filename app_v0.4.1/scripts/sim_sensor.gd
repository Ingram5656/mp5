extends Node
## Simulated sensor for the entry test. Keyboard drives the three derived values:
##   Left / Right  -> force direction (deg)
##   Up / Down     -> force magnitude (N)
##   Q / E         -> target-axis moment (N·m)
## Replace with a live source that reads the acquisition program (/api/state) later.

var connected: bool = false
var direction_deg: float = 160.0
var force_n: float = 0.0
var moment_nm: float = 0.0

const DIR_RATE := 70.0     # deg per second
const FORCE_RATE := 8.0    # N per second
const MOMENT_RATE := 0.25  # N·m per second
const MAX_FORCE := 20.0
const MAX_MOMENT := 0.5

var _t: float = 0.0


func connect_sensor() -> bool:
	connected = true
	return true


## Put the simulated values back outside the target zones (used when the check is repeated).
func reset_values() -> void:
	direction_deg = 160.0
	force_n = 0.0
	moment_nm = 0.0


func is_valid() -> bool:
	return connected


func _process(delta: float) -> void:
	if not connected:
		return
	_t += delta
	if Input.is_key_pressed(KEY_LEFT):
		direction_deg += DIR_RATE * delta
	if Input.is_key_pressed(KEY_RIGHT):
		direction_deg -= DIR_RATE * delta
	if Input.is_key_pressed(KEY_UP):
		force_n += FORCE_RATE * delta
	if Input.is_key_pressed(KEY_DOWN):
		force_n -= FORCE_RATE * delta
	if Input.is_key_pressed(KEY_E):
		moment_nm += MOMENT_RATE * delta
	if Input.is_key_pressed(KEY_Q):
		moment_nm -= MOMENT_RATE * delta
	direction_deg = fposmod(direction_deg, 360.0)
	force_n = clampf(force_n, 0.0, MAX_FORCE)
	moment_nm = clampf(moment_nm, -MAX_MOMENT, MAX_MOMENT)


## Small jitter so the display looks like live data.
func read() -> Dictionary:
	return {
		"direction_deg": direction_deg + sin(_t * 9.0) * 0.8,
		"force_n": maxf(0.0, force_n + sin(_t * 11.0) * 0.08),
		"moment_nm": moment_nm + sin(_t * 7.0) * 0.004,
	}
