shader_type spatial;
// Chicago building walls (CHI-02). Photo facade textures by day: an ambientCG CC0 set tiled in metres (UV.x is
// the distance along the footprint's perimeter, UV.y the height above the base, both in metres). After hours
// a window grid glows on the walls, one cell per floor and bay; a cell is lit by a stable hash of the
// building (`building_seed`, from the vertex colour's red channel) and the cell. The uniform is `afterhours`,
// like night_glow.gdshader, so NightGlow.set_night() toggles it.
render_mode cull_disabled;
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D rough_tex : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform vec2 tile_m = vec2(9.0, 9.0);
uniform vec3 tint : source_color = vec3(1.0);
uniform bool afterhours = false;
// Floor height and bay width (m) of the night window grid, and the share of lit windows.
uniform vec2 window_cell = vec2(3.6, 3.9);
uniform float lit_chance = 0.32;
uniform float glow_energy = 1.4;
// 1 for glass towers (more, cooler windows), 0 for masonry (fewer, warmer).
uniform float glassy = 0.0;
// Daytime window grid (CHI-LOOK-01): the same cells as the night windows, drawn as dark glass panes with
// sills and a darker storefront band on the ground floor. 0 leaves the bare photo texture.
uniform float day_windows = 1.0;

varying float seed;

void vertex() {
	seed = COLOR.r;
}

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 uv = UV / tile_m;
	vec3 base = texture(albedo_tex, uv).rgb * tint;
	ALBEDO = base;
	NORMAL_MAP = texture(normal_tex, uv).rgb;
	ROUGHNESS = texture(rough_tex, uv).r;
	METALLIC = glassy * 0.35;
	vec2 cell = floor(UV / window_cell);
	vec2 f = fract(UV / window_cell);
	if (!afterhours && day_windows > 0.0) {
		// Fade the grid out where a cell is under about 3 pixels, so distant towers do not shimmer.
		vec2 w = fwidth(UV / window_cell);
		float fade = 1.0 - smoothstep(0.2, 0.55, max(w.x, w.y));
		float ground = 1.0 - step(1.0, cell.y);
		float pane = step(0.14, f.x) * step(f.x, 0.86) * step(0.16, f.y) * step(f.y, 0.8);
		// Ground floor: one continuous darker storefront band instead of separate panes.
		pane = mix(pane, step(0.05, f.x) * step(f.x, 0.95) * step(0.12, f.y) * step(f.y, 0.85), ground);
		float sill = step(f.y, 0.16) * (1.0 - ground);
		float tone = hash21(cell + seed * 41.0);
		// Glass towers reflect more sky; masonry windows are darker and deeper set.
		vec3 glass = mix(vec3(0.07, 0.09, 0.12), vec3(0.32, 0.4, 0.5), glassy * (0.35 + 0.5 * tone));
		glass = mix(glass, vec3(0.11, 0.1, 0.09), ground * 0.6);
		vec3 lit_base = base * mix(1.0, 0.82, sill);
		ALBEDO = mix(base, mix(lit_base, glass, pane), fade * day_windows);
		float glossy = pane * fade * day_windows;
		ROUGHNESS = mix(ROUGHNESS, 0.18, glossy);
		METALLIC = mix(METALLIC, 0.0, glossy);
		NORMAL_MAP = mix(NORMAL_MAP, vec3(0.5, 0.5, 1.0), glossy);
	}
	if (afterhours) {
		// A window pane inside each cell (not the spandrel or mullions), above the ground floor.
		float pane = step(0.18, f.x) * step(f.x, 0.82) * step(0.22, f.y) * step(f.y, 0.78) * step(1.0, cell.y);
		float lit = step(1.0 - lit_chance - glassy * 0.12, hash21(cell + seed * 97.0));
		vec3 warm = vec3(1.0, 0.72, 0.38);
		vec3 cool = vec3(0.72, 0.84, 1.0);
		vec3 light = mix(warm, cool, glassy * step(0.5, hash21(cell.yx + seed * 13.0)));
		ALBEDO = base * 0.35;
		EMISSION = light * pane * lit * glow_energy;
	}
}
