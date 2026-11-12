extends CenterContainer
## View — sensor connection page (v0.5.4; v0.7.0: on a wooden board).

signal connect_pressed(source_index: int)
signal continue_pressed

const P := preload("res://app_v0.8.3/scripts/views/palette.gd")

var kit
var source_select: OptionButton
var conn_status: Label
var connect_btn: Button
var continue_btn: Button


func build(k) -> void:
	kit = k
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bf = kit.board(true, 20, 12)
	bf.custom_minimum_size = Vector2(560, 0)
	add_child(bf)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	bf.content.add_child(v)
	v.add_child(kit.tdisplay("conn_title", P.FS_HEAD, P.INK))
	var note: Label = kit.tlabel("conn_note", P.FS_BODY, P.STEEL)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(note)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 20)
	grid.add_theme_constant_override("v_separation", 12)
	v.add_child(grid)
	var in_l: Label = kit.tlabel("input", P.FS_BODY, P.STEEL)
	in_l.custom_minimum_size = Vector2(90, 0)
	grid.add_child(in_l)
	source_select = OptionButton.new()
	source_select.add_item("")
	source_select.add_item("")
	source_select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	source_select.add_theme_font_size_override("font_size", P.FS_BODY)
	source_select.add_theme_stylebox_override("normal", kit.box(P.PAPER, P.INK, P.LINE, 12, 12, 7))
	source_select.add_theme_stylebox_override("hover", kit.box(P.HOVER, P.INK, P.LINE, 12, 12, 7))
	source_select.add_theme_stylebox_override("pressed", kit.box(P.HOVER, P.INK, P.LINE, 12, 12, 7))
	source_select.add_theme_stylebox_override("focus", kit.focus_box())
	for k2 in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		source_select.add_theme_color_override(k2, P.SLATE)
	grid.add_child(source_select)
	grid.add_child(kit.tlabel("status", P.FS_BODY, P.STEEL))
	conn_status = kit.label("", P.FS_BODY, P.SLATE)
	grid.add_child(conn_status)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_END
	buttons.add_theme_constant_override("separation", 10)
	connect_btn = kit.tbutton("btn_connect", "secondary")
	connect_btn.pressed.connect(func(): connect_pressed.emit(source_select.selected))
	continue_btn = kit.tbutton("btn_continue", "primary")
	continue_btn.disabled = true
	continue_btn.pressed.connect(func(): continue_pressed.emit())
	buttons.add_child(connect_btn)
	buttons.add_child(continue_btn)
	v.add_child(buttons)


func relocalize() -> void:
	source_select.set_item_text(0, kit.t("src_sim"))
	source_select.set_item_text(1, kit.t("src_usb"))


## tone: "idle", "busy", "ok", "fault" (see AppView.TONES)
func set_conn_status(key: String, tone: String) -> void:
	var tones := {"idle": P.STEEL, "busy": P.SUN_TEXT, "ok": P.LEAF_TEXT, "plain": P.INK, "fault": P.TOMATO_TEXT}
	conn_status.text = kit.t(key)
	conn_status.add_theme_color_override("font_color", tones.get(tone, P.SLATE))


func set_buttons(connect_enabled: bool, continue_enabled: bool) -> void:
	connect_btn.disabled = not connect_enabled
	continue_btn.disabled = not continue_enabled


func focus_continue() -> void:
	continue_btn.grab_focus()
