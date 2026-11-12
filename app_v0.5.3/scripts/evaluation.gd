extends RefCounted
## Evaluation for the carrot game (v0.5.2): scores a round from its moment samples.
## Full description of every formula: design/评估方法_v0.5.2.md. All thresholds are placeholders, not validated values.
##
## Input `data` (built by the game at the end of a round, or by load_csv() from a round's CSV log):
##   params: band_min, band_max, overload, neutral, hold, rocks_to_win, offaxis_limit, pull_limit
##   t, m, off, pull: PackedFloat32Array — time from round start (s), target-axis moment (N·m), off-axis moment, pull force
##   events: Array of [t, name]   (hold_ok_L/R, half_n, rock_n, overload, offaxis, win, lose_broken, lose_timeout, abort)
##   result: "win" / "broken" / "timeout" / "abort";  sensor: bool;  difficulty: int;  log_file: String

## Weights agreed with the user (2026-11-07). A dimension without data is left out and the rest are re-weighted.
const WEIGHTS := {"safety": 25.0, "accuracy": 25.0, "stability": 20.0, "rhythm": 15.0, "efficiency": 10.0, "direction": 5.0}
const ORDER := ["safety", "accuracy", "stability", "rhythm", "efficiency", "direction"]
## Standard half-rock: rise, hold, fall in these proportions, stretched over each of the player's half-rocks.
const STD_UP := 0.4
const STD_HOLD := 0.6
const STD_DOWN := 0.4
const STD_REST := 0.1
## Grades for a cleared round. A round that was not cleared is always F (the report is still produced).
const GRADES := [[90.0, "S"], [80.0, "A"], [70.0, "B"], [60.0, "C"], [0.0, "D"]]


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


## Half-rocks: from the last moment the player was at centre, through a push past the green zone's
## lower edge, until back at centre. Returns Array of [t_start, t_end, side].
static func segments(data: Dictionary) -> Array:
	var p: Dictionary = data["params"]
	var t: PackedFloat32Array = data["t"]
	var m: PackedFloat32Array = data["m"]
	var segs: Array = []
	if t.is_empty():
		return segs
	var armed := true
	var t_leave: float = t[0]
	var cur: Array = []
	for i in t.size():
		var a := absf(m[i])
		if a < p["neutral"]:
			if not cur.is_empty():
				cur[1] = t[i]
				segs.append(cur)
				cur = []
			armed = true
			t_leave = t[i]
		elif armed and a >= p["band_min"]:
			armed = false
			cur = [t_leave, t[t.size() - 1], 1 if m[i] > 0.0 else -1]
	if not cur.is_empty():
		segs.append(cur)
	return segs


## Standard curve value at time x, aligned to the player's half-rocks.
static func standard_at(x: float, segs: Array, c: float) -> float:
	var tot := STD_UP + STD_HOLD + STD_DOWN
	for sg in segs:
		var ts: float = sg[0]
		var te: float = sg[1]
		var dur := te - ts
		if dur <= 0.0 or x < ts or x > te:
			continue
		var u := dur * STD_UP / tot
		var h := dur * STD_HOLD / tot
		var d := x - ts
		var side: float = sg[2]
		if d < u:
			return side * c * d / u
		if d < u + h:
			return side * c
		return side * c * maxf(0.0, 1.0 - (d - u - h) / maxf(dur - u - h, 0.001))
	return 0.0


