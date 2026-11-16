extends SceneTree

const TEST_SCENE := "res://debug/lighttest.tscn"
const LIGHT_RANGE := 15
const CHUNK_BORDER_X := 15

var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := load(TEST_SCENE) as PackedScene
	if packed == null:
		push_error("M2 test could not load isolated lighttest scene")
		quit(1)
		return
	var scene := packed.instantiate()
	root.add_child(scene)
	await process_frame
	_check_light_table(scene)
	_check_chunk_border(scene)
	_check_air_hud(scene)
	_check_dynamic_flashlight(scene)
	_benchmark_chunk(scene)
	print("M2 AUTOMATED CHECKS %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)


func _check_light_table(scene: Node) -> void:
	var source: Vector3i = scene.get("source_cell")
	for distance in range(1, LIGHT_RANGE + 1):
		var air_expected := maxi(0, LIGHT_RANGE - distance)
		var mycelium_expected := maxi(0, LIGHT_RANGE - 4 * distance)
		var pale_expected := 0
		var air_actual: int = scene.call("_light_at", source + Vector3i(distance, 0, 0))
		var mycelium_actual: int = scene.call("_light_at", source + Vector3i(0, distance, 0))
		var pale_actual: int = scene.call("_light_at", source + Vector3i(0, 0, distance))
		var passed := air_actual == air_expected and mycelium_actual == mycelium_expected and pale_actual == pale_expected
		print("M2 TABLE d=%02d air=%d/%d mycelium=%d/%d pale=%d/%d %s" % [distance, air_actual, air_expected, mycelium_actual, mycelium_expected, pale_actual, pale_expected, "PASS" if passed else "FAIL"])
		if not passed:
			failures += 1


func _check_chunk_border(scene: Node) -> void:
	var passed := true
	for distance in range(0, LIGHT_RANGE + 1):
		var cell := Vector3i(CHUNK_BORDER_X + distance, 15, 15)
		var actual: int = scene.call("_light_at", cell)
		var expected := maxi(0, LIGHT_RANGE - distance)
		if actual != expected:
			passed = false
			print("M2 BORDER FAIL x=%d light=%d expected=%d" % [cell.x, actual, expected])
	print("M2 CHUNK BORDER LIGHT CONTINUITY %s" % ("PASS" if passed else "FAIL"))
	if not passed:
		failures += 1


func _check_air_hud(scene: Node) -> void:
	var camera: Camera3D = scene.get_node("Camera3D")
	camera.position = Vector3(10.5, 16.5, 12.5)
	camera.look_at(Vector3(15.5, 15.5, 15.5))
	scene.call("_update_readout")
	var readout: Label = scene.get_node("HUD/Readout")
	var passed := readout.text.contains("LIGHT_LEVEL 12") and readout.text.contains("GLOOM_LEVEL") and readout.text.contains("block air at (13, 15, 14)")
	print("M2 AIR HUD %s | %s" % ["PASS" if passed else "FAIL", readout.text.get_slice("\n", 1)])
	if not passed:
		failures += 1

func _check_dynamic_flashlight(scene: Node) -> void:
	var camera: Camera3D = scene.get_node("Camera3D")
	var material: ShaderMaterial = scene.get("world_material")
	var mesh_generation_before: int = scene.get("mesh_build_generation")
	var position_before: Vector3 = material.get_shader_parameter("flashlight_position")
	var direction_before: Vector3 = material.get_shader_parameter("flashlight_direction")
	camera.position += Vector3(0.25, 0.0, 0.0)
	camera.rotation.y += 0.2
	scene.call("_update_flashlight_uniforms")
	var position_after: Vector3 = material.get_shader_parameter("flashlight_position")
	var direction_after: Vector3 = material.get_shader_parameter("flashlight_direction")
	var mesh_generation_after: int = scene.get("mesh_build_generation")
	var passed := position_before != position_after and direction_before != direction_after and mesh_generation_before == mesh_generation_after
	print("M2 DYNAMIC FLASHLIGHT uniforms update without chunk remesh %s" % ("PASS" if passed else "FAIL"))
	if not passed:
		failures += 1

func _benchmark_chunk(scene: Node) -> void:
	var samples: Array[int] = []
	for run_index in range(5):
		var elapsed_usec: int = scene.call("_propagate_chunk", Vector3i(0, 0, 0))
		samples.append(elapsed_usec)
	samples.sort()
	var median_usec := samples[2]
	var max_usec := samples[4]
	var passed := median_usec < 3000 and max_usec < 4000
	print("M2 CHUNK TIMING usec=%s median=%d max=%d %s" % [str(samples), median_usec, max_usec, "PASS" if passed else "FAIL"])
	if not passed:
		failures += 1