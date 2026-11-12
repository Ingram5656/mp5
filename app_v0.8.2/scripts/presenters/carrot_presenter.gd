extends Node
## Presenter — Rocking Challenge Level A, "Pull the Carrot" (v0.5.4).
## Each frame: reads the input source → steps RockingModel → turns the model's state and events into calls
## on CarrotView → writes the CSV log row. At the end of a round: evaluation, achievements database,
## pop-ups and the result panel. The rules live in RockingModel; the drawing lives in CarrotView.
## Run carrot_game.tscn alone (F6) to play without the app (Trainee Dentist, Chinese).

signal exit_requested

const RockingModel := preload("res://app_v0.8.2/scripts/models/rocking_model.gd")
const KeyboardSource := preload("res://app_v0.8.2/scripts/models/keyboard_moment_source.gd")
const RoundLog := preload("res://app_v0.8.2/scripts/models/round_log.gd")
const AchievementDB := preload("res://app_v0.8.2/scripts/models/achievement_db.gd")
const AchDefs := preload("res://app_v0.8.2/scripts/models/achievement_defs.gd")
const Evaluation := preload("res://app_v0.8.2/scripts/models/evaluation.gd")
const CarrotView := preload("res://app_v0.8.2/scripts/views/carrot_view.gd")
const ToastHost := preload("res://app_v0.8.2/scripts/views/achievement_toast_host.gd")
const ReportPresenter := preload("res://app_v0.8.2/scripts/presenters/report_presenter.gd")

# ---- set by whoever starts the game
var difficulty := 1
var lang := "zh"
var cycles_to_win := 6
var time_limit := 90.0
## Real sensor: a node with read() returning {"moment_nm", optional "offaxis_nm", "pull_n"}. null = keyboard.
var sensor: Node = null
## Achievements database (passed in by the app; created here when the scene runs on its own).
var db: AchievementDB = null

var model: RockingModel
var input: KeyboardSource
var log_file: RoundLog
var view: CarrotView
var toasts: ToastHost
var report_ui = null

var mid_round_ids: Array = []
var new_ids: Array = []
var recorded := false
var report: Dictionary = {}
var report_data: Dictionary = {}


func _ready() -> void:
	if db == null:
		db = AchievementDB.new()
	view = CarrotView.new()
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
	model = RockingModel.new(difficulty, cycles_to_win, time_limit)
	input = KeyboardSource.new((RockingModel.BAND_MIN + RockingModel.BAND_MAX) / 2.0,
		RockingModel.OVERLOAD, RockingModel.OFFAXIS_LIMIT)
	mid_round_ids = []
	new_ids = []
	recorded = false
	report = {}
	report_data = {}
	view.build({"band_min": RockingModel.BAND_MIN, "band_max": RockingModel.BAND_MAX, "allowed": model.allowed,
		"zone": model.zone_hints, "timed": model.timed, "text": model.text_hints, "keyboard": sensor == null})
	log_file = RoundLog.new()
	log_file.open(model.log_header(sensor != null))


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
	for id in model.frame_achievements:
		_unlock_now(id)

	view.render({
		"active": model.is_active(),
		"torque": model.torque,
		"hold_pos": model.hold_pos, "hold_neg": model.hold_neg, "near_limit": model.near_limit,
		"sparkle": model.sparkle, "tint": model.tint, "status_key": model.status_key,
		"flash_side": model.flash_side, "hint_side": model.hint_side,
		"time_frac": clampf(model.time_left / model.time_limit, 0.0, 1.0),
	}, delta)
	view.set_debug_text("moment %.3f N·m  off-axis %.2f  pull %.1f\nhold %.2f s  halves %d  rocks %d/%d  mistakes %d/%d" % [
		model.torque, model.offaxis, model.pull, model.hold_t, model.half_count, model.cycles, model.cycles_to_win,
		model.mistakes, model.allowed])
	log_file.write(model.log_row())


## Model events → what the player sees.
func _on_event(e: String) -> void:
	if e == "offaxis":
		view.show_offaxis()
	elif e == "overload":
		view.show_overload(model.mistakes, model.allowed - model.mistakes)
		get_tree().call_group("mp5_sfx", "play_overload")   # v0.8.2: "too much force" sound (only when run from the app)
	elif e.begins_with("half_"):
		view.show_progress(model.progress())
	elif e.begins_with("rock_"):
		view.show_progress(model.progress())
		view.show_rock(clampi(int(ceil(float(model.cycles) / model.cycles_to_win * 4.0)), 1, 4))
		view.set_rabbit_base("excited")
		if model.cycles < model.cycles_to_win:
			view.rabbit_temp("jump", 0.6)
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
	var names := PackedStringArray()
	for id in mid_round_ids + new_ids:
		names.append(AchDefs.text(AchDefs.get_def(id), "name", lang))
	var grade: Array = [] if report.is_empty() else [report["grade"], report["total"]]
	view.show_result(kind, [model.cycles, model.cycles_to_win, model.mistakes, model.elapsed], grade, names)


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
## End of the round (cleared, snapped, time up or quit): evaluation, database, pop-ups.
func _record(result: String) -> void:
	if recorded or db == null:
		return
	recorded = true
	var r := model.summary()
	r["result"] = result
	r["game"] = AchDefs.GAME_ROCKING
	r["hour"] = int(Time.get_datetime_dict_from_system()["hour"])
	r["log_file"] = log_file.path
	r["mid_round"] = mid_round_ids.duplicate()
	if model.s_t.size() >= 2:
		report_data = model.evaluation_data(sensor != null)
		report_data["result"] = result
		report_data["log_file"] = log_file.path
		report_data["at"] = Time.get_datetime_string_from_system(false, true)
		report = Evaluation.evaluate(report_data)
		r["evaluation"] = {"total": report["total"], "grade": report["grade"], "dims": report["dims"]}
	new_ids = db.record_round(r)
	_toast(new_ids)


## Achievements reached during play (Inside Voice, Other Left) unlock and pop up at once.
func _unlock_now(id: String) -> void:
	if db != null and db.unlock(id):
		mid_round_ids.append(id)
		_toast([id])


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
