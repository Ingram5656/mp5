extends CanvasLayer
## Top-right stack of "achievement unlocked" pop-ups (v0.5.0), on its own CanvasLayer so it is the
## same size on every screen and above the game. Each pop-up stays SHOW_TIME seconds, at most 3 at once;
## no entrance animation (design principle 4).
## View (v0.5.4): the presenter passes achievement definition dictionaries, not ids.

const UI := preload("res://app_v0.6.0/scripts/views/achievement_ui.gd")
const SHOW_TIME := 4.0
const MAX_VISIBLE := 3

var lang := "zh"
var _stack: VBoxContainer
var _queue: Array = []


func _ready() -> void:
	layer = 100
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	margin.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(margin)
	_stack = VBoxContainer.new()
	_stack.add_theme_constant_override("separation", 8)
	_stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(_stack)


func show_defs(defs: Array) -> void:
	for d in defs:
		_queue.append(d)
	_pump()


func _pump() -> void:
	while _queue.size() > 0 and _stack.get_child_count() < MAX_VISIBLE:
		var d: Dictionary = _queue.pop_front()
		if d.is_empty():
			continue
		var t: Control = UI.toast(d, lang)
		_stack.add_child(t)
		get_tree().create_timer(SHOW_TIME).timeout.connect(_remove.bind(t))


func _remove(t: Control) -> void:
	if is_instance_valid(t):
		_stack.remove_child(t)
		t.queue_free()
	_pump()
