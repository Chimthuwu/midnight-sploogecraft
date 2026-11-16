extends Node3D

const WORLD_SIZE := 32
const CHUNK_SIZE := 16
const BLOCK_AIR := 0
const BLOCK_MYCELIUM := 1
const BLOCK_PALE_BLOOM := 2
const BLOCK_TEST_WALL := 4
const LIGHT_RANGE := 15
const PADDED_SIZE := CHUNK_SIZE + LIGHT_RANGE * 2
const PADDED_NEIGHBOR_OFFSETS := [-1, 1, -PADDED_SIZE, PADDED_SIZE, -PADDED_SIZE * PADDED_SIZE, PADDED_SIZE * PADDED_SIZE]
const FACE_NORMALS := [
	Vector3.RIGHT, Vector3.LEFT, Vector3.UP,
	Vector3.DOWN, Vector3.BACK, Vector3.FORWARD
]

@onready var camera: Camera3D = $Camera3D
@onready var readout: Label = $HUD/Readout

var block_defs: Array[BlockLightDef] = []
var blocks := PackedByteArray()
var light_buckets: Array[Array] = []
var chunk_light_buffers: Array[PackedByteArray] = []
var gloom_levels := PackedByteArray()
var source_cell := Vector3i(15, 15, 15)
var chunk_root: Node3D
var world_material: ShaderMaterial
var debug_visible := true
var mouse_captured := true
var mesh_build_generation := 0


func _ready() -> void:
	_load_block_defs()
	for bucket_index in range(LIGHT_RANGE + 1):
		light_buckets.append([])
	_build_test_world()
	_create_render_nodes()
	_recalculate_light(true)
	_run_light_table_check()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and mouse_captured:
		camera.rotate_y(-event.relative.x * 0.0025)
		camera.rotation.x = clampf(camera.rotation.x - event.relative.y * 0.0025, -1.5, 1.5)
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			mouse_captured = not mouse_captured
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if mouse_captured else Input.MOUSE_MODE_VISIBLE
	if event.is_action_pressed("move_light"):
		_move_light_to_view()
	if event.is_action_pressed("toggle_debug"):
		debug_visible = not debug_visible
		readout.visible = debug_visible


func _process(delta: float) -> void:
	_move_camera(delta)
	_update_flashlight_uniforms()
	_update_readout()


func _move_camera(delta: float) -> void:
	var wish := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var velocity := camera.global_basis.x * wish.x - camera.global_basis.z * wish.y
	if Input.is_action_pressed("move_up"):
		velocity += Vector3.UP
	if Input.is_action_pressed("move_down"):
		velocity -= Vector3.UP
	if velocity.length_squared() > 0.0:
		camera.position += velocity.normalized() * 8.0 * delta
		camera.position.x = clampf(camera.position.x, 1.0, 30.0)
		camera.position.y = clampf(camera.position.y, 1.0, 30.0)
		camera.position.z = clampf(camera.position.z, 1.0, 30.0)


func _load_block_defs() -> void:
	block_defs = [
		load("res://data/blocks/air.tres") as BlockLightDef,
		load("res://data/blocks/mycelium.tres") as BlockLightDef,
		load("res://data/blocks/pale_bloom.tres") as BlockLightDef,
		load("res://data/blocks/stone.tres") as BlockLightDef,
		load("res://data/blocks/test_wall.tres") as BlockLightDef
	]
	for block_def in block_defs:
		if block_def == null:
			push_error("M0 block definition failed to load.")
			return
		print("M0 block loaded: %s attenuation=%d" % [block_def.block_id, block_def.attenuation])


