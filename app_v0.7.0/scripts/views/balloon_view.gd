extends Node2D
## View — the balloon game scene (Rocking Challenge Level B, "Bunny's Balloons") (v0.6.0; v0.6.1: paws drawn separately in front of the rabbit).
## Passive: draws what the balloon presenter tells it, plays the animations and reports button presses.
## It knows nothing about the rules, the sensor, files or the database.
## Art: res://assets/balloon_game/ (positions from the README there) plus the shared backdrop, hourglass,
## result panel, sparkle and confetti from res://assets/carrot_game/.

signal again_pressed
signal report_pressed
signal back_pressed
## An ending animation (win, broken, time up) has finished; the presenter then shows the result panel.
signal ending_finished(kind: String)
signal escape_pressed

const ASSET_DIR := "res://assets/balloon_game/"
const SHARED_DIR := "res://assets/carrot_game/"
const FONT_PATH := "res://fonts/NotoSansSC-Bold.ttf"
const Garden := preload("res://app_v0.7.0/scripts/views/garden.gd")
const DESIGN := Vector2(1920, 1080)

const RABBIT_TL := Vector2(100, 400)
const PUMP_BASE_TL := Vector2(440, 640) ## v0.6.1：打气筒整体左移 30 px，把手左端藏在兔子脸颊后面
const PUMP_HANDLE_TL := Vector2(410, 555)
## v0.6.1：两只前爪单独绘制（从 pump_handle.png 拆出），并排放在把手靠兔子的一端，画在兔子前面
const PAW_LEFT_POS := Vector2(64, 20)   ## 相对把手图左上角
const PAW_RIGHT_POS := Vector2(106, 20)
const RABBIT_FOLLOW := 0.3 ## 把手下压时兔子跟着低头的比例
const HANDLE_TRAVEL := 40.0 ## px：力矩到上限时把手压下的距离
const PUMP_OUTLET := Vector2(582, 805) ## 底座右侧出气口（世界坐标）
const NOZZLE := Vector2(760, 760) ## 气球吹口（世界坐标）
const BALLOON_ANCHOR := Vector2(200, 479) ## 气球图内的吹口锚点
const BODY_CENTRE := Vector2(-4, -257) ## 气球球体中心，相对吹口（图内像素，乘缩放）
const BODY_RADIUS := Vector2(184, 210) ## 气球球体半径（图内像素，乘缩放）
const SCALE_MIN := 0.18 ## 力矩为 0 时的气球缩放
const SCALE_MAX := 0.86 ## 力矩到爆裂上限时的气球缩放
const CARROT_TL := Vector2(980, 580)
const KNOT := Vector2(235, 165) ## 大萝卜图内绳结线圈中心
const TIED_SCALE := 0.5
## 绑好的气球吹口相对绳结的位置（依次 1–5 个）
const TIED_SLOTS := [Vector2(-70, -250), Vector2(60, -300), Vector2(-170, -210), Vector2(170, -230), Vector2(-10, -380)]
const CARROT_LIFT := [0.0, 0.0, 6.0, 14.0, 26.0, 40.0] ## px：已绑 n 个气球时萝卜离地的高度
const COLOURS := ["pink", "yellow", "blue", "purple", "green"]
## balloon_flat.png 是粉色的；按颜色转色相（与各色气球主色相差）
const FLAT_HUE := [0.0, 0.21, -0.373, -0.183, 0.348]
const BAND_TOP := 930.0

const HUE_SHADER := """
shader_type canvas_item;
uniform float hue_shift = 0.0;
vec3 rgb2hsv(vec3 c) {
	vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	float e = 1.0e-10;
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}
vec3 hsv2rgb(vec3 c) {
	vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
	vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
	return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}
void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec3 h = rgb2hsv(c.rgb);
	float pinkish = 1.0 - smoothstep(0.06, 0.12, min(abs(h.x - 0.93), 1.0 - abs(h.x - 0.93)));
	if (h.y > 0.2) {
		h.x = fract(h.x + hue_shift * pinkish);
	}
	COLOR = vec4(hsv2rgb(h), c.a) * COLOR;
}
"""

