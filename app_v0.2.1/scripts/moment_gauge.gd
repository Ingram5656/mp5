extends Control
## Moment ring: grey ring, green target arc near the top, black triangle pointer inside the ring.
## The value range [-max_value, +max_value] maps to -135..+135 degrees around the top (0 = top).

var value: float = 0.0
var max_value: float = 0.5
var target_min: float = 0.15
var target_max: float = 0.25
var unlocked: bool = false

const C_OUTLINE := Color("3a3f45")
const C_TRACK := Color("d5d9de")
const C_ZONE := Color("7fdc93")
const C_ZONE_DONE := Color("34c759")
const C_POINTER := Color("1f2328")
const SWEEP := 135.0


func _ready() -> void:
	if custom_minimum_size == Vector2.ZERO:
		custom_minimum_size = Vector2(200, 200)


## Godot draw_arc angle (radians, 0 = right, clockwise on screen) for a gauge value.
func _angle_for(v: float) -> float:
	var t: float = clampf(v / max_value, -1.0, 1.0)
	var from_top_deg := t * SWEEP
	return deg_to_rad(-90.0 + from_top_deg)


func _draw() -> void:
	var c := size / 2.0
	var r_out: float = min(size.x, size.y) / 2.0 - 6.0
	var ring_w := 30.0
	var r_mid := r_out - ring_w / 2.0
	var r_in := r_out - ring_w

	draw_arc(c, r_mid, 0.0, TAU, 128, C_TRACK, ring_w, true)
	draw_arc(c, r_mid, _angle_for(target_min), _angle_for(target_max), 32,
		C_ZONE_DONE if unlocked else C_ZONE, ring_w, true)
	draw_arc(c, r_out, 0.0, TAU, 128, C_OUTLINE, 4.0, true)
	draw_arc(c, r_in, 0.0, TAU, 128, C_OUTLINE, 3.0, true)
	draw_circle(c, r_in - 1.5, Color.WHITE)

	# pointer: triangle just inside the ring, pointing outward
	var a := _angle_for(value)
	var dir := Vector2(cos(a), sin(a))
	var tip := c + dir * (r_in - 4.0)
	var base := tip - dir * 24.0
	var side := Vector2(-dir.y, dir.x) * 13.0
	draw_colored_polygon(PackedVector2Array([tip, base + side, base - side]), C_POINTER)
