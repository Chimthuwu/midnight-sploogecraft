extends RefCounted
class_name ChunkMesher

const CHUNK_SIZE := 16
const PADDED_SIZE := 18
const FACE_DIRECTIONS := [
	Vector3i(1, 0, 0), Vector3i(-1, 0, 0),
	Vector3i(0, 1, 0), Vector3i(0, -1, 0),
	Vector3i(0, 0, 1), Vector3i(0, 0, -1)
]
const FACE_NORMALS := [
	Vector3.RIGHT, Vector3.LEFT, Vector3.UP,
	Vector3.DOWN, Vector3.BACK, Vector3.FORWARD
]
const FACE_CORNERS := [
	[Vector3(1, 0, 0), Vector3(1, 1, 0), Vector3(1, 1, 1), Vector3(1, 0, 1)],
	[Vector3(0, 0, 1), Vector3(0, 1, 1), Vector3(0, 1, 0), Vector3(0, 0, 0)],
	[Vector3(0, 1, 1), Vector3(1, 1, 1), Vector3(1, 1, 0), Vector3(0, 1, 0)],
	[Vector3(0, 0, 0), Vector3(1, 0, 0), Vector3(1, 0, 1), Vector3(0, 0, 1)],
	[Vector3(1, 0, 1), Vector3(1, 1, 1), Vector3(0, 1, 1), Vector3(0, 0, 1)],
	[Vector3(0, 0, 0), Vector3(0, 1, 0), Vector3(1, 1, 0), Vector3(1, 0, 0)]
]
# Fake sun shading so untextured cubes read as solid objects instead of flat paint.
const FACE_SHADE := [0.94, 0.84, 1.0, 0.74, 0.90, 0.86]
# Tangent axes used to find the cells that occlude each face corner.
const FACE_TANGENTS := [
	[Vector3i(0, 1, 0), Vector3i(0, 0, 1)],
	[Vector3i(0, 1, 0), Vector3i(0, 0, 1)],
	[Vector3i(1, 0, 0), Vector3i(0, 0, 1)],
	[Vector3i(1, 0, 0), Vector3i(0, 0, 1)],
	[Vector3i(1, 0, 0), Vector3i(0, 1, 0)],
	[Vector3i(1, 0, 0), Vector3i(0, 1, 0)]
]
# Corner sign pairs (u, v) matching FACE_CORNERS order per face.
const FACE_CORNER_SIGNS := [
	[Vector2i(-1, -1), Vector2i(1, -1), Vector2i(1, 1), Vector2i(-1, 1)],
	[Vector2i(-1, 1), Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, -1)],
	[Vector2i(-1, 1), Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, -1)],
	[Vector2i(-1, -1), Vector2i(1, -1), Vector2i(1, 1), Vector2i(-1, 1)],
	[Vector2i(1, -1), Vector2i(1, 1), Vector2i(-1, 1), Vector2i(-1, -1)],
	[Vector2i(-1, -1), Vector2i(-1, 1), Vector2i(1, 1), Vector2i(1, -1)]
]
const AO_SHADE := [1.0, 0.82, 0.66, 0.46]
# Coloured light cast: torches warm, lumen crystals cool.
const LIGHT_TINT_RADIUS := 12.0
const WARM_LIGHT_TINT := Color(1.0, 0.66, 0.34)
const COOL_LIGHT_TINT := Color(0.40, 0.82, 1.0)