func _build_test_world() -> void:
	var volume := WORLD_SIZE * WORLD_SIZE * WORLD_SIZE
	blocks.resize(volume)
	blocks.fill(BLOCK_TEST_WALL)
	chunk_light_buffers.resize((WORLD_SIZE / CHUNK_SIZE) * (WORLD_SIZE / CHUNK_SIZE) * (WORLD_SIZE / CHUNK_SIZE))
	for chunk_index in range(chunk_light_buffers.size()):
		var chunk_light := PackedByteArray()
		chunk_light.resize(CHUNK_SIZE * CHUNK_SIZE * CHUNK_SIZE)
		chunk_light.fill(0)
		chunk_light_buffers[chunk_index] = chunk_light
	gloom_levels.resize(volume)
	gloom_levels.fill(0)

	# A sealed, fly-through camera bay joined to three isolated light probes.
	# The probes start at the same source: air (+X), mycelium (+Y), pale bloom (+Z).
	for x in range(8, 14):
		for y in range(12, 19):
			for z in range(12, 19):
				_set_block(Vector3i(x, y, z), BLOCK_AIR)
	# Solid observation floor puts the crosshair AIR sample one cell above it.
	for x in range(8, 14):
		for z in range(12, 19):
			_set_block(Vector3i(x, 14, z), BLOCK_TEST_WALL)
	_set_block(Vector3i(14, 15, 15), BLOCK_AIR)
	_set_block(source_cell, BLOCK_AIR)
	for distance in range(1, LIGHT_RANGE + 1):
		_set_block(source_cell + Vector3i(distance, 0, 0), BLOCK_AIR)
		_set_block(source_cell + Vector3i(0, distance, 0), BLOCK_MYCELIUM)
		_set_block(source_cell + Vector3i(0, 0, distance), BLOCK_PALE_BLOOM)


func _create_render_nodes() -> void:
	chunk_root = Node3D.new()
	chunk_root.name = "Chunks"
	add_child(chunk_root)
	var shader := load("res://shaders/light_dither.gdshader") as Shader
	world_material = ShaderMaterial.new()
	world_material.shader = shader
	world_material.set_shader_parameter("dither_bands", 6.0)
	world_material.set_shader_parameter("flashlight_enabled", true)
	world_material.set_shader_parameter("flashlight_range", 12.0)
	world_material.set_shader_parameter("flashlight_inner_cos", 0.94)
	world_material.set_shader_parameter("flashlight_outer_cos", 0.82)
	world_material.set_shader_parameter("flashlight_intensity", 0.85)
	_update_flashlight_uniforms()


func _update_flashlight_uniforms() -> void:
	if not is_instance_valid(camera) or not is_instance_valid(world_material):
		return
	world_material.set_shader_parameter("flashlight_position", camera.global_position)
	world_material.set_shader_parameter("flashlight_direction", -camera.global_basis.z)


func _move_light_to_view() -> void:
	var target := camera.global_position + -camera.global_basis.z * 4.0
	var next_cell := Vector3i(roundi(target.x), roundi(target.y), roundi(target.z))
	next_cell.x = clampi(next_cell.x, 1, WORLD_SIZE - 2)
	next_cell.y = clampi(next_cell.y, 1, WORLD_SIZE - 2)
	next_cell.z = clampi(next_cell.z, 1, WORLD_SIZE - 2)
	_set_block(next_cell, BLOCK_AIR)
	source_cell = next_cell
	_recalculate_light(false)


func _recalculate_light(initial: bool) -> void:
	var max_chunk_usec := 0
	for chunk_light in chunk_light_buffers:
		chunk_light.fill(0)
	for cz in range(WORLD_SIZE / CHUNK_SIZE):
		for cy in range(WORLD_SIZE / CHUNK_SIZE):
			for cx in range(WORLD_SIZE / CHUNK_SIZE):
				var elapsed := _propagate_chunk(Vector3i(cx, cy, cz))
				max_chunk_usec = maxi(max_chunk_usec, elapsed)
	_build_chunk_meshes()
	print("M0 max 16^3 chunk light update (15-block padded): %d us" % max_chunk_usec)
	if initial:
		print("M0 table: expected air 15-d, mycelium max(0,15-4d), pale bloom 0")
	_update_readout()


