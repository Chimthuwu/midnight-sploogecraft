extends Node
class_name StreetProps

# Street-level set dressing using normalized meshes extracted from the free city
# prop pack. Vehicles and buildings stay blocks/meshes; these are quiet details
# that make the sidewalks feel inhabited.
const MODEL_SCENES := [
	preload("res://assets/props/free_city/garbageBin.glb"),
	preload("res://assets/props/free_city/bench2.glb"),
	preload("res://assets/props/free_city/fireHydrant.glb"),
	preload("res://assets/props/free_city/trashBag1.glb"),
	preload("res://assets/props/free_city/trafficCone.glb")
]
const TARGET_HEIGHTS := [1.3, 0.9, 1.5, 0.8, 1.2]
const PROP_COLORS := [
	Color(0.26, 0.27, 0.29), Color(0.22, 0.20, 0.17), Color(0.32, 0.14, 0.11),
	Color(0.20, 0.18, 0.16), Color(0.34, 0.27, 0.12)
]

var world: VoxelWorld
var spawned := false
var prop_materials: Array[StandardMaterial3D] = []

func _ready() -> void:
	world = get_parent().get_node("VoxelWorld") as VoxelWorld
	for color in PROP_COLORS:
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.albedo_color = color
		prop_materials.append(material)

func _process(_delta: float) -> void:
	if spawned or world == null or not world.is_generated:
		return
	spawned = true
	_scatter()


func _scatter() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = world.world_seed + 991
	var root := Node3D.new()
	root.name = "StreetProps"
	add_child(root)
	var placed := 0
	for x in range(3, 125, 3):
		for z in range(3, 125, 3):
			if not WorldGenerator._is_sidewalk(x, z):
				continue
			if rng.randf() > 0.22:
				continue
			var index := rng.randi_range(0, MODEL_SCENES.size() - 1)
			var prop := _make_prop(index)
			if prop == null:
				continue
			prop.position = Vector3(float(x) + 0.5, float(WorldGenerator.CITY_GROUND) + 1.0, float(z) + 0.5)
			prop.rotation.y = rng.randf_range(0.0, TAU)
			root.add_child(prop)
			placed += 1
	print("CITY street props placed=%d" % placed)


func _make_prop(index: int) -> Node3D:
	var scene := MODEL_SCENES[index] as PackedScene
	if scene == null:
		return null
	var instance := scene.instantiate()
	var meshes: Array = []
	_collect_meshes(instance, meshes)
	if meshes.is_empty():
		instance.free()
		return null
	var combined := AABB(Vector3.ZERO, Vector3.ZERO)
	var first := true
	for child in meshes:
		var source := child as MeshInstance3D
		if source == null or source.mesh == null:
			continue
		var box: AABB = source.transform * source.mesh.get_aabb()
		if first:
			combined = box
			first = false
		else:
			combined = combined.merge(box)
	if first or combined.size.y <= 0.01:
		instance.free()
		return null
	var factor: float = TARGET_HEIGHTS[index] / combined.size.y
	var anchor := Vector3(combined.get_center().x, combined.position.y, combined.get_center().z)
	var holder := Node3D.new()
	for child in meshes:
		var source := child as MeshInstance3D
		if source == null or source.mesh == null:
			continue
		var mesh_instance := MeshInstance3D.new()
		mesh_instance.mesh = source.mesh
		mesh_instance.scale = Vector3(factor, factor, factor)
		mesh_instance.material_override = prop_materials[index % prop_materials.size()]
		mesh_instance.position = (source.transform.origin - anchor) * factor
		mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		holder.add_child(mesh_instance)
	instance.free()
	return holder


func _collect_meshes(node: Node, result: Array) -> void:
	if node is MeshInstance3D:
		result.append(node)
	for child in node.get_children():
		_collect_meshes(child, result)
