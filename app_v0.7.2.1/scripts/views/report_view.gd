extends Control
## View — evaluation report (v0.7.2.1: "at a glance" cards, force band and coach's notes above the curve, popping in
## when the report opens; v0.5.2; v0.5.4: no model imports, saving done by the presenter; v0.6.0: also the
## balloon game — one-sided chart, standard ramp, pops / leaks / ties marked, "ramp control" instead of rhythm), full screen. Opened from the carrot game's result panel and from History.
## Shows: grade and total score, the round's target-axis moment against the standard curve (green zone,
## limit line, events marked), off-axis moment and pull force when a sensor was used, and the six scored
## dimensions with the numbers behind them. "Save to folder" writes a PNG of the report, a CSV of the scores
## and a copy of the raw samples into a folder the user picks.
## Design: design/设计方案_v1.1.md — porcelain page, white surfaces with hairlines, no shadows or gradients,
## colour only for state (TARGET = green zone / passed, FAULT = mistake / limit / not cleared).

signal closed
## User picked a folder; `picture` is a capture of the report. The presenter writes the files and calls show_saved().
signal save_requested(dir: String, picture: Image)

const P := preload("res://app_v0.7.2.1/scripts/views/palette.gd")
const UI := preload("res://app_v0.7.2.1/scripts/views/achievement_ui.gd")
const Garden := preload("res://app_v0.7.2.1/scripts/views/garden.gd")

const TEXT := {
	"zh": {
		"title": "评估报告：拔萝卜",
		"diff": ["实习生", "见习医生", "大师牙医"],
		"res_win": "过关", "res_broken": "未过关 · 萝卜断了", "res_timeout": "未过关 · 时间到", "res_abort": "未过关 · 中途退出",
		"save": "保存到文件夹", "close": "关闭",
		"total": "综合评分", "not_cleared": "未过关，评级为 F",
		"chart_m": "目标轴力矩（N·m）", "chart_off": "偏轴力矩（N·m）", "chart_pull": "拔力（N）",
		"no_sensor": "偏轴力矩和拔力：键盘模式没有这两项数据，接上传感器后显示。",
		"lg_user": "本局", "lg_std": "标准曲线", "lg_zone": "绿区", "lg_limit": "上限", "lg_over": "用力过猛", "lg_hold": "保持成功",
		"axis_t": "时间（秒）",
		"dims": {"safety": "安全", "accuracy": "精准", "stability": "稳定", "rhythm": "节奏与对称", "efficiency": "效率", "direction": "方向纯度"},
		"weight": "权重 %d%%", "na": "不适用",
		"m_safety": "用力过猛 %d 次 · 峰值 %.2f N·m · 超过绿区 %.0f%% 的时间",
		"m_accuracy": "保持时偏离绿区中心 %.0f%% · 与标准曲线误差 %.3f N·m",
		"m_stability": "保持时抖动 %.3f N·m · 一次保持成功 %.0f%%",
		"m_rhythm": "左右对称 %s · 摆动节奏变异 %s · 同侧连推 %d 次",
		"m_efficiency": "每次半摆 %s · 回中用时 %s",
		"m_direction": "偏轴力矩占比 %s · 平均拔力 %s",
		"m_direction_na": "键盘模式没有偏轴力矩和拔力数据，这一项不计分，权重按比例分给其他各项",
		"saved": "已保存到：%s", "save_fail": "保存失败：%s",
		"note": "评分方法见 design/评估方法_v0.5.2.md。所有阈值都是占位值，尚未经过验证。",
	},
	"en": {
		"title": "Evaluation report: Pull the Carrot",
		"diff": ["Intern", "Trainee Dentist", "Master Dentist"],
		"res_win": "Cleared", "res_broken": "Not cleared · carrot snapped", "res_timeout": "Not cleared · time up", "res_abort": "Not cleared · quit",
		"save": "Save to folder", "close": "Close",
		"total": "Overall score", "not_cleared": "Not cleared, so the grade is F",
		"chart_m": "Target-axis moment (N·m)", "chart_off": "Off-axis moment (N·m)", "chart_pull": "Pull force (N)",
		"no_sensor": "Off-axis moment and pull force: not recorded in keyboard mode; shown once a sensor is connected.",
		"lg_user": "This round", "lg_std": "Standard", "lg_zone": "Green zone", "lg_limit": "Limit", "lg_over": "Too hard", "lg_hold": "Hold done",
		"axis_t": "Time (s)",
		"dims": {"safety": "Safety", "accuracy": "Accuracy", "stability": "Stability", "rhythm": "Rhythm & symmetry", "efficiency": "Efficiency", "direction": "Direction purity"},
		"weight": "weight %d%%", "na": "n/a",
		"m_safety": "Too hard %d times · peak %.2f N·m · %.0f%% of the time above the green zone",
		"m_accuracy": "Holds off the zone centre by %.0f%% · difference from standard %.3f N·m",
		"m_stability": "Wobble while holding %.3f N·m · holds done first time %.0f%%",
		"m_rhythm": "Left/right balance %s · rock timing variation %s · same-side repeats %d",
		"m_efficiency": "Per half-rock %s · back to centre in %s",
		"m_direction": "Off-axis share %s · mean pull %s",
		"m_direction_na": "No off-axis or pull data in keyboard mode; not scored, its weight is shared by the others",
		"saved": "Saved to: %s", "save_fail": "Could not save: %s",
		"note": "Scoring method: design/评估方法_v0.5.2.md. All thresholds are placeholders, not validated values.",
	},
}

