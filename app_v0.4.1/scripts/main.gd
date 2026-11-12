extends Control
## MP5 v0.4.1 — the Rocking Challenge entry on the game selection page now shows the carrot game
## (title, text and a cover picture). v0.4.0 added the carrot game. Otherwise the same as v0.3.1
## (design/设计方案_v1.1.md, deeper target-zone green, no "-0.00" readout).
## Flow: sensor connection -> instructions -> entry test (three locks) -> success -> game selection.
## Fonts: Atkinson Hyperlegible Next (Latin, digits, tabular readouts) with Noto Sans SC fallback (Chinese),
## loaded from res://fonts/. If the fonts are missing the app still runs with Godot's default font.
## Target ranges below are PLACEHOLDERS for the prototype, not validated or clinical values.

const P := preload("res://app_v0.4.1/scripts/palette.gd")
const DirectionGauge := preload("res://app_v0.4.1/scripts/direction_gauge.gd")
const ForceGauge := preload("res://app_v0.4.1/scripts/force_gauge.gd")
const MomentGauge := preload("res://app_v0.4.1/scripts/moment_gauge.gd")
const SimSensor := preload("res://app_v0.4.1/scripts/sim_sensor.gd")
const Strings := preload("res://app_v0.4.1/scripts/strings.gd")
const CarrotGame := preload("res://app_v0.4.1/scripts/carrot_game.gd")

const VERSION := "v0.4.1"
const SETTINGS_PATH := "user://mp5_settings.cfg"

# --- placeholder targets ---
const DIR_TARGET := 45.0
const DIR_TOL := 15.0
const FORCE_MIN := 8.0
const FORCE_MAX := 12.0
const MOMENT_MIN := 0.15
const MOMENT_MAX := 0.25
const HOLD_TIME := 1.0
const GAME_COUNT := 3
const C_SLATE := Color("1c2733")   # same as P.SLATE; used for default arguments
const DIFFICULTY_COUNT := 3

enum State { CONNECT, TEST, DONE, SELECT }
var state: State = State.CONNECT
var lang: String = "en"

# fonts
var font_bold: Font = null
var font_readout: Font = null

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

var bound: Array = []           # [node, key, args]
var subtitle_key := "sub_entry"
var status_key := "st_not_connected"
var conn_key := "cs_not"

# entry test
var gauges: Array = []
var readouts: Array = []
var lock_labels: Array = []
var hold_bars: Array = []
var hold := [0.0, 0.0, 0.0]
var unlocked := [false, false, false]

# game selection
var list_rows: Array = []       # PanelContainer
var list_titles: Array = []     # Label
var hovered_row: int = -1
var detail_title: Label
var detail_skill: Label
var detail_levels: Label
var detail_icons: Array = []
var detail_icon_box: Control    # gauge icons (games 1 and 2)
var detail_cover: Control       # carrot game cover picture (game 0)
const ROCKING_COVER := "res://assets/carrot_game/cover_rocking.png"
var selected_game: int = 0
var selected_difficulty: int = 0
var difficulty_desc: Label
var start_btn: Button
var game_node: Node = null      # running game (Rocking Challenge)
var hidden_ui: Array = []       # app UI hidden while a game runs


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_load_settings()
	_setup_theme()
	sensor = SimSensor.new()
	add_child(sensor)
	_build_ui()
	_set_sensor_status("st_not_connected", P.STEEL)
	_select_game(0)
	_apply_language()


# ------------------------------------------------------------------ fonts / theme
func _load_font(file_name: String) -> FontFile:
	var path: String = P.FONT_DIR + file_name
	if ResourceLoader.exists(path):
		return load(path) as FontFile
	push_warning("Font not found: " + path)
	return null


func _setup_theme() -> void:
	var reg := _load_font("AtkinsonHyperlegibleNext-Regular.ttf")
	var bold := _load_font("AtkinsonHyperlegibleNext-Bold.ttf")
	var cjk_reg := _load_font("NotoSansSC-Regular.ttf")
	var cjk_bold := _load_font("NotoSansSC-Bold.ttf")
	var th := Theme.new()
	th.default_font_size = P.FS_BODY
	if reg != null:
		if cjk_reg != null:
			var fb: Array[Font] = [cjk_reg]
			reg.fallbacks = fb
		th.default_font = reg
	if bold != null:
		if cjk_bold != null:
			var fbb: Array[Font] = [cjk_bold]
			bold.fallbacks = fbb
		font_bold = bold
		# readouts: bold with tabular figures so changing digits do not shift
		var fv := FontVariation.new()
		fv.base_font = bold
		var tnum: int = TextServerManager.get_primary_interface().name_to_tag("tnum")
		fv.opentype_features = {tnum: 1}
		font_readout = fv
	theme = th


