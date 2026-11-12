extends Node
## Model tests (v0.5.4). Open tests/run_tests.tscn and press F6. Results appear on screen and in the
## Output panel. Only models are tested — they have no UI, which is the point of the MVP split.
## These tests do not touch the achievements database or any files.

const RockingModel := preload("res://app_v0.5.4/scripts/models/rocking_model.gd")
const EntryTestModel := preload("res://app_v0.5.4/scripts/models/entry_test_model.gd")
const Evaluation := preload("res://app_v0.5.4/scripts/models/evaluation.gd")

const DT := 1.0 / 60.0

var _pass := 0
var _fail := 0
var _lines := PackedStringArray()


func _ready() -> void:
	_run("rocking: alternating pushes clear the round", _t_rocking_win)
	_run("rocking: pushing the same side twice does not count", _t_rocking_same_side)
	_run("rocking: too hard = one mistake, locked until back at centre", _t_rocking_overload)
	_run("rocking: Master Dentist snaps on the first mistake", _t_rocking_master_snaps)
	_run("rocking: Trainee times out, Intern has no timer", _t_rocking_timer)
	_run("rocking: off-axis warning pauses the hold and counts ears", _t_rocking_offaxis)
	_run("rocking: same side five times reaches Other Left", _t_rocking_wrong_side_ach)
	_run("rocking: quitting only counts while playing", _t_rocking_abort)
	_run("rocking: samples, events and log row", _t_rocking_records)
	_run("entry test: lock opens after 1 s in zone, not while paused", _t_entry)
	_run("evaluation: a clean round scores S, a failed round is F", _t_evaluation)
	var summary := "%d passed, %d failed" % [_pass, _fail]
	_lines.append("")
	_lines.append(summary)
	print(summary)
	var l := Label.new()
	l.text = "\n".join(_lines)
	l.position = Vector2(20, 20)
	l.add_theme_color_override("font_color", Color.WHITE if _fail == 0 else Color(1, 0.6, 0.6))
	add_child(l)
	if DisplayServer.get_name() == "headless":
		get_tree().quit(1 if _fail > 0 else 0)


func _run(title: String, f: Callable) -> void:
	var msg: String = f.call()
	if msg == "":
		_pass += 1
		_lines.append("PASS  " + title)
		print("PASS  " + title)
	else:
		_fail += 1
		_lines.append("FAIL  " + title + " — " + msg)
		push_error("FAIL  " + title + " — " + msg)


# ------------------------------------------------------------------ helpers
## Hold a moment for `seconds`, feeding the model frame by frame.
func _feed(m: RockingModel, moment: float, seconds: float, off := 0.0) -> void:
	var n := int(ceil(seconds / DT))
	for i in n:
		m.step(DT, moment, off, 0.0)


func _start(m: RockingModel) -> void:
	_feed(m, 0.0, 0.7)   # stay at centre past READY_TIME


## One good half-rock to `side` (+1 right, -1 left).
func _half(m: RockingModel, side: int) -> void:
	_feed(m, side * 0.225, 0.6)
	_feed(m, 0.0, 0.1)


# ------------------------------------------------------------------ rocking model
func _t_rocking_win() -> String:
	var m := RockingModel.new(1)
	_start(m)
	if m.phase != RockingModel.Phase.PLAYING:
		return "did not start"
	for k in 6:
		_half(m, 1)
		_half(m, -1)
	if m.phase != RockingModel.Phase.WIN or m.result != "win":
		return "expected win, phase %d after %d rocks" % [m.phase, m.cycles]
	if m.cycles != 6 or m.half_count != 12:
		return "rocks %d halves %d" % [m.cycles, m.half_count]
	if not m.clean_holds or m.over_band:
		return "clean round flagged as not clean"
	return ""


func _t_rocking_same_side() -> String:
	var m := RockingModel.new(1)
	_start(m)
	_half(m, 1)
	_half(m, 1)
	if m.half_count != 1:
		return "half_count %d, expected 1" % m.half_count
	_half(m, -1)
	if m.cycles != 1:
		return "cycles %d, expected 1" % m.cycles
	return ""


