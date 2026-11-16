extends GloomEnemy
class_name Civilian

# Background pedestrian. Hostile is false, so the base chase/attack loop never
# engages; this class only owns wandering along a street lane.
var move_axis := 0
var fixed_coord := 0.0
var min_dist := 4.0
var max_dist := 124.0
var direction := 1.0

func _update_behavior(delta: float) -> void:
	var coord := position.x if move_axis == 0 else position.z
	var half := (max_dist - min_dist) * 0.5
	var next := coord + direction * move_speed * delta
	if (next - min_dist) * direction < 0.0 or (max_dist - next) * direction < 0.0:
		direction = -direction
		next = coord + direction * move_speed * delta
	if move_axis == 0:
		position.x = next
		position.z = fixed_coord
	else:
		position.z = next
		position.x = fixed_coord


func _create_placeholder_mesh() -> void:
	var mesh_instance := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.30
	mesh.height = 0.60
	mesh.radial_segments = 12
	mesh.rings = 6
	mesh_instance.mesh = mesh
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(0.36, 0.40, 0.46)
	mesh_instance.material_override = material
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mesh_instance)
