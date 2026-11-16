extends RefCounted
class_name WorldGenerator

const WORLD_X := 128
const WORLD_Y := 64
const WORLD_Z := 128
const CHUNK_SIZE := 16
const CHUNKS_X := 8
const CHUNKS_Y := 4
const CHUNKS_Z := 8

# 20-block districts: 7-block roads, 1-block sidewalks, 11-block lots.
# Intersections sit at x/z == 9 (mod 20) and are the traffic graph nodes.
const CITY_GROUND := 2
const GRID_STEP := 20
const ROAD_LINE := 9
const ROAD_HALF_WIDTH := 3
const SIDEWALK_DIST := 4
const LOT_MIN_OFFSET := 5
const LOT_MAX_OFFSET := 15
const DISTRICTS := 6

const DISTRICT_DOWNTOWN := 0
const DISTRICT_NEON := 1
const DISTRICT_INDUSTRIAL := 2
const DISTRICT_RESIDENTIAL := 3
const DISTRICT_OUTSKIRTS := 4

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
		&"facade_brick": int(block_ids[&"facade_brick"]),
		&"facade_panel": int(block_ids[&"facade_panel"]),
		&"glass_dark": int(block_ids[&"glass_dark"]),
		&"glass_warm": int(block_ids[&"glass_warm"]),
		&"glass_cyan": int(block_ids[&"glass_cyan"]),
		&"neon_pink": int(block_ids[&"neon_pink"]),
		&"neon_blue": int(block_ids[&"neon_blue"]),
		&"neon_green": int(block_ids[&"neon_green"]),
		&"neon_red": int(block_ids[&"neon_red"]),
		&"neon_yellow": int(block_ids[&"neon_yellow"]),
		&"roof": int(block_ids[&"roof"]),
		&"rust_metal": int(block_ids[&"rust_metal"]),
		&"garage_door": int(block_ids[&"garage_door"]),
		&"sign_panel": int(block_ids[&"sign_panel"]),
		&"graffiti": int(block_ids[&"graffiti"]),
		&"billboard": int(block_ids[&"billboard"]),
		&"crosswalk": int(block_ids[&"crosswalk"]),
		&"traffic_light": int(block_ids[&"traffic_light"])
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
				_stamp_lot(output, origin_x, origin_y, origin_z, world_seed, gx, gz, ids)

	for z in range(CHUNK_SIZE):
		for x in range(CHUNK_SIZE):
			var world_x := origin_x + x
			var world_z := origin_z + z
			if world_x < 0 or world_x >= WORLD_X or world_z < 0 or world_z >= WORLD_Z:
				continue
			if not _is_sidewalk(world_x, world_z) or (world_x + world_z) % 12 != 0:
				continue
			_set_local(output, origin_x, origin_y, origin_z, world_x, CITY_GROUND + 1, world_z, ids[&"lamp"])

	for z in range(CHUNK_SIZE):
		for x in range(CHUNK_SIZE):
			var world_x := origin_x + x
			var world_z := origin_z + z
			if world_x < 0 or world_x >= WORLD_X or world_z < 0 or world_z >= WORLD_Z:
				continue
			if _line_distance(world_x) == SIDEWALK_DIST and _line_distance(world_z) == SIDEWALK_DIST:
				_set_local(output, origin_x, origin_y, origin_z, world_x, CITY_GROUND + 1, world_z, ids[&"facade_dark"])
				_set_local(output, origin_x, origin_y, origin_z, world_x, CITY_GROUND + 2, world_z, ids[&"facade_dark"])
				_set_local(output, origin_x, origin_y, origin_z, world_x, CITY_GROUND + 3, world_z, ids[&"traffic_light"])

	return output


static func _district(gx: int, gz: int) -> int:
	# The spawn quadrant is an entertainment/neon district so the city's identity
	# is visible the moment the player steps outside, not 40 blocks away.
	if gx == 5 or gz == 5:
		return DISTRICT_OUTSKIRTS
	if gx <= 2 and gz <= 2:
		return DISTRICT_NEON
	if (gx <= 1 and gz >= 3) or (gz <= 1 and gx >= 3):
		return DISTRICT_INDUSTRIAL
	if gx >= 2 and gx <= 3 and gz >= 2 and gz <= 3:
		return DISTRICT_DOWNTOWN
	if gx >= 3 and gz >= 2:
		return DISTRICT_NEON
	return DISTRICT_RESIDENTIAL


