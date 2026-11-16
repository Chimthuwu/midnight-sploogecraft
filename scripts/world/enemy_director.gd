extends Node
class_name EnemyDirector

const CONFIG: EnemyConfig = preload("res://data/world/enemy_config.tres")
const GLOOM_CONFIG: GloomConfig = preload("res://data/world/gloom_config.tres")
const GANG_SCRIPT: GDScript = preload("res://scripts/enemies/gang_member.gd")
const COP_SCRIPT: GDScript = preload("res://scripts/enemies/police_officer.gd")
const CIVILIAN_SCRIPT: GDScript = preload("res://scripts/enemies/civilian.gd")
const LAMP_EATER_SCRIPT: GDScript = preload("res://scripts/enemies/lamp_eater.gd")

const CITY_GROUND := 2
const MAX_CARS := 10

var world: VoxelWorld
var gloom: GloomManager
var player: VoxelPlayer
var spawn_timer := 0.0
var rng := RandomNumberGenerator.new()
var chunk_cooldowns: Dictionary = {}
var traffic_cars: Array[Node] = []
var wanted_timer := 0.0
var traffic_timer := 0.0
var parked_spawned := false

func _ready() -> void:
	world = get_parent().get_node("VoxelWorld") as VoxelWorld
	gloom = get_parent().get_node("GloomManager") as GloomManager
	player = get_parent().get_node("Player") as VoxelPlayer
	var caster := player.get_node_or_null("Lumencaster") as Lumencaster
	if caster != null:
		caster.fired.connect(_on_player_fired)
	rng.randomize()

func _process(delta: float) -> void:
	if not world.is_generated or not player.spawned:
		return
	if not parked_spawned:
		parked_spawned = true
		_spawn_parked_vehicles()
	_update_traffic(delta)
	_despawn_traffic()
	_update_wanted(delta)
	spawn_timer += delta
	for key in chunk_cooldowns.keys():
		chunk_cooldowns[key] = maxf(0.0, float(chunk_cooldowns[key]) - delta)
	if spawn_timer < CONFIG.spawn_tick_seconds:
		return
	spawn_timer = 0.0
	_spawn_from_gloom()
	if rng.randf() < 0.25:
		_spawn_civilian()

func _update_traffic(delta: float) -> void:
	traffic_timer += delta
	if traffic_timer < 2.0:
		return
	traffic_timer = 0.0
	_spawn_traffic()

func _spawn_traffic() -> void:
	if len(traffic_cars) >= MAX_CARS:
		return
	var move_axis := rng.randi_range(0, 1)
	var line := 8 + 16 * rng.randi_range(0, 6)
	var dir := 1.0 if rng.randf() < 0.5 else -1.0
	var bike := rng.randf() < 0.22
	# Two lanes per road, centred inside the three-block asphalt strip (7, 8, 9).
	var lane_center := float(line) + (-0.5 if dir > 0.0 else 0.5)
	var player_axis := player.position.x if move_axis == 0 else player.position.z
	var along := clampf(player_axis + rng.randf_range(-26.0, 26.0), 6.0, 122.0)
	var model_index := rng.randi_range(0, 6)
	var vehicle_speed := rng.randf_range(9.0, 13.0) if bike else rng.randf_range(7.0, 11.0)
	var car := Vehicle.new()
	car.configure(move_axis, lane_center, dir, vehicle_speed, model_index, true, bike)
	if move_axis == 0:
		car.position = Vector3(along, float(CITY_GROUND) + 1.05, lane_center)
	else:
		car.position = Vector3(lane_center, float(CITY_GROUND) + 1.05, along)
	get_parent().add_child(car)
	traffic_cars.append(car)


# A few stationary vehicles near the spawn intersection so the player can
# actually walk up and drive one without chasing moving traffic.
func _spawn_parked_vehicles() -> void:
	_spawn_parked(0, 8.5, 14.5, false, 4)
	_spawn_parked(0, 14.5, 8.5, false, 5)
	_spawn_parked(1, 8.5, 20.5, true, 0)


func _spawn_parked(axis: int, x: float, z: float, bike: bool, model_index: int) -> void:
	var vehicle := Vehicle.new()
	vehicle.configure(axis, x if axis == 1 else z, 1.0, 0.0, model_index, false, bike)
	vehicle.position = Vector3(x, float(CITY_GROUND) + 1.05, z)
	get_parent().add_child(vehicle)

func _despawn_traffic() -> void:
	var keep: Array[Node] = []
	for car in traffic_cars:
		if is_instance_valid(car) and player.position.distance_to(car.position) <= 80.0:
			keep.append(car)
	traffic_cars = keep

func _update_wanted(delta: float) -> void:
	if wanted_timer > 0.0:
		wanted_timer -= delta
		if wanted_timer > 0.0:
			return
		wanted_timer = 0.0
		_spawn_cops()

