extends RefCounted
class_name WorldGenerator

const WORLD_X := 128
const WORLD_Y := 64
const WORLD_Z := 128
const CHUNK_SIZE := 16
const CHUNKS_X := 8
const CHUNKS_Y := 4
const CHUNKS_Z := 8

# Neon City layout, reworked for real traffic. A 20-block district grid gives
# 7-block roads (three lanes each way), 1-block sidewalks and 11-block lots.
# Intersections sit at x/z == 9 (mod 20) and are the nodes of the traffic graph.
const CITY_GROUND := 2
const GRID_STEP := 20
const ROAD_LINE := 9
const ROAD_HALF_WIDTH := 3
const SIDEWALK_DIST := 4
const LOT_MIN_OFFSET := 5
const LOT_MAX_OFFSET := 15
const DISTRICTS := 6
const BUILDING_MIN_HEIGHT := 7
const BUILDING_MAX_HEIGHT := 26

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
	var output := PackedByteArray()
	output.resize(CHUNK_SIZE * CHUNK_SIZE * CHUNK_SIZE)
	output.fill(int(block_ids[&"air"]))
	var ids := {
		&"asphalt": int(block_ids[&"asphalt"]),
		&"concrete": int(block_ids[&"concrete"]),
		&"sidewalk": int(block_ids[&"sidewalk"]),
		&"road_line": int(block_ids[&"road_line"]),
		&"lamp": int(block_ids[&"street_lamp"]),
		&"neon_sign": int(block_ids[&"neon_sign"]),
		&"facade_dark": int(block_ids[&"facade_dark"]),
		&"facade_mid": int(block_ids[&"facade_mid"]),
		&"facade_light": int(block_ids[&"facade_light"]),
		&"window_warm": int(block_ids[&"window_warm"]),
		&"window_cyan": int(block_ids[&"window_cyan"]),
		&"window_dark": int(block_ids[&"window_dark"]),
		&"neon_pink": int(block_ids[&"neon_pink"]),
		&"neon_blue": int(block_ids[&"neon_blue"]),
		&"neon_yellow": int(block_ids[&"neon_yellow"]),
		&"roof": int(block_ids[&"roof"]),
		&"glass_dark": int(block_ids[&"glass_dark"]),
		&"glass_warm": int(block_ids[&"glass_warm"]),
		&"glass_cyan": int(block_ids[&"glass_cyan"]),
		&"facade_brick": int(block_ids[&"facade_brick"]),
		&"facade_panel": int(block_ids[&"facade_panel"]),
		&"crosswalk": int(block_ids[&"crosswalk"]),
		&"traffic_light": int(block_ids[&"traffic_light"]),
		&"billboard": int(block_ids[&"billboard"])
	}

	for z in range(CHUNK_SIZE):
		for y in range(CHUNK_SIZE):
			for x in range(CHUNK_SIZE):
				var world_x := origin_x + x
				var world_z := origin_z + z
				var world_y := origin_y + y
				if world_y > CITY_GROUND or world_x < 0 or world_x >= WORLD_X or world_z < 0 or world_z >= WORLD_Z:
					continue
				var surface_id: int = ids[&"concrete"]
				if _is_road(world_x, world_z):
					surface_id = ids[&"asphalt"]
					if world_y == CITY_GROUND and _is_crosswalk(world_x, world_z):
						surface_id = ids[&"crosswalk"]
					elif world_y == CITY_GROUND and _is_lane_marking(world_x, world_z):
						surface_id = ids[&"road_line"]
				elif _is_sidewalk(world_x, world_z):
					surface_id = ids[&"sidewalk"]
				output[x + y * CHUNK_SIZE + z * CHUNK_SIZE * CHUNK_SIZE] = surface_id

	for gx in range(DISTRICTS):
		for gz in range(DISTRICTS):
			var lot_min_x := ROAD_LINE + gx * GRID_STEP + LOT_MIN_OFFSET
			var lot_max_x := ROAD_LINE + gx * GRID_STEP + LOT_MAX_OFFSET
			var lot_min_z := ROAD_LINE + gz * GRID_STEP + LOT_MIN_OFFSET
			var lot_max_z := ROAD_LINE + gz * GRID_STEP + LOT_MAX_OFFSET
			if lot_max_x < origin_x or lot_min_x > origin_x + CHUNK_SIZE - 1:
				continue
			if lot_max_z < origin_z or lot_min_z > origin_z + CHUNK_SIZE - 1:
				continue
			if gx == 0 and gz == 0:
				_stamp_plaza_monument(output, origin_x, origin_y, origin_z, ids)
			else:
				_stamp_building(output, origin_x, origin_y, origin_z, world_seed, gx, gz, ids)

	for z in range(CHUNK_SIZE):
		for x in range(CHUNK_SIZE):
			var world_x := origin_x + x
			var world_z := origin_z + z
			if world_x < 0 or world_x >= WORLD_X or world_z < 0 or world_z >= WORLD_Z:
				continue
			if not _is_sidewalk(world_x, world_z) or (world_x + world_z) % 12 != 0:
				continue
			_set_local(output, origin_x, origin_y, origin_z, world_x, CITY_GROUND + 1, world_z, ids[&"lamp"])

	# Traffic lights on the four corners of each intersection.
	for z in range(CHUNK_SIZE):
		for x in range(CHUNK_SIZE):
			var world_x := origin_x + x
			var world_z := origin_z + z
			if world_x < 0 or world_x >= WORLD_X or world_z < 0 or world_z >= WORLD_Z:
				continue
			if _line_distance(world_x) == SIDEWALK_DIST and _line_distance(world_z) == SIDEWALK_DIST:
				_set_local(output, origin_x, origin_y, origin_z, world_x, CITY_GROUND + 1, world_z, ids[&"traffic_light"])

	return output