## Balloon game (Level B, v0.6.0): these keys replace the ones above.
const TEXT_BALLOON := {
	"zh": {
		"title": "评估报告：兔子的气球",
		"res_broken": "未过关 · 气球爆太多了",
		"lg_std": "标准加力线", "lg_limit": "爆裂上限", "lg_over": "爆掉", "lg_hold": "绑好", "lg_leak": "漏气",
		"dims": {"safety": "安全", "accuracy": "精准", "stability": "稳定", "ramp": "加力平稳", "efficiency": "效率", "direction": "方向纯度"},
		"m_safety": "爆掉 %d 次 · 峰值 %.2f N·m · 超过安全线 %.0f%% 的时间",
		"m_accuracy": "加力时与标准线误差 %.3f N·m · 保持时偏离目标 %.0f%%",
		"m_stability": "保持时抖动 %.3f N·m · 一次保持成功 %.0f%%",
		"m_ramp": "加力速度匹配 %s · 平稳上升 %s · 漏气 %d 次",
		"m_efficiency": "每个气球用时 %s",
		"note": "评分方法见 design/评估方法_v0.6.0.md。所有阈值都是占位值，尚未经过验证。",
	},
	"en": {
		"title": "Evaluation report: Bunny's Balloons",
		"res_broken": "Not cleared · too many balloons popped",
		"lg_std": "Standard ramp", "lg_limit": "Pop limit", "lg_over": "Popped", "lg_hold": "Tied", "lg_leak": "Leaked",
		"dims": {"safety": "Safety", "accuracy": "Accuracy", "stability": "Stability", "ramp": "Ramp control", "efficiency": "Efficiency", "direction": "Direction purity"},
		"m_safety": "Popped %d times · peak %.2f N·m · %.0f%% of the time above the safe line",
		"m_accuracy": "Difference from the standard ramp %.3f N·m · holds off target by %.0f%%",
		"m_stability": "Wobble while holding %.3f N·m · holds done first time %.0f%%",
		"m_ramp": "Rate match %s · steady rise %s · leaks %d",
		"m_efficiency": "Per balloon %s",
		"note": "Scoring method: design/评估方法_v0.6.0.md. All thresholds are placeholders, not validated values.",
	},
}

var lang := "zh"
var game := "rocking"
var data: Dictionary = {}
var rep: Dictionary = {}
var _status: Label
var _buttons: HBoxContainer
var _dialog: FileDialog


func tx(key: String):
	if game == "balloon":
		var bt: Dictionary = TEXT_BALLOON.get(lang, TEXT_BALLOON["en"])
		if bt.has(key):
			return bt[key]
	var tb: Dictionary = TEXT.get(lang, TEXT["en"])
	return tb.get(key, TEXT["en"].get(key, key))


func setup(d: Dictionary, r: Dictionary, glance: Dictionary = {}) -> void:
	data = d
	rep = r
	game = str(d.get("game", "rocking"))
	insights = glance


var _board: Control
var _clip: TextureRect


## v0.7.0 (design v2.0 §4.3): the garden behind, a board with a sheet of squared note paper clipped to it;
## Save / Close sit above the board on the right.
func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(Garden.backdrop())
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for k in ["margin_left", "margin_right"]:
		margin.add_theme_constant_override(k, 22)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 14)
	add_child(margin)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 6)
	margin.add_child(outer)
	_buttons = HBoxContainer.new()
	_buttons.add_theme_constant_override("separation", 10)
	_buttons.alignment = BoxContainer.ALIGNMENT_END
	outer.add_child(_buttons)
	var board := PanelContainer.new()
	board.add_theme_stylebox_override("panel", Garden.board_box(-14, -16))
	board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(board)
	_board = board
	var sheet := PanelContainer.new()
	sheet.add_theme_stylebox_override("panel", Garden.paper_box(16, 8))
	sheet.draw.connect(_draw_squares.bind(sheet))
	board.add_child(sheet)
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 8)
	sheet.add_child(page)
	_build_header(page)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	page.add_child(scroll)
	var body := HBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 24)
	scroll.add_child(body)
	_build_charts(body)
	_build_scores(body)
	_status = _lbl("", P.FS_SMALL, P.STEEL, true)
	page.add_child(_status)
	# metal clip holding the paper, on top of everything at the board's top edge
	_clip = TextureRect.new()
	_clip.texture = Garden.ui_texture("ui_clip.png", 0.6)
	_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_clip)
	board.resized.connect(_place_clip)
	_start_glance_animation()


func _place_clip() -> void:
	if _clip.texture == null:
		return
	var r := _board.get_global_rect()
	var w := float(_clip.texture.get_width())
	_clip.position = r.position - get_global_rect().position + Vector2(r.size.x / 2.0 - w / 2.0, -12.0)


## Light blue squares on the note paper (they are also the chart's grid feeling).
func _draw_squares(sheet: Control) -> void:
	var step := 24.0
	var inset := 16.0
	var col := Color("d7ecf7")
	var x := inset
	while x < sheet.size.x - inset:
		sheet.draw_line(Vector2(x, inset), Vector2(x, sheet.size.y - inset), col, 1.0)
		x += step
	var y := inset
	while y < sheet.size.y - inset:
		sheet.draw_line(Vector2(inset, y), Vector2(sheet.size.x - inset, y), col, 1.0)
		y += step


# ------------------------------------------------------------------ helpers
func _lbl(text: String, font_size: int, color: Color, bold := false) -> Label:
	var l := UI.label(text, font_size, color, bold)
	return l


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


