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

# Facade face indices used by the builder helpers.
const FACE_SOUTH := 0  # z = z0, looks toward -z
const FACE_NORTH := 1  # z = z1, looks toward +z
const FACE_WEST := 2   # x = x0, looks toward -x
const FACE_EAST := 3   # x = x1, looks toward +x

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
	var ids := _block_table(block_ids)

	# --- Ground pass: roads, paint, sidewalk, road furniture. ---
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
					elif world_y == CITY_GROUND and _is_lane_dash(world_x, world_z):
						surface_id = ids[&"paint_white"]
					elif world_y == CITY_GROUND and _is_manhole(world_x, world_z):
						surface_id = ids[&"manhole"]
					elif world_y == CITY_GROUND and _is_drain(world_x, world_z):
						surface_id = ids[&"drain"]
				elif _is_sidewalk(world_x, world_z):
					surface_id = ids[&"sidewalk"]
				output[x + y * CHUNK_SIZE + z * CHUNK_SIZE * CHUNK_SIZE] = surface_id

	# --- Lot pass: landmarks and styled buildings. ---
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
			elif gx == 3 and gz == 3:
				_stamp_landmark_tower(output, origin_x, origin_y, origin_z, world_seed, ids)
			elif gx == 1 and gz == 1:
				_stamp_landmark_venue(output, origin_x, origin_y, origin_z, world_seed, ids)
			elif gx == 0 and gz == 4:
				_stamp_landmark_works(output, origin_x, origin_y, origin_z, world_seed, ids)
			else:
				_stamp_lot(output, origin_x, origin_y, origin_z, world_seed, gx, gz, ids)

	# --- Sidewalk lamps: straight runs only, not the corner posts. ---
	for z in range(CHUNK_SIZE):
		for x in range(CHUNK_SIZE):
			var world_x := origin_x + x
			var world_z := origin_z + z
			if world_x < 0 or world_x >= WORLD_X or world_z < 0 or world_z >= WORLD_Z:
				continue
			if not _is_sidewalk(world_x, world_z) or (world_x + world_z) % 12 != 0:
				continue
			if _line_distance(world_x) == SIDEWALK_DIST and _line_distance(world_z) == SIDEWALK_DIST:
				continue
			_set_local(output, origin_x, origin_y, origin_z, world_x, CITY_GROUND + 1, world_z, ids[&"lamp"])

	# --- Traffic signals on the four corners of every intersection. ---
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


static func _block_table(block_ids: Dictionary) -> Dictionary:
	return {
		&"air": int(block_ids[&"air"]),
		&"asphalt": int(block_ids[&"asphalt"]),
		&"concrete": int(block_ids[&"concrete"]),
		&"sidewalk": int(block_ids[&"sidewalk"]),
		&"road_line": int(block_ids[&"road_line"]),
		&"paint_white": int(block_ids[&"paint_white"]),
		&"manhole": int(block_ids[&"manhole"]),
		&"drain": int(block_ids[&"drain"]),
		&"lamp": int(block_ids[&"street_lamp"]),
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
		&"neon_sign": int(block_ids[&"neon_sign"]),
		&"neon_yellow": int(block_ids[&"neon_yellow"]),
		&"roof": int(block_ids[&"roof"]),
		&"rust_metal": int(block_ids[&"rust_metal"]),
		&"garage_door": int(block_ids[&"garage_door"]),
		&"sign_panel": int(block_ids[&"sign_panel"]),
		&"graffiti": int(block_ids[&"graffiti"]),
		&"billboard": int(block_ids[&"billboard"]),
		&"crosswalk": int(block_ids[&"crosswalk"]),
		&"traffic_light": int(block_ids[&"traffic_light"]),
		&"door": int(block_ids[&"door"]),
		&"awning_red": int(block_ids[&"awning_red"]),
		&"awning_teal": int(block_ids[&"awning_teal"])
	}


# ---------------------------------------------------------------------------
# Districts and building programs
# ---------------------------------------------------------------------------

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


# A building program: everything a facade builder needs. Neon ids are reserved
# for signs, marquees and beacons so colour always communicates a business.
static func _program(kind: StringName, rng: RandomNumberGenerator, ids: Dictionary) -> Dictionary:
	var program := {"kind": kind}
	match kind:
		&"deco":
			program.merge({
				"primary": ids[&"facade_panel"], "secondary": ids[&"facade_mid"], "pier": ids[&"facade_light"],
				"height": 24 + rng.randi_range(0, 14),
				"period": 3, "win_w": 1, "floor_h": 3, "win_row": 1, "lit": 62, "warm_bias": 0.7,
				"ground": &"lobby", "roof": &"crown", "tiers": true, "cornice": true, "blade": false
			}, true)
		&"office":
			program.merge({
				"primary": ids[&"facade_dark"], "secondary": ids[&"facade_mid"], "pier": ids[&"facade_dark"],
				"height": 20 + rng.randi_range(0, 14),
				"period": 2, "win_w": 1, "floor_h": 3, "win_row": 1, "lit": 66, "warm_bias": 0.5,
				"ground": &"lobby", "roof": &"office", "tiers": false, "podium": true, "cornice": false, "blade": false
			}, true)
		&"tenement":
			program.merge({
				"primary": ids[&"facade_brick"], "secondary": ids[&"facade_dark"], "pier": ids[&"facade_brick"],
				"height": 9 + rng.randi_range(0, 9),
				"period": 3, "win_w": 1, "floor_h": 3, "win_row": 1, "lit": 56, "warm_bias": 0.85,
				"ground": &"shops", "roof": &"tank", "awnings": true, "blade": true, "cornice": true
			}, true)
		&"venue":
			program.merge({
				"primary": ids[&"facade_dark"], "secondary": ids[&"facade_mid"], "pier": ids[&"facade_mid"],
				"height": 8 + rng.randi_range(0, 4),
				"period": 4, "win_w": 2, "floor_h": 4, "win_row": 2, "lit": 52, "warm_bias": 0.4,
				"ground": &"marquee", "roof": &"billboard", "blade": true, "cornice": false
			}, true)
		&"warehouse":
			program.merge({
				"primary": ids[&"facade_brick"], "secondary": ids[&"facade_panel"], "pier": ids[&"facade_brick"],
				"height": 6 + rng.randi_range(0, 6),
				"period": 4, "win_w": 1, "floor_h": 4, "win_row": 2, "lit": 25, "warm_bias": 0.8, "clerestory": true,
				"ground": &"dock", "roof": &"vents", "graffiti": 22, "blade": false
			}, true)
		&"walkup":
			program.merge({
				"primary": ids[&"facade_light"], "secondary": ids[&"facade_mid"], "pier": ids[&"facade_light"],
				"height": 7 + rng.randi_range(0, 7),
				"period": 3, "win_w": 1, "floor_h": 3, "win_row": 1, "lit": 56, "warm_bias": 0.85,
				"ground": &"stoop", "roof": &"ac", "balconies": true, "awnings": true, "blade": false
			}, true)
		_:  # outskirts sheds and fenced heaps
			program.merge({
				"primary": ids[&"rust_metal"], "secondary": ids[&"facade_dark"], "pier": ids[&"rust_metal"],
				"height": 3 + rng.randi_range(0, 3),
				"period": 4, "win_w": 1, "floor_h": 4, "win_row": 2, "lit": 15, "warm_bias": 0.9,
				"ground": &"dock", "roof": &"shed", "graffiti": 30, "blade": false
			}, true)
	return program


