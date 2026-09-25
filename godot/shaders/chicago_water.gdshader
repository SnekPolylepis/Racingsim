shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform vec4 deep_color : source_color = vec4(0.055, 0.145, 0.17, 1.0);
uniform vec4 light_ripple : source_color = vec4(0.19, 0.31, 0.30, 1.0);
uniform float flow_speed = 0.035;
uniform float ripple_scale = 0.075;
uniform float reflection_strength = 0.26;

varying vec3 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_position.xz;
	float t = TIME * flow_speed;
	float long_wave = sin(p.x * 0.021 + p.y * 0.014 + t * 3.1);
	float cross_wave = sin(p.y * 0.047 - p.x * 0.011 - t * 2.1);
	float fine_wave = sin((p.x + p.y) * 0.125 + t * 1.35);
	float ripple = long_wave * 0.48 + cross_wave * 0.36 + fine_wave * 0.16;
	float sheen = smoothstep(0.50, 0.98, ripple * 0.5 + 0.5) * reflection_strength;
	ALBEDO = mix(deep_color.rgb, light_ripple.rgb, sheen);
	ROUGHNESS = mix(0.3, 0.19, sheen);
	METALLIC = 0.24;
	vec3 wave_normal = normalize(vec3(cos(p.x * 0.08 + t) * ripple_scale, 1.0, sin(p.y * 0.065 - t * 0.8) * ripple_scale));
	NORMAL_MAP = wave_normal * 0.5 + 0.5;
	NORMAL_MAP_DEPTH = 0.22;
}