func _sb(bg: Color, border: Color, bw: int, radius: int, ph: int, pv: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(bw)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = ph
	sb.content_margin_right = ph
	sb.content_margin_top = pv
	sb.content_margin_bottom = pv
	return sb


func _btn(text: String, primary: bool) -> Button:
	var b := Button.new()
	b.text = text
	Garden.style_button(b, "primary" if primary else "secondary", P.FS_BODY)
	return b


func _result_text() -> String:
	return tx("res_" + str(data.get("result", "abort")))


# ------------------------------------------------------------------ header
func _build_header(page: VBoxContainer) -> void:
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 0)
	page.add_child(left)
	left.add_child(Garden.display_label(tx("title"), P.FS_HEAD, P.INK))
	var diffs: Array = tx("diff")
	var d: int = clampi(int(data.get("difficulty", 1)), 0, 2)
	var sub := "%s，%s，%s" % [str(data.get("at", "")).substr(0, 16), diffs[d], _result_text()] if lang == "zh" \
		else "%s, %s, %s" % [str(data.get("at", "")).substr(0, 16), diffs[d], _result_text()]
	left.add_child(_lbl(sub, P.FS_SMALL, P.STEEL, true))
	var save := _btn(tx("save"), true)
	save.pressed.connect(_on_save)
	_buttons.add_child(save)
	var close := _btn(tx("close"), false)
	close.pressed.connect(func(): closed.emit())
	_buttons.add_child(close)


# ------------------------------------------------------------------ charts
func _build_charts(body: HBoxContainer) -> void:
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.size_flags_stretch_ratio = 1.8
	col.add_theme_constant_override("separation", 6)
	body.add_child(col)
	_build_glance(col)   # v0.7.2.1: cards, force band, coach's notes — the curve stays below
	col.add_child(_lbl(tx("chart_m"), P.FS_SMALL, P.STEEL))
	var p: Dictionary = data["params"]
	var ch := Chart.new()
	ch.custom_minimum_size = Vector2(0, 280)
	ch.font = UI.font(false)
	ch.t = data["t"]
	ch.y = data["m"]
	ch.ref = rep["standard"]
	ch.y_max = 0.5
	ch.limit = p["overload"]
	ch.axis_label = tx("axis_t")
	if game == "balloon":
		ch.symmetric = false
		ch.ref_gaps = true
		for e in data["events"]:
			var ev_b: String = e[1]
			if ev_b == "pop":
				ch.marks.append([float(e[0]), "over"])
			elif ev_b == "leak":
				ch.marks.append([float(e[0]), "leak"])
			elif ev_b.begins_with("tie_"):
				ch.marks.append([float(e[0]), "hold"])
	else:
		ch.symmetric = true
		ch.zone = [p["band_min"], p["band_max"]]
		for e in data["events"]:
			var ev_name: String = e[1]
			if ev_name == "overload":
				ch.marks.append([float(e[0]), "over"])
			elif ev_name.begins_with("hold_ok"):
				ch.marks.append([float(e[0]), "hold"])
	col.add_child(ch)
	col.add_child(_legend())
	if data.get("sensor", false):
		col.add_child(_lbl(tx("chart_off"), P.FS_SMALL, P.STEEL))
		var c2 := Chart.new()
		c2.custom_minimum_size = Vector2(0, 90)
		c2.font = ch.font
		c2.t = data["t"]
		c2.y = data["off"]
		c2.y_max = maxf(float(p["offaxis_limit"]) * 1.5, 0.1)
		c2.limit = p["offaxis_limit"]
		col.add_child(c2)
		col.add_child(_lbl(tx("chart_pull"), P.FS_SMALL, P.STEEL))
		var c3 := Chart.new()
		c3.custom_minimum_size = Vector2(0, 90)
		c3.font = ch.font
		c3.t = data["t"]
		c3.y = data["pull"]
		c3.y_max = maxf(float(p["pull_limit"]) * 1.5, 1.0)
		c3.limit = p["pull_limit"]
		col.add_child(c3)
	else:
		var note := _lbl(tx("no_sensor"), P.FS_SMALL, P.STEEL)
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		col.add_child(note)
	var n2 := _lbl(tx("note"), P.FS_SMALL, P.STEEL)
	n2.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(n2)


func _legend() -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	var items: Array = [["line", P.INK, tx("lg_user")], ["dash", P.SKY_DEEP, tx("lg_std")], ["box", P.TARGET_TINT, tx("lg_zone")],
			["dash", P.FAULT, tx("lg_limit")], ["dot", P.FAULT, tx("lg_over")], ["tick", P.TARGET, tx("lg_hold")]]
	if game == "balloon":
		items = [["line", P.INK, tx("lg_user")], ["dash", P.SKY_DEEP, tx("lg_std")], ["dash", P.FAULT, tx("lg_limit")],
			["dot", P.FAULT, tx("lg_over")], ["ring", P.FAULT, tx("lg_leak")], ["tick", P.TARGET, tx("lg_hold")]]
	for item in items:
		var sw := Swatch.new()
		sw.kind = item[0]
		sw.color = item[1]
		sw.custom_minimum_size = Vector2(18, 14)
		sw.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(sw)
		var l := _lbl(item[2], P.FS_SMALL, P.STEEL)
		h.add_child(l)
	return h


# ------------------------------------------------------------------ scores
func _fmt_or_na(v: float, fmt: String) -> String:
	return tx("na") if v < 0.0 else fmt % v


