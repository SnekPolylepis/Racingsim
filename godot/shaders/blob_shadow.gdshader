shader_type spatial;
render_mode unshaded, cull_disabled;

// Contact patch under the car.
//
// This deliberately stays in the OPAQUE pass and stipples its edge with an ordered dither instead
// of writing ALPHA. A transparent material on this mesh is never composited by the world
// SubViewport in retro_renderer.gd, which is why the original alpha-blended patch was invisible on
// every surface. Dithered coverage also matches the era the presentation is aiming at: hardware of
// that generation faked soft shadows with exactly this stipple.
//
// strength scales the whole patch; visuals.gd lowers it after dark, where the amber lamps already
// model the ground and a full-weight patch reads as a hole.
uniform float strength : hint_range(0.0, 1.0) = 1.0;
uniform float density : hint_range(0.0, 1.0) = 1.0;

const float BAYER[16] = {
	1.0, 9.0, 3.0, 11.0, 13.0, 5.0, 15.0, 7.0, 4.0, 12.0, 2.0, 10.0, 16.0, 8.0, 14.0, 6.0
};

void fragment() {
	// Rounded rectangle rather than a disc: closer to a car's plan shape, so the nose and tail stay
	// anchored instead of fading out inside a circular blob.
	vec2 q = abs((UV - 0.5) * 2.0);
	float d = pow(pow(q.x, 4.0) + pow(q.y, 4.0), 0.25);
	// Wide soft penumbra plus a tighter core, so there is a definite contact point under the floor.
	float penumbra = 1.0 - smoothstep(0.24, 1.0, d);
	float contact = 1.0 - smoothstep(0.0, 0.60, d);
	float coverage = clamp(penumbra * 0.5 + contact * 0.5, 0.0, 1.0) * density * strength;
	int x = int(mod(FRAGCOORD.x, 4.0));
	int y = int(mod(FRAGCOORD.y, 4.0));
	if (coverage < BAYER[y * 4 + x] / 17.0) {
		discard;
	}
	// Cool, not black: the patch is lit by sky bounce, so a neutral black reads as a hole.
	ALBEDO = vec3(0.004, 0.005, 0.009);
}
