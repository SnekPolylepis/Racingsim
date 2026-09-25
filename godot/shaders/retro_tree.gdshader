shader_type spatial;
render_mode vertex_lighting, cull_disabled;
// Photographic tree cards from one atlas (assets/trees/tree_atlas.png). INSTANCE_CUSTOM is the card's
// [u, v, w, h] rectangle, INSTANCE_COLOR a near-white tint. Alpha-scissored, never blended.
uniform sampler2D tree_atlas : source_color, filter_linear_mipmap, repeat_disable;
uniform float alpha_cut = .34;
varying float height01;
void vertex() {
	height01 = 1. - UV.y;
	UV = INSTANCE_CUSTOM.xy + UV * INSTANCE_CUSTOM.zw;
}
void fragment() {
	vec4 ink = texture(tree_atlas, UV);
	// Canopy occlusion: the lower crown and trunk sit darker than the sunlit top.
	float shade = mix(.55, 1., smoothstep(0., .55, height01));
	ALBEDO = ink.rgb * COLOR.rgb * shade;
	ALPHA = ink.a;
	ALPHA_SCISSOR_THRESHOLD = alpha_cut;
	ROUGHNESS = 1.;
}
