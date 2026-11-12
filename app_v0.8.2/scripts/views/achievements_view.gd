extends VBoxContainer
## View — Achievements page (v0.5.4; v0.7.0: garden look, design/设计方案_v2.0.md §4.4).
## Steam-like list on a wooden board: one paper plate per achievement (locked ones on older, darker
## paper), colour only for state (green ✓ = unlocked).
## The presenter passes everything to show; the view never reads the database.

signal filter_changed(index: int)   # 0 all, 1 unlocked, 2 locked
signal back_pressed

const P := preload("res://app_v0.8.2/scripts/views/palette.gd")
const AchUI := preload("res://app_v0.8.2/scripts/views/achievement_ui.gd")

var kit
var summary: Label
var pct: Label
var bar: ProgressBar
var list: VBoxContainer


func build(k, filter: int) -> void:
	kit = k
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_theme_constant_override("separation", 0)
	# v0.7.0: everything sits on one board; each achievement is a paper plate
	var bf = kit.board(true, 8, 0)
	bf.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(bf)
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 10)
	bf.content.add_child(page)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 16)
	page.add_child(top)
	summary = kit.display("", P.FS_TITLE, P.INK)
	summary.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(summary)
	bar = kit.progress_bar(220)
	top.add_child(bar)
	pct = kit.label("", P.FS_BODY, P.STEEL)
	pct.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(pct)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(spacer)
	var fg := ButtonGroup.new()
	var frow := HBoxContainer.new()
	frow.add_theme_constant_override("separation", 4)
	frow.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(frow)
	for i in range(3):
		var b: Button = kit.toggle("", fg)
		kit.bind(b, ["ach_all", "ach_unlocked", "ach_locked"][i])
		b.button_pressed = i == filter
		b.pressed.connect(func(): filter_changed.emit(i))
		frow.add_child(b)
	var back: Button = kit.tbutton("btn_back", "secondary")
	back.set_meta("sfx", "back")   # v0.8.2 (revised): back buttons have their own sound
	back.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(func(): back_pressed.emit())
	top.add_child(back)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	page.add_child(scroll)
	list = VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	scroll.add_child(list)


## done/total: counts. sections: [{"group": {"id", "zh", "en"}, "rows": [{"def", "unlocked", "unlocked_at", "progress"}]}]
## (already filtered by the presenter).
func show_list(done: int, total: int, sections: Array) -> void:
	summary.text = kit.fmt("ach_summary", [done, total])
	bar.max_value = total
	bar.value = done
	pct.text = "%d%%" % int(round(100.0 * done / maxi(total, 1)))
	kit.clear(list)
	var shown := 0
	for sec in sections:
		var head := MarginContainer.new()
		head.add_theme_constant_override("margin_top", 10 if shown > 0 else 0)
		var g: Dictionary = sec["group"]
		var group_name: String = g[kit.lang] if g.has(kit.lang) else g["en"]
		var level_key := "levelB_title" if sec.get("game", "") == "balloon" else "levelA_title"
		head.add_child(kit.display("%s：%s" % [kit.t(level_key), group_name] if kit.lang == "zh"
			else "%s: %s" % [kit.t(level_key), group_name], P.FS_LABEL, P.INK))
		list.add_child(head)
		for r in sec["rows"]:
			list.add_child(_row(r))
			shown += 1
	if shown == 0:
		var m := MarginContainer.new()
		m.add_theme_constant_override("margin_top", 24)
		m.add_child(kit.label(kit.t("ach_empty"), P.FS_BODY, P.STEEL))
		list.add_child(m)


func _row(r: Dictionary) -> Control:
	var d: Dictionary = r["def"]
	var un: bool = r["unlocked"]
	var hidden_locked: bool = d["hidden"] and not un
	var lang: String = kit.lang
	# unlocked: paper plate; locked: darker, older paper
	var m: PanelContainer = kit.plate(14, 10, P.PAPER if un else Color("ecdcbc"))
	m.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 16)
	m.add_child(h)
	var ic := AchUI.icon(d, un, 64)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(ic)

	var mid := VBoxContainer.new()
	mid.add_theme_constant_override("separation", 2)
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(mid)
	if hidden_locked:
		mid.add_child(kit.label(kit.t("ach_hidden_name"), P.FS_LABEL, P.STEEL, true))
		mid.add_child(kit.label(kit.t("ach_hidden_desc"), P.FS_BODY, P.STEEL))
	else:
		mid.add_child(kit.display(AchUI.text_of(d, "name", lang), P.FS_LABEL, P.INK if un else P.STEEL))
		var cond: Label = kit.label(AchUI.text_of(d, "cond", lang), P.FS_BODY, P.SLATE)
		cond.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		mid.add_child(cond)
		var fl: Label = kit.label(AchUI.text_of(d, "flavor", lang), P.FS_SMALL, P.STEEL)
		fl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		mid.add_child(fl)

	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(170, 0)
	right.add_theme_constant_override("separation", 4)
	right.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(right)
	if un:
		right.add_child(kit.label(kit.t("ach_status_unlocked") + " ✓", P.FS_BODY, P.LEAF_TEXT, true))
		right.add_child(kit.label(str(r["unlocked_at"]).substr(0, 16), P.FS_SMALL, P.STEEL))
	else:
		var target: int = d["target"]
		if target > 0 and not hidden_locked:
			var pb: ProgressBar = kit.progress_bar(150)
			pb.max_value = target
			pb.value = int(r["progress"])
			right.add_child(pb)
			right.add_child(kit.label("%d / %d" % [int(r["progress"]), target], P.FS_SMALL, P.STEEL))
		else:
			right.add_child(kit.label(kit.t("ach_status_locked"), P.FS_BODY, P.STEEL))
	return m
