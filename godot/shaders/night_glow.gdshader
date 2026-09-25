shader_type spatial;
// Shared facade material for trackside structures (Look-9, ART-DIRECTION.md "Nights"): pit building,
// grandstand, gantry and billboards. By day this renders exactly like the StandardMaterial3D it
// replaces (vertex COLOR as albedo). After hours it adds two independent emissive layers on
// near-vertical faces only (|world_normal.y| < the given threshold), so roof/seat-tread top faces never
// glow:
//   - a procedural amber window grid on desaturated surfaces (concrete, doors, steel: pit-building and
//     grandstand walls), keyed off world position so no UVs are needed;
//   - the surface's own colour, boosted, on already-saturated surfaces (gantry's red/green start
//     lights, a billboard's printed panel stripes) — a cheap stand-in for backlit signage/signal lights.
// Together with the hill silhouette (RetroAssets.hills_panorama) this is what keeps night captures from
// reading as a black void beyond the lit road.
render_mode cull_back;
uniform bool afterhours = false;
uniform float window_scale = 1.35;
uniform float lit_chance = 0.4;

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec3 col = COLOR.rgb;
	ALBEDO = col;
	ROUGHNESS = 0.85;
	vec3 glow = vec3(0.0);
	if (afterhours && abs(world_normal.y) < 0.5) {
		float mx = max(col.r, max(col.g, col.b));
		float mn = min(col.r, min(col.g, col.b));
		float sat = mx > 0.001 ? (mx - mn) / mx : 0.0;
		// A coordinate that runs along the wall regardless of which way it faces, no UVs required.
		float along = world_pos.x + world_pos.z;
		if (sat > 0.5) {
			// Saturated surface: a start light or a printed sign panel. Let it glow in its own hue.
			glow = col * 1.6;
		} else if (abs(world_normal.y) < 0.4) {
			// Desaturated wall: a procedural grid of lit windows, amber, only some cells lit.
			vec2 cell = floor(vec2(along, world_pos.y) / window_scale);
			float h = hash21(cell);
			if (h < lit_chance) {
				vec2 local = fract(vec2(along, world_pos.y) / window_scale);
				vec2 pane = step(vec2(0.15), local) * step(local, vec2(0.85));
				float lit = pane.x * pane.y * (0.55 + 0.45 * hash21(cell + 5.2));
				glow = vec3(1.0, 0.78, 0.45) * lit;
			}
		}
	}
	EMISSION = glow;
}
