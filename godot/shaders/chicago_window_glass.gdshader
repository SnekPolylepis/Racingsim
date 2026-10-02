shader_type spatial;
render_mode cull_disabled;
uniform bool afterhours = false;
varying flat vec3 office;
void vertex() { office = INSTANCE_CUSTOM.rgb; }
void fragment() {
	ALBEDO = afterhours ? vec3(.035, .047, .058) : mix(vec3(.07, .09, .12), vec3(.24, .32, .42), office.g);
	ROUGHNESS = .2;
	METALLIC = .15;
	if (afterhours) {
		float blind = mix(.32, .88, office.b);
		float shade = mix(.38, 1.0, smoothstep(blind - .05, blind + .05, UV.y));
		EMISSION = mix(vec3(1.0, .72, .38), vec3(.72, .84, 1.0), office.g * step(.5, office.b)) * office.r * shade * .72;
	}
}
