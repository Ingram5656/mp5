extends CanvasLayer
## View — whole-screen cover transition (v0.8.0), used when the app hands over to a game and back.
## A cocoa-ink circle closes in on the middle of the screen, the screens are swapped while it is shut,
## then it opens again. Clicks are blocked while it moves.

const P := preload("res://app_v0.8.4/scripts/views/palette.gd")

const CLOSE_TIME := 0.32
const OPEN_TIME := 0.38

const SHADER := """
shader_type canvas_item;
uniform float progress : hint_range(0.0, 1.0) = 0.0;   // 0 = open, 1 = shut
uniform vec2 rect_size = vec2(1152.0, 648.0);
uniform vec4 ink : source_color = vec4(0.37, 0.2, 0.06, 1.0);
void fragment() {
	vec2 p = UV * rect_size - rect_size * 0.5;
	float r = (length(rect_size * 0.5) + 6.0) * (1.0 - progress);
	float d = length(p) - r;
	COLOR = vec4(ink.rgb, ink.a * smoothstep(-1.5, 1.5, d));
}
"""

var _cover: ColorRect
var _mat: ShaderMaterial
var busy := false


func _ready() -> void:
	layer = 120
	_cover = ColorRect.new()
	_cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = SHADER
	_mat = ShaderMaterial.new()
	_mat.shader = sh
	_mat.set_shader_parameter("ink", P.INK)
	_mat.set_shader_parameter("progress", 0.0)
	_cover.material = _mat
	_cover.visible = false
	add_child(_cover)
	_cover.resized.connect(_on_resized)


func _on_resized() -> void:
	_mat.set_shader_parameter("rect_size", _cover.size)


## Close, call swap (which changes what is on screen), open again.
func play(swap: Callable) -> void:
	if busy:
		swap.call()
		return
	busy = true
	_on_resized()
	_cover.visible = true
	_cover.mouse_filter = Control.MOUSE_FILTER_STOP
	var t := create_tween()
	t.tween_method(_set_progress, 0.0, 1.0, CLOSE_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	await t.finished
	swap.call()
	await get_tree().process_frame   # let the new screen lay itself out before it is shown
	var t2 := create_tween()
	t2.tween_method(_set_progress, 1.0, 0.0, OPEN_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await t2.finished
	_cover.visible = false
	_cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	busy = false


func _set_progress(v: float) -> void:
	_mat.set_shader_parameter("progress", v)
