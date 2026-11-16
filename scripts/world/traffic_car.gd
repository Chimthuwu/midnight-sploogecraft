extends CharacterBody3D
class_name TrafficCar

# Non-voxel traffic actor. Cars are real meshes with real physics so they read
# correctly in the city; the voxel blockout only carries the streets they drive on.
const CITY_LIMIT := 124.0
const BODY_COLORS := [
	Color(0.85, 0.12, 0.16), Color(0.10, 0.45, 0.85), Color(0.92, 0.74, 0.14),
	Color(0.16, 0.72, 0.42), Color(0.74, 0.26, 0.82), Color(0.88, 0.90, 0.94)
]

var move_axis := 0
var fixed_coord := 0.0
var min_dist := 6.0
var max_dist := 122.0
var direction := 1.0
var speed := 9.0
var visual_root: Node3D

func _ready() -> void:
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.32
	capsule.height = 0.7
	shape.shape = capsule
	shape.position = Vector3(0, 0.35, 0)
	add_child(shape)


# Called by the director before the car enters the scene tree.
func configure(axis: int, coord: float, dir: float, car_speed: float, color_index: int) -> void:
	move_axis = axis
	fixed_coord = coord
	direction = dir
	speed = car_speed
	visual_root = Node3D.new()
	visual_root.name = "Visual"
	add_child(visual_root)
	visual_root.rotation.y = -PI * 0.5 if axis == 1 else 0.0
	if direction < 0.0:
		visual_root.rotation.y += PI
	var body_color: Color = BODY_COLORS[color_index % BODY_COLORS.size()]
	_box(visual_root, Vector3(0, 0.24, 0), Vector3(1.9, 0.34, 0.95), _material(body_color))
	_box(visual_root, Vector3(-0.08, 0.52, 0), Vector3(1.15, 0.30, 0.85), _material(body_color.darkened(0.5)))
	_box(visual_root, Vector3(0.36, 0.53, 0), Vector3(0.55, 0.18, 0.80), _material(Color(0.04, 0.09, 0.15)))
	for wheel_x in [-0.62, 0.62]:
		for wheel_z in [-0.50, 0.50]:
			_box(visual_root, Vector3(wheel_x, 0.12, wheel_z), Vector3(0.34, 0.24, 0.12), _material(Color(0.025, 0.025, 0.03)))
	for light_z in [-0.32, 0.32]:
		_box(visual_root, Vector3(0.97, 0.27, light_z), Vector3(0.06, 0.12, 0.18), _material(Color(1.8, 1.55, 0.95)))
		_box(visual_root, Vector3(-0.97, 0.27, light_z), Vector3(0.06, 0.10, 0.18), _material(Color(1.5, 0.06, 0.03)))


func _physics_process(delta: float) -> void:
	var motion := Vector3.ZERO
	if move_axis == 0:
		motion.x = direction * speed * delta
	else:
		motion.z = direction * speed * delta
	var collision := move_and_collide(motion)
	var out_of_bounds := false
	if move_axis == 0:
		out_of_bounds = position.x < 4.0 or position.x > CITY_LIMIT
	else:
		out_of_bounds = position.z < 4.0 or position.z > CITY_LIMIT
	if collision != null or out_of_bounds:
		direction = -direction
		if visual_root != null:
			visual_root.rotation.y += PI


func _box(parent: Node3D, center: Vector3, size: Vector3, material: Material) -> void:
	var instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	instance.mesh = mesh
	instance.position = center
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)


func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	return material
