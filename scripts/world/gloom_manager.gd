extends Node
class_name GloomManager

signal gloom_changed(chunk_index: int, value: float)

const CONFIG: GloomConfig = preload("res://data/world/gloom_config.tres")

var world: VoxelWorld
var cycle: DayNightCycle
var levels := PackedFloat32Array()
var lit_fraction := PackedFloat32Array()
var sky_fraction := PackedFloat32Array()
var underground_fraction := PackedFloat32Array()
var rot_cursors := PackedInt32Array()
var tick_accumulator := 0.0
var rot_chunk_cursor := 0
var initialized := false
var pending_restore: Array = []

func _ready() -> void:
	world = get_parent().get_node("VoxelWorld") as VoxelWorld
	cycle = get_parent().get_node("DayNightCycle") as DayNightCycle
	world.chunk_light_changed.connect(_on_chunk_light_changed)
	world.gloom_noise_emitted.connect(_on_gloom_noise)

func _process(delta: float) -> void:
	if not world.is_generated:
		return
	if not initialized:
		_initialize_levels()
	tick_accumulator += delta
	if tick_accumulator < CONFIG.tick_seconds:
		return
	var elapsed := minf(tick_accumulator, CONFIG.tick_seconds * 2.0)
	tick_accumulator = 0.0
	_tick_gloom(elapsed)
	_process_rotting()

func _initialize_levels() -> void:
	levels.resize(world.CHUNK_COUNT)
	levels.fill(0.0)
	lit_fraction.resize(world.CHUNK_COUNT)
	lit_fraction.fill(0.0)
	sky_fraction.resize(world.CHUNK_COUNT)
	underground_fraction.resize(world.CHUNK_COUNT)
	rot_cursors.resize(world.CHUNK_COUNT)
	rot_cursors.fill(0)
	for chunk_index in range(world.CHUNK_COUNT):
		var coords: Vector3i = world._chunk_coords(chunk_index)
		var origin := coords * world.CHUNK_SIZE
		var sky_cells := 0
		for z in range(world.CHUNK_SIZE):
			for x in range(world.CHUNK_SIZE):
				for y in range(world.CHUNK_SIZE):
					var cell := origin + Vector3i(x, y, z)
					if world._inside_world(cell) and world.get_block_id(cell) == world.air_id and world.get_block_id(cell + Vector3i.UP) == world.air_id:
						sky_cells += 1
		var exposed := float(sky_cells) / float(world.CHUNK_SIZE * world.CHUNK_SIZE * world.CHUNK_SIZE)
		sky_fraction[chunk_index] = exposed
		underground_fraction[chunk_index] = 1.0 - exposed
	initialized = true
	if not pending_restore.is_empty():
		_restore_levels(pending_restore)
		pending_restore.clear()

func _tick_gloom(delta: float) -> void:
	for chunk_index in range(world.CHUNK_COUNT):
		var coords: Vector3i = world._chunk_coords(chunk_index)
		var center := Vector3(coords * world.CHUNK_SIZE) + Vector3.ONE * (world.CHUNK_SIZE * 0.5)
		var sky_light := sky_fraction[chunk_index] * cycle.ambient_level
		var dynamic_light := world.get_flashlight_level_at(center)
		if world.player_camera != null:
			var player_coords := Vector3i(floori(world.player_camera.global_position.x / 16.0), floori(world.player_camera.global_position.y / 16.0), floori(world.player_camera.global_position.z / 16.0))
			if player_coords == coords:
				dynamic_light = maxf(dynamic_light, world.get_flashlight_level_at(world.player_camera.global_position))
		var light_exposure := maxf(lit_fraction[chunk_index], maxf(sky_light * (1.0 + CONFIG.daylight_relief), dynamic_light))
		var previous := levels[chunk_index]
		if light_exposure >= 0.08:
			levels[chunk_index] = maxf(0.0, previous - CONFIG.lit_fall_per_second * light_exposure * delta)
		else:
			var multiplier := underground_fraction[chunk_index] * (CONFIG.underground_multiplier - 1.0) + 1.0
			if sky_fraction[chunk_index] > 0.1 and cycle.phase_name == "night":
				multiplier *= CONFIG.night_multiplier
			elif sky_fraction[chunk_index] > 0.1 and (cycle.phase_name == "twilight" or cycle.phase_name == "dawn"):
				multiplier *= lerpf(1.0, CONFIG.night_multiplier, cycle.phase_fraction)
			levels[chunk_index] = minf(1.0, previous + CONFIG.dark_rise_per_second * multiplier * delta)
		if not is_equal_approx(previous, levels[chunk_index]):
			gloom_changed.emit(chunk_index, levels[chunk_index])

