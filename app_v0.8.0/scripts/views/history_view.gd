extends VBoxContainer
## View — History page (v0.5.4; v0.7.0: written on a sheet of note paper, design v2.0 §4.4).
## One row per round, newest first: date, game, difficulty, result, grade, score, and View report.

signal report_requested(index: int)   # index into the database's round list
signal back_pressed

const P := preload("res://app_v0.8.0/scripts/views/palette.gd")
const COLS := [["hist_col_time", 170], ["hist_col_game", 150], ["hist_col_diff", 130], ["hist_col_result", 130], ["hist_col_grade", 70], ["hist_col_score", 80]]

var kit
var summary: Label
var list: VBoxContainer
var status: Label


func build(k) -> void:
	kit = k
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_theme_constant_override("separation", 0)
	# v0.7.0: the list is written on one big sheet of note paper
	var sheet: PanelContainer = kit.paper(16, 10)
	sheet.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(sheet)
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 8)
	sheet.add_child(page)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 16)
	page.add_child(top)
	summary = kit.display("", P.FS_TITLE, P.INK)
	summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	summary.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(summary)
	var back: Button = kit.tbutton("btn_back", "secondary")
	back.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(func(): back_pressed.emit())
	top.add_child(back)
	var head := _row_box()
	for c in COLS:
		var l: Label = kit.tlabel(c[0], P.FS_SMALL, P.STEEL, true)
		l.custom_minimum_size = Vector2(c[1], 0)
		head.add_child(l)
	page.add_child(head)
	page.add_child(kit.hrule())
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	page.add_child(scroll)
	list = VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 0)
	scroll.add_child(list)
	status = kit.label("", P.FS_SMALL, P.TOMATO_TEXT, true)
	page.add_child(status)


func _row_box() -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	return h


## total: number of rounds in the database. rows (newest first): [{"index", "at", "difficulty",
## "result", "grade", "total" (float or null), "has_log", "game" ("rocking" = Level A, "balloon" = Level B)}]
func show_rounds(total: int, rows: Array) -> void:
	kit.clear(list)
	summary.text = kit.fmt("hist_count", [total])
	if rows.is_empty():
		var m := MarginContainer.new()
		m.add_theme_constant_override("margin_top", 16)
		m.add_child(kit.label(kit.t("hist_empty"), P.FS_BODY, P.STEEL))
		list.add_child(m)
		return
	for r in rows:
		list.add_child(_row(r))
		list.add_child(kit.hrule())


func show_status(key: String) -> void:
	status.text = kit.t(key) if key != "" else ""


func _row(r: Dictionary) -> Control:
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_top", 6)
	m.add_theme_constant_override("margin_bottom", 6)
	var h := _row_box()
	m.add_child(h)
	var res: String = r["result"]
	var grade: String = r["grade"]
	var res_key := "hist_res_" + res
	if r.get("game", "") == "balloon" and res == "broken":
		res_key = "hist_res_popped"
	var cells := [
		[str(r["at"]).substr(0, 16), 170, P.SLATE, false],
		[kit.t("levelB_title" if r.get("game", "") == "balloon" else "levelA_title"), 150, P.SLATE, false],
		[kit.t("diff%d_name" % clampi(int(r["difficulty"]), 0, 2)), 130, P.SLATE, false],
		[kit.t(res_key), 130, P.LEAF_TEXT if res == "win" else P.TOMATO_TEXT, true],
		[grade, 70, P.TOMATO_TEXT if grade == "F" else P.LEAF_TEXT, true],
		["%.1f" % float(r["total"]) if r["total"] != null else "—", 80, P.SLATE, false],
	]
	for c in cells:
		var l: Label = kit.label(c[0], P.FS_BODY, c[2], c[3])
		l.custom_minimum_size = Vector2(c[1], 0)
		l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(l)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(spacer)
	var b: Button = kit.button(kit.t("hist_view"), "secondary")
	b.disabled = not r["has_log"]
	var idx: int = r["index"]
	b.pressed.connect(func(): report_requested.emit(idx))
	h.add_child(b)
	return m
