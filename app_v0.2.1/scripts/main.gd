extends Control
## MP5 v0.2.1
## Sensor connection -> instructions -> entry test (three locks) -> success -> game selection.
## New in v0.2.1: English / Chinese language switch in the header (remembered between runs).
## Target ranges below are PLACEHOLDERS for the prototype, not validated or clinical values.

const DirectionGauge := preload("res://app_v0.2.1/scripts/direction_gauge.gd")
const ForceGauge := preload("res://app_v0.2.1/scripts/force_gauge.gd")
const MomentGauge := preload("res://app_v0.2.1/scripts/moment_gauge.gd")
const SimSensor := preload("res://app_v0.2.1/scripts/sim_sensor.gd")
const Strings := preload("res://app_v0.2.1/scripts/strings.gd")

const VERSION := "v0.2.1"
const SETTINGS_PATH := "user://mp5_settings.cfg"
const CJK_FONTS := ["Microsoft YaHei UI", "Microsoft YaHei", "PingFang SC", "Noto Sans CJK SC", "Source Han Sans SC"]

# --- placeholder targets ---
const DIR_TARGET := 45.0
const DIR_TOL := 15.0
const FORCE_MIN := 8.0
const FORCE_MAX := 12.0
const MOMENT_MIN := 0.15
const MOMENT_MAX := 0.25
const HOLD_TIME := 1.0
const DIFFICULTY_COUNT := 3

# --- palette ---
const C_BG := Color("f4f5f7")
const C_CARD := Color.WHITE
const C_BORDER := Color("dfe2e6")
const C_TEXT := Color("1f2328")
const C_MUTED := Color("6b7280")
const C_ACCENT := Color("2f6fed")
const C_ACCENT_SOFT := Color("eaf1fe")
const C_OK := Color("1f9d4c")
const C_GREEN := Color("34c759")
const C_WARN := Color("c2410c")
const C_AMBER := Color("f5a524")
const C_GREY_DOT := Color("9aa1a9")

enum State { CONNECT, TEST, DONE, SELECT }
var state: State = State.CONNECT
var lang: String = "en"

var sensor: Node
var subtitle: Label
var status_dot: Panel
var status_label: Label
var connect_page: Control
var test_page: Control
var select_page: Control
var source_select: OptionButton
var conn_status: Label
var connect_btn: Button
var continue_btn: Button
var lang_buttons: Array = []
var modal_layer: Control = null
var modal_spec: Dictionary = {}

# text bindings: [node, key, args]
var bound: Array = []
var subtitle_key := "sub_entry"
var status_key := "st_not_connected"
var conn_key := "cs_not"

# entry test
var gauges: Array = []
var readouts: Array = []
var lock_labels: Array = []
var hold_bars: Array = []
var cards: Array = []
var hold := [0.0, 0.0, 0.0]
var unlocked := [false, false, false]

# game selection
var game_cards: Array = []
var selected_game: int = -1
var selected_difficulty: int = 0
var difficulty_desc: Label
var start_btn: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_load_settings()
	sensor = SimSensor.new()
	add_child(sensor)
	_build_ui()
	_set_sensor_status("st_not_connected", C_GREY_DOT)
	_apply_language()


# ------------------------------------------------------------------ language
func t(key: String) -> String:
	return Strings.get_text(lang, key)


func _fmt(key: String, args: Array = []) -> String:
	var s := t(key)
	if args.is_empty():
		return s
	return s % args


## Set a node's text from a key and remember it so it updates on language change.
func _bind(node: Control, key: String, args: Array = []) -> Control:
	node.set("text", _fmt(key, args))
	bound.append([node, key, args])
	return node


func _set_language(new_lang: String) -> void:
	if new_lang == lang:
		return
	lang = new_lang
	_save_settings()
	_apply_language()


