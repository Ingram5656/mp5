extends RefCounted
## Model (persistence) — MP5 local database (v0.5.0; v0.5.2 adds each round's evaluation; v0.5.4 adds query
## methods so presenters do not reach into `data`; v0.7.1 adds Level B statistics and achievements): achievement state, play statistics and a round history.
##
## Stored as one JSON file so it survives closing the game:
##   user://mp5_data/mp5_db.json      (Windows: %APPDATA%\Godot\app_userdata\MP5\mp5_data\)
## Every save writes a temporary file first and keeps the previous version as .bak, so a crash
## while saving cannot wipe the data. On load, the newest readable copy is used.
## One shared database per computer; nothing is reset when the game restarts.

const Defs := preload("res://app_v0.8.3/scripts/models/achievement_defs.gd")

const DIR := "user://mp5_data"
const PATH := "user://mp5_data/mp5_db.json"
const TMP := "user://mp5_data/mp5_db.json.tmp"
const BAK := "user://mp5_data/mp5_db.json.bak"
const SCHEMA := 1
const MAX_ROUNDS := 2000

var data: Dictionary = {}


func _init() -> void:
	load_db()


# ------------------------------------------------------------------ storage
func _empty() -> Dictionary:
	return {
		"schema": SCHEMA,
		"created_at": _now(),
		"updated_at": _now(),
		"stats": {
			"rounds_total": 0,
			"wins_total": 0,
			"wins_by_difficulty": [0, 0, 0],
			"broken_total": 0,
			"timeout_total": 0,
			"master_streak": 0,       # consecutive Master Dentist wins (Master rounds only)
			"master_streak_best": 0,
			"fail_streak": 0,         # consecutive failed rounds (snapped or timed out), any difficulty
		},
		"stats_balloon": {            # Level B, Bunny's Balloons (v0.7.1)
			"rounds_total": 0,
			"wins_total": 0,
			"wins_by_difficulty": [0, 0, 0],
			"balloons_tied_total": 0,
			"master_streak": 0,
			"master_streak_best": 0,
			"fail_streak": 0,
		},
		"achievements": {},           # id -> {"unlocked": bool, "unlocked_at": String, "progress": int}
		"rounds": [],                 # newest last
	}


func load_db() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	for p in [PATH, TMP, BAK]:
		var d = _read(p)
		if d is Dictionary:
			data = d
			_migrate()
			return
	data = _empty()
	_migrate()
	save()


func _read(path: String):
	if not FileAccess.file_exists(path):
		return null
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return null
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if parsed is Dictionary and parsed.has("achievements") and parsed.has("stats"):
		return parsed
	return null


## Fill in anything missing (older file, or achievements added in a later version).
func _migrate() -> void:
	var base := _empty()
	for k in base.keys():
		if not data.has(k):
			data[k] = base[k]
	for sk in ["stats", "stats_balloon"]:
		for k in base[sk].keys():
			if not data[sk].has(k):
				data[sk][k] = base[sk][k]
	for d in Defs.LIST:
		if not data["achievements"].has(d["id"]):
			data["achievements"][d["id"]] = {"unlocked": false, "unlocked_at": "", "progress": 0}
	# JSON stores every number as a float; turn counters back into integers
	for sk in ["stats", "stats_balloon"]:
		var st: Dictionary = data[sk]
		for k in st.keys():
			if st[k] is Array:
				var arr: Array = []
				for v in st[k]:
					arr.append(int(v))
				st[k] = arr
			else:
				st[k] = int(st[k])
		while st["wins_by_difficulty"].size() < 3:
			st["wins_by_difficulty"].append(0)
	for id in data["achievements"].keys():
		var s: Dictionary = data["achievements"][id]
		s["unlocked"] = bool(s.get("unlocked", false))
		s["unlocked_at"] = str(s.get("unlocked_at", ""))
		s["progress"] = int(s.get("progress", 0))
	data["schema"] = SCHEMA


func save() -> void:
	data["updated_at"] = _now()
	var text := JSON.stringify(data, "\t")
	var f := FileAccess.open(TMP, FileAccess.WRITE)
	if f == null:
		push_error("MP5 database: cannot write " + TMP)
		return
	f.store_string(text)
	f.close()
	var abs_path := ProjectSettings.globalize_path(PATH)
	var abs_tmp := ProjectSettings.globalize_path(TMP)
	var abs_bak := ProjectSettings.globalize_path(BAK)
	if FileAccess.file_exists(PATH):
		if FileAccess.file_exists(BAK):
			DirAccess.remove_absolute(abs_bak)
		DirAccess.rename_absolute(abs_path, abs_bak)
	if DirAccess.rename_absolute(abs_tmp, abs_path) != OK:
		push_error("MP5 database: cannot replace " + PATH)


func _now() -> String:
	return Time.get_datetime_string_from_system(false, true)


