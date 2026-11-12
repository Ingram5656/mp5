extends Control
## MP5 entry test: sensor connection -> instructions -> three locks (direction, force, moment)
## -> success message. Works with the simulated sensor until the USB acquisition layer exists.
## Target ranges below are PLACEHOLDERS for the prototype, not validated or clinical values.

const DirectionGauge := preload("res://entry_test/scripts/direction_gauge.gd")
const ForceGauge := preload("res://entry_test/scripts/force_gauge.gd")
const MomentGauge := preload("res://entry_test/scripts/moment_gauge.gd")
const SimSensor := preload("res://entry_test/scripts/sim_sensor.gd")

# --- placeholder targets ---
const DIR_TARGET := 45.0
const DIR_TOL := 15.0
const FORCE_MIN := 8.0
const FORCE_MAX := 12.0
const MOMENT_MIN := 0.15
const MOMENT_MAX := 0.25
const HOLD_TIME := 1.0

# --- palette ---
const C_BG := Color("f4f5f7")
const C_CARD := Color.WHITE
const C_BORDER := Color("dfe2e6")
const C_TEXT := Color("1f2328")
const C_MUTED := Color("6b7280")
const C_ACCENT := Color("2f6fed")
const C_OK := Color("1f9d4c")
const C_WARN := Color("c2410c")
const C_GREY_DOT := Color("9aa1a9")

enum State { CONNECT, TEST, DONE }
var state: State = State.CONNECT

var sensor: Node
var status_dot: Panel
var status_label: Label
var connect_page: Control
var test_page: Control
var source_select: OptionButton
var conn_status: Label
var connect_btn: Button
var continue_btn: Button
var modal_layer: Control = null

var gauges: Array = []          # [direction, force, moment]
var readouts: Array = []        # Label per gauge
var lock_labels: Array = []     # Label per gauge
var hold_bars: Array = []       # ProgressBar per gauge
var cards: Array = []           # PanelContainer per gauge
var hold := [0.0, 0.0, 0.0]
var unlocked := [false, false, false]


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sensor = SimSensor.new()
	add_child(sensor)
	_build_ui()
	_set_sensor_status("Sensor: not connected", C_GREY_DOT)


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


func _card() -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _style(C_CARD))
	return p


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
	root.add_child(header)
	var titles := VBoxContainer.new()
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titles.add_theme_constant_override("separation", 2)
	titles.add_child(_label("Dental Extraction Trainer", 26))
	titles.add_child(_label("Entry test · sensor check", 15, C_MUTED))
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

	# pages
	var pages := Control.new()
	pages.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(pages)
	connect_page = _build_connect_page()
	pages.add_child(connect_page)
	test_page = _build_test_page()
	test_page.visible = false
	pages.add_child(test_page)


func _build_connect_page() -> Control:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var card := _card()
	card.custom_minimum_size = Vector2(460, 0)
	center.add_child(card)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	card.add_child(v)
	v.add_child(_label("Sensor connection", 20))
	var note := _label("Connect the six-axis force/torque sensor before starting.", 14, C_MUTED)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(note)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 10)
	v.add_child(grid)

	grid.add_child(_label("Input", 15, C_MUTED))
	source_select = OptionButton.new()
	source_select.add_item("Simulated sensor (keyboard)")
	source_select.add_item("USB six-axis sensor")
	source_select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	source_select.add_theme_font_size_override("font_size", 15)
	grid.add_child(source_select)

	grid.add_child(_label("Status", 15, C_MUTED))
	conn_status = _label("Not connected", 15)
	grid.add_child(conn_status)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_END
	buttons.add_theme_constant_override("separation", 10)
	connect_btn = _button("Connect", false)
	connect_btn.pressed.connect(_on_connect)
	continue_btn = _button("Continue")
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

	var titles := ["Direction", "Force", "Moment"]
	var targets := [
		"Target %d–%d°" % [int(DIR_TARGET - DIR_TOL), int(DIR_TARGET + DIR_TOL)],
		"Target %.0f–%.0f N" % [FORCE_MIN, FORCE_MAX],
		"Target %.2f–%.2f N·m" % [MOMENT_MIN, MOMENT_MAX],
	]
	for i in range(3):
		var card := _card()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cards.append(card)
		row.add_child(card)
		var cv := VBoxContainer.new()
		cv.add_theme_constant_override("separation", 10)
		card.add_child(cv)
		var t := _label(titles[i], 22)
		t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cv.add_child(t)
		var g: Control = gauges[i]
		g.size_flags_vertical = Control.SIZE_EXPAND_FILL
		cv.add_child(g)
		var ro := _label("–", 18)
		ro.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		readouts.append(ro)
		cv.add_child(ro)
		var tg := _label(targets[i], 13, C_MUTED)
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
		fill_sb.bg_color = Color("34c759")
		fill_sb.set_corner_radius_all(4)
		bar.add_theme_stylebox_override("background", bg_sb)
		bar.add_theme_stylebox_override("fill", fill_sb)
		hold_bars.append(bar)
		cv.add_child(bar)
		var lk := _label("Locked", 15, C_MUTED)
		lk.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lock_labels.append(lk)
		cv.add_child(lk)

	var footer := HBoxContainer.new()
	v.add_child(footer)
	var hint := _label("Simulation keys:   Left / Right = direction    Up / Down = force    Q / E = moment", 13, C_MUTED)
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	footer.add_child(hint)
	var help := _button("How it works", false)
	help.pressed.connect(_show_instructions)
	footer.add_child(help)
	return v


