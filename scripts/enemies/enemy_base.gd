extends Node3D
class_name GloomEnemy

@export var move_speed := 2.2
@export var max_health := 20.0
@export var touch_damage := 5.0
@export var attack_range := 1.3
@export var dissolve_light_level := 12

var health := 20.0
var world: VoxelWorld
var player: VoxelPlayer
var attack_cooldown := 0.0
var dissolve_timer := 0.0
# Civilian background actors never chase or fight; gang and police threats do.
var hostile := true

func _ready() -> void:
	add_to_group("enemies")
	health = max_health
	var root := get_tree().current_scene
	if root == null:
		root = get_parent()
	world = root.get_node("VoxelWorld") as VoxelWorld
	player = root.get_node("Player") as VoxelPlayer
	_create_placeholder_mesh()

func _process(delta: float) -> void:
	if not is_instance_valid(player) or not player.spawned or not world.is_generated:
		return
	attack_cooldown = maxf(0.0, attack_cooldown - delta)
	var cell := Vector3i(floori(position.x), floori(position.y), floori(position.z))
	if _should_dissolve(cell):
		dissolve_timer += delta
		if dissolve_timer >= 0.65:
			_on_dissolve()
			queue_free()
		return
	dissolve_timer = 0.0
	if hostile:
		_update_behavior(delta)
		var toward := player.position - position
		if toward.length() <= attack_range and attack_cooldown <= 0.0:
			player.take_damage(touch_damage)
			attack_cooldown = 1.0

func _should_dissolve(cell: Vector3i) -> bool:
	return false

func _on_dissolve() -> void:
	pass

func _update_behavior(delta: float) -> void:
	var target := player.position
	var flat := target - position
	flat.y = 0.0
	if flat.length_squared() > 0.01:
		position += flat.normalized() * move_speed * delta
		look_at(Vector3(target.x, position.y, target.z), Vector3.UP)

func apply_damage(amount: float) -> void:
	health -= amount
	if health <= 0.0:
		queue_free()

func _create_placeholder_mesh() -> void:
	var mesh_instance := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.32
	mesh.height = 0.7
	mesh_instance.mesh = mesh
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(0.34, 0.08, 0.42)
	mesh_instance.material_override = material
	add_child(mesh_instance)