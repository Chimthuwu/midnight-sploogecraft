extends Resource
class_name DayNightConfig

@export_range(1.0, 3600.0, 1.0) var day_seconds := 420.0
@export_range(1.0, 3600.0, 1.0) var twilight_seconds := 120.0
@export_range(1.0, 3600.0, 1.0) var night_seconds := 900.0
@export_range(1.0, 3600.0, 1.0) var dawn_seconds := 60.0
@export_range(0.0, 1.0, 0.01) var day_sky_level := 0.22
@export_range(0.0, 1.0, 0.01) var twilight_sky_level := 0.06
@export_range(0.0, 1.0, 0.01) var night_sky_level := 0.0
@export var day_sky_color := Color(0.31, 0.4, 0.48, 1.0)
@export var night_sky_color := Color(0.005, 0.008, 0.016, 1.0)