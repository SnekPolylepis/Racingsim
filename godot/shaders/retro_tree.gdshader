shader_type spatial;
render_mode vertex_lighting, cull_disabled;
uniform sampler2D painted_tree : source_color, filter_linear_mipmap, repeat_disable;
void fragment() {
	vec4 ink = texture(painted_tree, UV);
	ALBEDO = ink.rgb * COLOR.rgb;
	ALPHA = ink.a;
	ALPHA_SCISSOR_THRESHOLD = .48;
	ROUGHNESS = 1.;
}
