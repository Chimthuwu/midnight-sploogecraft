shader_type spatial;
render_mode unshaded, cull_back, depth_draw_opaque;

uniform float dither_bands : hint_range(2.0, 16.0, 1.0) = 6.0;
uniform vec3 camera_position = vec3(0.0);
uniform vec3 camera_direction = vec3(0.0, 0.0, -1.0);
uniform float flashlight_range = 12.0;
uniform float flashlight_inner_cos = 0.94;
uniform float flashlight_outer_cos = 0.82;
uniform float flashlight_intensity = 0.85;
uniform bool flashlight_enabled = true;
uniform float ambient_sky_level = 0.0;
uniform vec3 sun_direction = vec3(0.42, 0.78, 0.45);
uniform float sun_strength = 0.0;
uniform vec3 sun_color = vec3(1.0, 0.86, 0.64);
uniform vec3 sky_tint = vec3(0.80, 0.87, 1.0);
uniform vec3 flashlight_color = vec3(1.0, 0.89, 0.72);
uniform vec3 static_light_color = vec3(1.0);

varying vec3 fragment_world_position;
varying vec3 fragment_world_normal;

void vertex() {
	fragment_world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	fragment_world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}

float bayer8(vec2 pixel_position) {
	ivec2 cell = ivec2(mod(floor(pixel_position), 8.0));
	int rank = 0;
	for (int bit_index = 0; bit_index < 3; bit_index++) {
		int x_bit = (cell.x >> bit_index) & 1;
		int y_bit = (cell.y >> bit_index) & 1;
		int rank_2 = ((x_bit ^ y_bit) << 1) | y_bit;
		rank += rank_2 << (bit_index * 2);
	}
	return (float(rank) + 0.5) / 64.0;
}

float hash31(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.yzx + 33.33);
	return fract((p.x + p.y) * p.z);
}

float value_noise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float n000 = hash31(i);
	float n100 = hash31(i + vec3(1.0, 0.0, 0.0));
	float n010 = hash31(i + vec3(0.0, 1.0, 0.0));
	float n110 = hash31(i + vec3(1.0, 1.0, 0.0));
	float n001 = hash31(i + vec3(0.0, 0.0, 1.0));
	float n101 = hash31(i + vec3(1.0, 0.0, 1.0));
	float n011 = hash31(i + vec3(0.0, 1.0, 1.0));
	float n111 = hash31(i + vec3(1.0, 1.0, 1.0));
	return mix(mix(mix(n000, n100, f.x), mix(n010, n110, f.x), f.y),
		mix(mix(n001, n101, f.x), mix(n011, n111, f.x), f.y), f.z);
}

float dynamic_flashlight_level() {
	if (!flashlight_enabled) {
		return 0.0;
	}
	vec3 from_source = fragment_world_position - camera_position;
	float distance_to_fragment = length(from_source);
	if (distance_to_fragment <= 0.001 || distance_to_fragment >= flashlight_range) {
		return 0.0;
	}
	float cone_alignment = dot(from_source / distance_to_fragment, normalize(camera_direction));
	float cone = smoothstep(flashlight_outer_cos, flashlight_inner_cos, cone_alignment);
	float distance_falloff = 1.0 - distance_to_fragment / flashlight_range;
	return clamp(flashlight_intensity * cone * distance_falloff * distance_falloff, 0.0, 1.0);
}

void fragment() {
	float static_light = clamp(COLOR.a, 0.0, 1.0);
	float flashlight_light = dynamic_flashlight_level();
	float sky_light = clamp(UV2.x * ambient_sky_level, 0.0, 1.0);
	// Wrapped sun term: lit faces go warm, faces turned away keep the cool sky tint.
	float sun_dot = dot(normalize(fragment_world_normal), normalize(sun_direction));
	float sun_term = clamp((sun_dot + 0.32) / 1.32, 0.0, 1.0);
	float sun_light = clamp(sun_strength * sun_term, 0.0, 1.0);

	// The strongest source sets both the brightness and the colour temperature.
	float light_value = static_light;
	vec3 light_tint = static_light_color;
	if (flashlight_light > light_value) {
		light_value = flashlight_light;
		light_tint = flashlight_color;
	}
	if (sky_light > light_value) {
		light_value = sky_light;
		light_tint = sky_tint;
	}
	if (sun_light > light_value) {
		light_value = sun_light;
		light_tint = sun_color;
	}

	float band_count = max(dither_bands - 1.0, 1.0);
	float scaled = light_value * band_count;
	float lower_band = floor(scaled);
	float upper_band = min(lower_band + 1.0, band_count);
	float threshold = bayer8(FRAGCOORD.xy);
	float band = mix(lower_band, upper_band, step(threshold, fract(scaled)));
	float quantized_light = band / band_count;
	// Keep the dot pattern for darkness and flashlight falloff only; daylight
	// gradients stay smooth so flat ash faces stop reading as a dithered screen.
	float dither_gate = 1.0 - smoothstep(0.26, 0.60, light_value);
	float graded_light = mix(light_value, quantized_light, dither_gate);

	// World-space surface detail: low-frequency mottling plus a dark seam at
	// every voxel edge, so 1 m faces stop reading as flat plastic.
	vec3 detail_position = fragment_world_position * 2.4;
	float mottle = value_noise(detail_position) * 0.6 + value_noise(detail_position * 3.1) * 0.4;
	float grain = mix(0.87, 1.13, mottle);
	vec3 cell = fract(fragment_world_position);
	float edge_distance = min(min(cell.x, 1.0 - cell.x), min(min(cell.y, 1.0 - cell.y), min(cell.z, 1.0 - cell.z)));
	float bevel = mix(0.79, 1.0, smoothstep(0.0, 0.08, edge_distance));
	ALBEDO = COLOR.rgb * graded_light * light_tint * grain * bevel;
}