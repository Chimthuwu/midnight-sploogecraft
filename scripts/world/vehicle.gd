extends CharacterBody3D
class_name Vehicle

# Driveable / traffic vehicle actor. Traffic follows the intersection graph and
# turns at junctions; the player gets arcade throttle/brake/steer with a
# third-person camera driven from the player controller.
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
const CITY_GROUND := 2
const GRID_STEP := 20
const GRID_LINE := 9
const GRID_COUNT := 6
const LANE_OFFSET := 1.5
const MAX_DRIVE_SPEED := 17.0
const MAX_REVERSE_SPEED := -5.0
const ACCELERATION := 11.0
const BRAKING := 16.0
const HANDBRAKE := 22.0
const STEER_RATE := 2.3

var kind: StringName = &"car"
var is_traffic := true
var speed := 0.0
var yaw := 0.0
var driven := false
var visual: Node3D
var model_index := 0
var cruise_speed := 9.0
var current_node := Vector2i.ZERO
var next_node := Vector2i.ZERO
var previous_node := Vector2i(-1, -1)
var target_point := Vector3.ZERO
var turn_timer := 0.0

func _ready() -> void:
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	add_to_group("vehicles")


static func node_position(node: Vector2i) -> Vector2:
	return Vector2(float(GRID_LINE + node.x * GRID_STEP), float(GRID_LINE + node.y * GRID_STEP))


static func lane_point(from: Vector2i, to: Vector2i) -> Vector3:
	var a := node_position(from)
	var b := node_position(to)
	var direction := b - a
	var offset := Vector2.ZERO
	if direction.x > 0.0:
		offset = Vector2(0.0, LANE_OFFSET)
	elif direction.x < 0.0:
		offset = Vector2(0.0, -LANE_OFFSET)
	elif direction.y > 0.0:
		offset = Vector2(-LANE_OFFSET, 0.0)
	else:
		offset = Vector2(LANE_OFFSET, 0.0)
	var center := a + offset
	return Vector3(center.x, float(CITY_GROUND) + 1.05, center.y)


func configure_traffic(from: Vector2i, to: Vector2i, vehicle_speed: float, index: int, bike: bool) -> void:
	current_node = from
	next_node = to
	previous_node = from
	cruise_speed = vehicle_speed
	is_traffic = true
	model_index = index
	kind = &"bike" if bike else &"car"
	_build_visual()
	target_point = lane_point(from, to)
	position = target_point
	var direction := node_position(to) - node_position(from)
	yaw = atan2(direction.x, direction.y)
	visual.rotation.y = yaw


func configure_parked(at: Vector3, facing_yaw: float, index: int, bike: bool) -> void:
	cruise_speed = 0.0
	is_traffic = false
	model_index = index
	kind = &"bike" if bike else &"car"
	_build_visual()
	position = at
	yaw = facing_yaw
	visual.rotation.y = yaw


func _build_visual() -> void:
	if visual != null:
		visual.queue_free()
	visual = BikeVisual.build(BIKE_ACCENTS[model_index % BIKE_ACCENTS.size()]) if kind == &"bike" else _build_car(model_index)
	add_child(visual)
	for existing in get_children():
		if existing is CollisionShape3D:
			existing.queue_free()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	if kind == &"bike":
		box.size = Vector3(0.85, 1.4, 2.2)
		shape.position = Vector3(0, 0.7, 0)
	else:
		var source_mesh: Mesh = CAR_MODELS[model_index % CAR_MODELS.size()]
		var aabb: AABB = source_mesh.get_aabb()
		var factor: float = TARGET_CAR_LENGTH / maxf(aabb.size.z, 0.01)
		box.size = Vector3(aabb.size.x * factor * 0.92, aabb.size.y * factor * 0.82, TARGET_CAR_LENGTH * 0.96)
		shape.position = Vector3(0, aabb.size.y * factor * 0.5, 0)
	shape.shape = box
	add_child(shape)


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
		velocity = Vector3.ZERO
	if visual != null:
		visual.rotation.y = yaw
	var forward := Vector3(sin(yaw), 0.0, cos(yaw))
	velocity = forward * speed
	move_and_slide()
	if get_slide_collision_count() > 0 and absf(speed) > 1.0:
		speed *= 0.82


func _drive_traffic(delta: float) -> void:
	var to_target := target_point - position
	to_target.y = 0.0
	if to_target.length() < 2.0:
		_advance_node()
		to_target = target_point - position
		to_target.y = 0.0
	var desired_yaw := atan2(to_target.x, to_target.z)
	var error := absf(angle_difference(yaw, desired_yaw))
	yaw = lerp_angle(yaw, desired_yaw, clampf(delta * 2.8, 0.0, 1.0))
	var target_speed := cruise_speed * (1.0 - 0.6 * clampf(error / 1.2, 0.0, 1.0))
	if _vehicle_ahead():
		target_speed = minf(target_speed, 3.0)
	speed = move_toward(speed, target_speed, 7.0 * delta)
	turn_timer += delta


func _vehicle_ahead() -> bool:
	var forward := Vector3(sin(yaw), 0.0, cos(yaw))
	for node in get_tree().get_nodes_in_group("vehicles"):
		var other := node as Vehicle
		if other == null or other == self:
			continue
		var offset := other.position - position
		var distance := offset.length()
		if distance > 5.0 or distance < 0.01:
			continue
		if forward.dot(offset.normalized()) > 0.75:
			return true
	return false


func _advance_node() -> void:
	previous_node = current_node
	current_node = next_node
	var options: Array[Vector2i] = []
	var straight := next_node + (next_node - previous_node)
	var directions := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	for direction in directions:
		var candidate: Vector2i = next_node + direction
		if candidate.x < 0 or candidate.x >= GRID_COUNT or candidate.y < 0 or candidate.y >= GRID_COUNT:
			continue
		if candidate == previous_node and straight != previous_node:
			continue
		options.append(candidate)
	if options.is_empty():
		options.append(previous_node)
	var chosen := straight if options.has(straight) else options[randi() % options.size()]
	if randi() % 100 < 45 and options.size() > 1:
		chosen = options[randi() % options.size()]
	next_node = chosen
	target_point = lane_point(current_node, next_node)


func _drive_player(delta: float) -> void:
	var throttle := Input.get_axis("move_back", "move_forward")
	var target_speed := 0.0
	if throttle > 0.0:
		target_speed = MAX_DRIVE_SPEED
	elif throttle < 0.0:
		target_speed = MAX_REVERSE_SPEED if speed <= 0.5 else 0.0
	var braking := throttle < 0.0 or (absf(throttle) < 0.01 and absf(speed) > 0.1)
	var rate := BRAKING if braking else ACCELERATION
	speed = move_toward(speed, target_speed, rate * delta)
	if Input.is_action_pressed("jump"):
		speed = move_toward(speed, 0.0, HANDBRAKE * delta)
	var steer := Input.get_axis("move_left", "move_right")
	var grip := clampf(absf(speed) / 5.0, 0.0, 1.0)
	# Vehicle forward is +Z while the chase camera looks down -Z mirrored:
	# subtract so pressing right turns the car right on screen.
	yaw -= steer * STEER_RATE * grip * delta


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
