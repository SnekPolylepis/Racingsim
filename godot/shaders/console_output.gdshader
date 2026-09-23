shader_type canvas_item;
render_mode unshaded;
uniform sampler2D scene_texture : filter_linear, repeat_disable;
uniform sampler2D ui_texture : filter_linear, repeat_disable;
uniform sampler2D previous_field : filter_nearest, repeat_disable;
uniform bool authentic_ui = true;
uniform bool interlaced = false;
uniform bool composite = false;
uniform bool rgb16 = false;
uniform bool dithering = true;
uniform bool field_valid = false;
uniform int field_phase = 0;
const float matrix4[16] = float[16](-4.,0.,-3.,1.,2.,-2.,3.,-1.,-3.,1.,-4.,0.,3.,-1.,2.,-2.);
vec3 source(vec2 uv) {
	vec3 c = texture(scene_texture, uv).rgb;
	vec4 ui = texture(ui_texture, uv);
	return authentic_ui ? mix(c, ui.rgb, ui.a) : c;
}
vec3 yiq(vec3 c) { return vec3(dot(c, vec3(.299,.587,.114)), dot(c,vec3(.596,-.274,-.322)), dot(c,vec3(.211,-.523,.312))); }
void fragment() {
	vec2 texel = 1.0 / vec2(textureSize(previous_field, 0));
	vec3 c = source(UV);
	if (interlaced) {
		c = c * .5 + source(UV + vec2(0.,texel.y)) * .25 + source(UV - vec2(0.,texel.y)) * .25;
		if (int(FRAGCOORD.y) % 2 != field_phase && field_valid) c = texture(previous_field, UV).rgb;
	}
	if (composite) {
		vec3 signal = yiq(c);
		vec3 left = yiq(source(UV - vec2(texel.x * 1.4, 0.)));
		vec3 right = yiq(source(UV + vec2(texel.x * 1.4, 0.)));
		signal.yz = (left.yz + signal.yz * 2. + right.yz) * .25;
		c = vec3(signal.x + .956 * signal.y + .621 * signal.z, signal.x - .272 * signal.y - .647 * signal.z, signal.x - 1.106 * signal.y + 1.703 * signal.z);
		c = pow(clamp(c,0.,1.), vec3(1.035));
		float mask = .965 + .035 * cos(FRAGCOORD.x * 2.094395);
		c *= mask * (.98 + .02 * cos(FRAGCOORD.y * 3.141593));
	}
	if (rgb16) {
		ivec2 xy = ivec2(FRAGCOORD.xy) % 4;
		float d = dithering ? matrix4[xy.y * 4 + xy.x] / 8. : 0.;
		c = floor(clamp(c,0.,1.) * 31. + .5 + d) / 31.;
	}
	COLOR = vec4(clamp(c,0.,1.),1.);
}