func _on_chunk_light_changed(chunk_index: int, light_data: PackedByteArray) -> void:
	var lit_cells := 0
	for level in light_data:
		if int(level) >= 3:
			lit_cells += 1
	lit_fraction[chunk_index] = float(lit_cells) / float(light_data.size())

func _on_gloom_noise(world_position: Vector3, strength: float) -> void:
	var cell := Vector3i(floori(world_position.x), floori(world_position.y), floori(world_position.z))
	if not world._inside_world(cell):
		return
	var coords := Vector3i(cell.x / 16, cell.y / 16, cell.z / 16)
	var center_index: int = world._chunk_index(coords)
	_add_noise(center_index, strength * CONFIG.noise_to_gloom_scale)
	var directions: Array[Vector3i] = [Vector3i.RIGHT, Vector3i.LEFT, Vector3i.UP, Vector3i.DOWN, Vector3i(0, 0, 1), Vector3i(0, 0, -1)]
	for direction in directions:
		var neighbor: Vector3i = coords + direction
		if neighbor.x >= 0 and neighbor.y >= 0 and neighbor.z >= 0 and neighbor.x < world.CHUNKS_X and neighbor.y < world.CHUNKS_Y and neighbor.z < world.CHUNKS_Z:
			_add_noise(world._chunk_index(neighbor), strength * CONFIG.noise_to_gloom_scale * 0.25)

func _add_noise(chunk_index: int, amount: float) -> void:
	levels[chunk_index] = minf(1.0, levels[chunk_index] + amount)
	gloom_changed.emit(chunk_index, levels[chunk_index])

func _process_rotting() -> void:
	var converted := 0
	for offset in range(world.CHUNK_COUNT):
		if converted >= CONFIG.max_rots_per_tick:
			break
		var index := (rot_chunk_cursor + offset) % world.CHUNK_COUNT
		if levels[index] < CONFIG.rot_threshold:
			continue
		if _try_rot_block(index):
			converted += 1
	rot_chunk_cursor = (rot_chunk_cursor + 1) % world.CHUNK_COUNT

func _try_rot_block(chunk_index: int) -> bool:
	var origin: Vector3i = world._chunk_coords(chunk_index) * world.CHUNK_SIZE
	var cursor := rot_cursors[chunk_index]
	for offset in range(96):
		var local_index := (cursor + offset) % 4096
		var local := Vector3i(local_index % 16, int(local_index / 16) % 16, int(local_index / 256))
		var cell := origin + local
		var block_id := world.get_block_id(cell)
		var definition: BlockLightDef = world.block_defs[block_id]
		if definition.rotted_variant_id == &"" or not world.block_ids.has(definition.rotted_variant_id):
			continue
		if world.set_block(cell, world.block_ids[definition.rotted_variant_id]):
			rot_cursors[chunk_index] = (local_index + 1) % 4096
			return true
	rot_cursors[chunk_index] = (cursor + 96) % 4096
	return false

func get_level_for_cell(cell: Vector3i) -> float:
	if not world._inside_world(cell) or not initialized:
		return 0.0
	return levels[world._chunk_index(Vector3i(cell.x / 16, cell.y / 16, cell.z / 16))]

func set_level_for_cell(cell: Vector3i, value: float) -> void:
	if not world._inside_world(cell) or not initialized:
		return
	var chunk_index: int = world._chunk_index(Vector3i(cell.x / 16, cell.y / 16, cell.z / 16))
	var clamped := clampf(value, 0.0, 1.0)
	if is_equal_approx(levels[chunk_index], clamped):
		return
	levels[chunk_index] = clamped
	gloom_changed.emit(chunk_index, clamped)

func to_save_array() -> Array:
	return Array(levels)

func restore_from_array(saved: Array) -> void:
	if not initialized:
		pending_restore = saved.duplicate()
		return
	_restore_levels(saved)

func _restore_levels(saved: Array) -> void:
	if saved.size() != world.CHUNK_COUNT:
		return
	for index in range(saved.size()):
		levels[index] = clampf(float(saved[index]), 0.0, 1.0)