extends RefCounted
## Model — evaluation for the balloon game (Rocking Challenge Level B) (v0.6.0).
## Same six dimensions and weights as the carrot game, except that "rhythm & symmetry" is replaced by
## "ramp control" (how smoothly and how fast the force was built up). Formulas: design/评估方法_v0.6.0.md.
## All thresholds are placeholders, not validated values.
##
## Input `data` (BalloonModel.evaluation_data() or load_csv()):
##   params: overload, safe_max, neutral, hold, tie, wait, balloons, tol, lead, mean_ramp, offaxis_limit, pull_limit
##   t, m, off, pull, guide, target: PackedFloat32Array (guide/target = -1 when no balloon is being inflated)
##   step: PackedInt32Array (0 WAIT, 1 RAMP, 2 HOLD, 3 TIE)
##   events: [[t, name]] — balloon_n, leak, hold_drop, pop, tie_n, offaxis, win, lose_*, abort
##   result, sensor, difficulty

const WEIGHTS := {"safety": 25.0, "accuracy": 25.0, "stability": 20.0, "ramp": 15.0, "efficiency": 10.0, "direction": 5.0}
const ORDER := ["safety", "accuracy", "stability", "ramp", "efficiency", "direction"]
const GRADES := [[90.0, "S"], [80.0, "A"], [70.0, "B"], [60.0, "C"], [0.0, "D"]]
const TRACK_SCALE := 0.10 ## N·m：跟踪误差达到这个值记 0 分
const STEP_RAMP := 1
const STEP_HOLD := 2


static func _cl(x: float, lo := 0.0, hi := 100.0) -> float:
	return clampf(x, lo, hi)


static func _sd(v: Array) -> float:
	if v.is_empty():
		return 0.0
	var mu := 0.0
	for x in v:
		mu += x
	mu /= v.size()
	var s := 0.0
	for x in v:
		s += (x - mu) * (x - mu)
	return sqrt(s / v.size())