func _build_scores(body: HBoxContainer) -> void:
	var col := VBoxContainer.new()
	col.custom_minimum_size = Vector2(320, 0)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 6)
	body.add_child(col)
	# grade
	var gh := HBoxContainer.new()
	gh.add_theme_constant_override("separation", 16)
	col.add_child(gh)
	var passed: bool = rep["passed"]
	gh.add_child(Garden.stamp(str(rep["grade"]), passed, 84))
	var gv := VBoxContainer.new()
	gv.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	gh.add_child(gv)
	gv.add_child(_lbl(tx("total"), P.FS_SMALL, P.STEEL))
	gv.add_child(_lbl("%.1f / 100" % float(rep["total"]), P.FS_HEAD, P.INK, true))
	if not passed:
		gv.add_child(_lbl(tx("not_cleared"), P.FS_SMALL, P.TOMATO_TEXT, true))
	col.add_child(_hrule())
	var mt: Dictionary = rep["metrics"]
	var lines: Dictionary
	if game == "balloon":
		lines = _balloon_lines(mt)
	else:
		lines = _carrot_lines(mt)
	if not data.get("sensor", false):
		lines["direction"] = tx("m_direction_na")
	_score_rows(col, lines)


func _balloon_lines(mt: Dictionary) -> Dictionary:
	return {
		"safety": tx("m_safety") % [int(mt["pops"]), float(mt["peak_nm"]), float(mt["time_over_safe_pct"])],
		"accuracy": tx("m_accuracy") % [float(mt["track_rmse_nm"]), float(mt["hold_deviation_pct"])],
		"stability": tx("m_stability") % [float(mt["hold_sd_nm"]), float(mt["first_try_pct"])],
		"ramp": tx("m_ramp") % [_fmt_or_na(float(mt["rate_match_pct"]), "%.0f%%"), _fmt_or_na(float(mt["smooth_pct"]), "%.0f%%"), int(mt["leaks"])],
		"efficiency": tx("m_efficiency") % _fmt_or_na(float(mt["time_per_balloon_s"]), "%.1f s"),
		"direction": tx("m_direction") % [_fmt_or_na(float(mt["offaxis_ratio_pct"]), "%.0f%%"), _fmt_or_na(float(mt["pull_mean_n"]), "%.1f N")],
	}


func _carrot_lines(mt: Dictionary) -> Dictionary:
	return {
		"safety": tx("m_safety") % [int(mt["overloads"]), float(mt["peak_nm"]), float(mt["time_over_band_pct"])],
		"accuracy": tx("m_accuracy") % [float(mt["hold_deviation_pct"]), float(mt["rmse_nm"])],
		"stability": tx("m_stability") % [float(mt["hold_sd_nm"]), float(mt["first_try_pct"])],
		"rhythm": tx("m_rhythm") % [_fmt_or_na(float(mt["symmetry_pct"]), "%.0f%%"), _fmt_or_na(float(mt["rock_period_cv_pct"]), "%.0f%%"), int(mt["same_side_repeats"])],
		"efficiency": tx("m_efficiency") % [_fmt_or_na(float(mt["time_per_half_s"]), "%.1f s"), _fmt_or_na(float(mt["return_time_s"]), "%.2f s")],
		"direction": tx("m_direction") % [_fmt_or_na(float(mt["offaxis_ratio_pct"]), "%.0f%%"), _fmt_or_na(float(mt["pull_mean_n"]), "%.1f N")],
	}


func _score_rows(col: VBoxContainer, lines: Dictionary) -> void:
	var dims: Dictionary = rep["dims"]
	var names: Dictionary = tx("dims")
	for k in rep["order"]:
		var row := VBoxContainer.new()
		row.add_theme_constant_override("separation", 2)
		col.add_child(row)
		var h := HBoxContainer.new()
		row.add_child(h)
		var nm := _lbl(names[k], P.FS_BODY, P.INK, true)
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(nm)
		h.add_child(_lbl(tx("weight") % int(rep["weights"][k]), P.FS_SMALL, P.STEEL))
		var val = dims[k]
		var vl := _lbl(tx("na") if val == null else "%.0f" % float(val), P.FS_BODY, P.SLATE if val != null else P.STEEL, true)
		vl.custom_minimum_size = Vector2(44, 0)
		vl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		h.add_child(vl)
		var bar := ProgressBar.new()
		bar.max_value = 100
		bar.value = 0.0 if val == null else float(val)
		Garden.style_bar(bar, P.SOIL, 10)   # scores are not states, so soil brown
		row.add_child(bar)
		var ml := _lbl(lines[k], P.FS_SMALL, P.STEEL)
		ml.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.add_child(ml)
		col.add_child(_hrule())


# ------------------------------------------------------------------ save
func _on_save() -> void:
	if _dialog == null:
		_dialog = FileDialog.new()
		_dialog.file_mode = FileDialog.FILE_MODE_OPEN_DIR
		_dialog.access = FileDialog.ACCESS_FILESYSTEM
		_dialog.use_native_dialog = true
		_dialog.title = tx("save")
		_dialog.dir_selected.connect(_save_to)
		add_child(_dialog)
	_dialog.popup_centered_ratio(0.6)


func _save_to(dir: String) -> void:
	# picture of the report, with the buttons and status line hidden while capturing
	_buttons.visible = false
	_status.text = ""
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	_buttons.visible = true
	save_requested.emit(dir, img)


## Called by the presenter after writing the files ("" = failed).
func show_saved(base: String, dir: String) -> void:
	_status.text = (tx("saved") % base + "（.png / _scores.csv / _samples.csv）") if base != "" else tx("save_fail") % dir


