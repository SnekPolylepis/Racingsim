shader_type spatial;
render_mode blend_mix;

uniform vec4 paint_color : source_color = vec4(.76, .15, .18, 1.);
uniform sampler2D environment_map : source_color, filter_linear_mipmap, repeat_disable;
varying vec3 world_normal;
varying vec3 world_position;

void vertex() {
	world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.)).xyz;
}

void fragment() {
	vec3 n = normalize(world_normal);
	vec3 v = normalize(CAMERA_POSITION_WORLD - world_position);
	vec3 reflected = reflect(-v, n);
	vec2 uv = vec2(atan(reflected.x, reflected.z) / 6.283185 + .5,
		acos(clamp(reflected.y, -1., 1.)) / 3.141593);
	vec3 env = texture(environment_map, uv).rgb;
	float fresnel = pow(1. - clamp(dot(n, v), 0., 1.), 4.);
	float sweep = pow(clamp(dot(reflected, normalize(vec3(-.4, .8, .45))), 0., 1.), 72.);
	ALBEDO = paint_color.rgb * .85;
	EMISSION = env * (.06 + fresnel * .32) + vec3(1., .94, .8) * sweep * .45;
	ROUGHNESS = .22;
	SPECULAR = .08;
}
