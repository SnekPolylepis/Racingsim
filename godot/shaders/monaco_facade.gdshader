shader_type spatial;
// Monaco apartment facades (MON-05), procedural: pastel render, a window bay every 3.4 m on 3.1 m floors,
// shutters on some buildings, a balcony slab and railing along each floor on most, a darker shopfront
// ground floor, terracotta or grey roofs. After hours a share of windows glow warm.
// UV: x = metres along the footprint perimeter, y = metres above the base. Vertex colour (as chicago_facade):
// r = building seed, b = 1 on roofs, a = 6x6x6 palette index + 1 of the render colour.
uniform bool afterhours = false;
const float FLOOR = 3.1;
const float BAY = 3.4;

varying flat vec4 info;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	info = COLOR;
}

void fragment() {
	float seed = info.r;
	float code = info.a * 255.0 - 1.0;
	vec3 render = code >= 0.0
		? vec3(floor(code / 36.0), mod(floor(code / 6.0), 6.0), mod(code, 6.0)) / 5.0
		: vec3(0.9, 0.86, 0.78);
	if (info.b > 0.5) {
		ALBEDO = hash(vec2(seed, 3.0)) < 0.6 ? vec3(0.62, 0.36, 0.26) : vec3(0.5, 0.5, 0.48);
		ROUGHNESS = 0.9;
	} else {
		vec2 cell = vec2(floor(UV.x / BAY), floor(UV.y / FLOOR));
		vec2 f = vec2(fract(UV.x / BAY) * BAY, fract(UV.y / FLOOR) * FLOOR);
		bool balconies = hash(vec2(seed, 1.0)) < 0.75;
		bool shutters = hash(vec2(seed, 2.0)) < 0.5;
		vec3 shutter_c = hash(vec2(seed, 4.0)) < 0.5 ? vec3(0.22, 0.38, 0.28) : vec3(0.55, 0.55, 0.52);
		vec3 col = render * (0.95 + 0.05 * hash(cell));
		float glass = 0.0;
		bool ground = UV.y < 4.0;
		if (ground) {
			// Shopfront: tall glass bays with a dark fascia above.
			glass = step(0.25, f.x) * step(f.x, BAY - 0.25) * step(0.3, UV.y) * step(UV.y, 3.2);
			col = mix(col * 0.8, vec3(0.08, 0.1, 0.12), glass);
		} else {
			float win = step(1.0, f.x) * step(f.x, 2.4) * step(0.55, f.y) * step(f.y, 2.55);
			float shut = shutters ? (step(0.6, f.x) * step(f.x, 0.98) + step(2.42, f.x) * step(f.x, 2.8))
				* step(0.55, f.y) * step(f.y, 2.55) : 0.0;
			glass = win;
			col = mix(col, shutter_c, shut);
			col = mix(col, vec3(0.1, 0.13, 0.17), win);
			if (balconies) {
				// Slab edge at the floor line, white railing above it, its shadow just below.
				float slab = step(f.y, 0.22);
				float rail = step(0.22, f.y) * step(f.y, 1.05) * (0.55 + 0.45 * step(0.5, fract(UV.x * 4.0)));
				float shade = step(FLOOR - 0.35, f.y);
				col = mix(col, vec3(0.93, 0.92, 0.9), slab);
				col = mix(col, vec3(0.85, 0.85, 0.83), rail * 0.6);
				col *= 1.0 - 0.35 * shade;
			}
		}
		ALBEDO = col;
		ROUGHNESS = mix(0.85, 0.15, glass);
		if (afterhours && glass > 0.5 && hash(cell + seed * 17.0) < (ground ? 0.7 : 0.35)) {
			EMISSION = vec3(1.0, 0.78, 0.5) * 1.6;
		}
	}
}
