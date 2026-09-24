shader_type spatial;
// Look-2 sodium lamp halo for TrackAsset lamps (scripts/track/track_lights.gd): the camera-facing
// Gaussian halo and horizontal streak of lamp_corona.gdshader (night_style.gd's legacy look), drawn
// from a MultiMesh. It stays visible much further than the legacy corona so a line of lamps reads into
// the night fog, and fades out close up so the quad never fills the screen.
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, fog_disabled, shadows_disabled;
uniform vec4 lamp_colour : source_color = vec4(1., .72, .36, 1.);
uniform float near_fade = 7.0;
uniform float fade_begin = 260.0;
uniform float fade_end = 560.0;
uniform float intensity = 1.0;
varying float fade;
varying float grow;

void vertex() {
	vec3 centre = MODEL_MATRIX[3].xyz;
	float distance_to_camera = length(centre - CAMERA_POSITION_WORLD);
	fade = smoothstep(near_fade * .4, near_fade, distance_to_camera);
	fade *= 1. - smoothstep(fade_begin, fade_end, distance_to_camera);
	// Keep distant halos a few pixels wide in the 640x448 raster instead of shrinking to nothing.
	grow = 1. + smoothstep(90., 400., distance_to_camera) * 1.6;
	MODELVIEW_MATRIX = VIEW_MATRIX
		* mat4(INV_VIEW_MATRIX[0] * grow, INV_VIEW_MATRIX[1] * grow, INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}

void fragment() {
	vec2 p = (UV - .5) * 2.;
	float radius = dot(p, p);
	float halo = exp(-radius * 9.) * .2 + exp(-radius * 120.) * 1.1;
	float streak = exp(-abs(p.y) * 90.) * exp(-abs(p.x) * 2.2) * .3;
	ALBEDO = lamp_colour.rgb * 1.8;
	ALPHA = clamp((halo + streak) * fade * intensity / grow, 0., 1.);
}