# ------------------------------------------------------------------ queries
func state(id: String) -> Dictionary:
	return data["achievements"].get(id, {"unlocked": false, "unlocked_at": "", "progress": 0})


func is_unlocked(id: String) -> bool:
	return bool(state(id).get("unlocked", false))


func unlocked_count() -> int:
	var n := 0
	for d in Defs.LIST:
		if is_unlocked(d["id"]):
			n += 1
	return n


func total_count() -> int:
	return Defs.LIST.size()


func rounds() -> Array:
	return data["rounds"]


## Store a score worked out later (rounds played before v0.5.2 have none until their report is opened).
func save_round_evaluation(index: int, evaluation: Dictionary) -> void:
	var rs: Array = data["rounds"]
	if index < 0 or index >= rs.size():
		return
	rs[index]["evaluation"] = evaluation
	save()


# ------------------------------------------------------------------ updates
## Unlock one achievement. Returns true if it was newly unlocked.
func unlock(id: String, save_now := true) -> bool:
	if Defs.get_def(id).is_empty() or is_unlocked(id):
		return false
	var s: Dictionary = data["achievements"][id]
	s["unlocked"] = true
	s["unlocked_at"] = _now()
	var target: int = Defs.get_def(id)["target"]
	if target > 0:
		s["progress"] = target
	if save_now:
		save()
	return true


func _progress(id: String, value: int, out: Array) -> void:
	var d := Defs.get_def(id)
	var s: Dictionary = data["achievements"][id]
	if not s["unlocked"]:
		s["progress"] = maxi(int(s["progress"]), mini(value, int(d["target"])))
		if value >= int(d["target"]) and unlock(id, false):
			out.append(id)


## Record a finished round and return the ids of newly unlocked achievements.
## r: game, difficulty, result ("win" / "broken" / "timeout" / "abort"), rocks, rocks_to_win,
##    mistakes, allowed, elapsed, clean_holds, over_band, ears, same_side_max, hour,
##    plus mid_round: ids already unlocked during the round (listed in history only),
##    and evaluation: {total, grade, dims} from evaluation.gd (v0.5.2).
func record_round(r: Dictionary) -> Array:
	if r.get("game", Defs.GAME_ROCKING) == Defs.GAME_BALLOON:
		return _record_balloon(r)
	if r.get("game", Defs.GAME_ROCKING) != Defs.GAME_ROCKING:
		return _record_history_only(r)
	var st: Dictionary = data["stats"]
	var out: Array = []
	var res: String = r["result"]
	var diff: int = r["difficulty"]
	var win := res == "win"
	var fail := res == "broken" or res == "timeout"

	if res != "abort":
		st["rounds_total"] += 1
	# streak needed for "Never give up" is the one *before* this round
	var fails_before: int = st["fail_streak"]
	if win:
		st["wins_total"] += 1
		st["wins_by_difficulty"][diff] += 1
		st["fail_streak"] = 0
	elif fail:
		st["fail_streak"] += 1
	if res == "broken":
		st["broken_total"] += 1
	if res == "timeout":
		st["timeout_total"] += 1
	if diff == 2 and res != "abort":
		st["master_streak"] = st["master_streak"] + 1 if win else 0
		st["master_streak_best"] = maxi(st["master_streak_best"], st["master_streak"])

	var checks := {
		"rock_first_carrot": win,
		"rock_intern_graduate": win and diff == 0 and r["mistakes"] == 0,
		"rock_slow_steady": win and diff == 0 and r["elapsed"] > 120.0,
		"rock_trainee_pass": win and diff == 1,
		"rock_quick_hands": win and diff == 1 and r["elapsed"] <= 45.0,
		"rock_close_call": win and diff == 1 and r["mistakes"] == 3,
		"rock_carrot_master": win and diff == 2,
		"rock_lightning": win and diff == 2 and r["elapsed"] <= 40.0,
		"rock_one_shot": win and r["clean_holds"],
		"rock_gentle": win and not r["over_band"],
		"rock_cracked": res == "broken",
		"rock_so_close": res == "timeout" and r["rocks"] >= 5,
		"rock_never_give_up": win and fails_before >= 3,
		"rock_night_owl": win and int(r["hour"]) < 5,
	}
	for id in checks.keys():
		if checks[id] and unlock(id, false):
			out.append(id)

	_progress("rock_practice_perfect", st["master_streak"], out)
	var diffs_cleared := 0
	for n in st["wins_by_difficulty"]:
		if n > 0:
			diffs_cleared += 1
	_progress("rock_all_rounder", diffs_cleared, out)
	_progress("rock_bunny_friend", st["wins_total"], out)
	_progress("rock_farm_owner", st["wins_total"], out)

	var entry := {
		"at": _now(),
		"game": r.get("game", Defs.GAME_ROCKING),
		"difficulty": diff,
		"result": res,
		"rocks": r["rocks"],
		"rocks_to_win": r["rocks_to_win"],
		"mistakes": r["mistakes"],
		"allowed_mistakes": r["allowed"],
		"elapsed_s": snappedf(r["elapsed"], 0.01),
		"log_file": r.get("log_file", ""),
		"new_achievements": r.get("mid_round", []) + out,
	}
	if r.has("evaluation"):
		entry["evaluation"] = r["evaluation"]   # total, grade, dims (v0.5.2)
	data["rounds"].append(entry)
	while data["rounds"].size() > MAX_ROUNDS:
		data["rounds"].pop_front()
	save()
	return out


