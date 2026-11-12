extends Node2D
## 摇牙挑战 Level A：拔萝卜（Rocking Challenge） — MP5 v0.5.3（v0.5.0 起记录成就；v0.5.2 起每局生成评估报告）
## 只用目标轴力矩。力矩为正时萝卜向右歪，为负时向左歪（与入门测试中 E 增大、Q 减小一致）。
## 一次合格的“半摆” = 推进绿色扇形 → 保持 HOLD_TIME 秒 → 回到中位。必须左右交替。
## 左右各一次算一个完整摆动；完成 cycles_to_win 次过关。
## 力矩超过 OVERLOAD 记一次失误（萝卜出现裂纹），失误超过难度允许的次数，萝卜断，本关失败。
## 偏轴力矩或拔力过大只做提醒，并暂停保持计时，不记失误。
## 场景全部由代码搭建；素材在 res://assets/carrot_game/（1920×1080 坐标见素材 README）。
## 下列数值都是原型占位值，不是验证值或临床值。

signal exit_requested

const AchievementDB := preload("res://app_v0.5.3/scripts/achievement_db.gd")
const AchDefs := preload("res://app_v0.5.3/scripts/achievement_defs.gd")
const ToastHost := preload("res://app_v0.5.3/scripts/achievement_toast_host.gd")
const Evaluation := preload("res://app_v0.5.3/scripts/evaluation.gd")
const ReportView := preload("res://app_v0.5.3/scripts/report_view.gd")

const ASSET_DIR := "res://assets/carrot_game/"
const FONT_PATH := "res://fonts/NotoSansSC-Bold.ttf"
const DESIGN := Vector2(1920, 1080)

# ---------------- 力矩参数（占位值，与入门测试的量程 ±0.5 N·m 一致） ----------------
const BAND_MIN := 0.15 ## N·m，绿色区间下沿
const BAND_MAX := 0.30 ## N·m，绿色区间上沿
const OVERLOAD := 0.40 ## N·m，超过记一次“用力过猛”
const NEUTRAL := 0.05 ## N·m，低于此值视为回到中位
const HOLD_TIME := 0.5 ## 秒
const DISPLAY_MAX := 0.45 ## 这个力矩对应最大倾角
const MAX_ANGLE_DEG := 35.0
const OFFAXIS_LIMIT := 0.30 ## N·m（真实传感器接入后使用）
const PULL_LIMIT := 30.0 ## N（真实传感器接入后使用）

## 难度：与游戏选择页的说明一致（game setting.md 第五节）
const DIFFICULTY := [
	{"mistakes": 5, "timed": false, "zone": true, "text": true},  # 实习生：文字＋颜色提示，无倒计时，允许失误 5 次
	{"mistakes": 3, "timed": true, "zone": true, "text": false},  # 见习医生：仅颜色提示，有倒计时，允许失误 3 次
	{"mistakes": 0, "timed": true, "zone": false, "text": false}, # 大师牙医：无提示，有倒计时，不允许失误
]

# ---------------- 素材坐标（来自素材 README，1920×1080） ----------------
const PIVOT := Vector2(960, 810) ## 萝卜出土点 / 旋转中心
const CARROT_SIZE := Vector2(400, 900)
const EXPOSE_START := 0.49 ## 起始时露出比例（左上角 y=370）
const EXPOSE_END := 0.90 ## 最后一次摆动后露出比例（只剩尖尖在土里）
const SOIL_CRACK_TL := Vector2(710, 735)
const RABBIT_TL := Vector2(1300, 390)
const SECTOR_RADIUS := 430.0

# ---------------- 由调用方设置 ----------------
var difficulty := 1
var lang := "zh"
var cycles_to_win := 6
var time_limit := 90.0
## 真实传感器：带 read() 的节点，返回 {"moment_nm", 可选 "offaxis_nm", "pull_n"}。为 null 时用键盘。
var sensor: Node = null
## 成就数据库（由主界面传入；单独运行本场景时自动创建）
var db: AchievementDB = null

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

enum Phase { READY, PLAYING, WIN, LOSE }

