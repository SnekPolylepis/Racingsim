shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, fog_disabled;
uniform vec4 lamp_colour : source_color = vec4(1., .72, .36, 1.);
varying float fade;
void vertex() {
 vec3 centre = MODEL_MATRIX[3].xyz;
 float distance_to_camera = length(centre - CAMERA_POSITION_WORLD);
 fade = 1. - smoothstep(100., 190., distance_to_camera);
 // Original camera-facing halo, a common fixed-function-era light treatment.
 MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}
void fragment() {
 vec2 p = (UV - .5) * 2.;
 float radius = dot(p, p);
 float halo = exp(-radius * 7.) * .12 + exp(-radius * 95.) * .7;
 float streak = exp(-abs(p.y) * 65.) * exp(-abs(p.x) * 3.) * .13;
 ALBEDO = lamp_colour.rgb * 1.8;
 ALPHA = (halo + streak) * fade;
}
