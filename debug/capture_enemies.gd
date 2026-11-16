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


func _hold_nearest(group_offset: int) -> Node3D:
	var enemies := get_nodes_in_group("enemies")
	if enemies.size() <= group_offset:
		return null
	var enemy: Node3D = enemies[group_offset]
	enemy.process_mode = Node.PROCESS_MODE_DISABLED
	return enemy


func _frame(enemy: Node3D, distance: float, path: String) -> void:
	var camera: Camera3D = main.player.get_node("Camera3D")
	camera.global_position = enemy.global_position + Vector3(distance, 0.9, distance)
	camera.look_at(enemy.global_position + Vector3(0, 0.35, 0), Vector3.UP)
	await _capture(path)


func _run() -> void:
	while not main.world.is_generated or not main.player.spawned:
		await process_frame
	for frame in range(420):
		await process_frame
	main.get_node("HUD/DebugReadout").visible = false
	main.cycle.restore_time(700.0)
	main.player.set_physics_process(false)

	main.enemy_director.debug_spawn_gloomlings(3)
	for frame in range(30):
		await process_frame
	var gloomling := _hold_nearest(0)
	if gloomling != null:
		await _frame(gloomling, 2.2, "res://debug/evidence/enemy_gloomling.png")
		await _frame(gloomling, 1.4, "res://debug/evidence/enemy_gloomling_close.png")

	main.enemy_director.debug_spawn_lamp_eater()
	for frame in range(30):
		await process_frame
	var eater := _hold_nearest(get_nodes_in_group("enemies").size() - 1)
	if eater != null:
		await _frame(eater, 2.6, "res://debug/evidence/enemy_lamp_eater.png")
		await _frame(eater, 1.6, "res://debug/evidence/enemy_lamp_eater_close.png")

	# Group shot with the flashlight picking them out of the dark.
	var camera: Camera3D = main.player.get_node("Camera3D")
	if gloomling != null:
		camera.global_position = gloomling.global_position + Vector3(4.5, 1.8, 4.5)
		camera.look_at(gloomling.global_position + Vector3(0, 0.3, 0), Vector3.UP)
		await _capture("res://debug/evidence/enemy_group_night.png")
	quit(0)