static func _kind_for(district: int, rng: RandomNumberGenerator) -> StringName:
	match district:
		DISTRICT_DOWNTOWN:
			return &"deco" if rng.randf() < 0.6 else &"office"
		DISTRICT_NEON:
			var roll := rng.randf()
			if roll < 0.5:
				return &"tenement"
			return &"venue" if roll < 0.75 else &"office"
		DISTRICT_INDUSTRIAL:
			return &"warehouse"
		DISTRICT_RESIDENTIAL:
			return &"walkup"
		_:
			return &"shed"


# ---------------------------------------------------------------------------
# Lot stamping
# ---------------------------------------------------------------------------

static func _stamp_lot(output: PackedByteArray, origin_x: int, origin_y: int, origin_z: int, world_seed: int, gx: int, gz: int, ids: Dictionary) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = _lot_seed(world_seed, gx, gz)
	if rng.randf() < 0.06:
		return
	var district := _district(gx, gz)
	var lot_min_x := ROAD_LINE + gx * GRID_STEP + LOT_MIN_OFFSET
	var lot_min_z := ROAD_LINE + gz * GRID_STEP + LOT_MIN_OFFSET
	var slot := LOT_MAX_OFFSET - LOT_MIN_OFFSET + 1
	var kind := _kind_for(district, rng)
	var alley: bool = district == DISTRICT_NEON and kind != &"venue" and rng.randf() < 0.5
	if alley:
		var first := rng.randi_range(4, 5)
		var gap := rng.randi_range(2, 3)
		var second := slot - first - gap
		if second >= 4:
			_stamp_building(output, origin_x, origin_y, origin_z, lot_min_x, lot_min_z, first, slot, kind, rng, _cell_hash(world_seed, gx, gz, 1), ids)
			_stamp_building(output, origin_x, origin_y, origin_z, lot_min_x + first + gap, lot_min_z, second, slot, _kind_for(district, rng), rng, _cell_hash(world_seed, gx, gz, 2), ids)
			_stamp_alley(output, origin_x, origin_y, origin_z, lot_min_x + first, lot_min_z, gap, slot, _cell_hash(world_seed, gx, gz, 3), ids)
		else:
			_stamp_building(output, origin_x, origin_y, origin_z, lot_min_x, lot_min_z, slot - 2, slot, kind, rng, world_seed + gx * 31 + gz, ids)
	elif district == DISTRICT_INDUSTRIAL:
		var depth := rng.randi_range(6, 8)
		_stamp_building(output, origin_x, origin_y, origin_z, lot_min_x, lot_min_z, slot, depth, kind, rng, world_seed + gx * 17 + gz * 29, ids)
		_stamp_container_yard(output, origin_x, origin_y, origin_z, lot_min_x, lot_min_z + depth, slot, slot - depth, world_seed + gx * 7 + gz, ids)
	elif district == DISTRICT_OUTSKIRTS:
		var width := rng.randi_range(6, slot)
		var depth_shed := rng.randi_range(5, 8)
		var offset_x := rng.randi_range(0, slot - width)
		_stamp_building(output, origin_x, origin_y, origin_z, lot_min_x + offset_x, lot_min_z, width, depth_shed, kind, rng, world_seed + gx * 13 + gz, ids)
		_stamp_scrap_yard(output, origin_x, origin_y, origin_z, lot_min_x, lot_min_z + depth_shed, slot, slot - depth_shed, world_seed + gx * 11 + gz, ids)
	else:
		var width := rng.randi_range(8, slot)
		var depth := rng.randi_range(8, slot)
		var offset_x := rng.randi_range(0, slot - width)
		var offset_z := rng.randi_range(0, slot - depth)
		_stamp_building(output, origin_x, origin_y, origin_z, lot_min_x + offset_x, lot_min_z + offset_z, width, depth, kind, rng, world_seed + gx * 17 + gz * 29, ids)


# ---------------------------------------------------------------------------
# The building kit: shell, facade articulation, ground floors, roofs
# ---------------------------------------------------------------------------

static func _fill_box(output: PackedByteArray, origin_x: int, origin_y: int, origin_z: int, x0: int, y0: int, z0: int, x1: int, y1: int, z1: int, block_id: int) -> void:
	for x in range(x0, x1 + 1):
		for z in range(z0, z1 + 1):
			for y in range(y0, y1 + 1):
				_set_local(output, origin_x, origin_y, origin_z, x, y, z, block_id)


