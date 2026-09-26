shader_type spatial;
// Terrain and verges: grass everywhere, gravel where the circuit paint mask says so (the same
// 2 m cells the physics reads). Two texture scales plus a macro variation map hide tiling.
render_mode cull_back;
uniform sampler2D grass_albedo : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D grass_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D grass_rough : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform sampler2D gravel_albedo : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D gravel_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D gravel_rough : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform sampler2D runoff_albedo : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D runoff_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D runoff_rough : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform sampler2D paint_mask : hint_default_black, filter_linear, repeat_disable;
uniform vec2 mask_origin = vec2(0.0);
uniform vec2 mask_size = vec2(1.0);
uniform vec3 grass_tint : source_color = vec3(0.78, 1.0, 0.62);
uniform float grass_tile = 0.16;
uniform float gravel_tile = 0.42;
varying vec3 world_pos;

void vertex() { world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
vec3 linear_sample(vec3 c) { return OUTPUT_IS_SRGB ? pow(max(c, vec3(0.)), vec3(2.2)) : c; }

void fragment() {
	vec2 w = world_pos.xz;
	float dist = length(world_pos - CAMERA_POSITION_WORLD);
	float far = smoothstep(30.0, 220.0, dist);
	vec2 g1 = w * grass_tile; vec2 g2 = w * grass_tile * 0.19 + vec2(0.21, 0.73);
	vec3 grass = mix(mix(linear_sample(texture(grass_albedo, g1).rgb), linear_sample(texture(grass_albedo, g2).rgb), 0.45), linear_sample(texture(grass_albedo, g2).rgb), far);
	float macro = texture(grass_albedo, w * 0.0031).g;
	float macro2 = texture(grass_albedo, w * 0.00083 + vec2(0.5)).r;
	grass *= grass_tint * mix(0.78, 1.18, smoothstep(0.08, 0.2, macro)) * mix(0.9, 1.08, smoothstep(0.06, 0.16, macro2));
	vec2 p1 = w * gravel_tile; vec2 p2 = w * gravel_tile * 0.27 + vec2(0.4, 0.1);
	vec3 gravel = mix(linear_sample(texture(gravel_albedo, p1).rgb), linear_sample(texture(gravel_albedo, p2).rgb), 0.3 + far * 0.7);
	vec2 mask = texture(paint_mask, (w - mask_origin) / mask_size).rg;
	float edge_noise = texture(gravel_albedo, w * 0.09).r - 0.5;
	float m = smoothstep(.38, .62, mask.r);
	// Tarmac runoff keeps a crisp edge (it is laid, not spread) and reads a little lighter than the circuit.
	float t = smoothstep(.46, .54, mask.g);
	vec2 r1 = w * 0.32; vec2 r2 = w * 0.074 + vec2(0.37, 0.61);
	// LOOK-13: 4.8 x (0.84, 0.98, 1.2) made runoff a pale blue-grey sheet; beyond ~700 m, fogged, Spa's big
	// runoffs read as lakes on the horizon. Now just a touch lighter than the circuit's asphalt, neutral.
	vec3 runoff = mix(linear_sample(texture(runoff_albedo, r1).rgb), linear_sample(texture(runoff_albedo, r2).rgb), 0.35 + far * 0.65) * 2.9 * vec3(0.96, 0.98, 1.02);
	// Graded to a lush Ardennes/Eifel green (mean about sRGB 70,100,40 in sun) from the dry-grass photo;
	// the old (1.65, 1.6, 1.2) grade read khaki on whole hillsides once terrain used this shader.
	// LOOK-13: yellower and a little less saturated. Measured on the Nordschleife verges, (0.62, 1.08, 0.7) gave
	// hue 0.27 / saturation 0.74 against GT4's 0.19 / 0.64 and the real circuit's 0.21 / ~0.5.
	vec3 styled_grass = grass * vec3(0.95, 1.0, 0.4);
	styled_grass = mix(vec3(dot(styled_grass, vec3(0.2126, 0.7152, 0.0722))), styled_grass, 0.85);
	vec3 styled_gravel = gravel * vec3(1.1, 1.12, 1.0);
	ALBEDO = mix(mix(styled_grass, styled_gravel, m), runoff, t) * COLOR.rgb;
	if (OUTPUT_IS_SRGB) ALBEDO = pow(max(ALBEDO, vec3(0.)), vec3(1. / 2.2));
	EMISSION = ALBEDO * 0.025;
	// LOOK-13: grass and gravel never below 0.85 roughness, with low specular. From ~0.3 roughness, distant
	// valley grass at a grazing angle mirrored the pale horizon sky and read as lakes (Spa, Nordschleife).
	float rough_nat = max(mix(texture(grass_rough, g1).r, texture(gravel_rough, p1).r, m), 0.85);
	ROUGHNESS = mix(rough_nat, texture(runoff_rough, r1).r, t);
	// Zero specular on grass and gravel: Godot's grazing Fresnel is clamp(50 * F0), so even rough grass at
	// SPECULAR 0.2 mirrored about a third of the sky on distant flat ground, the "lakes" on Spa's horizon.
	SPECULAR = mix(0.0, 0.3, t);
	vec3 ng = mix(texture(grass_normal, g1).rgb, texture(grass_normal, g2).rgb, far);
	vec3 np = texture(gravel_normal, p1).rgb;
}
