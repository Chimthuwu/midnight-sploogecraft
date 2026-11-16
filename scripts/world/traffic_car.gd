extends CharacterBody3D
class_name TrafficCar

# Non-voxel traffic actor. Cars are real meshes with real physics so they read
# correctly in the city; the voxel blockout only carries the streets they drive on.
const CITY_GROUND := 2

var move_axis := 0
var fixed_coord := 0.0
var min_dist := 6.0
var max_dist := 122.0
var direction := 1.0
var speed := 9.0

func _ready() -> void:
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	var body := BoxMesh.new()
	body.size = Vector3(1.8, 0.34, 0.95)
	var body_instance := MeshInstance3D.new()
	body_instance.mesh = body
	body_instance.position = Vector3(0, 0.17, 0)
	body_instance.material_override = _make_material(Color(0.10, 0.10, 0.12))
	add_child(body_instance)
	var cabin := BoxMesh.new()
	cabin.size = Vector3(1.4, 0.30, 0.85)
	var cabin_instance := MeshInstance3D.new()
	cabin_instance.mesh = cabin
	cabin_instance.position = Vector3(0, 0.44, 0)
	cabin_instance.material_override = _make_material(Color(0.16, 0.16, 0.19))
	add_child(cabin_instance)
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.32
	capsule.height = 0.7
	shape.shape = capsule
	shape.position = Vector3(0, 0.35, 0)
	add_child(shape)

func _physics_process(delta: float) -> void:
	var motion := Vector3.ZERO
	if move_axis == 0:
		motion.x = direction * speed * delta
	else:
		motion.z = direction * speed * delta
	var collision := move_and_collide(motion)
	if collision != null:
		direction = -direction

func _make_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	return material