static func _stamp_building(output: PackedByteArray, origin_x: int, origin_y: int, origin_z: int, min_x: int, min_z: int, width: int, depth: int, kind: StringName, rng: RandomNumberGenerator, seed_value: int, ids: Dictionary) -> void:
	var program := _program(kind, rng, ids)
	var height: int = int(program["height"])
	var base_y := CITY_GROUND + 1
	var top_y := mini(base_y + height - 1, WORLD_Y - 6)
	var sign_face := rng.randi_range(0, 3)
	var neon_palette: Array = [ids[&"neon_pink"], ids[&"neon_blue"], ids[&"neon_red"], ids[&"neon_green"]]
	var neon_id: int = neon_palette[rng.randi_range(0, neon_palette.size() - 1)]
	var awning_id: int = ids[&"awning_red"] if rng.randf() < 0.55 else ids[&"awning_teal"]
	program["neon"] = neon_id
	program["awning"] = awning_id
	program["sign_face"] = sign_face

	# Tier stack: deco towers step in twice; office towers rise from a podium.
	var tiers: Array = []
	if bool(program.get("tiers", false)):
		var tier_h1 := int(height * 0.6)
		var tier_h2 := int(height * 0.8)
		tiers = [
			{"inset": 0, "y0": base_y, "y1": top_y},
			{"inset": 1, "y0": base_y + tier_h1, "y1": top_y},
			{"inset": 2, "y0": base_y + tier_h2, "y1": top_y}
		]
	elif bool(program.get("podium", false)):
		tiers = [
			{"inset": 0, "y0": base_y, "y1": base_y + 2},
			{"inset": 1, "y0": base_y + 3, "y1": top_y}
		]
	else:
		tiers = [{"inset": 0, "y0": base_y, "y1": top_y}]

	for tier_index in range(tiers.size()):
		var tier: Dictionary = tiers[tier_index]
		var inset: int = int(tier["inset"])
		var x0 := min_x + inset
		var x1 := min_x + width - 1 - inset
		var z0 := min_z + inset
		var z1 := min_z + depth - 1 - inset
		if x1 < x0 or z1 < z0:
			continue
		_fill_box(output, origin_x, origin_y, origin_z, x0, int(tier["y0"]), z0, x1, int(tier["y1"]), z1, int(program["primary"]))
		for face in range(4):
			_stamp_facade(output, origin_x, origin_y, origin_z, x0, x1, z0, z1, int(tier["y0"]), int(tier["y1"]), tier_index, program, seed_value, ids)
		if bool(program.get("cornice", false)) and tier_index < tiers.size() - 1:
			_stamp_cornice(output, origin_x, origin_y, origin_z, x0, x1, z0, z1, int(tier["y1"]), int(program["secondary"]), ids)
		if tier_index == tiers.size() - 1:
			# The top of the last tier is the roof slab.
			_fill_box(output, origin_x, origin_y, origin_z, x0, top_y, z0, x1, top_y, z1, int(ids[&"roof"]))

	if bool(program.get("balconies", false)):
		_stamp_balconies(output, origin_x, origin_y, origin_z, min_x, min_z, width, depth, base_y, top_y, program, ids)
	_stamp_roof_edge(output, origin_x, origin_y, origin_z, min_x, min_z, width, depth, top_y, program, ids)
	_stamp_roof_kit(output, origin_x, origin_y, origin_z, min_x, min_z, width, depth, top_y, program, rng, ids)


# Walk-up balconies on two faces: projecting slab with a railing, so the
# silhouette breaks up instead of reading as a plain prism.
static func _stamp_balconies(output: PackedByteArray, origin_x: int, origin_y: int, origin_z: int, min_x: int, min_z: int, width: int, depth: int, base_y: int, top_y: int, program: Dictionary, ids: Dictionary) -> void:
	for v in range(3, top_y - base_y - 1, 3):
		var y := base_y + v
		for u in range(2, width - 2, 3):
			_set_local(output, origin_x, origin_y, origin_z, min_x + u, y, min_z - 1, int(program["secondary"]))
			_set_local(output, origin_x, origin_y, origin_z, min_x + u, y + 1, min_z - 1, int(program["pier"]))
		for u in range(2, depth - 2, 3):
			_set_local(output, origin_x, origin_y, origin_z, min_x - 1, y, min_z + u, int(program["secondary"]))
			_set_local(output, origin_x, origin_y, origin_z, min_x - 1, y + 1, min_z + u, int(program["pier"]))


