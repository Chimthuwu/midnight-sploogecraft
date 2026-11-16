extends RefCounted
class_name WorldGenerator

const WORLD_X := 128
const WORLD_Y := 64
const WORLD_Z := 128
const CHUNK_SIZE := 16
const CHUNKS_X := 8
const CHUNKS_Y := 4
const CHUNKS_Z := 8

# Neon City layout. Roads run on lines x/z == 8 (mod 16), three blocks wide.
# Each 16-block district is: road 7..9, sidewalk 6 and 10, lot 11..21, sidewalk 22,
# then the next road at 23..25. Buildings are generated per LOT (not per chunk) so
# they cross chunk borders intact and stay deterministic from the world seed.
const CITY_GROUND := 2
const ROAD_LINE := 8
const ROAD_HALF_WIDTH := 1
const DISTRICTS := 7
const LOT_MIN_OFFSET := 3
const LOT_MAX_OFFSET := 13
const BUILDING_MIN_HEIGHT := 6
const BUILDING_MAX_HEIGHT := 26
const LAMP_STRIDE := 12

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
		&"roof": int(block_ids[&"roof"])
	}

	# Ground slab: asphalt roadway, pale sidewalk, darker concrete lots.
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
					if world_y == CITY_GROUND and _is_lane_marking(world_x, world_z):
						surface_id = ids[&"road_line"]
				elif _is_sidewalk(world_x, world_z):
					surface_id = ids[&"sidewalk"]
				output[x + y * CHUNK_SIZE + z * CHUNK_SIZE * CHUNK_SIZE] = surface_id

	# Buildings, generated per district lot and clipped into this chunk.
	for gx in range(DISTRICTS):
		for gz in range(DISTRICTS):
			var lot_min_x := ROAD_LINE + gx * 16 + LOT_MIN_OFFSET
			var lot_max_x := ROAD_LINE + gx * 16 + LOT_MAX_OFFSET
			var lot_min_z := ROAD_LINE + gz * 16 + LOT_MIN_OFFSET
			var lot_max_z := ROAD_LINE + gz * 16 + LOT_MAX_OFFSET
			if lot_max_x < origin_x or lot_min_x > origin_x + CHUNK_SIZE - 1:
				continue
			if lot_max_z < origin_z or lot_min_z > origin_z + CHUNK_SIZE - 1:
				continue
			if gx == 0 and gz == 0:
				_stamp_plaza_monument(output, origin_x, origin_y, origin_z, ids)
			else:
				_stamp_building(output, origin_x, origin_y, origin_z, world_seed, gx, gz, ids)

	# Street lamps on sidewalk cells, spaced along the road grid.
	for z in range(CHUNK_SIZE):
		for x in range(CHUNK_SIZE):
			var world_x := origin_x + x
			var world_z := origin_z + z
			if world_x < 0 or world_x >= WORLD_X or world_z < 0 or world_z >= WORLD_Z:
				continue
			if not _is_sidewalk(world_x, world_z):
				continue
			if (world_x + world_z) % LAMP_STRIDE != 0:
				continue
			_set_local(output, origin_x, origin_y, origin_z, world_x, CITY_GROUND + 1, world_z, ids[&"lamp"])

	return output


