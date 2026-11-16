extends SceneTree

const SCENE_PATH := "res://debug/lighttest.tscn"
const OUTPUT_DIR := "res://debug/evidence/"

var test_scene: Node3D
var test_camera: Camera3D
var test_readout: Label
var torch_label: Label


func _initialize() -> void:
	call_deferred("_capture_all")


func _capture_all() -> void:
	var packed_scene := load(SCENE_PATH) as PackedScene
	if packed_scene == null:
		push_error("Could not load M0 lighttest scene.")
		quit(1)
		return
	test_scene = packed_scene.instantiate() as Node3D
	get_root().add_child(test_scene)
	test_camera = test_scene.get_node("Camera3D") as Camera3D
	test_camera.fov = 55.0
	test_readout = test_scene.get_node("HUD/Readout") as Label
	_create_source_label()

	# AIR sample above the tunnel floor; the ray ends at the sealed outer wall.
	_set_source(Vector3i(15, 15, 15))
	_aim(Vector3(10.5, 16.5, 12.5), Vector3(15.5, 15.5, 15.5))
	await _save_frame("m0_01_dither_air_crosshair.png")

	# Light source sits at the intersection of the 16-block chunk boundaries.
	_set_source(Vector3i(15, 15, 15))
	_aim(Vector3(10.5, 16.5, 12.5), Vector3(15.5, 15.5, 15.5))
	await _save_frame("m0_02_border_west.png")
	_aim(Vector3(10.5, 15.5, 17.5), Vector3(15.5, 15.5, 15.5))
	await _save_frame("m0_03_border_upper_angle.png")
	_aim(Vector3(12.5, 12.5, 12.5), Vector3(15.5, 15.5, 15.5))
	await _save_frame("m0_04_border_lower_angle.png")

	# Capture the same view before and after the existing L-key movement action.
	_set_source(Vector3i(15, 15, 15))
	_aim(Vector3(12.5, 15.5, 12.5), Vector3(12.5, 15.5, 32.0))
	await _save_frame("m0_05_light_before.png")
	_aim(Vector3(12.0, 15.0, 14.0), Vector3(8.0, 15.0, 12.0))
	var move_event := InputEventKey.new()
	move_event.physical_keycode = KEY_L
	move_event.pressed = true
	test_scene.call("_input", move_event)
	_update_torch_marker()
	print("M0 capture moved light using view action; source is now %s" % test_scene.get("source_cell"))
	_aim(Vector3(12.5, 15.5, 12.5), Vector3(12.5, 15.5, 32.0))
	await _save_frame("m0_06_light_after.png")

	# A distinct HUD evidence view, also sampling the AIR corridor.
	_set_source(Vector3i(15, 15, 15))
	_aim(Vector3(10.5, 16.5, 12.5), Vector3(15.5, 15.5, 15.5))
	await _save_frame("m0_07_debug_hud.png")
	quit()


func _set_source(cell: Vector3i) -> void:
	test_scene.set("source_cell", cell)
	test_scene.call("_recalculate_light", false)
	_update_torch_marker()


func _aim(position: Vector3, target: Vector3) -> void:
	test_camera.position = position
	var direction := (target - position).normalized()
	var up := Vector3.UP
	if absf(direction.dot(up)) > 0.98:
		up = Vector3.FORWARD
	test_camera.look_at(target, up)
	test_scene.call("_update_readout")


func _save_frame(file_name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var image := get_root().get_texture().get_image()
	var output_path := OUTPUT_DIR + file_name
	var error := image.save_png(output_path)
	print("M0 screenshot %s %dx%d; %s" % [output_path, image.get_width(), image.get_height(), test_readout.text.replace("\n", " | ")])
	if error != OK:
		push_error("Could not save screenshot %s: %s" % [output_path, error_string(error)])




func _create_source_label() -> void:
	torch_label = Label.new()
	torch_label.position = Vector2(560.0, 10.0)
	torch_label.size = Vector2(290.0, 24.0)
	torch_label.add_theme_color_override("font_color", Color(1.0, 0.58, 0.22))
	test_scene.get_node("HUD").add_child(torch_label)
	_update_torch_marker()


func _update_torch_marker() -> void:
	var source: Vector3i = test_scene.get("source_cell")
	if is_instance_valid(torch_label):
		var border_note := " | BORDER" if source == Vector3i(15, 15, 15) else ""
		torch_label.text = "TORCH @ %d,%d,%d%s" % [source.x, source.y, source.z, border_note]