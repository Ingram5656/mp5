extends Node2D
## View — the carrot game scene (Rocking Challenge Level A) (v0.5.4; look and animations unchanged from
## carrot_game.gd v0.5.3). Passive: it draws what the carrot presenter tells it, plays the animations,
## and reports button presses. It knows nothing about the rules, the sensor, files or the database.
## Art: res://assets/carrot_game/ (1920×1080 layout, see the README there).

signal again_pressed
signal report_pressed
signal back_pressed
## An ending animation (win, snapped, time up) has finished; the presenter then shows the result panel.
signal ending_finished(kind: String)
signal escape_pressed

const ASSET_DIR := "res://assets/carrot_game/"
const FONT_PATH := "res://fonts/NotoSansSC-Bold.ttf"
const Garden := preload("res://app_v0.7.1/scripts/views/garden.gd")
const DESIGN := Vector2(1920, 1080)
const DISPLAY_MAX := 0.45 ## 这个力矩对应最大倾角（N·m）
const MAX_ANGLE_DEG := 35.0
const PIVOT := Vector2(960, 810) ## 萝卜出土点 / 旋转中心
const CARROT_SIZE := Vector2(400, 900)
const EXPOSE_START := 0.49 ## 起始时露出比例（左上角 y=370）
const EXPOSE_END := 0.90 ## 最后一次摆动后露出比例（只剩尖尖在土里）
const SOIL_CRACK_TL := Vector2(710, 735)
const RABBIT_TL := Vector2(1300, 390)
const SECTOR_RADIUS := 430.0

const TEXT := {
	"zh": {
		"hint": "推一边 → 保持 → 回中 → 推另一边",
		"keys": "键盘：← / A / Q 向左，→ / D / E 向右，按住 Shift 用力过猛，按住 S 偏轴，Esc 返回",
		"relax": "把手放松，回到中位开始",
		"ready": "准备……",
		"other_side": "换另一边！",
		"win": "拔出来啦！",
		"broken": "断了……再来一根？",
		"timeout": "时间到！再来一次？",
		"result": "完成摆动：%d / %d\n用力过猛：%d 次\n用时：%.1f 秒",
		"again": "再来一次",
		"back": "返回选择",
		"new_ach": "本局新成就：%s",
		"report": "评估报告",
		"grade_line": "评级 %s · %.1f 分",
	},
	"en": {
		"hint": "Push one way → hold → back to centre → push the other way",
		"keys": "Keyboard: ← / A / Q left, → / D / E right, hold Shift = too hard, hold S = off-axis, Esc = back",
		"relax": "Relax your grip and return to centre to start",
		"ready": "Get ready…",
		"other_side": "Switch sides!",
		"win": "It's out!",
		"broken": "Snapped… try another one?",
		"timeout": "Time's up! Try again?",
		"result": "Rocks completed: %d / %d\nToo hard: %d\nTime: %.1f s",
		"again": "Play again",
		"back": "Back to games",
		"new_ach": "New this round: %s",
		"report": "Report",
		"grade_line": "Grade %s · %.1f",
	},
}

var lang := "zh"
var font: Font
var world: Node2D
var clouds: Array = []
var soil_front: Sprite2D
var carrot_pivot: Node2D
var carrot: Sprite2D
var carrot_cracks: Array = []
var soil_crack: Sprite2D
var soil_crack_tex: Array = []
var rabbit: Sprite2D
var rabbit_tex := {}
var rabbit_base := "wait"
var rabbit_temp_t := 0.0
var life_icons: Array = []
var tex_life_on: Texture2D
var tex_life_off: Texture2D
var sand: SandDrawer
var hourglass: Sprite2D
var sector: SectorDrawer
var sparkles: CPUParticles2D
var dirt: CPUParticles2D
var confetti: Array = []
var hint_label: Label
var status_label: Label
var debug_label: Label
var missing := PackedStringArray()
var display_angle := 0.0
var fly_start := Vector2.ZERO
var fly_ctrl := Vector2.ZERO
var fly_end := Vector2.ZERO