# One deterministic building per lot, built identically in every chunk it touches.
static func _stamp_building(output: PackedByteArray, origin_x: int, origin_y: int, origin_z: int, world_seed: int, gx: int, gz: int, ids: Dictionary) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = _lot_seed(world_seed, gx, gz)
	if rng.randf() < 0.10:
		return
	var width := 8 + rng.randi_range(0, 2)
	var depth := 8 + rng.randi_range(0, 2)
	var min_x := ROAD_LINE + gx * 16 + LOT_MIN_OFFSET + rng.randi_range(0, 11 - width)
	var min_z := ROAD_LINE + gz * 16 + LOT_MIN_OFFSET + rng.randi_range(0, 11 - depth)
	var max_x := min_x + width - 1
	var max_z := min_z + depth - 1
	var height := BUILDING_MIN_HEIGHT + rng.randi_range(0, BUILDING_MAX_HEIGHT - BUILDING_MIN_HEIGHT)
	if rng.randf() < 0.25:
		height = 8 + rng.randi_range(0, 8)
	var base_y := CITY_GROUND + 1
	var top_y := base_y + height - 1
	if top_y >= WORLD_Y:
		top_y = WORLD_Y - 1
	var facade_id: int = ids[&"facade_dark"] if rng.randf() < 0.55 else (ids[&"facade_mid"] if rng.randf() < 0.65 else ids[&"facade_light"])
	var window_id: int = ids[&"window_warm"] if rng.randf() < 0.5 else ids[&"window_cyan"]
	var neon_id: int = ids[&"neon_pink"] if rng.randf() < 0.4 else (ids[&"neon_blue"] if rng.randf() < 0.6 else ids[&"neon_yellow"])
	var sign_side := rng.randi_range(0, 3)
	var band_low := base_y + maxi(3, int(height * 0.45))
	var band_high := base_y + maxi(4, int(height * 0.78))

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
				var block_id: int = facade_id
				var on_face := x == x0 or x == x1 or z == z0 or z == z1
				if y == top_y:
					block_id = ids[&"roof"]
				elif on_face and vertical > 0:
					var horizontal := z - z0 if x == x0 or x == x1 else x - x0
					if vertical == 1 or vertical == 2:
						# Shopfront band: alternating lit panels at street level.
						if horizontal % 3 != 2:
							block_id = neon_id
					elif vertical == band_low or vertical == band_low + 1 or vertical == band_high or vertical == band_high + 1:
						block_id = neon_id
					elif horizontal % 3 == 1 and vertical % 2 == 1:
						var lit := int(_cell_hash(world_seed, x, y, z) % 100) < 72
						block_id = window_id if lit else ids[&"window_dark"]
					elif sign_side == 0 and z == z0 and vertical >= band_low and vertical < band_low + 5 and horizontal >= 1 and horizontal <= 3:
						block_id = neon_id
					elif sign_side == 1 and z == z1 and vertical >= band_high - 4 and vertical < band_high and horizontal >= 1 and horizontal <= 3:
						block_id = neon_id
				_set_local(output, origin_x, origin_y, origin_z, x, y, z, block_id)

	# Rooftop silhouette: a small plant box and an antenna mast.
	var mid_x := (min_x + max_x) / 2
	var mid_z := (min_z + max_z) / 2
	_set_local(output, origin_x, origin_y, origin_z, mid_x - 1, top_y + 1, mid_z - 1, ids[&"roof"])
	_set_local(output, origin_x, origin_y, origin_z, mid_x, top_y + 1, mid_z, ids[&"roof"])
	_set_local(output, origin_x, origin_y, origin_z, mid_x, top_y + 2, mid_z, facade_id)
	if height >= 18:
		_set_local(output, origin_x, origin_y, origin_z, mid_x, top_y + 3, mid_z, neon_id)


# A small landmark plaza on the spawn-facing lot so the player starts in a city,
# not an empty field.
static func _stamp_plaza_monument(output: PackedByteArray, origin_x: int, origin_y: int, origin_z: int, ids: Dictionary) -> void:
	var center_x := ROAD_LINE + LOT_MIN_OFFSET + 5
	var center_z := ROAD_LINE + LOT_MIN_OFFSET + 5
	for y in range(CITY_GROUND + 1, CITY_GROUND + 6):
		_set_local(output, origin_x, origin_y, origin_z, center_x, y, center_z, ids[&"facade_mid"])
	for dx in range(-1, 2):
		for dz in range(-1, 2):
			if absi(dx) == 1 and absi(dz) == 1:
				continue
			_set_local(output, origin_x, origin_y, origin_z, center_x + dx, CITY_GROUND + 1, center_z + dz, ids[&"neon_pink"])
	_set_local(output, origin_x, origin_y, origin_z, center_x, CITY_GROUND + 6, center_z, ids[&"neon_sign"])


static func _lot_seed(world_seed: int, gx: int, gz: int) -> int:
	var value := world_seed * 1103515245 + gx * 73856093 + gz * 83492791
	value = (value ^ (value >> 13)) * 1274126177
	return value & 0x7fffffff


static func _cell_hash(world_seed: int, x: int, y: int, z: int) -> int:
	var value := world_seed * 1103515245 + x * 73856093 + y * 19349663 + z * 83492791
	value = (value ^ (value >> 13)) * 1274126177
	return value & 0x7fffffff


static func _is_road(x: int, z: int) -> bool:
	return _near_line(x) or _near_line(z)


static func _is_sidewalk(x: int, z: int) -> bool:
	if _is_road(x, z):
		return false
	return _near_line(x + 1) or _near_line(x - 1) or _near_line(z + 1) or _near_line(z - 1)


# Dashed centre line, omitted at intersections so junctions read clearly.
static func _is_lane_marking(x: int, z: int) -> bool:
	var x_line := _near_line(x)
	var z_line := _near_line(z)
	if x_line and z_line:
		return false
	var offset := z - ROAD_LINE if x_line else x - ROAD_LINE
	return x_line == (x % 16 == ROAD_LINE) and fposmod(float(offset), 4.0) < 2.0


static func _near_line(coord: int) -> bool:
	var k := roundi(float(coord - ROAD_LINE) / 16.0)
	return absi(coord - (ROAD_LINE + 16 * k)) <= ROAD_HALF_WIDTH


static func _set_local(output: PackedByteArray, origin_x: int, origin_y: int, origin_z: int, x: int, y: int, z: int, block_id: int) -> void:
	if x < origin_x or x >= origin_x + CHUNK_SIZE or y < origin_y or y >= origin_y + CHUNK_SIZE or z < origin_z or z >= origin_z + CHUNK_SIZE:
		return
	output[(x - origin_x) + (y - origin_y) * CHUNK_SIZE + (z - origin_z) * CHUNK_SIZE * CHUNK_SIZE] = block_id
