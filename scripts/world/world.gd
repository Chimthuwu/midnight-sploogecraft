extends Node3D
class_name VoxelWorld
signal gloom_noise_emitted(world_position: Vector3, strength: float)
signal chunk_light_changed(chunk_index: int, light_data: PackedByteArray)

const WORLD_X := 128
const WORLD_Y := 64
const WORLD_Z := 128
const CHUNK_SIZE := 16
const CHUNKS_X := 8
const CHUNKS_Y := 4
const CHUNKS_Z := 8
const CHUNK_COUNT := CHUNKS_X * CHUNKS_Y * CHUNKS_Z
const MAX_WORKERS := 4
const MAX_MESH_COMMITS_PER_FRAME := 1
const MAX_MESH_DISPATCH_PER_FRAME := 1
const LIGHT_FRAME_BUDGET_USEC := 7000
const LIGHT_STEP_BATCH := 64
const FLASHLIGHT_RANGE := 16.0
const FLASHLIGHT_INNER_COS := 0.94
const FLASHLIGHT_OUTER_COS := 0.82
const FLASHLIGHT_INTENSITY := 1.0
const BLOCK_VOLUME := WORLD_X * WORLD_Y * WORLD_Z
const CITY_GROUND := 2
const CITY_SPAWN_X := 9
const CITY_SPAWN_Z := 9
const BLOCK_RESOURCE_PATHS := [
	"res://data/blocks/air.tres",
	"res://data/blocks/asphalt.tres",
	"res://data/blocks/ashen_soil.tres",
	"res://data/blocks/concrete.tres",
	"res://data/blocks/dirt.tres",
	"res://data/blocks/facade_dark.tres",
	"res://data/blocks/facade_light.tres",
	"res://data/blocks/facade_mid.tres",
	"res://data/blocks/facade_brick.tres",
	"res://data/blocks/facade_panel.tres",
	"res://data/blocks/garage_door.tres",
	"res://data/blocks/graffiti.tres",
	"res://data/blocks/glass_cyan.tres",
	"res://data/blocks/glass_dark.tres",
	"res://data/blocks/glass_warm.tres",
	"res://data/blocks/billboard.tres",
	"res://data/blocks/crosswalk.tres",
	"res://data/blocks/iron_ore.tres",
	"res://data/blocks/lumen_crystal.tres",
	"res://data/blocks/manhole.tres",
	"res://data/blocks/mycelium.tres",
	"res://data/blocks/neon_blue.tres",
	"res://data/blocks/neon_green.tres",
	"res://data/blocks/neon_pink.tres",
	"res://data/blocks/neon_red.tres",
	"res://data/blocks/neon_sign.tres",
	"res://data/blocks/neon_yellow.tres",
	"res://data/blocks/paint_white.tres",
	"res://data/blocks/pale_bloom.tres",
	"res://data/blocks/road_line.tres",
	"res://data/blocks/roof.tres",
	"res://data/blocks/rust_metal.tres",
	"res://data/blocks/rotted_ashen_soil.tres",
	"res://data/blocks/rotted_dirt.tres",
	"res://data/blocks/sidewalk.tres",
	"res://data/blocks/sign_panel.tres",
	"res://data/blocks/stone.tres",
	"res://data/blocks/street_lamp.tres",
	"res://data/blocks/test_wall.tres",
	"res://data/blocks/torch.tres",
	"res://data/blocks/traffic_light.tres",
	"res://data/blocks/window_cyan.tres",
	"res://data/blocks/window_dark.tres",
	"res://data/blocks/window_warm.tres",
	"res://data/blocks/dead_wood.tres",
	"res://data/blocks/door.tres",
	"res://data/blocks/drain.tres",
	"res://data/blocks/awning_red.tres",
	"res://data/blocks/awning_teal.tres"
]
const Generator = preload("res://scripts/world/world_generator.gd")
const ChunkScript = preload("res://scripts/world/chunk.gd")
const Mesher = preload("res://scripts/world/chunk_mesher.gd")
const LightPropagator = preload("res://scripts/light/light_propagator.gd")

@export var world_seed := 139732

