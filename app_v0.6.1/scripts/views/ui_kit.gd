extends RefCounted
## View helpers — shared widget builders, fonts/theme and localised text for every app page (v0.5.4;
## moved unchanged from main.gd). Follows design/设计方案_v1.1.md. Holds no app state except the
## current language and the list of widgets whose text follows the language.

const P := preload("res://app_v0.6.1/scripts/views/palette.gd")
const Strings := preload("res://app_v0.6.1/scripts/views/strings.gd")
const C_SLATE := Color("1c2733")   # same as P.SLATE; used for default arguments

var lang := "en"
var font_bold: Font = null
var font_readout: Font = null
var theme: Theme
var _bound: Array = []           # [node, key, args]


# ------------------------------------------------------------------ fonts / theme
func _load_font(file_name: String) -> FontFile:
	var path: String = P.FONT_DIR + file_name
	if ResourceLoader.exists(path):
		return load(path) as FontFile
	push_warning("Font not found: " + path)
	return null


## Fonts: Atkinson Hyperlegible Next (Latin, digits, tabular readouts) with Noto Sans SC fallback (Chinese).
## If the fonts are missing the app still runs with Godot's default font.
func build_theme() -> Theme:
	var reg := _load_font("AtkinsonHyperlegibleNext-Regular.ttf")
	var bold := _load_font("AtkinsonHyperlegibleNext-Bold.ttf")
	var cjk_reg := _load_font("NotoSansSC-Regular.ttf")
	var cjk_bold := _load_font("NotoSansSC-Bold.ttf")
	var th := Theme.new()
	th.default_font_size = P.FS_BODY
	if reg != null:
		if cjk_reg != null:
			var fb: Array[Font] = [cjk_reg]
			reg.fallbacks = fb
		th.default_font = reg
	if bold != null:
		if cjk_bold != null:
			var fbb: Array[Font] = [cjk_bold]
			bold.fallbacks = fbb
		font_bold = bold
		# readouts: bold with tabular figures so changing digits do not shift
		var fv := FontVariation.new()
		fv.base_font = bold
		var tnum: int = TextServerManager.get_primary_interface().name_to_tag("tnum")
		fv.opentype_features = {tnum: 1}
		font_readout = fv
	theme = th
	return th


# ------------------------------------------------------------------ language
func t(key: String) -> String:
	return Strings.get_text(lang, key)


func fmt(key: String, args: Array = []) -> String:
	var s := t(key)
	if args.is_empty():
		return s
	return s % args


## Text of `node` follows the language from now on.
func bind(node: Control, key: String, args: Array = []) -> Control:
	node.set("text", fmt(key, args))
	_bound.append([node, key, args])
	return node


## Re-translate every bound widget; widgets that were freed meanwhile are dropped (v0.5.3 fix).
func apply_language(new_lang: String) -> void:
	lang = new_lang
	var alive: Array = []
	for b in _bound:
		if is_instance_valid(b[0]):
			(b[0] as Control).set("text", fmt(b[1], b[2]))
			alive.append(b)
	_bound = alive