func _apply_language() -> void:
	_apply_font()
	for b in bound:
		(b[0] as Control).set("text", _fmt(b[1], b[2]))
	for i in range(lang_buttons.size()):
		lang_buttons[i].set_pressed_no_signal((i == 0) == (lang == "en"))
	subtitle.text = t(subtitle_key)
	status_label.text = t(status_key)
	conn_status.text = t(conn_key)
	source_select.set_item_text(0, t("src_sim"))
	source_select.set_item_text(1, t("src_usb"))
	for i in range(3):
		lock_labels[i].text = t("unlocked" if unlocked[i] else "locked")
	difficulty_desc.text = t("diff%d_desc" % selected_difficulty)
	if modal_layer != null and not modal_spec.is_empty():
		_render_modal()


## Chinese uses a system CJK font; English keeps Godot's default font.
func _apply_font() -> void:
	if lang == "zh":
		var f := SystemFont.new()
		f.font_names = PackedStringArray(CJK_FONTS)
		var th := Theme.new()
		th.default_font = f
		theme = th
	else:
		theme = null


func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		var v: String = cfg.get_value("ui", "lang", "en")
		if v == "en" or v == "zh":
			lang = v


func _save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("ui", "lang", lang)
	cfg.save(SETTINGS_PATH)


# ------------------------------------------------------------------ UI helpers
func _style(bg: Color, border: Color = C_BORDER, radius: int = 12, border_w: int = 1) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(border_w)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = 24
	sb.content_margin_right = 24
	sb.content_margin_top = 20
	sb.content_margin_bottom = 20
	return sb


func _label(text: String, font_size: int = 16, color: Color = C_TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	return l


func _tlabel(key: String, font_size: int = 16, color: Color = C_TEXT, args: Array = []) -> Label:
	var l := _label("", font_size, color)
	_bind(l, key, args)
	return l


func _button(text: String, primary: bool = true) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(140, 40)
	b.add_theme_font_size_override("font_size", 16)
	var bg := C_ACCENT if primary else Color.WHITE
	var fg := Color.WHITE if primary else C_TEXT
	var n := _style(bg, C_ACCENT if primary else C_BORDER, 8)
	n.content_margin_top = 8
	n.content_margin_bottom = 8
	n.content_margin_left = 18
	n.content_margin_right = 18
	var hv := n.duplicate()
	hv.bg_color = bg.darkened(0.08) if primary else Color("f0f2f5")
	var dis := n.duplicate()
	dis.bg_color = Color("c9d6f5") if primary else Color("f4f5f7")
	dis.border_color = dis.bg_color
	b.add_theme_stylebox_override("normal", n)
	b.add_theme_stylebox_override("hover", hv)
	b.add_theme_stylebox_override("pressed", hv)
	b.add_theme_stylebox_override("disabled", dis)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(k, fg)
	b.add_theme_color_override("font_disabled_color", Color.WHITE if primary else C_MUTED)
	return b


func _tbutton(key: String, primary: bool = true) -> Button:
	var b := _button("", primary)
	_bind(b, key)
	return b


## Toggle button used for difficulty and language choices.
func _toggle_button(text: String, group: ButtonGroup) -> Button:
	var b := _button(text, false)
	b.toggle_mode = true
	b.button_group = group
	var on := _style(C_ACCENT_SOFT, C_ACCENT, 8, 2)
	on.content_margin_top = 8
	on.content_margin_bottom = 8
	on.content_margin_left = 18
	on.content_margin_right = 18
	b.add_theme_stylebox_override("pressed", on)
	b.add_theme_stylebox_override("hover_pressed", on)
	b.add_theme_color_override("font_pressed_color", C_ACCENT)
	b.add_theme_color_override("font_hover_pressed_color", C_ACCENT)
	return b


func _card() -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _style(C_CARD))
	return p