# ---------------- 状态 ----------------
var phase := Phase.READY
var allowed := 3
var time_left := 90.0
var elapsed := 0.0
var half_count := 0
var cycles := 0
var expected_side := 0
var pending_side := 0
var hold_t := 0.0
var overload_latched := false
var mistakes := 0
var offaxis_cool := 0.0
var ready_t := 0.0
var rabbit_temp_t := 0.0
var torque := 0.0
var offaxis := 0.0
var pull := 0.0
var kb_t := 0.0
var display_angle := 0.0
var fly_start := Vector2.ZERO
var fly_ctrl := Vector2.ZERO
var fly_end := Vector2.ZERO

# ---- 成就用的本局统计 ----
var clean_holds := true   # 每次进入绿区都一次保持成功
var over_band := false    # 本局力矩是否超过过绿区上沿
var ears := 0             # 兔子捂耳朵次数（偏轴提醒）
var push_armed := true    # 回到中位后，下一次推进绿区算一次“推”
var last_push_side := 0
var same_side_run := 0
var mid_round_ids: Array = []
var new_ids: Array = []
var round_recorded := false
var log_path := ""
var toasts: ToastHost

# ---- 评估报告（v0.5.2）：本局采样（只记 PLAYING 阶段）、事件和评估结果 ----
var t0_round := -1.0
var s_t := PackedFloat32Array()
var s_m := PackedFloat32Array()
var s_off := PackedFloat32Array()
var s_pull := PackedFloat32Array()
var ev_list: Array = []
var report: Dictionary = {}
var report_data: Dictionary = {}
var report_layer: CanvasLayer

# ---------------- 节点 ----------------
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

var log_file: FileAccess
var pending_event := ""


# =====================================================================
func _ready() -> void:
	if ResourceLoader.exists(FONT_PATH):
		font = load(FONT_PATH)
	if db == null:
		db = AchievementDB.new()
	toasts = ToastHost.new()
	toasts.lang = lang
	add_child(toasts)
	get_viewport().size_changed.connect(_fit_to_viewport)
	_start_round()


func tr_(key: String) -> String:
	var table: Dictionary = TEXT.get(lang, TEXT["en"])
	return table.get(key, TEXT["en"].get(key, key))


