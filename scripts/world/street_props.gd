extends Node
class_name StreetProps

# Street-level set dressing using normalized meshes extracted from the free city
# prop pack. Vehicles and buildings stay blocks/meshes; these are quiet details
# that make the sidewalks feel inhabited.
const MODEL_SCENES := [
	preload("res://assets/props/free_city/tree2.glb"),
	preload("res://assets/props/free_city/tree6.glb"),
	preload("res://assets/props/free_city/garbageBin.glb"),
	preload("res://assets/props/free_city/bench2.glb"),
	preload("res://assets/props/free_city/fireHydrant.glb"),
	preload("res://assets/props/free_city/trashBag1.glb"),
	preload("res://assets/props/free_city/trafficCone.glb")
]
const TARGET_HEIGHTS := [5.0, 5.6, 1.3, 0.9, 1.5, 0.8, 1.2]

var world: VoxelWorld
var spawned := false

func _ready() -> void:
	world = get_parent().get_node("VoxelWorld") as VoxelWorld

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
	var source := _first_mesh(instance) as MeshInstance3D
	if source == null or source.mesh == null:
		instance.free()
		return null
	var aabb: AABB = source.mesh.get_aabb()
	if aabb.size.y <= 0.01:
		instance.free()
		return null
	var factor: float = TARGET_HEIGHTS[index] / aabb.size.y
	var holder := Node3D.new()
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = source.mesh
	mesh_instance.scale = Vector3(factor, factor, factor)
	mesh_instance.position = Vector3(-aabb.get_center().x * factor, -aabb.position.y * factor, -aabb.get_center().z * factor)
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	holder.add_child(mesh_instance)
	instance.free()
	return holder


func _first_mesh(node: Node) -> Node:
	if node is MeshInstance3D:
		return node
	for child in node.get_children():
		var found := _first_mesh(child)
		if found != null:
			return found
	return null
