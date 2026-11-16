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
		var car := node as TrafficCar
		if car != null:
			print("  CAR %s axis=%d dir=%.1f speed=%.1f" % [str(car.position), car.move_axis, car.direction, car.speed])


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

	camera.global_position = Vector3(24.0, 46.0, 24.0)
	camera.look_at(Vector3(60.0, 4.0, 60.0), Vector3.UP)
	await _capture("res://debug/evidence/city_overview.png")

	camera.global_position = Vector3(8.5, 4.4, 8.5)
	camera.look_at(Vector3(8.5, 3.4, 60.0), Vector3.UP)
	await _capture("res://debug/evidence/city_avenue.png")

	camera.global_position = Vector3(15.0, 6.0, 15.0)
	camera.look_at(Vector3(16.5, 7.0, 16.5), Vector3.UP)
	await _capture("res://debug/evidence/city_plaza.png")
	quit(0)
