shader_type spatial;
// Chicago retaining and river walls (CHI-SC-2): poured concrete, not a flat tint. World-projected Concrete034
// with vertical form joints every `panel_m`, a lighter coping strip at street level, grime darkening toward
// the base and rain streaks running down from the top. The flat 0.7 tint read as blockout.
uniform sampler2D concrete_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform float tile_m = 3.0;
uniform float panel_m = 3.0;
uniform float street_y = 8.0;
uniform vec3 tint : source_color = vec3(0.66, 0.65, 0.62);
varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

float hash11(float x) {
	return fract(sin(x * 127.1) * 43758.5453);
}

void fragment() {
	// Along-wall coordinate: the horizontal axis that runs along this face.
	vec3 n = abs(world_normal);
	float along = n.x > n.z ? world_pos.z : world_pos.x;
	vec2 uv = vec2(along, world_pos.y) / tile_m;
	vec3 base = texture(concrete_tex, uv).rgb * tint;
	// Pour panels: each a slightly different shade, dark joints between them.
	float panel = floor(along / panel_m);
	base *= 0.9 + 0.2 * hash11(panel);
	float from_mid = abs(fract(along / panel_m) - 0.5) * panel_m;
	float joint = smoothstep(panel_m * 0.5 - 0.08, panel_m * 0.5 - 0.03, from_mid);
	base *= 1.0 - 0.45 * joint;
	// Rain streaks from the top edge down, a few per panel.
	float streak = hash11(floor(along * 1.7) + panel * 7.0);
	float below_top = clamp((street_y - world_pos.y) / 4.0, 0.0, 1.0);
	base *= 1.0 - 0.22 * step(0.7, streak) * (1.0 - below_top * 0.6);
	// Grime toward the base (river walls reach the waterline, the Lower Wacker cut its floor).
	float from_base = clamp((world_pos.y + 3.0) / 6.0, 0.0, 1.0);
	base *= mix(0.62, 1.0, from_base);
	// Lighter coping strip along the top at street level.
	float coping = smoothstep(street_y - 0.4, street_y - 0.3, world_pos.y);
	base = mix(base, base * 1.25 + 0.03, coping);
	ALBEDO = base;
	ROUGHNESS = 0.92;
	SPECULAR = 0.25;
}
