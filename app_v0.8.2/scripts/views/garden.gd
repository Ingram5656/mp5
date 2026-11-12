extends RefCounted
## View helpers — the "菜园木牌" look (design/设计方案_v2.0.md, v0.7.0), as static functions so every
## view can use them: app pages (through ui_kit), the report, the achievement pop-ups and the result
## panels of the two games. Nothing here knows about rules, files or the database.
##
## Pieces: garden backdrop, wooden board on two posts, small sign, note paper, paper plate, pill buttons
## with a solid "lip", tags, the display font (ZCOOL KuaiLe) and the grade stamp.

const P := preload("res://app_v0.8.2/scripts/views/palette.gd")

## Art is drawn for a 1920-wide screen; the app window is 1152 wide. Nine-patch art is scaled down once
## (Lanczos) so its borders keep the same thickness as the game art on screen.
const BOARD_TEX := "res://assets/carrot_game/ui_result_panel.png"   # 800×500, border ~70 px
const BOARD_SCALE := 0.5
const BOARD_MARGIN := 35
const SIGN_TEX := "res://assets/ui/ui_sign_small.png"               # 600×160, border ~50 px
const SIGN_OFF_TEX := "res://assets/ui/ui_sign_small_off.png"
const SIGN_SCALE := 0.45
const SIGN_MARGIN := 23
const PAPER_TEX := "res://assets/ui/ui_paper.png"                   # 800×600, border ~60 px
const PAPER_SCALE := 0.5
const PAPER_MARGIN := 30
const POST_TEX := "res://assets/ui/ui_post.png"                     # 60×200
const POST_SIZE := Vector2(26, 86)

static var _cache := {}


# ------------------------------------------------------------------ fonts
## Title font: ZCOOL KuaiLe, falling back to Noto Sans SC Bold for any missing character.
## Only for titles of 20 px and up (design v2.0 §3.3). null when the font file is missing.
static func display_font() -> Font:
	if _cache.has("font_display"):
		return _cache["font_display"]
	var f: Font = null
	var path: String = P.FONT_DIR + "ZCOOLKuaiLe-Regular.ttf"
	if ResourceLoader.exists(path):
		var fv := FontVariation.new()
		fv.base_font = load(path)
		var fb: Array[Font] = []
		var cjk: String = P.FONT_DIR + "NotoSansSC-Bold.ttf"
		if ResourceLoader.exists(cjk):
			fb.append(load(cjk))
		fv.fallbacks = fb
		f = fv
	else:
		push_warning("Font not found: " + path)
	_cache["font_display"] = f
	return f


## Body / readout font (Atkinson Hyperlegible Next + Noto Sans SC), bold or regular.
static func body_font(bold := false) -> Font:
	var key := "font_body_b" if bold else "font_body_r"
	if _cache.has(key):
		return _cache[key]
	var f: Font = null
	var latin: String = P.FONT_DIR + ("AtkinsonHyperlegibleNext-Bold.ttf" if bold else "AtkinsonHyperlegibleNext-Regular.ttf")
	var cjk: String = P.FONT_DIR + ("NotoSansSC-Bold.ttf" if bold else "NotoSansSC-Regular.ttf")
	if ResourceLoader.exists(latin):
		var fv := FontVariation.new()
		fv.base_font = load(latin)
		var fb: Array[Font] = []
		if ResourceLoader.exists(cjk):
			fb.append(load(cjk))
		fv.fallbacks = fb
		f = fv
	_cache[key] = f
	return f


static func display_label(text: String, font_size: int, color: Color = P.INK) -> Label:
	var l := Label.new()
	l.text = text
	var f := display_font()
	if f != null:
		l.add_theme_font_override("font", f)
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


# ------------------------------------------------------------------ textures
## A smooth, scaled copy of a texture (cached). null when the file is missing.
static func scaled_tex(path: String, factor: float) -> Texture2D:
	var key := "%s|%.3f" % [path, factor]
	if _cache.has(key):
		return _cache[key]
	if not ResourceLoader.exists(path):
		push_warning("UI art not found: " + path)
		_cache[key] = null
		return null
	var src: Texture2D = load(path)
	var tex: Texture2D = src
	if not is_equal_approx(factor, 1.0):
		var img := src.get_image()
		if img != null:
			if img.is_compressed():
				img.decompress()
			img.convert(Image.FORMAT_RGBA8)
			img.resize(maxi(1, int(img.get_width() * factor)), maxi(1, int(img.get_height() * factor)), Image.INTERPOLATE_LANCZOS)
			tex = ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex


## Nine-patch style box from a piece of art; a flat outlined box when the art is missing.
static func tex_box(path: String, factor: float, margin: int, pad_h: int, pad_v: int, fallback_bg: Color) -> StyleBox:
	var tex := scaled_tex(path, factor)
	if tex == null:
		return flat(fallback_bg, P.INK, P.LINE, 14, pad_h, pad_v)
	var sb := StyleBoxTexture.new()
	sb.texture = tex
	sb.set_texture_margin_all(margin)
	sb.content_margin_left = pad_h
	sb.content_margin_right = pad_h
	sb.content_margin_top = pad_v
	sb.content_margin_bottom = pad_v
	return sb