func _ignore_mouse(node: Node) -> void:
	for child in node.get_children():
		if child is Control:
			(child as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
		_ignore_mouse(child)


# ------------------------------------------------------------------ build
func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = C_BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 32)
	add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 20)
	margin.add_child(root)

	# header
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	root.add_child(header)
	var titles := VBoxContainer.new()
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titles.add_theme_constant_override("separation", 2)
	titles.add_child(_tlabel("app_title", 26))
	subtitle = _label("", 15, C_MUTED)
	titles.add_child(subtitle)
	header.add_child(titles)

	var chip := PanelContainer.new()
	var chip_sb := _style(C_CARD, C_BORDER, 18)
	chip_sb.content_margin_top = 8
	chip_sb.content_margin_bottom = 8
	chip_sb.content_margin_left = 14
	chip_sb.content_margin_right = 16
	chip.add_theme_stylebox_override("panel", chip_sb)
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var chip_row := HBoxContainer.new()
	chip_row.add_theme_constant_override("separation", 8)
	chip.add_child(chip_row)
	status_dot = Panel.new()
	status_dot.custom_minimum_size = Vector2(12, 12)
	status_dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	chip_row.add_child(status_dot)
	status_label = _label("", 14)
	chip_row.add_child(status_label)
	header.add_child(chip)

	# language switch (labels stay in their own language)
	var lang_row := HBoxContainer.new()
	lang_row.add_theme_constant_override("separation", 4)
	lang_row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(lang_row)
	var lg := ButtonGroup.new()
	for pair in [["en", "EN"], ["zh", "中文"]]:
		var b := _toggle_button(pair[1], lg)
		b.custom_minimum_size = Vector2(64, 36)
		b.add_theme_font_size_override("font_size", 14)
		if pair[0] == "zh":
			var cjk := SystemFont.new()
			cjk.font_names = PackedStringArray(CJK_FONTS)
			b.add_theme_font_override("font", cjk)
		b.pressed.connect(_set_language.bind(pair[0]))
		lang_row.add_child(b)
		lang_buttons.append(b)

	# pages
	var pages := Control.new()
	pages.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(pages)
	connect_page = _build_connect_page()
	pages.add_child(connect_page)
	test_page = _build_test_page()
	test_page.visible = false
	pages.add_child(test_page)
	select_page = _build_select_page()
	select_page.visible = false
	pages.add_child(select_page)


func _build_connect_page() -> Control:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var card := _card()
	card.custom_minimum_size = Vector2(460, 0)
	center.add_child(card)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	card.add_child(v)
	v.add_child(_tlabel("conn_title", 20))
	var note := _tlabel("conn_note", 14, C_MUTED)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(note)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 10)
	v.add_child(grid)

	grid.add_child(_tlabel("input", 15, C_MUTED))
	source_select = OptionButton.new()
	source_select.add_item("")
	source_select.add_item("")
	source_select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	source_select.add_theme_font_size_override("font_size", 15)
	grid.add_child(source_select)

	grid.add_child(_tlabel("status", 15, C_MUTED))
	conn_status = _label("", 15)
	grid.add_child(conn_status)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_END
	buttons.add_theme_constant_override("separation", 10)
	connect_btn = _tbutton("btn_connect", false)
	connect_btn.pressed.connect(_on_connect)
	continue_btn = _tbutton("btn_continue")
	continue_btn.disabled = true
	continue_btn.pressed.connect(_on_continue)
	buttons.add_child(connect_btn)
	buttons.add_child(continue_btn)
	v.add_child(buttons)
	return center


