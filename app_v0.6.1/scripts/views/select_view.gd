extends HBoxContainer
## View — game selection page (v0.5.4; layout unchanged from main.gd v0.5.3; v0.6.0: Rocking Challenge
## gets a Level A / Level B choice, each with its own cover picture and description).
## Left: game list, then Sensor check / Achievements / History. Right: details, difficulty, Start.

signal game_selected(index: int)
signal difficulty_selected(index: int)
signal level_selected(index: int)   # Rocking Challenge: 0 = Level A (carrot), 1 = Level B (balloons) (v0.6.0)
signal start_pressed
signal recheck_pressed
signal achievements_pressed
signal history_pressed

const P := preload("res://app_v0.6.1/scripts/views/palette.gd")
const DirectionGauge := preload("res://app_v0.6.1/scripts/views/direction_gauge.gd")
const ForceGauge := preload("res://app_v0.6.1/scripts/views/force_gauge.gd")
const MomentGauge := preload("res://app_v0.6.1/scripts/views/moment_gauge.gd")
const COVERS := ["res://assets/carrot_game/cover_rocking.png", "res://assets/balloon_game/cover_balloon.png"]

var kit
var list_rows: Array = []       # PanelContainer
var list_titles: Array = []     # Label
var hovered_row: int = -1
var selected_game := 0
var selected_difficulty := 0
var selected_level := 0
var detail_title: Label
var detail_pic: TextureRect
var cover_tex: Array = []
var level_row: HBoxContainer
var level_btns: Array = []
var level_skill: Label
var detail_skill: Label
var detail_levels: Label
var detail_icons: Array = []
var detail_icon_box: Control    # gauge icons (games 1 and 2)
var detail_cover: Control       # carrot game cover picture (game 0)
var difficulty_desc: Label
var start_btn: Button
var ach_btn: Button
var _ach_counts := [0, 0]


func build(k, game_count: int, difficulty_count: int) -> void:
	kit = k
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_theme_constant_override("separation", 0)

	# left: list of games
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(300, 0)
	left.add_theme_constant_override("separation", 0)
	add_child(left)
	var list_head := MarginContainer.new()
	list_head.add_theme_constant_override("margin_bottom", 10)
	list_head.add_child(kit.tlabel("choose", P.FS_SMALL, P.STEEL))
	left.add_child(list_head)
	left.add_child(kit.hrule())
	for i in range(game_count):
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
		var rt: Label = kit.tlabel("game%d_title" % i, P.FS_LABEL, P.SLATE)
		rv.add_child(rt)
		list_titles.append(rt)
		rv.add_child(kit.tlabel("game%d_short" % i, P.FS_SMALL, P.STEEL))
		kit.ignore_mouse(rowp)
		left.add_child(kit.hrule())
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(spacer)
	var recheck_row := HBoxContainer.new()
	var recheck: Button = kit.tbutton("btn_recheck", "secondary")
	recheck.pressed.connect(func(): recheck_pressed.emit())
	recheck_row.add_child(recheck)
	left.add_child(recheck_row)
	var ach_row := HBoxContainer.new()
	ach_row.add_theme_constant_override("separation", 8)
	ach_btn = kit.button("", "secondary")
	ach_btn.pressed.connect(func(): achievements_pressed.emit())
	ach_row.add_child(ach_btn)
	var ach_wrap := MarginContainer.new()
	ach_wrap.add_theme_constant_override("margin_top", 8)
	ach_wrap.add_child(ach_row)
	left.add_child(ach_wrap)
	var hist_row := HBoxContainer.new()
	var hist_btn: Button = kit.tbutton("btn_history", "secondary")
	hist_btn.pressed.connect(func(): history_pressed.emit())
	hist_row.add_child(hist_btn)
	var hist_wrap := MarginContainer.new()
	hist_wrap.add_theme_constant_override("margin_top", 8)
	hist_wrap.add_child(hist_row)
	left.add_child(hist_wrap)

	add_child(kit.vrule())

	# right: details of the selected game
	var right_margin := MarginContainer.new()
	right_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_margin.add_theme_constant_override("margin_left", 36)
	add_child(right_margin)
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 10)
	right_margin.add_child(right)

	detail_title = kit.label("", P.FS_TITLE, P.SLATE, true)
	right.add_child(detail_title)
	detail_skill = kit.label("", P.FS_BODY, P.SLATE)
	detail_skill.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right.add_child(detail_skill)

	var mid := HBoxContainer.new()
	mid.add_theme_constant_override("separation", 28)
	mid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(mid)
	# carrot game cover picture, shown instead of a gauge icon for the Rocking Challenge
	var cover := PanelContainer.new()
	cover.add_theme_stylebox_override("panel", kit.box(P.SURFACE, P.RULE, 1, 10))
	cover.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	cover.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pic := TextureRect.new()
	pic.custom_minimum_size = Vector2(320, 180)
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for path in COVERS:
		cover_tex.append(load(path) if ResourceLoader.exists(path) else null)
	pic.texture = cover_tex[0]
	cover.add_child(pic)
	detail_pic = pic
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
	lv.add_child(kit.tlabel("levels", P.FS_SMALL, P.STEEL))
	# Rocking Challenge: choose Level A or Level B (v0.6.0)
	level_row = HBoxContainer.new()
	level_row.add_theme_constant_override("separation", 8)
	lv.add_child(level_row)
	var lgroup := ButtonGroup.new()
	for i in range(2):
		var lb: Button = kit.toggle("", lgroup)
		kit.bind(lb, "level%s_btn" % ["A", "B"][i])
		lb.button_pressed = i == selected_level
		lb.pressed.connect(func(): level_selected.emit(i))
		level_row.add_child(lb)
		level_btns.append(lb)
	level_skill = kit.label("", P.FS_BODY, P.SLATE)
	level_skill.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lv.add_child(level_skill)
	detail_levels = kit.label("", P.FS_BODY, P.SLATE)
	detail_levels.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lv.add_child(detail_levels)

	right.add_child(kit.tlabel("difficulty", P.FS_SMALL, P.STEEL))
	var drow := HBoxContainer.new()
	drow.add_theme_constant_override("separation", 8)
	right.add_child(drow)
	var group := ButtonGroup.new()
	for i in range(difficulty_count):
		var b: Button = kit.toggle("", group)
		kit.bind(b, "diff%d_name" % i)
		b.button_pressed = i == selected_difficulty
		b.pressed.connect(func(): difficulty_selected.emit(i))
		drow.add_child(b)
	difficulty_desc = kit.label("", P.FS_SMALL, P.STEEL)
	right.add_child(difficulty_desc)

	var start_row := HBoxContainer.new()
	start_row.alignment = BoxContainer.ALIGNMENT_END
	right.add_child(start_row)
	start_btn = kit.tbutton("btn_start", "primary")
	start_btn.custom_minimum_size = Vector2(160, 44)
	start_btn.pressed.connect(func(): start_pressed.emit())
	start_row.add_child(start_btn)


