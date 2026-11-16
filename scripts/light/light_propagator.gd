extends RefCounted
class_name VoxelLightPropagator

const WORLD_X := 128
const WORLD_Y := 64
const WORLD_Z := 128
const CHUNK_SIZE := 16
const LIGHT_RANGE := 15
const PADDED_SIZE := CHUNK_SIZE + LIGHT_RANGE * 2
const PADDED_VOLUME := PADDED_SIZE * PADDED_SIZE * PADDED_SIZE
const NEIGHBOR_OFFSETS := [-1, 1, -PADDED_SIZE, PADDED_SIZE, -PADDED_SIZE * PADDED_SIZE, PADDED_SIZE * PADDED_SIZE]


static func begin_chunk(blocks: PackedByteArray, chunk: Vector3i, sources: Array, attenuation: PackedByteArray, wall_id: int) -> Dictionary:
	var origin := chunk * CHUNK_SIZE - Vector3i(LIGHT_RANGE, LIGHT_RANGE, LIGHT_RANGE)
	var relevant_sources: Array[Dictionary] = []
	for source in sources:
		var source_cell: Vector3i = source["cell"]
		var source_level: int = source["level"]
		var local := source_cell - origin
		if source_level <= 0 or local.x < 0 or local.y < 0 or local.z < 0 or local.x >= PADDED_SIZE or local.y >= PADDED_SIZE or local.z >= PADDED_SIZE:
			continue
		var core_origin := chunk * CHUNK_SIZE
		var dx := maxi(0, maxi(core_origin.x - source_cell.x, source_cell.x - (core_origin.x + CHUNK_SIZE - 1)))
		var dy := maxi(0, maxi(core_origin.y - source_cell.y, source_cell.y - (core_origin.y + CHUNK_SIZE - 1)))
		var dz := maxi(0, maxi(core_origin.z - source_cell.z, source_cell.z - (core_origin.z + CHUNK_SIZE - 1)))
		# Every block attenuates by at least one, so this source cannot reach the core.
		if dx + dy + dz >= source_level:
			continue
		relevant_sources.append({"index": local.x + local.y * PADDED_SIZE + local.z * PADDED_SIZE * PADDED_SIZE, "level": source_level})
	var blank_result := PackedByteArray()
	blank_result.resize(CHUNK_SIZE * CHUNK_SIZE * CHUNK_SIZE)
	blank_result.fill(0)
	if relevant_sources.is_empty():
		return {"done": true, "result": blank_result}
	var blocks_padded := _copy_padded_blocks(blocks, origin, wall_id)
	var light_padded := PackedByteArray()
	light_padded.resize(PADDED_VOLUME)
	light_padded.fill(0)
	var buckets: Array[Array] = []
	for level in range(LIGHT_RANGE + 1):
		buckets.append([])
	for source in relevant_sources:
		var source_index: int = source["index"]
		var source_level: int = source["level"]
		if source_level > light_padded[source_index]:
			light_padded[source_index] = source_level
			buckets[source_level].append(source_index)
	return {"blocks": blocks_padded, "light": light_padded, "buckets": buckets, "level": LIGHT_RANGE, "done": false, "result": PackedByteArray(), "attenuation": attenuation}
static func advance_chunk(state: Dictionary, work_budget: int) -> bool:
	if state["done"]:
		return true
	var blocks_padded: PackedByteArray = state["blocks"]
	var light_padded: PackedByteArray = state["light"]
	var buckets: Array = state["buckets"]
	var level: int = state["level"]
	var processed := 0
	while level > 0 and processed < work_budget:
		var bucket: Array = buckets[level]
		if bucket.is_empty():
			level -= 1
			continue
		var current_index: int = bucket.pop_back()
		processed += 1
		if light_padded[current_index] != level:
			continue
		var local_x := current_index % PADDED_SIZE
		var local_row := int(current_index / PADDED_SIZE)
		var local_y := local_row % PADDED_SIZE
		var local_z := int(local_row / PADDED_SIZE)
		for direction in range(6):
			if direction == 0 and local_x == 0: continue
			if direction == 1 and local_x == PADDED_SIZE - 1: continue
			if direction == 2 and local_y == 0: continue
			if direction == 3 and local_y == PADDED_SIZE - 1: continue
			if direction == 4 and local_z == 0: continue
			if direction == 5 and local_z == PADDED_SIZE - 1: continue
			var neighbor_index: int = current_index + NEIGHBOR_OFFSETS[direction]
			var candidate := level - int(state["attenuation"][blocks_padded[neighbor_index]])
			if candidate > 0 and candidate > light_padded[neighbor_index]:
				light_padded[neighbor_index] = candidate
				buckets[candidate].append(neighbor_index)
	state["level"] = level
	state["light"] = light_padded
	state["buckets"] = buckets
	if level <= 0:
		state["result"] = _extract_core(light_padded)
		state["done"] = true
	return state["done"]


static func build_chunk(blocks: PackedByteArray, chunk: Vector3i, sources: Array, attenuation: PackedByteArray, wall_id: int) -> PackedByteArray:
	var state := begin_chunk(blocks, chunk, sources, attenuation, wall_id)
	state["attenuation"] = attenuation
	while not advance_chunk(state, PADDED_VOLUME * 8):
		pass
	return state["result"]


static func _extract_core(light_padded: PackedByteArray) -> PackedByteArray:
	var result := PackedByteArray()
	result.resize(CHUNK_SIZE * CHUNK_SIZE * CHUNK_SIZE)
	var core_origin := Vector3i(LIGHT_RANGE, LIGHT_RANGE, LIGHT_RANGE)
	var write_index := 0
	for z in range(CHUNK_SIZE):
		for y in range(CHUNK_SIZE):
			var row_start := core_origin.x + (core_origin.y + y) * PADDED_SIZE + (core_origin.z + z) * PADDED_SIZE * PADDED_SIZE
			for x in range(CHUNK_SIZE):
				result[write_index] = light_padded[row_start + x]
				write_index += 1
	return result


static func _copy_padded_blocks(blocks: PackedByteArray, origin: Vector3i, wall_id: int) -> PackedByteArray:
	var padded := PackedByteArray()
	var wall_row := PackedByteArray()
	wall_row.resize(PADDED_SIZE)
	wall_row.fill(wall_id)
	var copy_x_begin := maxi(0, -origin.x)
	var copy_x_end := mini(PADDED_SIZE, WORLD_X - origin.x)
	for z in range(PADDED_SIZE):
		var world_z := origin.z + z
		for y in range(PADDED_SIZE):
			var world_y := origin.y + y
			if world_z < 0 or world_z >= WORLD_Z or world_y < 0 or world_y >= WORLD_Y:
				padded.append_array(wall_row)
				continue
			if copy_x_begin > 0:
				padded.append_array(wall_row.slice(0, copy_x_begin))
			var row_start := origin.x + copy_x_begin + world_z * WORLD_X + world_y * WORLD_X * WORLD_Z
			var copy_count := copy_x_end - copy_x_begin
			if copy_count > 0:
				padded.append_array(blocks.slice(row_start, row_start + copy_count))
			if copy_x_end < PADDED_SIZE:
				padded.append_array(wall_row.slice(copy_x_end, PADDED_SIZE))
	if padded.size() != PADDED_VOLUME:
		push_error("Light propagator produced an invalid padded block volume")
	return padded