extends Node3D
class_name Lumencaster

signal noise_emitted(world_position: Vector3, strength: float)
signal combat_hit(cell: Vector3i, damage: float, cartridge_id: StringName)
signal fired(cartridge_id: StringName, kick: float)
signal cartridge_changed(index: int, cartridge: CartridgeDef)
signal projector_toggled(active: bool)

const CARTRIDGES: Array[CartridgeDef] = [
	preload("res://data/cartridges/excavator.tres"),
	preload("res://data/cartridges/beacon.tres"),
	preload("res://data/cartridges/photon_slug.tres"),
	preload("res://data/cartridges/flare.tres")
]
const CONFIG: LumencasterConfig = preload("res://data/cartridges/lumencaster_config.tres")

var player: Node3D
var world: VoxelWorld
var camera: Camera3D

var preview: MeshInstance3D
var preview_material: StandardMaterial3D
var reserve := 0.0
var selected_cartridge := 0
var projector_mode := false
var selected_projector_block: StringName
var inventory: Dictionary = {}
var temporary_lights: Array[Dictionary] = []
var dragging := false
var drag_start := Vector3i.ZERO
var drag_end := Vector3i.ZERO
var drag_hit := Vector3i.ZERO
var drag_normal := Vector3i.ZERO
var extrusion_depth := 1
var preview_valid := false
var status_message := ""
var status_time := 0.0
var hint_text := ""
var hint_time := 0.0
var hint_fade := 0.0
var projectiles: Array[Dictionary] = []

func _ready() -> void:
	player = get_parent()
	world = player.get_parent().get_node("VoxelWorld") as VoxelWorld
	camera = player.get_node("Camera3D") as Camera3D
	reserve = CONFIG.starting_reserve
	selected_projector_block = CONFIG.projector_default_block
	_create_preview()

func _process(delta: float) -> void:
	if world.is_generated and player.get("spawned"):
		var player_cell := Vector3i(floori(player.position.x), floori(player.position.y), floori(player.position.z))
		var light_level := world.get_light_level(player_cell)
		if light_level > 0:
			reserve = minf(CONFIG.reserve_capacity, reserve + CONFIG.recharge_per_second_at_full_light * float(light_level) / 15.0 * delta)
	_update_temporary_lights(delta)
	if world.is_generated:
		_update_projectiles(delta)
	if projector_mode:
		if dragging:
			_update_projector_preview()
		else:
			preview.visible = false
	if status_time > 0.0:
		status_time -= delta
	else:
		status_message = ""
	if hint_time > 0.0:
		hint_time = maxf(0.0, hint_time - delta)

func _unhandled_input(event: InputEvent) -> void:
	if not world.is_generated:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode >= KEY_1 and event.keycode <= KEY_4:
			_select_cartridge(event.keycode - KEY_1)
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_Q:
			_set_projector_mode(not projector_mode)
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_ESCAPE:
			if dragging:
				_cancel_projector_drag()
				get_viewport().set_input_as_handled()
			elif projector_mode:
				_set_projector_mode(false)
				get_viewport().set_input_as_handled()
		elif event.keycode == KEY_E and projector_mode:
			_cycle_projector_block()
			get_viewport().set_input_as_handled()
	if event is InputEventMouseButton:
		if projector_mode and dragging and event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			extrusion_depth = mini(4, extrusion_depth + 1)
			get_viewport().set_input_as_handled()
			return
		if projector_mode and dragging and event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			extrusion_depth = maxi(1, extrusion_depth - 1)
			get_viewport().set_input_as_handled()
			return
		if not projector_mode and event.pressed:
			if event.is_action_pressed("cartridge_next"):
				_cycle_cartridge(1)
				get_viewport().set_input_as_handled()
				return
			if event.is_action_pressed("cartridge_prev"):
				_cycle_cartridge(-1)
				get_viewport().set_input_as_handled()
				return
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				if projector_mode:
					_begin_projector_drag()
				else:
					_fire_selected_cartridge()
				get_viewport().set_input_as_handled()
			elif projector_mode and dragging:
				_commit_projector()
				get_viewport().set_input_as_handled()

func _fire_selected_cartridge() -> void:
	var cartridge: CartridgeDef = CARTRIDGES[selected_cartridge]
	var player_cell := Vector3i(floori(player.position.x), floori(player.position.y), floori(player.position.z))
	var light_level := world.get_light_level(player_cell)
	if light_level < cartridge.minimum_light:
		_set_status("TOO DARK TO FIRE")
		return
	if reserve < cartridge.energy_cost:
		_set_status("LOW LUMEN RESERVE")
		return
	reserve -= cartridge.energy_cost
	fired.emit(cartridge.cartridge_id, _kick_for(cartridge))
	if cartridge.action == "flare":
		_fire_flare(cartridge)
	else:
		_fire_hitscan(cartridge)

