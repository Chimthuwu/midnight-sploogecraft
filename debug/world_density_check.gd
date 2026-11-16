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
		push_error("DENSITY CHECK FAIL: %s %s" % [label, detail])
		return
	print("DENSITY PASS: %s %s" % [label, detail])


func _run() -> void:
	while not main.world.is_generated:
		await process_frame
	var world: VoxelWorld = main.world
	var heights: PackedInt32Array = world.heights
	var stone_id: int = world.block_ids[&"stone"]
	var wood_id: int = world.block_ids[&"dead_wood"]
	var bloom_id: int = world.block_ids[&"pale_bloom"]
	var mycelium_id: int = world.block_ids[&"mycelium"]

	var stone_props := 0
	var shrubs := 0
	var log_cells := 0
	for z in range(1, WorldGenerator.WORLD_Z - 1):
		for x in range(1, WorldGenerator.WORLD_X - 1):
			var top: int = heights[x + z * WorldGenerator.WORLD_X] + 1
			var block_id: int = world.get_block_id(Vector3i(x, top, z))
			if block_id == stone_id:
				stone_props += 1
			elif block_id == bloom_id or block_id == mycelium_id:
				shrubs += 1
			elif block_id == wood_id:
				var sideways := world.get_block_id(Vector3i(x + 1, top, z)) == wood_id or world.get_block_id(Vector3i(x, top, z + 1)) == wood_id
				if sideways:
					log_cells += 1

	_check(stone_props >= 40, "boulder and ruin stone sits above the ash", "cells=%d" % stone_props)
	_check(log_cells >= 12, "fallen logs lie horizontally on the ground", "cells=%d" % log_cells)
	_check(shrubs >= 40, "ground-cover clumps are scattered", "cells=%d" % shrubs)

	# Props are stamped from a seeded grid, so a chunk must rebuild byte-identically.
	var block_ids: Dictionary = world.block_ids
	var first := WorldGenerator.generate_chunk(0, 139732, heights, block_ids)
	var second := WorldGenerator.generate_chunk(0, 139732, heights, block_ids)
	_check(first == second, "prop stamping is deterministic", "bytes=%d" % first.size())

	if failures > 0:
		quit(1)
		return
	print("WORLD DENSITY CHECK PASS: boulders, fallen logs, ruins and clumps are present and deterministic")
	quit(0)