# Articulate one facade face: piers, recessed windows with floor-coherent
# lighting, ground-floor kit, blade sign. depth 0 cells sit on the shell face;
# windows carve one block in and glaze the back of the recess.
static func _stamp_facade(output: PackedByteArray, origin_x: int, origin_y: int, origin_z: int, x0: int, x1: int, z0: int, z1: int, base_y: int, top_y: int, tier_index: int, program: Dictionary, seed_value: int, ids: Dictionary) -> void:
	var primary: int = int(program["primary"])
	var pier_id: int = int(program["pier"])
	var secondary: int = int(program["secondary"])
	var period: int = int(program["period"])
	var win_w: int = int(program["win_w"])
	var floor_h: int = int(program["floor_h"])
	var win_row: int = int(program["win_row"])
	var lit_chance: int = int(program["lit"])
	var warm_bias: float = float(program["warm_bias"])
	var ground: StringName = program["ground"]
	var height := top_y - base_y
	for face_index in range(4):
		var u_count := 0
		var depth_dx := 0
		var depth_dz := 0
		match face_index:
			FACE_SOUTH:
				u_count = x1 - x0 + 1
				depth_dx = 0
				depth_dz = 1
			FACE_NORTH:
				u_count = x1 - x0 + 1
				depth_dx = 0
				depth_dz = -1
			FACE_WEST:
				u_count = z1 - z0 + 1
				depth_dx = 1
				depth_dz = 0
			FACE_EAST:
				u_count = z1 - z0 + 1
				depth_dx = -1
				depth_dz = 0
		for u in range(u_count):
			var wx := 0
			var wz := 0
			match face_index:
				FACE_SOUTH:
					wx = x0 + u
					wz = z0
				FACE_NORTH:
					wx = x0 + u
					wz = z1
				FACE_WEST:
					wx = x0
					wz = z0 + u
				FACE_EAST:
					wx = x1
					wz = z0 + u
			var corner := u == 0 or u == u_count - 1
			var pier: bool = corner or u % period == 0
			for v in range(height + 1):
				var y := base_y + v
				if y > top_y:
					break
				var floor_index := v / floor_h
				var row := v % floor_h
				var cell_id := -1
				var carve := false
				var glass_id := -1
				if tier_index == 0 and v < floor_h:
					# Ground-floor kit on the street-facing shell only.
					var kit := _ground_floor_cell(u, u_count, v, floor_h, face_index, pier, program, seed_value, ids)
					if kit.size() > 0:
						cell_id = int(kit["id"])
						carve = bool(kit.get("carve", false))
						glass_id = int(kit["glass"]) if kit.has("glass") else -1
					elif pier:
						cell_id = pier_id
				elif tier_index == 0 and v == floor_h and (ground == &"shops" or ground == &"marquee"):
					# Sign band above the shopfront: lit letters only over open
					# businesses, dark panel over the closed ones.
					if pier:
						cell_id = pier_id
					elif _bay_lit(seed_value, u, period, face_index):
						var letter := int(_cell_hash(seed_value, u, 0, face_index) % 100)
						cell_id = int(program["neon"]) if letter < 40 else ids[&"sign_panel"]
					else:
						cell_id = ids[&"sign_panel"]
				elif cell_id < 0 and pier:
					cell_id = pier_id
				else:
					if bool(program.get("clerestory", false)) and floor_index < 2 and row != win_row:
						cell_id = secondary
					elif row == win_row and not pier and u % period >= period - win_w:
						var effective := lit_chance + float((_cell_hash(seed_value, face_index, floor_index, 71) % 100) - 50) * 0.6
						var lit := int(_cell_hash(seed_value, u, v, face_index) % 100) < effective
						if lit:
							glass_id = ids[&"glass_warm"] if rng_rand(seed_value, u, v, face_index) < warm_bias else ids[&"glass_cyan"]
						else:
							glass_id = ids[&"glass_dark"]
						carve = true
						cell_id = ids[&"air"]
					elif row == 0 or (not pier and u % period == mini(period - 1 - win_w, maxi(1, period / 2))):
						cell_id = secondary
					else:
						cell_id = primary
				if carve:
					_set_local(output, origin_x, origin_y, origin_z, wx, y, wz, ids[&"air"])
					_set_local(output, origin_x, origin_y, origin_z, wx + depth_dx, y, wz + depth_dz, glass_id)
				elif cell_id >= 0:
					_set_local(output, origin_x, origin_y, origin_z, wx, y, wz, cell_id)
		# Street-tier extras: awnings over shopfronts, blade sign, graffiti.
		if tier_index == 0:
			if bool(program.get("awnings", false)) and ground == &"shops":
				for au in range(1, u_count - 1):
					if au % period == period - win_w or (win_w > 1 and au % period == period - win_w + 1):
						var ax := 0
						var az := 0
						match face_index:
							FACE_SOUTH:
								ax = x0 + au
								az = z0 - 1
							FACE_NORTH:
								ax = x0 + au
								az = z1 + 1
							FACE_WEST:
								ax = x0 - 1
								az = z0 + au
							FACE_EAST:
								ax = x1 + 1
								az = z0 + au
						_set_local(output, origin_x, origin_y, origin_z, ax, base_y + floor_h - 1, az, int(program["awning"]))
			if bool(program.get("blade", false)) and face_index == int(program.get("sign_face", -1)) and u_count >= 7:
				var bu := 2 + int(_cell_hash(seed_value, face_index, 5, 9) % maxi(1, u_count - 5))
				var bx := 0
				var bz := 0
				match face_index:
					FACE_SOUTH:
						bx = x0 + bu
						bz = z0 - 1
					FACE_NORTH:
						bx = x0 + bu
						bz = z1 + 1
					FACE_WEST:
						bx = x0 - 1
						bz = z0 + bu
					FACE_EAST:
						bx = x1 + 1
						bz = z0 + bu
				for bv in range(floor_h, mini(height - 1, floor_h + 7)):
					var sign_id: int = int(program["neon"]) if bv % 2 == 0 else ids[&"sign_panel"]
					_set_local(output, origin_x, origin_y, origin_z, bx, base_y + bv, bz, sign_id)
			if int(program.get("graffiti", 0)) > 0 and face_index == int(program.get("sign_face", -1)):
				for gu in range(1, u_count - 1):
					if int(_cell_hash(seed_value, gu, 3, face_index) % 100) < int(program["graffiti"]):
						var gx2 := 0
						var gz2 := 0
						match face_index:
							FACE_SOUTH:
								gx2 = x0 + gu
								gz2 = z0
							FACE_NORTH:
								gx2 = x0 + gu
								gz2 = z1
							FACE_WEST:
								gx2 = x0
								gz2 = z0 + gu
							FACE_EAST:
								gx2 = x1
								gz2 = z0 + gu
						_set_local(output, origin_x, origin_y, origin_z, gx2, base_y + 2, gz2, ids[&"graffiti"])


# Ground-floor kit: one cell of the street level. Returns {} to fall through to
# the pier logic. Storefronts light per bay so some shops read closed.
static func _bay_lit(seed_value: int, u: int, period: int, face_index: int) -> bool:
	return int(_cell_hash(seed_value, u / period, 77, face_index) % 100) < 65


static func _ground_floor_cell(u: int, u_count: int, v: int, floor_h: int, face_index: int, pier: bool, program: Dictionary, seed_value: int, ids: Dictionary) -> Dictionary:
	var ground: StringName = program["ground"]
	var period: int = int(program["period"])
	var mid := u_count / 2
	match ground:
		&"shops":
			if pier:
				return {}
			if v == 0:
				return {"id": ids[&"facade_dark"]}  # plinth under the display window
			if u == mid or u == mid - 1:
				return {"id": ids[&"door"]} if v <= 1 else {"id": ids[&"glass_dark"]}
			var lit := _bay_lit(seed_value, u, period, face_index)
			return {"id": ids[&"glass_warm"] if lit else ids[&"glass_dark"]}
		&"lobby":
			if pier:
				return {}
			if u == mid or u == mid - 1:
				return {"id": ids[&"door"]} if v == 0 else ({"id": ids[&"glass_warm"]} if v == floor_h - 1 else {"id": ids[&"facade_dark"]})
			if v == floor_h - 1:
				return {"id": ids[&"glass_warm"]}
			return {"id": ids[&"facade_dark"]}
		&"dock":
			if pier:
				return {}
			var door_left := u_count / 4
			if u >= door_left and u < door_left + 3 and v <= 1:
				return {"id": ids[&"garage_door"]}
			if v == floor_h - 1:
				return {"id": ids[&"sign_panel"]}
			return {"id": int(program["primary"])}
		&"marquee":
			if pier:
				return {}
			if v == 0:
				return {"id": ids[&"door"]} if (u == mid or u == mid - 1) else {"id": ids[&"facade_dark"]}
			if u == mid or u == mid - 1:
				return {"id": ids[&"glass_warm"]}
			if v == 1:
				return {"id": ids[&"glass_warm"]}
			return {"id": ids[&"sign_panel"]}
		&"stoop":
			if u == mid and v <= 1:
				return {"id": ids[&"door"]}
			return {}
	return {}