# ------------------------------------------------------------------ status
func _set_sensor_status(text: String, color: Color) -> void:
	status_label.text = text
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(6)
	status_dot.add_theme_stylebox_override("panel", sb)


# ------------------------------------------------------------------ connect page
func _on_connect() -> void:
	connect_btn.disabled = true
	continue_btn.disabled = true
	if source_select.selected == 1:
		conn_status.text = "USB driver not installed yet"
		conn_status.add_theme_color_override("font_color", C_WARN)
		_set_sensor_status("Sensor: not available", C_WARN)
		connect_btn.disabled = false
		return
	conn_status.text = "Connecting…"
	conn_status.add_theme_color_override("font_color", C_TEXT)
	_set_sensor_status("Sensor: connecting…", Color("f5a524"))
	await get_tree().create_timer(0.8).timeout
	if sensor.connect_sensor():
		conn_status.text = "Connected (simulated data)"
		conn_status.add_theme_color_override("font_color", C_OK)
		_set_sensor_status("Sensor: connected (simulated)", Color("34c759"))
		continue_btn.disabled = false
	connect_btn.disabled = false


func _on_continue() -> void:
	connect_page.visible = false
	test_page.visible = true
	state = State.TEST
	_show_instructions()


# ------------------------------------------------------------------ modal
func _show_modal(title: String, body: String, button_text: String, on_close: Callable = Callable()) -> void:
	_close_modal()
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
	v.add_child(_label(title, 22))
	var b := _label(body, 15, Color("374151"))
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.custom_minimum_size = Vector2(452, 0)
	v.add_child(b)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	v.add_child(row)
	var btn := _button(button_text)
	btn.pressed.connect(func():
		_close_modal()
		if on_close.is_valid():
			on_close.call())
	row.add_child(btn)
	btn.grab_focus.call_deferred()


func _close_modal() -> void:
	if modal_layer != null:
		modal_layer.queue_free()
		modal_layer = null


func _show_instructions() -> void:
	_show_modal(
		"How it works",
		"1.  Hold the forceps on the model tooth as demonstrated.\n" +
		"2.  Watch the three displays: Direction, Force and Moment.\n" +
		"3.  Bring each pointer into its green zone and hold it there for 1 second to open that lock.\n" +
		"4.  Open all three locks to finish the check.\n\n" +
		"The tooth is fixed. On-screen movement is feedback only.",
		"Start")


# ------------------------------------------------------------------ test loop
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
		_show_modal(
			"Connection successful",
			"Welcome to the Dental Extraction Trainer.",
			"OK")


func _unlock(i: int) -> void:
	unlocked[i] = true
	gauges[i].unlocked = true
	lock_labels[i].text = "Unlocked"
	lock_labels[i].add_theme_color_override("font_color", C_OK)
	cards[i].add_theme_stylebox_override("panel", _style(C_CARD, Color("34c759"), 12, 2))
