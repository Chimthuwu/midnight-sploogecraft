extends Resource
class_name GloomConfig

@export_range(0.1, 60.0, 0.1) var tick_seconds := 1.0
@export_range(0.0, 1.0, 0.001) var dark_rise_per_second := 0.006
@export_range(0.0, 1.0, 0.001) var lit_fall_per_second := 0.018
@export_range(1.0, 10.0, 0.1) var underground_multiplier := 2.0
@export_range(1.0, 10.0, 0.1) var night_multiplier := 2.0
@export_range(0.0, 1.0, 0.01) var spawn_threshold := 0.68
@export_range(0.0, 1.0, 0.01) var rot_threshold := 0.84
@export_range(0.0, 1.0, 0.01) var daylight_relief := 0.25
@export_range(0.0, 0.1, 0.001) var noise_to_gloom_scale := 0.01
@export_range(1, 256, 1) var max_rots_per_tick := 8