func _build_test_page() -> Control:
	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.add_theme_constant_override("separation", 16)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(row)

	var g_dir := DirectionGauge.new()
	g_dir.target_deg = DIR_TARGET
	g_dir.tolerance_deg = DIR_TOL
	var g_force := ForceGauge.new()
	g_force.target_min = FORCE_MIN
	g_force.target_max = FORCE_MAX
	var g_mom := MomentGauge.new()
	g_mom.target_min = MOMENT_MIN
	g_mom.target_max = MOMENT_MAX
	gauges = [g_dir, g_force, g_mom]

	var title_keys := ["g_direction", "g_force", "g_moment"]
	var target_keys := ["tgt_dir", "tgt_force", "tgt_mom"]
	var target_args := [
		[int(DIR_TARGET - DIR_TOL), int(DIR_TARGET + DIR_TOL)],
		[FORCE_MIN, FORCE_MAX],
		[MOMENT_MIN, MOMENT_MAX],
	]
	for i in range(3):
		var card := _card()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cards.append(card)
		row.add_child(card)
		var cv := VBoxContainer.new()
		cv.add_theme_constant_override("separation", 10)
		card.add_child(cv)
		var tl := _tlabel(title_keys[i], 22)
		tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cv.add_child(tl)
		var g: Control = gauges[i]
		g.size_flags_vertical = Control.SIZE_EXPAND_FILL
		cv.add_child(g)
		var ro := _label("–", 18)
		ro.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		readouts.append(ro)
		cv.add_child(ro)
		var tg := _tlabel(target_keys[i], 13, C_MUTED, target_args[i])
		tg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cv.add_child(tg)
		var bar := ProgressBar.new()
		bar.max_value = HOLD_TIME
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(0, 8)
		var bg_sb := StyleBoxFlat.new()
		bg_sb.bg_color = Color("eceef1")
		bg_sb.set_corner_radius_all(4)
		var fill_sb := StyleBoxFlat.new()
		fill_sb.bg_color = C_GREEN
		fill_sb.set_corner_radius_all(4)
		bar.add_theme_stylebox_override("background", bg_sb)
		bar.add_theme_stylebox_override("fill", fill_sb)
		hold_bars.append(bar)
		cv.add_child(bar)
		var lk := _label("", 15, C_MUTED)
		lk.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lock_labels.append(lk)
		cv.add_child(lk)

	var footer := HBoxContainer.new()
	v.add_child(footer)
	var hint := _tlabel("sim_keys", 13, C_MUTED)
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	footer.add_child(hint)
	var help := _tbutton("btn_help", false)
	help.pressed.connect(_show_instructions)
	footer.add_child(help)
	return v


func _build_select_page() -> Control:
	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.add_theme_constant_override("separation", 14)

	var intro := HBoxContainer.new()
	v.add_child(intro)
	var intro_text := _tlabel("choose", 20)
	intro_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	intro.add_child(intro_text)
	intro.add_child(_tlabel("scored", 13, C_MUTED))

	# game cards
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(row)

	var icons := [MomentGauge.new(), DirectionGauge.new(), ForceGauge.new()]
	icons[0].value = 0.18
	icons[1].value_deg = 52.0
	icons[2].value = 10.0
	for i in range(3):
		var card := _card()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		card.gui_input.connect(_on_game_card_input.bind(i))
		row.add_child(card)
		game_cards.append(card)

		var cv := VBoxContainer.new()
		cv.add_theme_constant_override("separation", 8)
		card.add_child(cv)
		var tl := _tlabel("game%d_title" % i, 20)
		tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cv.add_child(tl)
		var icon: Control = icons[i]
		cv.add_child(icon)
		icon.custom_minimum_size = Vector2(120, 120)
		icon.size_flags_vertical = Control.SIZE_EXPAND_FILL
		var sk := _tlabel("game%d_skill" % i, 14, C_TEXT)
		sk.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sk.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		cv.add_child(sk)
		var lv := _tlabel("game%d_levels" % i, 13, C_MUTED)
		lv.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cv.add_child(lv)
		_ignore_mouse(card)

	# difficulty + actions
	var bar := _card()
	var bar_sb := _style(C_CARD)
	bar_sb.content_margin_top = 14
	bar_sb.content_margin_bottom = 14
	bar.add_theme_stylebox_override("panel", bar_sb)
	v.add_child(bar)
	var bh := HBoxContainer.new()
	bh.add_theme_constant_override("separation", 10)
	bar.add_child(bh)

	var dv := VBoxContainer.new()
	dv.add_theme_constant_override("separation", 8)
	dv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bh.add_child(dv)
	var drow := HBoxContainer.new()
	drow.add_theme_constant_override("separation", 8)
	dv.add_child(drow)
	var dl := _tlabel("difficulty", 15, C_MUTED)
	dl.custom_minimum_size = Vector2(80, 0)
	drow.add_child(dl)
	var group := ButtonGroup.new()
	for i in range(DIFFICULTY_COUNT):
		var b := _toggle_button("", group)
		_bind(b, "diff%d_name" % i)
		b.custom_minimum_size = Vector2(0, 36)
		b.button_pressed = i == selected_difficulty
		b.pressed.connect(_on_difficulty.bind(i))
		drow.add_child(b)
	difficulty_desc = _label("", 13, C_MUTED)
	dv.add_child(difficulty_desc)

	var recheck := _tbutton("btn_recheck", false)
	recheck.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	recheck.pressed.connect(_on_recheck)
	bh.add_child(recheck)
	start_btn = _tbutton("btn_start")
	start_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	start_btn.disabled = true
	start_btn.pressed.connect(_on_start)
	bh.add_child(start_btn)
	return v


