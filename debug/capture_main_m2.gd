extends SceneTree

const MAIN_SCENE := "res://scenes/world/main.tscn"
const OUTPUT := "res://debug/m2_evidence/main_world_torch_flashlight.png"

var main_node: Node3D
var elapsed_frames := 0

func _initialize() -> void:
	call_deferred("_capture")

func _capture() -> void:
	var packed := load(MAIN_SCENE) as PackedScene
	if packed == null:
		push_error("M2 main scene could not be loaded")
		quit(1)
		return
	main_node = packed.instantiate() as Node3D
	get_root().add_child(main_node)
	var world = main_node.get_node("VoxelWorld")
	var player = main_node.get_node("Player")
	while elapsed_frames < 2400:
		await process_frame
		elapsed_frames += 1
		if world.is_generated and world.initialized_light_chunks == world.CHUNK_COUNT and world.meshed_chunk_count == world.CHUNK_COUNT and player.spawned:
			break
	if not world.is_generated or world.static_light_sources.is_empty() or not player.spawned:
		push_error("M2 capture timed out: generated=%s lit=%d meshed=%d lights=%d spawned=%s" % [world.is_generated, world.initialized_light_chunks, world.meshed_chunk_count, world.static_light_sources.size(), player.spawned])
		quit(1)
		return
	var torch_cell := Vector3i(64, world.get_surface_height(64, 58) + 1, 58)
	player.position = Vector3(64.5, float(torch_cell.y) + 8.0, 62.0)
	player.look_at(Vector3(float(torch_cell.x) + 0.5, float(torch_cell.y) + 0.5, float(torch_cell.z) + 0.5), Vector3.UP)
	player.camera.rotation.x = -0.06
	world.call("_update_flashlight_uniforms")
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var image := get_root().get_texture().get_image()
	var error := image.save_png(OUTPUT)
	print("M2 main world capture: %s %dx%d; torch=%s; lights=%d; lit=%d; meshed=%d" % [OUTPUT, image.get_width(), image.get_height(), torch_cell, world.static_light_sources.size(), world.initialized_light_chunks, world.meshed_chunk_count])
	if error != OK:
		push_error("Screenshot failed: %s" % error_string(error))
		quit(1)
		return
	quit()