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
	print("CITY CAPTURE %s" % path)


func _car_report(label: String) -> void:
	var cars: Array = main.enemy_director.traffic_cars
	print("CITY %s cars=%d" % [label, cars.size()])
	for node in cars:
		var car := node as Vehicle
		if car != null:
			print("  CAR %s speed=%.1f kind=%s node=%s->%s" % [str(car.position), car.speed, str(car.kind), str(car.current_node), str(car.next_node)])


func _run() -> void:
	while not main.world.is_generated or not main.player.spawned:
		await process_frame
	for frame in range(420):
		await process_frame
	main.get_node("HUD/DebugReadout").visible = false
	print("CITY PHASE %s" % main.cycle.phase_name)
	var car_wait := 0
	while main.enemy_director.traffic_cars.is_empty() and car_wait < 1800:
		await process_frame
		car_wait += 1
	_car_report("SPAWNED")
	for frame in range(90):
		await process_frame
	_car_report("LATER")

	main.player.set_physics_process(false)
	var camera: Camera3D = main.player.get_node("Camera3D")
	await _capture("res://debug/evidence/city_spawn_night.png")

	# Sky views: hide the HUD and viewmodel so the shots are clean city evidence.
	main.get_node("HUD").visible = false
	main.player.viewmodel.visible = false
	camera.global_position = Vector3(64.0, 85.0, 64.0)
	camera.rotation = Vector3(-PI * 0.5, 0.0, 0.0)
	await _capture("res://debug/evidence/city_topdown.png")

	camera.global_position = Vector3(24.0, 46.0, 24.0)
	camera.look_at(Vector3(60.0, 4.0, 60.0), Vector3.UP)
	await _capture("res://debug/evidence/city_overview.png")
	main.get_node("HUD").visible = true
	main.player.viewmodel.visible = true

	camera.global_position = Vector3(9.5, 4.4, 9.5)
	camera.look_at(Vector3(9.5, 3.4, 60.0), Vector3.UP)
	await _capture("res://debug/evidence/city_avenue.png")

	camera.global_position = Vector3(15.0, 6.0, 15.0)
	camera.look_at(Vector3(16.5, 7.0, 16.5), Vector3.UP)
	await _capture("res://debug/evidence/city_plaza.png")

	# Close-up of a parked vehicle to verify the imported mesh scale.
	camera.global_position = Vector3(14.5, 4.6, 17.5)
	camera.look_at(Vector3(10.5, 3.6, 14.5), Vector3.UP)
	await _capture("res://debug/evidence/city_vehicle_close.png")

	# Enter a parked vehicle and capture the driving view.
	var parked: Vehicle = null
	for node in main.get_tree().get_nodes_in_group("vehicles"):
		var candidate := node as Vehicle
		if candidate != null and not candidate.is_traffic and candidate.position.distance_to(Vector3(10.5, 3.05, 14.5)) < 1.0:
			parked = candidate
			break
	if parked != null:
		camera.position = Vector3(0.0, 1.62, 0.0)
		camera.rotation = Vector3.ZERO
		main.player.set_physics_process(true)
		main.player._enter_vehicle(parked)
		for frame in range(24):
			await process_frame
		await _capture("res://debug/evidence/city_driving.png")
		main.player._exit_vehicle()
	quit(0)