const TEXT := {
	"zh": {
		"hint": "跟着虚线圈，慢慢吹",
		"keys": "键盘：→ / D / E / ↑ 加力，← / A / Q / ↓ 松开，按住 Shift 用力过猛，按住 S 偏轴，Esc 返回",
		"relax": "把手放松，回到起点开始",
		"ready": "准备……",
		"relax_next": "松开，回到起点换下一个气球",
		"too_fast": "太快了！慢一点",
		"follow": "跟上虚线圈",
		"hold": "保持住！",
		"leak": "吹太快，漏气了！重新吹",
		"pop": "砰！",
		"win": "萝卜飞起来啦！",
		"broken": "气球全爆了……再来一次？",
		"timeout": "时间到！再来一次？",
		"result": "绑好气球：%d / %d\n爆掉：%d 次　漏气：%d 次\n用时：%.1f 秒",
		"again": "再来一次",
		"back": "返回选择",
		"new_ach": "本局新成就：%s",
		"report": "评估报告",
		"grade_line": "评级 %s · %.1f 分",
	},
	"en": {
		"hint": "Follow the dashed ring, blow slowly",
		"keys": "Keyboard: → / D / E / ↑ more force, ← / A / Q / ↓ let go, hold Shift = too hard, hold S = off-axis, Esc = back",
		"relax": "Relax your grip and return to the start",
		"ready": "Get ready…",
		"relax_next": "Let go — back to the start for the next balloon",
		"too_fast": "Too fast! Slow down",
		"follow": "Keep up with the ring",
		"hold": "Hold it!",
		"leak": "Too fast — it leaked! Start again",
		"pop": "POP!",
		"win": "Up goes the carrot!",
		"broken": "All popped… try again?",
		"timeout": "Time's up! Try again?",
		"result": "Balloons tied: %d / %d\nPopped: %d   Leaked: %d\nTime: %.1f s",
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
var missing := PackedStringArray()
var hue_shader: Shader

var overload := 0.40
var safe_max := 0.34
var colour_index := 0
var display_scale := SCALE_MIN

var clouds: Array = []
var soil_front: Sprite2D
var rabbit: Sprite2D
var rabbit_tex := {}
var rabbit_base := "focus"
var rabbit_temp_t := 0.0
var rabbit_fly: Sprite2D
var pump_handle: Sprite2D
var paws: Node2D
var hose: HoseDrawer
var flat: Sprite2D
var flat_mat: ShaderMaterial
var balloon_root: Node2D
var balloon: Sprite2D
var balloon_tex: Array = []
var stretch: Sprite2D
var ring: RingDrawer
var sparkles: CPUParticles2D
var air: CPUParticles2D
var rubber: Array = []
var pop_fx: Sprite2D
var carrot_group: Node2D
var carrot: Sprite2D
var carrot_fall_tex: Texture2D
var strings: StringDrawer
var tied_sprites: Array = []
var confetti: Array = []
var life_icons: Array = []
var tex_life_off: Texture2D
var slots: Array = []
var slot_tex: Array = []
var hourglass: Sprite2D
var sand: SandDrawer
var strip: StripDrawer
var hint_label: Label
var status_label: Label
var flash_label: Label
var flash_t := 0.0
var debug_label: Label
var sway_t := 0.0
var carrot_base_y := 0.0
var leak_tw: Tween


func tr_(key: String) -> String:
	var table: Dictionary = TEXT.get(lang, TEXT["en"])
	return table.get(key, TEXT["en"].get(key, key))


func _ready() -> void:
	if ResourceLoader.exists(FONT_PATH):
		font = load(FONT_PATH)
	hue_shader = Shader.new()
	hue_shader.code = HUE_SHADER
	get_viewport().size_changed.connect(_fit_to_viewport)


## (Re)build the scene for a new round.
## cfg: allowed (mistakes), timed, ring, strip, text (hints), keyboard (bool), overload, safe_max (N·m)
func build(cfg: Dictionary) -> void:
	if world != null:
		world.queue_free()
	clouds.clear()
	rabbit_tex.clear()
	balloon_tex.clear()
	rubber.clear()
	tied_sprites.clear()
	confetti.clear()
	life_icons.clear()
	slots.clear()
	slot_tex.clear()
	missing = PackedStringArray()
	rabbit_base = "focus"
	rabbit_temp_t = 0.0
	flash_t = 0.0
	colour_index = 0
	display_scale = SCALE_MIN
	leak_tw = null
	overload = cfg["overload"]
	safe_max = cfg["safe_max"]
	world = Node2D.new()
	add_child(world)
	_fit_to_viewport()
	_build_scene(cfg)
	if missing.size() > 0:
		push_warning("兔子的气球：缺少素材，已用色块代替：" + ", ".join(missing))


func _fit_to_viewport() -> void:
	if world == null:
		return
	var vp := get_viewport_rect().size
	var s: float = minf(vp.x / DESIGN.x, vp.y / DESIGN.y)
	world.scale = Vector2(s, s)
	world.position = (vp - DESIGN * s) / 2.0


# ---------------- 资源 ----------------
func _tex(res_name: String, fallback := Vector2i(64, 64), color := Color(1, 0, 1, 0.5), dir := ASSET_DIR) -> Texture2D:
	var path := dir + res_name + ".png"
	if ResourceLoader.exists(path):
		return load(path)
	missing.append(res_name)
	var img := Image.create(fallback.x, fallback.y, false, Image.FORMAT_RGBA8)
	img.fill(color)
	return ImageTexture.create_from_image(img)


func _shared(res_name: String, fallback := Vector2i(64, 64), color := Color(1, 0, 1, 0.5)) -> Texture2D:
	return _tex(res_name, fallback, color, SHARED_DIR)


func _sprite_tl(tex: Texture2D, top_left: Vector2, parent: Node = null) -> Sprite2D:
	var s := Sprite2D.new()
	s.centered = false
	s.texture = tex
	s.position = top_left
	(parent if parent != null else world).add_child(s)
	return s


# ---------------- 场景 ----------------
func _build_scene(cfg: Dictionary) -> void:
	_sprite_tl(_shared("bg_sky", Vector2i(1920, 1080), Color(0.45, 0.75, 0.98)), Vector2.ZERO)
	var cloud_spec := [["bg_cloud_02", Vector2(180, 150), 9.0], ["bg_cloud_03", Vector2(1150, 130), 6.0], ["bg_cloud_01", Vector2(640, 60), 13.0]]
	for c in cloud_spec:
		var n := _sprite_tl(_shared(c[0], Vector2i(360, 180), Color(1, 1, 1, 0.9)), c[1])
		clouds.append({"node": n, "speed": c[2]})
	_sprite_tl(_shared("bg_fence", Vector2i(4, 4), Color(0, 0, 0, 0)), Vector2.ZERO)
	_sprite_tl(_shared("bg_soil_back", Vector2i(4, 4), Color(0, 0, 0, 0)), Vector2.ZERO)

	# ---- 兔子与打气筒
	for n in ["focus", "happy", "frizz", "worried", "speechless"]:
		rabbit_tex[n] = _tex("balloon_rabbit_" + n, Vector2i(500, 450), Color(0.98, 0.92, 0.85))
	# 图层：把手（不带爪子）→ 底座 → 兔子 → 爪子，把手左端藏在兔子脸后，爪子搭在把手上
	pump_handle = _sprite_tl(_tex("pump_handle_bar", Vector2i(260, 180), Color(0.9, 0.2, 0.2)), PUMP_HANDLE_TL)
	_sprite_tl(_tex("pump_base", Vector2i(200, 260), Color(0.9, 0.2, 0.2)), PUMP_BASE_TL)
	rabbit = _sprite_tl(rabbit_tex["focus"], RABBIT_TL)
	paws = Node2D.new()
	paws.position = PUMP_HANDLE_TL
	world.add_child(paws)
	_sprite_tl(_tex("pump_paw_left", Vector2i(60, 44), Color(0.98, 0.92, 0.85)), PAW_LEFT_POS, paws)
	_sprite_tl(_tex("pump_paw_right", Vector2i(60, 44), Color(0.98, 0.92, 0.85)), PAW_RIGHT_POS, paws)
	hose = HoseDrawer.new()
	hose.a = PUMP_OUTLET
	hose.b = NOZZLE
	world.add_child(hose)

	# ---- 当前气球（瘪的 / 正在吹的）
	flat = _sprite_tl(_tex("balloon_flat", Vector2i(160, 120), Color(0.95, 0.45, 0.6)), NOZZLE + Vector2(-8, -84))
	flat.flip_h = true
	flat_mat = ShaderMaterial.new()
	flat_mat.shader = hue_shader
	flat.material = flat_mat
	balloon_root = Node2D.new()
	balloon_root.position = NOZZLE
	world.add_child(balloon_root)
	for c in COLOURS:
		balloon_tex.append(_tex("balloon_" + c, Vector2i(400, 480), Color(0.95, 0.45, 0.6)))
	balloon = Sprite2D.new()
	balloon.centered = false
	balloon.offset = -BALLOON_ANCHOR
	balloon.texture = balloon_tex[0]
	balloon.visible = false
	balloon_root.add_child(balloon)
	stretch = Sprite2D.new()
	stretch.centered = false
	stretch.offset = -BALLOON_ANCHOR
	stretch.texture = _tex("balloon_stretch", Vector2i(4, 4), Color(0, 0, 0, 0))
	stretch.visible = false
	balloon.add_child(stretch)

	ring = RingDrawer.new()
	ring.position = NOZZLE
	ring.show_ring = cfg["ring"]
	ring.show_ticks = not cfg["ring"]
	world.add_child(ring)

	sparkles = CPUParticles2D.new()
	sparkles.texture = _shared("fx_sparkle", Vector2i(16, 16), Color(1, 0.95, 0.5))
	sparkles.amount = 14
	sparkles.lifetime = 0.8
	sparkles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	sparkles.emission_sphere_radius = 120.0
	sparkles.gravity = Vector2(0, -40)
	sparkles.scale_amount_min = 0.3
	sparkles.scale_amount_max = 0.6
	sparkles.emitting = false
	world.add_child(sparkles)

	air = CPUParticles2D.new()
	air.texture = _tex("fx_air", Vector2i(32, 32), Color(1, 1, 1, 0.8))
	air.position = NOZZLE + Vector2(0, -10)
	air.amount = 10
	air.lifetime = 0.7
	air.one_shot = true
	air.explosiveness = 0.6
	air.direction = Vector2(1, -0.4)
	air.spread = 40.0
	air.initial_velocity_min = 120.0
	air.initial_velocity_max = 260.0
	air.gravity = Vector2(0, -60)
	air.scale_amount_min = 0.5
	air.scale_amount_max = 1.0
	air.emitting = false
	world.add_child(air)

	for i in 3:
		var r := CPUParticles2D.new()
		r.texture = _tex("fx_rubber_0%d" % (i + 1), Vector2i(24, 24), Color(0.95, 0.45, 0.6))
		r.amount = 5
		r.lifetime = 1.0
		r.one_shot = true
		r.explosiveness = 1.0
		r.spread = 180.0
		r.initial_velocity_min = 250.0
		r.initial_velocity_max = 520.0
		r.gravity = Vector2(0, 900)
		r.angular_velocity_min = -540.0
		r.angular_velocity_max = 540.0
		r.emitting = false
		world.add_child(r)
		rubber.append(r)

	pop_fx = Sprite2D.new()
	pop_fx.texture = _tex("balloon_pop", Vector2i(500, 500), Color(1, 0.8, 0.2))
	pop_fx.visible = false
	world.add_child(pop_fx)

	# ---- 大萝卜（绳、绑好的气球、萝卜，一起升起）
	carrot_group = Node2D.new()
	carrot_group.position = CARROT_TL + KNOT
	carrot_base_y = carrot_group.position.y
	world.add_child(carrot_group)
	strings = StringDrawer.new()
	carrot_group.add_child(strings)
	carrot = _sprite_tl(_tex("big_carrot", Vector2i(760, 300), Color(1.0, 0.55, 0.1)), -KNOT, carrot_group)
	carrot_fall_tex = _tex("big_carrot_fall", Vector2i(760, 300), Color(1.0, 0.55, 0.1))
	rabbit_fly = _sprite_tl(_tex("balloon_rabbit_fly", Vector2i(400, 500), Color(0.98, 0.92, 0.85)), Vector2(-440, -20), carrot_group)
	rabbit_fly.visible = false

	soil_front = _sprite_tl(_shared("bg_soil_front", Vector2i(1920, 300), Color(0.55, 0.33, 0.18)), Vector2.ZERO)
	if soil_front.texture.get_height() < 1000:
		soil_front.position = Vector2(0, 790)
	_sprite_tl(_shared("bg_plants_front", Vector2i(4, 4), Color(0, 0, 0, 0)), Vector2.ZERO)

	for i in 4:
		var cf := CPUParticles2D.new()
		cf.texture = _shared("fx_confetti_0%d" % (i + 1), Vector2i(14, 8), Color.from_hsv(i * 0.25, 0.7, 1.0))
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
		cf.position = Vector2(960, 700)
		world.add_child(cf)
		confetti.append(cf)

	# ---- UI：左上失误次数，中间 5 个气球槽，右上沙漏
	tex_life_off = _tex("ui_life_balloon_off", Vector2i(70, 100), Color(0.5, 0.5, 0.5))
	var life_on := _tex("ui_life_balloon_on", Vector2i(70, 100), Color(0.95, 0.45, 0.6))
	for i in int(cfg["allowed"]):
		life_icons.append(_sprite_tl(life_on, Vector2(40 + i * 72, 30)))
	var empty := _tex("ui_slot_empty", Vector2i(70, 100), Color(1, 1, 1, 0.5))
	for c in COLOURS:
		slot_tex.append(_tex("ui_slot_" + c, Vector2i(70, 100), Color(0.95, 0.45, 0.6)))
	for i in COLOURS.size():
		slots.append(_sprite_tl(empty, Vector2(960 - 2.5 * 90 + i * 90 + 10, 30)))
	hourglass = _sprite_tl(_shared("ui_hourglass", Vector2i(130, 200), Color(0.6, 0.4, 0.2)), Vector2(1750, 30))
	sand = SandDrawer.new()
	sand.show_behind_parent = true
	hourglass.add_child(sand)
	hourglass.visible = cfg["timed"]

	# ---- 实习生：底部半透明条，左边文字提示，右边当前气球的曲线
	strip = StripDrawer.new()
	strip.position = Vector2(0, BAND_TOP)
	strip.overload = overload
	strip.visible = cfg["strip"]
	world.add_child(strip)
	hint_label = _label(tr_("hint"), 40, Vector2(40, BAND_TOP + 10), Vector2(560, 90))
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	hint_label.visible = cfg["text"]

	status_label = _label("", 40, Vector2(0, 160), Vector2(1920, 60))
	flash_label = _label("", 48, Vector2(0, 230), Vector2(1920, 70))
	flash_label.visible = false

	var keys := _label(tr_("keys") if cfg["keyboard"] else "", 22, Vector2(0, 1038), Vector2(1920, 36))
	keys.modulate = Color(1, 1, 1, 0.8)

	debug_label = _label("", 26, Vector2(40, 200), Vector2(760, 200))
	debug_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	debug_label.visible = false


func _label(text: String, font_size: int, pos: Vector2, box: Vector2) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.size = box
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if font:
		l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", font_size)
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


# ---------------- 气球几何 ----------------
func _scale_for(m: float) -> float:
	return lerpf(SCALE_MIN, SCALE_MAX, clampf(m / overload, 0.0, 1.0))


func _body_centre(s: float) -> Vector2:
	return NOZZLE + BODY_CENTRE * s


# =====================================================================
# 每帧：云、兔子临时表情、绑好的气球轻轻摆动（纯画面）
func _process(delta: float) -> void:
	if world == null:
		return
	sway_t += delta
	for c in clouds:
		var n: Sprite2D = c["node"]
		n.position.x += c["speed"] * delta
		if n.position.x > DESIGN.x + 50:
			n.position.x = -n.texture.get_width() - 50
	if rabbit_temp_t > 0.0:
		rabbit_temp_t -= delta
		if rabbit_temp_t <= 0.0:
			_rabbit_set(rabbit_base)
	if flash_t > 0.0:
		flash_t -= delta
		if flash_t <= 0.0:
			flash_label.visible = false
	for i in tied_sprites.size():
		var sp: Sprite2D = tied_sprites[i]
		if not sp.has_meta("flying"):
			sp.rotation = 0.06 * sin(sway_t * 1.3 + i * 1.7)
	strings.balloons = tied_sprites
	strings.queue_redraw()


## Per-frame state from the presenter.
## s: active, torque, inflating, guide, target, ring_state ("ok"/"fast"/"slow"), hold_frac, near_limit,
##    status_key, time_frac, strip_t / strip_m (current balloon's trace, Intern only)
func render(s: Dictionary, delta: float) -> void:
	if world == null:
		return
	if s["active"]:
		var torque: float = maxf(s["torque"], 0.0)
		var press := HANDLE_TRAVEL * clampf(torque / overload, 0.0, 1.0)
		pump_handle.position.y = PUMP_HANDLE_TL.y + press
		paws.position.y = PUMP_HANDLE_TL.y + press
		rabbit.position.y = RABBIT_TL.y + RABBIT_FOLLOW * press
		var inflating: bool = s["inflating"]
		if inflating:
			display_scale = lerpf(display_scale, _scale_for(torque), 1.0 - exp(-15.0 * delta))
			balloon.scale = Vector2.ONE * display_scale
			balloon.visible = true
			flat.visible = false
			var near: bool = s["near_limit"]
			stretch.visible = near
			balloon_root.position = NOZZLE + (Vector2(randf_range(-2, 2), randf_range(-2, 2)) if near else Vector2.ZERO)
			ring.visible = true
			ring.scale_now = _scale_for(s["guide"])
			ring.scale_target = _scale_for(s["target"])
			ring.state = s["ring_state"]
			ring.hold = s["hold_frac"]
			sparkles.position = _body_centre(display_scale)
			sparkles.emitting = s["hold_frac"] > 0.0
			if near:
				rabbit_base = "worried"
			elif s["ring_state"] == "fast":
				rabbit_base = "worried"
			else:
				rabbit_base = "focus"
			if rabbit_temp_t <= 0.0:
				_rabbit_set(rabbit_base)
		else:
			ring.visible = false
			sparkles.emitting = false
			stretch.visible = false
		ring.queue_redraw()
		status_label.text = tr_(s["status_key"]) if s["status_key"] != "" else ""
		if strip.visible and s.has("strip_t"):
			strip.trace_t = s["strip_t"]
			strip.trace_m = s["strip_m"]
			strip.queue_redraw()
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


func _flash(key: String, t := 1.2) -> void:
	flash_label.text = tr_(key)
	flash_label.visible = true
	flash_t = t


# ---------------- 事件对应的画面 ----------------
## A new balloon (index 0..4) starts inflating; target (N·m) and ramp (s) set up the Intern strip chart.
func show_balloon_start(index: int, target: float, ramp: float, hold: float) -> void:
	if leak_tw != null:
		leak_tw.kill()
		leak_tw = null
	colour_index = clampi(index, 0, COLOURS.size() - 1)
	balloon.texture = balloon_tex[colour_index]
	balloon.modulate = Color.WHITE
	balloon.rotation = 0.0
	display_scale = SCALE_MIN
	balloon.scale = Vector2.ONE * display_scale
	balloon.visible = true
	flat.visible = false
	strip.target = target
	strip.ramp = ramp
	strip.span = ramp + hold + 1.5
	strip.trace_t = PackedFloat32Array()
	strip.trace_m = PackedFloat32Array()
	strip.queue_redraw()


## The flat balloon waiting on the hose for the next one (colour index 0..4).
func show_flat(index: int) -> void:
	colour_index = clampi(index, 0, COLOURS.size() - 1)
	flat_mat.set_shader_parameter("hue_shift", FLAT_HUE[colour_index])
	flat.visible = true
	balloon.visible = false
	ring.visible = false


## Too fast: air rushes out, the balloon shrinks back to flat (no mistake counted).
func show_leak() -> void:
	air.restart()
	air.emitting = true
	ring.visible = false
	sparkles.emitting = false
	_flash("leak")
	rabbit_temp("worried", 1.0)
	if leak_tw != null:
		leak_tw.kill()
	leak_tw = world.create_tween()
	leak_tw.tween_method(_leak_step, balloon.scale.x, SCALE_MIN, 0.45)
	leak_tw.tween_callback(_leak_done)


func _leak_step(v: float) -> void:
	balloon.scale = Vector2.ONE * v
	balloon.rotation = 0.25 * sin(v * 60.0)


func _leak_done() -> void:
	leak_tw = null
	balloon.rotation = 0.0
	show_flat(colour_index)


## Over the limit: the balloon bursts, rubber flies, the rabbit's fur stands on end, one life greyed.
func show_pop(life_index: int) -> void:
	var c := _body_centre(display_scale)
	balloon.visible = false
	stretch.visible = false
	ring.visible = false
	sparkles.emitting = false
	pop_fx.position = c
	pop_fx.scale = Vector2.ONE * 0.2
	pop_fx.modulate.a = 1.0
	pop_fx.visible = true
	var tw := world.create_tween()
	tw.tween_property(pop_fx, "scale", Vector2.ONE * 0.9, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(pop_fx, "modulate:a", 0.0, 0.3)
	tw.tween_callback(pop_fx.hide)
	for r in rubber:
		r.position = c
		r.modulate = Color.WHITE
		r.restart()
		r.emitting = true
	_flash("pop", 0.8)
	rabbit_temp("frizz", 1.5)
	if life_index >= 0 and life_index < life_icons.size():
		life_icons[life_index].texture = tex_life_off
	_shake(rabbit, 8.0)
	show_flat(colour_index)


## A balloon is done: it floats over to the carrot and is tied on; its slot at the top fills in.
func show_tie(index: int) -> void:
	var i := clampi(index, 0, COLOURS.size() - 1)
	ring.visible = false
	sparkles.emitting = false
	stretch.visible = false
	balloon.visible = false
	var sp := Sprite2D.new()
	sp.centered = false
	sp.offset = -BALLOON_ANCHOR
	sp.texture = balloon_tex[i]
	sp.scale = Vector2.ONE * display_scale
	sp.position = NOZZLE - carrot_group.position
	sp.set_meta("flying", true)
	carrot_group.add_child(sp)
	carrot_group.move_child(sp, carrot.get_index())   # 气球在萝卜后面，绳结盖住绳头
	tied_sprites.append(sp)
	var dest: Vector2 = TIED_SLOTS[i]
	var tw := world.create_tween()
	tw.tween_property(sp, "position", dest, 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.parallel().tween_property(sp, "scale", Vector2.ONE * TIED_SCALE, 0.6)
	tw.tween_callback(sp.remove_meta.bind("flying"))
	var lift: float = CARROT_LIFT[mini(tied_sprites.size(), CARROT_LIFT.size() - 1)]
	tw.tween_property(carrot_group, "position:y", carrot_base_y - lift, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	slots[i].texture = slot_tex[i]
	world.create_tween().tween_property(slots[i], "scale", Vector2.ONE * 1.15, 0.12).set_trans(Tween.TRANS_SINE)
	world.create_tween().tween_property(slots[i], "scale", Vector2.ONE, 0.15).set_delay(0.12)
	rabbit_temp("happy", 1.2)
	if i + 1 < COLOURS.size():
		show_flat(i + 1)
	else:
		flat.visible = false


## Off-axis warning: the soil shakes, the rabbit looks worried.
func show_offaxis() -> void:
	_shake(soil_front, 8.0)
	rabbit_temp("worried", 1.0)


# ---------------- 兔子 ----------------
func _rabbit_set(n: String) -> void:
	rabbit.texture = rabbit_tex[n]


func rabbit_temp(n: String, t: float) -> void:
	_rabbit_set(n)
	rabbit_temp_t = t


func rabbit_now(n: String) -> void:
	rabbit_temp_t = 0.0
	rabbit_base = n
	_rabbit_set(n)


# ---------------- 结束动画 ----------------
## All five tied: the rabbit jumps onto the carrot and they float away together.
func play_win() -> void:
	sparkles.emitting = false
	ring.visible = false
	status_label.text = ""
	rabbit_now("happy")
	var tw := world.create_tween()
	tw.tween_interval(0.7)
	tw.tween_property(rabbit, "position", RABBIT_TL + Vector2(260, -160), 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_callback(_grab_carrot)
	tw.tween_property(carrot_group, "position", carrot_group.position + Vector2(260, -1150), 2.6) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(carrot_group, "rotation", -0.12, 2.6)
	tw.tween_callback(func(): ending_finished.emit("win"))


func _grab_carrot() -> void:
	rabbit.visible = false
	rabbit_fly.visible = true
	# 兔子离开打气筒，爪子一起离开
	paws.visible = false
	for c in confetti:
		c.restart()
		c.emitting = true


## broken = true: too many pops; false: time is up. Tied balloons drift off and the carrot drops back.
func play_lose(broken: bool) -> void:
	sparkles.emitting = false
	ring.visible = false
	stretch.visible = false
	status_label.text = ""
	rabbit_now("speechless")
	strings.visible = false
	if not tied_sprites.is_empty():
		# the tied balloons come loose and drift up and away
		var fly := world.create_tween().set_parallel(true)
		for sp in tied_sprites:
			sp.set_meta("flying", true)
			fly.tween_property(sp, "position", sp.position + Vector2(randf_range(-200, 200), -1100), 2.0) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN).set_delay(0.3)
	var tw := world.create_tween()
	tw.tween_interval(0.5)
	if carrot_group.position.y < carrot_base_y - 1.0:
		tw.tween_property(carrot_group, "position:y", carrot_base_y, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_callback(_carrot_thud)
	tw.tween_interval(0.6)
	tw.tween_callback(func(): ending_finished.emit("broken" if broken else "timeout"))


func _carrot_thud() -> void:
	carrot.texture = carrot_fall_tex
	_shake(carrot_group, 6.0)


## Result panel. title_key: "win" / "broken" / "timeout". stats: [tied, balloons, pops, leaks, elapsed].
## grade: [grade, total] or [] when there is no report. new_ach: achievement names (already localised).
func show_result(title_key: String, stats: Array, grade: Array, new_ach: PackedStringArray) -> void:
	hint_label.visible = false
	strip.visible = false
	status_label.text = ""
	flash_label.visible = false
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.25)
	dim.size = DESIGN
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	world.add_child(dim)
	var panel := Sprite2D.new()
	panel.texture = _shared("ui_result_panel", Vector2i(800, 500), Color(1, 0.95, 0.85, 0.95))
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
		fade.append(_label(tr_("grade_line") % grade, 30, Vector2(560, 545), Vector2(800, 46)))
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
## 打气筒到气球的软管
class HoseDrawer extends Node2D:
	var a := Vector2.ZERO
	var b := Vector2.ZERO

	func _draw() -> void:
		var c1 := a + Vector2(50, 50)
		var c2 := b + Vector2(-40, 60)
		var pts := PackedVector2Array()
		for i in 25:
			var t := i / 24.0
			var u := 1.0 - t
			pts.append(u * u * u * a + 3.0 * u * u * t * c1 + 3.0 * u * t * t * c2 + t * t * t * b)
		draw_polyline(pts, Color(0.45, 0.2, 0.15), 11.0, true)
		draw_polyline(pts, Color(0.95, 0.52, 0.62), 7.0, true)


## 虚线目标圈（实习生、见习医生）或目标刻度（大师），以及保持进度弧。坐标原点 = 吹口。
class RingDrawer extends Node2D:
	const CENTRE := Vector2(-4, -257)
	const RADIUS := Vector2(184, 210)
	var show_ring := true
	var show_ticks := false
	var scale_now := 0.2     # 虚线圈：现在应该吹到的大小
	var scale_target := 0.5  # 刻度和进度弧：这个气球的目标大小
	var state := "ok"
	var hold := 0.0

	func _ellipse(s: float, a0: float, a1: float, n: int) -> PackedVector2Array:
		var pts := PackedVector2Array()
		for i in n + 1:
			var th := lerpf(a0, a1, float(i) / n)
			pts.append(CENTRE * s + Vector2(cos(th) * RADIUS.x, sin(th) * RADIUS.y) * s)
		return pts

	func _draw() -> void:
		var col: Color = Color(1.0, 0.55, 0.15, 0.95) if state == "fast" else Color(0.42, 0.8, 0.38, 0.95)
		if show_ring:
			var pts := _ellipse(scale_now + 0.02, 0.0, TAU, 72)
			for i in range(0, 72, 2):
				draw_line(pts[i], pts[i + 1], col, 5.0, true)
		if show_ticks:
			var c := CENTRE * scale_target
			var rx := RADIUS.x * scale_target + 6.0
			for sx in [-1.0, 1.0]:
				draw_line(c + Vector2(sx * (rx - 14.0), 0), c + Vector2(sx * (rx + 22.0), 0), Color(0.36, 0.22, 0.1, 0.9), 5.0, true)
		if hold > 0.0:
			var arc := _ellipse(scale_target + 0.05, -PI / 2.0, -PI / 2.0 + TAU * hold, 72)
			draw_polyline(arc, Color(1.0, 0.82, 0.25, 0.95), 8.0, true)


## 从绳结到每个绑好的气球的绳子（萝卜组的局部坐标，原点 = 绳结）
class StringDrawer extends Node2D:
	var balloons: Array = []

	func _draw() -> void:
		for sp in balloons:
			if not is_instance_valid(sp):
				continue
			var end: Vector2 = sp.position
			var mid := end * 0.5 + Vector2(18, 0)
			var pts := PackedVector2Array()
			for i in 13:
				var t := i / 12.0
				pts.append((1.0 - t) * (1.0 - t) * Vector2.ZERO + 2.0 * (1.0 - t) * t * mid + t * t * end)
			draw_polyline(pts, Color(0.45, 0.3, 0.2, 0.9), 3.0, true)


## 实习生的底部条：半透明底、计划的加力线（虚线）、目标线、实际曲线。原点 = 条的左上角。
class StripDrawer extends Node2D:
	const X0 := 620.0
	const X1 := 1860.0
	const Y_TOP := 14.0
	const Y_BOT := 100.0
	var overload := 0.40
	var target := 0.2
	var ramp := 3.0
	var span := 6.0
	var trace_t := PackedFloat32Array()
	var trace_m := PackedFloat32Array()

	func _xy(t: float, m: float) -> Vector2:
		var x := lerpf(X0, X1, clampf(t / span, 0.0, 1.0))
		var y := lerpf(Y_BOT, Y_TOP, clampf(m / overload, 0.0, 1.0))
		return Vector2(x, y)

	func _dashed(p0: Vector2, p1: Vector2, c: Color, w: float) -> void:
		var d := p0.distance_to(p1)
		var n := int(d / 14.0)
		for i in range(0, n, 2):
			draw_line(p0.lerp(p1, float(i) / n), p0.lerp(p1, float(i + 1) / n), c, w, true)

	func _draw() -> void:
		draw_rect(Rect2(0, 0, 1920, 150), Color(1.0, 0.98, 0.94, 0.62))
		draw_line(Vector2(X0, Y_BOT), Vector2(X1, Y_BOT), Color(0.36, 0.22, 0.1, 0.35), 2.0)
		var grey := Color(0.36, 0.22, 0.1, 0.55)
		_dashed(_xy(0.0, 0.0), _xy(ramp, target), grey, 4.0)
		_dashed(_xy(ramp, target), _xy(span, target), grey, 4.0)
		if trace_t.size() >= 2:
			var t0 := trace_t[0]
			var pts := PackedVector2Array()
			for i in trace_t.size():
				pts.append(_xy(trace_t[i] - t0, trace_m[i]))
			draw_polyline(pts, Color(0.93, 0.35, 0.55), 4.0, true)


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
