extends RefCounted
## Model — "at a glance" part of the evaluation report (v0.7.2.1): turns one round's samples into
##   1. cards  — one per balloon (Level B) or per full rock (Level A): result, ramp speed, hold steadiness;
##   2. band   — the whole round as a strip of states (rest / working / in target / too fast / over);
##   3. tips   — two or three coaching points, as text keys + numbers (the view writes the sentences).
## Input: the same `data` the evaluation uses (game's evaluation_data() or load_csv()) and the evaluation
## result `rep`. No UI here. All thresholds are placeholders, like the rest of the evaluation.

const B_RAMP := 1   # balloon stage codes (balloon_model.gd Stage)
const B_HOLD := 2
const SPEED_FAST := 0.5    # on average ahead of the ramp by more than half the leak margin = too fast
const SPEED_SLOW := 0.33   # on average behind it by more than a third of the leak margin = too slow
const MAX_TIPS := 3


static func build(data: Dictionary, rep: Dictionary) -> Dictionary:
	if data.get("t", PackedFloat32Array()).size() < 2:
		return {"cards": [], "band": [], "shares": {}, "tips": [], "duration": 0.0}
	if str(data.get("game", "")) == "balloon":
		return _balloon(data, rep)
	return _carrot(data, rep)


# ------------------------------------------------------------------ helpers
static func _sd(v: Array) -> float:
	if v.size() < 2:
		return 0.0
	var mu := 0.0
	for x in v:
		mu += x
	mu /= v.size()
	var s := 0.0
	for x in v:
		s += (x - mu) * (x - mu)
	return sqrt(s / v.size())


static func _mean(v: Array) -> float:
	if v.is_empty():
		return 0.0
	var s := 0.0
	for x in v:
		s += x
	return s / v.size()


## Stars for hold steadiness: wobble (sd) compared with the half-width of the target band.
static func _stars(sd: float, tol: float) -> int:
	if sd < 0.15 * tol:
		return 3
	if sd < 0.3 * tol:
		return 2
	return 1


## Merge per-sample states into runs [t0, t1, state] and time shares (%).
static func _runs(t: PackedFloat32Array, states: Array) -> Array:
	var runs: Array = []
	var n := t.size()
	var i := 0
	while i < n:
		var j := i
		while j + 1 < n and states[j + 1] == states[i]:
			j += 1
		var t1: float = t[j + 1] if j + 1 < n else t[j]
		runs.append([t[i] - t[0], t1 - t[0], states[i]])
		i = j + 1
	return runs


static func _shares(runs: Array, dur: float) -> Dictionary:
	var sh := {"rest": 0.0, "work": 0.0, "target": 0.0, "fast": 0.0, "over": 0.0}
	if dur <= 0.0:
		return sh
	for r in runs:
		sh[r[2]] += 100.0 * (float(r[1]) - float(r[0])) / dur
	return sh


static func _tip(kind: String, key: String, args: Array = []) -> Dictionary:
	return {"kind": kind, "key": key, "args": args}


