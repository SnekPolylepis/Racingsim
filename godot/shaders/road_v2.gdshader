shader_type spatial;
// TrackAsset asphalt in the PS2-era style: road.gdshader's graphic tones, rubbered centre band and
// after-hours amber lamp streaks, for RoadBuilder meshes whose UVs are metres (UV.x across the road
// from the centreline, UV.y along it). The lateral fraction uses a nominal half-width. The streaks sit
// under the TrackAsset's real lamps: scripts/track/track_lights.gd writes `lamp_data`, texel x covering
// `lamp_cell` metres of station, each row two lamps as (station, side * strength), nearest first.
render_mode cull_disabled;
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D rough_tex : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform bool afterhours = false;
uniform float half_width = 5.0;
uniform float tile = 0.32;
uniform float rubber = 0.55;
uniform sampler2D lamp_data : filter_nearest, repeat_disable;
uniform bool lamp_map = false;
uniform float lamp_cell = 4.0;
uniform float lamp_reach = 29.0;
// Closed roads wrap station distance at their length; 0 for an open road.
uniform float road_length = 0.0;
varying vec3 world_pos;

void vertex() { world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }

vec3 to_srgb(vec3 c) {
	return mix(c * 12.92, 1.055 * pow(max(c, vec3(0.)), vec3(1. / 2.4)) - .055, step(vec3(.0031308), c));
}

void fragment() {
	float lat = clamp(UV.x / half_width, -1.3, 1.3);
	vec2 uv = vec2(lat * 2.5, UV.y * tile);
	vec3 base = texture(albedo_tex, uv).rgb;
	float grain = base.r;
	float wear = floor(clamp(grain * 6.0, 0.0, 1.0) * 5.0) / 5.0;
	vec3 col = afterhours ? base * 2.5 + vec3(.014, .017, .021) : base * 3.8 + vec3(.015);
	// The rubbered line: without a racing-line channel, a soft band down the middle of the road.
	float line = exp(-pow(abs(lat * 1.6), 2.0));
	col *= 1.0 - rubber * .45 * line;
	col += vec3(.045) * smoothstep(.70, 1., abs(lat));
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
				glow += fall * lateral + pool * .25;
				reflected += neon * (fall * lateral * (.06 + reflection * 1.2) + pool * .12);
			}
		}
	}
	glow = min(glow, 1.2);
	reflected = min(reflected, vec3(1.1));
	EMISSION = (OUTPUT_IS_SRGB ? to_srgb(reflected) : reflected) + col * 0.045;
	ALBEDO = col + neon * glow * 0.18;
	METALLIC = 0.23;
	ROUGHNESS = mix(0.32, 0.48, wear) + line * 0.06;
}
