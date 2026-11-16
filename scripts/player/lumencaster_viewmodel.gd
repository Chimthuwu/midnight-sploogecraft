extends Node3D
class_name LumencasterViewmodel

const CONFIG: LumencasterConfig = preload("res://data/cartridges/lumencaster_config.tres")
const SEGMENT_COUNT := 6

@onready var world: VoxelWorld = owner.get_node_or_null("VoxelWorld") as VoxelWorld

var caster: Lumencaster
var body_material: StandardMaterial3D
var segment_materials: Array[StandardMaterial3D] = []
var muzzle_flash: MeshInstance3D
var flash_material: StandardMaterial3D
var indicator_material: StandardMaterial3D
var cartridge_stripe: MeshInstance3D
var muzzle_ring: MeshInstance3D
var base_position := Vector3.ZERO
var base_rotation := Vector3.ZERO
var recoil := 0.0
var flash_time := 0.0


func _ready() -> void:
	base_position = position
	base_rotation = rotation
	caster = get_parent().get_parent().get_node_or_null("Lumencaster") as Lumencaster
	if caster != null:
		caster.fired.connect(_on_fired)
		caster.cartridge_changed.connect(_on_cartridge_changed)
		caster.projector_toggled.connect(_on_projector_toggled)
	_build_model()
	if caster != null:
		_apply_cartridge(caster.CARTRIDGES[caster.selected_cartridge], caster.projector_mode)


func _build_model() -> void:
	body_material = _make_material(Color(0.21, 0.24, 0.28))
	var dark := _make_material(Color(0.11, 0.12, 0.14))
	var mid := _make_material(Color(0.33, 0.36, 0.40))
	var glove := _make_material(Color(0.20, 0.22, 0.25))
	_add_box("Body", Vector3(0.13, 0.12, 0.42), Vector3.ZERO, body_material)
	_add_box("Shroud", Vector3(0.085, 0.07, 0.20), Vector3(0, 0.02, -0.24), mid)
	_add_box("Barrel", Vector3(0.06, 0.06, 0.28), Vector3(0, 0.02, -0.34), mid)
	_add_box("Muzzle", Vector3(0.10, 0.10, 0.05), Vector3(0, 0.02, -0.50), dark)
	_add_box("Grip", Vector3(0.07, 0.17, 0.10), Vector3(0, -0.13, 0.11), dark, Vector3(-0.25, 0, 0))
	_add_box("Magazine", Vector3(0.055, 0.13, 0.10), Vector3(0, -0.15, -0.06), mid, Vector3(0.18, 0, 0))
	_add_box("Sight", Vector3(0.03, 0.05, 0.04), Vector3(0, 0.09, -0.12), mid)
	_add_box("Hand", Vector3(0.085, 0.105, 0.13), Vector3(0.005, -0.12, 0.075), glove, Vector3(-0.20, 0, 0))
	_add_box("Thumb", Vector3(0.030, 0.070, 0.10), Vector3(-0.045, -0.055, 0.095), glove, Vector3(-0.35, 0.15, 0.15))
	indicator_material = _make_indicator_material()
	cartridge_stripe = _add_box("CartridgeStripe", Vector3(0.045, 0.012, 0.17), Vector3(0, 0.062, -0.06), indicator_material)
	muzzle_ring = _add_box("MuzzleRing", Vector3(0.056, 0.056, 0.008), Vector3(0, 0.02, -0.526), indicator_material)
	_add_box("MuzzleBore", Vector3(0.050, 0.050, 0.010), Vector3(0, 0.02, -0.533), dark)
	for index in range(SEGMENT_COUNT):
		var material := _make_glow_material()
		segment_materials.append(material)
		_add_box("LumenCell%d" % index, Vector3(0.012, 0.022, 0.035), Vector3(-0.068, 0.02, -0.13 + index * 0.052), material)
	flash_material = _make_flash_material()
	muzzle_flash = _add_sphere("MuzzleFlash", 0.105, Vector3(0, 0.02, -0.55), flash_material)
	muzzle_flash.visible = false


