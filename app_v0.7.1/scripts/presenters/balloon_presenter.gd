extends Node
## Presenter — Rocking Challenge Level B, "Bunny's Balloons" (v0.6.0).
## Each frame: reads the input source → steps BalloonModel → turns the model's state and events into calls
## on BalloonView → writes the CSV log row. At the end of a round: evaluation, history in the database,
## and the result panel. v0.7.1: Level B has its own 20 achievements (checked at the end of the round).
## Run balloon_game.tscn alone (F6) to play without the app (Trainee Dentist, Chinese).

signal exit_requested

const BalloonModel := preload("res://app_v0.7.1/scripts/models/balloon_model.gd")
const KeyboardSource := preload("res://app_v0.7.1/scripts/models/keyboard_ramp_source.gd")
const RoundLog := preload("res://app_v0.7.1/scripts/models/round_log.gd")
const AchievementDB := preload("res://app_v0.7.1/scripts/models/achievement_db.gd")
const AchDefs := preload("res://app_v0.7.1/scripts/models/achievement_defs.gd")
const Evaluation := preload("res://app_v0.7.1/scripts/models/evaluation_balloon.gd")
const BalloonView := preload("res://app_v0.7.1/scripts/views/balloon_view.gd")
const ReportPresenter := preload("res://app_v0.7.1/scripts/presenters/report_presenter.gd")
const ToastHost := preload("res://app_v0.7.1/scripts/views/achievement_toast_host.gd")

# ---- set by whoever starts the game
var difficulty := 1
var lang := "zh"
var time_limit := 90.0
## Real sensor: a node with read() returning {"moment_nm", optional "offaxis_nm", "pull_n"}. null = keyboard.
var sensor: Node = null
## Achievements database, used here for the round history (passed in by the app; created when run alone).
var db: AchievementDB = null

var model: BalloonModel
var input: KeyboardSource
var log_file: RoundLog
var view: BalloonView
var report_ui = null
var toasts: ToastHost
var new_ids: Array = []   # achievements unlocked by the last round (v0.7.1)

var recorded := false
var report: Dictionary = {}
var report_data: Dictionary = {}


func _ready() -> void:
	if db == null:
		db = AchievementDB.new()
	view = BalloonView.new()
	view.lang = lang
	add_child(view)
	view.again_pressed.connect(_start_round)
	view.report_pressed.connect(_open_report)
	view.back_pressed.connect(_exit)
	view.ending_finished.connect(_on_ending_finished)
	view.escape_pressed.connect(_on_escape)
	toasts = ToastHost.new()
	toasts.lang = lang
	add_child(toasts)
	_start_round()


func _start_round() -> void:
	if log_file != null:
		log_file.close()
	_close_report()
	model = BalloonModel.new(difficulty, time_limit)
	input = KeyboardSource.new(BalloonModel.OVERLOAD, BalloonModel.OFFAXIS_LIMIT)
	recorded = false
	new_ids = []
	report = {}
	report_data = {}
	view.build({"allowed": model.allowed, "timed": model.timed, "ring": model.ring_hint, "strip": model.strip_hint,
		"text": model.text_hints, "keyboard": sensor == null,
		"overload": BalloonModel.OVERLOAD, "safe_max": BalloonModel.SAFE_MAX})
	view.show_flat(0)
	log_file = RoundLog.new()
	log_file.open(model.log_header(sensor != null), "rocking_B", BalloonModel.LOG_COLUMNS)


