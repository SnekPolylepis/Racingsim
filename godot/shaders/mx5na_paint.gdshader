shader_type spatial;
render_mode blend_mix;

uniform sampler2D body_texture : source_color, filter_linear_mipmap;
uniform sampler2D body_normal : hint_normal, filter_linear_mipmap;
uniform sampler2D environment_map : source_color, filter_linear_mipmap, repeat_disable;
uniform vec4 paint_color : source_color = vec4(0.757, 0.153, 0.176, 1.0);

varying vec3 world_normal;
varying vec3 world_position;

void vertex() {
 world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
 world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
 vec3 source = texture(body_texture, UV).rgb;
 float cream = source.r - source.b * 0.75;
 float mask = smoothstep(0.12, 0.23, cream);
 float shade = clamp(dot(source, vec3(0.30, 0.59, 0.11)) / 0.55, 0.38, 1.2);
 vec3 ink = mix(source, paint_color.rgb * shade, mask);
 vec3 n = normalize(world_normal);
 vec3 v = normalize(CAMERA_POSITION_WORLD - world_position);
 vec3 reflected = reflect(-v, n);
 vec2 env_uv = vec2(atan(reflected.x, reflected.z) / 6.283185 + 0.5, acos(clamp(reflected.y, -1.0, 1.0)) / 3.141593);
 float fresnel = pow(1.0 - clamp(dot(n, v), 0.0, 1.0), 4.0);
 ALBEDO = ink * 0.85;
 EMISSION = texture(environment_map, env_uv).rgb * (0.035 + fresnel * 0.2 * mask);
 NORMAL_MAP = texture(body_normal, UV).rgb;
 NORMAL_MAP_DEPTH = 0.45;
 ROUGHNESS = mix(0.65, 0.27, mask);
 SPECULAR = 0.12;
}