func tr_(key: String) -> String:
	var table: Dictionary = TEXT.get(lang, TEXT["en"])
	return table.get(key, TEXT["en"].get(key, key))


func _ready() -> void:
	if ResourceLoader.exists(FONT_PATH):
		font = load(FONT_PATH)
	get_viewport().size_changed.connect(_fit_to_viewport)


## (Re)build the scene for a new round.
## cfg: band_min, band_max (N·m), allowed (mistakes), zone, timed, text (hints), keyboard (bool)
func build(cfg: Dictionary) -> void:
	if world != null:
		world.queue_free()
	clouds.clear()
	carrot_cracks.clear()
	soil_crack_tex.clear()
	life_icons.clear()
	confetti.clear()
	rabbit_tex.clear()
	missing = PackedStringArray()
	rabbit_base = "wait"
	rabbit_temp_t = 0.0
	display_angle = 0.0
	world = Node2D.new()
	add_child(world)
	_fit_to_viewport()
	_build_scene(cfg)
	if missing.size() > 0:
		push_warning("拔萝卜：缺少素材，已用色块代替：" + ", ".join(missing))


func _fit_to_viewport() -> void:
	if world == null:
		return
	var vp := get_viewport_rect().size
	var s: float = minf(vp.x / DESIGN.x, vp.y / DESIGN.y)
	world.scale = Vector2(s, s)
	world.position = (vp - DESIGN * s) / 2.0


# ---------------- 资源 ----------------
func _tex(res_name: String, fallback := Vector2i(64, 64), color := Color(1, 0, 1, 0.5)) -> Texture2D:
	var path := ASSET_DIR + res_name + ".png"
	if ResourceLoader.exists(path):
		return load(path)
	missing.append(res_name)
	var img := Image.create(fallback.x, fallback.y, false, Image.FORMAT_RGBA8)
	img.fill(color)
	return ImageTexture.create_from_image(img)


func _sprite_tl(res_name: String, top_left: Vector2, fallback: Vector2i, color: Color, parent: Node = null) -> Sprite2D:
	var s := Sprite2D.new()
	s.centered = false
	s.texture = _tex(res_name, fallback, color)
	s.position = top_left
	(parent if parent != null else world).add_child(s)
	return s


