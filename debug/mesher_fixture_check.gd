extends SceneTree

const PADDED := 18
var failures := 0


func _check(condition: bool, label: String, detail := "") -> void:
	if not condition:
		failures += 1
		push_error("MESHER FIXTURE CHECK FAIL: %s %s" % [label, detail])
		return
	print("MESHER FIXTURE PASS: %s %s" % [label, detail])


func _index(x: int, y: int, z: int) -> int:
	return (x + 1) + (y + 1) * PADDED + (z + 1) * PADDED * PADDED


func _initialize() -> void:
	var snapshot := PackedByteArray()
	var light := PackedByteArray()
	var sky := PackedByteArray()
	snapshot.resize(PADDED * PADDED * PADDED)
	light.resize(PADDED * PADDED * PADDED)
	sky.resize(PADDED * PADDED * PADDED)
	snapshot.fill(0)
	light.fill(0)
	sky.fill(1)
	# A mycelium fixture sitting on top of a soil block, with air above both.
	snapshot[_index(5, 1, 5)] = 1
	snapshot[_index(5, 2, 5)] = 2

	var palette := PackedColorArray()
	palette.append(Color(0, 0, 0))
	palette.append(Color(0.72, 0.70, 0.64))
	palette.append(Color(0.31, 0.19, 0.36))
	var fixtures := {2: &"mycelium"}
	var mesh_data := ChunkMesher.build(snapshot, light, sky, palette, 0, fixtures, {})
	var vertices: PackedVector3Array = mesh_data["vertices"]
	var colors: PackedColorArray = mesh_data["colors"]

	# The soil's top face is the one painted with the soil palette entry; if the
	# fixture occluded its neighbour that face would be missing and the cell would
	# read as a see-through hole.
	var soil_face_vertices := 0
	var fixture_vertices := 0
	for index in range(vertices.size()):
		var vertex := vertices[index]
		if is_equal_approx(vertex.y, 2.0) and vertex.x >= 5.0 and vertex.x <= 6.0 and vertex.z >= 5.0 and vertex.z <= 6.0 and colors[index].r > 0.6:
			soil_face_vertices += 1
		if vertex.x >= 5.0 and vertex.x <= 6.0 and vertex.z >= 5.0 and vertex.z <= 6.0 and vertex.y > 2.0 and vertex.y < 2.9:
			fixture_vertices += 1

	_check(soil_face_vertices >= 6, "soil under a fixture still renders its top face", "verts=%d" % soil_face_vertices)
	_check(fixture_vertices >= 6, "the fixture itself renders", "verts=%d" % fixture_vertices)

	var warm_tint := ChunkMesher._light_tint([{"position": Vector3(5.5, 1.5, 5.5), "cool": false}], Vector3(5.5, 1.5, 6.5), 0.9)
	_check(warm_tint.r > warm_tint.b, "torch light bakes a warm tint", str(warm_tint))
	var cool_tint := ChunkMesher._light_tint([{"position": Vector3(5.5, 1.5, 5.5), "cool": true}], Vector3(5.5, 1.5, 6.5), 0.9)
	_check(cool_tint.b > cool_tint.r, "crystal light bakes a cool tint", str(cool_tint))
	var unlit := ChunkMesher._light_tint([{"position": Vector3(5.5, 1.5, 5.5), "cool": true}], Vector3(5.5, 1.5, 6.5), 0.0)
	_check(unlit == Color.WHITE, "unlit cells stay neutral", str(unlit))

	if failures > 0:
		quit(1)
		return
	print("MESHER FIXTURE CHECK PASS: fixtures do not leave see-through holes")
	quit(0)