func _add_box(node_name: String, size: Vector3, offset: Vector3, material: Material, box_rotation := Vector3.ZERO) -> MeshInstance3D:
	var box := BoxMesh.new()
	box.size = size
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = box
	instance.material_override = material
	instance.position = offset
	instance.rotation = box_rotation
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)
	return instance


func _add_sphere(node_name: String, radius: float, offset: Vector3, material: Material) -> MeshInstance3D:
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	sphere.radial_segments = 12
	sphere.rings = 6
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = sphere
	instance.material_override = material
	instance.position = offset
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)
	return instance


func _make_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	return material


func _make_glow_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(0.05, 0.16, 0.13)
	material.emission_enabled = true
	material.emission = Color(0.25, 1.0, 0.78)
	material.emission_energy_multiplier = 1.4
	return material


func _make_indicator_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(0.2, 0.9, 0.7)
	material.emission_enabled = true
	material.emission = Color(0.25, 1.0, 0.78)
	material.emission_energy_multiplier = 1.2
	return material


func _apply_cartridge(cartridge: CartridgeDef, projector: bool) -> void:
	if indicator_material == null:
		return
	var tint := Color(0.15, 0.9, 1.0) if projector else cartridge.accent_color
	indicator_material.albedo_color = tint
	indicator_material.emission = tint
	indicator_material.emission_energy_multiplier = 1.6 if projector else 1.1
	if cartridge_stripe != null:
		cartridge_stripe.visible = not projector
	if muzzle_ring != null:
		muzzle_ring.visible = true
	if flash_material != null:
		flash_material.emission = tint.lerp(Color.WHITE, 0.45)
		flash_material.albedo_color = tint.lerp(Color.WHITE, 0.65)


func _make_flash_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(1.0, 0.97, 0.80)
	material.emission_enabled = true
	material.emission = Color(1.0, 0.86, 0.48)
	material.emission_energy_multiplier = 9.0
	return material


func _process(delta: float) -> void:
	var ratio := 0.0
	if is_instance_valid(caster):
		ratio = clampf(caster.reserve / CONFIG.reserve_capacity, 0.0, 1.0)
	_update_reserve_cells(ratio)
	_update_body_light()
	recoil = lerpf(recoil, 0.0, 1.0 - exp(-delta * 11.0))
	flash_time = maxf(0.0, flash_time - delta)
	if muzzle_flash != null:
		muzzle_flash.visible = flash_time > 0.0
	var shake := sin(float(Time.get_ticks_msec()) * 0.045) * recoil * 0.02
	position = base_position + Vector3(0.0, recoil * 0.018, recoil * 0.07)
	rotation = base_rotation + Vector3(recoil * 0.22, shake, 0.0)


func _update_reserve_cells(ratio: float) -> void:
	var lit := 0 if ratio <= 0.001 else ceili(ratio * float(SEGMENT_COUNT))
	for index in range(segment_materials.size()):
		var material := segment_materials[index]
		var on := index < lit
		material.albedo_color = Color(0.30, 1.0, 0.80) if on else Color(0.03, 0.07, 0.06)
		material.emission_energy_multiplier = 2.2 if on else 0.0


func _update_body_light() -> void:
	if body_material == null or world == null or not world.is_generated:
		return
	var camera := get_parent() as Camera3D
	if camera == null:
		return
	var cell := Vector3i(floori(camera.global_position.x), floori(camera.global_position.y), floori(camera.global_position.z))
	var light := clampf(maxf(float(world.get_light_level(cell)) / 15.0, world.get_flashlight_level_at(camera.global_position)), 0.0, 1.0)
	body_material.albedo_color = Color(0.05, 0.06, 0.07).lerp(Color(0.40, 0.43, 0.45), light)


func _on_cartridge_changed(_index: int, cartridge: CartridgeDef) -> void:
	_apply_cartridge(cartridge, false)


func _on_projector_toggled(active: bool) -> void:
	if caster == null or indicator_material == null:
		return
	_apply_cartridge(caster.CARTRIDGES[caster.selected_cartridge], active)


func _on_fired(_cartridge_id: StringName, kick: float) -> void:
	recoil = minf(1.25, recoil + kick * 1.25)
	flash_time = 0.07
	if muzzle_flash != null:
		muzzle_flash.scale = Vector3.ONE * randf_range(0.95, 1.35)
