shader_type spatial;
// Glass on the Blender-modelled Monaco exteriors (monaco.gd _frontage): dark reflective panes by day; after
// hours a share of windows glow warm, as monaco_facade.gdshader does for the extruded blocks. Each pane is
// its own quad, so a hash of its world-space cell (about one window bay by one storey) picks it.
uniform bool afterhours = false;
uniform float lit_share = 0.35;
uniform float glow = 1.6;
uniform vec3 glass_color : source_color = vec3(0.05, 0.07, 0.08);

varying vec3 world;

float hash(vec3 p) {
	return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453);
}

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	ALBEDO = glass_color;
	METALLIC = 0.3;
	ROUGHNESS = 0.15;
	vec3 cell = floor(world / vec3(1.6, 3.1, 1.6));
	if (afterhours && hash(cell) < lit_share) {
		EMISSION = mix(vec3(1.0, 0.78, 0.5), vec3(1.0, 0.9, 0.75), hash(cell + 7.0)) * glow;
	}
}
