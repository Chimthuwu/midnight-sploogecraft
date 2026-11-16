extends Node3D
class_name VoxelPlayer

const PLAYER_HALF_EXTENTS := Vector3(0.32, 0.9, 0.32)
const WALK_SPEED := 5.0
const SPRINT_SPEED := 8.5
const JUMP_SPEED := 6.2
const GRAVITY := 20.0
const FIXED_STEP := 1.0 / 60.0
const COLLISION_EPSILON := 0.001
const LOOK_SENSITIVITY := 0.0022

@onready var camera: Camera3D = $Camera3D
@onready var viewmodel: Node3D = $Camera3D/Viewmodel
@onready var world = get_parent().get_node("VoxelWorld")

var velocity := Vector3.ZERO
var on_floor := false
var fixed_accumulator := 0.0
var spawned := false
var health := 100.0
var damage_cooldown := 0.0
var axis_collided := PackedByteArray([0, 0, 0])
var driven_vehicle: Vehicle
var nearby_vehicle: Vehicle


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _physics_process(delta: float) -> void:
	damage_cooldown = maxf(0.0, damage_cooldown - delta)
	if not spawned:
		if world.is_generated:
			position = world.get_city_spawn_position()
			spawned = true
		return
	if driven_vehicle != null:
		if not is_instance_valid(driven_vehicle):
			_exit_vehicle()
			return
		var forward := Vector3(sin(driven_vehicle.yaw), 0.0, cos(driven_vehicle.yaw))
		var desired := driven_vehicle.position - forward * 5.4 + Vector3(0.0, 0.7, 0.0)
		var follow: float = 1.0 - exp(-delta * 9.0)
		position = position.lerp(desired, follow)
		rotation.y = lerp_angle(rotation.y, driven_vehicle.yaw + PI, follow)
		nearby_vehicle = driven_vehicle
		return
	_update_nearby_vehicle()
	fixed_accumulator += delta
	var steps := 0
	while fixed_accumulator >= FIXED_STEP and steps < 4:
		_simulate_fixed_step(FIXED_STEP)
		fixed_accumulator -= FIXED_STEP
		steps += 1
	if steps == 4:
		fixed_accumulator = 0.0


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		_toggle_vehicle()
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotation.y -= event.relative.x * LOOK_SENSITIVITY
		camera.rotation.x = clampf(camera.rotation.x - event.relative.y * LOOK_SENSITIVITY, -1.52, 1.52)


func _update_nearby_vehicle() -> void:
	nearby_vehicle = null
	var best := 3.2
	for node in get_tree().get_nodes_in_group("vehicles"):
		var candidate := node as Vehicle
		if candidate == null or candidate.driven:
			continue
		var distance := position.distance_to(candidate.position)
		if distance < best:
			best = distance
			nearby_vehicle = candidate


func _toggle_vehicle() -> void:
	if not spawned:
		return
	if driven_vehicle != null:
		_exit_vehicle()
	elif nearby_vehicle != null:
		_enter_vehicle(nearby_vehicle)


func _enter_vehicle(vehicle: Vehicle) -> void:
	vehicle.set_driven(true)
	driven_vehicle = vehicle
	nearby_vehicle = vehicle
	velocity = Vector3.ZERO
	if viewmodel != null:
		viewmodel.visible = false


func _exit_vehicle() -> void:
	var vehicle := driven_vehicle
	driven_vehicle = null
	if not is_instance_valid(vehicle):
		return
	vehicle.set_driven(false)
	var side := vehicle.global_basis * Vector3(1.9, 0.0, 0.0)
	position = vehicle.position + Vector3(side.x, 0.0, side.z)
	rotation.y = vehicle.yaw + PI
	velocity = Vector3.ZERO
	if viewmodel != null:
		viewmodel.visible = true
	nearby_vehicle = vehicle


func _simulate_fixed_step(delta: float) -> void:
	var input_vector := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var local_direction := Vector3(input_vector.x, 0.0, input_vector.y)
	var move_direction := (global_basis * local_direction).normalized()
	var speed := SPRINT_SPEED if Input.is_action_pressed("sprint") else WALK_SPEED
	velocity.x = move_direction.x * speed
	velocity.z = move_direction.z * speed
	if on_floor and Input.is_action_just_pressed("jump"):
		velocity.y = JUMP_SPEED
	else:
		velocity.y -= GRAVITY * delta
	var was_on_floor := on_floor
	on_floor = false
	axis_collided.fill(0)
	var displacement := velocity * delta
	for axis in [0, 2, 1]:
		var amount := _sweep_axis(axis, displacement[axis])
		if axis != 1 and axis_collided[axis] != 0 and was_on_floor and absf(displacement[axis]) > 0.0:
			var saved_y := position.y
			var up_amount := _sweep_axis(1, 1.01)
			if up_amount >= 1.01 - COLLISION_EPSILON:
				position.y += up_amount
				axis_collided[axis] = 0
				amount = _sweep_axis(axis, displacement[axis])
				if axis_collided[axis] != 0:
					position.y = saved_y
					amount = 0.0
			else:
				position.y = saved_y
		position[axis] += amount
		if axis_collided[axis] != 0:
			velocity[axis] = 0.0
	if axis_collided[1] == 1:
		on_floor = true


