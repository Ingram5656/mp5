extends Control
## View — the app shell (v0.5.4; v0.7.0: garden look, design/设计方案_v2.0.md): the garden backdrop,
## the header (title sign, subtitle, sensor status, language), the five pages and the dialog. Passive: it only shows what the app presenter tells
## it and reports what the user did through signals. Text keys come from the presenter; the view
## translates them for the current language.

signal language_selected(lang: String)
signal modal_closed

const P := preload("res://app_v0.7.2.1/scripts/views/palette.gd")
const Garden := preload("res://app_v0.7.2.1/scripts/views/garden.gd")
const UiKit := preload("res://app_v0.7.2.1/scripts/views/ui_kit.gd")
const ConnectView := preload("res://app_v0.7.2.1/scripts/views/connect_view.gd")
const EntryTestView := preload("res://app_v0.7.2.1/scripts/views/entry_test_view.gd")
const SelectView := preload("res://app_v0.7.2.1/scripts/views/select_view.gd")
const AchievementsView := preload("res://app_v0.7.2.1/scripts/views/achievements_view.gd")
const HistoryView := preload("res://app_v0.7.2.1/scripts/views/history_view.gd")

var kit: UiKit
var subtitle: Label
var status_dot: Panel
var status_label: Label
var lang_buttons: Array = []
var connect_page: ConnectView
var test_page: EntryTestView
var select_page: SelectView
var ach_page: AchievementsView
var hist_page: HistoryView
var modal_layer: Control = null
var _modal: Dictionary = {}       # title, body, button keys and body args (args already plain values)
var _subtitle_key := "sub_entry"
var _status := ["st_not_connected", "idle"]
## Tone of a status → colour of the dot (colour only for state). idle: soil, busy: sun, ok: leaf, fault: tomato.
const TONES := {"idle": P.STEEL, "busy": P.SUN, "ok": P.LEAF, "plain": P.LEAF, "fault": P.TOMATO}


## config: lang, entry_targets (see EntryTestView.build), game_count, difficulty_count, ach_filter
func setup(config: Dictionary) -> void:
	kit = UiKit.new()
	kit.lang = config["lang"]
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = kit.build_theme()

	add_child(Garden.backdrop())

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 54)   # room for the board posts in the soil
	add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	margin.add_child(root)

	# header: title sign and subtitle left, sensor state and language right
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	root.add_child(header)
	var title_sign := PanelContainer.new()
	title_sign.add_theme_stylebox_override("panel", Garden.sign_box(false, 12, 2))
	title_sign.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	title_sign.rotation = deg_to_rad(-1.5)
	title_sign.add_child(kit.tdisplay("app_title", P.FS_TITLE, P.INK))
	header.add_child(title_sign)
	var sub_pill := PanelContainer.new()
	sub_pill.add_theme_stylebox_override("panel", kit.box(P.PAPER, P.INK, P.LINE, 999, 12, 2))
	sub_pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	subtitle = kit.label("", P.FS_BODY, P.INK, true)
	sub_pill.add_child(subtitle)
	header.add_child(sub_pill)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(spacer)

	var status_pill := PanelContainer.new()
	status_pill.add_theme_stylebox_override("panel", kit.box(P.PAPER, P.INK, P.LINE, 999, 10, 3))
	status_pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(status_pill)
	var status_row := HBoxContainer.new()
	status_row.add_theme_constant_override("separation", 8)
	status_pill.add_child(status_row)
	status_dot = Panel.new()
	status_dot.custom_minimum_size = Vector2(14, 14)
	status_dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	status_row.add_child(status_dot)
	status_label = kit.label("", P.FS_SMALL, P.INK, true)
	status_row.add_child(status_label)

	var lang_row := HBoxContainer.new()
	lang_row.add_theme_constant_override("separation", 4)
	lang_row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(lang_row)
	var lg := ButtonGroup.new()
	for pair in [["en", "EN"], ["zh", "中文"]]:
		var b: Button = kit.toggle(pair[1], lg)
		b.custom_minimum_size = Vector2(52, 0)
		var code: String = pair[0]
		b.pressed.connect(func(): language_selected.emit(code))
		lang_row.add_child(b)
		lang_buttons.append(b)

	var pages := Control.new()
	pages.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(pages)
	connect_page = ConnectView.new()
	connect_page.build(kit)
	pages.add_child(connect_page)
	test_page = EntryTestView.new()
	test_page.build(kit, config["entry_targets"])
	test_page.visible = false
	pages.add_child(test_page)
	select_page = SelectView.new()
	select_page.build(kit, config["game_count"], config["difficulty_count"])
	select_page.visible = false
	pages.add_child(select_page)
	ach_page = AchievementsView.new()
	ach_page.build(kit, config["ach_filter"])
	ach_page.visible = false
	pages.add_child(ach_page)
	hist_page = HistoryView.new()
	hist_page.build(kit)
	hist_page.visible = false
	pages.add_child(hist_page)