static func _style_for(district: int, ids: Dictionary) -> Dictionary:
	var style := {}
	match district:
		DISTRICT_DOWNTOWN:
			style = {
				"facades": [ids[&"facade_panel"], ids[&"facade_dark"], ids[&"facade_mid"]],
				"height_min": 24, "height_var": 16,
				"win_x": 2, "win_y": 2, "lit_chance": 52,
				"neon": -1, "strip": false, "bands": 1,
				"shop": false, "balcony": false, "entrance": true,
				"roof": "crown", "alley": false, "graffiti": 0, "garage": false
			}
		DISTRICT_NEON:
			style = {
				"facades": [ids[&"facade_dark"], ids[&"facade_brick"], ids[&"facade_mid"]],
				"height_min": 9, "height_var": 12,
				"win_x": 2, "win_y": 2, "lit_chance": 55,
				"neon": ids[&"neon_pink"], "strip": true, "bands": 0, "sign": 1,
				"shop": true, "balcony": false, "entrance": true,
				"roof": "billboard", "alley": true, "graffiti": 0, "garage": false
			}
		DISTRICT_INDUSTRIAL:
			style = {
				"facades": [ids[&"facade_brick"], ids[&"rust_metal"], ids[&"concrete"]],
				"height_min": 6, "height_var": 7,
				"win_x": 4, "win_y": 3, "lit_chance": 30,
				"neon": -1, "strip": false, "bands": 0,
				"shop": false, "balcony": false, "entrance": true,
				"roof": "vent", "alley": false, "graffiti": 0, "garage": true
			}
		DISTRICT_RESIDENTIAL:
			style = {
				"facades": [ids[&"facade_brick"], ids[&"facade_light"], ids[&"facade_mid"]],
				"height_min": 8, "height_var": 9,
				"win_x": 2, "win_y": 2, "lit_chance": 50,
				"neon": -1, "strip": false, "bands": 0,
				"shop": false, "balcony": true, "entrance": true,
				"roof": "ac", "alley": false, "graffiti": 0, "garage": false
			}
		_:
			style = {
				"facades": [ids[&"facade_dark"], ids[&"facade_brick"], ids[&"facade_mid"]],
				"height_min": 5, "height_var": 6,
				"win_x": 3, "win_y": 3, "lit_chance": 30,
				"neon": ids[&"neon_red"], "strip": false, "bands": 0, "sign": 1,
				"shop": false, "balcony": false, "entrance": true,
				"roof": "antenna", "alley": true, "graffiti": 30, "garage": false
			}
	return style


static func _stamp_lot(output: PackedByteArray, origin_x: int, origin_y: int, origin_z: int, world_seed: int, gx: int, gz: int, ids: Dictionary) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = _lot_seed(world_seed, gx, gz)
	if rng.randf() < 0.06:
		return
	var district := _district(gx, gz)
	var style := _style_for(district, ids)
	var lot_min_x := ROAD_LINE + gx * GRID_STEP + LOT_MIN_OFFSET
	var lot_min_z := ROAD_LINE + gz * GRID_STEP + LOT_MIN_OFFSET
	var slot := LOT_MAX_OFFSET - LOT_MIN_OFFSET + 1
	var alley: bool = bool(style["alley"]) and rng.randf() < 0.55
	if alley:
		var first := rng.randi_range(4, 5)
		var gap := rng.randi_range(2, 3)
		var second := slot - first - gap
		if second >= 3:
			_stamp_tower(output, origin_x, origin_y, origin_z, lot_min_x, lot_min_z, first, slot, style, _cell_hash(world_seed, gx, gz, 1), ids)
			_stamp_tower(output, origin_x, origin_y, origin_z, lot_min_x + first + gap, lot_min_z, second, slot, style, _cell_hash(world_seed, gx, gz, 2), ids)
		else:
			_stamp_tower(output, origin_x, origin_y, origin_z, lot_min_x, lot_min_z, slot - 2, slot, style, world_seed + gx * 31 + gz, ids)
	else:
		var width := rng.randi_range(8, slot)
		var depth := rng.randi_range(8, slot)
		if district == DISTRICT_INDUSTRIAL:
			depth = rng.randi_range(6, 8)
		var offset_x := rng.randi_range(0, slot - width)
		var offset_z := 0 if district == DISTRICT_INDUSTRIAL else rng.randi_range(0, slot - depth)
		_stamp_tower(output, origin_x, origin_y, origin_z, lot_min_x + offset_x, lot_min_z + offset_z, width, depth, style, world_seed + gx * 17 + gz * 29, ids)
		if district == DISTRICT_INDUSTRIAL:
			_stamp_container_yard(output, origin_x, origin_y, origin_z, lot_min_x, lot_min_z + depth, slot, slot - depth, world_seed + gx * 7 + gz, ids)
		elif district == DISTRICT_OUTSKIRTS:
			_stamp_lot_clutter(output, origin_x, origin_y, origin_z, lot_min_x, lot_min_z, slot, world_seed + gx * 13 + gz, ids)