static func _stamp_cornice(output: PackedByteArray, origin_x: int, origin_y: int, origin_z: int, x0: int, x1: int, z0: int, z1: int, y: int, material: int, ids: Dictionary) -> void:
	for x in range(x0 - 1, x1 + 2):
		_set_local(output, origin_x, origin_y, origin_z, x, y, z0 - 1, material)
		_set_local(output, origin_x, origin_y, origin_z, x, y, z1 + 1, material)
	for z in range(z0, z1 + 1):
		_set_local(output, origin_x, origin_y, origin_z, x0 - 1, y, z, material)
		_set_local(output, origin_x, origin_y, origin_z, x1 + 1, y, z, material)


static func _stamp_roof_edge(output: PackedByteArray, origin_x: int, origin_y: int, origin_z: int, min_x: int, min_z: int, width: int, depth: int, top_y: int, program: Dictionary, ids: Dictionary) -> void:
	# Parapet ring one above the roof slab, broken by gaps so it reads as a wall walk.
	var parapet: int = int(program["pier"])
	for x in range(min_x, min_x + width):
		if x % 3 != 1:
			_set_local(output, origin_x, origin_y, origin_z, x, top_y + 1, min_z, parapet)
			_set_local(output, origin_x, origin_y, origin_z, x, top_y + 1, min_z + depth - 1, parapet)
	for z in range(min_z, min_z + depth):
		if z % 3 != 1:
			_set_local(output, origin_x, origin_y, origin_z, min_x, top_y + 1, z, parapet)
			_set_local(output, origin_x, origin_y, origin_z, min_x + width - 1, top_y + 1, z, parapet)


static func _stamp_roof_kit(output: PackedByteArray, origin_x: int, origin_y: int, origin_z: int, min_x: int, min_z: int, width: int, depth: int, top_y: int, program: Dictionary, rng: RandomNumberGenerator, ids: Dictionary) -> void:
	var cx := min_x + width / 2
	var cz := min_z + depth / 2
	match String(program["roof"]):
		"crown":
			for dx in range(-1, 2):
				for dz in range(-1, 2):
					_set_local(output, origin_x, origin_y, origin_z, cx + dx, top_y + 1, cz + dz, int(program["secondary"]))
			for dx in range(-2, 3):
				_set_local(output, origin_x, origin_y, origin_z, cx + dx, top_y + 2, cz + (2 if dx % 2 == 0 else -2), int(program["primary"]))
			for dy in range(4):
				_set_local(output, origin_x, origin_y, origin_z, cx, top_y + 2 + dy, cz, ids[&"facade_dark"])
			_set_local(output, origin_x, origin_y, origin_z, cx, top_y + 6, cz, ids[&"glass_warm"])
		"office":
			_stamp_bulkhead(output, origin_x, origin_y, origin_z, cx, cz, top_y, ids)
			_set_local(output, origin_x, origin_y, origin_z, cx - 2, top_y + 1, cz + 2, ids[&"concrete"])
			_set_local(output, origin_x, origin_y, origin_z, cx + 2, top_y + 1, cz - 2, ids[&"facade_mid"])
			if rng.randf() < 0.4:
				_stamp_mast(output, origin_x, origin_y, origin_z, min_x + 1, min_z + 1, top_y, 4, ids)
		"tank":
			if rng.randf() < 0.6:
				_stamp_water_tank(output, origin_x, origin_y, origin_z, cx, cz, top_y, ids)
			else:
				_stamp_roof_billboard(output, origin_x, origin_y, origin_z, min_x, min_z, width, depth, top_y, int(program["neon"]), ids)
			_stamp_bulkhead(output, origin_x, origin_y, origin_z, cx - 2, cz, top_y, ids)
		"billboard":
			_stamp_roof_billboard(output, origin_x, origin_y, origin_z, min_x, min_z, width, depth, top_y, int(program["neon"]), ids)
			_set_local(output, origin_x, origin_y, origin_z, cx, top_y + 1, cz, ids[&"facade_mid"])
			_set_local(output, origin_x, origin_y, origin_z, cx, top_y + 2, cz, ids[&"facade_dark"])
		"vents":
			for index in range(3):
				var vx := cx - 2 + index * 2
				for dy in range(3):
					_set_local(output, origin_x, origin_y, origin_z, vx, top_y + 1 + dy, cz, ids[&"rust_metal"])
				_set_local(output, origin_x, origin_y, origin_z, vx, top_y + 4, cz, ids[&"concrete"])
			if rng.randf() < 0.35:
				_stamp_water_tank(output, origin_x, origin_y, origin_z, cx + 2, cz + 2, top_y, ids)
		"ac":
			_set_local(output, origin_x, origin_y, origin_z, cx - 1, top_y + 1, cz - 1, ids[&"concrete"])
			_set_local(output, origin_x, origin_y, origin_z, cx + 1, top_y + 1, cz + 1, ids[&"facade_mid"])
			if rng.randf() < 0.4:
				_stamp_water_tank(output, origin_x, origin_y, origin_z, cx, cz - 2, top_y, ids)
			if rng.randf() < 0.3:
				_stamp_mast(output, origin_x, origin_y, origin_z, min_x + 1, min_z + 1, top_y, 3, ids)
		"shed":
			_set_local(output, origin_x, origin_y, origin_z, cx, top_y + 1, cz, ids[&"rust_metal"])


static func _stamp_bulkhead(output: PackedByteArray, origin_x: int, origin_y: int, origin_z: int, cx: int, cz: int, top_y: int, ids: Dictionary) -> void:
	for dx in range(2):
		for dz in range(2):
			_set_local(output, origin_x, origin_y, origin_z, cx + dx, top_y + 1, cz + dz, ids[&"facade_dark"])
	_set_local(output, origin_x, origin_y, origin_z, cx, top_y + 2, cz, ids[&"door"])


