extends SceneTree

var main: Node
var camera: Camera3D

func _initialize() -> void:
	main = load("res://scenes/world/main.tscn").instantiate()
	root.add_child(main)
	_run.call_deferred()


func _capture(path: String, label: String) -> void:
	await process_frame
	await process_frame
	root.get_texture().get_image().save_png(path)
	var draws := Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	print("M6 CAPTURE %s -> %s (fps=%d draws=%d)" % [label, path, Engine.get_frames_per_second(), int(draws)])


func _view(from: Vector3, to: Vector3, path: String, label: String) -> void:
	camera.global_position = from
	camera.look_at(to, Vector3.UP)
	await _capture(path, label)


func _run() -> void:
	while not main.world.is_generated or not main.player.spawned:
		await process_frame
	for frame in range(360):
		await process_frame
	main.get_node("HUD/DebugReadout").visible = false
	main.player.set_physics_process(false)
	camera = main.player.get_node("Camera3D")

	# 1. Street level, downtown avenue.
	await _view(Vector3(49.5, 4.6, 49.5), Vector3(90.0, 6.0, 49.5), "res://debug/evidence/m6_street_level.png", "street level")

	# 2. Downtown skyline from a wide intersection.
	await _view(Vector3(12.0, 44.0, 12.0), Vector3(70.0, 14.0, 70.0), "res://debug/evidence/m6_downtown_skyline.png", "downtown skyline")

	# 3. Neon district street.
	await _view(Vector3(69.5, 4.6, 69.5), Vector3(69.5, 5.5, 112.0), "res://debug/evidence/m6_neon_district.png", "neon district")

	# 4. Industrial edge.
	await _view(Vector3(9.5, 4.6, 19.5), Vector3(9.5, 5.5, 60.0), "res://debug/evidence/m6_industrial.png", "industrial")

	# 5. Residential / outskirts.
	await _view(Vector3(109.5, 4.6, 89.5), Vector3(109.5, 5.5, 49.5), "res://debug/evidence/m6_outskirts.png", "outskirts")

	# 6. Actually driving a car.
	camera.position = Vector3(0.0, 1.62, 0.0)
	camera.rotation = Vector3.ZERO
	main.player.set_physics_process(true)
	var parked: Vehicle = null
	for node in main.get_tree().get_nodes_in_group("vehicles"):
		var candidate := node as Vehicle
		if candidate != null and not candidate.is_traffic and candidate.position.distance_to(Vector3(10.5, 3.05, 14.5)) < 1.0:
			parked = candidate
			break
	if parked != null:
		main.player._enter_vehicle(parked)
		for frame in range(24):
			await process_frame
		await _capture("res://debug/evidence/m6_driving.png", "driving")
		main.player._exit_vehicle()
	else:
		print("M6 WARNING parked vehicle not found for driving capture")
	quit(0)
