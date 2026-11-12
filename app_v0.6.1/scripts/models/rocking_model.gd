extends RefCounted
## Model — rules of Rocking Challenge Level A, "Pull the Carrot" (v0.5.4).
## Moved unchanged from carrot_game.gd (v0.5.3). No nodes, no drawing, no files: the presenter feeds one
## moment sample per frame with step() and reads back state and this frame's events.
##
## Only the target-axis moment counts. Positive = carrot tilts right, negative = left.
## Half-rock = push into the green zone, hold HOLD_TIME s, return to centre. Sides must alternate.
## Left + right = one rock; cycles_to_win rocks clear the round. Moment above OVERLOAD = one mistake;
## more mistakes than the difficulty allows snaps the carrot. Off-axis moment / pull force above their
## limits only warn and pause the hold timer.
## All numbers are prototype placeholders, not validated or clinical values.

const BAND_MIN := 0.15 ## N·m，绿色区间下沿
const BAND_MAX := 0.30 ## N·m，绿色区间上沿
const OVERLOAD := 0.40 ## N·m，超过记一次“用力过猛”
const NEUTRAL := 0.05 ## N·m，低于此值视为回到中位
const HOLD_TIME := 0.5 ## 秒
const READY_TIME := 0.6 ## 秒：开局前在中位停留这么久才开始
const OFFAXIS_LIMIT := 0.30 ## N·m（真实传感器接入后使用）
const PULL_LIMIT := 30.0 ## N（真实传感器接入后使用）
const OFFAXIS_COOLDOWN := 1.2 ## 秒：两次偏轴提醒的最短间隔

## Difficulty settings (game setting.md, section 5).
const DIFFICULTY := [
	{"mistakes": 5, "timed": false, "zone": true, "text": true},  # Intern
	{"mistakes": 3, "timed": true, "zone": true, "text": false},  # Trainee Dentist
	{"mistakes": 0, "timed": true, "zone": false, "text": false}, # Master Dentist
]

enum Phase { READY, PLAYING, WIN, LOSE }

# ---- configuration
var difficulty := 1
var cycles_to_win := 6
var time_limit := 90.0
var allowed := 3
var timed := true
var zone_hints := true
var text_hints := false

# ---- round state
var phase := Phase.READY
var result := ""               # "win" / "broken" / "timeout" / "abort" once the round has ended
var clock := 0.0               # seconds since the model was created; used for samples, events and the log
var t0 := -1.0                 # clock at the "start" event
var time_left := 90.0
var elapsed := 0.0
var ready_t := 0.0
var half_count := 0
var cycles := 0
var expected_side := 0
var pending_side := 0
var hold_t := 0.0
var overload_latched := false
var mistakes := 0
var offaxis_cool := 0.0
var torque := 0.0
var offaxis := 0.0
var pull := 0.0

# ---- statistics used by achievements
var clean_holds := true        # every hold in the green zone succeeded first time
var over_band := false         # moment went above the green zone at some point
var ears := 0                  # off-axis warnings
var push_armed := true         # after returning to centre, the next push past BAND_MIN counts as a push
var last_push_side := 0
var same_side_run := 0

# ---- recorded samples (PLAYING phase only) and timed events, for evaluation
var s_t := PackedFloat32Array()
var s_m := PackedFloat32Array()
var s_off := PackedFloat32Array()
var s_pull := PackedFloat32Array()
var events: Array = []         # [t from start, name]

# ---- what happened this frame (reset at the start of every step)
var frame_events := PackedStringArray()   # logged names: start, offaxis, hold_ok_L/R, half_n, rock_n, overload, win, lose_broken, lose_timeout, abort
var frame_achievements := PackedStringArray()  # achievement ids reached during play (rock_shh, rock_wrong_side)