# ---------------- 场景 ----------------
func _build_scene(cfg: Dictionary) -> void:
	_sprite_tl("bg_sky", Vector2.ZERO, Vector2i(1920, 1080), Color(0.45, 0.75, 0.98))

	var cloud_spec := [["bg_cloud_02", Vector2(180, 120), 9.0], ["bg_cloud_03", Vector2(1080, 90), 6.0], ["bg_cloud_01", Vector2(700, 40), 13.0]]
	for c in cloud_spec:
		var n := _sprite_tl(c[0], c[1], Vector2i(360, 180), Color(1, 1, 1, 0.9))
		clouds.append({"node": n, "speed": c[2]})

	_sprite_tl("bg_fence", Vector2.ZERO, Vector2i(4, 4), Color(0, 0, 0, 0))
	_sprite_tl("bg_soil_back", Vector2.ZERO, Vector2i(4, 4), Color(0, 0, 0, 0))

	sector = SectorDrawer.new()
	sector.position = PIVOT
	sector.radius = SECTOR_RADIUS
	sector.a0 = _angle_for(cfg["band_min"])
	sector.a1 = _angle_for(cfg["band_max"])
	sector.show_zone = cfg["zone"]
	world.add_child(sector)

	carrot_pivot = Node2D.new()
	carrot_pivot.position = PIVOT
	world.add_child(carrot_pivot)
	carrot = Sprite2D.new()
	carrot.texture = _tex("carrot_full", Vector2i(CARROT_SIZE), Color(1.0, 0.55, 0.1))
	carrot_pivot.add_child(carrot)
	for i in 3:
		var cr := Sprite2D.new()
		cr.texture = _tex("carrot_crack_%d" % (i + 1), Vector2i(4, 4), Color(0, 0, 0, 0))
		cr.visible = false
		carrot.add_child(cr) # 与 carrot_full 同尺寸、同变换
		carrot_cracks.append(cr)
	_set_expose(EXPOSE_START)

	sparkles = CPUParticles2D.new()
	sparkles.texture = _tex("fx_sparkle", Vector2i(16, 16), Color(1, 0.95, 0.5))
	sparkles.amount = 12
	sparkles.lifetime = 0.8
	sparkles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	sparkles.emission_sphere_radius = 150.0
	sparkles.gravity = Vector2(0, -40)
	sparkles.scale_amount_min = 0.3
	sparkles.scale_amount_max = 0.6
	sparkles.position = Vector2(0, -230)
	sparkles.emitting = false
	carrot_pivot.add_child(sparkles)

	soil_front = _sprite_tl("bg_soil_front", Vector2.ZERO, Vector2i(1920, 300), Color(0.55, 0.33, 0.18))
	if soil_front.texture.get_height() < 1000:
		soil_front.position = Vector2(0, PIVOT.y - 20)

	for i in 4:
		soil_crack_tex.append(_tex("soil_crack_%d" % (i + 1), Vector2i(500, 150), Color(0.25, 0.12, 0.05, 0.4)))
	soil_crack = Sprite2D.new()
	soil_crack.centered = false
	soil_crack.position = SOIL_CRACK_TL
	soil_crack.visible = false
	world.add_child(soil_crack)

	dirt = CPUParticles2D.new()
	dirt.texture = _tex("fx_dirt", Vector2i(14, 14), Color(0.4, 0.22, 0.1))
	dirt.position = PIVOT
	dirt.amount = 22
	dirt.lifetime = 0.9
	dirt.one_shot = true
	dirt.explosiveness = 0.95
	dirt.direction = Vector2(0, -1)
	dirt.spread = 70.0
	dirt.initial_velocity_min = 260.0
	dirt.initial_velocity_max = 460.0
	dirt.gravity = Vector2(0, 980)
	dirt.angular_velocity_min = -360.0
	dirt.angular_velocity_max = 360.0
	dirt.scale_amount_min = 0.35
	dirt.scale_amount_max = 0.7
	dirt.emitting = false
	world.add_child(dirt)

	_sprite_tl("bg_plants_front", Vector2.ZERO, Vector2i(4, 4), Color(0, 0, 0, 0))

	for n in ["wait", "excited", "jump", "hold", "cover_ears", "speechless"]:
		rabbit_tex[n] = _tex("rabbit_" + n, Vector2i(500, 450), Color(0.98, 0.92, 0.85))
	rabbit = Sprite2D.new()
	rabbit.centered = false
	rabbit.position = RABBIT_TL
	rabbit.texture = rabbit_tex["wait"]
	world.add_child(rabbit)

	for i in 4:
		var cf := CPUParticles2D.new()
		cf.texture = _tex("fx_confetti_0%d" % (i + 1), Vector2i(14, 8), Color.from_hsv(i * 0.25, 0.7, 1.0))
		cf.amount = 28
		cf.lifetime = 2.5
		cf.one_shot = true
		cf.explosiveness = 0.9
		cf.direction = Vector2(0, -1)
		cf.spread = 65.0
		cf.initial_velocity_min = 550.0
		cf.initial_velocity_max = 950.0
		cf.gravity = Vector2(0, 750)
		cf.angular_velocity_min = -540.0
		cf.angular_velocity_max = 540.0
		cf.emitting = false
		cf.position = RABBIT_TL + Vector2(200, 120)
		world.add_child(cf)
		confetti.append(cf)

	# ---- UI ----
	tex_life_on = _tex("ui_life_on", Vector2i(100, 120), Color(1, 0.55, 0.1))
	tex_life_off = _tex("ui_life_off", Vector2i(100, 120), Color(0.5, 0.5, 0.5))
	for i in int(cfg["allowed"]):
		life_icons.append(_sprite_tl("ui_life_on", Vector2(40 + i * 90, 30), Vector2i(100, 120), Color(1, 0.55, 0.1)))

	hourglass = _sprite_tl("ui_hourglass", Vector2(1750, 30), Vector2i(130, 200), Color(0.6, 0.4, 0.2))
	sand = SandDrawer.new()
	sand.show_behind_parent = true
	hourglass.add_child(sand)
	hourglass.visible = cfg["timed"]

	hint_label = _label(tr_("hint"), 44, Vector2(0, 950), Vector2(1920, 70))
	hint_label.modulate = Color(1, 1, 1, 0.75)
	hint_label.visible = cfg["text"]

	status_label = _label("", 40, Vector2(0, 170), Vector2(1920, 60))

	var keys := _label(tr_("keys") if cfg["keyboard"] else "", 22, Vector2(0, 1035), Vector2(1920, 36))
	keys.modulate = Color(1, 1, 1, 0.8)

	debug_label = _label("", 26, Vector2(40, 200), Vector2(760, 200))
	debug_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	debug_label.visible = false


