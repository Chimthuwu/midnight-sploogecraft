extends Node
class_name DayNightCycle

const CONFIG: DayNightConfig = preload("res://data/world/day_night_config.tres")
const DAY_HORIZON_COLOR := Color(0.80, 0.74, 0.62, 1)
const NIGHT_HORIZON_COLOR := Color(0.13, 0.05, 0.17, 1)
const SUN_COLOR_DAY := Color(1.0, 0.88, 0.68, 1)
const SUN_COLOR_LOW := Color(1.0, 0.56, 0.32, 1)
const STARS_FULL_AT := 0.10
const STARS_GONE_AT := 0.38

var world: VoxelWorld
var environment: Environment
var sky_material: ShaderMaterial
# Open at night: day 420 s + twilight 120 s, then 60 s into the night phase.
# This is a neon city; the dark is the presentation, not an end-state to wait for.
var elapsed_seconds := 600.0
var phase_name := "day"
var phase_fraction := 0.0
var ambient_level := 0.22
var daylight := 0.0
var twilight := 0.0

func _ready() -> void:
	world = get_parent().get_node("VoxelWorld") as VoxelWorld
	var environment_node := get_parent().get_node_or_null("WorldEnvironment") as WorldEnvironment
	if environment_node != null:
		environment = environment_node.environment
		if environment != null and environment.sky != null:
			sky_material = environment.sky.sky_material as ShaderMaterial
	_update_phase()

func _process(delta: float) -> void:
	var cycle_length := CONFIG.day_seconds + CONFIG.twilight_seconds + CONFIG.night_seconds + CONFIG.dawn_seconds
	elapsed_seconds = fposmod(elapsed_seconds + delta, cycle_length)
	_update_phase()

func _update_phase() -> void:
	var day_end := CONFIG.day_seconds
	var twilight_end := day_end + CONFIG.twilight_seconds
	var night_end := twilight_end + CONFIG.night_seconds
	twilight = 0.0
	if elapsed_seconds < day_end:
		phase_name = "day"
		phase_fraction = elapsed_seconds / CONFIG.day_seconds
		ambient_level = CONFIG.day_sky_level
	elif elapsed_seconds < twilight_end:
		phase_name = "twilight"
		phase_fraction = (elapsed_seconds - day_end) / CONFIG.twilight_seconds
		ambient_level = lerpf(CONFIG.day_sky_level, CONFIG.twilight_sky_level, smoothstep(0.0, 1.0, phase_fraction))
		twilight = sin(phase_fraction * PI)
	elif elapsed_seconds < night_end:
		phase_name = "night"
		phase_fraction = (elapsed_seconds - twilight_end) / CONFIG.night_seconds
		ambient_level = CONFIG.night_sky_level
	else:
		phase_name = "dawn"
		phase_fraction = (elapsed_seconds - night_end) / CONFIG.dawn_seconds
		ambient_level = lerpf(CONFIG.night_sky_level, CONFIG.day_sky_level, smoothstep(0.0, 1.0, phase_fraction))
		twilight = sin(phase_fraction * PI)

	daylight = clampf(inverse_lerp(CONFIG.night_sky_level, CONFIG.day_sky_level, ambient_level), 0.0, 1.0)
	var top_color := CONFIG.night_sky_color.lerp(CONFIG.day_sky_color, daylight)
	var horizon_color := NIGHT_HORIZON_COLOR.lerp(DAY_HORIZON_COLOR, daylight)
	var star_energy := 1.0 - smoothstep(STARS_FULL_AT, STARS_GONE_AT, daylight)

	if sky_material != null:
		sky_material.set_shader_parameter("top_color", top_color)
		sky_material.set_shader_parameter("horizon_color", horizon_color)
		sky_material.set_shader_parameter("ground_color", horizon_color.darkened(0.45))
		sky_material.set_shader_parameter("star_energy", star_energy)
		sky_material.set_shader_parameter("twilight_energy", twilight)
		sky_material.set_shader_parameter("horizon_glow", 0.55 + twilight * 0.75 + (1.0 - daylight) * 0.10)
	if is_instance_valid(environment):
		environment.background_color = top_color
		environment.fog_light_color = horizon_color.lerp(DAY_HORIZON_COLOR, 0.25 * daylight)
		environment.fog_light_energy = lerpf(0.34, 0.62, daylight)
		environment.fog_density = lerpf(0.0045, 0.0016, daylight)
		environment.ambient_light_color = top_color
		environment.ambient_light_energy = ambient_level
		if environment.glow_enabled:
			environment.glow_intensity = lerpf(1.30, 0.85, daylight)
	if is_instance_valid(world):
		world.set_ambient_sky_level(ambient_level)
		_update_sun(star_energy)

# The day phase sweeps the sun from a low east horizon to a low west horizon;
# twilight, night and dawn reuse the clamped ends so the direction never jumps.
func _update_sun(star_energy: float) -> void:
	var day_progress := clampf(elapsed_seconds / maxf(CONFIG.day_seconds, 1.0), 0.0, 1.0)
	var sun_angle := lerpf(0.65, PI - 0.55, day_progress)
	var direction := Vector3(cos(sun_angle), sin(sun_angle), 0.45).normalized()
	var strength := daylight * 1.15
	var low_sun := (1.0 - clampf(sin(sun_angle) * 1.6, 0.0, 1.0)) * 0.65
	var sun_color := SUN_COLOR_DAY.lerp(SUN_COLOR_LOW, low_sun)
	world.set_sun(direction, sun_color, strength)

	if sky_material != null:
		sky_material.set_shader_parameter("sun_direction", direction)
		sky_material.set_shader_parameter("sun_color", sun_color)
		sky_material.set_shader_parameter("sun_energy", clampf(strength * 1.35, 0.0, 1.2))
		sky_material.set_shader_parameter("star_energy", star_energy)


func get_save_time() -> float:
	return elapsed_seconds

func restore_time(value: float) -> void:
	elapsed_seconds = maxf(0.0, value)
	_update_phase()
