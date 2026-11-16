extends GloomEnemy
class_name LampEater

var target_light_cell := Vector3i(-1, -1, -1)
var retarget_timer := 0.0
var extinguish_distance := 1.25
var extinguish_seconds := 12.0
var target_radius := 24.0
var target_blocks: Array[StringName] = [&"torch"]

func _update_behavior(delta: float) -> void:
	retarget_timer -= delta
	if retarget_timer <= 0.0:
		retarget_timer = 1.0
		_find_target_light()
	if target_light_cell.x >= 0:
		var target := Vector3(target_light_cell) + Vector3.ONE * 0.5
		var toward := target - position
		if toward.length() <= extinguish_distance:
			if attack_cooldown <= 0.0 and world.extinguish_light_source(target_light_cell, extinguish_seconds):
				attack_cooldown = 2.0
			target_light_cell = Vector3i(-1, -1, -1)
			return
		if toward.length_squared() > 0.01:
			position += toward.normalized() * move_speed * delta
			look_at(Vector3(target.x, position.y, target.z), Vector3.UP)
		return
	super._update_behavior(delta)

func _find_target_light() -> void:
	var nearest_distance := INF
	target_light_cell = Vector3i(-1, -1, -1)
	for source in world.static_light_sources:
		var cell: Vector3i = source["cell"]
		if world.extinguished_sources.has(cell):
			continue
		var distance := position.distance_squared_to(Vector3(cell) + Vector3.ONE * 0.5)
		if distance >= nearest_distance or distance > target_radius * target_radius:
			continue
		var block_id := world.get_block_id(cell)
		if block_id <= 0 or block_id >= world.block_defs.size():
			continue
		if not target_blocks.has(world.block_defs[block_id].block_id):
			continue
		nearest_distance = distance
		target_light_cell = cell