# ------------------------------------------------------------------ language
func t(key: String) -> String:
	return Strings.get_text(lang, key)


func _fmt(key: String, args: Array = []) -> String:
	var s := t(key)
	if args.is_empty():
		return s
	return s % args


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
	_refresh_detail()
	if modal_layer != null and not modal_spec.is_empty():
		_render_modal()


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
func _box(bg: Color, border: Color = Color(0, 0, 0, 0), border_w: int = 0, radius: int = 0,
		pad_h: int = 0, pad_v: int = 0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(border_w)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = pad_h
	sb.content_margin_right = pad_h
	sb.content_margin_top = pad_v
	sb.content_margin_bottom = pad_v
	return sb


func _focus_box() -> StyleBoxFlat:
	var sb := _box(Color(0, 0, 0, 0), P.SLATE, 2, 8)
	sb.draw_center = false
	sb.set_expand_margin_all(3)
	return sb


func _label(text: String, font_size: int = 16, color: Color = C_SLATE, bold: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	if bold and font_bold != null:
		l.add_theme_font_override("font", font_bold)
	return l


func _tlabel(key: String, font_size: int = 16, color: Color = C_SLATE, bold: bool = false,
		args: Array = []) -> Label:
	var l := _label("", font_size, color, bold)
	_bind(l, key, args)
	return l


func _set_bold(l: Label, bold: bool) -> void:
	if bold and font_bold != null:
		l.add_theme_font_override("font", font_bold)
	else:
		l.remove_theme_font_override("font")


## kind: "primary" (slate fill) or "secondary" (outline).
func _button(text: String, kind: String = "primary") -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(120, 40)
	b.add_theme_font_size_override("font_size", P.FS_BODY)
	b.focus_mode = Control.FOCUS_ALL
	var normal: StyleBoxFlat
	var hover: StyleBoxFlat
	var fg: Color
	if kind == "primary":
		normal = _box(P.SLATE, P.SLATE, 1, 6, 20, 9)
		hover = _box(P.SLATE.lightened(0.15), P.SLATE.lightened(0.15), 1, 6, 20, 9)
		fg = Color.WHITE
		if font_bold != null:
			b.add_theme_font_override("font", font_bold)
	else:
		normal = _box(Color(0, 0, 0, 0), P.CONTROL_BORDER, 1, 6, 20, 9)
		hover = _box(P.HOVER, P.CONTROL_BORDER, 1, 6, 20, 9)
		fg = P.SLATE
	var disabled := _box(P.TRACK, P.TRACK, 1, 6, 20, 9)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", hover)
	b.add_theme_stylebox_override("disabled", disabled)
	b.add_theme_stylebox_override("focus", _focus_box())
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(k, fg)
	b.add_theme_color_override("font_disabled_color", P.STEEL)
	return b


func _tbutton(key: String, kind: String = "primary") -> Button:
	var b := _button("", kind)
	_bind(b, key)
	return b


## Segmented toggle (difficulty, language): selected = white with slate outline.
func _toggle(text: String, group: ButtonGroup) -> Button:
	var b := Button.new()
	b.text = text
	b.toggle_mode = true
	b.button_group = group
	b.custom_minimum_size = Vector2(0, 36)
	b.add_theme_font_size_override("font_size", P.FS_BODY)
	var off := _box(Color(0, 0, 0, 0), P.CONTROL_BORDER, 1, 6, 16, 7)
	var off_hover := _box(P.HOVER, P.CONTROL_BORDER, 1, 6, 16, 7)
	var on := _box(P.SURFACE, P.SLATE, 2, 6, 16, 7)
	b.add_theme_stylebox_override("normal", off)
	b.add_theme_stylebox_override("hover", off_hover)
	b.add_theme_stylebox_override("pressed", on)
	b.add_theme_stylebox_override("hover_pressed", on)
	b.add_theme_stylebox_override("focus", _focus_box())
	b.add_theme_color_override("font_color", P.STEEL)
	b.add_theme_color_override("font_hover_color", P.SLATE)
	b.add_theme_color_override("font_focus_color", P.STEEL)
	b.add_theme_color_override("font_pressed_color", P.SLATE)
	b.add_theme_color_override("font_hover_pressed_color", P.SLATE)
	return b


func _hrule() -> ColorRect:
	var r := ColorRect.new()
	r.color = P.RULE
	r.custom_minimum_size = Vector2(0, 1)
	return r


func _vrule() -> ColorRect:
	var r := ColorRect.new()
	r.color = P.RULE
	r.custom_minimum_size = Vector2(1, 0)
	return r


func _ignore_mouse(node: Node) -> void:
	for child in node.get_children():
		if child is Control:
			(child as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
		_ignore_mouse(child)


# ------------------------------------------------------------------ build
func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = P.PORCELAIN
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 40)
	margin.add_theme_constant_override("margin_right", 40)
	margin.add_theme_constant_override("margin_top", 28)
	margin.add_theme_constant_override("margin_bottom", 28)
	add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 18)
	margin.add_child(root)

	# header: title left, sensor state and language right
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 20)
	root.add_child(header)
	var titles := VBoxContainer.new()
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titles.add_theme_constant_override("separation", 0)
	titles.add_child(_tlabel("app_title", P.FS_TITLE, P.SLATE, true))
	subtitle = _label("", P.FS_BODY, P.STEEL)
	titles.add_child(subtitle)
	header.add_child(titles)

	var status_row := HBoxContainer.new()
	status_row.add_theme_constant_override("separation", 8)
	status_row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	status_dot = Panel.new()
	status_dot.custom_minimum_size = Vector2(10, 10)
	status_dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	status_row.add_child(status_dot)
	status_label = _label("", P.FS_BODY, P.SLATE)
	status_row.add_child(status_label)
	header.add_child(status_row)

	var lang_row := HBoxContainer.new()
	lang_row.add_theme_constant_override("separation", 4)
	lang_row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(lang_row)
	var lg := ButtonGroup.new()
	for pair in [["en", "EN"], ["zh", "中文"]]:
		var b := _toggle(pair[1], lg)
		b.custom_minimum_size = Vector2(56, 34)
		b.pressed.connect(_set_language.bind(pair[0]))
		lang_row.add_child(b)
		lang_buttons.append(b)

	root.add_child(_hrule())

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
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _box(P.SURFACE, P.RULE, 1, 0, 32, 28))
	panel.custom_minimum_size = Vector2(500, 0)
	center.add_child(panel)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 16)
	panel.add_child(v)
	v.add_child(_tlabel("conn_title", P.FS_TITLE, P.SLATE, true))
	var note := _tlabel("conn_note", P.FS_BODY, P.STEEL)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(note)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 20)
	grid.add_theme_constant_override("v_separation", 12)
	v.add_child(grid)
	var in_l := _tlabel("input", P.FS_BODY, P.STEEL)
	in_l.custom_minimum_size = Vector2(90, 0)
	grid.add_child(in_l)
	source_select = OptionButton.new()
	source_select.add_item("")
	source_select.add_item("")
	source_select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	source_select.add_theme_font_size_override("font_size", P.FS_BODY)
	source_select.add_theme_stylebox_override("normal", _box(P.SURFACE, P.CONTROL_BORDER, 1, 6, 12, 7))
	source_select.add_theme_stylebox_override("hover", _box(P.HOVER, P.CONTROL_BORDER, 1, 6, 12, 7))
	source_select.add_theme_stylebox_override("pressed", _box(P.HOVER, P.SLATE, 1, 6, 12, 7))
	source_select.add_theme_stylebox_override("focus", _focus_box())
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		source_select.add_theme_color_override(k, P.SLATE)
	grid.add_child(source_select)
	grid.add_child(_tlabel("status", P.FS_BODY, P.STEEL))
	conn_status = _label("", P.FS_BODY, P.SLATE)
	grid.add_child(conn_status)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_END
	buttons.add_theme_constant_override("separation", 10)
	connect_btn = _tbutton("btn_connect", "secondary")
	connect_btn.pressed.connect(_on_connect)
	continue_btn = _tbutton("btn_continue", "primary")
	continue_btn.disabled = true
	continue_btn.pressed.connect(_on_continue)
	buttons.add_child(connect_btn)
	buttons.add_child(continue_btn)
	v.add_child(buttons)
	return center