func _on_player_fired(_cartridge_id: StringName, kick: float) -> void:
	wanted_timer = 5.0

func _spawn_cops() -> void:
	var cops := 0
	for enemy in get_tree().get_nodes_in_group("enemies"):
		var candidate := enemy as GloomEnemy
		if candidate is PoliceOfficer:
			cops += 1
	if cops >= 2:
		return
	var cop: PoliceOfficer = COP_SCRIPT.new()
	cop.move_speed = CONFIG.police_speed
	cop.max_health = CONFIG.police_health
	cop.touch_damage = CONFIG.police_damage
	cop.attack_range = CONFIG.police_attack_range
	cop.position = player.position + Vector3(rng.randf_range(-4.0, 4.0), float(CITY_GROUND) + 1.05, rng.randf_range(-4.0, 4.0))
	get_parent().add_child(cop)

func _spawn_from_gloom() -> void:
	var enemies := get_tree().get_nodes_in_group("enemies")
	if enemies.size() >= CONFIG.max_active_enemies:
		return
	var candidates: Array[int] = []
	for chunk_index in range(world.CHUNK_COUNT):
		if gloom.levels[chunk_index] < GLOOM_CONFIG.spawn_threshold:
			continue
		if float(chunk_cooldowns.get(chunk_index, 0.0)) > 0.0:
			continue
		candidates.append(chunk_index)
	if candidates.is_empty():
		return
	candidates.shuffle()
	for chunk_index in candidates:
		var position := _find_spawn_position(chunk_index)
		if position == Vector3(-1.0, -1.0, -1.0):
			continue
		var lamp_eater := rng.randf() < CONFIG.lamp_eater_spawn_chance
		var count := 1 if lamp_eater else mini(CONFIG.threat_group_size, CONFIG.max_active_enemies - enemies.size())
		for index in range(count):
			var enemy: GloomEnemy = LAMP_EATER_SCRIPT.new() if lamp_eater and index == 0 else GANG_SCRIPT.new()
			enemy.position = position + Vector3(rng.randf_range(-1.2, 1.2), 0.0, rng.randf_range(-1.2, 1.2))
			if lamp_eater:
				enemy.move_speed = CONFIG.lamp_eater_speed
				enemy.max_health = CONFIG.lamp_eater_health
				enemy.touch_damage = CONFIG.lamp_eater_damage
				enemy.attack_range = CONFIG.lamp_eater_attack_range
				enemy.extinguish_distance = CONFIG.lamp_eater_extinguish_distance
				enemy.extinguish_seconds = CONFIG.lamp_eater_extinguish_seconds
				enemy.target_radius = CONFIG.lamp_eater_target_radius
				enemy.target_blocks = CONFIG.lamp_eater_target_blocks
				enemy.dissolve_light_level = 15
			else:
				enemy.move_speed = CONFIG.gang_speed
				enemy.max_health = CONFIG.gang_health
				enemy.touch_damage = CONFIG.gang_damage
				enemy.attack_range = CONFIG.gang_attack_range
			get_parent().add_child(enemy)
		chunk_cooldowns[chunk_index] = CONFIG.spawn_cooldown_seconds
		return

func _spawn_civilian() -> void:
	if get_tree().get_nodes_in_group("enemies").size() >= CONFIG.max_active_enemies:
		return
	var civilian: Civilian = CIVILIAN_SCRIPT.new()
	civilian.move_speed = CONFIG.civilian_speed
	civilian.max_health = CONFIG.civilian_health
	var move_axis := rng.randi_range(0, 1)
	var line := 8 + 16 * rng.randi_range(0, 7)
	if move_axis == 0:
		civilian.move_axis = 0
		civilian.fixed_coord = float(line - 1 + rng.randi_range(0, 2))
		civilian.position = Vector3(rng.randf_range(8.0, 116.0), float(CITY_GROUND) + 1.05, civilian.fixed_coord)
	else:
		civilian.move_axis = 1
		civilian.fixed_coord = float(line - 1 + rng.randi_range(0, 2))
		civilian.position = Vector3(civilian.fixed_coord, float(CITY_GROUND) + 1.05, rng.randf_range(8.0, 116.0))
	get_parent().add_child(civilian)

func _find_spawn_position(chunk_index: int) -> Vector3:
	var surface_spawn := _find_surface_spawn_position(chunk_index)
	if surface_spawn != Vector3(-1.0, -1.0, -1.0):
		return surface_spawn
	return _find_cave_spawn_position(chunk_index)

