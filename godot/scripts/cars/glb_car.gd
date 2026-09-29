extends RefCounted
## A car from any GLB whose four wheels are separate nodes named with FL/FR/RL/RR (Sketchfab convention, e.g.
## "f2004_wheel_fl_1", "Tire_RR_11"). The body is oriented and scaled so its axles land on the preset's
## wheelbase (a + b) and track; each source wheel hangs on the game's steer pivot / spin node.
## Preset keys: "body": "glb", "model": res:// path.
const Kit = preload("res://scripts/cars/car_kit.gd")
const KEYS = ["FL", "FR", "RL", "RR"]


func build(visuals, preset, ghost):
	var kit = Kit.new()
	var root = kit.start(visuals, preset, ghost, String(preset.get("name", "Car")).replace(" ", ""))
	var src: Node3D = load(preset.model).instantiate()
	# Source wheels and their centres in the source scene's frame.
	var wheels = []
	var centres = []
	for key in KEYS:
		var w = _find_wheel(src, key)
		wheels.append(w)
		centres.append(_to_root(src, w) * _centre(w))
	var front = (centres[0] + centres[1]) * .5
	var rear = (centres[2] + centres[3]) * .5
	var fwd = (front - rear).normalized()
	var right = (centres[1] - centres[0])
	right = (right - fwd * right.dot(fwd)).normalized()
	var up = right.cross(fwd).normalized()
	# Car frame: +X nose, +Y up, +Z right. Rows of the rotation are the source axes expressed in it.
	var to_car = Basis(fwd, up, right).transposed()
	var s = (preset.a + preset.b) / front.distance_to(rear)
	var place = Transform3D(to_car * s, Vector3.ZERO)
	place.origin = Vector3(preset.a, preset.wheelR, 0) - place * front + Vector3(0, 0, 0)
	src.transform = place
	var ghost_mat = visuals.paint_material(Color.WHITE, true) if ghost else null
	# Wheels leave the body before finish(): merge_static would bake wheels that share a body material into
	# the static body mesh.
	var in_body = []
	for w in wheels:
		in_body.append(place * _to_root(src, w) if w != null else Transform3D.IDENTITY)
		if w != null:
			w.get_parent().remove_child(w)
			w.owner = null
	kit.body.add_child(src)
	for part in src.find_children("*", "MeshInstance3D", true, false):
		part.cast_shadow = Kit.shadow_mode(part)
		if ghost:
			part.material_override = ghost_mat
	for w in wheels:
		if w != null and ghost:
			for part in w.find_children("*", "MeshInstance3D", true, false):
				part.material_override = ghost_mat
	var model = kit.finish(root, preset.a + 0.6)
	for i in 4:
		var spin: Node3D = model.spins[i]
		var pivot: Node3D = model.pivots[i]
		for child in spin.get_children():
			spin.remove_child(child)
			child.free()
		for child in pivot.get_children():
			if child != spin:
				pivot.remove_child(child)
				child.free()
		var w: Node3D = wheels[i]
		if w == null:
			continue
		# Wheel in spin space, then shifted so its own centre sits on the axle.
		var t = (pivot.transform).affine_inverse() * in_body[i]
		# Square the wheel's own axle (the local axis nearest the spin axis) onto it: the RB19 bakes ~3.5 deg of
		# camber into its front wheels, which then wobbled as they spun.
		var a = Vector3.ZERO
		for axis in [Vector3.RIGHT, Vector3.UP, Vector3.BACK]:
			var d = (t.basis * axis).normalized()
			if absf(d.z) > absf(a.z):
				a = d
		t.basis = Basis(Quaternion(a, Vector3(0, 0, signf(a.z)))) * t.basis
		t.origin = -(t.basis * _centre(w))
		w.transform = t
		spin.add_child(w)
	return model


func _find_wheel(src: Node, key: String) -> Node3D:
	for n in src.find_children("*", "Node3D", true, false):
		var name = String(n.name).to_upper()
		if ("WHEEL_" + key in name or "TIRE_" + key in name or "TYRE_" + key in name) and not n.find_children("*", "MeshInstance3D", true, false).is_empty():
			return n
	return null


## Accumulated transform from `node` up to (not including) `root`.
func _to_root(root: Node, node: Node) -> Transform3D:
	var t = Transform3D.IDENTITY
	var n = node
	while n != null and n != root:
		if n is Node3D:
			t = n.transform * t
		n = n.get_parent()
	return t


## Centre of the node's meshes in the node's own frame.
func _centre(node: Node3D) -> Vector3:
	var box = AABB()
	var first = true
	for m in node.find_children("*", "MeshInstance3D", true, false) + ([node] if node is MeshInstance3D else []):
		var a = _to_root(node, m) * m.get_aabb() if m != node else m.get_aabb()
		box = a if first else box.merge(a)
		first = false
	return box.get_center()