func _t_rocking_overload() -> String:
	var m := RockingModel.new(1)
	_start(m)
	_feed(m, 0.46, 0.2)
	if m.mistakes != 1:
		return "mistakes %d" % m.mistakes
	_feed(m, 0.46, 0.5)
	if m.mistakes != 1:
		return "counted again before returning to centre"
	_feed(m, 0.225, 0.6)
	if m.half_count != 0:
		return "a hold counted while still locked"
	_feed(m, 0.0, 0.1)
	_half(m, 1)
	if m.half_count != 1:
		return "no half-rock after returning to centre"
	return ""


func _t_rocking_master_snaps() -> String:
	var m := RockingModel.new(2)
	_start(m)
	_feed(m, 0.46, 0.1)
	if m.phase != RockingModel.Phase.LOSE or m.result != "broken":
		return "phase %d result %s" % [m.phase, m.result]
	return ""


func _t_rocking_timer() -> String:
	var m := RockingModel.new(1)
	_start(m)
	_feed(m, 0.0, 91.0)
	if m.result != "timeout":
		return "Trainee result %s" % m.result
	var m2 := RockingModel.new(0)
	_start(m2)
	_feed(m2, 0.0, 120.0)
	if m2.phase != RockingModel.Phase.PLAYING:
		return "Intern ended without a timer"
	return ""


func _t_rocking_offaxis() -> String:
	var m := RockingModel.new(1)
	_start(m)
	_feed(m, 0.225, 1.0, 0.45)
	if m.half_count != 0 or m.hold_t > 0.0:
		return "hold advanced during off-axis warning"
	if m.ears != 1:
		return "ears %d after 1 s (cool-down 1.2 s)" % m.ears
	_feed(m, 0.225, 2.5, 0.45)
	if m.ears != 3:
		return "ears %d after 3.5 s" % m.ears
	return ""


func _t_rocking_wrong_side_ach() -> String:
	var m := RockingModel.new(1)
	_start(m)
	var got := false
	for k in 5:
		for i in 18:   # 0.3 s pushed, not long enough to complete a hold
			m.step(DT, 0.225, 0.0, 0.0)
			if "rock_wrong_side" in m.frame_achievements:
				got = true
		for i in 6:    # back to centre
			m.step(DT, 0.0, 0.0, 0.0)
	if not got:
		return "same_side_run %d" % m.same_side_run
	return ""


func _t_rocking_abort() -> String:
	var m := RockingModel.new(1)
	if m.abort():
		return "abort counted before the round started"
	_start(m)
	if not m.abort() or m.result != "abort":
		return "abort while playing not recorded"
	return ""


func _t_rocking_records() -> String:
	var m := RockingModel.new(1)
	_start(m)
	_half(m, 1)
	if m.s_t.size() < 30 or m.s_t.size() != m.s_m.size():
		return "samples %d" % m.s_t.size()
	var names: Array = []
	for e in m.events:
		names.append(e[1])
	if not "hold_ok_R" in names or not "half_1" in names:
		return "events %s" % str(names)
	var cols := m.log_row().split(",")
	if cols.size() != 10:
		return "log row has %d columns" % cols.size()
	if not m.log_header(false).begins_with("# game=rocking_A"):
		return "log header"
	return ""


# ------------------------------------------------------------------ entry test model
func _t_entry() -> String:
	var e := EntryTestModel.new()
	var good := {"direction_deg": 45.0, "force_n": 10.0, "moment_nm": 0.2}
	var t := 0.0
	while t < 1.2:
		e.step(DT, good, true)
		t += DT
	if e.unlocked[0]:
		return "advanced while paused"
	var opened: Array = []
	t = 0.0
	while t < 1.05:
		opened += e.step(DT, good, false)
		t += DT
	if not e.all_unlocked() or opened.size() != 3:
		return "opened %s" % str(opened)
	return ""


# ------------------------------------------------------------------ evaluation
func _t_evaluation() -> String:
	var m := RockingModel.new(1)
	_start(m)
	for k in 6:
		_half(m, 1)
		_half(m, -1)
	var rep := Evaluation.evaluate(m.evaluation_data(false))
	if rep["grade"] != "S":
		return "clean round grade %s (%.1f)" % [rep["grade"], rep["total"]]
	if rep["dims"]["direction"] != null:
		return "direction should be n/a in keyboard mode"
	var m2 := RockingModel.new(2)
	_start(m2)
	_half(m2, 1)
	_feed(m2, 0.46, 0.1)
	var rep2 := Evaluation.evaluate(m2.evaluation_data(false))
	if rep2["grade"] != "F":
		return "failed round grade %s" % rep2["grade"]
	return ""
