extends SceneTree

const WorldScript = preload("res://scripts/world/world.gd")
const SaveSystem = preload("res://scripts/save/save_manager.gd")
const WORLD_SEED := 139732
const WORLD_VOLUME := 128 * 64 * 128
const EXPECTED_PATH := "user://m1_roundtrip_expected.json"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		push_error("Usage: m1_roundtrip_test.gd save|load")
		quit(2)
		return
	if args[0] == "save":
		await _save_phase()
	elif args[0] == "load":
		_load_phase()
	else:
		push_error("Unknown round-trip phase: %s" % args[0])
		quit(2)


func _save_phase() -> void:
	var world = WorldScript.new()
	world.world_seed = WORLD_SEED
	root.add_child(world)
	var frames := 0
	while not world.is_generated and frames < 6000:
		await process_frame
		frames += 1
	if not world.is_generated:
		push_error("M1 round-trip save phase timed out during generation")
		quit(1)
		return
	var samples: Array = []
	for sample_index in range(20):
		var x := 3 + sample_index * 6
		var y := 2 + (sample_index * 7) % 55
		var z := 24 + (sample_index % 5) * 13
		var block_id: int = world.block_ids[&"iron_ore"] if sample_index % 2 == 0 else world.block_ids[&"air"]
		world.set_block(Vector3i(x, y, z), block_id)
		samples.append({"x": x, "y": y, "z": z, "id": block_id})
	if not SaveSystem.save_world(world, Vector3(64.5, 30.0, 64.5)):
		push_error("M1 round-trip save phase failed to write save files")
		quit(1)
		return
	var metadata_path := "user://worlds/%d/metadata.json" % WORLD_SEED
	var metadata_file := FileAccess.open(metadata_path, FileAccess.READ)
	if metadata_file == null:
		push_error("M1 round-trip could not read written metadata")
		quit(1)
		return
	var parser := JSON.new()
	var parse_error := parser.parse(metadata_file.get_as_text())
	metadata_file.close()
	if parse_error != OK:
		push_error("M1 round-trip saved invalid metadata JSON")
		quit(1)
		return
	var expected_file := FileAccess.open(EXPECTED_PATH, FileAccess.WRITE)
	expected_file.store_string(JSON.stringify({"samples": samples, "metadata": parser.data}))
	expected_file.close()
	print("M1 ROUNDTRIP SAVE PHASE PASS: generated world saved; exiting before reload.")
	quit(0)


func _load_phase() -> void:
	var expected_file := FileAccess.open(EXPECTED_PATH, FileAccess.READ)
	if expected_file == null:
		push_error("M1 round-trip expected data missing; run save phase first")
		quit(1)
		return
	var expected_parser := JSON.new()
	var expected_error := expected_parser.parse(expected_file.get_as_text())
	expected_file.close()
	if expected_error != OK:
		push_error("M1 round-trip expected data is invalid")
		quit(1)
		return
	var loaded := SaveSystem.load_world(WORLD_SEED, WORLD_VOLUME)
	if loaded.is_empty():
		push_error("M1 round-trip load phase failed")
		quit(1)
		return
	var samples: Array = expected_parser.data["samples"]
	var loaded_blocks: PackedByteArray = loaded["blocks"]
	var passed := true
	for sample in samples:
		var index := int(sample["x"]) + int(sample["z"]) * 128 + int(sample["y"]) * 128 * 128
		var actual := int(loaded_blocks[index])
		var expected := int(sample["id"])
		print("M1 round-trip sample (%d,%d,%d) expected=%d actual=%d %s" % [sample["x"], sample["y"], sample["z"], expected, actual, "PASS" if actual == expected else "FAIL"])
		if actual != expected:
			passed = false
	if loaded["metadata"] != expected_parser.data["metadata"]:
		passed = false
		push_error("M1 round-trip metadata does not match the saved metadata")
	print("M1 ROUNDTRIP %s: 20 blocks and full JSON metadata after a fresh process." % ("PASS" if passed else "FAIL"))
	quit(0 if passed else 1)