func _kick_for(cartridge: CartridgeDef) -> float:
	match cartridge.action:
		"photon":
			return 0.62
		"flare":
			return 0.46
		"beacon":
			return 0.30
		_:
			return 0.38

# Photon Slug traces a beam, the Beacon plants a pulsing light, and the
# Excavator drills a short burst into whatever surface it hits.
func _fire_hitscan(cartridge: CartridgeDef) -> void:
	var direction := -camera.global_basis.z.normalized()
	var hit := _voxel_raycast(cartridge.range)
	var event_position: Vector3 = camera.global_position + direction * cartridge.range
	var impact_direction := Vector3.UP
	var impacted := false
	var enemy_hit := _enemy_raycast(cartridge.range)
	if not enemy_hit.is_empty() and (hit.is_empty() or float(enemy_hit["distance"]) < float(hit["distance"])):
		var enemy: GloomEnemy = enemy_hit["enemy"]
		event_position = enemy_hit["point"]
		impacted = true
		if cartridge.damage > 0.0:
			enemy.apply_damage(cartridge.damage)
			combat_hit.emit(Vector3i(floori(enemy.position.x), floori(enemy.position.y), floori(enemy.position.z)), cartridge.damage, cartridge.cartridge_id)
		hit = {}
	elif not hit.is_empty():
		event_position = hit["point"]
		impact_direction = Vector3(hit["face_normal"])
		impacted = true
		if cartridge.damage > 0.0:
			combat_hit.emit(hit["cell"], cartridge.damage, cartridge.cartridge_id)
	match cartridge.action:
		"excavate":
			if not hit.is_empty():
				_mine_burst(hit)
			else:
				_set_status("NO BLOCK IN RANGE")
		"beacon":
			if _place_temporary_light(cartridge, hit):
				var planted: Vector3i = hit["cell"] + hit["face_normal"]
				Vfx.pillar(world, Vector3(planted) + Vector3(0.5, 0.0, 0.5), cartridge.accent_color, 4.0, 1.4)
		"photon":
			Vfx.beam(world, camera.global_position + direction * 0.45, event_position, cartridge.accent_color, 0.05, 0.14, 8.0)
			_set_status("PHOTON BEAM HIT" if impacted else "PHOTON BEAM FIRED")
	if impacted:
		Vfx.burst(world, event_position, cartridge.accent_color, impact_direction, 12, 4.5, 0.05, 0.35)
	if cartridge.gloom_noise > 0.0:
		noise_emitted.emit(event_position, cartridge.gloom_noise)
		world.emit_gloom_noise(event_position, cartridge.gloom_noise)

# The Excavator burst removes up to three connected blocks along the impact axis.
func _mine_burst(hit: Dictionary) -> void:
	var normal: Vector3i = hit["face_normal"]
	var step := Vector3i(-normal.x, -normal.y, -normal.z)
	if step == Vector3i.ZERO:
		step = Vector3i.DOWN
	var cell: Vector3i = hit["cell"]
	var mined := 0
	var last_name: StringName = &""
	for depth in range(3):
		if not world._inside_world(cell):
			break
		var mined_id := world.get_block_id(cell)
		if mined_id == world.air_id or not world.set_block(cell, world.air_id):
			break
		last_name = world.block_defs[mined_id].block_id
		inventory[last_name] = int(inventory.get(last_name, 0)) + 1
		if int(inventory.get(selected_projector_block, 0)) == 0:
			selected_projector_block = last_name
		mined += 1
		cell += step
	if mined == 0:
		_set_status("NO BLOCK IN RANGE")
	elif mined == 1:
		_set_status("MINED %s" % String(last_name).to_upper())
	else:
		_set_status("DRILLED %d %s" % [mined, String(last_name).to_upper()])

func _fire_flare(cartridge: CartridgeDef) -> void:
	var direction := -camera.global_basis.z.normalized()
	var start := camera.global_position + direction * 0.55
	var body := Vfx.flare_projectile(world, start, cartridge.accent_color)
	if body == null:
		return
	projectiles.append({
		"node": body,
		"position": start,
		"velocity": direction * 16.0 + Vector3.UP * 2.2,
		"cartridge": cartridge,
		"life": 4.0
	})
	_set_status("FLARE AWAY")

