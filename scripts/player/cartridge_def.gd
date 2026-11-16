extends Resource
class_name CartridgeDef

@export var cartridge_id: StringName = &"excavator"
@export var display_name: String = "EXCAVATOR"
@export var accent_color: Color = Color(0.25, 1.0, 0.78)
@export_enum("excavate", "beacon", "photon", "flare") var action: String = "excavate"
@export_range(0.0, 100.0, 0.1) var energy_cost := 15.0
@export_range(0, 15, 1) var minimum_light := 1
@export_range(1.0, 64.0, 0.5) var range := 12.0
@export_range(0.0, 100.0, 0.1) var gloom_noise := 8.0
@export_range(0.0, 1000.0, 0.1) var damage := 0.0
@export_range(0, 15, 1) var light_level := 0
@export var light_block_id: StringName = &"torch"
@export_range(0.0, 300.0, 0.5) var duration := 0.0