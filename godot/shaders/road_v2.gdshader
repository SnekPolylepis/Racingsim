shader_type spatial;
// TrackAsset asphalt (Look-8, ART-DIRECTION.md "Road"): a 2K photographic asphalt set tiled in metres in
// both directions, a procedural non-repeating macro layer (broad shading, repair patches with tar seams,
// a rubbered line), white edge lines, and after-hours amber lamp streaks. RoadBuilder UVs are metres
// (UV.x across the road from the centreline, UV.y along it); UV2.x is metres to the nearer tarmac edge
// (0 on the edge; 0 everywhere on meshes that don't provide it). Lamp logic uses the lateral fraction of a
// nominal half-width. The streaks sit
// under the TrackAsset's real lamps: scripts/track/track_lights.gd writes `lamp_data`, texel x covering
// `lamp_cell` metres of station, each row two lamps as (station, side * strength), nearest first.
// Look-9 adds a camera-proximity streak standing in for the car's own headlights on wet tarmac.
render_mode cull_disabled;
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D rough_tex : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap, repeat_enable;
uniform bool afterhours = false;
uniform float half_width = 5.0;
// Metres per repeat of the photo texture, along and across.
uniform float tile_m = 3.5;
uniform float rubber = 0.35;
// Edge line: `edge_line_inset` metres inside the tarmac edge, `edge_line_width` wide (ART-DIRECTION: ~0.12 m).
uniform float edge_line_inset = 0.25;
uniform float edge_line_width = 0.12;
uniform float macro = 1.0;
// Share of the sharp photo grain kept over a softer mip (the rest is the softened texture).
uniform float grain_keep = 0.18;
uniform sampler2D lamp_data : filter_nearest, repeat_disable;
uniform bool lamp_map = false;
uniform float lamp_cell = 4.0;
uniform float lamp_reach = 29.0;
// Closed roads wrap station distance at their length; 0 for an open road.
uniform float road_length = 0.0;
// A concrete-slab band (the Nordschleife's Karussell bowl), set per road instance: (from, to) station
// metres along UV.y and (min, max) metres across UV.x. Unused (from == to) everywhere else.
instance uniform vec4 concrete_band = vec4(0.0);
varying vec3 world_pos;

varying float edge_dist;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	edge_dist = UV2.x;
}

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

vec3 to_srgb(vec3 c) {
	return mix(c * 12.92, 1.055 * pow(max(c, vec3(0.)), vec3(1. / 2.4)) - .055, step(vec3(.0031308), c));
}