# Flares arc under gravity and plant their temporary light where they land.
func _update_projectiles(delta: float) -> void:
	for index in range(projectiles.size() - 1, -1, -1):
		var shot: Dictionary = projectiles[index]
		var position: Vector3 = shot["position"]
		var velocity: Vector3 = shot["velocity"]
		shot["life"] = float(shot["life"]) - delta
		var landed := false
		var steps := 3
		var step_dt := delta / float(steps)
		for substep in range(steps):
			velocity.y -= 22.0 * step_dt
			var next := position + velocity * step_dt
			var cell := Vector3i(floori(next.x), floori(next.y), floori(next.z))
			if not world._inside_world(cell) or world.get_block_id(cell) != world.air_id:
				landed = true
				break
			position = next
		shot["position"] = position
		shot["velocity"] = velocity
		var node: Node3D = shot["node"]
		if is_instance_valid(node):
			node.global_position = position
		if landed or float(shot["life"]) <= 0.0:
			_land_flare(shot, position)
			if is_instance_valid(node):
				node.queue_free()
			projectiles.remove_at(index)

func _land_flare(shot: Dictionary, position: Vector3) -> void:
	var cartridge: CartridgeDef = shot["cartridge"]
	var cell := Vector3i(floori(position.x), floori(position.y), floori(position.z))
	var target := cell
	if not world._inside_world(target) or world.get_block_id(target) != world.air_id:
		target = cell + Vector3i.UP
	var torch_id: int = int(world.block_ids.get(cartridge.light_block_id, -1))
	if torch_id >= 0 and world._inside_world(target) and world.get_block_id(target) == world.air_id and world.set_block(target, torch_id):
		temporary_lights.append({"cell": target, "remaining": cartridge.duration})
		Vfx.pillar(world, Vector3(target) + Vector3(0.5, 0.0, 0.5), cartridge.accent_color, 2.5, 0.8, 0.16)
	Vfx.burst(world, position, cartridge.accent_color, Vector3.UP, 14, 5.0, 0.06, 0.45)
	if cartridge.damage > 0.0:
		for candidate in get_tree().get_nodes_in_group("enemies"):
			var enemy := candidate as GloomEnemy
			if enemy == null or not is_instance_valid(enemy):
				continue
			if enemy.global_position.distance_to(position) <= 1.8:
				enemy.apply_damage(cartridge.damage)
				combat_hit.emit(Vector3i(floori(enemy.position.x), floori(enemy.position.y), floori(enemy.position.z)), cartridge.damage, cartridge.cartridge_id)
	if cartridge.gloom_noise > 0.0:
		noise_emitted.emit(position, cartridge.gloom_noise)
		world.emit_gloom_noise(position, cartridge.gloom_noise)
	_set_status("FLARE LANDED")

func _enemy_raycast(max_distance: float) -> Dictionary:
	var origin := camera.global_position
	var direction := -camera.global_basis.z.normalized()
	var nearest := max_distance
	var result: Dictionary = {}
	for candidate in get_tree().get_nodes_in_group("enemies"):
		var enemy := candidate as GloomEnemy
		if enemy == null or not is_instance_valid(enemy):
			continue
		var center := enemy.global_position + Vector3.UP * 0.25
		var offset := center - origin
		var along := offset.dot(direction)
		if along < 0.0 or along > nearest:
			continue
		var closest := origin + direction * along
		if closest.distance_squared_to(center) > 0.45 * 0.45:
			continue
		nearest = along
		result = {"enemy": enemy, "point": closest, "distance": along}
	return result
func _place_temporary_light(cartridge: CartridgeDef, hit: Dictionary) -> bool:
	if hit.is_empty():
		_set_status("NO SURFACE IN RANGE")
		return false
	var cell: Vector3i = hit["cell"] + hit["face_normal"]
	if not world._inside_world(cell) or world.get_block_id(cell) != world.air_id:
		_set_status("NO ROOM FOR LIGHT")
		return false
	var torch_id: int = world.block_ids[cartridge.light_block_id]
	if not world.set_block(cell, torch_id):
		return false
	temporary_lights.append({"cell": cell, "remaining": cartridge.duration})
	_set_status("TEMPORARY LIGHT PLANTED")
	return true

func _update_temporary_lights(delta: float) -> void:
	for index in range(temporary_lights.size() - 1, -1, -1):
		temporary_lights[index]["remaining"] -= delta
		if temporary_lights[index]["remaining"] > 0.0:
			continue
		var cell: Vector3i = temporary_lights[index]["cell"]
		if world._inside_world(cell) and world.get_block_id(cell) == world.block_ids[CARTRIDGES[1].light_block_id]:
			world.set_block(cell, world.air_id)
		temporary_lights.remove_at(index)