static func evaluate(data: Dictionary) -> Dictionary:
	var p: Dictionary = data["params"]
	var t: PackedFloat32Array = data["t"]
	var m: PackedFloat32Array = data["m"]
	var off: PackedFloat32Array = data["off"]
	var pull: PackedFloat32Array = data["pull"]
	var events: Array = data["events"]
	var n := t.size()
	var c: float = (p["band_min"] + p["band_max"]) / 2.0
	var w: float = (p["band_max"] - p["band_min"]) / 2.0
	var dur: float = (t[n - 1] - t[0]) if n > 1 else 0.0
	var segs := segments(data)
	var std := PackedFloat32Array()
	std.resize(n)
	for i in n:
		std[i] = standard_at(t[i], segs, c)

	var hold_ok_t: Array = []
	var n_over := 0
	var halves := 0
	var rock_t: Array = []
	for e in events:
		var name: String = e[1]
		if name.begins_with("hold_ok"):
			hold_ok_t.append(float(e[0]))
		elif name == "overload":
			n_over += 1
		elif name.begins_with("half_"):
			halves += 1
		elif name.begins_with("rock_"):
			halves += 1
			rock_t.append(float(e[0]))

	# ---- 1. safety: overloads, time above the green zone, peak
	var t_over := 0.0
	var peak := 0.0
	for i in n:
		var a := absf(m[i])
		peak = maxf(peak, a)
		if a > p["band_max"] and i + 1 < n:
			t_over += t[i + 1] - t[i]
	var f_over := t_over / dur if dur > 0.0 else 0.0
	var pk := clampf((peak - p["band_max"]) / (p["overload"] - p["band_max"]), 0.0, 1.0)
	var safety := _cl(100.0 - 30.0 * n_over - 150.0 * f_over - 20.0 * pk)

	# ---- 2. accuracy: distance from the zone centre while holding, and difference from the standard curve
	var dev_sum := 0.0
	var dev_n := 0
	var sds: Array = []
	for th in hold_ok_t:
		var settled: Array = []
		for i in n:
			if t[i] >= th - p["hold"] and t[i] <= th:
				dev_sum += minf(1.0, absf(absf(m[i]) - c) / w)
				dev_n += 1
			if t[i] >= th - 0.6 * p["hold"] and t[i] <= th:
				settled.append(absf(m[i]))
		if settled.size() >= 3:
			sds.append(_sd(settled))
	var dev := dev_sum / dev_n if dev_n > 0 else 1.0
	var sq := 0.0
	var sq_n := 0
	for i in n:
		for sg in segs:
			if t[i] >= sg[0] and t[i] <= sg[1]:
				sq += (m[i] - std[i]) * (m[i] - std[i])
				sq_n += 1
				break
	var rmse := sqrt(sq / sq_n) if sq_n > 0 else c
	var accuracy := 0.5 * _cl(100.0 * (1.0 - dev)) + 0.5 * _cl(100.0 * (1.0 - rmse / c))

	# ---- 3. stability: wobble in the settled part of each hold, and holds that succeeded first time
	var sd_mean := w
	if not sds.is_empty():
		sd_mean = 0.0
		for v in sds:
			sd_mean += v
		sd_mean /= sds.size()
	var entries := 0
	var inband := false
	for i in n:
		var ib: bool = absf(m[i]) >= p["band_min"] and absf(m[i]) <= p["band_max"]
		if ib and not inband:
			entries += 1
		inband = ib
	var first := float(hold_ok_t.size()) / entries if entries > 0 else 0.0
	first = minf(first, 1.0)
	var stability := 0.5 * _cl(100.0 * (1.0 - sd_mean / (0.5 * w))) + 0.5 * _cl(100.0 * first)

	# ---- 4. rhythm and symmetry: left/right peak balance, even rock timing, same-side repeats
	var peaks := {-1: [], 1: []}
	var same := 0
	var last := 0
	for sg in segs:
		var pkv := 0.0
		for i in n:
			if t[i] >= sg[0] and t[i] <= sg[1]:
				pkv = maxf(pkv, absf(m[i]))
		peaks[int(sg[2])].append(pkv)
		if int(sg[2]) == last:
			same += 1
		last = int(sg[2])
	var parts: Array = []
	var sym := -1.0
	if not peaks[-1].is_empty() and not peaks[1].is_empty():
		var l := 0.0
		for v in peaks[-1]:
			l += v
		l /= peaks[-1].size()
		var r := 0.0
		for v in peaks[1]:
			r += v
		r /= peaks[1].size()
		sym = minf(l, r) / maxf(maxf(l, r), 0.0001)
		parts.append(100.0 * sym)
	var cv := -1.0
	var starts: Array = [t[0] if n > 0 else 0.0] + rock_t
	var periods: Array = []
	for i in range(starts.size() - 1):
		periods.append(starts[i + 1] - starts[i])
	if periods.size() >= 2:
		var mu := 0.0
		for v in periods:
			mu += v
		mu /= periods.size()
		cv = _sd(periods) / maxf(mu, 0.0001)
		parts.append(_cl(100.0 * (1.0 - cv / 0.5)))
	var rhythm = null
	if not parts.is_empty():
		var s := 0.0
		for v in parts:
			s += v
		rhythm = _cl(s / parts.size() - 10.0 * same)

	# ---- 5. efficiency: time per half-rock against the standard, and time to return to centre
	var ideal := STD_UP + STD_HOLD + STD_DOWN + STD_REST
	var eff_t := 0.0
	var per_half := -1.0
	if halves > 0:
		per_half = dur / halves
		var ratio := per_half / ideal
		eff_t = 100.0 if ratio <= 1.5 else _cl(100.0 * (1.0 - (ratio - 1.5) / 2.5))
	var rets: Array = []
	for th in hold_ok_t:
		for i in n:
			if t[i] > th and absf(m[i]) < p["neutral"]:
				rets.append(t[i] - th)
				break
	var ret := -1.0
	var eff_r := eff_t
	if not rets.is_empty():
		ret = 0.0
		for v in rets:
			ret += v
		ret /= rets.size()
		eff_r = _cl(100.0 * (1.0 - (ret - 0.4) / 1.6))
	var efficiency := 0.7 * eff_t + 0.3 * eff_r

	# ---- 6. direction purity: off-axis moment and pull force (only with a real sensor)
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
		"rhythm": rhythm, "efficiency": efficiency, "direction": direction}
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
		"metrics": {
			"duration_s": dur, "overloads": n_over, "peak_nm": peak, "time_over_band_pct": 100.0 * f_over,
			"hold_deviation_pct": 100.0 * dev, "rmse_nm": rmse, "hold_sd_nm": sd_mean,
			"first_try_pct": 100.0 * first, "symmetry_pct": 100.0 * sym if sym >= 0.0 else -1.0,
			"rock_period_cv_pct": 100.0 * cv if cv >= 0.0 else -1.0, "same_side_repeats": same,
			"time_per_half_s": per_half, "return_time_s": ret, "halves": halves, "holds": hold_ok_t.size(),
			"offaxis_ratio_pct": 100.0 * off_ratio if off_ratio >= 0.0 else -1.0, "pull_mean_n": pull_mean,
		},
		"standard": std,
		"segments": segs,
	}