func _build_test_page() -> Control:
	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.add_theme_constant_override("separation", 14)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 0)
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
		if i > 0:
			row.add_child(_vrule())
		var col_margin := MarginContainer.new()
		col_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col_margin.add_theme_constant_override("margin_left", 20)
		col_margin.add_theme_constant_override("margin_right", 20)
		row.add_child(col_margin)
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 6)
		col_margin.add_child(col)

		var tl := _tlabel(title_keys[i], P.FS_LABEL, P.SLATE)
		tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(tl)
		var g: Control = gauges[i]
		g.size_flags_vertical = Control.SIZE_EXPAND_FILL
		col.add_child(g)
		var ro := _label("–", P.FS_READOUT, P.SLATE)
		if font_readout != null:
			ro.add_theme_font_override("font", font_readout)
		ro.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		readouts.append(ro)
		col.add_child(ro)
		var tg := _tlabel(target_keys[i], P.FS_SMALL, P.STEEL, false, target_args[i])
		tg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(tg)

		var bar_margin := MarginContainer.new()
		bar_margin.add_theme_constant_override("margin_left", 36)
		bar_margin.add_theme_constant_override("margin_right", 36)
		bar_margin.add_theme_constant_override("margin_top", 6)
		col.add_child(bar_margin)
		var bar := ProgressBar.new()
		bar.max_value = HOLD_TIME
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(0, 4)
		bar.add_theme_stylebox_override("background", _box(P.TRACK, Color(0, 0, 0, 0), 0, 2))
		bar.add_theme_stylebox_override("fill", _box(P.TARGET, Color(0, 0, 0, 0), 0, 2))
		hold_bars.append(bar)
		bar_margin.add_child(bar)

		var lk := _label("", P.FS_BODY, P.STEEL)
		lk.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lock_labels.append(lk)
		col.add_child(lk)

	v.add_child(_hrule())
	var footer := HBoxContainer.new()
	v.add_child(footer)
	var hint := _tlabel("sim_keys", P.FS_SMALL, P.STEEL)
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	footer.add_child(hint)
	var help := _tbutton("btn_help", "secondary")
	help.pressed.connect(_show_instructions)
	footer.add_child(help)
	return v