func _voxel_raycast(max_distance: float) -> Dictionary:
	var origin := camera.global_position
	var direction := -camera.global_basis.z.normalized()
	var cell := Vector3i(floori(origin.x), floori(origin.y), floori(origin.z))
	var step := Vector3i(signf(direction.x), signf(direction.y), signf(direction.z))
	var t_delta := Vector3(INF, INF, INF)
	var t_max := Vector3(INF, INF, INF)
	for axis in range(3):
		if absf(direction[axis]) < 0.000001:
			continue
		t_delta[axis] = absf(1.0 / direction[axis])
		var boundary := float(cell[axis] + (1 if step[axis] > 0 else 0))
		t_max[axis] = (boundary - origin[axis]) / direction[axis]
	var previous := cell
	var face_normal := Vector3i.ZERO
	var distance := 0.0
	while distance <= max_distance:
		if not world._inside_world(cell):
			return {}
		var block_id := world.get_block_id(cell)
		if block_id != world.air_id:
			return {"cell": cell, "previous_air": previous, "face_normal": face_normal, "point": origin + direction * distance, "distance": distance}
		previous = cell
		var axis := 0
		if t_max.y < t_max.x:
			axis = 1
		if t_max.z < t_max[axis]:
			axis = 2
		distance = t_max[axis]
		if distance > max_distance:
			break
		cell[axis] += step[axis]
		face_normal = Vector3i.ZERO
		face_normal[axis] = -step[axis]
		t_max[axis] += t_delta[axis]
	return {}

func _create_preview() -> void:
	preview = MeshInstance3D.new()
	preview.mesh = _wire_box_mesh(Vector3.ONE)
	preview_material = StandardMaterial3D.new()
	preview_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	preview_material.no_depth_test = true
	preview_material.albedo_color = Color(0.15, 0.9, 1.0, 1.0)
	preview_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	preview.material_override = preview_material
	preview.visible = false
	world.add_child(preview)

func _wire_box_mesh(size: Vector3) -> ArrayMesh:
	var half := size * 0.5
	var corners: Array[Vector3] = [
		Vector3(-half.x, -half.y, -half.z), Vector3(half.x, -half.y, -half.z),
		Vector3(half.x, half.y, -half.z), Vector3(-half.x, half.y, -half.z),
		Vector3(-half.x, -half.y, half.z), Vector3(half.x, -half.y, half.z),
		Vector3(half.x, half.y, half.z), Vector3(-half.x, half.y, half.z)
	]
	var edges: Array[Vector2i] = [Vector2i(0, 1), Vector2i(1, 2), Vector2i(2, 3), Vector2i(3, 0), Vector2i(4, 5), Vector2i(5, 6), Vector2i(6, 7), Vector2i(7, 4), Vector2i(0, 4), Vector2i(1, 5), Vector2i(2, 6), Vector2i(3, 7)]
	var vertices := PackedVector3Array()
	for edge in edges:
		vertices.append(corners[edge.x])
		vertices.append(corners[edge.y])
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, arrays)
	return mesh
func _begin_projector_drag() -> void:
	var hit := _voxel_raycast(8.0)
	if hit.is_empty():
		_set_status("AIM AT A SURFACE")
		return
	dragging = true
	drag_hit = hit["cell"]
	drag_normal = hit["face_normal"]
	var hit_point: Vector3 = hit["point"]
	drag_start = Vector3i(floori(hit_point.x), floori(hit_point.y), floori(hit_point.z))
	drag_end = drag_start
	extrusion_depth = 1
	_update_projector_preview()

func _update_projector_preview() -> void:
	preview_valid = false
	if not dragging:
		preview.visible = false
		return
	var normal_axis := _normal_axis(drag_normal)
	var origin := camera.global_position
	var direction := -camera.global_basis.z.normalized()
	if absf(direction[normal_axis]) < 0.0001:
		preview.visible = false
		return
	var plane := float(drag_hit[normal_axis] + (1 if drag_normal[normal_axis] > 0 else 0))
	var distance := (plane - origin[normal_axis]) / direction[normal_axis]
	if distance < 0.0 or distance > 8.0:
		preview.visible = false
		return
	var point := origin + direction * distance
	drag_end = Vector3i(floori(point.x), floori(point.y), floori(point.z))
	var u_axis := (normal_axis + 1) % 3
	var v_axis := (normal_axis + 2) % 3
	drag_end[u_axis] = clampi(drag_end[u_axis], drag_start[u_axis] - 3, drag_start[u_axis] + 3)
	drag_end[v_axis] = clampi(drag_end[v_axis], drag_start[v_axis] - 3, drag_start[v_axis] + 3)
	var cells := _projector_cells()
	if cells.is_empty():
		preview.visible = false
		return
	var low := cells[0]
	var high := cells[0]
	var valid := int(inventory.get(selected_projector_block, 0)) >= cells.size()
	valid = valid and reserve >= float(cells.size()) * CONFIG.lumen_cost_per_projector_block
	for cell in cells:
		low = Vector3i(mini(low.x, cell.x), mini(low.y, cell.y), mini(low.z, cell.z))
		high = Vector3i(maxi(high.x, cell.x), maxi(high.y, cell.y), maxi(high.z, cell.z))
		if not world._inside_world(cell) or world.get_block_id(cell) != world.air_id or player.call("_player_overlaps_cell", cell):
			valid = false
	var size := Vector3(high - low + Vector3i.ONE)
	preview.mesh = _wire_box_mesh(size)
	preview.position = Vector3(low) + size * 0.5
	preview_material.albedo_color = Color(0.15, 0.9, 1.0, 1.0) if valid else Color(1.0, 0.2, 0.12, 1.0)
	preview_valid = valid
	preview.visible = true

