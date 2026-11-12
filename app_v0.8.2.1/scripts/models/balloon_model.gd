extends RefCounted
## Model — rules of Rocking Challenge Level B, "Bunny's Balloons" (v0.6.0). No nodes, no drawing, no files.
##
## One direction only (positive target-axis moment). For each of BALLOONS balloons:
##   WAIT  back at centre for WAIT_TIME s → the balloon's guide starts
##   RAMP  the guide rises from 0 to the balloon's target over its ramp time; the player follows it.
##         Staying more than `lead` above the guide for LEAK_TIME s = too fast: the balloon leaks and
##         starts again (no mistake counted).
##   HOLD  stay within ±`tol` of the target for HOLD_TIME s in a row (leaving the band restarts the hold)
##   TIE   the balloon is tied to the carrot (TIE_TIME s), then the next one
## Moment above OVERLOAD at any time = the balloon pops: one mistake, locked until back at centre.
## More mistakes than the difficulty allows, or running out of time, ends the round.
## Off-axis moment / pull force above their limits only warn and pause the hold timer.
## All numbers are prototype placeholders, not validated or clinical values.

const OVERLOAD := 0.40 ## N·m：气球爆掉
const SAFE_MAX := 0.34 ## N·m：85% × 上限，目标值不会超过它，超过它开始显示拉伸纹
const NEUTRAL := 0.05 ## N·m：回到起点
const READY_TIME := 0.6 ## s：开局前在起点停留
const WAIT_TIME := 0.4 ## s：每个气球开始前在起点停留
const HOLD_TIME := 1.5 ## s
const TIE_TIME := 1.0 ## s
const LEAK_TIME := 0.25 ## s：超前太多持续这么久就漏气
const BALLOONS := 5
const OFFAXIS_LIMIT := 0.30
const PULL_LIMIT := 30.0
const OFFAXIS_COOLDOWN := 1.2

## Difficulty: mistakes allowed, timer, hints, target range, ramp time, hold band (±tol), how far ahead counts as too fast.
const DIFFICULTY := [
	{"mistakes": 5, "timed": false, "ring": true, "strip": true, "text": true,
		"tmin": 0.15, "tmax": 0.25, "ramp": 4.0, "tol": 0.05, "lead": 0.08},   # Intern
	{"mistakes": 3, "timed": true, "ring": true, "strip": false, "text": false,
		"tmin": 0.15, "tmax": 0.30, "ramp": 3.0, "tol": 0.04, "lead": 0.06},   # Trainee Dentist
	{"mistakes": 0, "timed": true, "ring": false, "strip": false, "text": false,
		"tmin": 0.20, "tmax": 0.32, "ramp": 2.5, "tol": 0.03, "lead": 0.05},   # Master Dentist
]

enum Phase { READY, PLAYING, WIN, LOSE }
enum Stage { WAIT, RAMP, HOLD, TIE }

# ---- configuration
var difficulty := 1
var time_limit := 90.0
var allowed := 3
var timed := true
var ring_hint := true
var strip_hint := false
var text_hints := false
var tol := 0.04
var lead_tol := 0.06
var targets: Array = []        # N·m per balloon
var ramp_times: Array = []     # s per balloon

# ---- round state
var phase := Phase.READY
var result := ""
var clock := 0.0
var t0 := -1.0
var time_left := 90.0
var elapsed := 0.0
var ready_t := 0.0
var stage := Stage.WAIT
var step_t := 0.0
var guide := 0.0               # where the moment should be now (N·m)
var hold_t := 0.0
var lead_t := 0.0
var latched := false
var tied := 0
var mistakes := 0
var leaks := 0
var hold_drops := 0
var ears := 0
var peak := 0.0                 # highest moment while playing (N·m) (v0.7.1, achievements)
var daydream_t := 0.0           # time in HOLD below half the target (v0.7.1, "Daydreamer")
var daydream_max := 0.0
var offaxis_cool := 0.0
var torque := 0.0
var offaxis := 0.0
var pull := 0.0

# ---- recorded samples (PLAYING only) and timed events, for evaluation
var s_t := PackedFloat32Array()
var s_m := PackedFloat32Array()
var s_off := PackedFloat32Array()
var s_pull := PackedFloat32Array()
var s_guide := PackedFloat32Array()    # -1 when no balloon is being inflated
var s_target := PackedFloat32Array()   # -1 when no balloon is being inflated
var s_step := PackedInt32Array()
var events: Array = []

# ---- current balloon's trace (for the strip chart in Intern mode)
var cur_t := PackedFloat32Array()
var cur_m := PackedFloat32Array()
var cur_g := PackedFloat32Array()