# ---- state for the view, recomputed every step
var hold_pos := 0.0            # 0..1 hold progress on the positive (right) side
var hold_neg := 0.0            # 0..1 on the negative (left) side
var near_limit := false        # above the green zone
var sparkle := false           # holding in the zone (shown only with zone hints)
var tint := "normal"           # "normal", "near" (above zone), "latched" (after a mistake, until back at centre)
var status_key := ""           # "", "ready", "relax", "other_side"
var flash_side := 0            # side whose hold just completed this frame
var hint_side := 0             # side the player should push (wrong side pushed this frame)


func _init(diff := 1, rocks := 6, limit := 90.0) -> void:
	difficulty = clampi(diff, 0, DIFFICULTY.size() - 1)
	cycles_to_win = rocks
	time_limit = limit
	var cfg: Dictionary = DIFFICULTY[difficulty]
	allowed = cfg["mistakes"]
	timed = cfg["timed"]
	zone_hints = cfg["zone"]
	text_hints = cfg["text"]
	time_left = time_limit


func is_active() -> bool:
	return phase == Phase.READY or phase == Phase.PLAYING


func progress() -> float:
	return float(half_count) / float(cycles_to_win * 2)


# =====================================================================
## One frame. torque in N·m (signed), offaxis and pull as magnitudes.
func step(delta: float, torque_nm: float, offaxis_nm: float, pull_n: float) -> void:
	clock += delta
	frame_events = PackedStringArray()
	frame_achievements = PackedStringArray()
	flash_side = 0
	hint_side = 0
	torque = torque_nm
	offaxis = offaxis_nm
	pull = pull_n
	match phase:
		Phase.READY:
			_step_ready(delta)
		Phase.PLAYING:
			_step_playing(delta)
	if phase == Phase.PLAYING and t0 >= 0.0:
		s_t.append(clock - t0)
		s_m.append(torque)
		s_off.append(offaxis)
		s_pull.append(pull)


## Player quit (Esc). Only counts while playing.
func abort() -> bool:
	if phase != Phase.PLAYING:
		return false
	frame_events = PackedStringArray()
	_event("abort")
	result = "abort"
	return true


func _event(n: String) -> void:
	frame_events.append(n)
	if n == "start":
		t0 = clock
	elif t0 >= 0.0:
		events.append([clock - t0, n])


func _step_ready(delta: float) -> void:
	if absf(torque) < NEUTRAL:
		status_key = "ready"
		ready_t += delta
		if ready_t >= READY_TIME:
			phase = Phase.PLAYING
			status_key = ""
			_event("start")
	else:
		status_key = "relax"
		ready_t = 0.0


func _step_playing(delta: float) -> void:
	elapsed += delta
	if timed:
		time_left -= delta
		if time_left <= 0.0:
			time_left = 0.0
			_end("timeout")
			return

	var off_bad := offaxis > OFFAXIS_LIMIT or pull > PULL_LIMIT
	offaxis_cool = maxf(0.0, offaxis_cool - delta)
	if off_bad and offaxis_cool <= 0.0:
		offaxis_cool = OFFAXIS_COOLDOWN
		_event("offaxis")
		ears += 1
		if ears == 3:
			frame_achievements.append("rock_shh")

	var a := absf(torque)
	var s := int(signf(torque))
	hold_pos = 0.0
	hold_neg = 0.0
	near_limit = a > BAND_MAX
	sparkle = false
	tint = "normal"

	# one "push" = from centre to past the green zone's lower edge; used to spot same-side repeats
	if a < NEUTRAL:
		push_armed = true
	elif push_armed and a >= BAND_MIN:
		push_armed = false
		same_side_run = same_side_run + 1 if s == last_push_side else 1
		last_push_side = s
		if same_side_run == 5:
			frame_achievements.append("rock_wrong_side")
	if a > BAND_MAX:
		over_band = true

	if overload_latched:
		tint = "latched"
		if a < NEUTRAL:
			overload_latched = false
		return

	if a > OVERLOAD:
		_on_overload()
		return

	if a > BAND_MAX:
		tint = "near"

	if pending_side != 0:
		if a < NEUTRAL:
			_on_half_complete(pending_side)
			pending_side = 0
		else:
			_set_hold(pending_side, 1.0)
		return

	if a >= BAND_MIN and a <= BAND_MAX:
		if expected_side == 0 or s == expected_side:
			if not off_bad:
				hold_t += delta
			sparkle = zone_hints
			_set_hold(s, hold_t / HOLD_TIME)
			if hold_t >= HOLD_TIME:
				pending_side = s
				hold_t = 0.0
				flash_side = s
				_event("hold_ok_" + ("R" if s > 0 else "L"))
		else:
			hold_t = 0.0
			if zone_hints:
				hint_side = expected_side
			if text_hints:
				status_key = "other_side"
	else:
		if hold_t > 0.0:
			clean_holds = false  # dropped out of the zone part-way through a hold
		hold_t = 0.0
		if a < NEUTRAL:
			status_key = ""