static func _stamp_water_tank(output: PackedByteArray, origin_x: int, origin_y: int, origin_z: int, cx: int, cz: int, top_y: int, ids: Dictionary) -> void:
	for dx in range(2):
		for dz in range(2):
			_set_local(output, origin_x, origin_y, origin_z, cx + dx, top_y + 1, cz + dz, ids[&"rust_metal"])
	for dy in range(2):
		for dx in range(2):
			for dz in range(2):
				_set_local(output, origin_x, origin_y, origin_z, cx + dx, top_y + 2 + dy, cz + dz, ids[&"rust_metal"])
	for dx in range(2):
		for dz in range(2):
			_set_local(output, origin_x, origin_y, origin_z, cx + dx, top_y + 4, cz + dz, ids[&"facade_dark"])


static func _stamp_roof_billboard(output: PackedByteArray, origin_x: int, origin_y: int, origin_z: int, min_x: int, min_z: int, width: int, depth: int, top_y: int, neon_id: int, ids: Dictionary) -> void:
	var cx := min_x + width / 2
	for dx in range(-2, 3):
		_set_local(output, origin_x, origin_y, origin_z, cx + dx, top_y + 2, min_z + depth - 1, ids[&"sign_panel"])
	for dx in range(-2, 3):
		if dx % 2 == 0:
			_set_local(output, origin_x, origin_y, origin_z, cx + dx, top_y + 3, min_z + depth - 1, neon_id)
		else:
			_set_local(output, origin_x, origin_y, origin_z, cx + dx, top_y + 3, min_z + depth - 1, ids[&"billboard"])
	for dx in range(-2, 3):
		_set_local(output, origin_x, origin_y, origin_z, cx + dx, top_y + 4, min_z + depth - 1, ids[&"billboard"])
	_set_local(output, origin_x, origin_y, origin_z, cx - 2, top_y + 1, min_z + depth - 1, ids[&"facade_dark"])
	_set_local(output, origin_x, origin_y, origin_z, cx + 2, top_y + 1, min_z + depth - 1, ids[&"facade_dark"])


static func _stamp_mast(output: PackedByteArray, origin_x: int, origin_y: int, origin_z: int, mx: int, mz: int, top_y: int, pole_height: int, ids: Dictionary) -> void:
	for dy in range(pole_height):
		_set_local(output, origin_x, origin_y, origin_z, mx, top_y + 1 + dy, mz, ids[&"facade_dark"])
		if dy >= 2 and dy % 2 == 0:
			_set_local(output, origin_x, origin_y, origin_z, mx - 1, top_y + 1 + dy, mz, ids[&"facade_dark"])
			_set_local(output, origin_x, origin_y, origin_z, mx + 1, top_y + 1 + dy, mz, ids[&"facade_dark"])
	_set_local(output, origin_x, origin_y, origin_z, mx, top_y + 1 + pole_height, mz, ids[&"neon_red"])


static func _stamp_alley(output: PackedByteArray, origin_x: int, origin_y: int, origin_z: int, min_x: int, min_z: int, gap: int, depth: int, seed_value: int, ids: Dictionary) -> void:
	# A working alley: dumpster, spill of trash bags, a fire door in each wall.
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for dz in range(2, depth - 2, 3):
		if rng.randf() < 0.6:
			_set_local(output, origin_x, origin_y, origin_z, min_x + rng.randi_range(0, gap - 1), CITY_GROUND + 1, min_z + dz, ids[&"rust_metal"])
			if rng.randf() < 0.4:
				_set_local(output, origin_x, origin_y, origin_z, min_x + rng.randi_range(0, gap - 1), CITY_GROUND + 1, min_z + dz + 1, ids[&"graffiti"])


static func _stamp_container_yard(output: PackedByteArray, origin_x: int, origin_y: int, origin_z: int, min_x: int, min_z: int, width: int, depth: int, seed_value: int, ids: Dictionary) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for stack in range(3):
		var sx := min_x + 1 + stack * 3
		if sx >= min_x + width - 1:
			break
		var sz := min_z + rng.randi_range(0, maxi(0, depth - 3))
		var levels := 1 + rng.randi_range(0, 2)
		var color_id: int = ids[&"rust_metal"] if rng.randf() < 0.6 else ids[&"facade_panel"]
		for dy in range(levels):
			for dz in range(2):
				for dx in range(2):
					_set_local(output, origin_x, origin_y, origin_z, sx + dx, CITY_GROUND + 1 + dy, sz + dz, color_id)
		if rng.randf() < 0.4:
			_set_local(output, origin_x, origin_y, origin_z, sx, CITY_GROUND + 1 + levels, sz, ids[&"graffiti"])
	for dx in range(0, width, 3):
		_set_local(output, origin_x, origin_y, origin_z, min_x + dx, CITY_GROUND + 1, min_z + depth / 2, ids[&"drain"])


static func _stamp_scrap_yard(output: PackedByteArray, origin_x: int, origin_y: int, origin_z: int, min_x: int, min_z: int, width: int, depth: int, seed_value: int, ids: Dictionary) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for heap in range(4):
		var hx := min_x + rng.randi_range(0, maxi(0, width - 2))
		var hz := min_z + rng.randi_range(0, maxi(0, depth - 2))
		var heap_id: int = ids[&"rust_metal"] if rng.randf() < 0.7 else ids[&"concrete"]
		for dx in range(2):
			_set_local(output, origin_x, origin_y, origin_z, hx + dx, CITY_GROUND + 1, hz, heap_id)
			if rng.randf() < 0.4:
				_set_local(output, origin_x, origin_y, origin_z, hx + dx, CITY_GROUND + 2, hz, heap_id)


# ---------------------------------------------------------------------------
# Handcrafted landmarks
# ---------------------------------------------------------------------------

