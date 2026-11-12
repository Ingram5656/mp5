extends Control
## Direction dial (v0.3.0 style): white face, slate rim with ticks, dashed crosshair,
## target sector that deepens from tint to TARGET as the hold progresses, slate arrow.
## Angles in degrees, 0 = right, counter-clockwise positive (screen up).

const P := preload("res://app_v0.8.4/scripts/views/palette.gd")

var value_deg: float = 0.0
var target_deg: float = 45.0
var tolerance_deg: float = 15.0
var zone_mix: float = 0.0   # 0 = tint, 1 = full TARGET


func _ready() -> void:
	if custom_minimum_size == Vector2.ZERO:
		custom_minimum_size = Vector2(200, 200)


func _dir(deg: float) -> Vector2:
	var a := deg_to_rad(deg)
	return Vector2(cos(a), -sin(a))


func _draw() -> void:
	var c := size / 2.0
	var r: float = min(size.x, size.y) / 2.0 - 4.0
	var small: bool = r < 80.0
	draw_circle(c, r, P.SURFACE)

	# target sector
	var pts := PackedVector2Array([c])
	var steps := 24
	for i in range(steps + 1):
		var d := lerpf(target_deg - tolerance_deg, target_deg + tolerance_deg, float(i) / steps)
		pts.append(c + _dir(d) * (r - 2.0))
	draw_colored_polygon(pts, P.zone_color(zone_mix))

	# crosshair and ticks every 30 degrees
	draw_dashed_line(c + Vector2(-r, 0), c + Vector2(r, 0), P.STEEL, 1.5, 5.0)
	draw_dashed_line(c + Vector2(0, -r), c + Vector2(0, r), P.STEEL, 1.5, 5.0)
	if not small:
		for k in range(12):
			var d := _dir(k * 30.0)
			var tick_len := 12.0 if k % 3 == 0 else 7.0
			draw_line(c + d * (r - tick_len), c + d * (r - 1.0), P.SLATE, 2.0, true)
	draw_arc(c, r, 0.0, TAU, 96, P.SLATE, 4.0, true)

	# arrow
	var dir := _dir(value_deg)
	var tip := c + dir * (r * 0.8)
	var head := 14.0 if small else 20.0
	var base := tip - dir * head
	draw_line(c, base, P.SLATE, 4.0 if small else 6.0, true)
	var side := Vector2(-dir.y, dir.x) * head * 0.55
	# v0.7.0: carrot-coloured arrow head and centre pin with ink outlines
	var head_pts := PackedVector2Array([tip, base + side, base - side])
	draw_colored_polygon(head_pts, P.CARROT)
	head_pts.append(tip)
	draw_polyline(head_pts, P.INK, 2.5, true)
	draw_circle(c, 5.0 if small else 8.0, P.CARROT)
	draw_arc(c, 5.0 if small else 8.0, 0.0, TAU, 24, P.INK, 2.5, true)
