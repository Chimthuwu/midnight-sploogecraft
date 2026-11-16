extends SceneTree

var main: Node


func _initialize() -> void:
	main = load("res://scenes/world/main.tscn").instantiate()
	root.add_child(main)
	_run.call_deferred()


func _capture(path: String) -> void:
	await process_frame
	await process_frame
	root.get_texture().get_image().save_png(path)
	print("CAPTURED %s" % path)


func _find_block(block_id: int, max_distance: int) -> Vector3i:
	var world: VoxelWorld = main.world
	var center := Vector3i(64, 0, 64)
	for radius in range(1, max_distance):
		for z in range(-radius, radius + 1):
			for x in range(-radius, radius + 1):
				if absi(x) != radius and absi(z) != radius:
					continue
				var cell := Vector3i(center.x + x, 0, center.z + z)
				cell.y = world.heights[cell.x + cell.z * 128]
				if world.get_block_id(cell) == block_id:
					return cell
	return Vector3i(-1, -1, -1)


func _look_at_block(block_id: int, path: String) -> void:
	var cell := _find_block(block_id, 20)
	if cell.x < 0:
		print("NOT FOUND %d" % block_id)
		return
	var camera: Camera3D = main.player.get_node("Camera3D")
	main.player.set_physics_process(false)
	camera.global_position = Vector3(cell) + Vector3(2.2, 1.5, 2.2)
	camera.look_at(Vector3(cell) + Vector3(0.5, 0.3, 0.5), Vector3.UP)
	await _capture(path)


func _run() -> void:
	while not main.world.is_generated or not main.player.spawned:
		await process_frame
	for frame in range(420):
		await process_frame
	main.get_node("HUD/DebugReadout").visible = false
	var world: VoxelWorld = main.world
	await _look_at_block(world.block_ids[&"pale_bloom"], "res://debug/evidence/probe_bloom.png")
	await _look_at_block(world.block_ids[&"torch"], "res://debug/evidence/probe_torch.png")

	# A dug pit reproduces the exposed-stone look from the report.
	var camera: Camera3D = main.player.get_node("Camera3D")
	var pit := Vector3i(56, 0, 56)
	pit.y = world.heights[pit.x + pit.z * 128]
	for depth in range(4):
		for dz in range(3):
			for dx in range(3):
				world.set_block(Vector3i(pit.x + dx, pit.y - depth, pit.z + dz), world.air_id)
	camera.global_position = Vector3(pit) + Vector3(1.5, 2.6, 6.0)
	camera.look_at(Vector3(pit) + Vector3(1.5, -1.0, 1.5), Vector3.UP)
	await _capture("res://debug/evidence/probe_pit.png")
	quit(0)