func _set_hold(s: int, f: float) -> void:
	if s > 0:
		hold_pos = clampf(f, 0.0, 1.0)
	else:
		hold_neg = clampf(f, 0.0, 1.0)


func _on_half_complete(s: int) -> void:
	half_count += 1
	expected_side = -s
	status_key = ""
	if half_count % 2 == 0:
		cycles += 1
		_event("rock_%d" % cycles)
		if cycles >= cycles_to_win:
			_end("win")
	else:
		_event("half_%d" % half_count)


func _on_overload() -> void:
	overload_latched = true
	if hold_t > 0.0:
		clean_holds = false
	hold_t = 0.0
	pending_side = 0
	mistakes += 1
	_event("overload")
	if mistakes > allowed:
		_end("broken")


func _end(res: String) -> void:
	result = res
	if res == "win":
		phase = Phase.WIN
		_event("win")
	else:
		phase = Phase.LOSE
		_event("lose_broken" if res == "broken" else "lose_timeout")


# =====================================================================
## Snapshot for the achievements database (record_round adds game, hour, log file, mid-round ids).
func summary() -> Dictionary:
	return {
		"difficulty": difficulty,
		"result": result,
		"rocks": cycles,
		"rocks_to_win": cycles_to_win,
		"mistakes": mistakes,
		"allowed": allowed,
		"elapsed": elapsed,
		"clean_holds": clean_holds,
		"over_band": over_band,
		"ears": ears,
		"same_side_max": same_side_run,
	}


## Data for evaluation.gd (same shape evaluation.load_csv() builds from a log).
func evaluation_data(sensor_used: bool) -> Dictionary:
	return {
		"params": params(),
		"t": s_t, "m": s_m, "off": s_off, "pull": s_pull, "events": events.duplicate(),
		"result": result, "sensor": sensor_used, "difficulty": difficulty,
		"mistakes": mistakes, "allowed": allowed, "rocks": cycles,
	}


func params() -> Dictionary:
	return {"band_min": BAND_MIN, "band_max": BAND_MAX, "overload": OVERLOAD, "neutral": NEUTRAL,
		"hold": HOLD_TIME, "rocks_to_win": cycles_to_win, "offaxis_limit": OFFAXIS_LIMIT, "pull_limit": PULL_LIMIT}


## First line of the round's CSV log (read back by evaluation.load_csv()).
func log_header(sensor_used: bool) -> String:
	return "# game=rocking_A difficulty=%d allowed_mistakes=%d timed=%s time_limit=%.0f band=%.2f-%.2f overload=%.2f neutral=%.2f hold=%.2f rocks_to_win=%d offaxis_limit=%.2f pull_limit=%.1f input=%s" % [
		difficulty, allowed, str(timed), time_limit, BAND_MIN, BAND_MAX, OVERLOAD, NEUTRAL, HOLD_TIME, cycles_to_win,
		OFFAXIS_LIMIT, PULL_LIMIT, "sensor" if sensor_used else "keyboard"]


## One CSV row for this frame.
func log_row() -> String:
	return "%.3f,%.4f,%.4f,%.3f,%s,%.3f,%d,%d,%d,%s" % [
		clock, torque, offaxis, pull, Phase.keys()[phase], hold_t, half_count, cycles, mistakes, ";".join(frame_events)]