func _sweep_axis(axis: int, motion: float) -> float:
	if absf(motion) < 0.000001:
		return 0.0
	var center := position + Vector3(0.0, PLAYER_HALF_EXTENTS.y, 0.0)
	var end_center := center
	end_center[axis] += motion
	var start_min := center - PLAYER_HALF_EXTENTS
	var end_min := end_center - PLAYER_HALF_EXTENTS
	var start_max := center + PLAYER_HALF_EXTENTS
	var end_max := end_center + PLAYER_HALF_EXTENTS
	var low := Vector3i(floori(minf(start_min.x, end_min.x)), floori(minf(start_min.y, end_min.y)), floori(minf(start_min.z, end_min.z)))
	var high := Vector3i(floori(maxf(start_max.x, end_max.x)), floori(maxf(start_max.y, end_max.y)), floori(maxf(start_max.z, end_max.z)))
	var allowed := motion
	for z in range(low.z, high.z + 1):
		for y in range(low.y, high.y + 1):
			for x in range(low.x, high.x + 1):
				var cell := Vector3i(x, y, z)
				if not world.is_solid(cell) or not _overlaps_other_axes(center, cell, axis):
					continue
				if motion > 0.0:
					var gap := float(cell[axis]) - (center[axis] + PLAYER_HALF_EXTENTS[axis])
					if gap >= -COLLISION_EPSILON and gap < allowed:
						allowed = maxf(0.0, gap - COLLISION_EPSILON)
						axis_collided[axis] = 1
				elif motion < 0.0:
					var gap := (center[axis] - PLAYER_HALF_EXTENTS[axis]) - float(cell[axis] + 1)
					if gap >= -COLLISION_EPSILON and -gap < -allowed:
						allowed = -maxf(0.0, gap - COLLISION_EPSILON)
						axis_collided[axis] = 1
	return allowed


func _overlaps_other_axes(center: Vector3, cell: Vector3i, ignored_axis: int) -> bool:
	for axis in range(3):
		if axis == ignored_axis:
			continue
		if center[axis] + PLAYER_HALF_EXTENTS[axis] <= float(cell[axis]) + COLLISION_EPSILON:
			return false
		if center[axis] - PLAYER_HALF_EXTENTS[axis] >= float(cell[axis] + 1) - COLLISION_EPSILON:
			return false
	return true


func _break_target_block() -> void:
	var hit := _voxel_raycast(7.0)
	if hit.is_empty():
		return
	world.set_block(hit["cell"], world.block_ids[&"air"])


func _place_target_block() -> void:
	var hit := _voxel_raycast(7.0)
	if hit.is_empty():
		return
	var place_cell: Vector3i = hit["previous_air"]
	if _player_overlaps_cell(place_cell):
		return
	var caster := get_parent().get_node_or_null("Lumencaster") as Lumencaster
	var block_name: StringName = caster.selected_projector_block if caster != null else &"concrete"
	var block_id: int = world.block_ids.get(block_name, world.block_ids[&"concrete"])
	world.set_block(place_cell, block_id)


func _voxel_raycast(max_distance: float) -> Dictionary:
	var origin := camera.global_position
	var direction := -camera.global_basis.z
	var last_air := Vector3i(-1, -1, -1)
	var steps := ceili(max_distance / 0.05)
	for step_index in range(1, steps + 1):
		var point := origin + direction * (float(step_index) * 0.05)
		var cell := Vector3i(floori(point.x), floori(point.y), floori(point.z))
		if not world._inside_world(cell):
			break
		if world.get_block_id(cell) != world.air_id:
			return {"cell": cell, "previous_air": last_air}
		last_air = cell
	return {}


func _player_overlaps_cell(cell: Vector3i) -> bool:
	var center := position + Vector3(0.0, PLAYER_HALF_EXTENTS.y, 0.0)
	var min_player := center - PLAYER_HALF_EXTENTS
	var max_player := center + PLAYER_HALF_EXTENTS
	return max_player.x > cell.x and min_player.x < cell.x + 1 and max_player.y > cell.y and min_player.y < cell.y + 1 and max_player.z > cell.z and min_player.z < cell.z + 1


func take_damage(amount: float) -> void:
	if damage_cooldown > 0.0 or amount <= 0.0:
		return
	health = maxf(0.0, health - amount)
	damage_cooldown = 0.7
