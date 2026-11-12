extends Node
## Presenter — one evaluation report on screen (v0.5.4). Shows ReportView on its own CanvasLayer and
## saves the report through ReportExporter when the user picks a folder. Used by the carrot game's
## result panel and by the History page.

signal closed

const ReportView := preload("res://app_v0.5.4/scripts/views/report_view.gd")
const Evaluation := preload("res://app_v0.5.4/scripts/models/evaluation.gd")
const ReportExporter := preload("res://app_v0.5.4/scripts/models/report_exporter.gd")

var data: Dictionary = {}
var rep: Dictionary = {}
var lang := "zh"
var _layer: CanvasLayer
var _view


## d: evaluation data (needs "at"); r: result of Evaluation.evaluate(d).
func setup(d: Dictionary, r: Dictionary, language: String) -> void:
	data = d
	rep = r.duplicate()
	rep["order"] = Evaluation.ORDER
	rep["weights"] = Evaluation.WEIGHTS
	lang = language


func _ready() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 50
	add_child(_layer)
	_view = ReportView.new()
	_view.lang = lang
	_view.setup(data, rep)
	_view.closed.connect(close)
	_view.save_requested.connect(_on_save)
	_layer.add_child(_view)


func _on_save(dir: String, picture: Image) -> void:
	var base := ReportExporter.save_report(dir, data, rep, picture)
	_view.show_saved(base, dir)


func close() -> void:
	closed.emit()
	queue_free()
