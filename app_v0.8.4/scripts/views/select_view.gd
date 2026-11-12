extends HBoxContainer
## View — game selection page (v0.5.4; v0.6.0: Rocking Challenge gets a Level A / Level B choice;
## v0.7.0: garden look, design/设计方案_v2.0.md §4.1).
## Left: one small wooden sign per game (the selected one is pulled out with a carrot pin; games that
## are not built yet use the darker sign), then Achievements / History / Sensor check.
## Right: a big board on two posts with the details, level, difficulty and Start.

signal game_selected(index: int)
signal difficulty_selected(index: int)
signal level_selected(index: int)   # Rocking Challenge: 0 = Level A (carrot), 1 = Level B (balloons) (v0.6.0)
signal start_pressed
signal recheck_pressed
signal achievements_pressed
signal history_pressed
signal quit_pressed   # v0.8.4: "Quit training"

const P := preload("res://app_v0.8.4/scripts/views/palette.gd")
const Garden := preload("res://app_v0.8.4/scripts/views/garden.gd")
const DirectionGauge := preload("res://app_v0.8.4/scripts/views/direction_gauge.gd")
const ForceGauge := preload("res://app_v0.8.4/scripts/views/force_gauge.gd")
const MomentGauge := preload("res://app_v0.8.4/scripts/views/moment_gauge.gd")
# v0.8.0: soft-edged cover picture (16:9, like the cover images)
const COVER_SIZE := Vector2(288, 162)
const COVER_RADIUS := 16.0
const COVER_FEATHER := 14.0      # px over which the picture fades into the wood
const COVER_BLUR := 12.0
const COVER_SHADOW := Color(0.55, 0.32, 0.1, 0.32)   # warm wood shade, not grey
const SOFT_RECT_SHADER := """
shader_type canvas_item;
uniform vec2 rect_size = vec2(288.0, 162.0);
uniform float radius = 16.0;
uniform float feather = 14.0;
float rounded_box(vec2 p, vec2 b, float r) {
	vec2 q = abs(p) - b + r;
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}
void fragment() {
	vec4 c = COLOR;   // v0.8.2: COLOR already holds the picture's colour (× modulate); v0.8.0 multiplied the picture in twice
	vec2 p = (UV - 0.5) * rect_size;
	float d = rounded_box(p, rect_size * 0.5, radius);
	COLOR = vec4(c.rgb, c.a * (1.0 - smoothstep(-feather, 0.0, d)));
}
"""
const COVERS := ["res://assets/carrot_game/cover_rocking.png", "res://assets/balloon_game/cover_balloon.png"]
const DIFF_ICONS := ["ui_diff_intern.png", "ui_diff_trainee.png", "ui_diff_master.png"]
const LABEL_W := 76   # width of the "Levels" / "Difficulty" labels (fits the English words)
## Games that can be played; the others show the darker "coming soon" sign.
const BUILT_GAMES := [0]

var kit
var list_rows: Array = []       # PanelContainer (sign)
var list_shift: Array = []      # MarginContainer around each sign (pulls the selected one out)
var list_titles: Array = []     # Label
var hovered_row: int = -1
var selected_game := 0
var selected_difficulty := 0
var selected_level := 0
var detail_title: Label
var detail_pic: TextureRect
var detail_pic_under: TextureRect   # v0.8.0: cross-fade
var _cover_tween: Tween = null
var cover_tex: Array = []
var level_row: HBoxContainer
var level_btns: Array = []
var level_skill: Label
var detail_skill: Label
var detail_levels: Label
var detail_icons: Array = []
var detail_icon_box: Control    # gauge icons (games 1 and 2)
var detail_cover: Control       # cover picture (Rocking Challenge)
var difficulty_desc: Label
var start_btn: Button
var ach_btn: Button
var _ach_counts := [0, 0]


