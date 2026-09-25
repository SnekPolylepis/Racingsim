shader_type spatial;
render_mode blend_mix, cull_back, unshaded;
// DRAFT — unintegrated, staged on rb/CHI-assets-prep for a future task (LOOK-NIGHT-01-adjacent or a
// CHI-01 follow-up) to adapt. Not wired into any scene, generator or gate. Loop-era storefronts and
// theatre marquees (State Street, the old Woolworth/Chicago Theatre block) read as pulsing tube-neon
// at night in GT4/NFSU-style references; nothing in the current night_glow.gdshader pulses or scrolls,
// it only toggles a flat emission boost. This is a starting point for that, not a replacement for it —
// pair it with night_glow.gd's existing facade wiring rather than duplicating the day/night toggle.

uniform sampler2D sign_texture : source_color, filter_linear, repeat_disable;
// Mask channel (R) picks which texels are neon tubing vs. dark sign backing, so the backing stays flat
// unlit while only the tube glyphs pulse and bloom.
uniform sampler2D glow_mask : hint_default_black, filter_linear, repeat_disable;
uniform vec3 tube_color : source_color = vec3(1.0, 0.25, 0.55);
uniform float glow_strength : hint_range(0.0, 8.0) = 3.0;
uniform float pulse_speed : hint_range(0.0, 4.0) = 1.2;
uniform float pulse_depth : hint_range(0.0, 1.0) = 0.35;
uniform bool afterhours = false;

void fragment() {
	vec4 base = texture(sign_texture, UV);
	float mask = texture(glow_mask, UV).r;
	float pulse = 1.0 - pulse_depth * 0.5 * (1.0 + sin(TIME * pulse_speed * TAU));
	ALBEDO = base.rgb;
	EMISSION = afterhours ? tube_color * mask * glow_strength * pulse : vec3(0.0);
	ALPHA = base.a;
}
