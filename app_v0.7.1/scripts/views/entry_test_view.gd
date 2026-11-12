extends VBoxContainer
## View — entry test page, three gauges with readouts, hold bars and lock labels (v0.5.4; v0.7.0: three paper plates
## on a wooden board). The presenter passes the sample and each lock's progress every frame.

signal help_pressed

const P := preload("res://app_v0.7.1/scripts/views/palette.gd")
const DirectionGauge := preload("res://app_v0.7.1/scripts/views/direction_gauge.gd")
const ForceGauge := preload("res://app_v0.7.1/scripts/views/force_gauge.gd")
const MomentGauge := preload("res://app_v0.7.1/scripts/views/moment_gauge.gd")

var kit
var gauges: Array = []
var readouts: Array = []
var lock_labels: Array = []
var hold_bars: Array = []
var _unlocked := [false, false, false]


## targets: {dir_target, dir_tol, force_min, force_max, moment_min, moment_max, hold_time}
func build(k, targets: Dictionary) -> void:
	kit = k
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_theme_constant_override("separation", 14)

	# v0.7.0: one board on two posts; three paper plates on it; the key hint and help button at its foot
	var bf = kit.board(true, 6, 0)
	bf.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(bf)
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 10)
	bf.content.add_child(inner)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inner.add_child(row)

	var g_dir := DirectionGauge.new()
	g_dir.target_deg = targets["dir_target"]
	g_dir.tolerance_deg = targets["dir_tol"]
	var g_force := ForceGauge.new()
	g_force.target_min = targets["force_min"]
	g_force.target_max = targets["force_max"]
	var g_mom := MomentGauge.new()
	g_mom.target_min = targets["moment_min"]
	g_mom.target_max = targets["moment_max"]
	gauges = [g_dir, g_force, g_mom]

	var title_keys := ["g_direction", "g_force", "g_moment"]
	var target_keys := ["tgt_dir", "tgt_force", "tgt_mom"]
	var target_args := [
		[int(targets["dir_target"] - targets["dir_tol"]), int(targets["dir_target"] + targets["dir_tol"])],
		[targets["force_min"], targets["force_max"]],
		[targets["moment_min"], targets["moment_max"]],
	]
	for i in range(3):
		var col_margin: PanelContainer = kit.plate(14, 8)
		col_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(col_margin)
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 2)
		col_margin.add_child(col)

		var tl: Label = kit.tdisplay(title_keys[i], P.FS_TITLE, P.INK)
		tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(tl)
		var g: Control = gauges[i]
		g.size_flags_vertical = Control.SIZE_EXPAND_FILL
		col.add_child(g)
		var ro: Label = kit.label("–", P.FS_READOUT, P.SLATE)
		if kit.font_readout != null:
			ro.add_theme_font_override("font", kit.font_readout)
		ro.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		readouts.append(ro)
		col.add_child(ro)
		var tg: Label = kit.tlabel(target_keys[i], P.FS_SMALL, P.STEEL, false, target_args[i])
		tg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(tg)

		var bar_margin := MarginContainer.new()
		bar_margin.add_theme_constant_override("margin_left", 18)
		bar_margin.add_theme_constant_override("margin_right", 18)
		bar_margin.add_theme_constant_override("margin_top", 6)
		col.add_child(bar_margin)
		var bar: ProgressBar = kit.progress_bar(0, P.LEAF)
		bar.max_value = 1.0
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hold_bars.append(bar)
		bar_margin.add_child(bar)

		var lk: Label = kit.label("", P.FS_BODY, P.STEEL)
		lk.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lock_labels.append(lk)
		col.add_child(lk)

	var footer := HBoxContainer.new()
	inner.add_child(footer)
	var hint: Label = kit.tlabel("sim_keys", P.FS_SMALL, P.STEEL)
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	footer.add_child(hint)
	var help: Button = kit.tbutton("btn_help", "secondary")
	help.pressed.connect(func(): help_pressed.emit())
	footer.add_child(help)


## sample: direction_deg, force_n, moment_nm; progress: 0..1 per lock (1 = unlocked).
func show_sample(sample: Dictionary, progress: Array) -> void:
	var dir: float = sample["direction_deg"]
	var force: float = sample["force_n"]
	var mom: float = sample["moment_nm"]
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
	for i in range(3):
		# the target zone deepens from tint to full green while it is held
		gauges[i].zone_mix = progress[i]
		hold_bars[i].value = progress[i]
		gauges[i].queue_redraw()


## Lock label: "Locked" in steel, or "Unlocked" in bold target green.
func set_lock(i: int, unlocked: bool) -> void:
	_unlocked[i] = unlocked
	lock_labels[i].text = kit.t("unlocked" if unlocked else "locked")
	lock_labels[i].add_theme_color_override("font_color", P.LEAF_TEXT if unlocked else P.STEEL)
	kit.set_bold(lock_labels[i], unlocked)


func reset() -> void:
	for i in range(3):
		gauges[i].zone_mix = 0.0
		gauges[i].queue_redraw()
		hold_bars[i].value = 0.0
		set_lock(i, false)


func relocalize() -> void:
	for i in range(3):
		lock_labels[i].text = kit.t("unlocked" if _unlocked[i] else "locked")