func _start_round() -> void:
	_close_log()
	if world != null:
		world.queue_free()
	var cfg: Dictionary = DIFFICULTY[clampi(difficulty, 0, DIFFICULTY.size() - 1)]
	allowed = cfg["mistakes"]
	phase = Phase.READY
	time_left = time_limit
	elapsed = 0.0
	half_count = 0
	cycles = 0
	expected_side = 0
	pending_side = 0
	hold_t = 0.0
	overload_latched = false
	mistakes = 0
	offaxis_cool = 0.0
	ready_t = 0.0
	rabbit_temp_t = 0.0
	kb_t = 0.0
	display_angle = 0.0
	clean_holds = true
	over_band = false
	ears = 0
	push_armed = true
	last_push_side = 0
	same_side_run = 0
	mid_round_ids = []
	new_ids = []
	round_recorded = false
	t0_round = -1.0
	s_t = PackedFloat32Array()
	s_m = PackedFloat32Array()
	s_off = PackedFloat32Array()
	s_pull = PackedFloat32Array()
	ev_list = []
	report = {}
	report_data = {}
	if report_layer != null:
		report_layer.queue_free()
		report_layer = null
	clouds.clear()
	carrot_cracks.clear()
	soil_crack_tex.clear()
	life_icons.clear()
	confetti.clear()
	rabbit_tex.clear()
	missing = PackedStringArray()

	world = Node2D.new()
	add_child(world)
	_fit_to_viewport()
	_build_scene(cfg)
	if missing.size() > 0:
		push_warning("拔萝卜：缺少素材，已用色块代替：" + ", ".join(missing))
	_open_log()


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
	sector.a0 = _angle_for(BAND_MIN)
	sector.a1 = _angle_for(BAND_MAX)
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
	for i in allowed:
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

	var keys := _label(tr_("keys") if sensor == null else "", 22, Vector2(0, 1035), Vector2(1920, 36))
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
	var b := Button.new()
	b.text = text
	b.position = pos
	b.size = Vector2(240, 72)
	b.focus_mode = Control.FOCUS_ALL
	if font:
		b.add_theme_font_override("font", font)
	b.add_theme_font_size_override("font_size", 32)
	var bg: Color = Color(0.93, 0.47, 0.13) if primary else Color(1, 0.97, 0.9)
	var fg: Color = Color.WHITE if primary else Color(0.42, 0.25, 0.1)
	for st in ["normal", "hover", "pressed", "focus"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = bg.lightened(0.08) if st == "hover" else (bg.darkened(0.1) if st == "pressed" else bg)
		if st == "focus":
			sb.bg_color = Color(0, 0, 0, 0)
			sb.border_color = Color(0.42, 0.25, 0.1)
			sb.set_border_width_all(3)
		else:
			sb.border_color = Color(0.45, 0.26, 0.1)
			sb.set_border_width_all(3)
		sb.set_corner_radius_all(18)
		b.add_theme_stylebox_override(st, sb)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(c, fg)
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
func _process(delta: float) -> void:
	if world == null:
		return
	_update_input(delta)
	for c in clouds:
		var n: Sprite2D = c["node"]
		n.position.x += c["speed"] * delta
		if n.position.x > DESIGN.x + 50:
			n.position.x = -n.texture.get_width() - 50

	if phase == Phase.READY or phase == Phase.PLAYING:
		var target: float = signf(torque) * _angle_for(torque)
		display_angle = lerp_angle(display_angle, target, 1.0 - exp(-15.0 * delta))
		carrot_pivot.rotation = display_angle

	match phase:
		Phase.READY:
			_step_ready(delta)
		Phase.PLAYING:
			_step_playing(delta)

	sector.queue_redraw()
	sand.frac = clampf(time_left / time_limit, 0.0, 1.0)
	sand.queue_redraw()
	if debug_label.visible:
		debug_label.text = "moment %.3f N·m  off-axis %.2f  pull %.1f\nhold %.2f s  halves %d  rocks %d/%d  mistakes %d/%d" % [
			torque, offaxis, pull, hold_t, half_count, cycles, cycles_to_win, mistakes, allowed]
	_write_log()


func _step_ready(delta: float) -> void:
	if absf(torque) < NEUTRAL:
		status_label.text = tr_("ready")
		ready_t += delta
		if ready_t >= 0.6:
			phase = Phase.PLAYING
			status_label.text = ""
			_event("start")
	else:
		status_label.text = tr_("relax")
		ready_t = 0.0


func _step_playing(delta: float) -> void:
	elapsed += delta
	if hourglass.visible:
		time_left -= delta
		if time_left <= 0.0:
			time_left = 0.0
			_lose(false)
			return

	if rabbit_temp_t > 0.0:
		rabbit_temp_t -= delta
		if rabbit_temp_t <= 0.0:
			_rabbit_base()

	var off_bad := offaxis > OFFAXIS_LIMIT or pull > PULL_LIMIT
	offaxis_cool = maxf(0.0, offaxis_cool - delta)
	if off_bad and offaxis_cool <= 0.0:
		offaxis_cool = 1.2
		_shake(soil_front, 8.0)
		_rabbit_temp("cover_ears", 1.0)
		_event("offaxis")
		ears += 1
		if ears == 3:
			_unlock_now("rock_shh")

	var a := absf(torque)
	var s := int(signf(torque))
	sector.hold_pos = 0.0
	sector.hold_neg = 0.0
	sector.near_limit = a > BAND_MAX
	sparkles.emitting = false
	carrot.modulate = Color.WHITE

	# 一次“推” = 从中位推到绿区下沿以上；用来判断是否在同一侧连续推
	if a < NEUTRAL:
		push_armed = true
	elif push_armed and a >= BAND_MIN:
		push_armed = false
		same_side_run = same_side_run + 1 if s == last_push_side else 1
		last_push_side = s
		if same_side_run == 5:
			_unlock_now("rock_wrong_side")
	if a > BAND_MAX:
		over_band = true

	if overload_latched:
		carrot.modulate = Color(1, 0.6, 0.6)
		if a < NEUTRAL:
			overload_latched = false
		return

	if a > OVERLOAD:
		_on_overload()
		return

	if a > BAND_MAX:
		carrot.modulate = Color(1, 0.82, 0.82)

	if pending_side != 0:
		if a < NEUTRAL:
			_on_half_complete(pending_side)
			pending_side = 0
		else:
			_set_hold(pending_side, 1.0)
		return

	if a >= BAND_MIN and a <= BAND_MAX:
		if expected_side == 0 or s == expected_side:
			if not off_bad:
				hold_t += delta
			sparkles.emitting = sector.show_zone
			_set_hold(s, hold_t / HOLD_TIME)
			if hold_t >= HOLD_TIME:
				pending_side = s
				hold_t = 0.0
				sector.flash(s)
				_event("hold_ok_" + ("R" if s > 0 else "L"))
		else:
			hold_t = 0.0
			if sector.show_zone:
				sector.hint(expected_side)
			if hint_label.visible:
				status_label.text = tr_("other_side")
	else:
		if hold_t > 0.0:
			clean_holds = false  # 保持到一半掉出绿区
		hold_t = 0.0
		if a < NEUTRAL:
			status_label.text = ""


func _set_hold(s: int, f: float) -> void:
	if s > 0:
		sector.hold_pos = clampf(f, 0.0, 1.0)
	else:
		sector.hold_neg = clampf(f, 0.0, 1.0)


func _on_half_complete(s: int) -> void:
	half_count += 1
	expected_side = -s
	status_label.text = ""
	var p := float(half_count) / float(cycles_to_win * 2)
	world.create_tween().tween_method(_set_expose, _expose_now(), _expose_for(p), 0.35) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if half_count % 2 == 0:
		cycles += 1
		_event("rock_%d" % cycles)
		dirt.restart()
		dirt.emitting = true
		var lvl := clampi(int(ceil(float(cycles) / cycles_to_win * 4.0)), 1, 4)
		soil_crack.texture = soil_crack_tex[lvl - 1]
		soil_crack.visible = true
		if cycles >= cycles_to_win:
			_win()
		else:
			_rabbit_temp("jump", 0.6)
	else:
		_event("half_%d" % half_count)


func _on_overload() -> void:
	overload_latched = true
	if hold_t > 0.0:
		clean_holds = false
	hold_t = 0.0
	pending_side = 0
	mistakes += 1
	_event("overload")
	var idx := clampi(mistakes, 1, 3) - 1
	for i in carrot_cracks.size():
		carrot_cracks[i].visible = (i == idx)
	var left := allowed - mistakes
	if left >= 0 and left < life_icons.size():
		life_icons[left].texture = tex_life_off
	_shake(carrot_pivot, 10.0)
	if mistakes > allowed:
		_lose(true)


# ---------------- 兔子 ----------------
func _rabbit_set(n: String) -> void:
	rabbit.texture = rabbit_tex[n]


func _rabbit_base() -> void:
	_rabbit_set("excited" if cycles >= 1 else "wait")


func _rabbit_temp(n: String, t: float) -> void:
	_rabbit_set(n)
	rabbit_temp_t = t


# ---------------- 结束 ----------------
func _win() -> void:
	phase = Phase.WIN
	_event("win")
	_record("win")
	sparkles.emitting = false
	_rabbit_set("jump")
	var tw := world.create_tween()
	tw.tween_property(carrot_pivot, "rotation", 0.0, 0.15)
	tw.tween_method(_set_expose, _expose_now(), 1.05, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	fly_start = carrot_pivot.position
	fly_end = RABBIT_TL + Vector2(250, 280)
	fly_ctrl = (fly_start + fly_end) / 2.0 + Vector2(0, -480)
	tw.tween_method(_fly_step, 0.0, 1.0, 0.9).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(_on_carrot_caught)
	tw.tween_interval(0.9)
	tw.tween_callback(_show_result.bind(tr_("win")))


# ---------------- 成就 ----------------
## 本局结束（过关、断、时间到、中途退出）时写入数据库，并弹出新解锁的成就。
func _record(result: String) -> void:
	if round_recorded or db == null:
		return
	round_recorded = true
	var r := {
		"game": AchDefs.GAME_ROCKING,
		"difficulty": clampi(difficulty, 0, 2),
		"result": result,
		"rocks": cycles,
		"rocks_to_win": cycles_to_win,
		"mistakes": mistakes,
		"allowed": allowed,
		"elapsed": elapsed,
		"clean_holds": clean_holds,
		"over_band": over_band,
		"ears": ears,
		"same_side_max": same_side_run,
		"hour": int(Time.get_datetime_dict_from_system()["hour"]),
		"log_file": log_path,
		"mid_round": mid_round_ids.duplicate(),
	}
	_evaluate(result)
	if not report.is_empty():
		r["evaluation"] = {"total": report["total"], "grade": report["grade"], "dims": report["dims"]}
	new_ids = db.record_round(r)
	toasts.lang = lang
	toasts.show_ids(new_ids)


## 本局评估：用内存里的采样和事件算分（与历史记录从 CSV 重算用的是同一套方法）。
func _evaluate(result: String) -> void:
	if s_t.size() < 2:
		report = {}
		return
	report_data = {
		"params": {"band_min": BAND_MIN, "band_max": BAND_MAX, "overload": OVERLOAD, "neutral": NEUTRAL,
			"hold": HOLD_TIME, "rocks_to_win": cycles_to_win, "offaxis_limit": OFFAXIS_LIMIT, "pull_limit": PULL_LIMIT},
		"t": s_t, "m": s_m, "off": s_off, "pull": s_pull, "events": ev_list.duplicate(),
		"result": result, "sensor": sensor != null, "difficulty": clampi(difficulty, 0, 2),
		"log_file": log_path, "at": Time.get_datetime_string_from_system(false, true),
		"mistakes": mistakes, "allowed": allowed, "rocks": cycles,
	}
	report = Evaluation.evaluate(report_data)


func _open_report() -> void:
	if report.is_empty() or report_layer != null:
		return
	report_layer = CanvasLayer.new()
	report_layer.layer = 50
	add_child(report_layer)
	var v = ReportView.new()
	v.lang = lang
	v.setup(report_data, report)
	v.closed.connect(_close_report)
	report_layer.add_child(v)


func _close_report() -> void:
	if report_layer != null:
		report_layer.queue_free()
		report_layer = null


## 局中就能达成的成就（你小声点、左右不分）立刻解锁并弹出。
func _unlock_now(id: String) -> void:
	if db != null and db.unlock(id):
		mid_round_ids.append(id)
		toasts.lang = lang
		toasts.show_ids([id])


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


func _lose(broken: bool) -> void:
	phase = Phase.LOSE
	_event("lose_broken" if broken else "lose_timeout")
	_record("broken" if broken else "timeout")
	sparkles.emitting = false
	_rabbit_set("speechless")
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
		tw.tween_callback(_show_result.bind(tr_("broken")))
	else:
		var tw2 := world.create_tween()
		tw2.tween_interval(0.6)
		tw2.tween_callback(_show_result.bind(tr_("timeout")))


func _show_result(title: String) -> void:
	_close_log()
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
	var t := _label(title, 60, Vector2(560, 300), Vector2(800, 80))
	var body := _label(tr_("result") % [cycles, cycles_to_win, mistakes, elapsed], 36, Vector2(560, 380), Vector2(800, 150))
	var again := _button(tr_("again"), Vector2(580, 600), true, _start_round)
	var rep := _button(tr_("report"), Vector2(840, 600), false, _open_report)
	rep.disabled = report.is_empty()
	var back := _button(tr_("back"), Vector2(1100, 600), false, _exit)
	var fade: Array = [t, body, again, rep, back]
	if not report.is_empty():
		var g := _label(tr_("grade_line") % [report["grade"], report["total"]], 30, Vector2(560, 545), Vector2(800, 46))
		fade.append(g)
	var got: Array = mid_round_ids + new_ids
	if got.size() > 0:
		var names := PackedStringArray()
		for id in got:
			names.append(AchDefs.text(AchDefs.get_def(id), "name", lang))
		var line := _label(tr_("new_ach") % "、".join(names) if lang == "zh" else tr_("new_ach") % ", ".join(names),
			26, Vector2(560, 685), Vector2(800, 50))
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		fade.append(line)
	for n in fade:
		n.modulate.a = 0.0
		world.create_tween().tween_property(n, "modulate:a", 1.0, 0.25).set_delay(0.2)
	again.grab_focus.call_deferred()


func _exit() -> void:
	_close_log()
	if exit_requested.get_connections().is_empty():
		_start_round() # 单独运行本场景时没有选择页，直接重开
	else:
		exit_requested.emit()


# ---------------- 小工具 ----------------
func _shake(n: Node2D, amp: float) -> void:
	var base := n.position
	var tw := world.create_tween()
	for i in 6:
		tw.tween_property(n, "position", base + Vector2(randf_range(-amp, amp), randf_range(-amp * 0.4, amp * 0.4)), 0.035)
	tw.tween_property(n, "position", base, 0.04)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_ESCAPE:
				if report_layer != null:
					_close_report()
					return
				if phase == Phase.PLAYING:
					_event("abort")
					_record("abort")
				_write_log()
				_exit()
			KEY_F3:
				debug_label.visible = not debug_label.visible


# =====================================================================
# 输入：有真实传感器时读 sensor.read()；否则用键盘（松手自动回中，模拟手放松）。
func _update_input(delta: float) -> void:
	if sensor != null and sensor.has_method("read"):
		var d: Dictionary = sensor.read()
		torque = float(d.get("moment_nm", 0.0))
		offaxis = absf(float(d.get("offaxis_nm", 0.0)))
		pull = absf(float(d.get("pull_n", 0.0)))
		return
	var mag := (BAND_MIN + BAND_MAX) / 2.0
	if Input.is_key_pressed(KEY_SHIFT):
		mag = OVERLOAD * 1.15
	var target := 0.0
	if Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_E):
		target += mag
	if Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_Q):
		target -= mag
	kb_t = move_toward(kb_t, target, 0.9 * delta)
	torque = kb_t + sin(Time.get_ticks_msec() * 0.007) * 0.004
	offaxis = OFFAXIS_LIMIT * 1.5 if Input.is_key_pressed(KEY_S) else 0.0
	pull = 0.0


