shader_type spatial;
render_mode cull_disabled;
// Seated spectators with gaps between silhouettes, rather than an opaque noise wall.
void fragment() {
	float person = floor(UV.x * 8.0);
	vec2 f = vec2(fract(UV.x * 8.0), UV.y);
	float seed = fract(sin(person * 127.1) * 43758.5453);
	bool head = length((f - vec2(0.5, 0.23)) / vec2(0.13, 0.17)) < 1.0;
	bool torso = f.y > 0.38 && f.y < 0.98 && abs(f.x - 0.5) < 0.22;
	ALPHA = head || torso ? 1.0 : 0.0;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	vec3 shirt = mix(vec3(0.17, 0.28, 0.48), vec3(0.86, 0.65, 0.33), seed);
	if (seed > 0.75) { shirt = vec3(0.78, 0.22, 0.2); }
	ALBEDO = head ? mix(vec3(0.38, 0.23, 0.16), vec3(0.88, 0.68, 0.5), seed) : shirt;
	ROUGHNESS = 0.9;
}
