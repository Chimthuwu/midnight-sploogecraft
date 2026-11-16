extends SceneTree

func _initialize() -> void:
	var paths := [
		"res://assets/vehicles/psx/car01/Car.obj",
		"res://assets/vehicles/psx/car03/Car3.obj",
		"res://assets/vehicles/psx/car04/Car4.obj",
		"res://assets/vehicles/psx/car05/Car5.obj",
		"res://assets/vehicles/psx/car05/Car5_Police.obj",
		"res://assets/vehicles/psx/car05/Car5_Taxi.obj",
		"res://assets/vehicles/psx/car06/Car6.obj"
	]
	for path in paths:
		var mesh := load(path) as Mesh
		if mesh == null:
			print("VEHICLE PROBE FAIL %s" % path)
			continue
		var aabb: AABB = mesh.get_aabb()
		print("VEHICLE PROBE %s size=%s center=%s" % [path.get_file(), str(aabb.size), str(aabb.get_center())])
	quit(0)