func _projector_cells() -> Array[Vector3i]:
	var cells: Array[Vector3i] = []
	var normal_axis := _normal_axis(drag_normal)
	var u_axis := (normal_axis + 1) % 3
	var v_axis := (normal_axis + 2) % 3
	var low_u := mini(drag_start[u_axis], drag_end[u_axis])
	var high_u := maxi(drag_start[u_axis], drag_end[u_axis])
	var low_v := mini(drag_start[v_axis], drag_end[v_axis])
	var high_v := maxi(drag_start[v_axis], drag_end[v_axis])
	for depth in range(1, extrusion_depth + 1):
		for v in range(low_v, high_v + 1):
			for u in range(low_u, high_u + 1):
				var cell := drag_hit
				cell[normal_axis] += drag_normal[normal_axis] * depth
				cell[u_axis] = u
				cell[v_axis] = v
				cells.append(cell)
	return cells

func _commit_projector() -> void:
	_update_projector_preview()
	dragging = false
	preview.visible = false
	if not preview_valid:
		_set_status("PROJECTOR NEEDS CLEAR SPACE, BLOCKS, AND LUMEN")
		return
	var cells := _projector_cells()
	var block_id: int = world.block_ids.get(selected_projector_block, -1)
	if block_id < 0 or int(inventory.get(selected_projector_block, 0)) < cells.size():
		_set_status("NOT ENOUGH BLOCKS")
		return
	var spent := float(cells.size()) * CONFIG.lumen_cost_per_projector_block
	if reserve < spent:
		_set_status("NOT ENOUGH LUMEN")
		return
	reserve -= spent
	inventory[selected_projector_block] -= cells.size()
	for cell in cells:
		world.set_block(cell, block_id)
	_set_status("PROJECTOR BUILT %d BLOCKS" % cells.size())

func _cycle_projector_block() -> void:
	var available: Array[StringName] = []
	for block_name in inventory:
		if int(inventory[block_name]) > 0 and world.block_ids.has(block_name):
			available.append(block_name)
	available.sort()
	if available.is_empty():
		_set_status("MINE BLOCKS FIRST")
		return
	var current := available.find(selected_projector_block)
	selected_projector_block = available[(current + 1) % available.size()]
	_set_status("BUILD MATERIAL: %s" % String(selected_projector_block).to_upper())

func _normal_axis(normal: Vector3i) -> int:
	if normal.x != 0:
		return 0
	if normal.y != 0:
		return 1
	return 2

func _select_cartridge(index: int) -> void:
	selected_cartridge = posmod(index, CARTRIDGES.size())
	var cartridge: CartridgeDef = CARTRIDGES[selected_cartridge]
	cartridge_changed.emit(selected_cartridge, cartridge)

func _cycle_cartridge(direction: int) -> void:
	_select_cartridge(selected_cartridge + direction)

func _set_projector_mode(active: bool) -> void:
	projector_mode = active
	dragging = false
	preview.visible = false
	projector_toggled.emit(projector_mode)
	if projector_mode:
		_show_hint("PROJECTOR MODE\nLMB DRAG to build   E material   WHEEL depth\nQ or ESC to exit", 6.0)
	else:
		hint_time = 0.0

func _cancel_projector_drag() -> void:
	dragging = false
	preview.visible = false
	_set_status("PROJECTOR CANCELLED")

func _show_hint(text: String, duration: float) -> void:
	hint_text = text
	hint_time = duration
	hint_fade = duration

func _set_status(message: String) -> void:
	status_message = message
	status_time = 2.0

