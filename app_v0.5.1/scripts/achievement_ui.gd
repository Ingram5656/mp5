extends RefCounted
## Shared pieces for achievements: icons and the "achievement unlocked" pop-up.
## v0.5.1: drawn icons are scaled smoothly, and locked ones are shown in grey (colour = unlocked).
## Follows design/设计方案_v1.1.md: porcelain/white surfaces, hairline borders, no shadows or gradients,
## colour only for state (TARGET = unlocked), Atkinson Hyperlegible Next + Noto Sans SC, type scale 13/16/20/25.

const P := preload("res://app_v0.5.1/scripts/palette.gd")
const Defs := preload("res://app_v0.5.1/scripts/achievement_defs.gd")

const ICON_DIR := "res://assets/achievements/"
const PLACEHOLDER := "🦷"

static var _fonts := {}
static var _icon_cache := {}


# ------------------------------------------------------------------ fonts
static func font(bold := false) -> Font:
	var key := "bold" if bold else "reg"
	if _fonts.has(key):
		return _fonts[key]
	var latin_path := P.FONT_DIR + ("AtkinsonHyperlegibleNext-Bold.ttf" if bold else "AtkinsonHyperlegibleNext-Regular.ttf")
	var cjk_path := P.FONT_DIR + ("NotoSansSC-Bold.ttf" if bold else "NotoSansSC-Regular.ttf")
	var f: Font = null
	if ResourceLoader.exists(latin_path):
		var fv := FontVariation.new()   # own copy, so the app theme's font is not changed
		fv.base_font = load(latin_path)
		var fb: Array[Font] = []
		if ResourceLoader.exists(cjk_path):
			fb.append(load(cjk_path))
		fb.append(emoji_font())
		fv.fallbacks = fb
		f = fv
	_fonts[key] = f
	return f


static func emoji_font() -> Font:
	if _fonts.has("emoji"):
		return _fonts["emoji"]
	var sf := SystemFont.new()
	sf.font_names = PackedStringArray(["Segoe UI Emoji", "Apple Color Emoji", "Noto Color Emoji"])
	_fonts["emoji"] = sf
	return sf


static func label(text: String, size: int, color: Color, bold := false) -> Label:
	var l := Label.new()
	l.text = text
	var f := font(bold)
	if f != null:
		l.add_theme_font_override("font", f)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func box(bg: Color, border: Color, border_w: int, pad: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(border_w)
	sb.content_margin_left = pad
	sb.content_margin_right = pad
	sb.content_margin_top = pad
	sb.content_margin_bottom = pad
	return sb


# ------------------------------------------------------------------ icon
## Square icon. Uses res://assets/achievements/<icon>.png when it exists, otherwise a 🦷 placeholder.
## Locked: grey and lighter (drawn icon) or faded (placeholder). Hidden and locked: "?" instead of the icon.
static func icon(d: Dictionary, unlocked: bool, size: int) -> Control:
	var frame := PanelContainer.new()
	frame.custom_minimum_size = Vector2(size, size)
	frame.add_theme_stylebox_override("panel", box(P.SURFACE, P.RULE, 1, 0))
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var hidden_locked: bool = d.get("hidden", false) and not unlocked
	var path: String = ICON_DIR + str(d.get("icon", "")) + ".png"
	var content: Control
	if not hidden_locked and ResourceLoader.exists(path):
		var tex_rect := TextureRect.new()
		tex_rect.texture = _icon_texture(path, size * 2, not unlocked)
		tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		content = tex_rect
	else:
		var l := Label.new()
		l.text = "?" if hidden_locked else PLACEHOLDER
		if hidden_locked:
			var f := font(true)
			if f != null:
				l.add_theme_font_override("font", f)
			l.add_theme_color_override("font_color", P.STEEL)
		else:
			l.add_theme_font_override("font", emoji_font())
		l.add_theme_font_size_override("font_size", int(size * 0.55))
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		content = l
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not unlocked and content is Label:
		content.modulate = Color(1, 1, 1, 0.35)
	frame.add_child(content)
	return frame


# ------------------------------------------------------------------ pop-up
## One pop-up: icon, "Achievement unlocked" (TARGET colour = unlocked state), name, flavour text.
static func toast(d: Dictionary, lang: String) -> Control:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", box(P.SURFACE, P.RULE, 1, 12))
	p.custom_minimum_size = Vector2(360, 0)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(h)
	var ic := icon(d, true, 56)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(ic)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(v)
	v.add_child(label("成就解锁" if lang == "zh" else "Achievement unlocked", P.FS_SMALL, P.TARGET, true))
	v.add_child(label(Defs.text(d, "name", lang), P.FS_LABEL, P.SLATE, true))
	var fl := label(Defs.text(d, "flavor", lang), P.FS_BODY, P.STEEL)
	fl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	fl.custom_minimum_size = Vector2(270, 0)
	v.add_child(fl)
	return p


## The drawn icons are 256×256. Scaling them down 4× on screen looks rough, so make a smooth copy at
## px×px once (Lanczos) and reuse it. Locked copies are converted to light grey here, so colour on an
## icon always means "unlocked" (design rule: colour only for state).
static func _icon_texture(path: String, px: int, locked: bool) -> Texture2D:
	var key := "%s|%d|%s" % [path, px, str(locked)]
	if _icon_cache.has(key):
		return _icon_cache[key]
	var src: Texture2D = load(path)
	var img := src.get_image()
	if img == null:
		return src
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	img.resize(px, px, Image.INTERPOLATE_LANCZOS)
	if locked:
		for y in range(px):
			for x in range(px):
				var c := img.get_pixel(x, y)
				var l := lerpf(c.r * 0.299 + c.g * 0.587 + c.b * 0.114, 1.0, 0.3)
				img.set_pixel(x, y, Color(l, l, l, c.a * 0.6))
	var tex := ImageTexture.create_from_image(img)
	_icon_cache[key] = tex
	return tex

