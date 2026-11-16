extends Node3D
class_name VoxelChunk

var mesh_instance: MeshInstance3D
var static_body: StaticBody3D
var collision_shape: CollisionShape3D
var chunk_coords := Vector3i.ZERO


func configure(coords: Vector3i, origin: Vector3, material: Material) -> void:
	chunk_coords = coords
	position = origin
	mesh_instance = MeshInstance3D.new()
	mesh_instance.name = "Mesh"
	mesh_instance.material_override = material
	add_child(mesh_instance)
	static_body = StaticBody3D.new()
	static_body.name = "Collision"
	static_body.collision_layer = 1
	static_body.collision_mask = 1
	add_child(static_body)
	collision_shape = CollisionShape3D.new()
	collision_shape.name = "TerrainFaces"
	static_body.add_child(collision_shape)


func install_geometry(vertices: PackedVector3Array, normals: PackedVector3Array, colors: PackedColorArray, uv2: PackedVector2Array) -> void:
	if vertices.is_empty():
		mesh_instance.mesh = null
		collision_shape.shape = null
		return
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_TEX_UV2] = uv2
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh_instance.mesh = mesh
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(vertices)
	collision_shape.shape = shape
