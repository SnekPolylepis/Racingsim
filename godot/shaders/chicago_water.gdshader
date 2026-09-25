shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

// Cheap procedural equivalent of two scrolling tangent-space normal maps. The east lake face
// gets shorter, faster chop; the river stays long and slow. Standard PBR specular keeps the water
// responsive to the scene's sky, reflection probes and city lights without another render pass.
uniform vec4 deep_color : source_color = vec4(0.018, 0.105, 0.12, 1.0);
uniform vec4 lake_color : source_color = vec4(0.03, 0.17, 0.26, 1.0);
uniform float flow_speed = 0.022;
uniform float ripple_scale = 0.075;

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


float water_height(vec2 p, float time, float lake) {
	// River flow follows the city's east-west channel; broad undulation remains calm.
	vec2 river_a = p * vec2(0.018, 0.075) + vec2(time * flow_speed, time * flow_speed * 0.12);
	vec2 river_b = p * vec2(-0.052, 0.031) + vec2(-time * flow_speed * 0.38, time * flow_speed * 0.28);
	float river = value_noise(river_a) * 0.72 + value_noise(river_b) * 0.28;
	// Open lake has tighter, faster intersecting chop, faded in geographically east of downtown.
	vec2 lake_a = p * vec2(0.12, 0.19) + vec2(time * 0.19, -time * 0.11);
	vec2 lake_b = p * vec2(-0.21, 0.14) + vec2(-time * 0.13, -time * 0.17);
	float lake_noise = value_noise(lake_a) * 0.58 + value_noise(lake_b) * 0.42;
	return mix(river, lake_noise, lake) * mix(0.16, 0.52, lake);
}


void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}


void fragment() {
	vec2 p = world_position.xz;
	float lake = smoothstep(1450.0, 2350.0, p.x);
	float t = TIME;
	float h = water_height(p, t, lake);
	float hx = water_height(p + vec2(0.55, 0.0), t, lake) - h;
	float hz = water_height(p + vec2(0.0, 0.55), t, lake) - h;
	vec3 tangent_normal = normalize(vec3(-hx * ripple_scale * 2.0, 1.0, -hz * ripple_scale * 2.0));
	NORMAL_MAP = tangent_normal * 0.5 + 0.5;
	NORMAL_MAP_DEPTH = mix(0.32, 0.78, lake);

	ALBEDO = mix(deep_color.rgb, lake_color.rgb, lake);
	// At Lake Shore Drive's grazing angle a near-mirror (roughness 0.1, specular 0.95) showed only the
	// warm horizon haze, so the lake read as a beige plain. Rougher, lower specular keeps a sky sheen
	// and the city lights' streaks at night while the blue-green body colour survives.
	ROUGHNESS = mix(0.3, 0.24, lake);
	METALLIC = 0.0;
	SPECULAR = 0.35;
	// Reflections come from the environment's sky radiance and the city's lights through the low
	// roughness above. (A screen-colour read here rendered the lake as a flat beige sheet: the water
	// sampled its own unlit copy.) Fresnel only darkens the body colour looking straight down.
	float fresnel = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 5.0);
	ALBEDO *= mix(1.0, 0.6, 1.0 - fresnel);
}