static func _stamp_container_yard(output: PackedByteArray, origin_x: int, origin_y: int, origin_z: int, min_x: int, min_z: int, width: int, depth: int, seed: int, ids: Dictionary) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	for stack in range(3):
		var sx := min_x + 1 + stack * 3
		var sz := min_z + rng.randi_range(0, maxi(0, depth - 2))
		var levels := 1 + rng.randi_range(0, 2)
		var color_id: int = ids[&"rust_metal"] if rng.randf() < 0.6 else ids[&"facade_panel"]
		for dy in range(levels):
			for dz in range(2):
				_set_local(output, origin_x, origin_y, origin_z, sx, CITY_GROUND + 1 + dy, sz + dz, color_id)
		_set_local(output, origin_x, origin_y, origin_z, sx, CITY_GROUND + 1 + levels, sz, ids[&"neon_red"])
	for dx in range(0, width, 3):
		_set_local(output, origin_x, origin_y, origin_z, min_x + dx, CITY_GROUND + 3, min_z + depth - 1, ids[&"rust_metal"])


static func _stamp_lot_clutter(output: PackedByteArray, origin_x: int, origin_y: int, origin_z: int, min_x: int, min_z: int, slot: int, seed: int, ids: Dictionary) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	for index in range(4):
		var x := min_x + rng.randi_range(0, slot - 1)
		var z := min_z + rng.randi_range(0, slot - 1)
		_set_local(output, origin_x, origin_y, origin_z, x, CITY_GROUND + 1, z, ids[&"facade_dark"])
		if rng.randf() < 0.5:
			_set_local(output, origin_x, origin_y, origin_z, x, CITY_GROUND + 2, z, ids[&"graffiti"])


