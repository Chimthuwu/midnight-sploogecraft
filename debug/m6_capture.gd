extends SceneTree

var main: Node
var camera: Camera3D

func _initialize() -> void:
	main = load("res://scenes/world/main.tscn").instantiate()
	root.add_child(main)
	_run.call_deferred()


func _force_resume() -> void:
	# A lost window focus pauses the tree and opens the pause overlay; clear it
	# so no capture happens over the menu.
	paused = false
	main.set("pause_due_to_focus", false)
	var caster: Node = main.player.get_node_or_null("Lumencaster")
	if caster != null:
		caster.set("status_time", 0.0)  # no stale drill toast over the shot
	var hud: Node = main.get_node_or_null("HUD")
	if hud != null and "paused" in hud:
		hud.set("paused", false)
		var overlay: Node = hud.get_node_or_null("PauseOverlay")
		if overlay != null:
			overlay.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _capture(path: String, label: String) -> void:
	_force_resume()
	await process_frame
	await process_frame
	root.get_texture().get_image().save_png(path)
	var draws := Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	print("M6 CAPTURE %s -> %s (fps=%d draws=%d)" % [label, path, Engine.get_frames_per_second(), int(draws)])


func _view(from: Vector3, to: Vector3, path: String, label: String) -> void:
	camera.global_position = from
	camera.look_at(to, Vector3.UP)
	await _capture(path, label)


# The world streams roughly 30 active chunks around the player body, so every
# vantage needs the player teleported there first, then a wait while the
# streaming set rebuilds, lights and meshes around the new position.
func _goto(pos: Vector3) -> void:
	main.player.global_position = pos
	main.player.velocity = Vector3.ZERO
	for frame in range(300):
		await process_frame


func _run() -> void:
	while not main.world.is_generated or not main.player.spawned:
		await process_frame
		# A stray window-activation click can fire the idle Lumencaster during
		# the spawn wait; disarm it the moment the player exists.
		var caster: Node = main.player.get_node_or_null("Lumencaster")
		if caster != null:
			caster.process_mode = Node.PROCESS_MODE_DISABLED
	for frame in range(360):
		await process_frame
	main.get_node("HUD/DebugReadout").visible = false
	main.player.set_physics_process(false)
	main.player.process_mode = Node.PROCESS_MODE_DISABLED  # keep the idle drill from firing
	camera = main.player.get_node("Camera3D")
	var viewmodel: Node3D = main.player.get_node("Camera3D/Viewmodel")
	viewmodel.visible = false

	# 1. Street level at the spawn intersection, looking down the avenue
	# toward the plaza gateway and the district behind it. The camera floats
	# above parked-car roofs on purpose.
	await _view(Vector3(9.5, 5.0, 9.5), Vector3(9.5, 6.5, 80.0), "res://debug/evidence/m6_street_level.png", "street level")

	# 2. Looking down a street canyon in the neon district, shopfronts at eye level.
	await _goto(Vector3(29.5, 3.2, 29.5))
	await _view(Vector3(29.5, 5.0, 29.5), Vector3(29.5, 6.5, 80.0), "res://debug/evidence/m6_neon_district.png", "neon street")

	# 3. Looking up at a tenement corner from the sidewalk.
	await _goto(Vector3(30.5, 3.2, 51.0))
	await _view(Vector3(30.5, 4.0, 51.0), Vector3(36.0, 22.0, 56.0), "res://debug/evidence/m6_looking_up.png", "looking up")

	# 4. Downtown skyline from a rooftop vantage.
	await _goto(Vector3(58.0, 39.0, 16.0))
	await _view(Vector3(58.0, 40.0, 16.0), Vector3(76.0, 16.0, 76.0), "res://debug/evidence/m6_downtown_skyline.png", "downtown skyline")

	# 5. Orbit Hall landmark from the street: marquee, blade sign and dome.
	await _goto(Vector3(49.5, 3.2, 29.5))
	await _view(Vector3(49.5, 5.0, 29.5), Vector3(39.0, 9.0, 36.0), "res://debug/evidence/m6_venue.png", "venue landmark")

	# 6. Gasworks on the industrial edge, framed on the smokestacks.
	await _goto(Vector3(9.5, 3.2, 69.5))
	await _view(Vector3(9.5, 5.0, 69.5), Vector3(19.0, 12.0, 100.0), "res://debug/evidence/m6_industrial.png", "industrial")

	# 7. Outskirts: shed and scrap yard from the intersection south of them,
	# aimed down so the flashlight reaches the yard.
	await _goto(Vector3(109.5, 3.2, 109.5))
	await _view(Vector3(109.5, 6.5, 109.5), Vector3(119.0, 4.0, 119.0), "res://debug/evidence/m6_outskirts.png", "outskirts")

	# 8. Actually driving a car: return to spawn and take a parked vehicle.
	await _goto(Vector3(9.5, 3.2, 9.5))
	camera.position = Vector3(0.0, 1.62, 0.0)
	camera.rotation = Vector3.ZERO
	main.player.process_mode = Node.PROCESS_MODE_INHERIT
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
