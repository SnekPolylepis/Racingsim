shader_type spatial;
render_mode blend_mix;
uniform sampler2D environment_map : source_color, filter_linear_mipmap, repeat_disable;
uniform int paint_variant = 0;
varying vec3 world_normal;
varying vec3 world_position;
void vertex() {
 world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
 world_position = (MODEL_MATRIX * vec4(VERTEX, 1.)).xyz;
}
void fragment() {
 vec3 n = normalize(world_normal);
 vec3 v = normalize(CAMERA_POSITION_WORLD - world_position);
 vec3 reflected = reflect(-v,n);
 vec2 uv = vec2(atan(reflected.x, reflected.z) / 6.283185 + .5, acos(clamp(reflected.y,-1.,1.)) / 3.141593);
 vec3 env = texture(environment_map, uv).rgb;
 vec3 ink = OUTPUT_IS_SRGB ? clamp(COLOR.rgb, vec3(0.), vec3(1.)) : pow(clamp(COLOR.rgb, vec3(0.), vec3(1.)), vec3(2.2));
 if (paint_variant > 0 && COLOR.r > COLOR.g * 1.4 && COLOR.r > COLOR.b * 1.4) {
  ink = (paint_variant == 1 ? vec3(.72,.68,.55) : vec3(.025,.12,.32)) * clamp(COLOR.r * 1.2,.2,1.);
 }
 float fresnel = pow(1. - clamp(dot(n,v),0.,1.), 4.);
 float sweep = pow(clamp(dot(reflected, normalize(vec3(-.4,.8,.45))),0.,1.), 72.);
 ALBEDO = ink * .85;
 EMISSION = env * (.06 + fresnel * .32) + vec3(1.,.94,.8) * sweep * .45;
 ROUGHNESS = .18;
 SPECULAR = .05;
}