# ------------------------------------------------------------------ rendering
## Show the selected game, difficulty and (Rocking Challenge only) level.
func show_selection(game: int, difficulty: int, level := -1) -> void:
	selected_game = game
	selected_difficulty = difficulty
	if level >= 0:
		selected_level = level
	for i in range(level_btns.size()):
		level_btns[i].set_pressed_no_signal(i == selected_level)
	_refresh_rows()
	detail_title.text = kit.t("game%d_title" % game)
	detail_skill.text = kit.t("game%d_skill" % game)
	detail_levels.text = kit.t("game%d_levels" % game)
	var rocking := game == 0
	level_row.visible = rocking
	level_skill.visible = rocking
	detail_levels.visible = not rocking
	if rocking:
		var lk: String = ["A", "B"][selected_level]
		level_skill.text = kit.t("level%s_skill" % lk)
		detail_pic.texture = cover_tex[selected_level]
	for k2 in range(detail_icons.size()):
		detail_icons[k2].visible = k2 == game
	# Rocking Challenge: carrot cover picture instead of the moment gauge
	detail_cover.visible = game == 0
	detail_icon_box.visible = game != 0
	if game == 0 and selected_level == 1:
		difficulty_desc.text = kit.t("diffB%d_desc" % difficulty)
	else:
		difficulty_desc.text = kit.t("diff%d_desc" % difficulty)


func set_achievement_count(unlocked: int, total: int) -> void:
	_ach_counts = [unlocked, total]
	ach_btn.text = "%s  %d / %d" % [kit.t("btn_achievements"), unlocked, total]


func relocalize() -> void:
	show_selection(selected_game, selected_difficulty)
	set_achievement_count(_ach_counts[0], _ach_counts[1])


func focus_start() -> void:
	start_btn.grab_focus.call_deferred()


# ------------------------------------------------------------------ list rows (hover is view-only state)
func _row_style(i: int) -> StyleBoxFlat:
	var sb: StyleBoxFlat
	if i == selected_game:
		sb = kit.box(P.SURFACE, P.SLATE, 0, 0, 16, 14)
		sb.border_width_left = 4
	elif i == hovered_row:
		sb = kit.box(P.HOVER, Color(0, 0, 0, 0), 0, 0, 16, 14)
		sb.border_width_left = 4
		sb.border_color = P.HOVER
	else:
		sb = kit.box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 0, 16, 14)
		sb.border_width_left = 4
	return sb


func _refresh_rows() -> void:
	for i in range(list_rows.size()):
		list_rows[i].add_theme_stylebox_override("panel", _row_style(i))
		kit.set_bold(list_titles[i], i == selected_game)


func _on_row_input(event: InputEvent, i: int) -> void:
	var mb := event as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		game_selected.emit(i)


func _on_row_hover(i: int, entered: bool) -> void:
	hovered_row = i if entered else -1
	_refresh_rows()