var blocks := PackedByteArray()
var heights := PackedInt32Array()
var biome_map := PackedByteArray()
var block_defs: Array[BlockLightDef] = []
var block_ids: Dictionary = {}
var palette := PackedColorArray()
var fixture_ids: Dictionary = {}
var emissive_ids: Dictionary = {}
var glow_ids: Dictionary = {}
var air_id := 0
var attenuation := PackedByteArray()
var emitted_light := PackedByteArray()
var light_buffers: Array[PackedByteArray] = []
var light_initialized := PackedByteArray()
var static_light_sources: Array[Dictionary] = []
var extinguished_sources: Dictionary = {}
var gloom_manager: GloomManager
var ambient_sky_level := 0.0
var flashlight_enabled := true
var light_dirty_queue: Array[int] = []
var light_dirty_head := 0
var light_dirty_set: Dictionary = {}
var initialized_light_chunks := 0
var light_updates_last_frame := 0
var light_work_frames := 0
var max_light_frame_usec := 0
var light_completion_logged := false
var active_light_chunk := -1
var active_light_state: Dictionary = {}
var chunk_nodes: Array = []
var generation_results: Array = []
var generation_task_ids := PackedInt64Array([-1, -1, -1, -1])
var generation_task_chunks := PackedInt32Array([-1, -1, -1, -1])
var generated_chunk_count := 0
var is_generated := false
var mesh_results: Array = []
var mesh_task_ids := PackedInt64Array([-1, -1, -1, -1])
var mesh_task_chunks := PackedInt32Array([-1, -1, -1, -1])
var mesh_task_revisions := PackedInt32Array([-1, -1, -1, -1])
var mesh_task_revisions_for_result := PackedInt32Array()
var worker_mutex := Mutex.new()
var chunk_revisions := PackedInt32Array()
var mesh_installed := PackedByteArray()
var meshed_chunk_count := 0
var dirty_queue: Array[int] = []
var dirty_head := 0
var dirty_set: Dictionary = {}
var completed_meshes: Array[int] = []
var completed_head := 0
var world_material: ShaderMaterial
var player_camera: Camera3D
var slow_frame_streak := 0


func _exit_tree() -> void:
	for slot in range(MAX_WORKERS):
		if generation_task_ids[slot] != -1:
			WorkerThreadPool.wait_for_task_completion(generation_task_ids[slot])
			generation_task_ids[slot] = -1
		if mesh_task_ids[slot] != -1:
			WorkerThreadPool.wait_for_task_completion(mesh_task_ids[slot])
			mesh_task_ids[slot] = -1


func _ready() -> void:
	_load_block_palette()
	blocks.resize(BLOCK_VOLUME)
	blocks.fill(air_id)
	generation_results.resize(CHUNK_COUNT)
	mesh_results.resize(CHUNK_COUNT)
	mesh_task_revisions_for_result.resize(CHUNK_COUNT)
	chunk_revisions.resize(CHUNK_COUNT)
	chunk_revisions.fill(0)
	mesh_installed.resize(CHUNK_COUNT)
	mesh_installed.fill(0)
	light_buffers.resize(CHUNK_COUNT)
	light_initialized.resize(CHUNK_COUNT)
	light_initialized.fill(0)
	for chunk_index in range(CHUNK_COUNT):
		var chunk_light := PackedByteArray()
		chunk_light.resize(CHUNK_SIZE * CHUNK_SIZE * CHUNK_SIZE)
		chunk_light.fill(0)
		light_buffers[chunk_index] = chunk_light
	_create_chunk_nodes()
	player_camera = get_parent().get_node_or_null("Player/Camera3D") as Camera3D
	var maps: Dictionary = Generator.build_maps(world_seed)
	heights = maps["heights"]
	biome_map = maps["biome_map"]
	_fill_generation_workers()


func _process(delta: float) -> void:
	_check_slow_frame(delta)
	if not is_generated:
		_process_generation()
	else:
		_process_light_updates()
		_process_extinguished_lights(delta)
		_process_mesh_pipeline()
		_update_flashlight_uniforms()

