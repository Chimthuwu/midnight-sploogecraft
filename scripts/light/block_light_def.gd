class_name BlockLightDef
extends Resource

@export var block_id: StringName
@export_range(1, 15, 1) var attenuation: int = 1
@export var albedo: Color = Color.WHITE

@export_range(0, 15, 1) var emitted_light: int = 0
# Visual-only emission: glows in the dark without adding a light-propagation source.
@export var glow_only := false

@export var rotted_variant_id: StringName = &""
@export var is_rotted := false
