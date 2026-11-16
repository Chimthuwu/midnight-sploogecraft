extends CanvasLayer
class_name GameHUD

const PANEL_BG := Color(0.035, 0.055, 0.07, 0.86)
const PANEL_BORDER := Color(0.24, 0.78, 0.70, 0.35)
const TEXT_PALE := Color(0.86, 0.95, 0.91)
const TEXT_DIM := Color(0.55, 0.72, 0.68)
const TEXT_WARN := Color(0.98, 0.82, 0.52)
const ACCENT_PROJECTOR := Color(0.15, 0.90, 1.0)
const RESERVE_SEGMENTS := 6

var player: VoxelPlayer
var caster: Lumencaster
var world: VoxelWorld

var debug_label: Label
var flashlight_label: Label
var loadout_panel: Panel
var accent_bar: ColorRect
var name_label: Label
var mode_label: Label
var build_label: Label
var reserve_label: Label
var reserve_segments: Array[ColorRect] = []
var cartridge_pips: Array[ColorRect] = []
var health_bar: ColorRect
var health_fill: ColorRect
var status_label: Label
var hint_panel: Panel
var hint_label: Label

var pause_overlay: Control
var pause_buttons: Array[Button] = []
var paused := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var main := get_parent()
	player = main.get_node_or_null("Player") as VoxelPlayer
	world = main.get_node_or_null("VoxelWorld") as VoxelWorld
	if player != null:
		caster = player.get_node_or_null("Lumencaster") as Lumencaster
	_build_status()
	_build_loadout()
	_build_health()
	_build_crosshair()
	_build_hint()
	_build_pause()
	_update_loadout()


func _process(_delta: float) -> void:
	if not is_instance_valid(caster) or not is_instance_valid(player):
		return
	_update_loadout()
	_update_health()
	_update_status()
	_update_hint()
	_update_flashlight()


# --- Construction -----------------------------------------------------------

func _style(bg: Color, border: Color, border_width := 1, radius := 4) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 10.0
	style.content_margin_right = 10.0
	style.content_margin_top = 6.0
	style.content_margin_bottom = 6.0
	return style