func _load_block_palette() -> void:
	world_material = ShaderMaterial.new()
	world_material.shader = load("res://shaders/light_dither.gdshader") as Shader
	world_material.set_shader_parameter("dither_bands", 8.0)
	world_material.set_shader_parameter("flashlight_enabled", flashlight_enabled)
	world_material.set_shader_parameter("flashlight_range", FLASHLIGHT_RANGE)
	world_material.set_shader_parameter("flashlight_inner_cos", FLASHLIGHT_INNER_COS)
	world_material.set_shader_parameter("flashlight_outer_cos", FLASHLIGHT_OUTER_COS)
	world_material.set_shader_parameter("flashlight_intensity", FLASHLIGHT_INTENSITY)
	world_material.set_shader_parameter("ambient_sky_level", ambient_sky_level)
	world_material.set_shader_parameter("sun_strength", 0.0)
	for path in BLOCK_RESOURCE_PATHS:
		var definition := load(path) as BlockLightDef
		if definition == null:
			push_error("Could not load block definition: %s" % path)
			continue
		var block_index := block_defs.size()
		block_defs.append(definition)
		block_ids[definition.block_id] = block_index
		var color := definition.albedo
		color.a = 1.0
		palette.append(color)
		attenuation.append(definition.attenuation)
		emitted_light.append(definition.emitted_light)
		if definition.block_id == &"air":
			air_id = block_index
	fixture_ids.clear()
	for fixture in [&"torch", &"street_lamp", &"pale_bloom", &"mycelium", &"traffic_light"]:
		if block_ids.has(fixture):
			fixture_ids[int(block_ids[fixture])] = fixture
	emissive_ids.clear()
	glow_ids.clear()
	for index in range(block_defs.size()):
		if block_defs[index].emitted_light > 0 or block_defs[index].glow_only:
			emissive_ids[index] = true
			if block_defs[index].glow_only:
				glow_ids[index] = true

func _create_chunk_nodes() -> void:
	chunk_nodes.resize(CHUNK_COUNT)
	for chunk_y in range(CHUNKS_Y):
		for chunk_z in range(CHUNKS_Z):
			for chunk_x in range(CHUNKS_X):
				var index := _chunk_index(Vector3i(chunk_x, chunk_y, chunk_z))
				var chunk = ChunkScript.new()
				chunk.name = "Chunk_%d_%d_%d" % [chunk_x, chunk_y, chunk_z]
				chunk.configure(Vector3i(chunk_x, chunk_y, chunk_z), Vector3(chunk_x, chunk_y, chunk_z) * CHUNK_SIZE, world_material)
				add_child(chunk)
				chunk_nodes[index] = chunk


func _fill_generation_workers() -> void:
	for slot in range(MAX_WORKERS):
		if generation_task_ids[slot] != -1 or generated_chunk_count + _active_generation_count() >= CHUNK_COUNT:
			continue
		var next_chunk := generated_chunk_count + _active_generation_count()
		if next_chunk >= CHUNK_COUNT:
			return
		generation_task_chunks[slot] = next_chunk
		generation_task_ids[slot] = WorkerThreadPool.add_task(Callable(self, "_generate_chunk_task").bind(next_chunk))


func _active_generation_count() -> int:
	var active := 0
	for slot in range(MAX_WORKERS):
		if generation_task_ids[slot] != -1:
			active += 1
	return active


func _generate_chunk_task(chunk_index: int) -> void:
	var generated := Generator.generate_chunk(chunk_index, world_seed, heights, block_ids)
	worker_mutex.lock()
	generation_results[chunk_index] = generated
	worker_mutex.unlock()


func _process_generation() -> void:
	for slot in range(MAX_WORKERS):
		var task_id := generation_task_ids[slot]
		if task_id == -1 or not WorkerThreadPool.is_task_completed(task_id):
			continue
		WorkerThreadPool.wait_for_task_completion(task_id)
		var chunk_index := generation_task_chunks[slot]
		var chunk_data: PackedByteArray = generation_results[chunk_index]
		_copy_generated_chunk(chunk_index, chunk_data)
		generation_results[chunk_index] = null
		generation_task_ids[slot] = -1
		generation_task_chunks[slot] = -1
		generated_chunk_count += 1
	if generated_chunk_count == CHUNK_COUNT:
		is_generated = true
		_rebuild_static_light_sources()
		_log_world_counts()
		for chunk_index in range(CHUNK_COUNT):
			_enqueue_light_dirty(chunk_index)
	else:
		_fill_generation_workers()


func _copy_generated_chunk(chunk_index: int, chunk_data: PackedByteArray) -> void:
	var chunk_x := chunk_index % CHUNKS_X
	var chunk_z := int(chunk_index / CHUNKS_X) % CHUNKS_Z
	var chunk_y := int(chunk_index / (CHUNKS_X * CHUNKS_Z))
	for z in range(CHUNK_SIZE):
		for y in range(CHUNK_SIZE):
			var local_start := y * CHUNK_SIZE + z * CHUNK_SIZE * CHUNK_SIZE
			var world_start := chunk_x * CHUNK_SIZE + (chunk_z * CHUNK_SIZE + z) * WORLD_X + (chunk_y * CHUNK_SIZE + y) * WORLD_X * WORLD_Z
			for x in range(CHUNK_SIZE):
				blocks[world_start + x] = chunk_data[local_start + x]


