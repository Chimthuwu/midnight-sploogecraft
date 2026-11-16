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
	while not main.world.is_generated:
		await process_frame
	var world: VoxelWorld = main.world
	var asphalt_id: int = world.block_ids[&"asphalt"]
	var concrete_id: int = world.block_ids[&"concrete"]
	var lamp_id: int = world.block_ids[&"street_lamp"]
	var neon_id: int = world.block_ids[&"neon_sign"]

	_check(world.generated_chunk_count == world.CHUNK_COUNT, "city chunks all generate", "count=%d" % world.generated_chunk_count)

	_check(world.get_block_id(Vector3i(8, 2, 8)) == asphalt_id, "street intersection stays asphalt", "cell=%d" % world.get_block_id(Vector3i(8, 2, 8)))
	_check(world.get_block_id(Vector3i(8, 3, 8)) == world.air_id, "spawn plaza has open air above the street", "cell=%d" % world.get_block_id(Vector3i(8, 3, 8)))

	var building_cells := 0
	for z in range(16):
		for y in range(3, 18):
			for x in range(16):
				if world.get_block_id(Vector3i(x, y, z)) == concrete_id:
					building_cells += 1
	_check(building_cells > 0, "city buildings are concrete blocks", "cells=%d" % building_cells)

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
	_check(neon_sources > 0, "neon signs emit static light", "sources=%d" % neon_sources)

	var first := WorldGenerator.generate_chunk(0, world.world_seed, world.heights, world.block_ids)
	var second := WorldGenerator.generate_chunk(0, world.world_seed, world.heights, world.block_ids)
	_check(first == second, "city stamping is deterministic", "bytes=%d" % first.size())

	if failures > 0:
		quit(1)
		return
	print("NEON CITY CHECK PASS: blockout, lighting and determinism verified")
	quit(0)
