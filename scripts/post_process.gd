class_name PostProcess
extends CanvasLayer

# Screen-space cinematic post stack (bloom + chromatic aberration + grade +
# grain). Sits above the world but below the fog/letterbox overlay (layer 50)
# and the HUD (layer 60), so only the rendered world is processed.

const SHADER := preload("res://shaders/post_process.gdshader")

var rect: ColorRect
var mat: ShaderMaterial


func _ready() -> void:
	layer = 45
	mat = ShaderMaterial.new()
	mat.shader = SHADER
	rect = ColorRect.new()
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.material = mat
	add_child(rect)


func configure(params: Dictionary) -> void:
	for key in params:
		mat.set_shader_parameter(key, params[key])