func _process_mesh_pipeline() -> void:
	for slot in range(MAX_WORKERS):
		var task_id := mesh_task_ids[slot]
		if task_id == -1 or not WorkerThreadPool.is_task_completed(task_id):
			continue
		WorkerThreadPool.wait_for_task_completion(task_id)
		completed_meshes.append(mesh_task_chunks[slot])
		mesh_task_ids[slot] = -1
		mesh_task_chunks[slot] = -1
	var commits := 0
	while commits < MAX_MESH_COMMITS_PER_FRAME and completed_head < completed_meshes.size():
		var chunk_index := completed_meshes[completed_head]
		completed_head += 1
		var result: Dictionary = mesh_results[chunk_index]
		mesh_results[chunk_index] = null
		if chunk_revisions[chunk_index] != mesh_task_revisions_for_result[chunk_index]:
			_queue_dirty(chunk_index)
		else:
			_apply_mesh_result(chunk_index, result)
		commits += 1
	if completed_head >= completed_meshes.size():
		completed_meshes.clear()
		completed_head = 0
	_fill_mesh_workers()


func _fill_mesh_workers() -> void:
	var active := 0
	var dispatched := 0
	for slot in range(MAX_WORKERS):
		if mesh_task_ids[slot] != -1:
			active += 1
	active += completed_meshes.size() - completed_head
	for slot in range(MAX_WORKERS):
		if active >= MAX_WORKERS:
			return
		if mesh_task_ids[slot] != -1:
			continue
		var next_chunk := _pop_dirty()
		if next_chunk == -1:
			return
		var snapshot := _make_mesh_snapshot(next_chunk)
		var revision := chunk_revisions[next_chunk]
		mesh_task_chunks[slot] = next_chunk
		mesh_task_revisions[slot] = revision
		mesh_task_revisions_for_result[next_chunk] = revision
		var chunk_sources := _light_sources_for_chunk(next_chunk)
		mesh_task_ids[slot] = WorkerThreadPool.add_task(Callable(self, "_mesh_chunk_task").bind(next_chunk, snapshot["blocks"], snapshot["light"], snapshot["sky"], chunk_sources))
		active += 1
		dispatched += 1
		if dispatched >= MAX_MESH_DISPATCH_PER_FRAME:
			return


func _light_sources_for_chunk(chunk_index: int) -> Array:
	var chunk_x := chunk_index % CHUNKS_X
	var chunk_z := int(chunk_index / CHUNKS_X) % CHUNKS_Z
	var chunk_y := int(chunk_index / (CHUNKS_X * CHUNKS_Z))
	var origin := Vector3i(chunk_x, chunk_y, chunk_z) * CHUNK_SIZE
	var reach := 12
	var low := origin - Vector3i(reach, reach, reach)
	var high := origin + Vector3i(CHUNK_SIZE + reach, CHUNK_SIZE + reach, CHUNK_SIZE + reach)
	var sources: Array = []
	for source in static_light_sources:
		var cell: Vector3i = source["cell"]
		if cell.x < low.x or cell.y < low.y or cell.z < low.z or cell.x > high.x or cell.y > high.y or cell.z > high.z:
			continue
		sources.append({"position": Vector3(cell - origin) + Vector3(0.5, 0.5, 0.5), "cool": bool(source.get("cool", false))})
	return sources


func _mesh_chunk_task(chunk_index: int, block_snapshot: PackedByteArray, light_snapshot: PackedByteArray, sky_snapshot: PackedByteArray, light_sources: Array) -> void:
	var mesh_data := Mesher.build(block_snapshot, light_snapshot, sky_snapshot, palette, air_id, fixture_ids, emissive_ids, light_sources, glow_ids)
	worker_mutex.lock()
	mesh_results[chunk_index] = mesh_data
	worker_mutex.unlock()

func _make_mesh_snapshot(chunk_index: int) -> Dictionary:
	var chunk_x := chunk_index % CHUNKS_X
	var chunk_z := int(chunk_index / CHUNKS_X) % CHUNKS_Z
	var chunk_y := int(chunk_index / (CHUNKS_X * CHUNKS_Z))
	var origin := Vector3i(chunk_x, chunk_y, chunk_z) * CHUNK_SIZE
	var block_snapshot := PackedByteArray()
	var light_snapshot := PackedByteArray()
	var sky_snapshot := PackedByteArray()
	block_snapshot.resize(18 * 18 * 18)
	light_snapshot.resize(18 * 18 * 18)
	sky_snapshot.resize(18 * 18 * 18)
	block_snapshot.fill(air_id)
	light_snapshot.fill(0)
	sky_snapshot.fill(0)
	for z in range(-1, CHUNK_SIZE + 1):
		for y in range(-1, CHUNK_SIZE + 1):
			for x in range(-1, CHUNK_SIZE + 1):
				var cell := origin + Vector3i(x, y, z)
				if not _inside_world(cell):
					continue
				var snapshot_index := (x + 1) + (y + 1) * 18 + (z + 1) * 18 * 18
				block_snapshot[snapshot_index] = blocks[_block_index(cell)]
				light_snapshot[snapshot_index] = get_light_level(cell)
				var surface_y: int = heights[cell.x + cell.z * WORLD_X]
				sky_snapshot[snapshot_index] = 1 if cell.y >= surface_y else 0
	return {"blocks": block_snapshot, "light": light_snapshot, "sky": sky_snapshot}
