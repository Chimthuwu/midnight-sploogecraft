extends RefCounted
class_name BikeVisual

# Low-poly neon bike ported from the SKYJUMP3D three.js `makeBikeMesh` silhouette.
# Built from primitives so it stays consistent with the city's flat retro palette.

static func build(accent: Color) -> Node3D:
	var root := Node3D.new()
	root.name = "BikeVisual"
	var dark := _material(Color(0.055, 0.07, 0.10))
	var armor := _material(Color(0.11, 0.14, 0.19))
	var trim := _material(Color(0.17, 0.21, 0.28))
	var neon := _material(accent * 1.7)
	var headlight := _material(Color(1.8, 1.65, 1.1))
	var taillight := _material(Color(1.6, 0.05, 0.08))

	# Chunky low frame and angular nose fairing.
	_box(root, Vector3(0, 0.52, -0.05), Vector3(0.80, 0.32, 1.85), dark)
	_box(root, Vector3(0, 0.70, -0.15), Vector3(0.55, 0.28, 1.35), armor)
	_box(root, Vector3(0, 0.78, -0.60), Vector3(0.40, 0.18, 0.65), dark)
	_box(root, Vector3(0, 0.88, -0.39), Vector3(0.44, 0.28, 0.12), dark)
	_cone(root, Vector3(0, 0.62, 0.90), 0.55, 0.90, armor, true)
	for side in [-1.0, 1.0]:
		_box(root, Vector3(side * 0.20, 0.55, -0.05), Vector3(0.15, 0.38, 1.25), armor)
		_box(root, Vector3(side * 0.25, 0.58, -0.02), Vector3(0.04, 0.08, 0.98), trim)
		_box(root, Vector3(side * 0.52, 0.40, -0.78), Vector3(0.24, 0.30, 0.42), dark)

	# Wheels and steerable fork with twin headlights.
	for wheel_z in [-0.78, 0.88]:
		_cylinder(root, Vector3(0, 0.35, wheel_z), 0.35, 0.16, _material(Color(0.02, 0.02, 0.025)))
	_box(root, Vector3(0, 0.50, 0.95), Vector3(0.14, 0.55, 0.16), trim)
	_box(root, Vector3(0, 0.98, 0.95), Vector3(1.0, 0.09, 0.14), trim)
	for side in [-1.0, 1.0]:
		_box(root, Vector3(side * 0.50, 0.98, 0.95), Vector3(0.22, 0.12, 0.15), dark)
		_box(root, Vector3(side * 0.14, 0.72, 1.06), Vector3(0.30, 0.16, 0.10), headlight)
		_cylinder(root, Vector3(side * 0.52, 0.25, -0.85), 0.20, 0.06, neon)

	# Neon brow markers, exhaust glow and a compact rider silhouette.
	_box(root, Vector3(0, 0.98, 0.42), Vector3(0.20, 0.07, 0.10), neon)
	_box(root, Vector3(0, 0.98, -0.55), Vector3(0.20, 0.07, 0.10), taillight)
	_box(root, Vector3(0, 1.00, -0.02), Vector3(0.38, 0.44, 0.28), dark)
	_box(root, Vector3(0, 1.38, 0.06), Vector3(0.24, 0.24, 0.20), neon)
	for side in [-1.0, 1.0]:
		_box(root, Vector3(side * 0.22, 0.95, 0.25), Vector3(0.12, 0.32, 0.12), dark)
		_box(root, Vector3(side * 0.10, 0.58, 0.15), Vector3(0.14, 0.24, 0.22), armor)
	root.scale = Vector3(1.18, 1.18, 1.18)
	return root


static func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	return material


static func _box(parent: Node3D, center: Vector3, size: Vector3, material: Material) -> void:
	var instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	instance.mesh = mesh
	instance.position = center
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)


static func _cylinder(parent: Node3D, center: Vector3, radius: float, height: float, material: Material) -> void:
	var instance := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 12
	instance.mesh = mesh
	instance.position = center
	instance.rotation.z = PI * 0.5
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)


static func _cone(parent: Node3D, center: Vector3, radius: float, height: float, material: Material, face_forward: bool) -> void:
	var instance := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.0
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 8
	instance.mesh = mesh
	instance.position = center
	if face_forward:
		instance.rotation.x = PI * 0.5
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)
