extends RefCounted
## Presenter — History page (v0.5.4). Lists every round from the database, newest first, and opens a
## round's evaluation report rebuilt from its CSV log. Rounds played before v0.5.2 have no stored score;
## it is worked out the first time their report is opened and saved to the database.

const Evaluation := preload("res://app_v0.5.4/scripts/models/evaluation.gd")
const ReportPresenter := preload("res://app_v0.5.4/scripts/presenters/report_presenter.gd")
const MAX_ROWS := 200

var db
var view
var host: Node            # where report presenters are added
var report_ui = null


func _init(database, history_view, report_host: Node) -> void:
	db = database
	view = history_view
	host = report_host
	view.report_requested.connect(open_report)


func render() -> void:
	var rounds: Array = db.rounds()
	var rows: Array = []
	for i in range(rounds.size() - 1, -1, -1):
		if rows.size() >= MAX_ROWS:
			break
		var r: Dictionary = rounds[i]
		var ev: Dictionary = r.get("evaluation", {})
		rows.append({
			"index": i,
			"at": r.get("at", ""),
			"difficulty": int(r.get("difficulty", 1)),
			"result": r.get("result", "abort"),
			"grade": ev.get("grade", "—"),
			"total": ev.get("total", null),
			"has_log": str(r.get("log_file", "")) != "",
		})
	view.show_rounds(rounds.size(), rows)


func open_report(index: int) -> void:
	var rounds: Array = db.rounds()
	if index < 0 or index >= rounds.size() or report_ui != null:
		return
	var r: Dictionary = rounds[index]
	var d := Evaluation.load_csv(str(r.get("log_file", "")))
	if d.is_empty() or d["t"].size() < 2:
		view.show_status("hist_no_log")
		return
	d["at"] = r.get("at", "")
	d["difficulty"] = int(r.get("difficulty", d["difficulty"]))
	d["result"] = r.get("result", d["result"])
	var rep := Evaluation.evaluate(d)
	if not r.has("evaluation"):
		db.save_round_evaluation(index, {"total": rep["total"], "grade": rep["grade"], "dims": rep["dims"]})
		render()
	var rp = ReportPresenter.new()
	rp.setup(d, rep, view.kit.lang)
	rp.closed.connect(func(): report_ui = null)
	host.add_child(rp)
	report_ui = rp
