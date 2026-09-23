shader_type spatial;
// Painted concrete for curbs and white lines: vertex colour is the paint, concrete adds grain and relief.
render_mode cull_back;
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D rough_tex : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform float tile = 0.5;
varying vec3 world_pos;
void vertex() { world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec2 uv = world_pos.xz * tile;
	float grain = dot(texture(albedo_tex, uv).rgb, vec3(0.333));
	ALBEDO = COLOR.rgb * mix(0.78, 1.08, grain);
	ROUGHNESS = clamp(texture(rough_tex, uv).r * 0.9, 0.3, 1.0);
}
