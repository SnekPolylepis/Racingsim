shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_prepass_alpha;

uniform sampler2D atlas : source_color, filter_linear_mipmap;
varying float particle_frame;

void vertex() {
	particle_frame = INSTANCE_CUSTOM.x;
	float scale = length(MODEL_MATRIX[0].xyz);
	vec3 center = MODEL_MATRIX[3].xyz;
	vec3 right = INV_VIEW_MATRIX[0].xyz;
	vec3 up = INV_VIEW_MATRIX[1].xyz;
	vec3 world_position = center + (right * VERTEX.x + up * VERTEX.y) * scale;
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(world_position, 1.0);
}

void fragment() {
	int frame = int(particle_frame + 0.5);
	vec2 cell = vec2(float(frame % 4), float(frame / 4));
	vec2 uv = cell * vec2(0.25, 0.5) + UV * vec2(0.25, 0.5);
	vec4 texel = texture(atlas, uv);
	ALBEDO = COLOR.rgb * texel.rgb;
	ALPHA = COLOR.a * texel.a;
}