static func board_box(pad_h := 22, pad_v := 18) -> StyleBox:
	return tex_box(BOARD_TEX, BOARD_SCALE, BOARD_MARGIN, BOARD_MARGIN + pad_h, BOARD_MARGIN + pad_v, P.PLANK)


static func sign_box(off := false, pad_h := 14, pad_v := 8) -> StyleBox:
	return tex_box(SIGN_OFF_TEX if off else SIGN_TEX, SIGN_SCALE, SIGN_MARGIN, pad_h + 6, pad_v + 4, P.PLANK)


static func paper_box(pad_h := 22, pad_v := 18) -> StyleBox:
	return tex_box(PAPER_TEX, PAPER_SCALE, PAPER_MARGIN, pad_h + 6, pad_v + 6, P.PAPER)


# ------------------------------------------------------------------ flat boxes
static func flat(bg: Color, border: Color = P.INK, border_w: int = P.LINE, radius: int = 12,
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


## Plate: paper, ink outline, radius 18 (gauges, achievement rows, chips).
static func plate_box(pad_h := 16, pad_v := 12, bg: Color = P.PAPER) -> StyleBoxFlat:
	return flat(bg, P.INK, P.LINE, 18, pad_h, pad_v)


## A box with a solid ink lip under it (a thicker bottom outline), like a sticker on a board.
## pad_v is the space above the text; the lip is added below it, so the text stays centred on the face.
static func lip_box(bg: Color, lip: int, radius: int, pad_h: int, pad_v: int) -> StyleBoxFlat:
	var sb := flat(bg, P.INK, P.LINE, radius, pad_h, pad_v)
	sb.border_width_bottom = P.LINE + lip
	sb.content_margin_bottom = pad_v + lip
	return sb


## Same box pressed in: the lip almost disappears and the text moves down by the same amount.
static func lip_box_pressed(bg: Color, lip: int, radius: int, pad_h: int, pad_v: int) -> StyleBoxFlat:
	var sb := flat(bg, P.INK, P.LINE, radius, pad_h, pad_v + lip - 1)
	sb.border_width_bottom = P.LINE + 1
	sb.content_margin_bottom = pad_v + 1
	return sb


# ------------------------------------------------------------------ buttons
## kind: "primary" (carrot, one per page), "secondary" (paper). Pill shape, ink outline, solid lip;
## pressing sinks the button by 3 px (the only standing animation, v2.0 §3.4).
static func style_button(b: Button, kind := "secondary", font_size := P.FS_BODY) -> void:
	var primary := kind == "primary"
	var bg: Color = P.CARROT if primary else P.PAPER
	var hover_bg: Color = bg.lightened(0.12) if primary else P.HOVER
	var h_pad := 26 if primary else 20
	var v_pad := 8
	var normal := lip_box(bg, P.LIP, 999, h_pad, v_pad)
	var hover := lip_box(hover_bg, P.LIP, 999, h_pad, v_pad)
	var pressed := lip_box_pressed(hover_bg, P.LIP, 999, h_pad, v_pad)
	var disabled := flat(Color("eadbbd"), P.SOIL, P.LINE, 999, h_pad, v_pad)
	disabled.content_margin_bottom = v_pad + P.LIP
	var focus := flat(Color(0, 0, 0, 0), P.INK, 2, 999)
	focus.draw_center = false
	focus.set_expand_margin_all(5)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("hover_pressed", pressed)
	b.add_theme_stylebox_override("disabled", disabled)
	b.add_theme_stylebox_override("focus", focus)
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(k, P.INK)
	b.add_theme_color_override("font_disabled_color", P.SOIL)
	var f := body_font(true)
	if f != null:
		b.add_theme_font_override("font", f)
	b.add_theme_font_size_override("font_size", P.FS_LABEL if primary and font_size == P.FS_BODY else font_size)
	b.focus_mode = Control.FOCUS_ALL
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


## Toggle tag (level, difficulty, language, filters): paper; selected = ink with plank-coloured text,
## sunk 2 px.
static func style_toggle(b: Button) -> void:
	var off := lip_box(P.PAPER, 3, 12, 14, 6)
	var off_hover := lip_box(P.HOVER, 3, 12, 14, 6)
	var on := lip_box_pressed(P.INK, 3, 12, 14, 6)
	var focus := flat(Color(0, 0, 0, 0), P.INK, 2, 14)
	focus.draw_center = false
	focus.set_expand_margin_all(4)
	b.add_theme_stylebox_override("normal", off)
	b.add_theme_stylebox_override("hover", off_hover)
	b.add_theme_stylebox_override("pressed", on)
	b.add_theme_stylebox_override("hover_pressed", on)
	b.add_theme_stylebox_override("focus", focus)
	var dis := flat(Color("eadbbd"), P.SOIL, P.LINE, 12, 14, 6)
	dis.content_margin_bottom = 9
	b.add_theme_stylebox_override("disabled", dis)
	for k in ["font_color", "font_hover_color", "font_focus_color"]:
		b.add_theme_color_override(k, P.INK)
	b.add_theme_color_override("font_pressed_color", P.PLANK)
	b.add_theme_color_override("font_hover_pressed_color", P.PLANK)
	b.add_theme_color_override("font_disabled_color", P.SOIL)
	var f := body_font(true)
	if f != null:
		b.add_theme_font_override("font", f)
	b.add_theme_font_size_override("font_size", P.FS_BODY)
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


## Rounded bar: white track with ink outline, coloured fill.
static func style_bar(pb: ProgressBar, fill: Color = P.SOIL, height := 12) -> void:
	pb.custom_minimum_size.y = height
	pb.show_percentage = false
	pb.add_theme_stylebox_override("background", flat(P.SURFACE, P.INK, P.LINE, 999))
	var f := flat(fill, P.INK, P.LINE, 999)
	pb.add_theme_stylebox_override("fill", f)


# ------------------------------------------------------------------ scene pieces
## The garden behind every app page: sky, fence, back soil, front soil (same art as the games), still.
static func backdrop() -> Control:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sky := ColorRect.new()
	sky.color = P.SKY
	sky.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(sky)
	for n in ["bg_sky", "bg_fence", "bg_soil_back", "bg_soil_front"]:
		var path: String = P.GARDEN_DIR + n + ".png"
		if not ResourceLoader.exists(path):
			continue
		var layer := TextureRect.new()
		layer.texture = load(path)
		layer.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		layer.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(layer)
	return root


## A wooden board standing on two posts stuck in the soil. Put the page's content in `.content`.
static func board(with_posts := true, pad_h := 22, pad_v := 18) -> BoardFrame:
	var bf := BoardFrame.new()
	var post_tex: Texture2D = null
	if with_posts:
		post_tex = scaled_tex(POST_TEX, 1.0)
	bf.setup(board_box(pad_h, pad_v), post_tex)
	return bf


## Grade stamp: double ring (ui_stamp_ring.png, white art tinted here) with the grade letter, tilted −8°.
static func stamp(grade: String, passed: bool, px := 92) -> Control:
	var col: Color = P.LEAF_TEXT if passed else P.TOMATO_TEXT
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(px, px)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tex := scaled_tex(P.UI_DIR + "ui_stamp_ring.png", float(px * 2) / 256.0)
	var ring: Control
	if tex != null:
		var ring_rect := TextureRect.new()
		ring_rect.texture = tex
		ring_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ring_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ring_rect.modulate = col
		ring = ring_rect
	else:
		var pn := Panel.new()
		pn.add_theme_stylebox_override("panel", flat(Color(1, 1, 1, 0.5), col, 4, 999))
		ring = pn
	ring.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(ring)
	var l := display_label(grade, int(px * 0.6), col)
	l.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	holder.add_child(l)
	holder.pivot_offset = Vector2(px, px) / 2.0
	holder.rotation = deg_to_rad(-8.0)
	return holder


static func ui_texture(file_name: String, factor := 1.0) -> Texture2D:
	return scaled_tex(P.UI_DIR + file_name, factor)


# =====================================================================
## Board on posts. The posts are children drawn behind the board and hang below it into the soil, so
## leave about 60 px free under a board.
class BoardFrame extends Control:
	var panel: PanelContainer
	var content: MarginContainer
	var _posts: Array = []

	func setup(style: StyleBox, post_tex: Texture2D) -> void:
		mouse_filter = Control.MOUSE_FILTER_PASS
		if post_tex != null:
			for i in 2:
				var p := TextureRect.new()
				p.texture = post_tex
				p.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				p.stretch_mode = TextureRect.STRETCH_SCALE
				p.size = Vector2(26, 86)
				p.mouse_filter = Control.MOUSE_FILTER_IGNORE
				add_child(p)
				_posts.append(p)
		panel = PanelContainer.new()
		panel.add_theme_stylebox_override("panel", style)
		panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		panel.mouse_filter = Control.MOUSE_FILTER_PASS
		add_child(panel)
		content = MarginContainer.new()
		panel.add_child(content)
		panel.minimum_size_changed.connect(update_minimum_size)
		resized.connect(_place_posts)

	func _place_posts() -> void:
		for i in _posts.size():
			var p: TextureRect = _posts[i]
			var fx: float = 0.18 if i == 0 else 0.82
			p.position = Vector2(size.x * fx - p.size.x / 2.0, size.y - 34.0)

	## The board's minimum size follows its content.
	func _get_minimum_size() -> Vector2:
		return panel.get_combined_minimum_size() if panel != null else Vector2.ZERO