# Spioogecraft Tower: a stepped deco tower at the end of the spawn avenue,
# visible from the plaza intersection down the whole street canyon.
static func _stamp_landmark_tower(output: PackedByteArray, origin_x: int, origin_y: int, origin_z: int, world_seed: int, ids: Dictionary) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = _lot_seed(world_seed, 3, 3)
	var min_x := ROAD_LINE + 3 * GRID_STEP + LOT_MIN_OFFSET
	var min_z := ROAD_LINE + 3 * GRID_STEP + LOT_MIN_OFFSET
	var program := _program(&"deco", rng, ids)
	program["height"] = 34
	program["neon"] = ids[&"neon_yellow"]
	var width := 11
	var depth := 11
	var base_y := CITY_GROUND + 1
	program["ground"] = &"lobby"
	var tiers := [
		{"inset": 0, "y0": base_y, "y1": base_y + 17},
		{"inset": 1, "y0": base_y + 18, "y1": base_y + 26},
		{"inset": 3, "y0": base_y + 27, "y1": base_y + 31}
	]
	for tier_index in range(tiers.size()):
		var tier: Dictionary = tiers[tier_index]
		var inset: int = int(tier["inset"])
		var x0 := min_x + inset
		var x1 := min_x + width - 1 - inset
		var z0 := min_z + inset
		var z1 := min_z + depth - 1 - inset
		_fill_box(output, origin_x, origin_y, origin_z, x0, int(tier["y0"]), z0, x1, int(tier["y1"]), z1, int(program["primary"]))
		for face in range(4):
			_stamp_facade(output, origin_x, origin_y, origin_z, x0, x1, z0, z1, int(tier["y0"]), int(tier["y1"]), tier_index, program, world_seed * 3 + tier_index, ids)
		_stamp_cornice(output, origin_x, origin_y, origin_z, x0, x1, z0, z1, int(tier["y1"]), int(program["secondary"]), ids)
	# Lit crown fins and a beacon spire.
	var crown_y := base_y + 32
	var cx := min_x + width / 2
	var cz := min_z + depth / 2
	for dx in range(-2, 3):
		for dz in range(-2, 3):
			if absi(dx) + absi(dz) <= 2:
				_set_local(output, origin_x, origin_y, origin_z, cx + dx, crown_y, cz + dz, int(program["secondary"]))
	for corner in [Vector2i(-2, -2), Vector2i(2, -2), Vector2i(-2, 2), Vector2i(2, 2)]:
		for dy in range(3):
			_set_local(output, origin_x, origin_y, origin_z, cx + corner.x, crown_y + 1 + dy, cz + corner.y, int(program["pier"]))
		_set_local(output, origin_x, origin_y, origin_z, cx + corner.x, crown_y + 4, cz + corner.y, ids[&"glass_warm"])
	for dy in range(6):
		_set_local(output, origin_x, origin_y, origin_z, cx, crown_y + 1 + dy, cz, ids[&"facade_dark"])
	_set_local(output, origin_x, origin_y, origin_z, cx, crown_y + 7, cz, ids[&"neon_yellow"])


# Orbit Hall: an entertainment landmark in the neon district — podium, glowing
# dome, marquee entrance and a vertical blade sign.
static func _stamp_landmark_venue(output: PackedByteArray, origin_x: int, origin_y: int, origin_z: int, world_seed: int, ids: Dictionary) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = _lot_seed(world_seed, 1, 1)
	var min_x := ROAD_LINE + 1 * GRID_STEP + LOT_MIN_OFFSET
	var min_z := ROAD_LINE + 1 * GRID_STEP + LOT_MIN_OFFSET
	var width := 11
	var depth := 11
	var base_y := CITY_GROUND + 1
	var podium_top := base_y + 4
	var program := _program(&"venue", rng, ids)
	program["height"] = 5
	program["neon"] = ids[&"neon_pink"]
	program["blade"] = false  # Signage is hand-stamped below; skip the generic blade.
	_fill_box(output, origin_x, origin_y, origin_z, min_x, base_y, min_z, min_x + width - 1, podium_top, min_z + depth - 1, int(program["primary"]))
	for face in range(4):
		_stamp_facade(output, origin_x, origin_y, origin_z, min_x, min_x + width - 1, min_z, min_z + depth - 1, base_y, podium_top, 0, program, world_seed, ids)
	# Voxel dome: rings shrinking to a cap, pale shell with cyan skylights so
	# the silhouette survives the night sky.
	var cx := min_x + width / 2
	var cz := min_z + depth / 2
	for dy in range(6):
		var radius := sqrt(maxf(0.0, 25.0 - float(dy * dy) * 1.35))
		var inner := radius - 1.6
		for dx in range(-5, 6):
			for dz in range(-5, 6):
				var dist := sqrt(float(dx * dx + dz * dz))
				if dist <= radius and dist > inner:
					var dome_id: int = ids[&"facade_light"]
					if dy == 0:
						dome_id = ids[&"neon_blue"] if (dx + dz) % 2 == 0 else ids[&"facade_light"]
					elif dy >= 2 and (dx * 7 + dz * 13) % 3 == 0:
						dome_id = ids[&"glass_cyan"]
					_set_local(output, origin_x, origin_y, origin_z, cx + dx, podium_top + 1 + dy, cz + dz, dome_id)
	# Marquee canopy over the north entrance and a tall blade sign.
	for dx in range(-2, 3):
		_set_local(output, origin_x, origin_y, origin_z, cx + dx, base_y + 3, min_z - 1, ids[&"neon_pink"])
		_set_local(output, origin_x, origin_y, origin_z, cx + dx, base_y + 4, min_z - 1, ids[&"sign_panel"])
	var blade_x := min_x + 1
	for bv in range(10):
		_set_local(output, origin_x, origin_y, origin_z, blade_x, base_y + bv, min_z - 1, ids[&"neon_pink"] if bv % 2 == 0 else ids[&"sign_panel"])