# ------------------------------------------------------------------ language
## Re-translate everything that is static; the presenter then re-sends anything dynamic.
func set_language(lang: String) -> void:
	kit.apply_language(lang)
	for i in range(lang_buttons.size()):
		lang_buttons[i].set_pressed_no_signal((i == 0) == (lang == "en"))
	subtitle.text = kit.t(_subtitle_key)
	status_label.text = kit.t(_status[0])
	connect_page.relocalize()
	test_page.relocalize()
	select_page.relocalize()
	if modal_layer != null and not _modal.is_empty():
		_render_modal()


# ------------------------------------------------------------------ header and pages
## tone: "idle", "busy", "ok", "fault"
func set_sensor_status(key: String, tone: String) -> void:
	_status = [key, tone]
	status_label.text = kit.t(key)
	status_dot.add_theme_stylebox_override("panel", kit.box(TONES.get(tone, P.STEEL), P.INK, P.LINE, 999))


## page: "connect", "test", "select", "achievements", "history"
func show_page(page: String, sub_key: String) -> void:
	connect_page.visible = page == "connect"
	test_page.visible = page == "test"
	select_page.visible = page == "select"
	ach_page.visible = page == "achievements"
	hist_page.visible = page == "history"
	_subtitle_key = sub_key
	subtitle.text = kit.t(sub_key)


# ------------------------------------------------------------------ dialog
## body_args: plain values, or text keys (Strings) that are translated too.
func show_modal(title_key: String, body_key: String, button_key: String, body_args: Array = []) -> void:
	_modal = {"title": title_key, "body": body_key, "button": button_key, "args": body_args}
	_render_modal()


func is_modal_open() -> bool:
	return modal_layer != null


func _render_modal() -> void:
	if modal_layer != null:
		modal_layer.queue_free()
	modal_layer = Control.new()
	modal_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(modal_layer)
	var dim := ColorRect.new()
	dim.color = Color(P.INK, 0.35)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal_layer.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal_layer.add_child(center)
	# the dialog is a wooden sign (no posts: it floats over the page)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", Garden.board_box(18, 12))
	panel.custom_minimum_size = Vector2(560, 0)
	center.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 16)
	panel.add_child(v)
	v.add_child(kit.display(kit.t(_modal["title"]), P.FS_TITLE, P.INK))
	var args: Array = []
	for a in _modal["args"]:
		args.append(kit.t(a) if a is String else a)
	var b: Label = kit.label(kit.fmt(_modal["body"], args), P.FS_BODY, P.SLATE)
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.custom_minimum_size = Vector2(476, 0)
	b.add_theme_constant_override("line_spacing", 6)
	v.add_child(b)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	v.add_child(row)
	var btn: Button = kit.button(kit.t(_modal["button"]), "primary")
	btn.pressed.connect(_on_modal_button)
	row.add_child(btn)
	btn.grab_focus.call_deferred()


func _on_modal_button() -> void:
	if modal_layer != null:
		modal_layer.queue_free()
		modal_layer = null
	_modal = {}
	modal_closed.emit()
