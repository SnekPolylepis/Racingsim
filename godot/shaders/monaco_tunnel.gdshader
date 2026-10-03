shader_type spatial;
// The Monaco tunnel's inner wall: tall cream tiles (about 0.35 x 0.6 m) with light grout, in 4 m panels
// with a darker seam, as in the Commons reference photos ("Circuit de Monaco - Tunnel", "Dans le tunnel
// Louis II"). UV is metres along the wall and up it.
uniform vec3 tile_color : source_color = vec3(0.86, 0.8, 0.68);
uniform vec3 grout_color : source_color = vec3(0.56, 0.53, 0.48);
uniform vec2 tile_m = vec2(0.35, 0.6);
uniform float panel_m = 4.0;

void fragment() {
	vec2 g = abs(fract(UV / tile_m) - 0.5);
	float grout = step(0.45, max(g.x * 1.6, g.y));
	float seam = step(0.49, abs(fract(UV.x / panel_m) - 0.5));
	float shade = 0.9 + 0.1 * fract(sin(dot(floor(UV / tile_m), vec2(12.9898, 78.233))) * 43758.5453);
	ALBEDO = mix(mix(tile_color * shade, grout_color, grout), grout_color * 0.6, seam);
	ROUGHNESS = mix(0.55, 0.9, max(grout, seam));
	SPECULAR = 0.25;
}