func _process_light_updates() -> void:
	light_updates_last_frame = 0
	var frame_start_usec := Time.get_ticks_usec()
	while Time.get_ticks_usec() - frame_start_usec < LIGHT_FRAME_BUDGET_USEC:
		if active_light_chunk == -1:
			active_light_chunk = _pop_light_dirty()
			if active_light_chunk == -1:
				break
			var coords := _chunk_coords(active_light_chunk)
			active_light_state = LightPropagator.begin_chunk(blocks, coords, static_light_sources, attenuation, block_ids[&"stone"])
		if not LightPropagator.advance_chunk(active_light_state, LIGHT_STEP_BATCH):
			continue
		var chunk_index := active_light_chunk
		var new_light: PackedByteArray = active_light_state["result"]
		active_light_chunk = -1
		active_light_state.clear()
		var was_initialized := light_initialized[chunk_index] != 0
		if not was_initialized or new_light != light_buffers[chunk_index]:
			light_buffers[chunk_index] = new_light
			chunk_light_changed.emit(chunk_index, new_light)
			chunk_revisions[chunk_index] += 1
			_queue_dirty(chunk_index)
		if not was_initialized:
			light_initialized[chunk_index] = 1
			initialized_light_chunks += 1
			if initialized_light_chunks == CHUNK_COUNT and not light_completion_logged:
				light_completion_logged = true
				_log_light_timings()
		light_updates_last_frame += 1
	var frame_work_usec := Time.get_ticks_usec() - frame_start_usec
	if frame_work_usec > 0:
		light_work_frames += 1
		max_light_frame_usec = maxi(max_light_frame_usec, frame_work_usec)
	if light_dirty_head >= light_dirty_queue.size():
		light_dirty_queue.clear()
		light_dirty_head = 0

func _log_light_timings() -> void:
	print("M2 incremental light bake complete: chunks=%d frames=%d budget_us=%d max_frame_work_us=%d" % [initialized_light_chunks, light_work_frames, LIGHT_FRAME_BUDGET_USEC, max_light_frame_usec])
func _enqueue_light_dirty(chunk_index: int) -> void:
	if chunk_index < 0 or chunk_index >= CHUNK_COUNT or light_dirty_set.has(chunk_index):
		return
	light_dirty_set[chunk_index] = true
	light_dirty_queue.append(chunk_index)


func _pop_light_dirty() -> int:
	var best_queue_index := -1
	var best_distance := INF
	var player_position := Vector3(64.0, 32.0, 64.0)
	if is_instance_valid(player_camera):
		player_position = player_camera.global_position
	for queue_index in range(light_dirty_head, light_dirty_queue.size()):
		var candidate := light_dirty_queue[queue_index]
		if candidate < 0:
			continue
		var center := Vector3(_chunk_coords(candidate) * CHUNK_SIZE) + Vector3.ONE * (CHUNK_SIZE * 0.5)
		var distance := center.distance_squared_to(player_position)
		if distance < best_distance:
			best_distance = distance
			best_queue_index = queue_index
	if best_queue_index < 0:
		return -1
	var chunk_index := light_dirty_queue[best_queue_index]
	light_dirty_queue[best_queue_index] = -1
	light_dirty_set.erase(chunk_index)
	while light_dirty_head < light_dirty_queue.size() and light_dirty_queue[light_dirty_head] < 0:
		light_dirty_head += 1
	return chunk_index
func _rebuild_static_light_sources() -> void:
	static_light_sources.clear()
	extinguished_sources.clear()
	for block_index in range(BLOCK_VOLUME):
		var block_id := int(blocks[block_index])
		var level := int(emitted_light[block_id])
		if level <= 0:
			continue
		var cell_y := int(block_index / (WORLD_X * WORLD_Z))
		var cell_z := int(block_index / WORLD_X) % WORLD_Z
		var cell_x := block_index % WORLD_X
		var cell := Vector3i(cell_x, cell_y, cell_z)
		if not extinguished_sources.has(cell):
			static_light_sources.append({"cell": cell, "level": level, "cool": block_id == int(block_ids[&"lumen_crystal"])})


