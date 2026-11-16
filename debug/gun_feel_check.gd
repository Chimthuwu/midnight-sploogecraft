extends SceneTree

var main: Node
var failures := 0


func _initialize() -> void:
	main = load("res://scenes/world/main.tscn").instantiate()
	root.add_child(main)
	_run.call_deferred()


func _check(condition: bool, label: String, detail := "") -> void:
	if not condition:
		failures += 1
		push_error("GUN FEEL CHECK FAIL: %s %s" % [label, detail])
		return
	print("GUN FEEL PASS: %s %s" % [label, detail])


func _wheel(button: int) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame


func _key(code: int) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame


func _run() -> void:
	while not main.world.is_generated or not main.player.spawned:
		await process_frame
	var caster: Lumencaster = main.get_node("Player/Lumencaster") as Lumencaster
	var viewmodel: LumencasterViewmodel = main.get_node("Player/Camera3D/Viewmodel") as LumencasterViewmodel
	var hint: Label = main.get_node("HUD/ContextHint") as Label

	var hud: Label = main.get_node("HUD/LumenReadout") as Label
	var status_label: Label = main.get_node("HUD/StatusLabel") as Label
	var debug_label: Label = main.get_node("HUD/DebugReadout") as Label
	_check(not debug_label.visible, "debug readout starts hidden")
	var loadout_panel: Panel = main.get_node("HUD/LoadoutPanel") as Panel
	_check(loadout_panel.position.x < 100.0 and loadout_panel.position.y > 300.0, "loadout card is parked bottom-left", str(loadout_panel.position))

	_check(InputMap.has_action("cartridge_next") and InputMap.has_action("cartridge_prev"), "cartridge wheel actions exist")
	var next_events := InputMap.action_get_events("cartridge_next")
	var prev_events := InputMap.action_get_events("cartridge_prev")
	_check(next_events.size() == 1 and next_events[0] is InputEventMouseButton and (next_events[0] as InputEventMouseButton).button_index == MOUSE_BUTTON_WHEEL_DOWN, "wheel down cycles forward")
	_check(prev_events.size() == 1 and prev_events[0] is InputEventMouseButton and (prev_events[0] as InputEventMouseButton).button_index == MOUSE_BUTTON_WHEEL_UP, "wheel up cycles backward")

	var accents: Array[Color] = []
	for cartridge in Lumencaster.CARTRIDGES:
		accents.append(cartridge.accent_color)
	_check(accents.size() == 4 and accents[0] != accents[1] and accents[1] != accents[2] and accents[2] != accents[3], "each cartridge has a distinct accent", str(accents))

	var changed: Array = []
	caster.cartridge_changed.connect(func(index: int, cartridge: CartridgeDef) -> void: changed.append([index, cartridge.cartridge_id]))
	caster._select_cartridge(0)
	await process_frame
	_check(caster.selected_cartridge == 0, "starts on the excavator round")
	await _wheel(MOUSE_BUTTON_WHEEL_DOWN)
	_check(caster.selected_cartridge == 1, "wheel down selects next cartridge", "index=%d" % caster.selected_cartridge)
	_check(not changed.is_empty() and changed[-1][1] == &"beacon", "cartridge_changed emitted for the wheel pick")
	await _wheel(MOUSE_BUTTON_WHEEL_UP)
	_check(caster.selected_cartridge == 0, "wheel up selects previous cartridge", "index=%d" % caster.selected_cartridge)
	await _wheel(MOUSE_BUTTON_WHEEL_UP)
	_check(caster.selected_cartridge == 3, "wheel wraps past the first cartridge", "index=%d" % caster.selected_cartridge)
	await _wheel(MOUSE_BUTTON_WHEEL_DOWN)
	_check(caster.selected_cartridge == 0, "wheel wraps past the last cartridge", "index=%d" % caster.selected_cartridge)
	var accent_ok := viewmodel.indicator_material.emission.is_equal_approx(Lumencaster.CARTRIDGES[0].accent_color)
	_check(accent_ok, "viewmodel indicator matches the selected cartridge", str(viewmodel.indicator_material.emission))

	caster._set_projector_mode(true)
	await process_frame
	_check(caster.projector_mode, "projector mode toggles on")
	var hint_text := hint.text
	_check(hint.visible and hint_text.find("PROJECTOR MODE") != -1 and hint_text.find("WHEEL depth") != -1, "projector hint overlay is shown", hint_text.replace("\n", " / "))
	_check(viewmodel.indicator_material.emission.is_equal_approx(Color(0.15, 0.9, 1.0)), "viewmodel indicator switches to projector cyan")
	var index_before: int = caster.selected_cartridge
	await _wheel(MOUSE_BUTTON_WHEEL_DOWN)
	_check(caster.selected_cartridge == index_before, "wheel does not cycle cartridges in projector mode")
	caster._set_projector_mode(false)
	await process_frame
	_check(not hint.visible, "projector hint hides when leaving projector mode")

	caster.dragging = true
	caster.preview.visible = true
	await _key(KEY_ESCAPE)
	_check(not caster.dragging and not caster.preview.visible, "escape cancels an active projector drag")
	caster._set_projector_mode(true)
	await process_frame
	await _key(KEY_ESCAPE)
	_check(not caster.projector_mode, "escape leaves projector mode when not dragging")

	caster._select_cartridge(0)
	await process_frame
	var kicks: Array = []
	caster.fired.connect(func(_id: StringName, kick: float) -> void: kicks.append(kick))
	caster._fire_selected_cartridge()
	await process_frame
	_check(not kicks.is_empty() and float(kicks[-1]) > 0.0, "firing emits a kick", str(kicks))
	_check(viewmodel.recoil > 0.5 or viewmodel.flash_time > 0.0, "viewmodel recoil and flash react to firing")
	_check(hud.text.find("EXCAVATOR") != -1 and hud.text.find("NO BLOCK") == -1, "cartridge readout keeps only the loadout", hud.text)
	_check(status_label.text != "" and hud.text.find(status_label.text) == -1, "status is shown separately from the loadout", status_label.text)

	# --- distinct cartridge behaviours ---
	var air_id: int = caster.world.air_id
	var stone_id: int = caster.world.block_ids[&"stone"]
	var torch_id: int = caster.world.block_ids[&"torch"]
	var camera: Camera3D = main.get_node("Player/Camera3D") as Camera3D
	var base := Vector3i(floori(camera.global_position.x) + 6, 46, floori(camera.global_position.z) + 6)

	# Excavator: a short burst drills three cells along the impact axis.
	for depth in range(3):
		caster.world.set_block(base - Vector3i(0, depth, 0), stone_id)
	caster._select_cartridge(0)
	await process_frame
	var stone_before := int(caster.inventory.get(&"stone", 0))
	caster._mine_burst({"cell": base, "face_normal": Vector3i.UP})
	var drilled := true
	for depth in range(3):
		drilled = drilled and caster.world.get_block_id(base - Vector3i(0, depth, 0)) == air_id
	_check(drilled, "excavator burst drills three blocks")
	_check(int(caster.inventory.get(&"stone", 0)) == stone_before + 3, "excavator burst banks every drilled block")

	# Photon: an instant beam tracer is spawned from the muzzle.
	caster._select_cartridge(2)
	await process_frame
	var children_before := caster.world.get_child_count()
	caster._fire_selected_cartridge()
	await process_frame
	_check(caster.world.get_child_count() > children_before, "photon slug spawns a beam tracer")
	_check(caster._kick_for(Lumencaster.CARTRIDGES[2]) > caster._kick_for(Lumencaster.CARTRIDGES[1]), "photon kick is stronger than beacon kick")

	# Beacon: plants a lasting temporary light on the aimed face.
	caster._select_cartridge(1)
	await process_frame
	var wall_cell := base + Vector3i(0, 0, 4)
	caster.world.set_block(wall_cell, stone_id)
	caster.world.set_block(wall_cell + Vector3i.UP, air_id)
	var lights_before := caster.temporary_lights.size()
	var planted := caster._place_temporary_light(Lumencaster.CARTRIDGES[1], {"cell": wall_cell, "face_normal": Vector3i.UP})
	_check(planted and caster.world.get_block_id(wall_cell + Vector3i.UP) == torch_id and caster.temporary_lights.size() == lights_before + 1, "beacon plants a temporary light")

	# Flare: launches a gravity projectile, and landing plants its own light.
	caster._select_cartridge(3)
	await process_frame
	caster._fire_flare(Lumencaster.CARTRIDGES[3])
	_check(caster.projectiles.size() == 1, "flare launches an arcing projectile")
	var landing := base + Vector3i(-5, 0, 0)
	caster.world.set_block(landing, air_id)
	var flare_lights := caster.temporary_lights.size()
	caster._land_flare({"cartridge": Lumencaster.CARTRIDGES[3]}, Vector3(landing) + Vector3(0.5, 0.5, 0.5))
	_check(caster.world.get_block_id(landing) == torch_id and caster.temporary_lights.size() == flare_lights + 1, "flare plants its light where it lands")
	var steps := 0
	while not caster.projectiles.is_empty() and steps < 400:
		caster._update_projectiles(1.0 / 60.0)
		steps += 1
	_check(caster.projectiles.is_empty(), "flare projectile lands and clears itself", "steps=%d" % steps)

	var game_hud: GameHUD = main.get_node("HUD") as GameHUD
	game_hud.pause_game()
	await process_frame
	_check(game_hud.paused and paused and game_hud.pause_overlay.visible, "pause overlay opens")
	game_hud.resume_game()
	await process_frame
	_check(not game_hud.paused and not paused and not game_hud.pause_overlay.visible, "pause overlay resumes")

	if failures > 0:
		quit(1)
		return
	print("GUN FEEL CHECK PASS: wheel cycling, indicator, hint overlay, escape cancel, fire feedback, distinct cartridge behaviours")
	quit(0)