# ------------------------------------------------------------------ chart widget
## Line chart: player's curve (SLATE), standard curve (STEEL, dashed), green zone (TARGET_TINT, light),
## limit lines (FAULT, dashed), event marks. Light hairline axes only.
# ================================================================== at a glance (v0.7.2.1)
## Words for the "at a glance" part. %d / %.1f / %.3f are filled from the insight numbers.
const GLANCE_TEXT := {
	"zh": {
		"glance": "本局一览", "band_title": "力度色带：整局每一刻的状态", "tips_title": "教练点评", "detail": "详细曲线",
		"card_b": "第 %d 个", "card_c": "第 %d 次",
		"res_b_clean": "一次绑好 ✓", "res_b_tied": "绑好了", "res_b_popped": "爆了 ✗", "res_b_unfinished": "没吹完", "res_b_none": "没开始",
		"res_c_clean": "两边都稳 ✓", "res_c_tied": "保持 %d / %d", "res_c_popped": "用力过猛 ✗", "res_c_unfinished": "没保持住", "res_c_none": "没开始",
		"sub_leaks": "漏气 %d", "sub_pops": "爆 %d", "sub_drops": "掉出 %d",
		"speed": ["慢", "准", "快"], "speed_label": "加力", "stars_label": "稳定",
		"st_b": {"target": "在目标区", "work": "加力中", "fast": "太快", "over": "超过安全线", "rest": "放松"},
		"st_c": {"target": "在绿区", "work": "推进中", "fast": "超过绿区", "over": "用力过猛", "rest": "回中"},
		"good": "做得好", "fix": "可以改进",
		"tip_b_pop": "第 %d 个气球用力过猛，爆了。接近目标时放慢，看到气球发亮就别再加力。",
		"tip_b_leak": "第 %d 个气球开始加力 %.1f 秒时就比标准线快太多，漏气了。开头再慢一点，跟着虚线圈走。",
		"tip_b_slow": "第 %d 个气球加力偏慢，落在虚线圈后面，可以再跟紧一些。",
		"tip_hold_low": "保持时平均比目标低 %.3f N·m，可以再稍微用点力。",
		"tip_hold_high": "保持时平均比目标高 %.3f N·m，可以稍微松一点。",
		"tip_drop": "保持中途掉出目标带 %d 次。保持时手腕放稳，不要来回调。",
		"tip_b_good_clean": "一共 %d 个气球，%d 个一次就绑好了。",
		"tip_b_good_tied": "这一局绑好了 %d 个气球。",
		"tip_good_try": "每练一次都会更稳，再来一局吧。",
		"tip_all_good": "这一局没有发现需要改的地方，保持这个节奏。",
		"tip_c_over": "第 %d 次摆动用力过猛。推进绿区后就停住，不要继续加力。",
		"tip_c_alternate": "有 %d 次没有左右交替。每次回到中间后记得换另一边。",
		"tip_c_side_left": "左边平均比右边少用力 %.3f N·m，左右要一样稳。",
		"tip_c_side_right": "右边平均比左边少用力 %.3f N·m，左右要一样稳。",
		"tip_c_hold": "有 %d 次推进没能在绿区保持住。进入绿区后稳住 0.5 秒再回中。",
		"tip_c_good_holds": "一共推进 %d 次，%d 次成功保持住。",
		"side_L": "左", "side_R": "右",
	},
	"en": {
		"glance": "This round at a glance", "band_title": "Force band: the state at every moment of the round", "tips_title": "Coach's notes", "detail": "Detailed curve",
		"card_b": "Balloon %d", "card_c": "Rock %d",
		"res_b_clean": "First time ✓", "res_b_tied": "Tied", "res_b_popped": "Popped ✗", "res_b_unfinished": "Not finished", "res_b_none": "Not started",
		"res_c_clean": "Both sides ✓", "res_c_tied": "Held %d / %d", "res_c_popped": "Too hard ✗", "res_c_unfinished": "Not held", "res_c_none": "Not started",
		"sub_leaks": "leaked %d", "sub_pops": "popped %d", "sub_drops": "slipped %d",
		"speed": ["Slow", "Right", "Fast"], "speed_label": "Ramp", "stars_label": "Steady",
		"st_b": {"target": "On target", "work": "Building up", "fast": "Too fast", "over": "Above safe line", "rest": "Relaxed"},
		"st_c": {"target": "In green zone", "work": "Pushing", "fast": "Past green zone", "over": "Too hard", "rest": "At centre"},
		"good": "Well done", "fix": "To improve",
		"tip_b_pop": "Balloon %d popped: too much force. Slow down near the target and stop pushing when the balloon starts to shine.",
		"tip_b_leak": "Balloon %d leaked %.1f s into the ramp: you got ahead of the standard ramp. Start slower and follow the dashed ring.",
		"tip_b_slow": "Balloon %d was built up too slowly and fell behind the ring. Keep up with it a little more.",
		"tip_hold_low": "While holding you were %.3f N·m below the target on average. Push a little more.",
		"tip_hold_high": "While holding you were %.3f N·m above the target on average. Ease off a little.",
		"tip_drop": "You slipped out of the target band %d times while holding. Keep your wrist still instead of correcting back and forth.",
		"tip_b_good_clean": "Of %d balloons, %d were tied first time.",
		"tip_b_good_tied": "You tied %d balloons this round.",
		"tip_good_try": "Every round makes you steadier. Have another go.",
		"tip_all_good": "Nothing to fix this round. Keep this rhythm.",
		"tip_c_over": "Rock %d: too much force. Once you are in the green zone, stop pushing.",
		"tip_c_alternate": "%d times you pushed the same side twice. Switch sides after each return to centre.",
		"tip_c_side_left": "Your left pushes were %.3f N·m weaker than your right. Aim for the same on both sides.",
		"tip_c_side_right": "Your right pushes were %.3f N·m weaker than your left. Aim for the same on both sides.",
		"tip_c_hold": "%d pushes were not held in the green zone. Hold for 0.5 s before returning to centre.",
		"tip_c_good_holds": "Of %d pushes, %d were held.",
		"side_L": "L", "side_R": "R",
	},
}
const BALLOON_COLOURS := ["pink", "yellow", "blue", "purple", "green"]
const STATE_ORDER := ["target", "work", "fast", "over", "rest"]
const STATE_COLOURS := {"target": Color("5fb52a"), "work": Color("ffc531"), "fast": Color("ff7f1f"),
	"over": Color("e8442e"), "rest": Color("eadfc8")}

