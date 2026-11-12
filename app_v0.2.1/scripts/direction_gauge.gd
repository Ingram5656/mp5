extends Control
## Direction dial: circle with crosshair, green target sector and a blue arrow.
## Angles are in degrees, 0 = right, counter-clockwise positive (screen up).

var value_deg: float = 0.0
var target_deg: float = 45.0
var tolerance_deg: float = 15.0
var unlocked: bool = false

const C_OUTLINE := Color("3a3f45")
const C_DASH := Color("9aa1a9")
const C_ZONE := Color("7fdc93")
const C_ZONE_DONE := Color("34c759")
const C_ARROW := Color("1f4fe0")


func _ready() -> void:
	if custom_minimum_size == Vector2.ZERO:
		custom_minimum_size = Vector2(200, 200)


func _to_screen(deg: float) -> Vector2:
	var a := deg_to_rad(deg)
	return Vector2(cos(a), -sin(a))


func _draw() -> void:
	var c := size / 2.0
	var r: float = min(size.x, size.y) / 2.0 - 6.0
	# white face
	draw_circle(c, r, Color.WHITE)
	# green target sector (pie slice)
	var pts := PackedVector2Array([c])
	var steps := 24
	var a0 := target_deg - tolerance_deg
	var a1 := target_deg + tolerance_deg
	for i in range(steps + 1):
		var d := lerpf(a0, a1, float(i) / steps)
		pts.append(c + _to_screen(d) * (r - 2.0))
	draw_colored_polygon(pts, C_ZONE_DONE if unlocked else C_ZONE)
	# dashed crosshair
	draw_dashed_line(c + Vector2(-r, 0), c + Vector2(r, 0), C_DASH, 2.0, 6.0)
	draw_dashed_line(c + Vector2(0, -r), c + Vector2(0, r), C_DASH, 2.0, 6.0)
	# outline
	draw_arc(c, r, 0.0, TAU, 96, C_OUTLINE, 5.0, true)
	# arrow
	var dir := _to_screen(value_deg)
	var tip := c + dir * (r * 0.78)
	var base := tip - dir * 16.0
	draw_line(c, base, C_ARROW, 7.0, true)
	var side := Vector2(-dir.y, dir.x) * 10.0
	draw_colored_polygon(PackedVector2Array([tip, base + side, base - side]), C_ARROW)
	draw_circle(c, 9.0, C_OUTLINE)