# =====================================================================
func _process(delta: float) -> void:
	if model == null:
		return
	var d: Dictionary
	if sensor != null and sensor.has_method("read"):
		d = sensor.read()
	else:
		d = input.read(delta)
	model.step(delta, float(d.get("moment_nm", 0.0)), absf(float(d.get("offaxis_nm", 0.0))), absf(float(d.get("pull_n", 0.0))))

	for e in model.frame_events:
		_on_event(e)

	var s := {
		"active": model.is_active(),
		"torque": model.torque,
		"inflating": model.inflating,
		"guide": model.guide,
		"target": model.current_target(),
		"ring_state": model.ring_state,
		"hold_frac": model.hold_frac,
		"near_limit": model.near_limit,
		"status_key": model.status_key,
		"time_frac": clampf(model.time_left / model.time_limit, 0.0, 1.0),
	}
	if model.strip_hint:
		s["strip_t"] = model.cur_t
		s["strip_m"] = model.cur_m
	view.render(s, delta)
	view.set_debug_text("moment %.3f N·m  guide %.3f  target %.2f  off-axis %.2f  pull %.1f\nstage %s  hold %.2f s  tied %d/%d  pops %d/%d  leaks %d" % [
		model.torque, model.guide, model.current_target(), model.offaxis, model.pull,
		BalloonModel.Stage.keys()[model.stage], model.hold_t, model.tied, BalloonModel.BALLOONS,
		model.mistakes, model.allowed, model.leaks])
	log_file.write(model.log_row())


## Model events → what the player sees.
func _on_event(e: String) -> void:
	if e == "offaxis":
		view.show_offaxis()
	elif e.begins_with("balloon_"):
		var i := model.tied
		view.show_balloon_start(i, model.targets[i], model.ramp_times[i], BalloonModel.HOLD_TIME)
	elif e == "leak":
		view.show_leak()
	elif e == "pop":
		view.show_pop(model.allowed - model.mistakes)
	elif e.begins_with("tie_"):
		view.show_tie(model.tied - 1)
	elif e == "win":
		_record("win")
		view.play_win()
	elif e == "lose_broken":
		_record("broken")
		view.play_lose(true)
	elif e == "lose_timeout":
		_record("timeout")
		view.play_lose(false)


func _on_ending_finished(kind: String) -> void:
	log_file.close()
	var grade: Array = [] if report.is_empty() else [report["grade"], report["total"]]
	var names := PackedStringArray()
	for id in new_ids:
		names.append(AchDefs.text(AchDefs.get_def(id), "name", lang))
	view.show_result(kind, [model.tied, BalloonModel.BALLOONS, model.mistakes, model.leaks, model.elapsed],
		grade, names)


func _on_escape() -> void:
	if report_ui != null:
		_close_report()
		return
	if model.abort():
		log_file.write(model.log_row())
		_record("abort")
	_exit()


func _exit() -> void:
	log_file.close()
	if exit_requested.get_connections().is_empty():
		_start_round() # 单独运行本场景时没有选择页，直接重开
	else:
		exit_requested.emit()


func _exit_tree() -> void:
	if log_file != null:
		log_file.close()


# =====================================================================
## End of the round (cleared, popped too often, time up or quit): evaluation and history.
func _record(result: String) -> void:
	if recorded or db == null:
		return
	recorded = true
	var r := model.summary()
	r["result"] = result
	r["game"] = AchDefs.GAME_BALLOON
	r["rocks"] = model.tied
	r["rocks_to_win"] = BalloonModel.BALLOONS
	r["log_file"] = log_file.path
	r["hour"] = int(Time.get_datetime_dict_from_system()["hour"])
	r["safe_max"] = BalloonModel.SAFE_MAX
	r["track_rmse"] = -1.0
	if model.s_t.size() >= 2:
		report_data = model.evaluation_data(sensor != null)
		report_data["result"] = result
		report_data["log_file"] = log_file.path
		report_data["at"] = Time.get_datetime_string_from_system(false, true)
		report = Evaluation.evaluate(report_data)
		r["evaluation"] = {"total": report["total"], "grade": report["grade"], "dims": report["dims"]}
		r["track_rmse"] = float(report["metrics"]["track_rmse_nm"])
	new_ids = db.record_round(r)
	_toast(new_ids)


## Pop-ups for newly unlocked achievements (v0.7.1).
func _toast(ids: Array) -> void:
	var defs: Array = []
	for id in ids:
		defs.append(AchDefs.get_def(id))
	toasts.lang = lang
	toasts.show_defs(defs)


func _open_report() -> void:
	if report.is_empty() or report_ui != null:
		return
	var rp = ReportPresenter.new()
	rp.setup(report_data, report, lang)
	rp.closed.connect(func(): report_ui = null)
	add_child(rp)
	report_ui = rp


func _close_report() -> void:
	if report_ui != null:
		report_ui.close()
		report_ui = null
