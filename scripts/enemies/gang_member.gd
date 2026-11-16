extends GloomEnemy
class_name GangMember

# Hostile street gang threat. Inherits the base chase + melee loop and overrides
# only the silhouette so the gang reads as a different faction than the horror
# creatures. No dissolve: gang members stay solid until killed.
var accent_color := Color(0.85, 0.12, 0.10)

func _create_placeholder_mesh() -> void:
	var visual_root := Node3D.new()
	visual_root.name = "Visual"
	add_child(visual_root)
	var body := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.44
	sphere.height = 1.0
	sphere.radial_segments = 12
	sphere.rings = 6
	body.mesh = sphere
	var body_material := StandardMaterial3D.new()
	body_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	body_material.albedo_color = Color(0.09, 0.09, 0.11)
	body_material.emission_enabled = true
	body_material.emission = Color(0.05, 0.05, 0.06)
	body_material.emission_energy_multiplier = 0.6
	body.material_override = body_material
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visual_root.add_child(body)
	for eye_offset in [Vector3(-0.14, 0.16, -0.42), Vector3(0.14, 0.16, -0.42)]:
		var eye := MeshInstance3D.new()
		var eye_mesh := SphereMesh.new()
		eye_mesh.radius = 0.07
		eye_mesh.height = 0.14
		eye_mesh.radial_segments = 8
		eye_mesh.rings = 4
		eye.mesh = eye_mesh
		var eye_material := StandardMaterial3D.new()
		eye_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		eye_material.albedo_color = Color(1.0, 0.12, 0.08)
		eye_material.emission_enabled = true
		eye_material.emission = accent_color
		eye_material.emission_energy_multiplier = 8.0
		eye.material_override = eye_material
		eye.position = eye_offset
		eye.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		visual_root.add_child(eye)