# Gasworks: an industrial landmark — smokestacks, a gasometer tank and a
# graffiti-tagged machine hall on the industrial edge.
static func _stamp_landmark_works(output: PackedByteArray, origin_x: int, origin_y: int, origin_z: int, world_seed: int, ids: Dictionary) -> void:
	var min_x := ROAD_LINE + LOT_MIN_OFFSET
	var min_z := ROAD_LINE + 4 * GRID_STEP + LOT_MIN_OFFSET
	var base_y := CITY_GROUND + 1
	# Machine hall with clerestory band.
	var hall_depth := 7
	for x in range(min_x, min_x + 11):
		for z in range(min_z, min_z + hall_depth):
			var wall := x == min_x or x == min_x + 10 or z == min_z or z == min_z + hall_depth - 1
			for y in range(base_y, base_y + 8):
				var id: int = int(ids[&"facade_brick"])
				if wall and y == base_y + 6 and x % 2 == 0:
					id = int(ids[&"glass_warm"])
				elif not wall and y == base_y + 7:
					id = int(ids[&"roof"])
				_set_local(output, origin_x, origin_y, origin_z, x, y, z, id)
	for index in range(4):
		var gx := min_x + 1 + index * 3
		if int(_cell_hash(world_seed, gx, 1, 1) % 100) < 50:
			_set_local(output, origin_x, origin_y, origin_z, gx, base_y + 2, min_z + hall_depth - 1, ids[&"garage_door"])
	# Two smokestacks with dark bands and red beacons.
	for stack_x in [min_x + 2, min_x + 7]:
		for y in range(base_y, base_y + 15):
			for dx in range(2):
				for dz in range(2):
					var stack_id: int = int(ids[&"rust_metal"])
					if y >= base_y + 13:
						stack_id = int(ids[&"facade_dark"])
					_set_local(output, origin_x, origin_y, origin_z, stack_x + dx, y, min_z + hall_depth + 1 + dz, stack_id)
		_set_local(output, origin_x, origin_y, origin_z, stack_x, base_y + 15, min_z + hall_depth + 1, ids[&"neon_red"])
	# Gasometer: rust ring with a raised piston cross.
	var gx0 := min_x + 2
	var gz0 := min_z + hall_depth + 5
	for dx in range(-3, 4):
		for dz in range(-3, 4):
			var dist := sqrt(float(dx * dx + dz * dz))
			if dist <= 3.4 and dist > 2.2:
				for y in range(base_y, base_y + 5):
					_set_local(output, origin_x, origin_y, origin_z, gx0 + dx, y, gz0 + dz, ids[&"rust_metal"])
				_set_local(output, origin_x, origin_y, origin_z, gx0 + dx, base_y + 5, gz0 + dz, ids[&"concrete"])


static func _stamp_plaza_monument(output: PackedByteArray, origin_x: int, origin_y: int, origin_z: int, ids: Dictionary) -> void:
	var center := ROAD_LINE + LOT_MIN_OFFSET + 5
	# Stepped plinth, tapered obelisk, lit cap, four bollard lights.
	for dy in range(2):
		for dx in range(-1, 2):
			for dz in range(-1, 2):
				_set_local(output, origin_x, origin_y, origin_z, center + dx, CITY_GROUND + 1 + dy, center + dz, ids[&"concrete"])
	for dy in range(6):
		_set_local(output, origin_x, origin_y, origin_z, center, CITY_GROUND + 3 + dy, center, ids[&"facade_light"])
	_set_local(output, origin_x, origin_y, origin_z, center, CITY_GROUND + 9, center, ids[&"neon_sign"])
	for bollard in [Vector2i(-3, -3), Vector2i(3, -3), Vector2i(-3, 3), Vector2i(3, 3)]:
		_set_local(output, origin_x, origin_y, origin_z, center + bollard.x, CITY_GROUND + 1, center + bollard.y, ids[&"neon_yellow"])

	# Neon gateway over the road ahead of the spawn point: solid pylons with
	# continuous lit edges and a framed sign board — no floating cubes.
	var arch_z := ROAD_LINE + 10
	for post_x in [5, 13]:
		for y in range(CITY_GROUND + 1, CITY_GROUND + 10):
			_set_local(output, origin_x, origin_y, origin_z, post_x, y, arch_z, ids[&"facade_dark"])
		# Short neon accent under the lantern; a full-height strip overwhelms.
		var strip_x: int = post_x + (1 if post_x == 5 else -1)
		for y in range(CITY_GROUND + 7, CITY_GROUND + 10):
			_set_local(output, origin_x, origin_y, origin_z, strip_x, y, arch_z, ids[&"neon_pink"])
		_set_local(output, origin_x, origin_y, origin_z, post_x, CITY_GROUND + 10, arch_z, ids[&"glass_warm"])
	for x in range(5, 14):
		_set_local(output, origin_x, origin_y, origin_z, x, CITY_GROUND + 10, arch_z, ids[&"sign_panel"])
		if x % 2 == 0:
			_set_local(output, origin_x, origin_y, origin_z, x, CITY_GROUND + 9, arch_z, ids[&"neon_yellow"])
	_set_local(output, origin_x, origin_y, origin_z, 9, CITY_GROUND + 11, arch_z, ids[&"neon_sign"])


# ---------------------------------------------------------------------------
# Street predicates
# ---------------------------------------------------------------------------

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


static func rng_rand(seed_value: int, x: int, y: int, z: int) -> float:
	return float(_cell_hash(seed_value, x, y, z) % 1000) / 1000.0


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
	# Yellow centre line, dashed, never painted inside intersections.
	if _line_distance(x) == 0 and _line_distance(z) > ROAD_HALF_WIDTH:
		return fposmod(float(z - ROAD_LINE), 4.0) < 2.0
	if _line_distance(z) == 0 and _line_distance(x) > ROAD_HALF_WIDTH:
		return fposmod(float(x - ROAD_LINE), 4.0) < 2.0
	return false


static func _is_lane_dash(x: int, z: int) -> bool:
	if _line_distance(x) == 2 and _line_distance(z) > ROAD_HALF_WIDTH:
		return fposmod(float(z - ROAD_LINE), 4.0) < 2.0
	if _line_distance(z) == 2 and _line_distance(x) > ROAD_HALF_WIDTH:
		return fposmod(float(x - ROAD_LINE), 4.0) < 2.0
	return false


static func _is_manhole(x: int, z: int) -> bool:
	if _is_crosswalk(x, z) or _is_lane_marking(x, z) or _is_lane_dash(x, z):
		return false
	return int(_cell_hash(x, 17, z, 5) % 100) < 2


static func _is_drain(x: int, z: int) -> bool:
	var gutter := (_line_distance(x) == ROAD_HALF_WIDTH and _line_distance(z) > ROAD_HALF_WIDTH) \
		or (_line_distance(z) == ROAD_HALF_WIDTH and _line_distance(x) > ROAD_HALF_WIDTH)
	if not gutter or _is_crosswalk(x, z):
		return false
	return int(_cell_hash(x, 23, z, 7) % 100) < 6


static func _set_local(output: PackedByteArray, origin_x: int, origin_y: int, origin_z: int, x: int, y: int, z: int, block_id: int) -> void:
	if x < origin_x or x >= origin_x + CHUNK_SIZE or y < origin_y or y >= origin_y + CHUNK_SIZE or z < origin_z or z >= origin_z + CHUNK_SIZE:
		return
	output[(x - origin_x) + (y - origin_y) * CHUNK_SIZE + (z - origin_z) * CHUNK_SIZE * CHUNK_SIZE] = block_id