func _propagate_chunk(chunk: Vector3i) -> int:
	var start_usec := Time.get_ticks_usec()
	var padded_blocks := PackedByteArray()
	var padded_volume := PADDED_SIZE * PADDED_SIZE * PADDED_SIZE
	var padded_light := PackedByteArray()
	padded_light.resize(padded_volume)
	padded_light.fill(0)
	var padded_origin := chunk * CHUNK_SIZE - Vector3i(LIGHT_RANGE, LIGHT_RANGE, LIGHT_RANGE)
	var copy_x_begin := maxi(0, -padded_origin.x)
	var copy_x_end := mini(PADDED_SIZE, WORLD_SIZE - padded_origin.x)
	var wall_row := PackedByteArray()
	wall_row.resize(PADDED_SIZE)
	wall_row.fill(BLOCK_TEST_WALL)
	for z in range(PADDED_SIZE):
		var world_z := padded_origin.z + z
		for y in range(PADDED_SIZE):
			var world_y := padded_origin.y + y
			if world_z < 0 or world_z >= WORLD_SIZE or world_y < 0 or world_y >= WORLD_SIZE:
				padded_blocks.append_array(wall_row)
				continue
			if copy_x_begin > 0:
				padded_blocks.append_array(wall_row.slice(0, copy_x_begin))
			var source_row := padded_origin.x + copy_x_begin + world_y * WORLD_SIZE + world_z * WORLD_SIZE * WORLD_SIZE
			padded_blocks.append_array(blocks.slice(source_row, source_row + copy_x_end - copy_x_begin))
			if copy_x_end < PADDED_SIZE:
				padded_blocks.append_array(wall_row.slice(copy_x_end, PADDED_SIZE))
	if padded_blocks.size() != padded_volume:
		push_error("M0 padded block copy has the wrong size.")
		return 0

	var source_local := source_cell - padded_origin
	var core_index := _chunk_index(chunk)
	if source_local.x >= 0 and source_local.y >= 0 and source_local.z >= 0 and source_local.x < PADDED_SIZE and source_local.y < PADDED_SIZE and source_local.z < PADDED_SIZE:
		var source_index := _padded_index(source_local)
		padded_light[source_index] = LIGHT_RANGE
		light_buckets[LIGHT_RANGE].append(source_index)
		for level in range(LIGHT_RANGE, 0, -1):
			while not light_buckets[level].is_empty():
				var current_index: int = light_buckets[level].pop_back()
				if padded_light[current_index] != level:
					continue
				var local_x := current_index % PADDED_SIZE
				var local_row := int(current_index / PADDED_SIZE)
				var local_y := local_row % PADDED_SIZE
				var local_z := int(local_row / PADDED_SIZE)
				for direction in range(6):
					if direction == 0 and local_x == 0:
						continue
					if direction == 1 and local_x == PADDED_SIZE - 1:
						continue
					if direction == 2 and local_y == 0:
						continue
					if direction == 3 and local_y == PADDED_SIZE - 1:
						continue
					if direction == 4 and local_z == 0:
						continue
					if direction == 5 and local_z == PADDED_SIZE - 1:
						continue
					var neighbor_index: int = current_index + PADDED_NEIGHBOR_OFFSETS[direction]
					var candidate := level - block_defs[padded_blocks[neighbor_index]].attenuation
					if candidate > 0 and candidate > padded_light[neighbor_index]:
						padded_light[neighbor_index] = candidate
						light_buckets[candidate].append(neighbor_index)

	var core_light := PackedByteArray()
	var first_core_row := LIGHT_RANGE + LIGHT_RANGE * PADDED_SIZE + LIGHT_RANGE * PADDED_SIZE * PADDED_SIZE
	for z in range(CHUNK_SIZE):
		for y in range(CHUNK_SIZE):
			var padded_row := first_core_row + y * PADDED_SIZE + z * PADDED_SIZE * PADDED_SIZE
			core_light.append_array(padded_light.slice(padded_row, padded_row + CHUNK_SIZE))
	chunk_light_buffers[core_index] = core_light
	return Time.get_ticks_usec() - start_usec