# ---- this frame
var frame_events := PackedStringArray()   # start, balloon_n, leak, hold_drop, pop, tie_n, offaxis, win, lose_broken, lose_timeout, abort

# ---- state for the view
var inflating := false         # a balloon is on the hose and follows the moment
var ring_state := "ok"         # "ok", "fast" (ahead of the guide), "slow" (behind)
var hold_frac := 0.0
var near_limit := false
var status_key := ""           # "", "ready", "relax", "relax_next", "too_fast", "follow", "hold"


func _init(diff := 1, limit := 90.0, rng_seed := -1) -> void:
	difficulty = clampi(diff, 0, DIFFICULTY.size() - 1)
	time_limit = limit
	var cfg: Dictionary = DIFFICULTY[difficulty]
	allowed = cfg["mistakes"]
	timed = cfg["timed"]
	ring_hint = cfg["ring"]
	strip_hint = cfg["strip"]
	text_hints = cfg["text"]
	tol = cfg["tol"]
	lead_tol = cfg["lead"]
	time_left = time_limit
	var rng := RandomNumberGenerator.new()
	if rng_seed >= 0:
		rng.seed = rng_seed
	else:
		rng.randomize()
	var base_ramp: float = cfg["ramp"]
	for i in BALLOONS:
		var target := snappedf(rng.randf_range(cfg["tmin"], cfg["tmax"]), 0.01)
		targets.append(minf(target, SAFE_MAX))
		ramp_times.append(snappedf(base_ramp + rng.randf_range(-0.5, 0.5), 0.1))


func is_active() -> bool:
	return phase == Phase.READY or phase == Phase.PLAYING


func current_target() -> float:
	return targets[mini(tied, BALLOONS - 1)]


func current_ramp() -> float:
	return ramp_times[mini(tied, BALLOONS - 1)]


# =====================================================================
func step(delta: float, torque_nm: float, offaxis_nm: float, pull_n: float) -> void:
	clock += delta
	frame_events = PackedStringArray()
	torque = torque_nm
	offaxis = offaxis_nm
	pull = pull_n
	match phase:
		Phase.READY:
			_step_ready(delta)
		Phase.PLAYING:
			_step_playing(delta)
	if phase == Phase.PLAYING and t0 >= 0.0:
		var t := clock - t0
		s_t.append(t)
		s_m.append(torque)
		s_off.append(offaxis)
		s_pull.append(pull)
		s_guide.append(guide if inflating else -1.0)
		s_target.append(current_target() if inflating else -1.0)
		s_step.append(stage)
		if inflating:
			cur_t.append(t)
			cur_m.append(torque)
			cur_g.append(guide)


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
			stage = Stage.WAIT
			step_t = WAIT_TIME   # already at centre: the first balloon starts at once
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

	var x := maxf(torque, 0.0)
	near_limit = x > SAFE_MAX
	hold_frac = 0.0
	peak = maxf(peak, x)
	if stage != Stage.HOLD or latched:
		daydream_t = 0.0

	if latched:
		inflating = false
		status_key = "relax_next"
		if x < NEUTRAL:
			latched = false
			stage = Stage.WAIT
			step_t = 0.0
		return

	if x > OVERLOAD:
		_pop()
		return

	match stage:
		Stage.WAIT:
			inflating = false
			guide = 0.0
			if x < NEUTRAL:
				step_t += delta
				status_key = ""
				if step_t >= WAIT_TIME:
					_start_balloon()
			else:
				step_t = 0.0
				status_key = "relax_next"
		Stage.RAMP:
			inflating = true
			step_t += delta
			var ramp: float = current_ramp()
			guide = current_target() * minf(1.0, step_t / ramp)
			var lead := x - guide
			if lead > lead_tol:
				lead_t += delta
				ring_state = "fast"
				status_key = "too_fast" if text_hints else ""
				if lead_t >= LEAK_TIME:
					_leak()
					return
			else:
				lead_t = 0.0
				ring_state = "ok" if absf(lead) <= lead_tol else "slow"
				status_key = ("follow" if ring_state == "slow" else "") if text_hints else ""
			if step_t >= ramp:
				stage = Stage.HOLD
				step_t = 0.0
				hold_t = 0.0
		Stage.HOLD:
			inflating = true
			guide = current_target()
			# the ring is already full size but the balloon is not even half way (v0.7.1)
			if x < 0.5 * guide:
				daydream_t += delta
				daydream_max = maxf(daydream_max, daydream_t)
			else:
				daydream_t = 0.0
			var inside := absf(x - guide) <= tol
			if inside:
				if not off_bad:
					hold_t += delta
				ring_state = "ok"
			else:
				if hold_t > 0.0:
					hold_drops += 1
					_event("hold_drop")
				hold_t = 0.0
				ring_state = "fast" if x > guide else "slow"
			status_key = "hold" if text_hints else ""
			hold_frac = clampf(hold_t / HOLD_TIME, 0.0, 1.0)
			if hold_t >= HOLD_TIME:
				_tie()
		Stage.TIE:
			inflating = false
			step_t += delta
			if step_t >= TIE_TIME:
				stage = Stage.WAIT
				step_t = 0.0


