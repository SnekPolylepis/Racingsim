shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
void fragment() {
	ALBEDO = vec3(.045, .055, .04);
	ALPHA = COLOR.a;
}
