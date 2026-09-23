shader_type canvas_item;
render_mode unshaded;
uniform sampler2D world_texture : filter_linear, repeat_disable;
uniform sampler2D glow_texture : filter_linear, repeat_disable;
uniform sampler2D previous_texture : filter_linear, repeat_disable;
uniform float history_weight = 0.0;
uniform float glow_strength = .7;
uniform bool dithering = true;
uniform bool soft = true;
const float bayer[16] = float[16](0.,8.,2.,10.,12.,4.,14.,6.,3.,11.,1.,9.,15.,7.,13.,5.);
void fragment() {
	vec2 texel = 1.0 / vec2(textureSize(world_texture, 0));
	vec3 c = texture(world_texture, UV).rgb;
	if (soft) {
		vec3 neighbours = texture(world_texture, UV + vec2(texel.x, 0.)).rgb;
		neighbours += texture(world_texture, UV - vec2(texel.x, 0.)).rgb;
		neighbours += texture(world_texture, UV + vec2(0., texel.y)).rgb;
		neighbours += texture(world_texture, UV - vec2(0., texel.y)).rgb;
		c = mix(c, neighbours * .25, .18);
	}
	vec3 glow = vec3(0.);
	for (int x = -2; x <= 2; x++) {
		for (int y = -2; y <= 2; y++) {
			glow += texture(glow_texture, UV + vec2(float(x),float(y)) * texel * 7.).rgb / 25.;
		}
	}
	c += glow * glow_strength;
	vec2 p = UV * 2. - 1.;
	c *= 1. - smoothstep(.6, 2., dot(p,p)) * .12;
	c = mix(c, texture(previous_texture, UV).rgb, history_weight);
	if (dithering) {
		ivec2 xy = ivec2(FRAGCOORD.xy) % 4;
		float d = (bayer[xy.y * 4 + xy.x] + .5) / 16. - .5;
		vec3 levels = vec3(31., 63., 31.);
		c = floor(clamp(c, 0., 1.) * levels + .5 + d * .45) / levels;
	}
	COLOR = vec4(clamp(c, 0., 1.), 1.);
}