var insights: Dictionary = {}
var _pop_items: Array = []     # [Control, delay] — cards and tips pop in
var _band: StateBand = null


func gx(key: String):
	var tb: Dictionary = GLANCE_TEXT.get(lang, GLANCE_TEXT["en"])
	return tb.get(key, GLANCE_TEXT["en"].get(key, key))


func _section_title(text: String) -> Label:
	return Garden.display_label(text, P.FS_LABEL, P.INK)


## Cards, force band and coach's notes, above the detailed curve.
func _build_glance(col: VBoxContainer) -> void:
	if insights.is_empty() or (insights.get("cards", []) as Array).is_empty():
		return
	var balloon := str(insights.get("game", "")) == "balloon"
	col.add_child(_section_title(gx("glance")))

	# ---- 1. one card per balloon / per full rock
	var cards_row := HBoxContainer.new()
	cards_row.add_theme_constant_override("separation", 8)
	col.add_child(cards_row)
	var k := 0
	for c in insights["cards"]:
		var card := _card(c, balloon)
		cards_row.add_child(card)
		_pop_items.append([card, 0.15 + 0.09 * k])
		k += 1

	# ---- 2. force band and time shares
	col.add_child(_lbl(gx("band_title"), P.FS_SMALL, P.STEEL, true))
	_band = StateBand.new()
	_band.custom_minimum_size = Vector2(0, 26)
	_band.runs = insights["band"]
	_band.duration = float(insights["duration"])
	_band.colours = STATE_COLOURS
	_band.reveal = 0.0
	col.add_child(_band)
	var legend := HFlowContainer.new()
	legend.add_theme_constant_override("h_separation", 14)
	legend.add_theme_constant_override("v_separation", 2)
	col.add_child(legend)
	var names: Dictionary = gx("st_b" if balloon else "st_c")
	var shares: Dictionary = insights["shares"]
	for s in STATE_ORDER:
		var item := HBoxContainer.new()
		item.add_theme_constant_override("separation", 5)
		var sw := ColorRect.new()
		sw.color = STATE_COLOURS[s]
		sw.custom_minimum_size = Vector2(14, 14)
		sw.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		item.add_child(sw)
		item.add_child(_lbl("%s %d%%" % [names[s], roundi(float(shares.get(s, 0.0)))], P.FS_SMALL, P.INK, s == "target"))
		legend.add_child(item)
	_pop_items.append([legend, 0.15 + 0.09 * k + 0.75])

	# ---- 3. coach's notes
	col.add_child(_section_title(gx("tips_title")))
	var j := 0
	for tip in insights["tips"]:
		var row := _tip_row(tip)
		col.add_child(row)
		_pop_items.append([row, 0.15 + 0.09 * k + 0.95 + 0.18 * j])
		j += 1
	col.add_child(_section_title(gx("detail")))


func _card(c: Dictionary, balloon: bool) -> Control:
	var res: String = c["result"]
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", Garden.plate_box(6, 6, P.SURFACE if res != "none" else Color("efe5d2")))
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 1)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	card.add_child(v)
	var icon_path := "res://assets/carrot_game/ui_life_on.png"
	if balloon:
		icon_path = "res://assets/balloon_game/ui_slot_%s.png" % BALLOON_COLOURS[int(c["index"]) % 5]
	if ResourceLoader.exists(icon_path):
		var ic := TextureRect.new()
		ic.texture = load(icon_path)
		ic.custom_minimum_size = Vector2(0, 34)
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.modulate = Color(1, 1, 1, 1.0 if res != "none" else 0.35)
		v.add_child(ic)
	var head: String = (gx("card_b") if balloon else gx("card_c")) % (int(c["index"]) + 1)
	if not balloon and (c["sides"] as Array).size() > 0:
		var sides: Array = []
		for sd in c["sides"]:
			sides.append(gx("side_" + str(sd)))
		head += " " + "→".join(PackedStringArray(sides))
	v.add_child(_centered(_lbl(head, P.FS_SMALL, P.STEEL, true)))
	# result line: green = done cleanly, red = popped / too hard, ink = done with slips, soil = not done
	var prefix := "res_b_" if balloon else "res_c_"
	var res_text: String = gx(prefix + res)
	if not balloon and res == "tied":
		res_text = res_text % [int(c["held"]), int(c["halves"])]
	var res_col: Color = {"clean": P.LEAF_TEXT, "tied": P.INK, "popped": P.TOMATO_TEXT}.get(res, P.STEEL)
	v.add_child(_centered(_lbl(res_text, P.FS_SMALL, res_col, true)))
	var subs: Array = []
	if int(c.get("leaks", 0)) > 0:
		subs.append(gx("sub_leaks") % int(c["leaks"]))
	if balloon and int(c.get("pops", 0)) > 0 and res != "popped":
		subs.append(gx("sub_pops") % int(c["pops"]))
	if int(c.get("drops", 0)) > 0:
		subs.append(gx("sub_drops") % int(c["drops"]))
	v.add_child(_centered(_lbl(" · ".join(PackedStringArray(subs)) if not subs.is_empty() else " ", 11, P.STEEL)))
	if balloon:
		var sm := SpeedMeter.new()
		sm.labels = gx("speed")
		sm.font = UI.font(true)
		sm.speed = str(c.get("speed", ""))
		sm.custom_minimum_size = Vector2(84, 16)
		sm.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		v.add_child(sm)
	var st := StarRow.new()
	st.count = int(c.get("stars", 0))
	st.custom_minimum_size = Vector2(54, 16)
	st.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(st)
	return card