# ------------------------------------------------------------------ status
func _set_sensor_status(key: String, color: Color) -> void:
	status_key = key
	status_label.text = t(key)
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(6)
	status_dot.add_theme_stylebox_override("panel", sb)


func _set_conn_status(key: String, color: Color) -> void:
	conn_key = key
	conn_status.text = t(key)
	conn_status.add_theme_color_override("font_color", color)


func _show_page(page: Control, sub_key: String) -> void:
	connect_page.visible = page == connect_page
	test_page.visible = page == test_page
	select_page.visible = page == select_page
	subtitle_key = sub_key
	subtitle.text = t(sub_key)


# ------------------------------------------------------------------ connect page
func _on_connect() -> void:
	connect_btn.disabled = true
	continue_btn.disabled = true
	if source_select.selected == 1:
		_set_conn_status("cs_usb", C_WARN)
		_set_sensor_status("st_unavailable", C_WARN)
		connect_btn.disabled = false
		return
	_set_conn_status("cs_connecting", C_TEXT)
	_set_sensor_status("st_connecting", C_AMBER)
	await get_tree().create_timer(0.8).timeout
	if sensor.connect_sensor():
		_set_conn_status("cs_connected", C_OK)
		_set_sensor_status("st_connected", C_GREEN)
		continue_btn.disabled = false
	connect_btn.disabled = false


func _on_continue() -> void:
	_start_entry_test()


func _start_entry_test() -> void:
	_reset_locks()
	_show_page(test_page, "sub_entry")
	state = State.TEST
	_show_instructions()


# ------------------------------------------------------------------ modal
## Modal text is stored as keys so an open modal can be re-rendered after a language change.
func _show_modal(title_key: String, body_key: String, button_key: String,
		on_close: Callable = Callable(), body_args: Array = []) -> void:
	modal_spec = {
		"title": title_key, "body": body_key, "button": button_key,
		"on_close": on_close, "args": body_args,
	}
	_render_modal()