func extinguish_light_source(cell: Vector3i, duration: float) -> bool:
	if not _inside_world(cell) or duration <= 0.0:
		return false
	var block_id := get_block_id(cell)
	if emitted_light[block_id] <= 0:
		return false
	extinguished_sources[cell] = duration
	_update_static_light_source(cell, block_id)
	_queue_light_region(cell)
	return true

func _process_extinguished_lights(delta: float) -> void:
	for cell in extinguished_sources.keys():
		var remaining := float(extinguished_sources[cell]) - delta
		if remaining > 0.0:
			extinguished_sources[cell] = remaining
			continue
		extinguished_sources.erase(cell)
		var block_id := get_block_id(cell)
		if emitted_light[block_id] > 0:
			_update_static_light_source(cell, block_id)
			_queue_light_region(cell)
func _update_static_light_source(cell: Vector3i, new_block_id: int) -> void:
	_remove_static_light_source(cell)
	if extinguished_sources.has(cell):
		return
	var level := int(emitted_light[new_block_id])
	if level > 0:
		static_light_sources.append({"cell": cell, "level": level, "cool": new_block_id == int(block_ids[&"lumen_crystal"])})

func _remove_static_light_source(cell: Vector3i) -> void:
	for index in range(static_light_sources.size() - 1, -1, -1):
		if static_light_sources[index]["cell"] == cell:
			static_light_sources.remove_at(index)

func _queue_light_region(cell: Vector3i) -> void:
	var min_x := maxi(0, floori(float(cell.x - 15) / CHUNK_SIZE))
	var min_y := maxi(0, floori(float(cell.y - 15) / CHUNK_SIZE))
	var min_z := maxi(0, floori(float(cell.z - 15) / CHUNK_SIZE))
	var max_x := mini(CHUNKS_X - 1, floori(float(cell.x + 15) / CHUNK_SIZE))
	var max_y := mini(CHUNKS_Y - 1, floori(float(cell.y + 15) / CHUNK_SIZE))
	var max_z := mini(CHUNKS_Z - 1, floori(float(cell.z + 15) / CHUNK_SIZE))
	if active_light_chunk >= 0:
		var active_coords := _chunk_coords(active_light_chunk)
		if active_coords.x >= min_x and active_coords.x <= max_x and active_coords.y >= min_y and active_coords.y <= max_y and active_coords.z >= min_z and active_coords.z <= max_z:
			_enqueue_light_dirty(active_light_chunk)
			active_light_chunk = -1
			active_light_state.clear()
	for chunk_y in range(min_y, max_y + 1):
		for chunk_z in range(min_z, max_z + 1):
			for chunk_x in range(min_x, max_x + 1):
				_enqueue_light_dirty(_chunk_index(Vector3i(chunk_x, chunk_y, chunk_z)))


func _chunk_coords(chunk_index: int) -> Vector3i:
	return Vector3i(chunk_index % CHUNKS_X, int(chunk_index / (CHUNKS_X * CHUNKS_X)), int(chunk_index / CHUNKS_X) % CHUNKS_Z)


func get_light_level(cell: Vector3i) -> int:
	if not _inside_world(cell):
		return 0
	var coords := Vector3i(int(cell.x / CHUNK_SIZE), int(cell.y / CHUNK_SIZE), int(cell.z / CHUNK_SIZE))
	var local_index := (cell.x % CHUNK_SIZE) + (cell.y % CHUNK_SIZE) * CHUNK_SIZE + (cell.z % CHUNK_SIZE) * CHUNK_SIZE * CHUNK_SIZE
	return light_buffers[_chunk_index(coords)][local_index]


func set_sun(direction: Vector3, color: Color, strength: float) -> void:
	if world_material == null:
		return
	world_material.set_shader_parameter("sun_direction", direction.normalized())
	world_material.set_shader_parameter("sun_color", Vector3(color.r, color.g, color.b))
	world_material.set_shader_parameter("sun_strength", clampf(strength, 0.0, 1.0))


func set_ambient_sky_level(level: float) -> void:
	ambient_sky_level = clampf(level, 0.0, 1.0)
	if world_material != null:
		world_material.set_shader_parameter("ambient_sky_level", ambient_sky_level)

