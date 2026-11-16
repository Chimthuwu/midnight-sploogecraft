extends Resource
class_name LumencasterConfig

@export_range(1.0, 1000.0, 1.0) var reserve_capacity := 100.0
@export_range(0.0, 1000.0, 1.0) var starting_reserve := 100.0
@export_range(0.0, 100.0, 0.1) var recharge_per_second_at_full_light := 6.0
@export_range(0.0, 10.0, 0.1) var lumen_cost_per_projector_block := 1.0
@export var projector_default_block: StringName = &"concrete"