extends SceneTree

func _initialize() -> void:
	var names := ["bench2", "garbageBin", "tree2", "tree6", "fireHydrant", "trashBag1", "trafficCone", "garden1"]
	for name in names:
		var packed := load("res://assets/props/free_city/%s.glb" % name) as PackedScene
		if packed == null:
			print("PROP FAIL %s" % name)
			continue
		var instance := packed.instantiate()
		var aabb := AABB(Vector3.ZERO, Vector3.ZERO)
		var first := true
		for node in _meshes(instance):
			var mesh_instance := node as MeshInstance3D
			var box: AABB = mesh_instance.mesh.get_aabb()
			var world_box := mesh_instance.transform * box
			if first:
				aabb = world_box
				first = false
			else:
				aabb = aabb.merge(world_box)
		print("PROP %s size=%s pos=%s" % [name, str(aabb.size), str(aabb.position)])
		instance.free()
	quit(0)


func _meshes(node: Node) -> Array:
	var result: Array = []
	if node is MeshInstance3D:
		result.append(node)
	for child in node.get_children():
		result.append_array(_meshes(child))
	return result
