extends SceneTree

const MAIN_SCENE := "res://scenes/world/main.tscn"
const WALK_DISTANCE := 50.0
const FRAME_BUDGET_USEC := 20000


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := load(MAIN_SCENE) as PackedScene
	if packed == null:
		push_error("M1 walk test could not load main scene")
		quit(1)
		return
	var main := packed.instantiate()
	root.add_child(main)
	var world = main.get_node("VoxelWorld")
	var player = main.get_node("Player")
	var frames := 0
	while (not world.is_generated or world.meshed_chunk_count < world.CHUNK_COUNT or not player.spawned) and frames < 12000:
		await process_frame
		frames += 1
	if not world.is_generated or world.meshed_chunk_count < world.CHUNK_COUNT or not player.spawned:
		push_error("M1 walk test timed out waiting for generated/meshed world and player spawn")
		quit(1)
		return
	player.rotation.y = 0.0
	var start_x: float = player.position.x
	var start_z: float = player.position.z
	var frame_count := 0
	var slow_count := 0
	var max_usec := 0
	Input.action_press("move_right")
	Input.action_press("sprint")
	while player.position.x - start_x < WALK_DISTANCE and frame_count < 1800:
		var frame_start := Time.get_ticks_usec()
		await process_frame
		var elapsed := Time.get_ticks_usec() - frame_start
		max_usec = maxi(max_usec, elapsed)
		if elapsed > FRAME_BUDGET_USEC:
			slow_count += 1
			print("M1 WALK frame %d: %d us (>20ms), position=%s" % [frame_count, elapsed, str(player.position)])
		frame_count += 1
	Input.action_release("move_right")
	Input.action_release("sprint")
	var distance := player.position.x - start_x
	print("M1 WALK distance=%.2f blocks frames=%d start_z=%.2f end_z=%.2f slow_frames=%d max_frame=%d us" % [distance, frame_count, start_z, player.position.z, slow_count, max_usec])
	if distance < WALK_DISTANCE:
		push_error("M1 WALK FAIL: only moved %.2f of %.2f blocks" % [distance, WALK_DISTANCE])
		quit(1)
		return
	print("M1 WALK PASS: completed 50-block traverse; >20ms frames logged above.")
	quit(0)