func set_flashlight_enabled(enabled: bool) -> void:
	flashlight_enabled = enabled
	if world_material != null:
		world_material.set_shader_parameter("flashlight_enabled", enabled)

func get_flashlight_level_at(world_position: Vector3) -> float:
	if not flashlight_enabled or player_camera == null:
		return 0.0
	var from_source := world_position - player_camera.global_position
	var distance := from_source.length()
	if distance <= 0.001 or distance >= FLASHLIGHT_RANGE:
		return 0.0
	var alignment := from_source.normalized().dot((-player_camera.global_basis.z).normalized())
	var cone := smoothstep(FLASHLIGHT_OUTER_COS, FLASHLIGHT_INNER_COS, alignment)
	var falloff := 1.0 - distance / FLASHLIGHT_RANGE
	return clampf(FLASHLIGHT_INTENSITY * cone * falloff * falloff, 0.0, 1.0)

func get_gloom_level(cell: Vector3i) -> float:
	if gloom_manager == null:
		return 0.0
	return gloom_manager.get_level_for_cell(cell)

func _update_flashlight_uniforms() -> void:
	if player_camera == null or world_material == null:
		return
	world_material.set_shader_parameter("camera_position", player_camera.global_position)
	world_material.set_shader_parameter("camera_direction", (-player_camera.global_basis.z).normalized())

func _apply_mesh_result(chunk_index: int, result: Dictionary) -> void:
	var chunk = chunk_nodes[chunk_index]
	var vertices: PackedVector3Array = result["vertices"]
	chunk.install_geometry(vertices, result["normals"], result["colors"], result["uv2"])
	if mesh_installed[chunk_index] == 0:
		mesh_installed[chunk_index] = 1
		meshed_chunk_count += 1


func _queue_dirty(chunk_index: int) -> void:
	if chunk_index < 0 or chunk_index >= CHUNK_COUNT or dirty_set.has(chunk_index):
		return
	dirty_set[chunk_index] = true
	dirty_queue.append(chunk_index)


func _pop_dirty() -> int:
	while dirty_head < dirty_queue.size():
		var chunk_index := dirty_queue[dirty_head]
		dirty_head += 1
		dirty_set.erase(chunk_index)
		return chunk_index
	if dirty_head > 0:
		dirty_queue.clear()
		dirty_head = 0
	return -1


func set_block(cell: Vector3i, block_id: int) -> bool:
	if not is_generated or not _inside_world(cell) or block_id < 0 or block_id >= block_defs.size():
		return false
	var index := _block_index(cell)
	var previous_id := int(blocks[index])
	if previous_id == block_id:
		return false
	var was_extinguished := extinguished_sources.has(cell)
	blocks[index] = block_id
	if extinguished_sources.has(cell):
		extinguished_sources.erase(cell)
	_mark_cell_and_border_chunks(cell)
	if attenuation[previous_id] != attenuation[block_id] or emitted_light[previous_id] != emitted_light[block_id]:
		if emitted_light[previous_id] != emitted_light[block_id] or was_extinguished:
			_update_static_light_source(cell, block_id)
		_queue_light_region(cell)
	return true

func _mark_cell_and_border_chunks(cell: Vector3i) -> void:
	var chunk_cell := Vector3i(int(cell.x / CHUNK_SIZE), int(cell.y / CHUNK_SIZE), int(cell.z / CHUNK_SIZE))
	_mark_chunk(chunk_cell)
	if cell.x % CHUNK_SIZE == 0: _mark_chunk(chunk_cell + Vector3i(-1, 0, 0))
	if cell.x % CHUNK_SIZE == CHUNK_SIZE - 1: _mark_chunk(chunk_cell + Vector3i(1, 0, 0))
	if cell.y % CHUNK_SIZE == 0: _mark_chunk(chunk_cell + Vector3i(0, -1, 0))
	if cell.y % CHUNK_SIZE == CHUNK_SIZE - 1: _mark_chunk(chunk_cell + Vector3i(0, 1, 0))
	if cell.z % CHUNK_SIZE == 0: _mark_chunk(chunk_cell + Vector3i(0, 0, -1))
	if cell.z % CHUNK_SIZE == CHUNK_SIZE - 1: _mark_chunk(chunk_cell + Vector3i(0, 0, 1))


func _mark_chunk(coords: Vector3i) -> void:
	if coords.x < 0 or coords.y < 0 or coords.z < 0 or coords.x >= CHUNKS_X or coords.y >= CHUNKS_Y or coords.z >= CHUNKS_Z:
		return
	var index := _chunk_index(coords)
	chunk_revisions[index] += 1
	_queue_dirty(index)


