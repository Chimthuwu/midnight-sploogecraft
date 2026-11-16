extends GloomEnemy
class_name Gloomling

var visual_root: Node3D
var bob_time := 0.0


func _should_dissolve(cell: Vector3i) -> bool:
	return world.get_light_level(cell) >= dissolve_light_level or world.get_flashlight_level_at(position + Vector3.UP * 0.5) >= 0.65


func _process(delta: float) -> void:
	bob_time += delta
	if visual_root != null:
		visual_root.position.y = sin(bob_time * 4.2) * 0.07
	super._process(delta)


func _create_placeholder_mesh() -> void:
	visual_root = Node3D.new()
	visual_root.name = "Visual"
	add_child(visual_root)
	var body := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.34
	sphere.height = 0.72
	sphere.radial_segments = 12
	sphere.rings = 6
	body.mesh = sphere
	var body_material := StandardMaterial3D.new()
	body_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	body_material.albedo_color = Color(0.035, 0.03, 0.045)
	body_material.emission_enabled = true
	body_material.emission = Color(0.12, 0.02, 0.18)
	body_material.emission_energy_multiplier = 0.8
	body.material_override = body_material
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visual_root.add_child(body)
	for eye_offset in [Vector3(-0.09, 0.07, -0.30), Vector3(0.09, 0.07, -0.30)]:
		var eye := MeshInstance3D.new()
		var eye_mesh := SphereMesh.new()
		eye_mesh.radius = 0.042
		eye_mesh.height = 0.084
		eye_mesh.radial_segments = 8
		eye_mesh.rings = 4
		eye.mesh = eye_mesh
		var eye_material := StandardMaterial3D.new()
		eye_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		eye_material.albedo_color = Color(1.0, 0.12, 0.18)
		eye_material.emission_enabled = true
		eye_material.emission = Color(1.0, 0.08, 0.15)
		eye_material.emission_energy_multiplier = 6.0
		eye.material_override = eye_material
		eye.position = eye_offset
		eye.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		visual_root.add_child(eye)


func _on_dissolve() -> void:
	Vfx.burst(get_parent() as Node3D, global_position + Vector3.UP * 0.2, Color(0.07, 0.03, 0.10), Vector3.UP, 18, 1.8, 0.11, 0.75, 0.25)