# ------------------------------------------------------------------ widgets
func box(bg: Color, border: Color = Color(0, 0, 0, 0), border_w: int = 0, radius: int = 0,
		pad_h: int = 0, pad_v: int = 0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(border_w)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = pad_h
	sb.content_margin_right = pad_h
	sb.content_margin_top = pad_v
	sb.content_margin_bottom = pad_v
	return sb


func focus_box() -> StyleBoxFlat:
	var sb := box(Color(0, 0, 0, 0), P.SLATE, 2, 8)
	sb.draw_center = false
	sb.set_expand_margin_all(3)
	return sb


func label(text: String, font_size: int = 16, color: Color = C_SLATE, bold: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	if bold and font_bold != null:
		l.add_theme_font_override("font", font_bold)
	return l


## Label whose text follows the language.
func tlabel(key: String, font_size: int = 16, color: Color = C_SLATE, bold: bool = false,
		args: Array = []) -> Label:
	var l := label("", font_size, color, bold)
	bind(l, key, args)
	return l


func set_bold(l: Label, bold: bool) -> void:
	if bold and font_bold != null:
		l.add_theme_font_override("font", font_bold)
	else:
		l.remove_theme_font_override("font")


## kind: "primary" (slate fill) or "secondary" (outline).
func button(text: String, kind: String = "primary") -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(120, 40)
	b.add_theme_font_size_override("font_size", P.FS_BODY)
	b.focus_mode = Control.FOCUS_ALL
	var normal: StyleBoxFlat
	var hover: StyleBoxFlat
	var fg: Color
	if kind == "primary":
		normal = box(P.SLATE, P.SLATE, 1, 6, 20, 9)
		hover = box(P.SLATE.lightened(0.15), P.SLATE.lightened(0.15), 1, 6, 20, 9)
		fg = Color.WHITE
		if font_bold != null:
			b.add_theme_font_override("font", font_bold)
	else:
		normal = box(Color(0, 0, 0, 0), P.CONTROL_BORDER, 1, 6, 20, 9)
		hover = box(P.HOVER, P.CONTROL_BORDER, 1, 6, 20, 9)
		fg = P.SLATE
	var disabled := box(P.TRACK, P.TRACK, 1, 6, 20, 9)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", hover)
	b.add_theme_stylebox_override("disabled", disabled)
	b.add_theme_stylebox_override("focus", focus_box())
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(k, fg)
	b.add_theme_color_override("font_disabled_color", P.STEEL)
	return b


## Button whose text follows the language.
func tbutton(key: String, kind: String = "primary") -> Button:
	var b := button("", kind)
	bind(b, key)
	return b


## Segmented toggle (difficulty, language, filters): selected = white with slate outline.
func toggle(text: String, group: ButtonGroup) -> Button:
	var b := Button.new()
	b.text = text
	b.toggle_mode = true
	b.button_group = group
	b.custom_minimum_size = Vector2(0, 36)
	b.add_theme_font_size_override("font_size", P.FS_BODY)
	var off := box(Color(0, 0, 0, 0), P.CONTROL_BORDER, 1, 6, 16, 7)
	var off_hover := box(P.HOVER, P.CONTROL_BORDER, 1, 6, 16, 7)
	var on := box(P.SURFACE, P.SLATE, 2, 6, 16, 7)
	b.add_theme_stylebox_override("normal", off)
	b.add_theme_stylebox_override("hover", off_hover)
	b.add_theme_stylebox_override("pressed", on)
	b.add_theme_stylebox_override("hover_pressed", on)
	b.add_theme_stylebox_override("focus", focus_box())
	b.add_theme_color_override("font_color", P.STEEL)
	b.add_theme_color_override("font_hover_color", P.SLATE)
	b.add_theme_color_override("font_focus_color", P.STEEL)
	b.add_theme_color_override("font_pressed_color", P.SLATE)
	b.add_theme_color_override("font_hover_pressed_color", P.SLATE)
	return b


func progress_bar(width: int) -> ProgressBar:
	var pb := ProgressBar.new()
	pb.custom_minimum_size = Vector2(width, 6)
	pb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pb.show_percentage = false
	pb.add_theme_stylebox_override("background", box(P.TRACK))
	pb.add_theme_stylebox_override("fill", box(P.SLATE))
	pb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return pb


func hrule() -> ColorRect:
	var r := ColorRect.new()
	r.color = P.RULE
	r.custom_minimum_size = Vector2(0, 1)
	return r


func vrule() -> ColorRect:
	var r := ColorRect.new()
	r.color = P.RULE
	r.custom_minimum_size = Vector2(1, 0)
	return r


func ignore_mouse(node: Node) -> void:
	for child in node.get_children():
		if child is Control:
			(child as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
		ignore_mouse(child)


func clear(container: Node) -> void:
	for c in container.get_children():
		container.remove_child(c)
		c.queue_free()
