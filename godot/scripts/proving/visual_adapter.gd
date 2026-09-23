extends RefCounted
## Minimal presentation adapter posing the visual car model from 6-DOF CarBody snapshots (P2-08).
## Bridges CarBody.snapshot() (Transform3D xform, steer, wheel phase, comp) to Visuals / Ferrari 296.
## Notes for P4-04:
##   - Root origin is offset by (0, -cgHeight, 0) in the body frame so the tires align to ground level.
##   - Suspension compression acts along the strut axis (+Y in root space).
##   - Drop shadow is currently local to root (tilted with chassis); P4-04 should project onto ground.

const Visuals = preload("res://scripts/visuals.gd")


static func make_model(visuals: Visuals, preset: Dictionary, ghost: bool = false) -> Dictionary:
	return visuals.make_car(preset, ghost)


static func blend(a: Dictionary, b: Dictionary, t: float) -> Dictionary:
	var q_a = a.xform.basis.get_rotation_quaternion()
	var q_b = b.xform.basis.get_rotation_quaternion()
	var q = q_a.slerp(q_b, t)
	var origin = a.xform.origin.lerp(b.xform.origin, t)
	var xform = Transform3D(Basis(q), origin)
	var steer = lerpf(a.steer, b.steer, t)
	var phases = []
	for i in b.phase.size():
		phases.append(lerp_angle(a.phase[i], b.phase[i], t))
	var out = {"xform": xform, "steer": steer, "phase": phases}
	if a.has("comp") and b.has("comp"):
		var comps = []
		for i in b.comp.size():
			comps.append(lerpf(a.comp[i], b.comp[i], t))
		out["comp"] = comps
	if b.has("brake"):
		out["brake"] = lerpf(a.get("brake", 0.0), b.brake, t)
	if b.has("handbrake"):
		out["handbrake"] = lerpf(a.get("handbrake", 0.0), b.handbrake, t)
	return out


static func pose(model: Dictionary, snap: Dictionary, cg_height: float) -> void:
	if model.is_empty() or not model.has("root"):
		return
	# Poses the root transform from the 6-DOF chassis CG pose.
	model.root.transform = snap.xform * Transform3D(Basis(), Vector3(0, -cg_height, 0))
	# Steering: positive steer steers right (clockwise looking down, negative Y rotation).
	for i in 2:
		if i < model.pivots.size():
			model.pivots[i].rotation.y = -snap.steer
	# Wheel spin: forward roll rotates clockwise along +Z.
	for i in model.spins.size():
		if i < snap.phase.size():
			model.spins[i].rotation.z = -snap.phase[i]
	# Suspension compression deflection along the strut.
	if snap.has("comp"):
		for i in model.pivots.size():
			if i < snap.comp.size():
				model.pivots[i].position.y = model.wheel_r + snap.comp[i]
	if model.has("brakes") and model.brakes != null and snap.has("brake"):
		var active = snap.brake > 0.05 or snap.get("handbrake", 0.0) > 0.05
		model.brakes.emission = Color(1, 0.03, 0.01) * (1.7 if active else 0.55)