func _start_balloon() -> void:
	stage = Stage.RAMP
	step_t = 0.0
	lead_t = 0.0
	guide = 0.0
	inflating = true
	ring_state = "ok"
	cur_t = PackedFloat32Array()
	cur_m = PackedFloat32Array()
	cur_g = PackedFloat32Array()
	_event("balloon_%d" % (tied + 1))


func _leak() -> void:
	leaks += 1
	inflating = false
	stage = Stage.WAIT
	step_t = 0.0
	lead_t = 0.0
	_event("leak")


func _pop() -> void:
	latched = true
	inflating = false
	mistakes += 1
	hold_t = 0.0
	stage = Stage.WAIT
	step_t = 0.0
	_event("pop")
	if mistakes > allowed:
		_end("broken")


func _tie() -> void:
	tied += 1
	inflating = false
	hold_t = 0.0
	stage = Stage.TIE
	step_t = 0.0
	status_key = ""
	_event("tie_%d" % tied)
	if tied >= BALLOONS:
		_end("win")


func _end(res: String) -> void:
	result = res
	inflating = false
	if res == "win":
		phase = Phase.WIN
		_event("win")
	else:
		phase = Phase.LOSE
		_event("lose_broken" if res == "broken" else "lose_timeout")


# =====================================================================
func summary() -> Dictionary:
	return {
		"difficulty": difficulty, "result": result, "tied": tied, "balloons": BALLOONS,
		"mistakes": mistakes, "allowed": allowed, "elapsed": elapsed, "leaks": leaks,
		"hold_drops": hold_drops, "ears": ears, "peak": peak, "daydream_max": daydream_max,
	}


func params() -> Dictionary:
	var mean_ramp := 0.0
	for r in ramp_times:
		mean_ramp += r
	mean_ramp /= ramp_times.size()
	return {"overload": OVERLOAD, "safe_max": SAFE_MAX, "neutral": NEUTRAL, "hold": HOLD_TIME, "tie": TIE_TIME,
		"wait": WAIT_TIME, "balloons": BALLOONS, "tol": tol, "lead": lead_tol, "mean_ramp": mean_ramp,
		"offaxis_limit": OFFAXIS_LIMIT, "pull_limit": PULL_LIMIT}


func evaluation_data(sensor_used: bool) -> Dictionary:
	return {
		"game": "balloon", "params": params(),
		"t": s_t, "m": s_m, "off": s_off, "pull": s_pull, "guide": s_guide, "target": s_target, "step": s_step,
		"events": events.duplicate(), "result": result, "sensor": sensor_used, "difficulty": difficulty,
		"mistakes": mistakes, "allowed": allowed, "tied": tied,
	}


func log_header(sensor_used: bool) -> String:
	var p := params()
	return "# game=balloon difficulty=%d allowed_mistakes=%d timed=%s time_limit=%.0f overload=%.2f safe_max=%.2f neutral=%.2f hold=%.2f tol=%.3f lead=%.3f balloons=%d mean_ramp=%.2f offaxis_limit=%.2f pull_limit=%.1f targets=%s ramps=%s input=%s" % [
		difficulty, allowed, str(timed), time_limit, OVERLOAD, SAFE_MAX, NEUTRAL, HOLD_TIME, tol, lead_tol, BALLOONS,
		p["mean_ramp"], OFFAXIS_LIMIT, PULL_LIMIT,
		"/".join(PackedStringArray(targets.map(func(v): return "%.2f" % v))),
		"/".join(PackedStringArray(ramp_times.map(func(v): return "%.1f" % v))),
		"sensor" if sensor_used else "keyboard"]


const LOG_COLUMNS := "t_s,moment_nm,offaxis_nm,pull_n,phase,step,guide_nm,target_nm,tied,mistakes,event"


func log_row() -> String:
	return "%.3f,%.4f,%.4f,%.3f,%s,%s,%.4f,%.4f,%d,%d,%s" % [
		clock, torque, offaxis, pull, Phase.keys()[phase], Stage.keys()[stage],
		guide if inflating else -1.0, current_target() if inflating else -1.0, tied, mistakes, ";".join(frame_events)]