static func _stamp_tower(output: PackedByteArray, origin_x: int, origin_y: int, origin_z: int, min_x: int, min_z: int, width: int, depth: int, style: Dictionary, seed: int, ids: Dictionary) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var height_min: int = int(style["height_min"])
	var height: int = height_min + rng.randi_range(0, int(style["height_var"]))
	var base_y := CITY_GROUND + 1
	var top_y := mini(base_y + height - 1, WORLD_Y - 3)
	var facades: Array = style["facades"]
	var primary: int = facades[rng.randi_range(0, facades.size() - 1)]
	var secondary: int = facades[(rng.randi_range(0, facades.size() - 1) + 1) % facades.size()]
	var lit_id: int = ids[&"glass_warm"] if rng.randf() < 0.75 else ids[&"glass_cyan"]
	var dark_id: int = ids[&"glass_dark"]
	var neon_id: int = int(style["neon"])
	if neon_id < 0:
		neon_id = ids[&"neon_yellow"]
	var win_x: int = int(style["win_x"])
	var win_y: int = int(style["win_y"])
	var lit_chance: int = int(style["lit_chance"])
	var band_count: int = int(style["bands"])
	var sign_face := rng.randi_range(0, 3)
	var has_sign: bool = int(style.get("sign", 0)) > 0
	var band_one := 0
	var band_two := 0
	var setback: bool = height >= 22 and width >= 9

	for y in range(base_y, top_y + 1):
		var inset := 0
		if setback and y > base_y + int(height * 0.68):
			inset = 1
		var x0 := min_x + inset
		var x1 := min_x + width - 1 - inset
		var z0 := min_z + inset
		var z1 := min_z + depth - 1 - inset
		if x1 < x0 or z1 < z0:
			continue
		var vertical := y - base_y
		var band_a: bool = band_count > 0 and y == band_one
		var band_b: bool = band_count > 1 and y == band_two
		for x in range(x0, x1 + 1):
			for z in range(z0, z1 + 1):
				var block_id: int = primary if (vertical / 4) % 2 == 0 else secondary
				var on_face: bool = x == x0 or x == x1 or z == z0 or z == z1
				if y == top_y:
					block_id = ids[&"roof"]
				elif on_face and vertical >= 0:
					var horizontal: int = z - z0 if x == x0 or x == x1 else x - x0
					var face := 0 if z == z0 else (1 if z == z1 else (2 if x == x0 else 3))
					var mid := (depth / 2) if face <= 1 else (width / 2)
					if bool(style["garage"]) and vertical == 0 and face == 0 and horizontal >= 1 and horizontal <= 4:
						block_id = ids[&"garage_door"]
					elif bool(style["entrance"]) and vertical == 0 and face == 0 and horizontal >= mid - 1 and horizontal <= mid:
						block_id = dark_id
					elif bool(style["shop"]) and vertical == 0 and horizontal % 2 == 0:
						block_id = lit_id
					elif has_sign and face == sign_face and horizontal >= mid - 1 and horizontal <= mid and vertical >= 5 and vertical <= 11:
						block_id = ids[&"sign_panel"] if horizontal == mid - 1 else neon_id
					elif bool(style["strip"]) and face == sign_face and horizontal == 0 and vertical >= 4 and vertical <= 14 and vertical % 3 != 2:
						block_id = neon_id
					elif int(style["graffiti"]) > 0 and vertical >= 2 and vertical <= 4 and horizontal % 3 == 0:
						if int(_cell_hash(seed, x, y, z) % 100) < int(style["graffiti"]):
							block_id = ids[&"graffiti"]
					elif horizontal % win_x == 0 and vertical % win_y == 1 and vertical > 0:
						var lit := int(_cell_hash(seed, x, y, z) % 100) < lit_chance
						block_id = lit_id if lit else dark_id
				_set_local(output, origin_x, origin_y, origin_z, x, y, z, block_id)

	# Projecting balconies on residential facades.
	if bool(style["balcony"]):
		for v in range(3, height - 1, 3):
			for h in range(1, depth - 1, 3):
				_set_local(output, origin_x, origin_y, origin_z, min_x - 1, base_y + v, min_z + h, ids[&"sidewalk"])
			for h in range(1, width - 1, 3):
				_set_local(output, origin_x, origin_y, origin_z, min_x + h, base_y + v, min_z - 1, ids[&"sidewalk"])

	_stamp_roof(output, origin_x, origin_y, origin_z, min_x, min_z, width, depth, top_y, style, lit_id, ids)