func _label(text: String, font_size: int, color: Color, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	label.horizontal_alignment = align
	return label


func _panel(rect: Rect2, style: StyleBoxFlat) -> Panel:
	var panel := Panel.new()
	panel.position = rect.position
	panel.size = rect.size
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	return panel


func _build_status() -> void:
	debug_label = _label("", 11, TEXT_PALE)
	debug_label.name = "DebugReadout"
	debug_label.position = Vector2(16, 8)
	debug_label.size = Vector2(822, 96)
	debug_label.visible = false
	add_child(debug_label)

	status_label = _label("", 12, TEXT_WARN, HORIZONTAL_ALIGNMENT_CENTER)
	status_label.name = "StatusLabel"
	status_label.position = Vector2(127, 346)
	status_label.size = Vector2(600, 18)
	status_label.visible = false
	add_child(status_label)

	flashlight_label = _label("FLASHLIGHT  ON", 9, TEXT_DIM, HORIZONTAL_ALIGNMENT_RIGHT)
	flashlight_label.name = "FlashlightState"
	flashlight_label.position = Vector2(600, 8)
	flashlight_label.size = Vector2(238, 12)
	add_child(flashlight_label)


func _build_loadout() -> void:
	loadout_panel = _panel(Rect2(16, 388, 252, 78), _style(PANEL_BG, PANEL_BORDER))
	loadout_panel.name = "LoadoutPanel"

	accent_bar = ColorRect.new()
	accent_bar.color = Color(0.25, 1.0, 0.78)
	accent_bar.position = Vector2(0, 0)
	accent_bar.size = Vector2(3, 78)
	accent_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	loadout_panel.add_child(accent_bar)

	name_label = _label("EXCAVATOR ROUND", 13, TEXT_PALE)
	name_label.name = "LumenReadout"
	name_label.position = Vector2(30, 393)
	name_label.size = Vector2(226, 18)
	add_child(name_label)

	mode_label = _label("LUMENCASTER", 9, TEXT_DIM)
	mode_label.position = Vector2(30, 412)
	mode_label.size = Vector2(226, 12)
	add_child(mode_label)

	for index in range(4):
		var pip := ColorRect.new()
		pip.position = Vector2(30 + index * 18, 430)
		pip.size = Vector2(14, 4)
		pip.color = Color(1, 1, 1, 0.25)
		pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(pip)
		cartridge_pips.append(pip)

	var reserve_caption := _label("LUMEN", 9, TEXT_DIM)
	reserve_caption.position = Vector2(30, 442)
	reserve_caption.size = Vector2(40, 12)
	add_child(reserve_caption)

	for index in range(RESERVE_SEGMENTS):
		var segment := ColorRect.new()
		segment.position = Vector2(74 + index * 14, 444)
		segment.size = Vector2(11, 5)
		segment.color = Color(0.05, 0.10, 0.09, 1.0)
		segment.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(segment)
		reserve_segments.append(segment)

	reserve_label = _label("100", 9, TEXT_DIM, HORIZONTAL_ALIGNMENT_RIGHT)
	reserve_label.position = Vector2(166, 440)
	reserve_label.size = Vector2(88, 12)
	add_child(reserve_label)

	build_label = _label("BUILD  CONCRETE ×0   DEPTH 1", 9, TEXT_DIM)
	build_label.position = Vector2(30, 454)
	build_label.size = Vector2(226, 12)
	add_child(build_label)


func _build_health() -> void:
	var caption := _label("VITALS", 8, TEXT_DIM)
	caption.position = Vector2(16, 360)
	caption.size = Vector2(80, 10)
	add_child(caption)

	var value := _label("100", 8, TEXT_DIM, HORIZONTAL_ALIGNMENT_RIGHT)
	value.name = "HealthValue"
	value.position = Vector2(188, 360)
	value.size = Vector2(80, 10)
	add_child(value)

	var background := ColorRect.new()
	background.position = Vector2(16, 375)
	background.size = Vector2(252, 5)
	background.color = Color(0.03, 0.05, 0.06, 0.9)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	health_fill = ColorRect.new()
	health_fill.position = Vector2(16, 375)
	health_fill.size = Vector2(252, 5)
	health_fill.color = Color(0.42, 0.85, 0.62, 0.95)
	health_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(health_fill)


func _build_crosshair() -> void:
	var crosshair := Control.new()
	crosshair.name = "Crosshair"
	crosshair.position = Vector2(421, 234)
	crosshair.size = Vector2(12, 12)
	crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(crosshair)
	var color := Color(0.98, 0.90, 0.72, 0.9)
	var dot := ColorRect.new()
	dot.position = Vector2(5, 5)
	dot.size = Vector2(2, 2)
	dot.color = color
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	crosshair.add_child(dot)
	var offsets := [Vector2(0, 5.5), Vector2(8, 5.5), Vector2(5.5, 0), Vector2(5.5, 8)]
	for index in range(4):
		var tick := ColorRect.new()
		tick.position = offsets[index]
		tick.size = Vector2(4, 1) if index < 2 else Vector2(1, 4)
		tick.color = color
		tick.mouse_filter = Control.MOUSE_FILTER_IGNORE
		crosshair.add_child(tick)


func _build_hint() -> void:
	hint_panel = _panel(Rect2(207, 190, 440, 96), _style(Color(0.03, 0.07, 0.09, 0.9), Color(0.22, 0.9, 0.85, 0.5), 1, 4))
	hint_panel.name = "HintPanel"
	hint_panel.visible = false

	hint_label = _label("", 11, Color(0.72, 0.96, 0.93), HORIZONTAL_ALIGNMENT_CENTER)
	hint_label.name = "ContextHint"
	hint_label.position = Vector2(219, 202)
	hint_label.size = Vector2(416, 72)
	hint_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hint_label.visible = false
	add_child(hint_label)


func _button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 11)
	button.add_theme_color_override("font_color", TEXT_PALE)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_stylebox_override("normal", _style(Color(0.07, 0.10, 0.12, 0.95), Color(0.2, 0.45, 0.42, 0.7), 1, 3))
	button.add_theme_stylebox_override("hover", _style(Color(0.10, 0.22, 0.21, 0.98), Color(0.3, 0.9, 0.78, 0.9), 1, 3))
	button.add_theme_stylebox_override("pressed", _style(Color(0.06, 0.15, 0.14, 1.0), ACCENT_PROJECTOR, 1, 3))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	return button