void fragment() {
	float lat = clamp(UV.x / half_width, -1.3, 1.3);
	vec2 uv = UV / tile_m;
	// A second, rotated sample at another scale, blended by broad noise, hides the photo's repeat.
	vec2 uv_b = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8)) * UV / (tile_m * 1.37) + vec2(0.31, 0.17);
	float blend_ab = smoothstep(0.35, 0.65, vnoise(UV * vec2(0.09, 0.05)));
	// The photo's aggregate speckle reads as gravel at the 640x448 raster: keep 40 % of the sharp sample
	// over a softer mip (bias 2.5) so the grain is visible but the macro layer carries the look.
	vec3 fine = mix(texture(albedo_tex, uv).rgb, texture(albedo_tex, uv_b).rgb, blend_ab);
	vec3 soft = mix(texture(albedo_tex, uv, 2.5).rgb, texture(albedo_tex, uv_b, 2.5).rgb, blend_ab);
	vec3 base = mix(soft, fine, grain_keep);
	base = mix(vec3(dot(base, vec3(0.2126, 0.7152, 0.0722))), base, 0.35);
	float rough_t = mix(texture(rough_tex, uv).r, texture(rough_tex, uv_b).r, blend_ab);
	vec3 nrm = mix(texture(normal_tex, uv).rgb, texture(normal_tex, uv_b).rgb, blend_ab);
	float wear = rough_t;
	// Macro layer: broad tonal drift over 10-40 m.
	float drift = vnoise(UV * vec2(0.12, 0.035)) * 0.6 + vnoise(UV * vec2(0.4, 0.11)) * 0.4;
	float shade = 1.0 + macro * (drift - 0.5) * 0.5;
	// Repair patches: cells 22 m long, three lanes across; about one cell in four holds a patch, darker
	// (fresh tar) or lighter (older asphalt), with a thin tar seam round its edge.
	vec2 cell = vec2(floor((UV.x + 12.0) / 4.0), floor(UV.y / 22.0));
	float h = hash(cell);
	float patch = 0.0;
	float seam = 0.0;
	if (h < 0.24 * macro) {
		vec2 local = vec2(fract((UV.x + 12.0) / 4.0) * 4.0, fract(UV.y / 22.0) * 22.0);
		vec2 lo = vec2(0.3 + hash(cell + 3.1) * 0.8, 1.0 + hash(cell + 5.7) * 6.0);
		vec2 hi = lo + vec2(1.8 + hash(cell + 7.3) * 1.6, 5.0 + hash(cell + 9.1) * 10.0);
		vec2 inside = step(lo, local) * step(local, hi);
		patch = inside.x * inside.y;
		vec2 d = min(abs(local - lo), abs(hi - local));
		seam = patch * (1.0 - smoothstep(0.04, 0.09, min(d.x, d.y)));
	}
	float patch_tone = hash(cell + 1.9) < 0.6 ? 0.72 : 1.18;
	shade *= mix(1.0, patch_tone, patch);
	shade *= 1.0 - seam * 0.55;
	// Irregular dark stains (oil, old tar, damp), as on GT4's Nordschleife: thresholded noise over 3-15 m.
	float blot = vnoise(UV * vec2(0.28, 0.09) + vec2(17.0, 3.0)) * 0.65 + vnoise(UV * vec2(0.9, 0.3)) * 0.35;
	shade *= 1.0 - macro * 0.48 * smoothstep(0.5, 0.72, blot);
	// Rubbered line: a soft darker band down the middle, where cars run.
	float line = exp(-pow(abs(lat * 1.6), 2.0));
	shade *= 1.0 - rubber * 0.3 * line;
	// Day: near-neutral grey (ART-DIRECTION: saturation <= 0.20); night: darker, slightly cool.
	// LOOK-NIGHT-01: night asphalt stays dark (GT4/NFSU nights): at 0.95 it lit to a cream sheet.
	vec3 col = afterhours ? base * 0.6 * shade + vec3(.003, .004, .006) : base * 1.55 * shade;
	// Concrete bowl: pale, slightly warm slabs 2.5 m long with dark joints and a joint down the trough.
	float concrete = 0.0;
	if (concrete_band.y > concrete_band.x) {
		concrete = smoothstep(concrete_band.x, concrete_band.x + 4.0, UV.y)
			* (1.0 - smoothstep(concrete_band.y - 4.0, concrete_band.y, UV.y))
			* smoothstep(concrete_band.z, concrete_band.z + 0.25, UV.x)
			* (1.0 - smoothstep(concrete_band.w - 0.25, concrete_band.w, UV.x));
		float joint_along = smoothstep(0.47, 0.49, abs(fract(UV.y / 2.5) - 0.5));
		float joint_across = 1.0 - smoothstep(0.02, 0.06, abs(UV.x - (concrete_band.z + concrete_band.w) * 0.5));
		float slab = 0.9 + 0.2 * hash(vec2(floor(UV.y / 2.5), floor(UV.x)));
		// LOOK-16: weathered mid-grey. At 0.47 the bowl read near white (snow) against the lap's tarmac and forest.
		vec3 conc = vec3(0.3, 0.295, 0.28) * slab * mix(1.0, 0.55, max(joint_along, joint_across));
		conc = mix(conc, conc * 0.8, smoothstep(0.55, 0.8, blot));
		col = mix(col, afterhours ? conc * 0.6 : conc, concrete);
	}
	// White edge lines, `edge_line_inset` inside each tarmac edge, softened a little and worn by grain.
	float line_d = abs(edge_dist - (edge_line_inset + edge_line_width * 0.5));
	float aa = max(fwidth(edge_dist), 0.01);
	float paint = (edge_dist > 0.001) ? 1.0 - smoothstep(edge_line_width * 0.5 - aa, edge_line_width * 0.5 + aa, line_d) : 0.0;
	paint *= 0.8 + 0.2 * smoothstep(0.2, 0.5, base.r);
	col = mix(col, vec3(afterhours ? 0.42 : 0.78), paint);
	NORMAL_MAP = mix(nrm, vec3(0.5, 0.5, 1.0), paint * 0.7);
	NORMAL_MAP_DEPTH = 0.8;
	// Amber sodium lamps from the lamp texture: a pool under each lamp plus a glossy streak on its side.
	vec3 neon = vec3(0.95, 0.63, 0.28);
	float glow = 0.0;
	vec3 reflected = vec3(0.0);
	if (afterhours && lamp_map) {
		int width = textureSize(lamp_data, 0).x;
		int ix = clamp(int(floor(UV.y / lamp_cell)), 0, width - 1);
		for (int row = 0; row < 3; row++) {
			vec4 t = texelFetch(lamp_data, ivec2(ix, row), 0);
			for (int k = 0; k < 2; k++) {
				float s = k == 0 ? t.x : t.z;
				float code = k == 0 ? t.y : t.w;
				float d = abs(UV.y - s);
				if (road_length > 0.0) {
					d = min(d, road_length - d);
				}
				float side = sign(code);
				float fall = pow(max(0.0, 1.0 - d / lamp_reach), 1.5) * abs(code);
				float lateral = exp(-pow(abs((lat - side * 0.65) * 1.7), 2.0));
				float pool = fall * fall * exp(-pow(abs(lat - side * 0.8) * 0.9, 2.0));
				float reflection = exp(-abs((lat - side * .35) * 5.5));
				glow += (fall * lateral + pool * .25) * .6;
				// LOOK-NIGHT-01: streak 1.2 -> .45; at full strength the painted streaks of a lamp-lined
				// straight merged into one cream band from the camera to the horizon.
				reflected += neon * (fall * lateral * (.03 + reflection * .45) + pool * .08);
			}
		}
	}
	// Wet camera-proximity streak (Look-9, ART-DIRECTION "Nights"): a cheap PS2-style stand-in for the
	// car's own headlights reflecting on wet tarmac (nfsu-night-wet-street-reflections.jpg) — no per-frame
	// uniform needed, since CAMERA_POSITION_WORLD already tracks wherever the chase/bonnet camera (and so
	// the car) is. Narrow across the road (reuses `lat`) and fades over about 26 m, so it reads as a
	// streak running down the lane toward the camera rather than a puddle centred on it.
	if (afterhours) {
		float cam_dist = length(world_pos - CAMERA_POSITION_WORLD);
		float near_cam = pow(max(0.0, 1.0 - cam_dist / 26.0), 2.2);
		float head_lat = exp(-pow(lat * 2.0, 2.0));
		float head_glow = near_cam * head_lat;
		// LOOK-NIGHT-01: faint, so it no longer paints a white patch round the car.
		glow += head_glow * 0.1;
		reflected += vec3(1.0, 0.96, 0.88) * head_glow * 0.12;
	}
	// LOOK-NIGHT-01: lower caps, so a lamp-lined straight (Spa) is a row of pools, not one amber sheet.
	glow = min(glow, 0.6);
	reflected = min(reflected, vec3(0.55));
	EMISSION = (OUTPUT_IS_SRGB ? to_srgb(reflected) : reflected) + col * 0.045;
	ALBEDO = col + neon * glow * 0.18;
	// Matte by day (no glare toward the sun); a wet-looking sheen at night for the NFSU lamp streaks.
	// LOOK-NIGHT-01: a damp sheen, not a mirror: at roughness 0.3 / metallic 0.18 the headlights and sky
	// washed the whole road cream. The amber streaks are emission and keep their gloss.
	METALLIC = afterhours ? 0.04 : 0.0;
	SPECULAR = afterhours ? 0.3 : 0.5;
	ROUGHNESS = afterhours ? mix(0.55, 0.75, wear) : mix(0.72, 0.95, wear) - seam * 0.1 + paint * 0.05;
	ROUGHNESS = mix(ROUGHNESS, 0.9, concrete);
}