# =====================================================================
# 试次记录：user://carrot_logs/（Windows：%APPDATA%\Godot\app_userdata\MP5\carrot_logs）
func _open_log() -> void:
	DirAccess.make_dir_recursive_absolute("user://carrot_logs")
	var stamp := Time.get_datetime_string_from_system().replace(":", "").replace("-", "").replace("T", "_")
	log_path = "user://carrot_logs/rocking_A_%s.csv" % stamp
	log_file = FileAccess.open(log_path, FileAccess.WRITE)
	if log_file == null:
		return
	log_file.store_line("# game=rocking_A difficulty=%d allowed_mistakes=%d timed=%s time_limit=%.0f band=%.2f-%.2f overload=%.2f neutral=%.2f hold=%.2f rocks_to_win=%d offaxis_limit=%.2f pull_limit=%.1f input=%s" % [
		difficulty, allowed, str(hourglass.visible), time_limit, BAND_MIN, BAND_MAX, OVERLOAD, NEUTRAL, HOLD_TIME, cycles_to_win,
		OFFAXIS_LIMIT, PULL_LIMIT, "keyboard" if sensor == null else "sensor"])
	log_file.store_line("t_s,moment_nm,offaxis_nm,pull_n,phase,hold_s,halves,rocks,mistakes,event")


## 记录一个事件：写入本帧的 CSV 行（同一帧有多个事件时用“;”分隔），并存入本局事件表。
func _event(ev_name: String) -> void:
	pending_event = ev_name if pending_event == "" else pending_event + ";" + ev_name
	var now := Time.get_ticks_msec() / 1000.0
	if ev_name == "start":
		t0_round = now
	elif t0_round >= 0.0:
		ev_list.append([now - t0_round, ev_name])


func _write_log() -> void:
	if phase == Phase.PLAYING and t0_round >= 0.0:
		s_t.append(Time.get_ticks_msec() / 1000.0 - t0_round)
		s_m.append(torque)
		s_off.append(offaxis)
		s_pull.append(pull)
	if log_file == null:
		pending_event = ""
		return
	log_file.store_line("%.3f,%.4f,%.4f,%.3f,%s,%.3f,%d,%d,%d,%s" % [
		Time.get_ticks_msec() / 1000.0, torque, offaxis, pull, Phase.keys()[phase], hold_t, half_count, cycles, mistakes, pending_event])
	pending_event = ""


func _close_log() -> void:
	if log_file != null:
		log_file.close()
		log_file = null


func _exit_tree() -> void:
	_close_log()


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
