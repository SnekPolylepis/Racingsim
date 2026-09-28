shader_type spatial;
// Chicago retaining and river walls (CHI-SC-2): poured concrete, not a flat tint. World-projected Concrete034
// with vertical form joints every `panel_m`, a lighter coping strip at street level, grime darkening toward
// the base and rain streaks running down from the top. The flat 0.7 tint read as blockout.
uniform sampler2D concrete_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform float tile_m = 3.0;
uniform float panel_m = 3.0;
uniform float street_y = 8.0;
uniform vec3 tint : source_color = vec3(0.66, 0.65, 0.62);
// Lower Wacker: pilasters every `pilaster_m` (0 = none). Vertex colour (white on meshes without it) carries
// the height fraction up the wall (r) and deck cover at the top (b = 0), for road spray and exhaust soot.
uniform float pilaster_m = 0.0;
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
	if (pilaster_m > 0.0) {
		// Lower Wacker (docs/art/reference/chicago/lower-wacker-drive.jpg, -tunnel-day.jpg). h: metres above
		// the wall's foot, from vertex colour (r = height fraction, g = wall height / 10).
		float h = COLOR.r * COLOR.g * 10.0;
		// Pilaster: a lighter 0.9 m face with shadowed edges where it steps out of the wall.
		float in_bay = abs(fract(along / pilaster_m) - 0.5) * pilaster_m;
		float face = 1.0 - smoothstep(0.42, 0.45, in_bay);
		float edge = smoothstep(0.38, 0.45, in_bay) * (1.0 - smoothstep(0.45, 0.55, in_bay));
		base *= mix(1.0, 1.12, face) * (1.0 - 0.35 * edge);
		// The pale knee-high parapet along the road, with yellow safety paint on the pilaster feet.
		float parapet = 1.0 - smoothstep(1.12, 1.15, h);
		base = mix(base, base * 1.35 + 0.05, parapet * (1.0 - face));
		base = mix(base, vec3(0.6, 0.48, 0.1), parapet * face * 0.85);
		base *= 1.0 - 0.5 * (smoothstep(1.12, 1.15, h) - smoothstep(1.17, 1.2, h));
		// Loading-dock roll-up doors in about one bay in five under the deck (covered walls are under 6.5 m):
		// corrugated grey-green steel, 4.2 m wide and 4 m high, in a dark frame, breaking the parapet.
		float bay_x = fract(along / pilaster_m) * pilaster_m;
		float dock = step(COLOR.g * 10.0, 6.5) * step(hash11(floor(along / pilaster_m) * 1.37 + 5.0), 0.2);
		float in_door = dock * step(abs(bay_x - pilaster_m * 0.5), 2.1) * step(h, 4.0);
		float frame = dock * step(abs(bay_x - pilaster_m * 0.5), 2.3) * step(h, 4.2) * (1.0 - in_door);
		vec3 steel = vec3(0.3, 0.33, 0.31) * (0.82 + 0.18 * sin(h * 42.0)) * (0.8 + 0.2 * smoothstep(0.0, 1.5, h));
		base = mix(base, steel, in_door);
		base = mix(base, base * 0.35, frame);
		// Wet road spray at the foot; exhaust soot creeping down from a covering deck (b = 0 at its top).
		base *= mix(0.7, 1.0, smoothstep(0.0, 0.45, h));
		base *= 1.0 - 0.7 * (1.0 - COLOR.b) * smoothstep(0.45, 1.0, COLOR.r);
		// Leak stains running down from the deck joints over each pilaster bay.
		float leak = hash11(floor(along / 2.0) + 3.0);
		base *= 1.0 - 0.25 * step(0.72, leak) * (1.0 - COLOR.b) * smoothstep(0.2, 0.9, COLOR.r);
	}
	ALBEDO = base;
	ROUGHNESS = 0.92;
	SPECULAR = 0.25;
}