func _run_light_table_check() -> void:
	var passed := true
	for distance in range(1, LIGHT_RANGE + 1):
		var air_actual := _light_at(source_cell + Vector3i(distance, 0, 0))
		var mycelium_actual := _light_at(source_cell + Vector3i(0, distance, 0))
		var pale_actual := _light_at(source_cell + Vector3i(0, 0, distance))
		var air_expected := maxi(0, LIGHT_RANGE - distance)
		var mycelium_expected := maxi(0, LIGHT_RANGE - 4 * distance)
		var pale_expected := 0
		print("M0 d=%02d air=%d/%d mycelium=%d/%d pale=%d/%d" % [
			distance, air_actual, air_expected, mycelium_actual, mycelium_expected,
			pale_actual, pale_expected
		])
		if air_actual != air_expected or mycelium_actual != mycelium_expected or pale_actual != pale_expected:
			passed = false
			push_warning("M0 light table mismatch at distance %d" % distance)
	print("M0 LIGHT_LEVEL table %s" % ("PASS" if passed else "FAIL"))


func _build_chunk_meshes() -> void:
	mesh_build_generation += 1
	for child in chunk_root.get_children():
		child.free()
	for cz in range(WORLD_SIZE / CHUNK_SIZE):
		for cy in range(WORLD_SIZE / CHUNK_SIZE):
			for cx in range(WORLD_SIZE / CHUNK_SIZE):
				var mesh := _build_chunk_mesh(Vector3i(cx, cy, cz))
				if mesh == null:
					continue
				var instance := MeshInstance3D.new()
				instance.name = "Chunk_%d_%d_%d" % [cx, cy, cz]
				instance.position = Vector3(cx, cy, cz) * CHUNK_SIZE
				instance.mesh = mesh
				instance.material_override = world_material
				chunk_root.add_child(instance)


func _build_chunk_mesh(chunk: Vector3i) -> ArrayMesh:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var origin := chunk * CHUNK_SIZE
	for z in range(CHUNK_SIZE):
		for y in range(CHUNK_SIZE):
			for x in range(CHUNK_SIZE):
				var cell := origin + Vector3i(x, y, z)
				var block_id := _block_at(cell)
				if block_id == BLOCK_AIR:
					continue
				for face in range(6):
					var neighbor := cell + Vector3i(FACE_NORMALS[face])
					var neighbor_id := _block_at(neighbor)
					if neighbor_id == block_id or (neighbor_id != BLOCK_AIR and block_id > neighbor_id):
						continue
					_append_face(vertices, normals, colors, cell, cell - origin, face, block_id, neighbor)
	if vertices.is_empty():
		return null
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _append_face(
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	colors: PackedColorArray,
	world_cell: Vector3i,
	local_cell: Vector3i,
	face: int,
	block_id: int,
	neighbor: Vector3i
) -> void:
	var corners := _face_corners(face)
	var level := _light_at(world_cell)
	# Lit air on the opposite side illuminates the face of an opaque voxel.
	if _inside_world(neighbor):
		level = maxi(level, _light_at(neighbor))
	var light_color := block_defs[block_id].albedo
	light_color.a = float(level) / float(LIGHT_RANGE)
	var normal: Vector3 = FACE_NORMALS[face]
	for corner_index in [0, 1, 2, 0, 2, 3]:
		vertices.append(Vector3(local_cell) + corners[corner_index])
		normals.append(normal)
		colors.append(light_color)

func _face_corners(face: int) -> PackedVector3Array:
	match face:
		0: return PackedVector3Array([Vector3(1, 0, 0), Vector3(1, 1, 0), Vector3(1, 1, 1), Vector3(1, 0, 1)])
		1: return PackedVector3Array([Vector3(0, 0, 1), Vector3(0, 1, 1), Vector3(0, 1, 0), Vector3(0, 0, 0)])
		2: return PackedVector3Array([Vector3(0, 1, 1), Vector3(1, 1, 1), Vector3(1, 1, 0), Vector3(0, 1, 0)])
		3: return PackedVector3Array([Vector3(0, 0, 0), Vector3(1, 0, 0), Vector3(1, 0, 1), Vector3(0, 0, 1)])
		4: return PackedVector3Array([Vector3(1, 0, 1), Vector3(1, 1, 1), Vector3(0, 1, 1), Vector3(0, 0, 1)])
		_: return PackedVector3Array([Vector3(0, 0, 0), Vector3(0, 1, 0), Vector3(1, 1, 0), Vector3(1, 0, 0)])