func build(k, game_count: int, difficulty_count: int) -> void:
	kit = k
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_theme_constant_override("separation", 22)

	# ---- left: signs for the games, then the three page buttons
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(262, 0)
	left.add_theme_constant_override("separation", 10)
	add_child(left)
	for i in range(game_count):
		var shift := MarginContainer.new()
		left.add_child(shift)
		list_shift.append(shift)
		var rowp := PanelContainer.new()
		rowp.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		rowp.gui_input.connect(_on_row_input.bind(i))
		rowp.mouse_entered.connect(_on_row_hover.bind(i, true))
		rowp.mouse_exited.connect(_on_row_hover.bind(i, false))
		shift.add_child(rowp)
		list_rows.append(rowp)
		var rv := VBoxContainer.new()
		rv.add_theme_constant_override("separation", 0)
		rowp.add_child(rv)
		var rt: Label = kit.tdisplay("game%d_title" % i, P.FS_TITLE, P.INK)
		rv.add_child(rt)
		list_titles.append(rt)
		var rs: Label = kit.tlabel("game%d_short" % i, P.FS_SMALL, P.STEEL, true)
		rs.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		rv.add_child(rs)
		kit.ignore_mouse(rowp)
		rowp.draw.connect(_draw_pin.bind(i))
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left.add_child(spacer)
	ach_btn = kit.button("", "secondary")
	ach_btn.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	ach_btn.pressed.connect(func(): achievements_pressed.emit())
	left.add_child(ach_btn)
	var hist_btn: Button = kit.tbutton("btn_history", "secondary")
	hist_btn.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	hist_btn.pressed.connect(func(): history_pressed.emit())
	left.add_child(hist_btn)
	# v0.8.4: "Quit training" sits next to "Sensor check" (a fourth row would not fit the window)
	var last_row := HBoxContainer.new()
	last_row.add_theme_constant_override("separation", 10)
	left.add_child(last_row)
	var recheck: Button = kit.tbutton("btn_recheck", "secondary")
	recheck.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	recheck.pressed.connect(func(): recheck_pressed.emit())
	last_row.add_child(recheck)
	var quit_btn: Button = kit.tbutton("btn_quit", "secondary")
	quit_btn.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	quit_btn.pressed.connect(func(): quit_pressed.emit())
	quit_btn.set_meta("sfx", "back")
	last_row.add_child(quit_btn)

	# ---- right: details on a big board standing on two posts
	var bf = kit.board(true, 14, 4)
	bf.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bf.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(bf)
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 8)
	bf.content.add_child(right)

	detail_title = kit.display("", P.FS_DISPLAY, P.INK)
	right.add_child(detail_title)
	detail_skill = kit.label("", P.FS_BODY, P.INK)
	detail_skill.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right.add_child(detail_skill)

	# Rocking Challenge: Level A or Level B (v0.6.0). Own full-width row under the title, like the
	# difficulty row, so the long English names never push the board wider than the window.
	level_row = HBoxContainer.new()
	level_row.add_theme_constant_override("separation", 8)
	right.add_child(level_row)
	var ll: Label = kit.tlabel("levels", P.FS_SMALL, P.STEEL, true)
	ll.custom_minimum_size = Vector2(LABEL_W, 0)
	ll.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	level_row.add_child(ll)
	var lgroup := ButtonGroup.new()
	for i in range(2):
		var lb: Button = kit.toggle("", lgroup)
		kit.bind(lb, "level%s_btn" % ["A", "B"][i])
		lb.button_pressed = i == selected_level
		lb.pressed.connect(func(): level_selected.emit(i))
		level_row.add_child(lb)
		level_btns.append(lb)

	var mid := HBoxContainer.new()
	mid.add_theme_constant_override("separation", 22)
	mid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(mid)
	# cover picture (Rocking Challenge). v0.8.0: no hard ink frame any more — the picture's edges fade
	# softly into the wood and a soft shadow sits under it, so it looks printed onto the board.
	# Switching Level A / B cross-fades the two pictures.
	var cover := Control.new()
	cover.custom_minimum_size = COVER_SIZE
	cover.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cover.pivot_offset = COVER_SIZE / 2.0
	cover.rotation = deg_to_rad(-1.0)
	var shadow := ColorRect.new()
	shadow.color = COVER_SHADOW
	shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shadow.position = Vector2(-COVER_BLUR + 3, -COVER_BLUR + 7)
	shadow.size = COVER_SIZE + Vector2(COVER_BLUR, COVER_BLUR) * 2.0
	shadow.material = _soft_rect_material(shadow.size, COVER_RADIUS + COVER_BLUR, COVER_BLUR * 1.6)
	cover.add_child(shadow)
	var pic_mat := _soft_rect_material(COVER_SIZE, COVER_RADIUS, COVER_FEATHER)
	for path in COVERS:
		var cover_t: Texture2D = null
		if ResourceLoader.exists(path):
			cover_t = load(path)
		cover_tex.append(cover_t)
	var under := TextureRect.new()   # the previous picture while the new one fades in
	var pic := TextureRect.new()
	for tr_pic in [under, pic]:
		var r: TextureRect = tr_pic
		r.size = COVER_SIZE
		r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		r.stretch_mode = TextureRect.STRETCH_SCALE   # covers are 16:9 like COVER_SIZE, so UV 0..1 = whole picture
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		r.material = pic_mat
		cover.add_child(r)
	under.visible = false
	pic.texture = cover_tex[0]
	mid.add_child(cover)
	detail_cover = cover
	detail_pic = pic
	detail_pic_under = under
	# gauge icon on a paper plate (games 1 and 2)
	var icon_box := PanelContainer.new()
	icon_box.add_theme_stylebox_override("panel", Garden.plate_box(10, 10))
	icon_box.custom_minimum_size = Vector2(170, 170)
	icon_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mid.add_child(icon_box)
	detail_icon_box = icon_box
	var icon_area := Control.new()
	icon_box.add_child(icon_area)
	var icons := [MomentGauge.new(), DirectionGauge.new(), ForceGauge.new()]
	icons[0].value = 0.2
	icons[1].value_deg = 50.0
	icons[2].value = 10.0
	icons[2].show_scale = false
	for icon in icons:
		icon.custom_minimum_size = Vector2(150, 150)
		icon.zone_mix = 0.35
		icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon_area.add_child(icon)
	detail_icons = icons
	var lv := VBoxContainer.new()
	lv.add_theme_constant_override("separation", 8)
	lv.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	lv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lv.custom_minimum_size = Vector2(200, 0)
	mid.add_child(lv)
	level_skill = kit.label("", P.FS_BODY, P.INK)
	level_skill.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lv.add_child(level_skill)
	detail_levels = kit.label("", P.FS_BODY, P.INK)
	detail_levels.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lv.add_child(detail_levels)

	# difficulty: label and three tags with their icons on one line
	var drow := HBoxContainer.new()
	drow.add_theme_constant_override("separation", 8)
	right.add_child(drow)
	var dl: Label = kit.tlabel("difficulty", P.FS_SMALL, P.STEEL, true)
	dl.custom_minimum_size = Vector2(LABEL_W, 0)
	dl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	drow.add_child(dl)
	var group := ButtonGroup.new()
	for i in range(difficulty_count):
		var b: Button = kit.toggle("", group)
		kit.bind(b, "diff%d_name" % i)
		if i < DIFF_ICONS.size():
			var tex := Garden.ui_texture(DIFF_ICONS[i], 0.34)
			if tex != null:
				b.icon = tex
		b.button_pressed = i == selected_difficulty
		b.pressed.connect(func(): difficulty_selected.emit(i))
		drow.add_child(b)

	# description of the difficulty on the left, Start (the one carrot button) on the right
	var start_row := HBoxContainer.new()
	start_row.add_theme_constant_override("separation", 16)
	right.add_child(start_row)
	difficulty_desc = kit.label("", P.FS_SMALL, P.STEEL, true)
	difficulty_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	difficulty_desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	difficulty_desc.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	start_row.add_child(difficulty_desc)
	start_btn = kit.tbutton("btn_start", "primary")
	start_btn.custom_minimum_size = Vector2(150, 0)
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
	detail_skill.visible = not rocking   # the level's own description says more (v0.7.0: saves height)
	if rocking:
		var lk: String = ["A", "B"][selected_level]
		level_skill.text = kit.t("level%s_skill" % lk)
		_show_cover(cover_tex[selected_level])
	for k2 in range(detail_icons.size()):
		detail_icons[k2].visible = k2 == game
	detail_cover.visible = rocking
	detail_icon_box.visible = not rocking
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
func _refresh_rows() -> void:
	for i in range(list_rows.size()):
		var sel := i == selected_game
		var built: bool = i in BUILT_GAMES
		var pad := 10 if sel or i == hovered_row else 8
		list_rows[i].add_theme_stylebox_override("panel", Garden.sign_box(not built and not sel, 12, pad))
		# the selected sign is pulled out to the right; a hovered one a little
		var out := 12 if sel else (4 if i == hovered_row else 0)
		list_shift[i].add_theme_constant_override("margin_left", out)
		list_shift[i].add_theme_constant_override("margin_right", 12 - out)
		list_titles[i].add_theme_color_override("font_color", P.INK if built or sel else P.STEEL)
		list_rows[i].queue_redraw()