func get_block_id(cell: Vector3i) -> int:
	if not _inside_world(cell):
		return air_id
	return blocks[_block_index(cell)]


func is_solid(cell: Vector3i) -> bool:
	return not _inside_world(cell) or get_block_id(cell) != air_id


func _block_index(cell: Vector3i) -> int:
	return cell.x + cell.z * WORLD_X + cell.y * WORLD_X * WORLD_Z


func _chunk_index(coords: Vector3i) -> int:
	return coords.x + coords.z * CHUNKS_X + coords.y * CHUNKS_X * CHUNKS_Z


func _inside_world(cell: Vector3i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.z >= 0 and cell.x < WORLD_X and cell.y < WORLD_Y and cell.z < WORLD_Z


func get_surface_height(x: int, z: int) -> int:
	return heights[clampi(x, 0, WORLD_X - 1) + clampi(z, 0, WORLD_Z - 1) * WORLD_X]


# The city spawn plaza sits on the central street intersection.
func get_city_spawn_position() -> Vector3:
	var surface: int = get_surface_height(CITY_SPAWN_X, CITY_SPAWN_Z)
	return Vector3(float(CITY_SPAWN_X) + 0.5, float(surface) + 1.0, float(CITY_SPAWN_Z) + 0.5)


func restore_save(save_data: Dictionary) -> bool:
	var loaded_blocks: PackedByteArray = save_data.get("blocks", PackedByteArray())
	var metadata: Dictionary = save_data.get("metadata", {})
	var dimensions: Array = metadata.get("dimensions", [])
	if loaded_blocks.size() != BLOCK_VOLUME or dimensions != [WORLD_X, WORLD_Y, WORLD_Z]:
		push_error("M1 restore: save dimensions or block volume do not match this world")
		return false
	blocks = loaded_blocks
	world_seed = int(metadata["seed"])
	var saved_biomes: Array = metadata.get("biome_map", [])
	if saved_biomes.size() != WORLD_X * WORLD_Z:
		push_error("M1 restore: biome map length mismatch")
		return false
	biome_map.resize(saved_biomes.size())
	for index in range(saved_biomes.size()):
		biome_map[index] = int(saved_biomes[index])
	_rebuild_static_light_sources()
	light_dirty_queue.clear()
	light_dirty_set.clear()
	light_dirty_head = 0
	active_light_chunk = -1
	active_light_state.clear()
	light_completion_logged = false
	light_work_frames = 0
	max_light_frame_usec = 0
	initialized_light_chunks = 0
	for index in range(CHUNK_COUNT):
		light_buffers[index].fill(0)
		light_initialized[index] = 0
		chunk_revisions[index] += 1
		_queue_dirty(index)
		_enqueue_light_dirty(index)
	return true

func _log_world_counts() -> void:
	var counts := PackedInt64Array()
	counts.resize(block_defs.size())
	counts.fill(0)
	for block_id in blocks:
		counts[block_id] += 1
	print("CITY world generated seed=%d size=%dx%dx%d chunks=%d" % [world_seed, WORLD_X, WORLD_Y, WORLD_Z, CHUNK_COUNT])
	for block_index in range(block_defs.size()):
		print("CITY block count %s=%d" % [block_defs[block_index].block_id, counts[block_index]])
	var ashen_columns := 0
	for biome_id in biome_map:
		if biome_id == 0:
			ashen_columns += 1
	var cave_air := 0
	for y in range(12):
		for z in range(WORLD_Z):
			for x in range(WORLD_X):
				if get_block_id(Vector3i(x, y, z)) == air_id:
					cave_air += 1
	print("CITY biome count District columns=%d; street-level open air voxels=%d" % [ashen_columns, cave_air])


func _check_slow_frame(delta: float) -> void:
	if delta > 0.020:
		slow_frame_streak += 1
		if slow_frame_streak == 10:
			var active_meshes := 0
			for chunk in chunk_nodes:
				if chunk.mesh_instance.mesh != null:
					active_meshes += 1
			var phase := "generation" if not is_generated else ("light" if light_dirty_head < light_dirty_queue.size() else "meshing/render")
			push_warning("M1 10 consecutive >20ms frames; draw_calls=%d active_chunks=%d phase=%s" % [Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), active_meshes, phase])
	else:
		slow_frame_streak = 0




func emit_gloom_noise(world_position: Vector3, strength: float) -> void:
	if strength > 0.0:
		gloom_noise_emitted.emit(world_position, strength)
