extends SceneTree

var main: Node


func _initialize() -> void:
	main = load("res://scenes/world/main.tscn").instantiate()
	root.add_child(main)
	_run.call_deferred()


func _capture(path: String) -> void:
	await process_frame
	root.get_texture().get_image().save_png(path)
	print("CAPTURED %s" % path)


func _find_block(block_id: int) -> Vector3i:
	var world: VoxelWorld = main.world
	for y in range(10, 45):
		for z in range(1, 127):
			for x in range(1, 127):
				if world.get_block_id(Vector3i(x, y, z)) == block_id:
					return Vector3i(x, y, z)
	return Vector3i(-1, -1, -1)


func _run() -> void:
	while not main.world.is_generated or not main.player.spawned:
		await process_frame
	for frame in range(420):
		await process_frame
	main.get_node("HUD/DebugReadout").visible = false
	var world: VoxelWorld = main.world
	var camera: Camera3D = main.player.get_node("Camera3D")
	main.player.set_physics_process(false)

	var torch_cell := Vector3i(64, world.heights[64 + 58 * 128] + 1, 58)
	print("torch cell %s block=%d" % [torch_cell, world.get_block_id(torch_cell)])
	camera.global_position = Vector3(torch_cell) + Vector3(1.6, 0.8, 2.4)
	camera.look_at(Vector3(torch_cell) + Vector3(0.5, 0.5, 0.5), Vector3.UP)
	await _capture("res://debug/evidence/probe_torch.png")

	var crystal := Vector3i(-1, -1, -1)
	for z in range(1, 127):
		for x in range(1, 127):
			var ground: int = world.heights[x + z * 128]
			if world.get_block_id(Vector3i(x, ground, z)) == world.block_ids[&"lumen_crystal"]:
				crystal = Vector3i(x, ground, z)
				break
		if crystal.x >= 0:
			break
	print("crystal cell %s" % crystal)
	if crystal.x >= 0:
		camera.global_position = Vector3(crystal) + Vector3(3.5, 2.5, 3.5)
		camera.look_at(Vector3(crystal) + Vector3(0.5, 1.0, 0.5), Vector3.UP)
		await _capture("res://debug/evidence/probe_crystal.png")

	var caster: Lumencaster = main.get_node("Player/Lumencaster") as Lumencaster
	caster._select_cartridge(2)
	camera.global_position = Vector3(torch_cell) + Vector3(1.6, 0.8, 2.4)
	camera.look_at(Vector3(torch_cell) + Vector3(0.5, 0.5, 0.5), Vector3.UP)
	caster._fire_selected_cartridge()
	var viewmodel: LumencasterViewmodel = main.get_node("Player/Camera3D/Viewmodel") as LumencasterViewmodel
	viewmodel.flash_time = 0.5
	await _capture("res://debug/evidence/probe_flash.png")

	# Night shots: static light is the only illumination, so the baked warm/cool
	# tint is what has to carry the contrast.
	main.cycle.restore_time(700.0)
	await process_frame
	var torch_y: int = world.heights[64 + 58 * 128]
	camera.global_position = Vector3(64.5, torch_y + 2.4, 62.0)
	camera.look_at(Vector3(64.5, torch_y + 1.0, 58.5), Vector3.UP)
	await _capture("res://debug/evidence/night_torch.png")
	if crystal.x >= 0:
		camera.global_position = Vector3(crystal) + Vector3(4.0, 3.0, 4.0)
		camera.look_at(Vector3(crystal) + Vector3(0.5, 1.0, 0.5), Vector3.UP)
		await _capture("res://debug/evidence/night_crystal.png")
	quit(0)
