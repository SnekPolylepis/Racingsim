shader_type spatial;
// Generic trackside sponsor panels (MON-06): four layouts made of abstract bars, no real text or brands.
// Instance colour = panel colour; INSTANCE_CUSTOM.r = layout (0..3), .g = seed. UV per face.
varying flat vec4 pick;

float hash(float n) {
	return fract(sin(n) * 43758.5453);
}

// A row of letter-like blocks centred at `c`, width w, height h.
float word(vec2 uv, vec2 c, float w, float h, float seed) {
	vec2 d = uv - c;
	if (abs(d.x) > w * 0.5 || abs(d.y) > h * 0.5) return 0.0;
	float x = (d.x / w + 0.5) * 9.0;
	float letter = floor(x);
	float gap = step(0.18, fract(x)) * step(fract(x), 0.92);
	float tall = mix(0.55, 1.0, hash(letter + seed * 13.0));
	return gap * step(abs(d.y), h * 0.5 * tall);
}

void vertex() {
	pick = INSTANCE_CUSTOM;
}

void fragment() {
	vec3 base = COLOR.rgb;
	vec3 ink = dot(base, vec3(0.3, 0.59, 0.11)) > 0.6 ? vec3(0.08) : vec3(0.97);
	int layout = int(pick.r * 4.0);
	// BoxMesh lays its six faces out on a 3 x 2 UV grid: back to 0..1 per face.
	vec2 uv = fract(UV * vec2(3.0, 2.0));
	vec3 col = base;
	float seed = pick.g * 100.0;
	if (layout == 0) {
		col = mix(col, ink, word(uv, vec2(0.5, 0.5), 0.62, 0.42, seed));
	} else if (layout == 1) {
		float band = step(abs(uv.x - uv.y * 0.35 - 0.62), 0.05);
		col = mix(col, ink, max(band, word(uv, vec2(0.3, 0.5), 0.38, 0.38, seed)));
	} else if (layout == 2) {
		float disc = step(length((uv - vec2(0.14, 0.5)) * vec2(3.0, 1.0)), 0.3);
		col = mix(col, ink, max(disc, word(uv, vec2(0.58, 0.5), 0.6, 0.36, seed)));
	} else {
		vec3 second = vec3(hash(seed), hash(seed + 1.0), hash(seed + 2.0)) * 0.8 + 0.1;
		col = uv.x > 0.55 ? second : base;
		col = mix(col, ink, word(uv, vec2(0.27, 0.5), 0.4, 0.4, seed));
	}
	ALBEDO = col;
	ROUGHNESS = 0.55;
}
