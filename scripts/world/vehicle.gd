extends CharacterBody3D
class_name Vehicle

# Driveable / traffic vehicle actor. Cars use imported PSX low-poly meshes,
# bikes use the ported SKYJUMP3D silhouette; both share arcade driving physics.
const CAR_MODELS := [
	preload("res://assets/vehicles/psx/car01/Car.obj"),
	preload("res://assets/vehicles/psx/car03/Car3.obj"),
	preload("res://assets/vehicles/psx/car04/Car4.obj"),
	preload("res://assets/vehicles/psx/car05/Car5.obj"),
	preload("res://assets/vehicles/psx/car05/Car5_Police.obj"),
	preload("res://assets/vehicles/psx/car05/Car5_Taxi.obj"),
	preload("res://assets/vehicles/psx/car06/Car6.obj")
]
const BIKE_ACCENTS := [Color(0.22, 1.0, 1.0), Color(0.30, 1.0, 0.72), Color(1.0, 0.32, 0.85)]
const UNDERGLOW_COLORS := [Color(0.10, 0.90, 1.0), Color(1.0, 0.12, 0.55), Color(0.60, 0.25, 1.0)]
const TARGET_CAR_LENGTH := 4.9
const MAX_DRIVE_SPEED := 16.0
const MAX_REVERSE_SPEED := -5.0
const ACCELERATION := 9.0
const STEER_RATE := 2.0
const CITY_LIMIT := 124.0

var kind: StringName = &"car"
var is_traffic := true
var move_axis := 0
var lane := 0.0
var direction := 1.0
var cruise_speed := 9.0
var speed := 0.0
var yaw := 0.0
var driven := false
var visual: Node3D
var model_index := 0

func _ready() -> void:
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	add_to_group("vehicles")


func configure(axis: int, lane_coord: float, dir: float, vehicle_speed: float, index: int, traffic := true, bike := false) -> void:
	move_axis = axis
	lane = lane_coord
	direction = dir
	cruise_speed = vehicle_speed
	is_traffic = traffic
	model_index = index
	kind = &"bike" if bike else &"car"
	visual = BikeVisual.build(BIKE_ACCENTS[index % BIKE_ACCENTS.size()]) if bike else _build_car(index)
	add_child(visual)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	if bike:
		box.size = Vector3(0.85, 1.4, 2.2)
		shape.position = Vector3(0, 0.7, 0)
	else:
		var length: float = TARGET_CAR_LENGTH
		var width: float = 2.3
		var height: float = 1.7
		var source_mesh: Mesh = CAR_MODELS[index % CAR_MODELS.size()]
		var aabb: AABB = source_mesh.get_aabb()
		var factor: float = length / maxf(aabb.size.z, 0.01)
		width = aabb.size.x * factor
		height = aabb.size.y * factor
		box.size = Vector3(width * 0.92, height * 0.82, length * 0.96)
		shape.position = Vector3(0, height * 0.5, 0)
	shape.shape = box
	add_child(shape)
	yaw = _heading_for(axis, dir)
	visual.rotation.y = yaw


func _build_car(index: int) -> Node3D:
	var root := Node3D.new()
	root.name = "CarVisual"
	var source_mesh: Mesh = CAR_MODELS[index % CAR_MODELS.size()]
	var aabb: AABB = source_mesh.get_aabb()
	var factor: float = TARGET_CAR_LENGTH / maxf(aabb.size.z, 0.01)
	var instance := MeshInstance3D.new()
	instance.mesh = source_mesh
	instance.scale = Vector3(factor, factor, factor)
	instance.position = Vector3(-aabb.get_center().x * factor, -aabb.position.y * factor, -aabb.get_center().z * factor)
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(instance)
	var half_length := TARGET_CAR_LENGTH * 0.5
	var car_width: float = aabb.size.x * factor
	var car_height: float = aabb.size.y * factor
	var underglow: Color = UNDERGLOW_COLORS[index % UNDERGLOW_COLORS.size()]
	for side in [-0.75, 0.75]:
		_box(root, Vector3(side, 0.55, half_length - 0.08), Vector3(0.34, 0.14, 0.08), _material(Color(1.9, 1.7, 1.15)))
		_box(root, Vector3(side, 0.55, -half_length + 0.08), Vector3(0.34, 0.12, 0.08), _material(Color(1.6, 0.06, 0.04)))
	for side in [-1.0, 1.0]:
		_box(root, Vector3(side * car_width * 0.42, 0.16, 0.0), Vector3(0.07, 0.06, TARGET_CAR_LENGTH * 0.72), _material(underglow * 1.8))
		_box(root, Vector3(side * car_width * 0.42, car_height * 0.92, 0.0), Vector3(0.05, 0.05, TARGET_CAR_LENGTH * 0.66), _material(underglow * 1.6))
	return root


func _physics_process(delta: float) -> void:
	if driven:
		_drive_player(delta)
	elif is_traffic:
		_drive_traffic(delta)
	else:
		speed = 0.0
	if visual != null:
		visual.rotation.y = yaw
	var motion: Vector3
	if move_axis == 0:
		motion = Vector3(direction * speed, 0.0, 0.0)
	else:
		motion = Vector3(0.0, 0.0, direction * speed)
	var collision := move_and_collide(motion * delta)
	if collision != null:
		if driven:
			speed *= 0.25
		else:
			direction = -direction
			yaw = _heading_for(move_axis, direction)
	var position_axis := position.x if move_axis == 0 else position.z
	if not driven and (position_axis < 4.0 or position_axis > CITY_LIMIT):
		direction = -direction
		yaw = _heading_for(move_axis, direction)


func _drive_traffic(delta: float) -> void:
	var target := _heading_for(move_axis, direction)
	yaw = lerp_angle(yaw, target, clampf(delta * 5.0, 0.0, 1.0))
	speed = cruise_speed


func _drive_player(delta: float) -> void:
	var throttle := 0.0
	if Input.is_action_pressed("move_forward"):
		throttle += 1.0
	if Input.is_action_pressed("move_back"):
		throttle -= 1.0
	var target_speed := MAX_DRIVE_SPEED if throttle > 0.0 else (MAX_REVERSE_SPEED if throttle < 0.0 else 0.0)
	speed = move_toward(speed, target_speed, ACCELERATION * delta)
	var steer := Input.get_axis("move_left", "move_right")
	var grip := clampf(absf(speed) / 4.0, 0.0, 1.0)
	yaw += steer * STEER_RATE * grip * signf(speed) * delta


func _heading_for(axis: int, dir: float) -> float:
	if axis == 0:
		return PI * 0.5 if dir > 0.0 else -PI * 0.5
	return 0.0 if dir > 0.0 else PI


func set_driven(value: bool) -> void:
	driven = value
	speed = 0.0
	if value:
		is_traffic = false


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