static func _stamp_building(output: PackedByteArray, origin_x: int, origin_y: int, origin_z: int, world_seed: int, gx: int, gz: int, ids: Dictionary) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = _lot_seed(world_seed, gx, gz)
	if rng.randf() < 0.08:
		return
	var width := 8 + rng.randi_range(0, 2)
	var depth := 8 + rng.randi_range(0, 2)
	var slot_width := LOT_MAX_OFFSET - LOT_MIN_OFFSET + 1
	var min_x := ROAD_LINE + gx * GRID_STEP + LOT_MIN_OFFSET + rng.randi_range(0, slot_width - width)
	var min_z := ROAD_LINE + gz * GRID_STEP + LOT_MIN_OFFSET + rng.randi_range(0, slot_width - depth)
	var max_x := min_x + width - 1
	var max_z := min_z + depth - 1
	var height := BUILDING_MIN_HEIGHT + rng.randi_range(0, 17)
	if rng.randf() < 0.30:
		height = 24 + rng.randi_range(0, 14)
	var base_y := CITY_GROUND + 1
	var top_y := mini(base_y + height - 1, WORLD_Y - 1)
	var facade_ids := [ids[&"facade_dark"], ids[&"facade_mid"], ids[&"facade_light"], ids[&"facade_brick"], ids[&"facade_panel"]]
	var facade_id: int = facade_ids[rng.randi_range(0, facade_ids.size() - 1)]
	var accent_id: int = facade_ids[(rng.randi_range(0, facade_ids.size() - 1) + 1) % facade_ids.size()]
	var window_id: int = ids[&"glass_warm"] if rng.randf() < 0.5 else ids[&"glass_cyan"]
	var glass_dark_id: int = ids[&"glass_dark"]
	var neon_id: int = ids[&"neon_pink"] if rng.randf() < 0.4 else (ids[&"neon_blue"] if rng.randf() < 0.65 else ids[&"neon_yellow"])
	var band_y := base_y + maxi(3, int(height * 0.55))
	var sign_face := rng.randi_range(0, 3)

	for y in range(base_y, top_y + 1):
		var inset := 0
		if y > base_y + int(height * 0.72):
			inset = 1
		var x0 := min_x + inset
		var x1 := max_x - inset
		var z0 := min_z + inset
		var z1 := max_z - inset
		if x1 < x0 or z1 < z0:
			continue
		var vertical := y - base_y
		for x in range(x0, x1 + 1):
			for z in range(z0, z1 + 1):
				var block_id: int = facade_id if (vertical / 5) % 2 == 0 else accent_id
				var on_face := x == x0 or x == x1 or z == z0 or z == z1
				if y == top_y:
					block_id = ids[&"roof"]
				elif on_face and vertical > 0:
					var horizontal := z - z0 if x == x0 or x == x1 else x - x0
					var face_index := 0 if z == z0 else (1 if z == z1 else (2 if x == x0 else 3))
					if sign_face == face_index and horizontal == 0 and vertical > 2:
						block_id = neon_id
					elif vertical == band_y - base_y and face_index == (sign_face + 1) % 4:
						block_id = neon_id
					elif vertical == 1 and horizontal % 2 == 0:
						block_id = window_id
					elif horizontal % 2 == 0 and vertical % 2 == 1:
						var lit := int(_cell_hash(world_seed, x, y, z) % 100) < 60
						block_id = window_id if lit else glass_dark_id
				_set_local(output, origin_x, origin_y, origin_z, x, y, z, block_id)

	var mid_x := (min_x + max_x) / 2
	var mid_z := (min_z + max_z) / 2
	_set_local(output, origin_x, origin_y, origin_z, mid_x - 1, top_y + 1, mid_z - 1, ids[&"roof"])
	_set_local(output, origin_x, origin_y, origin_z, mid_x, top_y + 1, mid_z, ids[&"roof"])
	_set_local(output, origin_x, origin_y, origin_z, mid_x, top_y + 2, mid_z, facade_id)
	if height >= 15:
		for dy in range(2):
			for dx in range(-1, 2):
				_set_local(output, origin_x, origin_y, origin_z, mid_x + dx, top_y - dy, min_z - 1, ids[&"billboard"])
	if height >= 18:
		_set_local(output, origin_x, origin_y, origin_z, mid_x, top_y + 3, mid_z, ids[&"neon_blue"])


