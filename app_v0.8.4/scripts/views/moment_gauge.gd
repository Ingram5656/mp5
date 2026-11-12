extends Control
## Moment ring (v0.3.0 style): track ring with slate outlines, zero tick at the top,
## target arc that deepens as the hold progresses, slate triangle pointer inside the ring.
## Value range [-max_value, +max_value] maps to -135..+135 degrees around the top (0 = top).

const P := preload("res://app_v0.8.4/scripts/views/palette.gd")

var value: float = 0.0
var max_value: float = 0.5
var target_min: float = 0.15
var target_max: float = 0.25
var zone_mix: float = 0.0

const SWEEP := 135.0


func _ready() -> void:
	if custom_minimum_size == Vector2.ZERO:
		custom_minimum_size = Vector2(200, 200)


## draw_arc angle (radians, 0 = right, clockwise on screen) for a value.
func _angle(v: float) -> float:
	return deg_to_rad(-90.0 + clampf(v / max_value, -1.0, 1.0) * SWEEP)


func _draw() -> void:
	var c := size / 2.0
	var r_out: float = min(size.x, size.y) / 2.0 - 4.0
	var ring_w: float = clampf(r_out * 0.24, 12.0, 28.0)
	var r_mid := r_out - ring_w / 2.0
	var r_in := r_out - ring_w

	draw_arc(c, r_mid, 0.0, TAU, 128, P.TRACK, ring_w, true)
	draw_arc(c, r_mid, _angle(target_min), _angle(target_max), 32, P.zone_color(zone_mix), ring_w, true)
	draw_arc(c, r_out, 0.0, TAU, 128, P.SLATE, 4.0, true)
	draw_arc(c, r_in, 0.0, TAU, 128, P.SLATE, 2.0, true)
	draw_circle(c, r_in - 1.0, P.SURFACE)

	# zero tick at the top and the ends of the range
	for v in [0.0, -max_value, max_value]:
		var ta := _angle(v)
		var d := Vector2(cos(ta), sin(ta))
		draw_line(c + d * r_out, c + d * (r_out + 4.0), P.STEEL, 2.0, true)

	var a := _angle(value)
	var dir := Vector2(cos(a), sin(a))
	var tip := c + dir * (r_in - 3.0)
	var head: float = clampf(r_in * 0.28, 12.0, 24.0)
	var base := tip - dir * head
	var side := Vector2(-dir.y, dir.x) * head * 0.55
	var pts := PackedVector2Array([tip, base + side, base - side])
	draw_colored_polygon(pts, P.CARROT)   # v0.7.0: carrot pointer with ink outline
	pts.append(tip)
	draw_polyline(pts, P.INK, 2.5, true)