func _find_surface_spawn_position(chunk_index: int) -> Vector3:
	var coords: Vector3i = world._chunk_coords(chunk_index)
	for attempt in range(12):
		var x := coords.x * 16 + rng.randi_range(1, 14)
		var z := coords.z * 16 + rng.randi_range(1, 14)
		var floor_y: int = world.get_surface_height(x, z)
		var spawn := Vector3(x + 0.5, floor_y + 1.05, z + 0.5)
		var distance := spawn.distance_to(player.position)
		if distance < CONFIG.min_spawn_distance or distance > CONFIG.max_spawn_distance:
			continue
		var surface_chunk := Vector3i(x / 16, floor_y / 16, z / 16)
		if world._chunk_index(surface_chunk) != chunk_index:
			continue
		if world.get_block_id(Vector3i(x, floor_y + 1, z)) != world.air_id:
			continue
		if _is_visible_from_player(spawn):
			continue
		return spawn
	return Vector3(-1.0, -1.0, -1.0)

func _find_cave_spawn_position(chunk_index: int) -> Vector3:
	var coords: Vector3i = world._chunk_coords(chunk_index)
	var min_y := coords.y * 16 + 1
	var max_y := coords.y * 16 + 14
	for attempt in range(16):
		var x := coords.x * 16 + rng.randi_range(1, 14)
		var z := coords.z * 16 + rng.randi_range(1, 14)
		var highest := mini(max_y, world.get_surface_height(x, z) - 2)
		if highest < min_y:
			continue
		var y := rng.randi_range(min_y, highest)
		var cell := Vector3i(x, y, z)
		if world.get_block_id(cell) != world.air_id or world.get_block_id(cell + Vector3i.UP) != world.air_id:
			continue
		if world.get_block_id(Vector3i(x, y - 1, z)) == world.air_id:
			continue
		var spawn := Vector3(x + 0.5, y + 0.05, z + 0.5)
		var distance := spawn.distance_to(player.position)
		if distance < CONFIG.min_spawn_distance or distance > CONFIG.max_spawn_distance:
			continue
		if world._chunk_index(Vector3i(x / 16, y / 16, z / 16)) != chunk_index:
			continue
		if _is_visible_from_player(spawn):
			continue
		return spawn
	return Vector3(-1.0, -1.0, -1.0)

func debug_spawn_gangs(count: int = 3) -> void:
	_debug_spawn(false, count)

func debug_spawn_lamp_eater() -> void:
	_debug_spawn(true, 1)

func debug_spawn_cops(count: int = 2) -> void:
	for index in range(count):
		var cop: PoliceOfficer = COP_SCRIPT.new()
		cop.move_speed = CONFIG.police_speed
		cop.max_health = CONFIG.police_health
		cop.touch_damage = CONFIG.police_damage
		cop.attack_range = CONFIG.police_attack_range
		cop.position = player.position + Vector3(rng.randf_range(-4.0, 4.0), float(CITY_GROUND) + 1.05, rng.randf_range(-4.0, 4.0))
		get_parent().add_child(cop)

func _debug_spawn(lamp_eater: bool, count: int) -> void:
	if not world.is_generated or not player.spawned:
		return
	for index in range(count):
		var cell_x := 0
		var cell_z := 0
		var found_column := false
		for attempt in range(8):
			var angle := rng.randf_range(0.0, TAU)
			var distance := rng.randf_range(5.0, 8.0)
			cell_x = floori(player.position.x + cos(angle) * distance)
			cell_z = floori(player.position.z + sin(angle) * distance)
			if world._inside_world(Vector3i(cell_x, 0, cell_z)):
				found_column = true
				break
		if not found_column:
			continue
		var surface: int = world.get_surface_height(cell_x, cell_z)
		var enemy: GloomEnemy = LAMP_EATER_SCRIPT.new() if lamp_eater else GANG_SCRIPT.new()
		enemy.position = Vector3(cell_x + 0.5, surface + 1.05, cell_z + 0.5)
		if lamp_eater:
			enemy.move_speed = CONFIG.lamp_eater_speed
			enemy.max_health = CONFIG.lamp_eater_health
			enemy.touch_damage = CONFIG.lamp_eater_damage
			enemy.attack_range = CONFIG.lamp_eater_attack_range
			enemy.extinguish_distance = CONFIG.lamp_eater_extinguish_distance
			enemy.extinguish_seconds = CONFIG.lamp_eater_extinguish_seconds
			enemy.target_radius = CONFIG.lamp_eater_target_radius
			enemy.target_blocks = CONFIG.lamp_eater_target_blocks
			enemy.dissolve_light_level = 15
		else:
			enemy.move_speed = CONFIG.gang_speed
			enemy.max_health = CONFIG.gang_health
			enemy.touch_damage = CONFIG.gang_damage
			enemy.attack_range = CONFIG.gang_attack_range
		get_parent().add_child(enemy)

func _is_visible_from_player(target: Vector3) -> bool:
	var start := player.camera.global_position
	var offset := target - start
	var steps := ceili(offset.length() * 3.0)
	for step_index in range(1, steps):
		var point := start + offset * (float(step_index) / float(steps))
		var cell := Vector3i(floori(point.x), floori(point.y), floori(point.z))
		if world._inside_world(cell) and world.get_block_id(cell) != world.air_id:
			return false
	return true