static func _stamp_roof(output: PackedByteArray, origin_x: int, origin_y: int, origin_z: int, min_x: int, min_z: int, width: int, depth: int, top_y: int, style: Dictionary, lit_id: int, ids: Dictionary) -> void:
	var cx := min_x + width / 2
	var cz := min_z + depth / 2
	var kind: String = str(style["roof"])
	match kind:
		"crown":
			for dx in range(-1, 2):
				for dz in range(-1, 2):
					_set_local(output, origin_x, origin_y, origin_z, cx + dx, top_y + 1, cz + dz, ids[&"facade_panel"])
			_set_local(output, origin_x, origin_y, origin_z, cx, top_y + 2, cz, ids[&"facade_dark"])
			for dy in range(3):
				_set_local(output, origin_x, origin_y, origin_z, cx, top_y + 3 + dy, cz, ids[&"facade_dark"])
			_set_local(output, origin_x, origin_y, origin_z, cx, top_y + 6, cz, lit_id)
		"billboard":
			for dx in range(-2, 3):
				for dy in range(2):
					_set_local(output, origin_x, origin_y, origin_z, cx + dx, top_y - dy, min_z - 1, ids[&"sign_panel"])
			for dx in range(-1, 2):
				for dy in range(2):
					_set_local(output, origin_x, origin_y, origin_z, cx + dx, top_y - dy, min_z - 2, ids[&"billboard"])
		"vent":
			for dx in range(2):
				for dz in range(2):
					for dy in range(5):
						_set_local(output, origin_x, origin_y, origin_z, cx + dx, top_y + 1 + dy, cz + dz, ids[&"rust_metal"])
			_set_local(output, origin_x, origin_y, origin_z, cx, top_y + 6, cz, ids[&"neon_red"])
			_set_local(output, origin_x, origin_y, origin_z, min_x + 1, top_y + 1, min_z + 1, ids[&"facade_panel"])
			_set_local(output, origin_x, origin_y, origin_z, min_x + 2, top_y + 1, min_z + 1, ids[&"rust_metal"])
		"ac":
			for dx in range(-1, 2):
				_set_local(output, origin_x, origin_y, origin_z, cx + dx, top_y + 1, cz - 1, ids[&"facade_panel"])
			_set_local(output, origin_x, origin_y, origin_z, cx + 1, top_y + 1, cz + 2, ids[&"facade_mid"])
		_:
			for dy in range(5):
				_set_local(output, origin_x, origin_y, origin_z, cx, top_y + 1 + dy, cz, ids[&"facade_dark"])
			_set_local(output, origin_x, origin_y, origin_z, cx, top_y + 6, cz, ids[&"neon_red"])


static func _stamp_plaza_monument(output: PackedByteArray, origin_x: int, origin_y: int, origin_z: int, ids: Dictionary) -> void:
	var center := ROAD_LINE + LOT_MIN_OFFSET + 5
	for y in range(CITY_GROUND + 1, CITY_GROUND + 7):
		_set_local(output, origin_x, origin_y, origin_z, center, y, center, ids[&"facade_panel"])
	for dx in range(-1, 2):
		for dz in range(-1, 2):
			if absi(dx) == 1 and absi(dz) == 1:
				continue
			_set_local(output, origin_x, origin_y, origin_z, center + dx, CITY_GROUND + 1, center + dz, ids[&"neon_yellow"])
	_set_local(output, origin_x, origin_y, origin_z, center, CITY_GROUND + 7, center, ids[&"neon_sign"])

	# Neon gateway over the road ahead of the spawn point: a landmark visible
	# the moment the player looks down the street.
	var arch_z := ROAD_LINE + 10
	for post_x in [5, 13]:
		for y in range(CITY_GROUND + 1, CITY_GROUND + 8):
			_set_local(output, origin_x, origin_y, origin_z, post_x, y, arch_z, ids[&"facade_dark"])
		for y in range(CITY_GROUND + 3, CITY_GROUND + 7, 2):
			_set_local(output, origin_x, origin_y, origin_z, post_x, y, arch_z - 1, ids[&"neon_pink"])
	for x in range(6, 13):
		_set_local(output, origin_x, origin_y, origin_z, x, CITY_GROUND + 8, arch_z, ids[&"sign_panel"])
		if x % 2 == 0:
			_set_local(output, origin_x, origin_y, origin_z, x, CITY_GROUND + 7, arch_z, ids[&"neon_yellow"])
	_set_local(output, origin_x, origin_y, origin_z, 9, CITY_GROUND + 9, arch_z, ids[&"neon_sign"])


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


static func _is_crosswalk(x: int, z: int) -> bool:
	var x_road := _line_distance(x) <= ROAD_HALF_WIDTH
	var z_road := _line_distance(z) <= ROAD_HALF_WIDTH
	if x_road and _line_distance(z) == ROAD_HALF_WIDTH:
		return x % 2 == 0
	if z_road and _line_distance(x) == ROAD_HALF_WIDTH:
		return z % 2 == 0
	return false


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
