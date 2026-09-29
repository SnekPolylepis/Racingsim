shader_type spatial;
// The Monaco tunnel's inner wall: pale square tiles (about 0.6 m) with dark grout, as in the reference photos.
// UV is metres along the wall and up it.
uniform vec3 tile_color : source_color = vec3(0.78, 0.74, 0.66);
uniform vec3 grout_color : source_color = vec3(0.35, 0.34, 0.32);
uniform float tile_m = 0.6;

void fragment() {
	vec2 g = abs(fract(UV / tile_m) - 0.5);
	float grout = step(0.46, max(g.x, g.y));
	float shade = 0.92 + 0.08 * fract(sin(dot(floor(UV / tile_m), vec2(12.9898, 78.233))) * 43758.5453);
	ALBEDO = mix(tile_color * shade, grout_color, grout);
	ROUGHNESS = mix(0.35, 0.9, grout);
}
