extends SceneTree

var main: Node


func _initialize() -> void:
	main = load("res://scenes/world/main.tscn").instantiate()
	root.add_child(main)
	_run.call_deferred()


func _capture(path: String) -> void:
	await process_frame
	await process_frame
	var image := root.get_texture().get_image()
	image.save_png(path)
	print("CAPTURED %s %dx%d" % [path, image.get_width(), image.get_height()])


func _run() -> void:
	while not main.world.is_generated or not main.player.spawned:
		await process_frame
	for frame in range(420):
		await process_frame
	main.get_node("HUD/DebugReadout").visible = false

	var player: Node3D = main.player
	var camera: Camera3D = player.get_node("Camera3D")
	await _capture("res://debug/evidence/audit_spawn.png")

	# High vista looking across the ash plain toward the spawn clearing.
	player.set_physics_process(false)
	player.global_position = Vector3(52.0, 39.0, 91.0)
	camera.global_position = Vector3(52.0, 40.6, 91.0)
	camera.look_at(Vector3(70.0, 24.0, 60.0), Vector3.UP)
	await _capture("res://debug/evidence/audit_vista.png")

	# Low eye-level shot of props near the ground.
	camera.global_position = Vector3(66.0, 26.5, 74.0)
	camera.look_at(Vector3(75.0, 22.0, 66.0), Vector3.UP)
	await _capture("res://debug/evidence/audit_ground.png")

	var caster: Lumencaster = main.get_node("Player/Lumencaster") as Lumencaster
	caster._set_projector_mode(true)
	await process_frame
	main.get_node("Player/Camera3D/Viewmodel").visible = false
	await _capture("res://debug/evidence/ui_projector.png")
	main.get_node("Player/Camera3D/Viewmodel").visible = true
	caster._set_projector_mode(false)

	var game_hud: GameHUD = main.get_node("HUD") as GameHUD
	game_hud.pause_game()
	await process_frame
	await _capture("res://debug/evidence/ui_pause.png")
	game_hud.resume_game()
	quit(0)