# ------------------------------------------------------------------ Level B: balloons
static func _balloon(data: Dictionary, rep: Dictionary) -> Dictionary:
	var p: Dictionary = data["params"]
	var t: PackedFloat32Array = data["t"]
	var m: PackedFloat32Array = data["m"]
	var guide: PackedFloat32Array = data["guide"]
	var target: PackedFloat32Array = data["target"]
	var stp: PackedInt32Array = data["step"]
	var n := t.size()
	var tol: float = p["tol"]
	var lead: float = p["lead"]
	var safe: float = p["safe_max"]
	var balloons: int = int(p.get("balloons", 5))

	# ---- per balloon: which events belong to which balloon (balloon_k starts an attempt, tie_k ends it)
	var cards: Array = []
	for k in balloons:
		cards.append({"index": k, "started": false, "tied": false, "leaks": 0, "pops": 0, "drops": 0,
			"t_start": -1.0, "t_tie": -1.0, "speed": "", "ratio": -1.0, "stars": 0, "leak_at": -1.0})
	var cur := -1
	var attempt_t := 0.0
	for e in data["events"]:
		var name_e: String = e[1]
		var te: float = float(e[0])
		if name_e.begins_with("balloon_"):
			cur = clampi(int(name_e.substr(8)) - 1, 0, balloons - 1)
			cards[cur]["started"] = true
			if cards[cur]["t_start"] < 0.0:
				cards[cur]["t_start"] = te
			attempt_t = te
		elif cur < 0:
			continue
		elif name_e == "leak":
			cards[cur]["leaks"] += 1
			if cards[cur]["leak_at"] < 0.0:
				cards[cur]["leak_at"] = te - attempt_t
		elif name_e == "pop":
			cards[cur]["pops"] += 1
		elif name_e == "hold_drop":
			cards[cur]["drops"] += 1
		elif name_e.begins_with("tie_"):
			cards[cur]["tied"] = true
			cards[cur]["t_tie"] = te

	# ---- ramp speed of the last finished ramp before each tie, hold steadiness before each tie
	var hold_bias: Array = []
	for c in cards:
		if not c["tied"]:
			continue
		var tt: float = c["t_tie"]
		# last RAMP run that ended before the tie
		var i1 := -1
		var i0 := -1
		for i in range(n - 1, -1, -1):
			if t[i] >= tt:
				continue
			if stp[i] == B_RAMP and guide[i] >= 0.0:
				if i1 < 0:
					i1 = i
				i0 = i
			elif i1 >= 0:
				break
		if i1 - i0 >= 5:
			# mean distance ahead of (+) or behind (−) the standard ramp
			var off_sum := 0.0
			for i in range(i0, i1 + 1):
				off_sum += m[i] - guide[i]
			var off := off_sum / float(i1 - i0 + 1)
			c["ratio"] = off
			c["speed"] = "fast" if off > SPEED_FAST * lead else ("slow" if off < -SPEED_SLOW * lead else "ok")
		# settled part of the hold (last 60 %)
		var settled: Array = []
		for i in n:
			if t[i] >= tt - 0.6 * float(p["hold"]) and t[i] < tt and target[i] >= 0.0:
				settled.append(m[i])
				hold_bias.append(m[i] - target[i])
		c["stars"] = _stars(_sd(settled), tol)
	for c in cards:
		if c["speed"] == "" and int(c["leaks"]) > 0:
			c["speed"] = "fast"
		var res := "none"
		if c["tied"]:
			res = "clean" if c["leaks"] + c["pops"] + c["drops"] == 0 else "tied"
		elif c["pops"] > 0:
			res = "popped"
		elif c["started"]:
			res = "unfinished"
		c["result"] = res

	# ---- band: state of every sample
	var states: Array = []
	states.resize(n)
	for i in n:
		var x := maxf(m[i], 0.0)
		var s := "rest"
		if x > safe:
			s = "over"
		elif stp[i] == B_RAMP and guide[i] >= 0.0:
			s = "fast" if x - guide[i] > lead else "work"
		elif stp[i] == B_HOLD and target[i] >= 0.0:
			s = "target" if absf(x - target[i]) <= tol else "work"
		states[i] = s
	var runs := _runs(t, states)
	var dur: float = t[n - 1] - t[0]
	var shares := _shares(runs, dur)

	# ---- tips: up to two things to fix (most serious first), then one thing done well
	var tips: Array = []
	for c in cards:
		if c["pops"] > 0:
			tips.append(_tip("fix", "tip_b_pop", [int(c["index"]) + 1]))
			break
	for c in cards:
		if c["leaks"] > 0:
			tips.append(_tip("fix", "tip_b_leak", [int(c["index"]) + 1, maxf(float(c["leak_at"]), 0.1)]))
			break
	var slow_n := 0
	var first_slow := -1
	for c in cards:
		if c["speed"] == "slow":
			slow_n += 1
			if first_slow < 0:
				first_slow = int(c["index"]) + 1
	if slow_n > 0:
		tips.append(_tip("fix", "tip_b_slow", [first_slow]))
	var bias := _mean(hold_bias)
	if hold_bias.size() > 0 and absf(bias) > 0.4 * tol:
		tips.append(_tip("fix", "tip_hold_low" if bias < 0.0 else "tip_hold_high", [absf(bias)]))
	var drops := 0
	for c in cards:
		drops += int(c["drops"])
	if drops > 0:
		tips.append(_tip("fix", "tip_drop", [drops]))
	tips = tips.slice(0, MAX_TIPS - 1)
	var clean := 0
	var tied := 0
	for c in cards:
		if c["result"] == "clean":
			clean += 1
		if c["tied"]:
			tied += 1
	if clean > 0:
		tips.append(_tip("good", "tip_b_good_clean", [balloons, clean]))
	elif tied > 0:
		tips.append(_tip("good", "tip_b_good_tied", [tied]))
	else:
		tips.append(_tip("good", "tip_good_try"))
	if tips.size() == 1 and rep.get("passed", false):
		tips.push_front(_tip("good", "tip_all_good"))

	return {"game": "balloon", "cards": cards, "band": runs, "shares": shares, "tips": tips, "duration": dur}


