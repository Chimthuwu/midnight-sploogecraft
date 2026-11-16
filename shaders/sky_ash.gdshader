shader_type sky;
render_mode use_debanding;

uniform vec3 top_color : source_color = vec3(0.18, 0.22, 0.31);
uniform vec3 horizon_color : source_color = vec3(0.72, 0.68, 0.60);
uniform vec3 ground_color : source_color = vec3(0.11, 0.11, 0.12);
uniform vec3 sun_color : source_color = vec3(1.0, 0.82, 0.58);
uniform vec3 sun_direction = vec3(0.0, 1.0, 0.0);
uniform float sun_energy : hint_range(0.0, 4.0) = 1.0;
uniform float sun_radius : hint_range(0.001, 0.12) = 0.014;
uniform float sun_halo : hint_range(0.0, 3.0) = 0.55;
uniform float horizon_glow : hint_range(0.0, 2.0) = 0.55;
uniform float star_energy : hint_range(0.0, 1.0) = 0.0;
uniform float twilight_energy : hint_range(0.0, 1.0) = 0.0;

float hash31(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.yzx + 33.33);
	return fract((p.x + p.y) * p.z);
}

void sky() {
	vec3 dir = normalize(EYEDIR);
	float height = clamp(dir.y, 0.0, 1.0);

	// Gradient: dense horizon band under a deeper zenith.
	float horizon_mix = pow(1.0 - height, 3.4);
	vec3 col = mix(top_color, horizon_color, horizon_mix);

	vec3 sun_dir = normalize(sun_direction);
	float sun_dot = max(dot(dir, sun_dir), 0.0);

	// Small hard disc, wide soft halo, plus azimuth bias so dusk glows around
	// the sun rather than uniformly along the whole horizon.
	float disc = smoothstep(cos(sun_radius), cos(sun_radius * 0.55), sun_dot);
	float halo = pow(sun_dot, 32.0) * sun_halo + pow(sun_dot, 7.0) * 0.035;
	float azimuth = pow(1.0 - height, 7.0);
	float glow = pow(sun_dot, 7.0) * horizon_glow * azimuth;
	col += sun_color * (disc * 2.4 + halo + glow) * sun_energy;

	// Twilight band: a warm/cool split sitting on the horizon.
	col += mix(sun_color, vec3(0.26, 0.32, 0.55), height) * twilight_energy * pow(1.0 - height, 4.0) * 0.45;

	// Sparse stars, faded out by daylight and masked below the horizon.
	if (star_energy > 0.001 && dir.y > 0.0) {
		vec3 cell = floor(dir * 280.0);
		vec3 local = fract(dir * 280.0) - 0.5;
		float seed = hash31(cell);
		float presence = smoothstep(0.982, 0.999, seed);
		float point = 1.0 - smoothstep(0.0, 0.30, length(local));
		float twinkle = 0.6 + 0.4 * sin(TIME * 1.6 + seed * 40.0);
		col += vec3(0.84, 0.92, 1.0) * presence * point * twinkle * star_energy * smoothstep(0.0, 0.22, dir.y);
	}

	// Ground half: slope into the fog colour so the world edge never shows sky.
	float below = clamp(-dir.y * 2.6, 0.0, 1.0);
	col = mix(col, ground_color, smoothstep(0.0, 1.0, below));

	COLOR = col;
}
