extends SceneTree

var main: Node


func _initialize() -> void:
	main = load("res://scenes/world/main.tscn").instantiate()
	root.add_child(main)
	_run.call_deferred()


func _run() -> void:
	while not main.world.is_generated or not main.player.spawned:
		await process_frame
	var world: VoxelWorld = main.world
	var director: EnemyDirector = main.get_node("EnemyDirector")
	var min_height := 999
	var max_height := -1
	var max_slope := 0
	for z in range(world.WORLD_Z):
		for x in range(world.WORLD_X):
			var height: int = world.heights[x + z * world.WORLD_X]
			min_height = mini(min_height, height)
			max_height = maxi(max_height, height)
			if x > 0:
				max_slope = maxi(max_slope, absi(height - world.heights[x - 1 + z * world.WORLD_X]))
			if z > 0:
				max_slope = maxi(max_slope, absi(height - world.heights[x + (z - 1) * world.WORLD_X]))
	var relief := max_height - min_height
	if relief < 3 or relief > 16 or max_slope > 4:
		push_error("TERRAIN CHECK FAIL: heights min=%d max=%d relief=%d max_slope=%d" % [min_height, max_height, relief, max_slope])
		quit(1)
		return
	print("TERRAIN CHECK PASS: heights %d..%d relief=%d max_slope=%d" % [min_height, max_height, relief, max_slope])
	var tall_tree := false
	var tall_crystal := false
	for y in range(world.WORLD_Y):
		for z in range(world.WORLD_Z):
			for x in range(world.WORLD_X):
				var block_id := world.get_block_id(Vector3i(x, y, z))
				if block_id == world.air_id:
					continue
				var surface_y: int = world.get_surface_height(x, z)
				var name: StringName = world.block_defs[block_id].block_id
				if name == &"dead_wood" and y >= surface_y + 6:
					tall_tree = true
				elif name == &"lumen_crystal" and y >= surface_y + 9:
					tall_crystal = true
	if not tall_tree or not tall_crystal:
		push_error("FEATURE CHECK FAIL: tall_tree=%s tall_crystal=%s" % [tall_tree, tall_crystal])
		quit(1)
		return
	print("FEATURE CHECK PASS: tall dead wood and tall crystal verified")
	var spawn_cell := Vector3i(64, world.get_surface_height(64, 64) + 1, 64)
	if world.get_block_id(spawn_cell) != world.air_id:
		push_error("SPAWN CHECK FAIL: spawn cell %s is not air" % spawn_cell)
		quit(1)
		return
	print("SPAWN CHECK PASS: spawn cell is clear")
	if not InputMap.has_action("toggle_flashlight"):
		push_error("FLASHLIGHT CHECK FAIL: toggle_flashlight action missing")
		quit(1)
		return
	world.set_flashlight_enabled(false)
	if world.flashlight_enabled or bool(world.world_material.get_shader_parameter("flashlight_enabled")):
		push_error("FLASHLIGHT CHECK FAIL: disable did not reach the shader")
		quit(1)
		return
	world.set_flashlight_enabled(true)
	print("FLASHLIGHT CHECK PASS: toggle action and shader flag wired")
	var cave_chunk := -1
	var cave_cell := Vector3i.ZERO
	for chunk_index in range(world.CHUNK_COUNT):
		var coords: Vector3i = world._chunk_coords(chunk_index)
		for y in range(coords.y * 16 + 1, coords.y * 16 + 15):
			for z in range(coords.z * 16 + 1, coords.z * 16 + 15):
				for x in range(coords.x * 16 + 1, coords.x * 16 + 15):
					var cell := Vector3i(x, y, z)
					if world.get_block_id(cell) != world.air_id:
						continue
					if y >= world.get_surface_height(x, z) - 1:
						continue
					if world.get_block_id(Vector3i(x, y - 1, z)) == world.air_id:
						continue
					if world.get_block_id(cell + Vector3i.UP) != world.air_id:
						continue
					cave_chunk = chunk_index
					cave_cell = cell
					break
				if cave_chunk >= 0:
					break
			if cave_chunk >= 0:
				break
		if cave_chunk >= 0:
			break
	if cave_chunk < 0:
		push_error("CAVE CHECK FAIL: no cave candidate found")
		quit(1)
		return
	main.player.position = Vector3(cave_cell) + Vector3(12.0, 0.0, 0.0)
	var found := Vector3(-1.0, -1.0, -1.0)
	for attempt in range(400):
		found = director._find_cave_spawn_position(cave_chunk)
		if found != Vector3(-1.0, -1.0, -1.0):
			break
	if found == Vector3(-1.0, -1.0, -1.0):
		push_error("CAVE CHECK FAIL: no spawn placed in chunk %d near %s" % [cave_chunk, cave_cell])
		quit(1)
		return
	var cell := Vector3i(floori(found.x), floori(found.y), floori(found.z))
	if world.get_block_id(cell) != world.air_id or world.get_block_id(Vector3i(cell.x, cell.y - 1, cell.z)) == world.air_id:
		push_error("CAVE CHECK FAIL: spawn %s is not on solid ground with air above" % cell)
		quit(1)
		return
	if cell.y >= world.get_surface_height(cell.x, cell.z):
		push_error("CAVE CHECK FAIL: spawn %s is not underground" % cell)
		quit(1)
		return
	print("CAVE CHECK PASS: chunk=%d spawn=%s distance=%.1f" % [cave_chunk, found, found.distance_to(main.player.position)])
	var fx_parent: Node3D = world
	var before := fx_parent.get_child_count()
	Vfx.burst(fx_parent, main.player.position + Vector3.UP, Color(1.0, 0.5, 0.2))
	if fx_parent.get_child_count() != before + 1:
		push_error("VFX CHECK FAIL: burst node was not added")
		quit(1)
		return
	print("VFX CHECK PASS: burst node created")
	var child_count_before := main.get_child_count()
	director.debug_spawn_gloomlings(1)
	print("GLOOMLING DEBUG: main children %d -> %d, group=%d, spawned=%s, generated=%s" % [child_count_before, main.get_child_count(), get_nodes_in_group("enemies").size(), main.player.spawned, world.is_generated])
	await process_frame
	print("GLOOMLING DEBUG after frame: main children=%d group=%d" % [main.get_child_count(), get_nodes_in_group("enemies").size()])
	if get_nodes_in_group("enemies").is_empty():
		push_error("GLOOMLING CHECK FAIL: debug spawn produced no enemy")
		quit(1)
		return
	print("GLOOMLING CHECK PASS: debug spawn produced an enemy")
	var caster: Lumencaster = main.get_node("Player/Lumencaster") as Lumencaster
	var fired_calls: Array = []
	caster.fired.connect(func(_id: StringName, _kick: float) -> void: fired_calls.append(1))
	caster._fire_selected_cartridge()
	await process_frame
	if fired_calls.is_empty():
		push_error("FIRE CHECK FAIL: cartridge did not fire with zero cost and zero light requirement")
		quit(1)
		return
	print("FIRE CHECK PASS: cartridge fired")
	quit(0)