func _render_modal() -> void:
	if modal_layer != null:
		modal_layer.queue_free()
	modal_layer = Control.new()
	modal_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(modal_layer)
	var dim := ColorRect.new()
	dim.color = Color(0.07, 0.09, 0.12, 0.45)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal_layer.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal_layer.add_child(center)
	var card := _card()
	card.custom_minimum_size = Vector2(500, 0)
	center.add_child(card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	card.add_child(v)
	v.add_child(_label(t(modal_spec["title"]), 22))
	# String args are translated too, so names inside a message follow the language.
	var args: Array = []
	for a in modal_spec["args"]:
		args.append(t(a) if a is String else a)
	var b := _label(_fmt(modal_spec["body"], args), 15, Color("374151"))
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.custom_minimum_size = Vector2(452, 0)
	v.add_child(b)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	v.add_child(row)
	var btn := _button(t(modal_spec["button"]))
	btn.pressed.connect(_on_modal_button)
	row.add_child(btn)
	btn.grab_focus.call_deferred()


func _on_modal_button() -> void:
	var on_close: Callable = modal_spec.get("on_close", Callable())
	_close_modal()
	if on_close.is_valid():
		on_close.call()


func _close_modal() -> void:
	if modal_layer != null:
		modal_layer.queue_free()
		modal_layer = null
	modal_spec = {}


func _show_instructions() -> void:
	_show_modal("help_title", "help_body", "btn_start")


# ------------------------------------------------------------------ entry test loop
func _process(delta: float) -> void:
	if state != State.TEST or not sensor.is_valid():
		return
	var s: Dictionary = sensor.read()
	var dir: float = s["direction_deg"]
	var force: float = s["force_n"]
	var mom: float = s["moment_nm"]

	gauges[0].value_deg = dir
	gauges[1].value = force
	gauges[2].value = mom
	readouts[0].text = "%d°" % int(round(fposmod(dir, 360.0)))
	readouts[1].text = "%.1f N" % force
	readouts[2].text = "%.2f N·m" % mom

	var in_zone := [
		absf(angle_difference(deg_to_rad(dir), deg_to_rad(DIR_TARGET))) <= deg_to_rad(DIR_TOL),
		force >= FORCE_MIN and force <= FORCE_MAX,
		mom >= MOMENT_MIN and mom <= MOMENT_MAX,
	]
	var paused := modal_layer != null
	for i in range(3):
		if not unlocked[i] and not paused:
			hold[i] = hold[i] + delta if in_zone[i] else 0.0
			if hold[i] >= HOLD_TIME:
				_unlock(i)
		hold_bars[i].value = HOLD_TIME if unlocked[i] else hold[i]
		gauges[i].queue_redraw()

	if unlocked[0] and unlocked[1] and unlocked[2]:
		state = State.DONE
		await get_tree().create_timer(0.5).timeout
		_show_modal("ok_title", "ok_body", "btn_continue", _show_select)


func _unlock(i: int) -> void:
	unlocked[i] = true
	gauges[i].unlocked = true
	lock_labels[i].text = t("unlocked")
	lock_labels[i].add_theme_color_override("font_color", C_OK)
	cards[i].add_theme_stylebox_override("panel", _style(C_CARD, C_GREEN, 12, 2))


func _reset_locks() -> void:
	for i in range(3):
		unlocked[i] = false
		hold[i] = 0.0
		gauges[i].unlocked = false
		gauges[i].queue_redraw()
		hold_bars[i].value = 0.0
		lock_labels[i].text = t("locked")
		lock_labels[i].add_theme_color_override("font_color", C_MUTED)
		cards[i].add_theme_stylebox_override("panel", _style(C_CARD))


# ------------------------------------------------------------------ game selection
func _show_select() -> void:
	state = State.SELECT
	_show_page(select_page, "sub_select")


func _on_game_card_input(event: InputEvent, i: int) -> void:
	var mb := event as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		_select_game(i)


func _select_game(i: int) -> void:
	selected_game = i
	for k in range(game_cards.size()):
		var on: bool = k == i
		var sb := _style(C_ACCENT_SOFT if on else C_CARD, C_ACCENT if on else C_BORDER, 12, 2 if on else 1)
		game_cards[k].add_theme_stylebox_override("panel", sb)
	start_btn.disabled = false


func _on_difficulty(i: int) -> void:
	selected_difficulty = i
	difficulty_desc.text = t("diff%d_desc" % i)


func _on_recheck() -> void:
	sensor.reset_values()
	_start_entry_test()


func _on_start() -> void:
	if selected_game < 0:
		return
	_show_modal("soon_title", "soon_body", "btn_ok", Callable(), [
		"game%d_title" % selected_game, "diff%d_name" % selected_difficulty])