func _build_select_page() -> Control:
	var h := HBoxContainer.new()
	h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	h.add_theme_constant_override("separation", 0)

	# left: list of games
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(300, 0)
	left.add_theme_constant_override("separation", 0)
	h.add_child(left)
	var list_head := MarginContainer.new()
	list_head.add_theme_constant_override("margin_bottom", 10)
	list_head.add_child(_tlabel("choose", P.FS_SMALL, P.STEEL))
	left.add_child(list_head)
	left.add_child(_hrule())
	for i in range(GAME_COUNT):
		var rowp := PanelContainer.new()
		rowp.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		rowp.gui_input.connect(_on_row_input.bind(i))
		rowp.mouse_entered.connect(_on_row_hover.bind(i, true))
		rowp.mouse_exited.connect(_on_row_hover.bind(i, false))
		left.add_child(rowp)
		list_rows.append(rowp)
		var rv := VBoxContainer.new()
		rv.add_theme_constant_override("separation", 2)
		rowp.add_child(rv)
		var rt := _tlabel("game%d_title" % i, P.FS_LABEL, P.SLATE)
		rv.add_child(rt)
		list_titles.append(rt)
		rv.add_child(_tlabel("game%d_short" % i, P.FS_SMALL, P.STEEL))
		_ignore_mouse(rowp)
		left.add_child(_hrule())
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(spacer)
	var recheck_row := HBoxContainer.new()
	var recheck := _tbutton("btn_recheck", "secondary")
	recheck.pressed.connect(_on_recheck)
	recheck_row.add_child(recheck)
	left.add_child(recheck_row)

	h.add_child(_vrule())

	# right: details of the selected game
	var right_margin := MarginContainer.new()
	right_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_margin.add_theme_constant_override("margin_left", 36)
	h.add_child(right_margin)
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 10)
	right_margin.add_child(right)

	detail_title = _label("", P.FS_TITLE, P.SLATE, true)
	right.add_child(detail_title)
	detail_skill = _label("", P.FS_BODY, P.SLATE)
	detail_skill.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right.add_child(detail_skill)

	var mid := HBoxContainer.new()
	mid.add_theme_constant_override("separation", 28)
	mid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(mid)
	# carrot game cover picture, shown instead of a gauge icon for the Rocking Challenge
	var cover := PanelContainer.new()
	var cover_box := _box(P.SURFACE, P.RULE, 1, 10)
	cover.add_theme_stylebox_override("panel", cover_box)
	cover.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	cover.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pic := TextureRect.new()
	pic.custom_minimum_size = Vector2(320, 180)
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if ResourceLoader.exists(ROCKING_COVER):
		pic.texture = load(ROCKING_COVER)
	cover.add_child(pic)
	mid.add_child(cover)
	detail_cover = cover
	var icon_box := Control.new()
	icon_box.custom_minimum_size = Vector2(170, 170)
	icon_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mid.add_child(icon_box)
	detail_icon_box = icon_box
	var icons := [MomentGauge.new(), DirectionGauge.new(), ForceGauge.new()]
	icons[0].value = 0.2
	icons[1].value_deg = 50.0
	icons[2].value = 10.0
	icons[2].show_scale = false
	for icon in icons:
		icon.custom_minimum_size = Vector2(170, 170)
		icon.zone_mix = 0.35
		icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon_box.add_child(icon)
	detail_icons = icons
	var lv := VBoxContainer.new()
	lv.add_theme_constant_override("separation", 6)
	lv.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	lv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.add_child(lv)
	lv.add_child(_tlabel("levels", P.FS_SMALL, P.STEEL))
	detail_levels = _label("", P.FS_BODY, P.SLATE)
	detail_levels.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lv.add_child(detail_levels)

	right.add_child(_tlabel("difficulty", P.FS_SMALL, P.STEEL))
	var drow := HBoxContainer.new()
	drow.add_theme_constant_override("separation", 8)
	right.add_child(drow)
	var group := ButtonGroup.new()
	for i in range(DIFFICULTY_COUNT):
		var b := _toggle("", group)
		_bind(b, "diff%d_name" % i)
		b.button_pressed = i == selected_difficulty
		b.pressed.connect(_on_difficulty.bind(i))
		drow.add_child(b)
	difficulty_desc = _label("", P.FS_SMALL, P.STEEL)
	right.add_child(difficulty_desc)

	var start_row := HBoxContainer.new()
	start_row.alignment = BoxContainer.ALIGNMENT_END
	right.add_child(start_row)
	start_btn = _tbutton("btn_start", "primary")
	start_btn.custom_minimum_size = Vector2(160, 44)
	start_btn.pressed.connect(_on_start)
	start_row.add_child(start_btn)
	return h


