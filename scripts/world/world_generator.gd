extends RefCounted
class_name WorldGenerator

const WORLD_X := 128
const WORLD_Y := 64
const WORLD_Z := 128
const CHUNK_SIZE := 16
const CHUNKS_X := 8
const CHUNKS_Y := 4
const CHUNKS_Z := 8

# Neon City blockout constants. The playfield is a road grid: avenues run along
# Z and streets along X on lines at x/z == 8 (mod 16), three blocks wide. Buildings
# fill the inter-block zones, the ground slab carries asphalt on roads and concrete
# off-road, and the city sits flat on CITY_GROUND.
const CITY_GROUND := 2
const ROAD_LINE := 8
const ROAD_HALF_WIDTH := 1
const BUILDING_MIN_HEIGHT := 4
const BUILDING_MAX_HEIGHT := 15
const BUILDING_SIZE := 8
const LAMP_STRIDE := 12
const SPAWN_X := 8
const SPAWN_Z := 8

static func build_maps(world_seed: int) -> Dictionary:
	var heights := PackedInt32Array()
	heights.resize(WORLD_X * WORLD_Z)
	var biome_map := PackedByteArray()
	biome_map.resize(WORLD_X * WORLD_Z)
	biome_map.fill(0)
	for z in range(WORLD_Z):
		for x in range(WORLD_X):
			heights[x + z * WORLD_X] = CITY_GROUND
	return {"heights": heights, "biome_map": biome_map}


static func generate_chunk(chunk_index: int, world_seed: int, heights: PackedInt32Array, block_ids: Dictionary) -> PackedByteArray:
	var chunk_x := chunk_index % CHUNKS_X
	var chunk_z := int(chunk_index / CHUNKS_X) % CHUNKS_Z
	var chunk_y := int(chunk_index / (CHUNKS_X * CHUNKS_Z))
	var origin_x := chunk_x * CHUNK_SIZE
	var origin_y := chunk_y * CHUNK_SIZE
	var origin_z := chunk_z * CHUNK_SIZE
	var chunk_seed := int((world_seed * 1103515245 + chunk_x * 73856093 + chunk_y * 19349663 + chunk_z * 83492791) & 0x7fffffff)
	var rng := RandomNumberGenerator.new()
	rng.seed = chunk_seed
	var output := PackedByteArray()
	output.resize(CHUNK_SIZE * CHUNK_SIZE * CHUNK_SIZE)
	output.fill(int(block_ids[&"air"]))
	var asphalt_id: int = int(block_ids[&"asphalt"])
	var concrete_id: int = int(block_ids[&"concrete"])
	var lamp_id: int = int(block_ids[&"street_lamp"])
	var neon_id: int = int(block_ids[&"neon_sign"])

	# Ground slab: asphalt on road cells, concrete off-road, from y=0 to CITY_GROUND.
	for z in range(CHUNK_SIZE):
		for y in range(CHUNK_SIZE):
			for x in range(CHUNK_SIZE):
				var world_x := origin_x + x
				var world_z := origin_z + z
				var world_y := origin_y + y
				if world_y > CITY_GROUND or world_x < 0 or world_x >= WORLD_X or world_z < 0 or world_z >= WORLD_Z:
					continue
				var block_id := asphalt_id if _is_road(world_x, world_z) else concrete_id
				output[x + y * CHUNK_SIZE + z * CHUNK_SIZE * CHUNK_SIZE] = block_id

	# Buildings fill the inter-block zones above the ground slab.
	for building in _city_buildings(rng, origin_x, origin_z):
		var min_cell: Vector3i = building["min"]
		var max_cell: Vector3i = building["max"]
		for z in range(min_cell.z, max_cell.z + 1):
			for y in range(min_cell.y, max_cell.y + 1):
				for x in range(min_cell.x, max_cell.x + 1):
					_set_local(output, origin_x, origin_y, origin_z, x, y, z, concrete_id)
		_stamp_neon(output, origin_x, origin_y, origin_z, building, neon_id)

	# Street lamps post on road cells with a deterministic stride.
	for z in range(CHUNK_SIZE):
		for x in range(CHUNK_SIZE):
			var world_x := origin_x + x
			var world_z := origin_z + z
			if world_x < 0 or world_x >= WORLD_X or world_z < 0 or world_z >= WORLD_Z:
				continue
			if not _is_road(world_x, world_z):
				continue
			if world_x % LAMP_STRIDE != 0 and world_z % LAMP_STRIDE != 0:
				continue
			_set_local(output, origin_x, origin_y, origin_z, world_x, CITY_GROUND, world_z, concrete_id)
			_set_local(output, origin_x, origin_y, origin_z, world_x, CITY_GROUND + 1, world_z, concrete_id)
			_set_local(output, origin_x, origin_y, origin_z, world_x, CITY_GROUND + 2, world_z, concrete_id)
			_set_local(output, origin_x, origin_y, origin_z, world_x, CITY_GROUND + 3, world_z, lamp_id)

	return output