func _label(text: String, size: int, pos: Vector2, box: Vector2) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.size = box
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if font:
		l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Color(0.36, 0.22, 0.1))
	l.add_theme_color_override("font_outline_color", Color(1, 1, 1, 0.85))
	l.add_theme_constant_override("outline_size", 8)
	world.add_child(l)
	return l


func _button(text: String, pos: Vector2, primary: bool, cb: Callable) -> Button:
	# v0.7.0 (design v2.0): pill button with ink outline and a solid ink lip; carrot = the main action.
	# Sizes are for the 1920×1080 game layout (the app pages use garden.gd at window scale).
	var b := Button.new()
	b.text = text
	b.position = pos
	b.size = Vector2(240, 72)
	b.focus_mode = Control.FOCUS_ALL
	if font:
		b.add_theme_font_override("font", font)
	b.add_theme_font_size_override("font_size", 32)
	var ink := Color("5e3410")
	var bg: Color = Color("ff7f1f") if primary else Color("fff4df")
	var hover_bg: Color = bg.lightened(0.12) if primary else Color("ffe6b8")
	for st in ["normal", "hover", "pressed", "focus", "disabled"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = hover_bg if st == "hover" or st == "pressed" else bg
		sb.border_color = ink
		sb.set_border_width_all(4)
		sb.set_corner_radius_all(36)
		sb.anti_aliasing = true
		var lip := 2 if st == "pressed" else 8
		sb.border_width_bottom = 4 + lip
		sb.content_margin_top = 8 + (6 if st == "pressed" else 0)
		sb.content_margin_bottom = 8
		if st == "focus":
			sb.draw_center = false
			sb.set_border_width_all(4)
			sb.set_expand_margin_all(8)
		if st == "disabled":
			sb.bg_color = Color("eadbbd")
			sb.border_color = Color("85572f")
		b.add_theme_stylebox_override(st, sb)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(c, ink)
	b.add_theme_color_override("font_disabled_color", Color("85572f"))
	b.pressed.connect(cb)
	world.add_child(b)
	return b


# ---------------- 萝卜几何 ----------------
func _angle_for(t: float) -> float:
	return clampf(absf(t) / DISPLAY_MAX, 0.0, 1.0) * deg_to_rad(MAX_ANGLE_DEG)


func _expose_for(p: float) -> float:
	return lerpf(EXPOSE_START, EXPOSE_END, p)


## e = 从萝卜图顶端算起，露出土面的比例（出土点在 pivot 原点）
func _set_expose(e: float) -> void:
	carrot.position = Vector2(0, CARROT_SIZE.y / 2.0 - e * CARROT_SIZE.y)


func _expose_now() -> float:
	return (CARROT_SIZE.y / 2.0 - carrot.position.y) / CARROT_SIZE.y


# =====================================================================
# 每帧：云、兔子临时表情的计时（纯画面）
func _process(delta: float) -> void:
	if world == null:
		return
	for c in clouds:
		var n: Sprite2D = c["node"]
		n.position.x += c["speed"] * delta
		if n.position.x > DESIGN.x + 50:
			n.position.x = -n.texture.get_width() - 50
	if rabbit_temp_t > 0.0:
		rabbit_temp_t -= delta
		if rabbit_temp_t <= 0.0:
			_rabbit_set(rabbit_base)


## Per-frame state from the presenter.
## s: active (bool, carrot follows the moment), torque, hold_pos, hold_neg, near_limit, sparkle,
##    tint ("normal"/"near"/"latched"), status_key, flash_side, hint_side, time_frac
func render(s: Dictionary, delta: float) -> void:
	if world == null:
		return
	if s["active"]:
		var torque: float = s["torque"]
		var target: float = signf(torque) * _angle_for(torque)
		display_angle = lerp_angle(display_angle, target, 1.0 - exp(-15.0 * delta))
		carrot_pivot.rotation = display_angle
		sector.hold_pos = s["hold_pos"]
		sector.hold_neg = s["hold_neg"]
		sector.near_limit = s["near_limit"]
		sparkles.emitting = s["sparkle"]
		match s["tint"]:
			"latched": carrot.modulate = Color(1, 0.6, 0.6)
			"near": carrot.modulate = Color(1, 0.82, 0.82)
			_: carrot.modulate = Color.WHITE
		status_label.text = tr_(s["status_key"]) if s["status_key"] != "" else ""
		if s["flash_side"] != 0:
			sector.flash(s["flash_side"])
		if s["hint_side"] != 0:
			sector.hint(s["hint_side"])
	sector.queue_redraw()
	sand.frac = s["time_frac"]
	sand.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_ESCAPE:
				escape_pressed.emit()
			KEY_F3:
				toggle_debug()


func set_debug_text(text: String) -> void:
	if debug_label.visible:
		debug_label.text = text


func toggle_debug() -> void:
	debug_label.visible = not debug_label.visible


# ---------------- 事件对应的画面 ----------------
## Progress 0..1 of half-rocks: the carrot rises.
func show_progress(p: float) -> void:
	world.create_tween().tween_method(_set_expose, _expose_now(), _expose_for(p), 0.35) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## A full rock: soil splashes and the crack grows (level 1..4).
func show_rock(level: int) -> void:
	dirt.restart()
	dirt.emitting = true
	soil_crack.texture = soil_crack_tex[clampi(level, 1, 4) - 1]
	soil_crack.visible = true


## A "too hard" mistake: crack on the carrot (1..3), one life icon greyed, carrot shakes.
func show_overload(crack: int, life_index: int) -> void:
	var idx := clampi(crack, 1, 3) - 1
	for i in carrot_cracks.size():
		carrot_cracks[i].visible = (i == idx)
	if life_index >= 0 and life_index < life_icons.size():
		life_icons[life_index].texture = tex_life_off
	_shake(carrot_pivot, 10.0)


## Off-axis warning: soil shakes, rabbit covers its ears.
func show_offaxis() -> void:
	_shake(soil_front, 8.0)
	rabbit_temp("cover_ears", 1.0)


# ---------------- 兔子 ----------------
func _rabbit_set(n: String) -> void:
	rabbit.texture = rabbit_tex[n]


## Expression to return to after a temporary one ("wait" before the first rock, then "excited").
func set_rabbit_base(n: String) -> void:
	rabbit_base = n


func rabbit_temp(n: String, t: float) -> void:
	_rabbit_set(n)
	rabbit_temp_t = t


func rabbit_now(n: String) -> void:
	rabbit_temp_t = 0.0
	_rabbit_set(n)


# ---------------- 结束动画 ----------------
func play_win() -> void:
	sparkles.emitting = false
	rabbit_now("jump")
	var tw := world.create_tween()
	tw.tween_property(carrot_pivot, "rotation", 0.0, 0.15)
	tw.tween_method(_set_expose, _expose_now(), 1.05, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	fly_start = carrot_pivot.position
	fly_end = RABBIT_TL + Vector2(250, 280)
	fly_ctrl = (fly_start + fly_end) / 2.0 + Vector2(0, -480)
	tw.tween_method(_fly_step, 0.0, 1.0, 0.9).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(_on_carrot_caught)
	tw.tween_interval(0.9)
	tw.tween_callback(func(): ending_finished.emit("win"))


func _fly_step(t: float) -> void:
	carrot_pivot.position = fly_start.lerp(fly_ctrl, t).lerp(fly_ctrl.lerp(fly_end, t), t)
	carrot_pivot.rotation = t * TAU
	carrot_pivot.scale = Vector2.ONE * lerpf(1.0, 0.4, t)


func _on_carrot_caught() -> void:
	carrot_pivot.visible = false
	_rabbit_set("hold")
	for c in confetti:
		c.restart()
		c.emitting = true


## broken = true: the carrot snaps; false: time is up.
func play_lose(broken: bool) -> void:
	sparkles.emitting = false
	rabbit_now("speechless")
	if broken:
		var e := _expose_now()
		carrot.visible = false
		carrot_pivot.rotation = 0.0
		# 下半截留在土里：断口（图中 y≈115）略高于土面
		var bottom := Sprite2D.new()
		bottom.texture = _tex("carrot_broken_bottom", Vector2i(400, 600), Color(0.9, 0.5, 0.1))
		bottom.position = Vector2(0, 300.0 - 115.0 - 15.0)
		carrot_pivot.add_child(bottom)
		# 上半截飞出去落在旁边
		var top := Sprite2D.new()
		top.texture = _tex("carrot_broken_top", Vector2i(438, 400), Color(0.4, 0.75, 0.3))
		top.position = PIVOT + Vector2(0, -e * CARROT_SIZE.y + 200)
		world.add_child(top)
		world.move_child(top, soil_front.get_index() + 1)
		var tw := world.create_tween()
		tw.tween_property(top, "position", PIVOT + Vector2(-330, -110), 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.parallel().tween_property(top, "rotation", -1.4, 0.6)
		tw.tween_interval(0.8)
		tw.tween_callback(func(): ending_finished.emit("broken"))
	else:
		var tw2 := world.create_tween()
		tw2.tween_interval(0.6)
		tw2.tween_callback(func(): ending_finished.emit("timeout"))


## Result panel. title_key: "win" / "broken" / "timeout". stats: [rocks, rocks_to_win, mistakes, elapsed].
## grade: [grade, total] or [] when there is no report. new_ach: achievement names (already localised).
func show_result(title_key: String, stats: Array, grade: Array, new_ach: PackedStringArray) -> void:
	hint_label.visible = false
	status_label.text = ""
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.25)
	dim.size = DESIGN
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	world.add_child(dim)
	var panel := Sprite2D.new()
	panel.texture = _tex("ui_result_panel", Vector2i(800, 500), Color(1, 0.95, 0.85, 0.95))
	panel.position = Vector2(960, 520)
	panel.scale = Vector2.ONE * 0.6
	world.add_child(panel)
	world.create_tween().tween_property(panel, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var t := _label(tr_(title_key), 60, Vector2(560, 300), Vector2(800, 80))
	var df := Garden.display_font()   # v0.7.0: title in ZCOOL KuaiLe
	if df != null:
		t.add_theme_font_override("font", df)
	var body := _label(tr_("result") % stats, 36, Vector2(560, 380), Vector2(800, 150))
	var again := _button(tr_("again"), Vector2(580, 600), true, func(): again_pressed.emit())
	var rep := _button(tr_("report"), Vector2(840, 600), false, func(): report_pressed.emit())
	rep.disabled = grade.is_empty()
	var back := _button(tr_("back"), Vector2(1100, 600), false, func(): back_pressed.emit())
	var fade: Array = [t, body, again, rep, back]
	if not grade.is_empty():
		var g := _label(tr_("grade_line") % grade, 30, Vector2(560, 545), Vector2(800, 46))
		fade.append(g)
	if new_ach.size() > 0:
		var line := _label(tr_("new_ach") % ("、".join(new_ach) if lang == "zh" else ", ".join(new_ach)),
			26, Vector2(560, 685), Vector2(800, 50))
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		fade.append(line)
	for n in fade:
		n.modulate.a = 0.0
		world.create_tween().tween_property(n, "modulate:a", 1.0, 0.25).set_delay(0.2)
	again.grab_focus.call_deferred()


# ---------------- 小工具 ----------------
func _shake(n: Node2D, amp: float) -> void:
	var base := n.position
	var tw := world.create_tween()
	for i in 6:
		tw.tween_property(n, "position", base + Vector2(randf_range(-amp, amp), randf_range(-amp * 0.4, amp * 0.4)), 0.035)
	tw.tween_property(n, "position", base, 0.04)


# =====================================================================
## 左右两个绿色扇形。pos = 正力矩一侧（右），neg = 负力矩一侧（左）。
class SectorDrawer extends Node2D:
	var radius := 430.0
	var a0 := 0.3
	var a1 := 0.6
	var show_zone := true
	var hold_pos := 0.0
	var hold_neg := 0.0
	var near_limit := false
	var flash_pos := 0.0
	var flash_neg := 0.0
	var hint_pos := 0.0
	var hint_neg := 0.0

	func flash(s: int) -> void:
		if s > 0:
			flash_pos = 1.0
		else:
			flash_neg = 1.0

	func hint(s: int) -> void:
		if s > 0:
			hint_pos = 1.0
		elif s < 0:
			hint_neg = 1.0

	func _process(delta: float) -> void:
		flash_pos = maxf(0.0, flash_pos - delta * 2.5)
		flash_neg = maxf(0.0, flash_neg - delta * 2.5)
		hint_pos = maxf(0.0, hint_pos - delta * 1.5)
		hint_neg = maxf(0.0, hint_neg - delta * 1.5)

	func _draw() -> void:
		_side(1, hold_pos, flash_pos, hint_pos)
		_side(-1, hold_neg, flash_neg, hint_neg)

	func _side(s: int, hold: float, fl: float, hi: float) -> void:
		if show_zone:
			_wedge(s, radius, Color(0.62, 1.0, 0.45, 0.24 + 0.3 * hi))
			if hold > 0.0:
				_wedge(s, radius * (0.2 + 0.8 * hold), Color(0.5, 0.95, 0.3, 0.5))
			var edge: Color = Color(1.0, 0.5, 0.45, 0.95) if near_limit and hold > 0.0 else Color(0.88, 1.0, 0.72, 0.95)
			draw_polyline(_points(s, radius, true), edge, 4.0, true)
		if fl > 0.0:
			_wedge(s, radius, Color(1, 1, 0.7, 0.65 * fl))

	func _points(s: int, r: float, closed: bool) -> PackedVector2Array:
		var pts := PackedVector2Array([Vector2.ZERO])
		var n := 24
		for i in n + 1:
			var th: float = lerpf(a0, a1, float(i) / n)
			var phi := -PI / 2.0 + s * th
			pts.append(Vector2(cos(phi), sin(phi)) * r)
		if closed:
			pts.append(Vector2.ZERO)
		return pts

	func _wedge(s: int, r: float, c: Color) -> void:
		draw_colored_polygon(_points(s, r, false), c)


## 沙漏里的沙子（画在 ui_hourglass 后面，坐标为沙漏图 130×200 的局部坐标）
class SandDrawer extends Node2D:
	var frac := 1.0
	const C := Color(1.0, 0.78, 0.2)
	const CX := 65.0
	const MID := 100.0
	const TOP := 28.0
	const BOT := 172.0
	const HALF_W := 38.0

	func _draw() -> void:
		var f := clampf(frac, 0.0, 1.0)
		var h := (MID - TOP) * f
		if h > 1.0:
			var w := HALF_W * h / (MID - TOP)
			draw_colored_polygon(PackedVector2Array([Vector2(CX - w, MID - h), Vector2(CX + w, MID - h), Vector2(CX, MID)]), C)
		var hb := (BOT - MID) * (1.0 - f)
		if hb > 1.0:
			var yt := BOT - hb
			var wt := HALF_W * (yt - MID) / (BOT - MID)
			draw_colored_polygon(PackedVector2Array([Vector2(CX - HALF_W, BOT), Vector2(CX + HALF_W, BOT), Vector2(CX + wt, yt), Vector2(CX - wt, yt)]), C)
		if f > 0.0 and f < 1.0:
			draw_line(Vector2(CX, MID), Vector2(CX, BOT - hb), C, 2.0)
