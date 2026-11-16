extends RefCounted
class_name Vfx

static func _fade_out(node: Node3D, material: StandardMaterial3D, lifetime: float) -> void:
	var tween := node.create_tween()
	tween.set_parallel(true)
	tween.tween_property(material, "albedo_color:a", 0.0, lifetime)
	tween.tween_property(material, "emission_energy_multiplier", 0.0, lifetime)
	tween.chain().tween_callback(node.queue_free)


# A fading hitscan tracer drawn from the muzzle to the impact point.
static func beam(parent: Node3D, from: Vector3, to: Vector3, color: Color, width := 0.05, lifetime := 0.14, glow := 7.0) -> void:
	var length := from.distance_to(to)
	if parent == null or not parent.is_inside_tree() or length < 0.05:
		return
	var box := BoxMesh.new()
	box.size = Vector3(width, width, length)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = glow
	var instance := MeshInstance3D.new()
	instance.mesh = box
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)
	instance.global_position = (from + to) * 0.5
	var axis := (to - from).normalized()
	instance.look_at(to, Vector3.RIGHT if absf(axis.y) > 0.99 else Vector3.UP)
	_fade_out(instance, material, lifetime)


# A vertical shaft of light used as the Beacon's planted-signal pulse.
static func pillar(parent: Node3D, at: Vector3, color: Color, height := 4.0, lifetime := 1.4, radius := 0.22) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var box := BoxMesh.new()
	box.size = Vector3(radius, height, radius)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(color.r, color.g, color.b, 0.55)
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 4.0
	var instance := MeshInstance3D.new()
	instance.mesh = box
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)
	instance.global_position = at + Vector3.UP * height * 0.5
	_fade_out(instance, material, lifetime)


# A glowing projectile head with a GPU-driven ember trail, moved by the caller.
static func flare_projectile(parent: Node3D, at: Vector3, color: Color) -> Node3D:
	if parent == null or not parent.is_inside_tree():
		return null
	var body := Node3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.09
	sphere.height = 0.18
	sphere.radial_segments = 10
	sphere.rings = 5
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 8.0
	var head := MeshInstance3D.new()
	head.mesh = sphere
	head.material_override = material
	head.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.add_child(head)
	var trail := GPUParticles3D.new()
	trail.amount = 16
	trail.lifetime = 0.3
	trail.local_coords = false
	trail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	trail.visibility_aabb = AABB(Vector3(-1.0, -1.0, -1.0), Vector3(2.0, 2.0, 2.0))
	var process := ParticleProcessMaterial.new()
	process.direction = Vector3.UP
	process.spread = 180.0
	process.initial_velocity_min = 0.05
	process.initial_velocity_max = 0.35
	process.gravity = Vector3.ZERO
	process.scale_min = 0.4
	process.scale_max = 0.9
	process.color = color
	trail.process_material = process
	var ember := SphereMesh.new()
	ember.radius = 0.035
	ember.height = 0.07
	ember.radial_segments = 6
	ember.rings = 3
	var ember_material := StandardMaterial3D.new()
	ember_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ember_material.albedo_color = color
	ember_material.emission_enabled = true
	ember_material.emission = color
	ember_material.emission_energy_multiplier = 5.0
	ember.material = ember_material
	trail.draw_pass_1 = ember
	body.add_child(trail)
	parent.add_child(body)
	body.global_position = at
	trail.emitting = true
	return body


static func burst(parent: Node3D, at: Vector3, color: Color, direction := Vector3.UP, count := 10, speed := 4.0, size := 0.055, lifetime := 0.35, glow := 5.0) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var particles := GPUParticles3D.new()
	particles.amount = count
	particles.lifetime = lifetime
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	particles.visibility_aabb = AABB(Vector3(-2.0, -2.0, -2.0), Vector3(4.0, 4.0, 4.0))
	var process := ParticleProcessMaterial.new()
	process.direction = direction
	process.spread = 55.0
	process.initial_velocity_min = speed * 0.35
	process.initial_velocity_max = speed
	process.gravity = Vector3(0.0, -9.8, 0.0)
	process.damping_min = 1.0
	process.damping_max = 2.0
	process.scale_min = 0.6
	process.scale_max = 1.4
	process.color = color
	particles.process_material = process
	var particle_mesh := SphereMesh.new()
	particle_mesh.radius = size
	particle_mesh.height = size * 2.0
	particle_mesh.radial_segments = 6
	particle_mesh.rings = 3
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = glow
	particle_mesh.material = material
	particles.draw_pass_1 = particle_mesh
	particles.finished.connect(particles.queue_free)
	parent.add_child(particles)
	particles.global_position = at
	particles.emitting = true
