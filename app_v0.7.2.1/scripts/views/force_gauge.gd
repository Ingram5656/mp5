extends Control
## Vertical force bar (v0.3.0 style): track with slate outline, scale labels on the right,
## target band that deepens as the hold progresses, slate triangle pointer on the left.

const P := preload("res://app_v0.7.2.1/scripts/views/palette.gd")

var value: float = 0.0
var max_value: float = 20.0
var target_min: float = 8.0
var target_max: float = 12.0
var zone_mix: float = 0.0
var show_scale: bool = true

const BAR_W := 40.0


func _ready() -> void:
	if custom_minimum_size == Vector2.ZERO:
		custom_minimum_size = Vector2(200, 200)


func _y(v: float, top: float, bottom: float) -> float:
	return lerpf(bottom, top, clampf(v / max_value, 0.0, 1.0))


func _draw() -> void:
	var top := 6.0
	var bottom := size.y - 6.0
	var x := size.x / 2.0 - BAR_W / 2.0
	var rect := Rect2(x, top, BAR_W, bottom - top)

	var track := StyleBoxFlat.new()
	track.bg_color = P.SURFACE
	track.set_corner_radius_all(14)
	track.set_border_width_all(4)
	track.border_color = P.SLATE
	draw_style_box(track, rect)

	var y0 := _y(target_max, top, bottom)
	var y1 := _y(target_min, top, bottom)
	draw_rect(Rect2(x + 3.0, y0, BAR_W - 6.0, y1 - y0), P.zone_color(zone_mix))

	if show_scale:
		var font := get_theme_default_font()
		var step := 5.0
		var v := 0.0
		while v <= max_value + 0.01:
			var y := _y(v, top, bottom)
			draw_line(Vector2(x + BAR_W + 4, y), Vector2(x + BAR_W + 10, y), P.STEEL, 1.5)
			if font != null:
				draw_string(font, Vector2(x + BAR_W + 14, y + 5), "%d" % int(v),
					HORIZONTAL_ALIGNMENT_LEFT, -1, P.FS_SMALL, P.STEEL)
			v += step

	var py := _y(value, top, bottom)
	var tip := Vector2(x - 4.0, py)
	var s := 12.0 if size.y > 160 else 9.0
	var pts := PackedVector2Array([tip, tip + Vector2(-s * 1.7, -s), tip + Vector2(-s * 1.7, s)])
	draw_colored_polygon(pts, P.CARROT)   # v0.7.0: carrot pointer with ink outline
	pts.append(tip)
	draw_polyline(pts, P.INK, 2.5, true)