static func _stamp_plaza_monument(output: PackedByteArray, origin_x: int, origin_y: int, origin_z: int, ids: Dictionary) -> void:
	var center := ROAD_LINE + LOT_MIN_OFFSET + 5
	for y in range(CITY_GROUND + 1, CITY_GROUND + 6):
		_set_local(output, origin_x, origin_y, origin_z, center, y, center, ids[&"facade_mid"])
	for dx in range(-1, 2):
		for dz in range(-1, 2):
			if absi(dx) == 1 and absi(dz) == 1:
				continue
			_set_local(output, origin_x, origin_y, origin_z, center + dx, CITY_GROUND + 1, center + dz, ids[&"neon_pink"])
	_set_local(output, origin_x, origin_y, origin_z, center, CITY_GROUND + 6, center, ids[&"neon_sign"])


static func _line_index(coord: int) -> int:
	return roundi(float(coord - ROAD_LINE) / float(GRID_STEP))


static func _line_center(coord: int) -> int:
	return ROAD_LINE + GRID_STEP * _line_index(coord)


static func _line_distance(coord: int) -> int:
	return absi(coord - _line_center(coord))


static func _lot_seed(world_seed: int, gx: int, gz: int) -> int:
	var value := world_seed * 1103515245 + gx * 73856093 + gz * 83492791
	value = (value ^ (value >> 13)) * 1274126177
	return value & 0x7fffffff


static func _cell_hash(world_seed: int, x: int, y: int, z: int) -> int:
	var value := world_seed * 1103515245 + x * 73856093 + y * 19349663 + z * 83492791
	value = (value ^ (value >> 13)) * 1274126177
	return value & 0x7fffffff


static func _is_road(x: int, z: int) -> bool:
	return _line_distance(x) <= ROAD_HALF_WIDTH or _line_distance(z) <= ROAD_HALF_WIDTH


static func _is_sidewalk(x: int, z: int) -> bool:
	if _is_road(x, z):
		return false
	return _line_distance(x) == SIDEWALK_DIST or _line_distance(z) == SIDEWALK_DIST


# Zebra stripes just outside each intersection, across both road axes.
static func _is_crosswalk(x: int, z: int) -> bool:
	var x_road := _line_distance(x) <= ROAD_HALF_WIDTH
	var z_road := _line_distance(z) <= ROAD_HALF_WIDTH
	if x_road and _line_distance(z) == ROAD_HALF_WIDTH:
		return x % 2 == 0
	if z_road and _line_distance(x) == ROAD_HALF_WIDTH:
		return z % 2 == 0
	return false


# Dashed centre line: one cell on the road axis, omitted at intersections.
static func _is_lane_marking(x: int, z: int) -> bool:
	var x_line := _line_distance(x) == 0
	var z_line := _line_distance(z) == 0
	if x_line and z_line:
		return false
	if not (x_line or z_line):
		return false
	var offset := z - ROAD_LINE if x_line else x - ROAD_LINE
	return fposmod(float(offset), 4.0) < 2.0


static func _set_local(output: PackedByteArray, origin_x: int, origin_y: int, origin_z: int, x: int, y: int, z: int, block_id: int) -> void:
	if x < origin_x or x >= origin_x + CHUNK_SIZE or y < origin_y or y >= origin_y + CHUNK_SIZE or z < origin_z or z >= origin_z + CHUNK_SIZE:
		return
	output[(x - origin_x) + (y - origin_y) * CHUNK_SIZE + (z - origin_z) * CHUNK_SIZE * CHUNK_SIZE] = block_id
