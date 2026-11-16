extends RefCounted
class_name WorldSave

const SAVE_VERSION := 1
const BLOCK_DEFS_VERSION := 1
const BLOCKS_FILE := "blocks.bin"
const METADATA_FILE := "metadata.json"


static func save_world(world: Node, player_position: Vector3, extra_metadata: Dictionary = {}) -> bool:
	var save_dir := "user://worlds/%d" % world.world_seed
	var dir_error := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(save_dir))
	if dir_error != OK:
		push_error("M1 save: could not create %s (%s)" % [save_dir, error_string(dir_error)])
		return false
	var blocks_file := FileAccess.open_compressed(save_dir.path_join(BLOCKS_FILE), FileAccess.WRITE, FileAccess.COMPRESSION_DEFLATE)
	if blocks_file == null:
		push_error("M1 save: could not open block file (%s)" % error_string(FileAccess.get_open_error()))
		return false
	blocks_file.store_buffer(world.blocks)
	blocks_file.close()
	var metadata := {
		"save_version": SAVE_VERSION,
		"seed": world.world_seed,
		"dimensions": [world.WORLD_X, world.WORLD_Y, world.WORLD_Z],
		"block_defs_version": BLOCK_DEFS_VERSION,
		"biome_map": Array(world.biome_map),
		"player_position": [player_position.x, player_position.y, player_position.z],
		"cradle_state": {},
		"inventory": {},
		"player_stats": {},
		"m4": extra_metadata
	}
	var metadata_file := FileAccess.open(save_dir.path_join(METADATA_FILE), FileAccess.WRITE)
	if metadata_file == null:
		push_error("M1 save: could not open metadata file (%s)" % error_string(FileAccess.get_open_error()))
		return false
	metadata_file.store_string(JSON.stringify(metadata))
	metadata_file.close()
	print("M1 save PASS: %s" % save_dir)
	return true


static func load_world(seed: int, expected_volume: int) -> Dictionary:
	var save_dir := "user://worlds/%d" % seed
	var metadata_path := save_dir.path_join(METADATA_FILE)
	var metadata_file := FileAccess.open(metadata_path, FileAccess.READ)
	if metadata_file == null:
		push_error("M1 load: missing metadata at %s" % metadata_path)
		return {}
	var parser := JSON.new()
	var parse_error := parser.parse(metadata_file.get_as_text())
	metadata_file.close()
	if parse_error != OK or not parser.data is Dictionary:
		push_error("M1 load: invalid metadata JSON")
		return {}
	var metadata: Dictionary = parser.data
	if int(metadata.get("save_version", -1)) != SAVE_VERSION:
		push_error("M1 load: save version mismatch; expected %d, got %s" % [SAVE_VERSION, str(metadata.get("save_version"))])
		return {}
	if int(metadata.get("block_defs_version", -1)) != BLOCK_DEFS_VERSION:
		push_error("M1 load: block definition version mismatch")
		return {}
	if int(metadata.get("seed", -1)) != seed:
		push_error("M1 load: seed mismatch")
		return {}
	var blocks_file := FileAccess.open_compressed(save_dir.path_join(BLOCKS_FILE), FileAccess.READ, FileAccess.COMPRESSION_DEFLATE)
	if blocks_file == null:
		push_error("M1 load: missing or invalid compressed blocks file")
		return {}
	var loaded_blocks := blocks_file.get_buffer(expected_volume)
	var file_error := blocks_file.get_error()
	blocks_file.close()
	if loaded_blocks.size() != expected_volume or file_error != OK:
		push_error("M1 load: block data length mismatch (%d, expected %d)" % [loaded_blocks.size(), expected_volume])
		return {}
	return {"metadata": metadata, "blocks": loaded_blocks}