static func evaluate(data: Dictionary) -> Dictionary:
	var p: Dictionary = data["params"]
	var t: PackedFloat32Array = data["t"]
	var m: PackedFloat32Array = data["m"]
	var off: PackedFloat32Array = data["off"]
	var pull: PackedFloat32Array = data["pull"]
	var guide: PackedFloat32Array = data["guide"]
	var target: PackedFloat32Array = data["target"]
	var stp: PackedInt32Array = data["step"]
	var events: Array = data["events"]
	var n := t.size()
	var dur: float = (t[n - 1] - t[0]) if n > 1 else 0.0
	var tol: float = p["tol"]

	var pops := 0
	var leaks := 0
	var drops := 0
	var tie_t: Array = []
	for e in events:
		var ev_name: String = e[1]
		if ev_name == "pop":
			pops += 1
		elif ev_name == "leak":
			leaks += 1
		elif ev_name == "hold_drop":
			drops += 1
		elif ev_name.begins_with("tie_"):
			tie_t.append(float(e[0]))
	var ties := tie_t.size()

	var std := PackedFloat32Array()
	std.resize(n)
	for i in n:
		std[i] = maxf(guide[i], 0.0)

	# ---- 1. safety: pops, time above the safe maximum, peak
	var t_over := 0.0
	var peak := 0.0
	for i in n:
		var x := maxf(m[i], 0.0)
		peak = maxf(peak, x)
		if x > p["safe_max"] and i + 1 < n:
			t_over += t[i + 1] - t[i]
	var f_over: float = t_over / dur if dur > 0.0 else 0.0
	var pk := clampf((peak - p["safe_max"]) / (p["overload"] - p["safe_max"]), 0.0, 1.0)
	var safety := _cl(100.0 - 30.0 * pops - 150.0 * f_over - 20.0 * pk)

	# ---- 2. accuracy: following the guide while inflating, and closeness to the target while holding
	var sq := 0.0
	var sq_n := 0
	for i in n:
		if stp[i] == STEP_RAMP or stp[i] == STEP_HOLD:
			if guide[i] >= 0.0:
				sq += (m[i] - guide[i]) * (m[i] - guide[i])
				sq_n += 1
	var rmse: float = sqrt(sq / sq_n) if sq_n > 0 else TRACK_SCALE
	var dev_sum := 0.0
	var dev_n := 0
	var sds: Array = []
	for tt in tie_t:
		var settled: Array = []
		for i in n:
			if t[i] >= tt - p["hold"] and t[i] < tt and target[i] >= 0.0:
				dev_sum += minf(1.0, absf(m[i] - target[i]) / tol)
				dev_n += 1
				if t[i] >= tt - 0.6 * p["hold"]:
					settled.append(m[i])
		if settled.size() >= 3:
			sds.append(_sd(settled))
	var dev: float = dev_sum / dev_n if dev_n > 0 else 1.0
	var accuracy := 0.5 * _cl(100.0 * (1.0 - rmse / TRACK_SCALE)) + 0.5 * _cl(100.0 * (1.0 - dev))

	# ---- 3. stability: wobble in the settled part of each hold, and holds done without dropping out
	var sd_mean := tol
	if not sds.is_empty():
		sd_mean = 0.0
		for v in sds:
			sd_mean += v
		sd_mean /= sds.size()
	var first: float = float(ties) / float(ties + drops) if ties + drops > 0 else 0.0
	var stability := 0.5 * _cl(100.0 * (1.0 - sd_mean / (0.5 * tol))) + 0.5 * _cl(100.0 * first)

	# ---- 4. ramp control: rate of rise against the guide, steadiness (no backing off), leaks
	var rate_scores: Array = []
	var smooth_scores: Array = []
	var i0 := -1
	for i in range(n + 1):
		var in_ramp := i < n and stp[i] == STEP_RAMP and guide[i] >= 0.0
		if in_ramp and i0 < 0:
			i0 = i
		elif not in_ramp and i0 >= 0:
			var i1 := i - 1
			# only ramps that reached the hold count (a leaked ramp is counted as a leak)
			if i < n and stp[i] == STEP_HOLD and i1 - i0 >= 5:
				var dt_r := t[i1] - t[i0]
				var g_slope := (guide[i1] - guide[i0]) / maxf(dt_r, 0.001)
				var m_slope := (m[i1] - m[i0]) / maxf(dt_r, 0.001)
				var r := m_slope / maxf(g_slope, 0.0001)
				rate_scores.append(100.0 * clampf(minf(r, 1.0 / maxf(r, 0.0001)), 0.0, 1.0))
				# steadiness: means over 0.1 s blocks should never drop by more than 0.005 N·m
				var blocks: Array = []
				var acc_sum := 0.0
				var acc_n := 0
				var bt := t[i0]
				for k in range(i0, i1 + 1):
					if t[k] - bt >= 0.1 and acc_n > 0:
						blocks.append(acc_sum / acc_n)
						acc_sum = 0.0
						acc_n = 0
						bt = t[k]
					acc_sum += m[k]
					acc_n += 1
				if acc_n > 0:
					blocks.append(acc_sum / acc_n)
				var ok := 0
				for k in range(1, blocks.size()):
					if blocks[k] - blocks[k - 1] >= -0.005:
						ok += 1
				smooth_scores.append(100.0 * ok / maxf(blocks.size() - 1, 1))
			i0 = -1
	var ramp = null
	var rate_pct := -1.0
	var smooth_pct := -1.0
	if not rate_scores.is_empty():
		rate_pct = 0.0
		for v in rate_scores:
			rate_pct += v
		rate_pct /= rate_scores.size()
		smooth_pct = 0.0
		for v in smooth_scores:
			smooth_pct += v
		smooth_pct /= smooth_scores.size()
		ramp = _cl(0.5 * rate_pct + 0.5 * smooth_pct - 20.0 * leaks)
	elif leaks > 0:
		ramp = 0.0

	# ---- 5. efficiency: time per tied balloon against the standard
	var ideal: float = p["wait"] + p["mean_ramp"] + p["hold"] + p["tie"]
	var efficiency := 0.0
	var per_balloon := -1.0
	if ties > 0:
		per_balloon = dur / ties
		var ratio := per_balloon / ideal
		efficiency = 100.0 if ratio <= 1.5 else _cl(100.0 * (1.0 - (ratio - 1.5) / 2.5))

	# ---- 6. direction purity (real sensor only)
	var direction = null
	var off_ratio := -1.0
	var pull_mean := -1.0
	if data.get("sensor", false) and n > 0:
		var mm := 0.0
		var oo := 0.0
		var pp := 0.0
		for i in n:
			mm += absf(m[i])
			oo += absf(off[i])
			pp += absf(pull[i])
		mm /= n
		oo /= n
		pp /= n
		off_ratio = oo / maxf(mm, 0.000001)
		pull_mean = pp
		direction = 0.5 * _cl(100.0 * (1.0 - off_ratio / 0.5)) + 0.5 * _cl(100.0 * (1.0 - pp / p["pull_limit"]))

	var dims := {"safety": safety, "accuracy": accuracy, "stability": stability,
		"ramp": ramp, "efficiency": efficiency, "direction": direction}
	var tw := 0.0
	var total := 0.0
	for k in ORDER:
		if dims[k] != null:
			tw += WEIGHTS[k]
			total += WEIGHTS[k] * float(dims[k])
	total = total / tw if tw > 0.0 else 0.0
	var passed: bool = data.get("result", "") == "win"
	var grade := "F"
	if passed:
		for g in GRADES:
			if total >= g[0]:
				grade = g[1]
				break
	for k in ORDER:
		if dims[k] != null:
			dims[k] = snappedf(float(dims[k]), 0.1)

	return {
		"total": snappedf(total, 0.1),
		"grade": grade,
		"passed": passed,
		"dims": dims,
		"order": ORDER,
		"weights": WEIGHTS,
		"metrics": {
			"duration_s": dur, "pops": pops, "peak_nm": peak, "time_over_safe_pct": 100.0 * f_over,
			"track_rmse_nm": rmse, "hold_deviation_pct": 100.0 * dev, "hold_sd_nm": sd_mean,
			"first_try_pct": 100.0 * first, "rate_match_pct": rate_pct, "smooth_pct": smooth_pct,
			"leaks": leaks, "hold_drops": drops, "ties": ties, "time_per_balloon_s": per_balloon,
			"offaxis_ratio_pct": 100.0 * off_ratio if off_ratio >= 0.0 else -1.0, "pull_mean_n": pull_mean,
		},
		"standard": std,
	}


