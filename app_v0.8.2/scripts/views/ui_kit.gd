extends RefCounted
## View helpers — shared widget builders, fonts/theme and localised text for every app page (v0.5.4;
## v0.7.0: garden look from design/设计方案_v2.0.md, built with garden.gd). Holds no app state except the
## current language and the list of widgets whose text follows the language.

const P := preload("res://app_v0.8.2/scripts/views/palette.gd")
const Strings := preload("res://app_v0.8.2/scripts/views/strings.gd")
const Garden := preload("res://app_v0.8.2/scripts/views/garden.gd")
const C_SLATE := Color("5e3410")   # same as P.INK (v0.7.0); used for default arguments

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
	# labels default to ink text
	th.set_color("font_color", "Label", P.INK)
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


# ------------------------------------------------------------------ widgets (v0.7.0: garden look, see garden.gd)
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
	sb.anti_aliasing = true
	return sb


func focus_box() -> StyleBoxFlat:
	var sb := box(Color(0, 0, 0, 0), P.INK, 2, 14)
	sb.draw_center = false
	sb.set_expand_margin_all(4)
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


## Title in the display font (ZCOOL KuaiLe), only for 20 px and up.
func display(text: String, font_size: int = P.FS_TITLE, color: Color = C_SLATE) -> Label:
	var l := Garden.display_label(text, font_size, color)
	l.mouse_filter = Control.MOUSE_FILTER_PASS
	return l


func tdisplay(key: String, font_size: int = P.FS_TITLE, color: Color = C_SLATE) -> Label:
	var l := display("", font_size, color)
	bind(l, key)
	return l


func set_bold(l: Label, bold: bool) -> void:
	if bold and font_bold != null:
		l.add_theme_font_override("font", font_bold)
	else:
		l.remove_theme_font_override("font")


## kind: "primary" (carrot, the one main action of a page) or "secondary" (paper).
func button(text: String, kind: String = "primary") -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(110, 0)
	Garden.style_button(b, kind)
	return b


## Button whose text follows the language.
func tbutton(key: String, kind: String = "primary") -> Button:
	var b := button("", kind)
	bind(b, key)
	return b


## Toggle tag (difficulty, level, language, filters): paper; selected = ink, pressed in.
func toggle(text: String, group: ButtonGroup) -> Button:
	var b := Button.new()
	b.text = text
	b.toggle_mode = true
	b.button_group = group
	b.focus_mode = Control.FOCUS_ALL
	Garden.style_toggle(b)
	return b


func progress_bar(width: int, fill: Color = P.SOIL) -> ProgressBar:
	var pb := ProgressBar.new()
	pb.custom_minimum_size = Vector2(width, 12)
	pb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	Garden.style_bar(pb, fill)
	pb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return pb


## Separator line on paper (light wood colour, 2 px). v2.0 has no grey hairlines.
func hrule() -> ColorRect:
	var r := ColorRect.new()
	r.color = P.RULE
	r.custom_minimum_size = Vector2(0, 2)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


func vrule() -> ColorRect:
	var r := ColorRect.new()
	r.color = P.RULE
	r.custom_minimum_size = Vector2(2, 0)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


## Wooden board on two posts; add the page content to `.content`.
func board(with_posts := true, pad_h := 22, pad_v := 18):
	return Garden.board(with_posts, pad_h, pad_v)


## Note paper (history list, report).
func paper(pad_h := 22, pad_v := 18) -> PanelContainer:
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", Garden.paper_box(pad_h, pad_v))
	return pc


## Paper plate with ink outline (gauges, achievement rows).
func plate(pad_h := 16, pad_v := 12, bg: Color = P.PAPER) -> PanelContainer:
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", Garden.plate_box(pad_h, pad_v, bg))
	return pc


func ignore_mouse(node: Node) -> void:
	for child in node.get_children():
		if child is Control:
			(child as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
		ignore_mouse(child)


func clear(container: Node) -> void:
	for c in container.get_children():
		container.remove_child(c)
		c.queue_free()