func _build_pause() -> void:
	pause_overlay = Control.new()
	pause_overlay.name = "PauseOverlay"
	pause_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pause_overlay.visible = false
	add_child(pause_overlay)

	var dim := ColorRect.new()
	dim.color = Color(0.015, 0.03, 0.04, 0.76)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pause_overlay.add_child(dim)

	var panel := Panel.new()
	panel.position = Vector2(197, 80)
	panel.size = Vector2(460, 320)
	panel.add_theme_stylebox_override("panel", _style(Color(0.035, 0.055, 0.07, 0.97), PANEL_BORDER, 1, 5))
	pause_overlay.add_child(panel)

	var title := _label("PAUSED", 26, TEXT_PALE)
	title.position = Vector2(24, 16)
	title.size = Vector2(300, 34)
	panel.add_child(title)

	var subtitle := _label("MIDNIGHT SPLOOGECRAFT  ·  NEON CITY", 9, TEXT_DIM)
	subtitle.position = Vector2(25, 48)
	subtitle.size = Vector2(300, 12)
	panel.add_child(subtitle)

	var header := _label("CONTROLS", 9, Color(0.35, 0.75, 0.68))
	header.position = Vector2(24, 72)
	header.size = Vector2(200, 12)
	panel.add_child(header)

	var left_controls := ["WASD      Move", "SHIFT     Sprint", "SPACE     Jump", "LMB       Fire", "WHEEL     Cycle cartridge", "T         Flashlight"]
	var right_controls := ["1–4       Select cartridge", "Q         Projector Mode", "E         Build material", "WHEEL     Build depth (drag)", "F         Debug readout", "ESC       Pause"]
	for index in range(left_controls.size()):
		var left := _label(left_controls[index], 10, TEXT_DIM)
		left.position = Vector2(24, 92 + index * 18)
		left.size = Vector2(210, 14)
		panel.add_child(left)
		var right := _label(right_controls[index], 10, TEXT_DIM)
		right.position = Vector2(240, 92 + index * 18)
		right.size = Vector2(200, 14)
		panel.add_child(right)

	var buttons := [
		["RESUME", "_on_resume_pressed"],
		["SAVE", "_on_save_pressed"],
		["LOAD", "_on_load_pressed"],
		["QUIT", "_on_quit_pressed"]
	]
	for index in range(buttons.size()):
		var button := _button(buttons[index][0])
		button.position = Vector2(24 + index * 108, 236)
		button.size = Vector2(100, 28)
		button.pressed.connect(Callable(self, buttons[index][1]))
		panel.add_child(button)
		pause_buttons.append(button)

	var footer := _label("ESC  Resume", 9, TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER)
	footer.position = Vector2(24, 276)
	footer.size = Vector2(412, 12)
	panel.add_child(footer)


# --- Live updates -----------------------------------------------------------