## Carrot pin just outside the left edge of the selected sign, half-way down (drawn on the sign).
func _draw_pin(i: int) -> void:
	if i != selected_game:
		return
	var rowp: Control = list_rows[i]
	var c := Vector2(-4, rowp.size.y / 2.0)
	rowp.draw_circle(c, 7.0, P.CARROT)
	rowp.draw_arc(c, 7.0, 0.0, TAU, 24, P.INK, 2.0, true)


func _on_row_input(event: InputEvent, i: int) -> void:
	var mb := event as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		game_selected.emit(i)


func _on_row_hover(i: int, entered: bool) -> void:
	hovered_row = i if entered else -1
	_refresh_rows()


# ------------------------------------------------------------------ cover picture (v0.8.0)
## A rounded rectangle whose edge fades out over `feather` px. Used for the picture and its shadow
## (a ColorRect has a plain white texture, so the same shader gives a soft coloured patch).
func _soft_rect_material(rect_size: Vector2, radius: float, feather: float) -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = SOFT_RECT_SHADER
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("rect_size", rect_size)
	m.set_shader_parameter("radius", radius)
	m.set_shader_parameter("feather", feather)
	return m


## Cross-fade to another cover picture (0.3 s). The same picture again does nothing.
func _show_cover(t: Texture2D) -> void:
	if detail_pic.texture == t:
		return
	if _cover_tween != null and _cover_tween.is_valid():
		_cover_tween.kill()
	if not is_visible_in_tree() or detail_pic.texture == null:
		detail_pic.texture = t
		detail_pic.modulate.a = 1.0
		detail_pic_under.visible = false
		return
	detail_pic_under.texture = detail_pic.texture
	detail_pic_under.visible = true
	detail_pic.texture = t
	detail_pic.modulate.a = 0.0
	_cover_tween = create_tween()
	_cover_tween.tween_property(detail_pic, "modulate:a", 1.0, 0.3).set_trans(Tween.TRANS_SINE)
	_cover_tween.tween_callback(_hide_under_cover)


func _hide_under_cover() -> void:
	detail_pic_under.visible = false
