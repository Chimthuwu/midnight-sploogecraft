shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.55;
uniform float grain_strength : hint_range(0.0, 0.15) = 0.028;
uniform float grain_fps : hint_range(1.0, 30.0) = 14.0;
uniform float lift : hint_range(0.0, 0.1) = 0.012;
uniform float saturation : hint_range(0.0, 2.0) = 1.06;

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec3 col = texture(screen_texture, SCREEN_UV).rgb;

	float dist = distance(SCREEN_UV, vec2(0.5, 0.48));
	float vignette = smoothstep(0.34, 0.82, dist) * vignette_strength;
	col *= 1.0 - vignette;

	float luma = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(vec3(luma), col, saturation);
	col += lift * (1.0 - luma);

	float seed = hash21(SCREEN_UV * vec2(854.0, 480.0) + floor(TIME * grain_fps));
	col += (seed - 0.5) * grain_strength;

	COLOR = vec4(col, 1.0);
}