func _centered(l: Label) -> Label:
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


func _tip_row(tip: Dictionary) -> Control:
	var good: bool = tip["kind"] == "good"
	var row := PanelContainer.new()
	row.add_theme_stylebox_override("panel", Garden.plate_box(10, 6, P.SURFACE))
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	row.add_child(h)
	var badge := PanelContainer.new()
	badge.add_theme_stylebox_override("panel", Garden.flat(P.LEAF_TINT if good else Color("ffd7b3"), P.INK, P.LINE, 999, 8, 1))
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	badge.add_child(_lbl(gx("good" if good else "fix"), P.FS_SMALL, P.INK, true))
	h.add_child(badge)
	var fmt: String = gx(str(tip["key"]))
	var args: Array = tip.get("args", [])
	var text := fmt % args if not args.is_empty() else fmt
	var l := _lbl(text, P.FS_BODY, P.INK)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(l)
	return row


## Cards and notes pop in one after another, the band fills from left to right (once, when the report opens).
func _start_glance_animation() -> void:
	await get_tree().process_frame
	for it in _pop_items:
		var c: Control = it[0]
		if not is_instance_valid(c):
			continue
		c.pivot_offset = c.size / 2.0
		c.scale = Vector2(0.6, 0.6)
		c.modulate.a = 0.0
		var tw := c.create_tween()
		tw.tween_interval(float(it[1]))
		tw.tween_property(c, "modulate:a", 1.0, 0.12)
		tw.parallel().tween_property(c, "scale", Vector2(1.06, 1.06), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(c, "scale", Vector2.ONE, 0.1)
	if _band != null:
		var cards_n := (insights.get("cards", []) as Array).size()
		var tb := _band.create_tween()
		tb.tween_interval(0.15 + 0.09 * cards_n + 0.1)
		tb.tween_property(_band, "reveal", 1.0, 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


## Strip of states over the round, drawn up to `reveal` (0–1) for the opening animation.
class StateBand extends Control:
	var runs: Array = []
	var duration := 1.0
	var colours: Dictionary = {}
	var reveal := 1.0:
		set(v):
			reveal = v
			queue_redraw()

	func _draw() -> void:
		var r := Rect2(Vector2(1, 1), size - Vector2(2, 2))
		var bg := StyleBoxFlat.new()
		bg.bg_color = Color("fffdf7")
		bg.set_corner_radius_all(int(r.size.y / 2.0))
		draw_style_box(bg, r)
		var limit := r.position.x + r.size.x * clampf(reveal, 0.0, 1.0)
		var inner := r.grow(-2.0)
		for run in runs:
			var x0: float = inner.position.x + inner.size.x * float(run[0]) / maxf(duration, 0.001)
			var x1: float = inner.position.x + inner.size.x * float(run[1]) / maxf(duration, 0.001)
			x1 = minf(x1, limit)
			if x1 <= x0:
				continue
			draw_rect(Rect2(x0, inner.position.y, maxf(x1 - x0, 1.0), inner.size.y), colours.get(run[2], Color.GRAY))
		var frame := StyleBoxFlat.new()
		frame.draw_center = false
		frame.border_color = Color("5e3410")
		frame.set_border_width_all(2)
		frame.set_corner_radius_all(int(r.size.y / 2.0))
		frame.anti_aliasing = true
		draw_style_box(frame, r)


## Three cells Slow / Right / Fast; the one that applies is filled (green for Right, carrot for the others).
class SpeedMeter extends Control:
	var labels: Array = ["慢", "准", "快"]
	var speed := ""
	var font: Font

	func _draw() -> void:
		var keys := ["slow", "ok", "fast"]
		var w := size.x / 3.0
		for i in 3:
			var cell := Rect2(i * w + 1, 1, w - 2, size.y - 2)
			var on: bool = keys[i] == speed
			var fill: Color = (Color("5fb52a") if keys[i] == "ok" else Color("ff7f1f")) if on else Color("fffdf7")
			var sb := StyleBoxFlat.new()
			sb.bg_color = fill
			sb.border_color = Color("5e3410")
			sb.set_border_width_all(1)
			sb.set_corner_radius_all(4)
			draw_style_box(sb, cell)
			if font != null:
				var fs := 11
				var txt: String = labels[i]
				var tw := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
				draw_string(font, Vector2(cell.position.x + (cell.size.x - tw) / 2.0, cell.position.y + cell.size.y / 2.0 + 4.0),
					txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color("5e3410") if not on or keys[i] != "ok" else Color.WHITE)


## Hold steadiness: three stars, `count` of them filled.
class StarRow extends Control:
	var count := 0

	func _draw() -> void:
		var r := minf(size.y / 2.0 - 1.0, size.x / 6.0 - 1.0)
		for i in 3:
			var c := Vector2(size.x / 6.0 * (2 * i + 1), size.y / 2.0 + 1.0)
			var pts := PackedVector2Array()
			for k in 10:
				var ang := -PI / 2.0 + k * PI / 5.0
				var rr := r if k % 2 == 0 else r * 0.45
				pts.append(c + Vector2(cos(ang), sin(ang)) * rr)
			if i < count:
				draw_colored_polygon(pts, Color("ff7f1f"))
			pts.append(pts[0])
			draw_polyline(pts, Color("5e3410"), 1.5, true)


class Chart extends Control:
	var t := PackedFloat32Array()
	var y := PackedFloat32Array()
	var ref := PackedFloat32Array()
	var y_max := 0.5
	var symmetric := false
	var zone: Array = []
	var limit := -1.0
	var marks: Array = []
	var ref_gaps := false   # balloon game: draw the standard only while a balloon is being inflated (ref > 0)
	var font: Font
	var axis_label := ""

	func _draw() -> void:
		var r := Rect2(Vector2(36, 4), size - Vector2(44, 24))
		var frame := StyleBoxFlat.new()   # v0.7.0: white chart card with an ink outline
		frame.bg_color = P.SURFACE
		frame.border_color = P.INK
		frame.set_border_width_all(2)
		frame.set_corner_radius_all(10)
		draw_style_box(frame, Rect2(Vector2.ZERO, size))
		if t.size() < 2:
			return
		var t_end: float = maxf(t[t.size() - 1], 1.0)
		var y_min := -y_max if symmetric else 0.0
		var to_px := func(tt: float, yy: float) -> Vector2:
			return Vector2(r.position.x + r.size.x * tt / t_end,
				r.position.y + r.size.y * (1.0 - (clampf(yy, y_min, y_max) - y_min) / (y_max - y_min)))
		# green zone
		if zone.size() == 2:
			for s in ([1.0, -1.0] if symmetric else [1.0]):
				var a: Vector2 = to_px.call(0.0, s * zone[1])
				var b: Vector2 = to_px.call(t_end, s * zone[0])
				var top := minf(a.y, b.y)
				draw_rect(Rect2(r.position.x, top, r.size.x, absf(b.y - a.y)), Color(P.TARGET_TINT, 0.25))
		# zero line and limits
		if symmetric:
			var z: Vector2 = to_px.call(0.0, 0.0)
			draw_line(Vector2(r.position.x, z.y), Vector2(r.end.x, z.y), P.RULE, 1.0)
		if limit > 0.0:
			for s in ([1.0, -1.0] if symmetric else [1.0]):
				var ly: float = to_px.call(0.0, s * limit).y
				draw_dashed_line(Vector2(r.position.x, ly), Vector2(r.end.x, ly), P.FAULT, 2.0, 6.0)
		# time ticks
		var step := 5.0 if t_end > 20.0 else 2.0
		if t_end > 60.0:
			step = 10.0
		var tick := 0.0
		while tick <= t_end + 0.001:
			var x: float = to_px.call(tick, 0.0).x
			draw_line(Vector2(x, r.end.y), Vector2(x, r.end.y + 4), P.STEEL, 1.0)
			if font:
				draw_string(font, Vector2(x - 8, r.end.y + 16), "%d" % int(tick), HORIZONTAL_ALIGNMENT_LEFT, -1, P.FS_SMALL - 2, P.STEEL)
			tick += step
		if font:
			draw_string(font, Vector2(2, r.position.y + 10), "%+.1f" % y_max if symmetric else ("%.1f" % y_max if y_max < 10.0 else "%.0f" % y_max), HORIZONTAL_ALIGNMENT_LEFT, -1, P.FS_SMALL - 2, P.STEEL)
			if symmetric:
				draw_string(font, Vector2(2, r.end.y), "%+.1f" % -y_max, HORIZONTAL_ALIGNMENT_LEFT, -1, P.FS_SMALL - 2, P.STEEL)
		# standard (dashed) and player (solid)
		if ref.size() == t.size():
			var prev: Vector2 = to_px.call(t[0], ref[0])
			for i in range(1, t.size()):
				var cur: Vector2 = to_px.call(t[i], ref[i])
				if i % 2 == 0 and not (ref_gaps and (ref[i] <= 0.0 or ref[i - 1] <= 0.0)):
					draw_line(prev, cur, P.SKY_DEEP, 2.0)
				prev = cur
		var pts := PackedVector2Array()
		for i in t.size():
			pts.append(to_px.call(t[i], y[i]))
		draw_polyline(pts, P.INK, 2.5, true)
		# events
		for mk in marks:
			var idx := t.bsearch(float(mk[0]))
			idx = clampi(idx, 0, t.size() - 1)
			var pos: Vector2 = to_px.call(float(mk[0]), y[idx])
			if mk[1] == "over":
				draw_circle(pos, 5.0, P.FAULT)
			elif mk[1] == "leak":
				draw_arc(pos, 5.0, 0.0, TAU, 16, P.FAULT, 1.5, true)
			else:
				draw_line(pos + Vector2(0, -7), pos + Vector2(0, 7), P.TARGET, 2.0)


class Swatch extends Control:
	var kind := "line"
	var color := Color.BLACK

	func _draw() -> void:
		var mid := size.y / 2.0
		match kind:
			"line":
				draw_line(Vector2(0, mid), Vector2(size.x, mid), color, 2.0)
			"dash":
				draw_dashed_line(Vector2(0, mid), Vector2(size.x, mid), color, 1.5, 4.0)
			"box":
				draw_rect(Rect2(0, 2, size.x, size.y - 4), Color(color, 0.45))
			"dot":
				draw_circle(Vector2(size.x / 2.0, mid), 4.0, color)
			"ring":
				draw_arc(Vector2(size.x / 2.0, mid), 4.0, 0.0, TAU, 16, color, 1.5, true)
			"tick":
				draw_line(Vector2(size.x / 2.0, 1), Vector2(size.x / 2.0, size.y - 1), color, 2.0)