func _update_readout() -> void:
	if not is_instance_valid(readout):
		return
	var viewport_center := get_viewport().get_visible_rect().size * 0.5
	var ray_origin := camera.project_ray_origin(viewport_center)
	var ray_direction := camera.project_ray_normal(viewport_center)
	var hit := Vector3i(-1, -1, -1)
	var last_air := Vector3i(-1, -1, -1)
	for step_index in range(1, 301):
		var point := ray_origin + ray_direction * (float(step_index) * 0.1)
		var cell := Vector3i(floori(point.x), floori(point.y), floori(point.z))
		if not _inside_world(cell):
			break
		if _block_at(cell) != BLOCK_AIR:
			hit = cell
			break
		last_air = cell
	var sample_cell := last_air if _inside_world(last_air) else hit
	var block_label := "none"
	var level := 0
	var gloom := 0.0
	if _inside_world(sample_cell):
		block_label = String(block_defs[_block_at(sample_cell)].block_id)
		level = _light_at(sample_cell)
		gloom = float(gloom_levels[_index(sample_cell)])
	readout.text = "M0 LIGHT + DITHER | FPS %.0f | camera free\n" % Engine.get_frames_per_second()
	readout.text += "LIGHT_LEVEL %d | GLOOM_LEVEL %.2f | block %s at %s\n" % [level, gloom, block_label, str(sample_cell)]
	readout.text += "L: move static torch | flashlight follows camera | WASD move | Space/Ctrl fly | F HUD | Esc mouse"


func _set_block(cell: Vector3i, block_id: int) -> void:
	if _inside_world(cell):
		blocks[_index(cell)] = block_id


func _block_at(cell: Vector3i) -> int:
	if not _inside_world(cell):
		return BLOCK_TEST_WALL
	return blocks[_index(cell)]


func _light_at(cell: Vector3i) -> int:
	if not _inside_world(cell):
		return 0
	var chunk := Vector3i(floori(float(cell.x) / CHUNK_SIZE), floori(float(cell.y) / CHUNK_SIZE), floori(float(cell.z) / CHUNK_SIZE))
	var local := Vector3i(cell.x % CHUNK_SIZE, cell.y % CHUNK_SIZE, cell.z % CHUNK_SIZE)
	var core_cell_index := local.x + local.y * CHUNK_SIZE + local.z * CHUNK_SIZE * CHUNK_SIZE
	return chunk_light_buffers[_chunk_index(chunk)][core_cell_index]


func _chunk_index(chunk: Vector3i) -> int:
	return chunk.x + chunk.y * (WORLD_SIZE / CHUNK_SIZE) + chunk.z * (WORLD_SIZE / CHUNK_SIZE) * (WORLD_SIZE / CHUNK_SIZE)


func _padded_index(cell: Vector3i) -> int:
	return cell.x + cell.y * PADDED_SIZE + cell.z * PADDED_SIZE * PADDED_SIZE


func _padded_cell_from_index(cell_index: int) -> Vector3i:
	var z := int(cell_index / (PADDED_SIZE * PADDED_SIZE))
	var remainder := cell_index - z * PADDED_SIZE * PADDED_SIZE
	var y := int(remainder / PADDED_SIZE)
	var x := remainder - y * PADDED_SIZE
	return Vector3i(x, y, z)



func _inside_world(cell: Vector3i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.z >= 0 and cell.x < WORLD_SIZE and cell.y < WORLD_SIZE and cell.z < WORLD_SIZE


func _index(cell: Vector3i) -> int:
	return cell.x + cell.y * WORLD_SIZE + cell.z * WORLD_SIZE * WORLD_SIZE

















