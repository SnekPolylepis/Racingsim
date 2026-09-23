shader_type canvas_item;
render_mode unshaded;
uniform sampler2D world_texture : filter_linear, repeat_disable;
uniform float threshold = .82;
void fragment() {
	vec2 px = 1.0 / vec2(textureSize(world_texture, 0));
	vec3 sum = vec3(0.);
	for (int x = -1; x <= 1; x++) {
		for (int y = -1; y <= 1; y++) {
			vec3 c = texture(world_texture, UV + vec2(float(x), float(y)) * px * 2.).rgb;
			float bright = max(c.r, max(c.g, c.b));
			sum += c * smoothstep(threshold, 1.0, bright) / 9.;
		}
	}
	COLOR = vec4(sum, 1.);
}
