extends RefCounted
## Shared low-poly coachwork and running gear for the v2 car models.
## All dimensions are metres; +X is the nose and +Z is the right side.

var v
var p
var body: Node3D
var ghost = false
var paint: Color
var paint_mat
var dark = Color("111820")


func start(visuals, preset, is_ghost, label):
	v = visuals
	p = preset
	ghost = is_ghost
	paint = Color(p.get("color", "#c1272d"))
	paint_mat = v.paint_material(paint, ghost)
	var root = Node3D.new()
	body = Node3D.new()
	body.name = label
	root.add_child(body)
	return root


func face(st, points, color, outward):
	for i in range(1, points.size() - 1):
		var a = points[0]
		var b = points[i]
		var c = points[i + 1]
		if (b - a).cross(c - a).dot(outward) > 0:
			var swap = b
			b = c
			c = swap
		for point in [a, b, c]:
			st.set_color(color)
			st.add_vertex(point)


func mesh(st, label, material = null):
	st.index()
	st.generate_normals()
	var node = MeshInstance3D.new()
	node.name = label
	node.mesh = st.commit()
	node.material_override = paint_mat if material == null else material
	body.add_child(node)
	return node


func panel(label, points, color, outward, material = null):
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	face(st, points, color, outward)
	return mesh(st, label, material)


func box(label, pos, size, color, metallic = 0.0):
	var node = v.box(body, pos, size, color, metallic)
	node.name = label
	return node


func line(label, a, b, thickness, color):
	var node = box(label, (a + b) * .5, Vector3(thickness, a.distance_to(b), thickness), color)
	node.quaternion = Quaternion(Vector3.UP, (b - a).normalized())
	return node


func y_at(frames, x):
	return v.keyframe(frames, x)


func arch_bottom(x, floor_y):
	var y = floor_y
	for axle in [p.a, -p.b]:
		var dx = x - axle
		var radius = p.wheelR + .055
		if absf(dx) < radius:
			y = maxf(y, p.wheelR + sqrt(radius * radius - dx * dx))
	return y


## A continuous crowned upper shell and separately cut side skins leave the wheel wells open.
func coachwork(x_rear, x_front, widths, heights, floor_y, shoulder_y):
	var crown = SurfaceTool.new()
	crown.begin(Mesh.PRIMITIVE_TRIANGLES)
	var sides = SurfaceTool.new()
	sides.begin(Mesh.PRIMITIVE_TRIANGLES)
	var lanes = [-1.0, -.90, -.70, -.38, 0.0, .38, .70, .90, 1.0]
	for i in 44:
		var xa = lerpf(x_rear, x_front, float(i) / 44.0)
		var xb = lerpf(x_rear, x_front, float(i + 1) / 44.0)
		for j in lanes.size() - 1:
			var t0 = lanes[j]
			var t1 = lanes[j + 1]
			face(crown, [crown_point(xa, t0, widths, heights, shoulder_y), crown_point(xb, t0, widths, heights, shoulder_y), crown_point(xb, t1, widths, heights, shoulder_y), crown_point(xa, t1, widths, heights, shoulder_y)], paint, Vector3.UP)
		for side in [-1, 1]:
			var wa = y_at(widths, xa)
			var wb = y_at(widths, xb)
			face(sides, [crown_point(xa, side, widths, heights, shoulder_y), crown_point(xb, side, widths, heights, shoulder_y), Vector3(xb, arch_bottom(xb, floor_y), side * (wb - .01)), Vector3(xa, arch_bottom(xa, floor_y), side * (wa - .01))], paint, Vector3(0, 0, side))
	mesh(crown, "CrownedCoachwork")
	mesh(sides, "CutWheelArchSideSkins")
	for side in [-1, 1]:
		for axle in [p.a, -p.b]:
			arch_lip(axle, side, y_at(widths, axle), p.wheelR + .055)
	panel("NosePanel", [crown_point(x_front, -1, widths, heights, shoulder_y), crown_point(x_front, 1, widths, heights, shoulder_y), Vector3(x_front, floor_y, y_at(widths, x_front)), Vector3(x_front, floor_y, -y_at(widths, x_front))], paint, Vector3.RIGHT)
	panel("TailPanel", [crown_point(x_rear, 1, widths, heights, shoulder_y), crown_point(x_rear, -1, widths, heights, shoulder_y), Vector3(x_rear, floor_y, -y_at(widths, x_rear)), Vector3(x_rear, floor_y, y_at(widths, x_rear))], paint, Vector3.LEFT)


func crown_point(x, t, widths, heights, shoulder_y):
	var center_y = y_at(heights, x)
	var y = lerpf(center_y, shoulder_y, pow(absf(t), 2.5))
	return Vector3(x, y, t * y_at(widths, x))


func arch_lip(axle, side, width, radius):
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 12:
		var a0 = PI * float(i) / 12.0
		var a1 = PI * float(i + 1) / 12.0
		var x0 = axle + cos(a0) * radius
		var x1 = axle + cos(a1) * radius
		var y0 = p.wheelR + sin(a0) * radius
		var y1 = p.wheelR + sin(a1) * radius
		face(st, [Vector3(x0, y0, side * width), Vector3(x1, y1, side * width), Vector3(x1, y1 + .025, side * (width + .035)), Vector3(x0, y0 + .025, side * (width + .035))], paint.darkened(.16), Vector3(0, 0, side))
	mesh(st, "RolledWheelArch")


func glass_panel(label, points, outward):
	return panel(label, points, Color("263942"), outward, v.material("263942", .08, .16))


