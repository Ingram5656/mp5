extends Node
## Presenter — one evaluation report on screen (v0.5.4; v0.6.0: also the balloon game). Shows ReportView on its own CanvasLayer and
## saves the report through ReportExporter when the user picks a folder. Used by the carrot game's
## result panel and by the History page.

signal closed

const ReportView := preload("res://app_v0.8.1/scripts/views/report_view.gd")
const Evaluation := preload("res://app_v0.8.1/scripts/models/evaluation.gd")
const ReportExporter := preload("res://app_v0.8.1/scripts/models/report_exporter.gd")
const Insights := preload("res://app_v0.8.1/scripts/models/report_insights.gd")

var data: Dictionary = {}
var rep: Dictionary = {}
var lang := "zh"
var _layer: CanvasLayer
var _view
var _closing := false


## d: evaluation data (needs "at"); r: result of Evaluation.evaluate(d).
func setup(d: Dictionary, r: Dictionary, language: String) -> void:
	data = d
	rep = r.duplicate()
	if not rep.has("order"):   # evaluation_balloon.gd fills these itself (v0.6.0)
		rep["order"] = Evaluation.ORDER
		rep["weights"] = Evaluation.WEIGHTS
	lang = language


func _ready() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 50
	add_child(_layer)
	_view = ReportView.new()
	_view.lang = lang
	_view.setup(data, rep, Insights.build(data, rep))   # v0.7.2.1: "at a glance" part
	_view.closed.connect(close)
	_view.save_requested.connect(_on_save)
	_layer.add_child(_view)
	# v0.8.0: the report rises in from below with the screen-change sound
	get_tree().call_group("mp5_sfx", "play_swoosh")
	_view.modulate.a = 0.0
	_slide(60.0)
	var t := create_tween().set_parallel(true)
	t.tween_property(_view, "modulate:a", 1.0, 0.2)
	t.tween_method(_slide, 60.0, 0.0, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _on_save(dir: String, picture: Image) -> void:
	var base := ReportExporter.save_report(dir, data, rep, picture)
	_view.show_saved(base, dir)


## v0.8.0: the report drops away (0.2 s) before it is freed. Calling close() again does nothing.
func close() -> void:
	if _closing:
		return
	_closing = true
	closed.emit()
	if _view == null or not is_inside_tree():
		queue_free()
		return
	get_tree().call_group("mp5_sfx", "play_swoosh")
	var t := create_tween().set_parallel(true)
	t.tween_property(_view, "modulate:a", 0.0, 0.2)
	t.tween_method(_slide, 0.0, 50.0, 0.2).set_ease(Tween.EASE_IN)
	t.chain().tween_callback(queue_free)


## v0.8.1: moves the report down by y and keeps it the size of the window (top and bottom offsets move
## together; setting `position` could leave the report at a stale size).
func _slide(y: float) -> void:
	if _view == null:
		return
	_view.offset_top = y
	_view.offset_bottom = y