# ------------------------------------------------------------------ Level A: carrot
static func _carrot(data: Dictionary, rep: Dictionary) -> Dictionary:
	var p: Dictionary = data["params"]
	var t: PackedFloat32Array = data["t"]
	var m: PackedFloat32Array = data["m"]
	var n := t.size()
	var bmin: float = p["band_min"]
	var bmax: float = p["band_max"]
	var over: float = p["overload"]
	var neutral: float = p["neutral"]
	var c_mid := (bmin + bmax) / 2.0
	var half_w := (bmax - bmin) / 2.0
	var segs: Array = rep.get("segments", [])
	var rocks_to_win: int = int(p.get("rocks_to_win", 6))

	# ---- one entry per half-rock (push to one side and back)
	var halves: Array = []
	for sg in segs:
		halves.append({"t0": float(sg[0]), "t1": float(sg[1]), "side": int(sg[2]), "held": false, "overloads": 0,
			"peak": 0.0, "in_band": []})
	for e in data["events"]:
		var te: float = float(e[0])
		var name_e: String = e[1]
		for h in halves:
			if te >= h["t0"] and te <= h["t1"] + 0.05:
				if name_e.begins_with("hold_ok"):
					h["held"] = true
				elif name_e == "overload":
					h["overloads"] += 1
				break
	var hold_bias: Array = []
	for h in halves:
		for i in n:
			if t[i] < h["t0"] or t[i] > h["t1"]:
				continue
			var a := absf(m[i])
			h["peak"] = maxf(h["peak"], a)
			if a >= bmin and a <= bmax:
				h["in_band"].append(a)
				hold_bias.append(a - c_mid)

	# ---- cards: a full rock = two half-rocks in a row
	var cards: Array = []
	var k := 0
	while k < halves.size() and cards.size() < rocks_to_win:
		var pair: Array = [halves[k]]
		if k + 1 < halves.size():
			pair.append(halves[k + 1])
		var sides: Array = []
		var held := 0
		var overs := 0
		var sds: Array = []
		for h in pair:
			sides.append("R" if h["side"] > 0 else "L")
			if h["held"]:
				held += 1
			overs += int(h["overloads"])
			if h["in_band"].size() >= 3:
				sds.append(_sd(h["in_band"]))
		var res := "clean"
		if overs > 0:
			res = "popped"
		elif held < pair.size() or pair.size() < 2:
			res = "unfinished" if held == 0 else "tied"
		cards.append({"index": cards.size(), "result": res, "sides": sides, "held": held, "halves": pair.size(),
			"pops": overs, "leaks": 0, "stars": _stars(_mean(sds), half_w) if not sds.is_empty() else 0,
			"speed": "", "same_side": sides.size() == 2 and sides[0] == sides[1]})
		k += 2

	# ---- band
	var states: Array = []
	states.resize(n)
	for i in n:
		var a := absf(m[i])
		var s := "rest"
		if a >= over:
			s = "over"
		elif a > bmax:
			s = "fast"
		elif a >= bmin:
			s = "target"
		elif a >= neutral:
			s = "work"
		states[i] = s
	var runs := _runs(t, states)
	var dur: float = t[n - 1] - t[0]
	var shares := _shares(runs, dur)

	# ---- tips
	var tips: Array = []
	for c in cards:
		if c["pops"] > 0:
			tips.append(_tip("fix", "tip_c_over", [int(c["index"]) + 1]))
			break
	var peaks := {"L": [], "R": []}
	var same := 0
	var prev_side := 0
	for h in halves:
		peaks["R" if h["side"] > 0 else "L"].append(float(h["peak"]))
		if h["side"] == prev_side:
			same += 1
		prev_side = h["side"]
	if same > 0:
		tips.append(_tip("fix", "tip_c_alternate", [same]))
	if not peaks["L"].is_empty() and not peaks["R"].is_empty():
		var pl := _mean(peaks["L"])
		var pr := _mean(peaks["R"])
		if absf(pl - pr) > 0.5 * half_w:
			tips.append(_tip("fix", "tip_c_side_left" if pl < pr else "tip_c_side_right", [absf(pl - pr)]))
	var bias := _mean(hold_bias)
	if hold_bias.size() > 0 and absf(bias) > 0.4 * half_w:
		tips.append(_tip("fix", "tip_hold_low" if bias < 0.0 else "tip_hold_high", [absf(bias)]))
	var unheld := 0
	for h in halves:
		if not h["held"]:
			unheld += 1
	if unheld > 0:
		tips.append(_tip("fix", "tip_c_hold", [unheld]))
	tips = tips.slice(0, MAX_TIPS - 1)
	var held_total := 0
	for h in halves:
		if h["held"]:
			held_total += 1
	if held_total > 0:
		tips.append(_tip("good", "tip_c_good_holds", [halves.size(), held_total]))
	else:
		tips.append(_tip("good", "tip_good_try"))
	if tips.size() == 1 and rep.get("passed", false):
		tips.push_front(_tip("good", "tip_all_good"))

	return {"game": "rocking", "cards": cards, "band": runs, "shares": shares, "tips": tips, "duration": dur}