static func build(snapshot: PackedByteArray, light_snapshot: PackedByteArray, sky_snapshot: PackedByteArray, palette: PackedColorArray, air_id: int, fixture_ids: Dictionary = {}, emissive_ids: Dictionary = {}, light_sources: Array = []) -> Dictionary:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var uv2 := PackedVector2Array()
	for z in range(CHUNK_SIZE):
		for y in range(CHUNK_SIZE):
			for x in range(CHUNK_SIZE):
				var cell_index := (x + 1) + (y + 1) * PADDED_SIZE + (z + 1) * PADDED_SIZE * PADDED_SIZE
				var block_id := int(snapshot[cell_index])
				if block_id == air_id:
					continue
				var cell := Vector3i(x, y, z)
				var hash_value := (x * 73856093) ^ (y * 19349663) ^ (z * 83492791)
				var tone := float(hash_value & 0xFF) / 255.0
				var variation := 0.94 + tone * 0.12
				var base_color: Color = palette[block_id]
				if emissive_ids.has(block_id):
					base_color = Color(base_color.r * 1.5, base_color.g * 1.5, base_color.b * 1.5, 1.0)
				var fixture: StringName = fixture_ids.get(block_id, &"")
				if fixture != &"":
					_append_fixture(vertices, normals, colors, uv2, cell, fixture, base_color, float(int(light_snapshot[cell_index])) / 15.0, sky_snapshot[cell_index] != 0, tone)
					continue
				var face_ao := PackedFloat32Array()
				face_ao.resize(4)
				for face in range(6):
					var direction: Vector3i = FACE_DIRECTIONS[face]
					var neighbor_index := cell_index + direction.x + direction.y * PADDED_SIZE + direction.z * PADDED_SIZE * PADDED_SIZE
					var neighbor_id := int(snapshot[neighbor_index])
					# Emit solid-to-open faces. Fixtures are solid for gameplay but must not
					# occlude their neighbours, or removing their cubes leaves see-through holes.
					if neighbor_id != air_id and not fixture_ids.has(neighbor_id):
						continue
					var face_light := maxi(int(light_snapshot[cell_index]), int(light_snapshot[neighbor_index]))
					var shade: float = FACE_SHADE[face] * variation
					var light_alpha := float(face_light) / 15.0
					var tint := _light_tint(light_sources, Vector3(cell) + Vector3(0.5, 0.5, 0.5), light_alpha)
					_calculate_corner_ao(snapshot, cell_index, face, air_id, face_ao)
					_append_face(vertices, normals, colors, uv2, cell, face, face_ao, shade, base_color, light_alpha, sky_snapshot[cell_index] != 0, tint)
	return {"vertices": vertices, "normals": normals, "colors": colors, "uv2": uv2}


static func _calculate_corner_ao(snapshot: PackedByteArray, cell_index: int, face: int, air_id: int, result: PackedFloat32Array) -> void:
	var direction: Vector3i = FACE_DIRECTIONS[face]
	var tangent: Array = FACE_TANGENTS[face]
	var u: Vector3i = tangent[0]
	var v: Vector3i = tangent[1]
	var n_offset := direction.x + direction.y * PADDED_SIZE + direction.z * PADDED_SIZE * PADDED_SIZE
	var u_offset := u.x + u.y * PADDED_SIZE + u.z * PADDED_SIZE * PADDED_SIZE
	var v_offset := v.x + v.y * PADDED_SIZE + v.z * PADDED_SIZE * PADDED_SIZE
	var face_base := cell_index + n_offset
	var signs: Array = FACE_CORNER_SIGNS[face]
	for corner_index in range(4):
		var sign: Vector2i = signs[corner_index]
		var side_a := face_base + u_offset * sign.x
		var side_b := face_base + v_offset * sign.y
		var occluders := 0
		if int(snapshot[side_a]) != air_id:
			occluders += 1
		if int(snapshot[side_b]) != air_id:
			occluders += 1
		if int(snapshot[side_a + v_offset * sign.y]) != air_id:
			occluders += 1
		result[corner_index] = AO_SHADE[occluders]


# Nearest-source colour blend for cells reached by static light. Intensity still
# comes from the baked light buffer; this only shifts the hue toward the light
# that actually reaches the cell, so torches read warm and crystals cool.
static func _light_tint(sources: Array, center: Vector3, strength: float) -> Color:
	if sources.is_empty() or strength <= 0.02:
		return Color.WHITE
	var warm := 0.0
	var cool := 0.0
	for source in sources:
		var position: Vector3 = source["position"]
		var distance := center.distance_to(position)
		if distance >= LIGHT_TINT_RADIUS:
			continue
		var falloff := 1.0 - distance / LIGHT_TINT_RADIUS
		falloff *= falloff
		if bool(source.get("cool", false)):
			cool += falloff
		else:
			warm += falloff
	var total := warm + cool
	if total <= 0.0:
		return Color.WHITE
	var tint := COOL_LIGHT_TINT.lerp(WARM_LIGHT_TINT, warm / total)
	return Color.WHITE.lerp(tint, clampf(strength * 0.9, 0.0, 0.9))