# ------------------------------------------------------------------ status
func _set_sensor_status(key: String, color: Color) -> void:
	status_key = key
	status_label.text = t(key)
	status_dot.add_theme_stylebox_override("panel", _box(color, Color(0, 0, 0, 0), 0, 5))


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
		_set_conn_status("cs_usb", P.FAULT)
		_set_sensor_status("st_unavailable", P.FAULT)
		connect_btn.disabled = false
		return
	_set_conn_status("cs_connecting", P.CAUTION)
	_set_sensor_status("st_connecting", P.CAUTION)
	await get_tree().create_timer(0.8).timeout
	if sensor.connect_sensor():
		_set_conn_status("cs_connected", P.SLATE)
		_set_sensor_status("st_connected", P.SLATE)
		continue_btn.disabled = false
		continue_btn.grab_focus()
	connect_btn.disabled = false


func _on_continue() -> void:
	_start_entry_test()


func _start_entry_test() -> void:
	_reset_locks()
	_show_page(test_page, "sub_entry")
	state = State.TEST
	_show_instructions()


# ------------------------------------------------------------------ modal
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
	dim.color = Color(P.SLATE, 0.35)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal_layer.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal_layer.add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _box(P.SURFACE, P.RULE, 1, 0, 32, 28))
	panel.custom_minimum_size = Vector2(540, 0)
	center.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 16)
	panel.add_child(v)
	v.add_child(_label(t(modal_spec["title"]), P.FS_TITLE, P.SLATE, true))
	var args: Array = []
	for a in modal_spec["args"]:
		args.append(t(a) if a is String else a)
	var b := _label(_fmt(modal_spec["body"], args), P.FS_BODY, P.SLATE)
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.custom_minimum_size = Vector2(476, 0)
	b.add_theme_constant_override("line_spacing", 6)
	v.add_child(b)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	v.add_child(row)
	var btn := _button(t(modal_spec["button"]), "primary")
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
	# round first so a tiny negative value does not show as "-0.00"
	var mom_shown: float = snappedf(mom, 0.01)
	if is_zero_approx(mom_shown):
		mom_shown = 0.0
	readouts[2].text = "%.2f N·m" % mom_shown

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
		# the target zone deepens from tint to full green while it is held
		gauges[i].zone_mix = 1.0 if unlocked[i] else hold[i] / HOLD_TIME
		hold_bars[i].value = HOLD_TIME if unlocked[i] else hold[i]
		gauges[i].queue_redraw()

	if unlocked[0] and unlocked[1] and unlocked[2]:
		state = State.DONE
		await get_tree().create_timer(0.5).timeout
		_show_modal("ok_title", "ok_body", "btn_continue", _show_select)


