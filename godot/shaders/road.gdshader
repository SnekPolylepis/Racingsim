shader_type spatial;
// Circuit asphalt. World-projected texture at two scales to hide tiling, plus a rubbered racing line.
// UV2.x = lateral position across the road (-1 left edge, +1 right edge); UV2.y = racing-line lateral (same units).
render_mode cull_back;
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D rough_tex : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform bool afterhours = false;
uniform float tile = 0.32;
uniform float brightness = 4.0;
uniform vec3 tint : source_color = vec3(0.93, 0.95, 1.0);
uniform float rubber = 0.55;
varying vec3 world_pos;

void vertex() { world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
vec3 from_srgb(vec3 c) {
	return mix(c / 12.92, pow((c + .055) / 1.055, vec3(2.4)), step(vec3(.04045), c));
}
vec3 to_srgb(vec3 c) {
	return mix(c * 12.92, 1.055 * pow(max(c, vec3(0.)), vec3(1. / 2.4)) - .055,
		step(vec3(.0031308), c));
}

// UV.y = arc length (m), UV.x = lateral fraction; UV2 retains the derived racing line.
void fragment() {
	vec2 uv = vec2(UV.x * 2.5, UV.y * tile);
	float dist = length(world_pos - CAMERA_POSITION_WORLD);
	float far = smoothstep(25.0, 140.0, dist);
	float grain = texture(albedo_tex, uv).r;
	// Broad graphic tones replace photo-real asphalt. Fine texture supplies only restrained grain.
	float wear = floor(clamp(grain * 6.0, 0.0, 1.0) * 5.0) / 5.0;
	vec3 col = texture(albedo_tex, uv).rgb * 2.5 + vec3(.014, .017, .021);
	float line = exp(-pow(abs((UV2.x - UV2.y) * 3.2), 2.0));
	if (!afterhours) { col = texture(albedo_tex, uv).rgb * 3.8 + vec3(.015); }
	col *= 1.0 - rubber * .45 * line;
	col += vec3(.045) * smoothstep(.70, 1., abs(UV.x));
	float phase = UV.y / 64.0;
	float lamp = floor(phase + 0.5);
	float d = abs(phase - lamp) * 64.0;
	float side = mod(lamp, 2.0) < 0.5 ? -1.0 : 1.0;
	vec3 neon = vec3(0.95, 0.63, 0.28);
	float lateral = exp(-pow(abs((UV.x - side * 0.65) * 1.7), 2.0));
	float streak = (afterhours ? 1.0 : 0.0) * pow(max(0.0, 1.0 - d / 29.0), 1.5) * lateral;
	// The quantized roughness photograph has only two near-white levels. Use
	// albedo luminance for the authored wet pattern, normalized in linear space.
	vec3 fleck_tex = texture(albedo_tex, vec2(UV.x * 2.7 + .37, UV.y * .13)).rgb;
	vec3 pool_tex = texture(albedo_tex, vec2(UV.x * .7, UV.y * .018)).rgb;
	if (OUTPUT_IS_SRGB) {
		fleck_tex = from_srgb(fleck_tex);
		pool_tex = from_srgb(pool_tex);
	}
	float flecks = dot(fleck_tex, vec3(.3333));
	float pools = dot(pool_tex, vec3(.3333));
	float breakup = (.10 + .90 * smoothstep(.011, .018, flecks))
		* (.18 + .82 * smoothstep(.0125, .016, pools));
	float reflection = exp(-abs((UV.x - side * .35) * 5.5));
	// Authored pool/reflection impression is visible even without screen-space reflections.
	vec3 reflected = neon * streak * (.06 + reflection * breakup * 1.6);
	EMISSION = (OUTPUT_IS_SRGB ? to_srgb(reflected) : reflected) + col * 0.045;
	ALBEDO = col * COLOR.rgb + neon * streak * 0.18;
	METALLIC = 0.23;
	ROUGHNESS = mix(0.32, 0.48, wear) + line * 0.06;
}