# ------------------------------------------------------------------ CSV log reader (for the history page)
## Reads a round's CSV log (user://carrot_logs/rocking_A_*.csv) into the same `data` shape the game builds.
## Only rows in the PLAYING phase are used as samples; events are taken from every row.
static func load_csv(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var params := {"band_min": 0.15, "band_max": 0.30, "overload": 0.40, "neutral": 0.05, "hold": 0.5,
		"rocks_to_win": 6, "offaxis_limit": 0.30, "pull_limit": 30.0}
	var data := {"events": [], "result": "abort", "sensor": false, "difficulty": 1, "log_file": path}
	var at := PackedFloat32Array()
	var am := PackedFloat32Array()
	var aoff := PackedFloat32Array()
	var apull := PackedFloat32Array()
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
					"band":
						var b := pair[1].split("-")
						if b.size() == 2:
							params["band_min"] = float(b[0])
							params["band_max"] = float(b[1])
					"overload": params["overload"] = float(pair[1])
					"neutral": params["neutral"] = float(pair[1])
					"hold": params["hold"] = float(pair[1])
					"rocks_to_win": params["rocks_to_win"] = int(pair[1])
					"offaxis_limit": params["offaxis_limit"] = float(pair[1])
					"pull_limit": params["pull_limit"] = float(pair[1])
					"input": data["sensor"] = pair[1] == "sensor"
			continue
		if line.begins_with("t_s"):
			continue
		var c := line.split(",")
		if c.size() < 10:
			continue
		var tt := float(c[0])
		var phase := c[4]
		var ev := c[9]
		if phase == "PLAYING" or (ev != "" and t0 >= 0.0):
			if t0 < 0.0:
				t0 = tt
			if phase == "PLAYING":
				at.append(tt - t0)
				am.append(float(c[1]))
				aoff.append(float(c[2]))
				apull.append(float(c[3]))
			# v0.5.2 logs join several events of one frame with ";"
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
	data["params"] = params
	return data