func _update_loadout() -> void:
	var cartridge: CartridgeDef = caster.CARTRIDGES[caster.selected_cartridge]
	var accent := ACCENT_PROJECTOR if caster.projector_mode else cartridge.accent_color
	name_label.text = cartridge.display_name
	mode_label.text = "PROJECTOR MODE" if caster.projector_mode else "LUMENCASTER"
	mode_label.add_theme_color_override("font_color", accent)
	accent_bar.color = accent

	for index in range(cartridge_pips.size()):
		var pip: ColorRect = cartridge_pips[index]
		var pip_color: Color = caster.CARTRIDGES[index].accent_color
		var selected := index == caster.selected_cartridge and not caster.projector_mode
		pip.color = Color(pip_color.r, pip_color.g, pip_color.b, 1.0 if selected else 0.28)
		pip.size = Vector2(14, 6) if selected else Vector2(14, 3)
		pip.position.y = 429 if selected else 431

	var ratio := clampf(caster.reserve / caster.CONFIG.reserve_capacity, 0.0, 1.0)
	var lit := 0 if ratio <= 0.001 else ceili(ratio * float(RESERVE_SEGMENTS))
	for index in range(reserve_segments.size()):
		var segment: ColorRect = reserve_segments[index]
		var on := index < lit
		segment.color = Color(0.25, 1.0, 0.78, 0.95) if on else Color(0.05, 0.10, 0.09, 1.0)
	reserve_label.text = "%d" % roundi(caster.reserve)
	reserve_label.add_theme_color_override("font_color", TEXT_WARN if ratio < 0.2 else TEXT_DIM)

	var stock := int(caster.inventory.get(caster.selected_projector_block, 0))
	var block_name := String(caster.selected_projector_block).replace("_", " ").to_upper()
	build_label.text = "BUILD  %s ×%d    DEPTH %d" % [block_name, stock, caster.extrusion_depth]
	build_label.add_theme_color_override("font_color", Color(0.95, 0.55, 0.45) if stock <= 0 else TEXT_DIM)


func _update_flashlight() -> void:
	var on := is_instance_valid(world) and world.flashlight_enabled
	flashlight_label.text = "FLASHLIGHT  ON" if on else "FLASHLIGHT  OFF"
	flashlight_label.add_theme_color_override("font_color", Color(0.55, 0.92, 0.78) if on else Color(0.42, 0.48, 0.48))


func _update_health() -> void:
	var ratio := clampf(player.health / 100.0, 0.0, 1.0)
	health_fill.size.x = 252.0 * ratio
	health_fill.color = Color(0.85, 0.38, 0.30, 0.95) if ratio < 0.35 else Color(0.42, 0.85, 0.62, 0.95)
	var value := get_node_or_null("HealthValue") as Label
	if value != null:
		value.text = "%d" % roundi(player.health)
		value.add_theme_color_override("font_color", Color(0.90, 0.45, 0.38) if ratio < 0.35 else TEXT_DIM)


func _update_status() -> void:
	var remaining: float = caster.status_time
	status_label.visible = remaining > 0.0
	if not status_label.visible:
		return
	status_label.text = caster.status_message
	status_label.modulate.a = clampf(remaining / 0.45, 0.0, 1.0)


func _update_hint() -> void:
	var active: bool = caster.hint_time > 0.0
	hint_panel.visible = active
	hint_label.visible = active
	if not active:
		return
	hint_label.text = caster.hint_text
	var fade := clampf(caster.hint_time / maxf(caster.hint_fade * 0.35, 0.001), 0.0, 1.0)
	hint_panel.modulate.a = fade
	hint_label.modulate.a = fade


# --- Pause ------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE):
		return
	if paused:
		resume_game()
	elif is_instance_valid(caster) and (caster.dragging or caster.projector_mode):
		return
	else:
		pause_game()
	get_viewport().set_input_as_handled()


func pause_game() -> void:
	paused = true
	pause_overlay.visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func resume_game() -> void:
	paused = false
	pause_overlay.visible = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _on_resume_pressed() -> void:
	resume_game()


func _on_save_pressed() -> void:
	if get_parent().has_method("save_game"):
		get_parent().save_game()


func _on_load_pressed() -> void:
	if get_parent().has_method("load_game"):
		get_parent().load_game()
	resume_game()


func _on_quit_pressed() -> void:
	get_tree().quit()
