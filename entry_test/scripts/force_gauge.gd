extends Control
## Vertical force bar: grey track, green target band, black triangle pointer on the left.

var value: float = 0.0
var max_value: float = 20.0
var target_min: float = 8.0
var target_max: float = 12.0
var unlocked: bool = false

const C_OUTLINE := Color("3a3f45")
const C_TRACK := Color("d5d9de")
const C_ZONE := Color("7fdc93")
const C_ZONE_DONE := Color("34c759")
const C_POINTER := Color("1f2328")

const BAR_W := 46.0


func _ready() -> void:
	custom_minimum_size = Vector2(200, 200)


func _y_for(v: float, top: float, bottom: float) -> float:
	var t: float = clampf(v / max_value, 0.0, 1.0)
	return lerpf(bottom, top, t)


func _draw() -> void:
	var h: float = size.y - 12.0
	var x := size.x / 2.0 - BAR_W / 2.0 + 10.0
	var top := 6.0
	var bottom := top + h
	var rect := Rect2(x, top, BAR_W, h)

	var track := StyleBoxFlat.new()
	track.bg_color = C_TRACK
	track.set_corner_radius_all(10)
	track.set_border_width_all(4)
	track.border_color = C_OUTLINE
	draw_style_box(track, rect)

	var y0 := _y_for(target_max, top, bottom)
	var y1 := _y_for(target_min, top, bottom)
	draw_rect(Rect2(x + 4.0, y0, BAR_W - 8.0, y1 - y0), C_ZONE_DONE if unlocked else C_ZONE)

	# pointer: triangle on the left, pointing right
	var py := _y_for(value, top, bottom)
	var tip := Vector2(x - 4.0, py)
	draw_colored_polygon(PackedVector2Array([tip, tip + Vector2(-22, -13), tip + Vector2(-22, 13)]), C_POINTER)
