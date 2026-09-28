shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

// Chicago River and Lake Michigan. Animated procedural normals: four crossing wave trains plus two octaves of
// drifting value-noise chop, calm and flowing on the river, livelier on the open lake (east of x 1450-2350).
// Low roughness lets the sun and the city's lights glint and streak; the body colour stays readable at
// grazing angles because the reflection is a sky tint blended by our own Fresnel, not a mirror of the horizon
// haze (a near-mirror read as a beige plain from Lake Shore Drive).
uniform vec4 river_color : source_color = vec4(0.05, 0.2, 0.15, 1.0);
uniform vec4 lake_color : source_color = vec4(0.03, 0.17, 0.3, 1.0);
uniform vec4 sky_tint : source_color = vec4(0.5, 0.63, 0.74, 1.0);
uniform float river_flow = 0.45;
uniform float wave_strength = 1.0;

varying vec3 world_position;


float hash21(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}


float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}


float wave(vec2 p, vec2 dir, float length_m, float speed, float t) {
	float k = 6.2831853 / length_m;
	return sin(dot(normalize(dir), p) * k - t * speed * k);
}


float water_height(vec2 p, float t, float lake) {
	// River: long, slow swells carried downstream (the main branch runs along x), cut by boat wakes' cross-chop.
	vec2 drift = vec2(t * river_flow, t * river_flow * 0.15);
	float river = wave(p, vec2(1.0, 0.18), 7.0, 0.9, t) * 0.35 + wave(p, vec2(0.3, 1.0), 3.1, 0.7, t) * 0.2;
	river += (value_noise((p - drift) * 0.55) - 0.5) * 0.5 + (value_noise((p - drift) * 1.7 + 11.0) - 0.5) * 0.22;
	// Lake: wind-driven chop from the north-east, shorter and faster.
	float lake_h = wave(p, vec2(-0.6, 1.0), 9.0, 2.6, t) * 0.45 + wave(p, vec2(-1.0, 0.35), 4.3, 1.9, t) * 0.3;
	lake_h += wave(p, vec2(0.2, 1.0), 2.2, 1.4, t) * 0.18;
	lake_h += (value_noise(p * 0.8 + vec2(-t * 0.9, t * 0.6)) - 0.5) * 0.45;
	return mix(river * 0.55, lake_h, lake) * wave_strength;
}


void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}


void fragment() {
	vec2 p = world_position.xz;
	float lake = smoothstep(1450.0, 2350.0, p.x);
	float t = TIME;
	float e = 0.12;
	float h = water_height(p, t, lake);
	float hx = water_height(p + vec2(e, 0.0), t, lake) - h;
	float hz = water_height(p + vec2(0.0, e), t, lake) - h;
	// Slopes fade with distance so far water settles into a smooth sheet instead of aliasing into noise.
	float dist = length(VERTEX);
	float settle = 1.0 - smoothstep(120.0, 900.0, dist) * 0.8;
	// Water is horizontal, so perturb the world up vector and hand Godot a view-space normal directly (the city's
	// water meshes carry no tangents for a normal map).
	vec3 up = normalize(vec3(-hx / e * 0.09 * settle, 1.0, -hz / e * 0.09 * settle));
	NORMAL = normalize((VIEW_MATRIX * vec4(up, 0.0)).xyz);

	vec3 body = mix(river_color.rgb, lake_color.rgb, lake);
	// Crest highlights: the tops of the swells catch a little more light than the troughs.
	body *= 0.85 + 0.35 * clamp(h * 0.8 + 0.5, 0.0, 1.0);
	float fresnel = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 4.0);
	ALBEDO = mix(body, sky_tint.rgb * 0.5, fresnel * 0.3);
	ROUGHNESS = mix(0.14, 0.08, lake);
	METALLIC = 0.0;
	// 0.5 washed grazing views out to pale cyan (the sky); glints still show through the low roughness.
	SPECULAR = 0.3;
	// Light scattered up out of the water column keeps the green/blue in the shade of the buildings and decks.
	EMISSION = body * 0.06;
}