## Level B, Bunny's Balloons (v0.7.1): its own statistics and 20 achievements (ids bal_*); nothing here
## touches the Level A statistics.
## r: difficulty, result, tied, balloons, mistakes (pops), allowed, elapsed, leaks, hold_drops, ears
##    (off-axis warnings), peak (N·m), daydream_max (s), hour, safe_max (N·m), track_rmse (N·m, -1 = unknown),
##    log_file, evaluation.
func _record_balloon(r: Dictionary) -> Array:
	var st: Dictionary = data["stats_balloon"]
	var out: Array = []
	var res: String = r["result"]
	var diff: int = r["difficulty"]
	var win := res == "win"
	var fail := res == "broken" or res == "timeout"
	var tied: int = int(r.get("tied", 0))
	if res != "abort":
		st["rounds_total"] += 1
	st["balloons_tied_total"] += tied
	var fails_before: int = st["fail_streak"]
	if win:
		st["wins_total"] += 1
		st["wins_by_difficulty"][diff] += 1
		st["fail_streak"] = 0
	elif fail:
		st["fail_streak"] += 1
	if diff == 2 and res != "abort":
		st["master_streak"] = st["master_streak"] + 1 if win else 0
		st["master_streak_best"] = maxi(st["master_streak_best"], st["master_streak"])

	var pops: int = int(r.get("mistakes", 0))
	var leaks: int = int(r.get("leaks", 0))
	var elapsed: float = float(r.get("elapsed", 0.0))
	var rmse: float = float(r.get("track_rmse", -1.0))
	var checks := {
		"bal_first_bunch": win,
		"bal_airtight": win and diff == 0 and pops == 0 and leaks == 0,
		"bal_deep_breath": win and diff == 0 and elapsed > 120.0,
		"bal_trainee": win and diff == 1,
		"bal_one_breath": win and diff == 1 and elapsed <= 45.0,
		"bal_on_edge": win and diff == 1 and pops == 3,
		"bal_master": win and diff == 2,
		"bal_gust": win and diff == 2 and elapsed <= 35.0,
		"bal_first_time": win and int(r.get("hold_drops", 0)) == 0,
		"bal_on_the_line": win and rmse >= 0.0 and rmse < 0.02,
		"bal_gentle": win and float(r.get("peak", 1.0)) <= float(r.get("safe_max", 0.34)),
		"bal_frizz": pops >= 1,
		"bal_pssst": leaks >= 3,
		"bal_leaning_pump": int(r.get("ears", 0)) >= 3,
		"bal_one_short": res == "timeout" and tied >= 4,
		"bal_daydreamer": float(r.get("daydream_max", 0.0)) >= 5.0,
		"bal_one_more": win and fails_before >= 3,
	}
	for id in checks.keys():
		if checks[id] and unlock(id, false):
			out.append(id)
	_progress("bal_rock_solid", st["master_streak"], out)
	_progress("bal_collector", st["balloons_tied_total"], out)
	_progress("bal_airlines", st["wins_total"], out)

	var entry := _history_entry(r)
	entry["new_achievements"] = out
	data["rounds"].append(entry)
	while data["rounds"].size() > MAX_ROUNDS:
		data["rounds"].pop_front()
	save()
	return out


## Rounds of a game without achievements go into the history only.
func _record_history_only(r: Dictionary) -> Array:
	var entry := _history_entry(r)
	data["rounds"].append(entry)
	while data["rounds"].size() > MAX_ROUNDS:
		data["rounds"].pop_front()
	save()
	return []


func _history_entry(r: Dictionary) -> Dictionary:
	var entry := {
		"at": _now(),
		"game": r["game"],
		"difficulty": r["difficulty"],
		"result": r["result"],
		"rocks": r.get("rocks", 0),
		"rocks_to_win": r.get("rocks_to_win", 0),
		"mistakes": r.get("mistakes", 0),
		"allowed_mistakes": r.get("allowed", 0),
		"elapsed_s": snappedf(float(r.get("elapsed", 0.0)), 0.01),
		"log_file": r.get("log_file", ""),
		"new_achievements": [],
	}
	if r.has("evaluation"):
		entry["evaluation"] = r["evaluation"]
	return entry
