extends SceneTree

var main: Node
var failures := 0


func _initialize() -> void:
	main = load("res://scenes/world/main.tscn").instantiate()
	root.add_child(main)
	_run.call_deferred()


func _check(condition: bool, label: String, detail := "") -> void:
	if not condition:
		failures += 1
		push_error("CITY CHECK FAIL: %s %s" % [label, detail])
		return
	print("CITY CHECK PASS: %s %s" % [label, detail])


func _run() -> void:
	while not main.world.is_generated or not main.player.spawned:
		await process_frame
	var world: VoxelWorld = main.world
	var asphalt_id: int = world.block_ids[&"asphalt"]
	var road_line_id: int = world.block_ids[&"road_line"]
	var sidewalk_id: int = world.block_ids[&"sidewalk"]
	var concrete_id: int = world.block_ids[&"concrete"]
	var warm_window_id: int = world.block_ids[&"window_warm"]
	var cyan_window_id: int = world.block_ids[&"window_cyan"]

	_check(world.generated_chunk_count == world.CHUNK_COUNT, "city chunks all generate", "count=%d" % world.generated_chunk_count)

	# Road, dashed centre line, sidewalk and lot must be four distinct surfaces.
	_check(world.get_block_id(Vector3i(8, 2, 22)) == asphalt_id, "roadway is asphalt", "cell=%d" % world.get_block_id(Vector3i(8, 2, 22)))
	_check(world.get_block_id(Vector3i(8, 2, 20)) == road_line_id, "road has a dashed centre line", "cell=%d" % world.get_block_id(Vector3i(8, 2, 20)))
	_check(world.get_block_id(Vector3i(10, 2, 20)) == sidewalk_id, "road edge has a sidewalk", "cell=%d" % world.get_block_id(Vector3i(10, 2, 20)))
	_check(world.get_block_id(Vector3i(11, 2, 20)) == concrete_id, "lots are concrete", "cell=%d" % world.get_block_id(Vector3i(11, 2, 20)))
	_check(world.get_block_id(Vector3i(8, 3, 8)) == world.air_id, "spawn plaza has open air above the street", "cell=%d" % world.get_block_id(Vector3i(8, 3, 8)))

	# Buildings now have glowing window grids, not solid concrete cubes.
	var windows := 0
	for x in range(27, 38):
		for z in range(27, 38):
			for y in range(3, 32):
				var cell_id: int = world.get_block_id(Vector3i(x, y, z))
				if cell_id == warm_window_id or cell_id == cyan_window_id:
					windows += 1
	_check(windows > 0, "buildings have lit window grids", "windows=%d" % windows)

	var lamp_sources := 0
	var neon_sources := 0
	for source in world.static_light_sources:
		var cell: Vector3i = source["cell"]
		var block_id: int = world.get_block_id(cell)
		if world.block_defs[block_id].block_id == &"street_lamp":
			lamp_sources += 1
		if world.block_defs[block_id].block_id == &"neon_sign":
			neon_sources += 1
	_check(lamp_sources > 0, "street lamps emit static light", "sources=%d" % lamp_sources)
	_check(neon_sources > 0, "plaza neon emits static light", "sources=%d" % neon_sources)
	_check(len(world.static_light_sources) < 4000, "glow-only windows do not explode the light bake", "sources=%d" % len(world.static_light_sources))

	# Cars must spawn ON the road surface (top face y=3), never inside the slab.
	var car_wait := 0
	while main.enemy_director.traffic_cars.is_empty() and car_wait < 1800:
		await process_frame
		car_wait += 1
	var cars: Array = main.enemy_director.traffic_cars
	_check(cars.size() > 0, "traffic cars spawn", "count=%d wait=%d" % [cars.size(), car_wait])
	var cars_on_road := 0
	for node in cars:
		var car := node as TrafficCar
		if car != null and car.position.y >= 3.0:
			cars_on_road += 1
	_check(cars.size() > 0 and cars_on_road == cars.size(), "traffic cars sit on the road, not inside it", "on_road=%d/%d" % [cars_on_road, cars.size()])

	var first := WorldGenerator.generate_chunk(0, world.world_seed, world.heights, world.block_ids)
	var second := WorldGenerator.generate_chunk(0, world.world_seed, world.heights, world.block_ids)
	_check(first == second, "city stamping is deterministic", "bytes=%d" % first.size())

	if failures > 0:
		quit(1)
		return
	print("NEON CITY CHECK PASS: roads, windows, lighting, traffic and determinism verified")
	quit(0)