func _unlock(i: int) -> void:
	unlocked[i] = true
	lock_labels[i].text = t("unlocked")
	lock_labels[i].add_theme_color_override("font_color", P.TARGET)
	_set_bold(lock_labels[i], true)


func _reset_locks() -> void:
	for i in range(3):
		unlocked[i] = false
		hold[i] = 0.0
		gauges[i].zone_mix = 0.0
		gauges[i].queue_redraw()
		hold_bars[i].value = 0.0
		lock_labels[i].text = t("locked")
		lock_labels[i].add_theme_color_override("font_color", P.STEEL)
		_set_bold(lock_labels[i], false)


# ------------------------------------------------------------------ game selection
func _show_select() -> void:
	state = State.SELECT
	_show_page(select_page, "sub_select")
	start_btn.grab_focus.call_deferred()


func _row_style(i: int) -> StyleBoxFlat:
	var sb: StyleBoxFlat
	if i == selected_game:
		sb = _box(P.SURFACE, P.SLATE, 0, 0, 16, 14)
		sb.border_width_left = 4
	elif i == hovered_row:
		sb = _box(P.HOVER, Color(0, 0, 0, 0), 0, 0, 16, 14)
		sb.border_width_left = 4
		sb.border_color = P.HOVER
	else:
		sb = _box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 0, 16, 14)
		sb.border_width_left = 4
	return sb


func _refresh_rows() -> void:
	for i in range(list_rows.size()):
		list_rows[i].add_theme_stylebox_override("panel", _row_style(i))
		_set_bold(list_titles[i], i == selected_game)


func _on_row_input(event: InputEvent, i: int) -> void:
	var mb := event as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		_select_game(i)


func _on_row_hover(i: int, entered: bool) -> void:
	hovered_row = i if entered else -1
	_refresh_rows()


func _select_game(i: int) -> void:
	selected_game = i
	_refresh_rows()
	_refresh_detail()


func _refresh_detail() -> void:
	if detail_title == null:
		return
	detail_title.text = t("game%d_title" % selected_game)
	detail_skill.text = t("game%d_skill" % selected_game)
	detail_levels.text = t("game%d_levels" % selected_game)
	for k in range(detail_icons.size()):
		detail_icons[k].visible = k == selected_game
	# Rocking Challenge: carrot cover picture instead of the moment gauge
	detail_cover.visible = selected_game == 0
	detail_icon_box.visible = selected_game != 0
	difficulty_desc.text = t("diff%d_desc" % selected_difficulty)


func _on_difficulty(i: int) -> void:
	selected_difficulty = i
	difficulty_desc.text = t("diff%d_desc" % i)


func _on_recheck() -> void:
	sensor.reset_values()
	_start_entry_test()


func _on_start() -> void:
	if selected_game == 0:
		_launch_rocking()
		return
	_show_modal("soon_title", "soon_body", "btn_ok", Callable(), [
		"game%d_title" % selected_game, "diff%d_name" % selected_difficulty])


# ------------------------------------------------------------------ games
## Rocking Challenge Level A (carrot game). The app UI is hidden while the game runs
## and shown again on the game selection page when the player goes back.
func _launch_rocking() -> void:
	hidden_ui.clear()
	for c in get_children():
		if c is CanvasItem and c.visible:
			c.visible = false
			hidden_ui.append(c)
	var g = CarrotGame.new()
	g.difficulty = selected_difficulty
	g.lang = lang
	g.sensor = null  # simulated sensor: the game uses its own keyboard input (returns to centre on release)
	g.exit_requested.connect(_on_game_exit)
	add_child(g)
	game_node = g


func _on_game_exit() -> void:
	if game_node != null:
		game_node.queue_free()
		game_node = null
	for c in hidden_ui:
		if is_instance_valid(c):
			c.visible = true
	hidden_ui.clear()
	_show_select()