# Torches and flora are drawn as small fixtures instead of full 1 m cubes.
static func _append_fixture(vertices: PackedVector3Array, normals: PackedVector3Array, colors: PackedColorArray, uv2: PackedVector2Array, cell: Vector3i, fixture: StringName, block_color: Color, light_alpha: float, sky_exposed: bool, tone: float) -> void:
	var origin := Vector3(cell)
	if fixture == &"torch":
		_append_box(vertices, normals, colors, uv2, origin + Vector3(0.5, 0.24, 0.5), Vector3(0.12, 0.48, 0.12), Color(0.22, 0.20, 0.21), light_alpha, sky_exposed)
		_append_box(vertices, normals, colors, uv2, origin + Vector3(0.5, 0.54, 0.5), Vector3(0.24, 0.20, 0.24), block_color, light_alpha, sky_exposed)
		_append_box(vertices, normals, colors, uv2, origin + Vector3(0.5, 0.67, 0.5), Vector3(0.16, 0.06, 0.16), Color(0.18, 0.16, 0.17), light_alpha, sky_exposed)
	elif fixture == &"mycelium":
		_append_cross(vertices, normals, colors, uv2, origin, 0.32, 0.18 + tone * 0.12, block_color, light_alpha, sky_exposed, tone)
	else:
		_append_cross(vertices, normals, colors, uv2, origin, 0.26, 0.50 + tone * 0.32, block_color, light_alpha, sky_exposed, tone)


static func _append_cross(vertices: PackedVector3Array, normals: PackedVector3Array, colors: PackedColorArray, uv2: PackedVector2Array, origin: Vector3, width: float, height: float, color: Color, light_alpha: float, sky_exposed: bool, tone: float) -> void:
	var half := width * 0.5
	var center_x := origin.x + 0.5 + (tone - 0.5) * 0.22
	var center_z := origin.z + 0.5 + (fposmod(tone * 7.0, 1.0) - 0.5) * 0.22
	var base_y := origin.y
	var top_y := origin.y + height
	_append_quad_2sided(vertices, normals, colors, uv2,
		Vector3(center_x - half, base_y, center_z), Vector3(center_x + half, base_y, center_z),
		Vector3(center_x + half, top_y, center_z), Vector3(center_x - half, top_y, center_z),
		color, light_alpha, sky_exposed)
	_append_quad_2sided(vertices, normals, colors, uv2,
		Vector3(center_x, base_y, center_z - half), Vector3(center_x, base_y, center_z + half),
		Vector3(center_x, top_y, center_z + half), Vector3(center_x, top_y, center_z - half),
		color, light_alpha, sky_exposed)


static func _append_quad_2sided(vertices: PackedVector3Array, normals: PackedVector3Array, colors: PackedColorArray, uv2: PackedVector2Array, a: Vector3, b: Vector3, c: Vector3, d: Vector3, color: Color, light_alpha: float, sky_exposed: bool) -> void:
	var points: Array[Vector3] = [a, b, c, d]
	var order := [0, 2, 1, 0, 3, 2, 0, 1, 2, 0, 2, 3]
	for index in order:
		vertices.append(points[index])
		normals.append(Vector3.UP)
		colors.append(Color(color.r, color.g, color.b, light_alpha))
		uv2.append(Vector2(1.0 if sky_exposed else 0.0, 0.0))


static func _append_box(vertices: PackedVector3Array, normals: PackedVector3Array, colors: PackedColorArray, uv2: PackedVector2Array, center: Vector3, size: Vector3, color: Color, light_alpha: float, sky_exposed: bool) -> void:
	var vertex_order := [0, 2, 1, 0, 3, 2]
	for face in range(6):
		var corners: Array = FACE_CORNERS[face]
		for corner_index in vertex_order:
			var corner: Vector3 = corners[corner_index]
			vertices.append(center + (corner - Vector3(0.5, 0.5, 0.5)) * size)
			normals.append(FACE_NORMALS[face])
			colors.append(Color(color.r, color.g, color.b, light_alpha))
			uv2.append(Vector2(1.0 if sky_exposed else 0.0, 0.0))


static func _append_face(vertices: PackedVector3Array, normals: PackedVector3Array, colors: PackedColorArray, uv2: PackedVector2Array, cell: Vector3i, face: int, face_ao: PackedFloat32Array, shade: float, block_color: Color, light_alpha: float, sky_exposed: bool, tint := Color.WHITE) -> void:
	var corners: Array = FACE_CORNERS[face]
	var vertex_order := [0, 2, 1, 0, 3, 2]
	for corner_index in vertex_order:
		vertices.append(Vector3(cell) + corners[corner_index])
		normals.append(FACE_NORMALS[face])
		var ao: float = face_ao[corner_index]
		colors.append(Color(
			block_color.r * shade * ao * tint.r,
			block_color.g * shade * ao * tint.g,
			block_color.b * shade * ao * tint.b,
			light_alpha
		))
		uv2.append(Vector2(1.0 if sky_exposed else 0.0, 0.0))