static func _city_buildings(rng: RandomNumberGenerator, origin_x: int, origin_z: int) -> Array:
	var buildings: Array = []
	for grid_z in range(0, int(ceil(float(WORLD_Z) / 16.0))):
		for grid_x in range(0, int(ceil(float(WORLD_X) / 16.0))):
			var base_x := 10 + grid_x * 16 + rng.randi_range(0, 1)
			var base_z := 10 + grid_z * 16 + rng.randi_range(0, 1)
			if absi(base_x - SPAWN_X) < 6 and absi(base_z - SPAWN_Z) < 6:
				continue
			var width := BUILDING_SIZE + rng.randi_range(0, 1)
			var depth := BUILDING_SIZE + rng.randi_range(0, 1)
			var height := BUILDING_MIN_HEIGHT + rng.randi_range(0, BUILDING_MAX_HEIGHT - BUILDING_MIN_HEIGHT)
			var min_cell := Vector3i(base_x, CITY_GROUND + 1, base_z)
			var max_cell := Vector3i(base_x + width - 1, CITY_GROUND + height, base_z + depth - 1)
			if max_cell.x < origin_x or min_cell.x > origin_x + CHUNK_SIZE - 1:
				continue
			if max_cell.z < origin_z or min_cell.z > origin_z + CHUNK_SIZE - 1:
				continue
			buildings.append({
				"min": min_cell,
				"max": max_cell,
				"width": width,
				"depth": depth,
				"height": height
			})
	return buildings


static func _stamp_neon(output: PackedByteArray, origin_x: int, origin_y: int, origin_z: int, building: Dictionary, neon_id: int) -> void:
	var min_cell: Vector3i = building["min"]
	var max_cell: Vector3i = building["max"]
	var width: int = building["width"]
	var depth: int = building["depth"]
	var min_x: int = min_cell.x
	var max_x: int = max_cell.x
	var min_z: int = min_cell.z
	var max_z: int = max_cell.z
	# South and north faces run along X (streets); east and west faces run along Z (avenues).
	var candidates := [
		{"pos": Vector3i(min_x + int(width / 2), min_cell.y, min_z - 1), "along_x": true},
		{"pos": Vector3i(min_x + int(width / 2), min_cell.y, max_z + 1), "along_x": true},
		{"pos": Vector3i(min_x - 1, min_cell.y, min_z + int(depth / 2)), "along_x": false},
		{"pos": Vector3i(max_x + 1, min_cell.y, min_z + int(depth / 2)), "along_x": false}
	]
	for candidate in candidates:
		var cell: Vector3i = candidate["pos"]
		if cell.x < 0 or cell.x >= WORLD_X or cell.z < 0 or cell.z >= WORLD_Z:
			continue
		if cell.y < 0 or cell.y >= WORLD_Y:
			continue
		if not _is_road(cell.x, cell.z):
			continue
		for step in range(2):
			var sign_cell := cell
			if candidate["along_x"]:
				sign_cell.y = min_cell.y + step
			else:
				sign_cell.y = min_cell.y + step
			_set_local(output, origin_x, origin_y, origin_z, sign_cell.x, sign_cell.y, sign_cell.z, neon_id)
		return


static func _is_road(x: int, z: int) -> bool:
	return _near_line(x, ROAD_LINE) or _near_line(z, ROAD_LINE)


static func _near_line(coord: int, line: int) -> bool:
	var k := int(floorf(float(coord - line) / 16.0))
	var nearest := line + 16 * k
	return absi(coord - nearest) <= ROAD_HALF_WIDTH


static func _set_local(output: PackedByteArray, origin_x: int, origin_y: int, origin_z: int, x: int, y: int, z: int, block_id: int) -> void:
	if x < origin_x or x >= origin_x + CHUNK_SIZE or y < origin_y or y >= origin_y + CHUNK_SIZE or z < origin_z or z >= origin_z + CHUNK_SIZE:
		return
	output[(x - origin_x) + (y - origin_y) * CHUNK_SIZE + (z - origin_z) * CHUNK_SIZE * CHUNK_SIZE] = block_id


static func _column_seed(world_seed: int, x: int, z: int, salt: int) -> int:
	var value := world_seed * 1103515245 + x * 73856093 + z * 19349663 + salt
	value = (value ^ (value >> 13)) * 1274126177
	return value & 0x7fffffff
