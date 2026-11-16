extends CanvasLayer

const GRADE_SHADER := preload("res://shaders/screen_grade.gdshader")

@export var vignette_strength := 0.55
@export var grain_strength := 0.028


func _ready() -> void:
	layer = 0
	var grade := ColorRect.new()
	grade.name = "GradeRect"
	grade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	grade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	material.shader = GRADE_SHADER
	material.set_shader_parameter("vignette_strength", vignette_strength)
	material.set_shader_parameter("grain_strength", grain_strength)
	grade.material = material
	add_child(grade)