func lamp(label, pos, size, base_color, glow_color, night_only = false):
	var base = box(label, pos, size, base_color)
	var mat = v.material(base_color, .08, .2).duplicate()
	mat.emission_enabled = true
	mat.emission = Color(glow_color)
	mat.emission_energy_multiplier = 1.8
	var node = box(label + "NightGlow", pos + Vector3(.003 if night_only else -.003, 0, 0), size * Vector3(.15, .83, .83), base_color)
	node.material_override = mat
	node.visible = v.night and not ghost
	if not ghost:
		v.headlights.append(weakref(node))
	return base


func number_plate(number, x, y, z):
	if ghost:
		return
	for side in [-1, 1]:
		var plate = box("RaceNumberRoundel", Vector3(x, y, side * z), Vector3(.43, .38, .012), "eee8d6")
		plate.material_override = v.material("eee8d6")
		var label = Label3D.new()
		label.name = "RaceNumber"
		label.text = str(number)
		label.font_size = 96
		label.pixel_size = .0036
		label.modulate = Color("171c24")
		label.position = Vector3(x, y, side * (z + .014))
		label.rotation.y = 0 if side > 0 else PI
		body.add_child(label)


func finish(root, nose):
	var brake_mat = v.material("ad1212", .08, .2).duplicate()
	brake_mat.emission_enabled = true
	brake_mat.emission = Color("ff2018")
	brake_mat.emission_energy_multiplier = 1.25
	for node in body.find_children("*", "MeshInstance3D", true, false):
		if node.name == "GTTailCluster" or node.name == "RoundTailLamp":
			node.material_override = brake_mat
	var model = v.finish_car(root, body, p, ghost, brake_mat, nose)
	replace_wheels(model, "road" if p.get("body", "") == "roadster" else "race")
	return model


## One mesh surface per wheel combines the tread, sidewall, rim and five paired spokes.
## The assembly remains under the original spin node; calipers stay under the pivot.
func replace_wheels(model, style):
	var wheel = build_wheel(style)
	var rim_mat = StandardMaterial3D.new()
	rim_mat.vertex_color_use_as_albedo = true
	rim_mat.vertex_color_is_srgb = true
	rim_mat.metallic = .2
	rim_mat.roughness = .48
	for i in 4:
		var spin = model.spins[i]
		var pivot = model.pivots[i]
		for child in spin.get_children():
			spin.remove_child(child)
			child.free()
		for child in pivot.get_children():
			if child != spin:
				pivot.remove_child(child)
				child.free()
		var mesh_node = MeshInstance3D.new()
		mesh_node.name = "TyreSidewallAndRim"
		mesh_node.mesh = wheel
		mesh_node.material_override = v.paint_material(paint, true) if ghost else rim_mat
		spin.add_child(mesh_node)
		if not ghost:
			var side = -1.0 if i % 2 == 0 else 1.0
			var caliper_node = v.box(pivot, Vector3(-p.wheelR * .42, p.wheelR * .3, side * .115), Vector3(.12, .14, .055), p.get("caliper", "#c9c9c9"))
			caliper_node.name = "BrakeCaliper"


func build_wheel(style):
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var r = p.wheelR
	var rim = Color(p.get("rim", "#aeb6bb"))
	var tire = Color("141719")
	var wall = Color("292d31")
	var shade = rim.darkened(.38)
	var count = 24
	for side in [-1, 1]:
		var z = side * .151
		for i in count:
			var t0 = TAU * i / count
			var t1 = TAU * (i + 1) / count
			wheel_band(st, r, .83 * r, z, z + side * .002, t0, t1, wall, Vector3(0, 0, side))
			wheel_band(st, .83 * r, .67 * r, z + side * .002, z + side * .006, t0, t1, tire, Vector3(0, 0, side))
			wheel_band(st, .67 * r, .59 * r, z + side * .008, z + side * .012, t0, t1, rim, Vector3(0, 0, side))
			wheel_band(st, .59 * r, .51 * r, z + side * .012, z - side * .012, t0, t1, shade, Vector3(0, 0, side))
			wheel_band(st, .13 * r, 0.0, z + side * .025, z + side * .025, t0, t1, rim, Vector3(0, 0, side))
		for spoke in 5:
			var angle = TAU * spoke / 5.0
			for delta in [-.075, .075]:
				var a = angle + delta
				var lo = .12 * r
				var hi = .56 * r
				var thin = .026 if style == "road" else .018
				var px = Vector3(cos(a), sin(a), 0)
				var py = Vector3(-sin(a), cos(a), 0)
				var zf = z + side * .024
				face(st, [px * lo - py * thin + Vector3(0, 0, zf), px * hi - py * thin + Vector3(0, 0, zf), px * hi + py * thin + Vector3(0, 0, zf), px * lo + py * thin + Vector3(0, 0, zf)], rim, Vector3(0, 0, side))
	# Tread and shoulder share the same 24-sided outline. Dark bands read at PS2 resolution.
	for i in count:
		var t0 = TAU * i / count
		var t1 = TAU * (i + 1) / count
		wheel_band(st, r, r, -.151, .151, t0, t1, tire if i % 3 else wall, Vector3(cos((t0 + t1) * .5), sin((t0 + t1) * .5), 0))
	st.index()
	st.generate_normals()
	return st.commit()


func wheel_band(st, outer_r, inner_r, outer_z, inner_z, a0, a1, color, outward):
	face(st, [Vector3(cos(a0) * outer_r, sin(a0) * outer_r, outer_z), Vector3(cos(a1) * outer_r, sin(a1) * outer_r, outer_z), Vector3(cos(a1) * inner_r, sin(a1) * inner_r, inner_z), Vector3(cos(a0) * inner_r, sin(a0) * inner_r, inner_z)], color, outward)
