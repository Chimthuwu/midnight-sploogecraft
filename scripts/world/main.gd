extends Node3D

const SaveSystem = preload("res://scripts/save/save_manager.gd")

@onready var world: VoxelWorld = $VoxelWorld
@onready var player: VoxelPlayer = $Player
@onready var debug_label: Label = $HUD/DebugReadout
@onready var cycle: DayNightCycle = $DayNightCycle
@onready var gloom: GloomManager = $GloomManager
@onready var enemy_director: EnemyDirector = $EnemyDirector

var debug_visible := false
var pause_due_to_focus := false

func _ready() -> void:
	world.process_mode = Node.PROCESS_MODE_PAUSABLE
	player.process_mode = Node.PROCESS_MODE_PAUSABLE
	$HUD.process_mode = Node.PROCESS_MODE_ALWAYS
	debug_label.visible = false
	var props := StreetProps.new()
	props.name = "StreetProps"
	add_child(props)

func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("toggle_debug"):
		debug_visible = not debug_visible
		debug_label.visible = debug_visible
	if Input.is_action_just_pressed("toggle_flashlight"):
		world.set_flashlight_enabled(not world.flashlight_enabled)
	if Input.is_action_just_pressed("save_world"):
		save_game()
	if Input.is_action_just_pressed("load_world"):
		load_game()
	if world.is_generated and player.spawned:
		if Input.is_action_just_pressed("debug_spawn_gangs"):
			enemy_director.debug_spawn_gangs(3)
		if Input.is_action_just_pressed("debug_spawn_lamp_eater"):
			enemy_director.debug_spawn_lamp_eater()
		if Input.is_action_just_pressed("debug_spawn_cops"):
			enemy_director.debug_spawn_cops(2)
		if Input.is_action_just_pressed("debug_local_gloom"):
			var cell := Vector3i(floori(player.camera.global_position.x), floori(player.camera.global_position.y), floori(player.camera.global_position.z))
			gloom.set_level_for_cell(cell, 1.0)
	debug_label.text = _debug_text()

func save_game() -> void:
	if not world.is_generated or not player.spawned:
		return
	SaveSystem.save_world(world, player.position, {
		"day_night_elapsed": cycle.elapsed_seconds,
		"gloom_levels": gloom.to_save_array()
	})


func load_game() -> void:
	if not world.is_generated:
		return
	var save_data := SaveSystem.load_world(world.world_seed, world.BLOCK_VOLUME)
	if save_data.is_empty() or not world.restore_save(save_data):
		return
	var metadata: Dictionary = save_data["metadata"]
	var saved_position: Array = metadata.get("player_position", [])
	if saved_position.size() == 3:
		player.position = Vector3(saved_position[0], saved_position[1], saved_position[2])
	var m4_data: Dictionary = metadata.get("m4", {})
	cycle.restore_time(float(m4_data.get("day_night_elapsed", 0.0)))
	gloom.restore_from_array(m4_data.get("gloom_levels", []))


func _debug_text() -> String:
	var draw_calls := int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	var generated: int = world.generated_chunk_count
	var meshed: int = world.meshed_chunk_count
	var block_total: int = world.blocks.size() if world.is_generated else 0
	var light_cell := Vector3i(floori(player.camera.global_position.x), floori(player.camera.global_position.y), floori(player.camera.global_position.z))
	var hit: Dictionary = player._voxel_raycast(7.0)
	if not hit.is_empty():
		light_cell = hit["previous_air"]
	var light_level: int = world.get_light_level(light_cell) if world.is_generated else 0
	var gloom_level := world.get_gloom_level(light_cell)
	var chunk_index := world._chunk_index(Vector3i(light_cell.x / 16, light_cell.y / 16, light_cell.z / 16))
	return "NEON CITY | FPS %d | Draw %d | HP %d | %s | LIGHT %d | GLOOM %.2f\nChunks %d/256 generated, %d/256 meshed, %d/256 lit | blocks %d\nGloom chunk %d | enemies %d | static lights %d | WASD move | 1–4 cartridges | Q projector | K save | J load | F HUD | T flashlight %s | F6 gangs | F7 lamp eater | F9 cops | F8 local gloom" % [Engine.get_frames_per_second(), draw_calls, roundi(player.health), cycle.phase_name.to_upper(), light_level, gloom_level, generated, meshed, world.initialized_light_chunks, block_total, chunk_index, get_tree().get_nodes_in_group("enemies").size(), world.static_light_sources.size(), "ON" if world.flashlight_enabled else "OFF"]

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		pause_due_to_focus = true
		get_tree().paused = true
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN and pause_due_to_focus:
		pause_due_to_focus = false
		get_tree().paused = false