# ------------------------------------------------------------------ CSV log reader (History page)
static func load_csv(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var params := {"overload": 0.40, "safe_max": 0.34, "neutral": 0.05, "hold": 1.5, "tie": 1.0, "wait": 0.4,
		"balloons": 5, "tol": 0.04, "lead": 0.06, "mean_ramp": 3.0, "offaxis_limit": 0.30, "pull_limit": 30.0}
	var data := {"game": "balloon", "events": [], "result": "abort", "sensor": false, "difficulty": 1, "log_file": path}
	var at := PackedFloat32Array()
	var am := PackedFloat32Array()
	var aoff := PackedFloat32Array()
	var apull := PackedFloat32Array()
	var ag := PackedFloat32Array()
	var atg := PackedFloat32Array()
	var ast := PackedInt32Array()
	var steps := {"WAIT": 0, "RAMP": 1, "HOLD": 2, "TIE": 3}
	var t0 := -1.0
	while not f.eof_reached():
		var line := f.get_line().strip_edges()
		if line.is_empty():
			continue
		if line.begins_with("#"):
			for kv in line.substr(1).strip_edges().split(" ", false):
				var pair := kv.split("=")
				if pair.size() != 2:
					continue
				match pair[0]:
					"difficulty": data["difficulty"] = int(pair[1])
					"input": data["sensor"] = pair[1] == "sensor"
					"balloons": params["balloons"] = int(pair[1])
					"overload", "safe_max", "neutral", "hold", "tol", "lead", "mean_ramp", "offaxis_limit", "pull_limit":
						params[pair[0]] = float(pair[1])
			continue
		if line.begins_with("t_s"):
			continue
		var c := line.split(",")
		if c.size() < 11:
			continue
		var tt := float(c[0])
		var ph := c[4]
		var ev := c[10]
		if ph == "PLAYING" or (ev != "" and t0 >= 0.0):
			if t0 < 0.0:
				t0 = tt
			if ph == "PLAYING":
				at.append(tt - t0)
				am.append(float(c[1]))
				aoff.append(float(c[2]))
				apull.append(float(c[3]))
				ast.append(int(steps.get(c[5], 0)))
				ag.append(float(c[6]))
				atg.append(float(c[7]))
			for one in ev.split(";", false):
				if one == "start":
					continue
				data["events"].append([tt - t0, one])
				match one:
					"win": data["result"] = "win"
					"lose_broken": data["result"] = "broken"
					"lose_timeout": data["result"] = "timeout"
	f.close()
	data["t"] = at
	data["m"] = am
	data["off"] = aoff
	data["pull"] = apull
	data["guide"] = ag
	data["target"] = atg
	data["step"] = ast
	data["params"] = params
	return data
