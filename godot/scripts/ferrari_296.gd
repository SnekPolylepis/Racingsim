extends RefCounted
## Original, reference-built 2023 296 GT3 exterior. +X nose, +Y up, +Z right; metres.
## This is authored game geometry, not a downloaded/licensed Ferrari CAD asset.
## Separate crown, arch-cut side skins, glazing and aero replace the generic superellipse.
## All moving running gear still comes from Visuals.finish_car and the simulation's axle data.
var v
var body: Node3D
var paint: Color
var black = Color("111923")
var glass = Color("263d4b")
var paint_mat
var p


func build(visuals, preset, ghost):
	v = visuals
	p = preset
	paint = Color(p.get("color", "#da252b"))
	paint_mat = v.paint_material(paint, ghost)
	var root = Node3D.new()
	body = Node3D.new()
	body.name = "Ferrari296GT3"
	root.add_child(body)
	shell()
	cockpit()
	front_clip()
	sides()
	livery()
	var brakes = v.material("c3221a", .1, .25).duplicate()
	brakes.emission_enabled = true
	rear_clip(brakes)
	# Wing plane sits close to roof height; the support hooks rise just above it.
	for node in body.get_children():
		if node.name.begins_with("SwanNeck") or node.name.begins_with("Wing") or node.name == "RearWing":
			node.position.y -= .12
	return v.finish_car(root, body, p, ghost, brakes, 1.08)


## A clockwise face with explicit exterior direction. Never guess mirrored-side winding.
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


func begin():
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	return st


func finish(st, label, mat = null, smooth = false):
	if smooth:
		st.index()
	st.generate_normals()
	var node = MeshInstance3D.new()
	node.name = label
	node.mesh = st.commit()
	node.material_override = paint_mat if mat == null else mat
	body.add_child(node)
	return node


func panel(label, points, color, outward, mat = null):
	var st = begin()
	face(st, points, color, outward)
	return finish(st, label, mat)


func block(pos, size, color, label = "Trim"):
	var node = v.box(body, pos, size, color)
	node.name = label
	return node


func line(a, b, thickness, color, label = "Seam", mat = null):
	var node = block((a + b) / 2, Vector3(thickness, a.distance_to(b), thickness), color, label)
	node.quaternion = Quaternion(Vector3.UP, (b - a).normalized())
	if mat != null:
		node.material_override = mat
	return node


func sample(frames, x):
	return v.keyframe(frames, x)


## Outer shoulder stays high over the tires; only the SIDE skin is cut for wheel openings.
## Unlike the old hull, the entire underbody does not rise at each axle.
func width_at(x):
	return sample(
		[
			[-2.01, .91],
			[-1.68, 1.005],
			[-1.1, 1.035],
			[-.60, .99],
			[.05, .9],
			[.8, .94],
			[1.54, 1.02],
			[2.1, 1.0],
			[2.62, .83]
		],
		x
	)


func crown(x, t):
	var center = sample(
		[
			[-2.01, .76],
			[-1.65, .82],
			[-.6, .82],
			[.85, .77],
			[1.15, .74],
			[1.8, .60],
			[2.3, .49],
			[2.62, .43]
		],
		x
	)
	var shoulder = sample(
		[
			[-2.01, .76],
			[-1.65, .84],
			[-1.1, .88],
			[-.5, .86],
			[.2, .79],
			[.85, .79],
			[1.54, .88],
			[2.1, .76],
			[2.62, .47]
		],
		x
	)
	var y = lerpf(center, shoulder, smoothstep(.38, .83, absf(t)))
	y -= smoothstep(.85, 1.0, absf(t)) * .045
	return Vector3(x, y, t * width_at(x))


func arch_bottom(x):
	var low = .19
	for axle in [p.a, -p.b]:
		var dx = x - axle
		var r = p.wheelR + .057
		if absf(dx) < r:
			low = maxf(low, p.wheelR + sqrt(r * r - dx * dx))
	return low


func shell():
	var st = begin()
	var lanes = [-1.0, -.94, -.84, -.72, -.54, -.28, 0, .28, .54, .72, .84, .94, 1.0]
	for i in 64:
		var xa = lerpf(-2.01, 2.62, float(i) / 64)
		var xb = lerpf(-2.01, 2.62, float(i + 1) / 64)
		for j in lanes.size() - 1:
			face(
				st,
				[crown(xa, lanes[j]), crown(xb, lanes[j]), crown(xb, lanes[j + 1]), crown(xa, lanes[j + 1])],
				paint,
				Vector3.UP
			)
	finish(st, "SculptedBodyCrown", null, true)
	st = begin()
	for side in [-1, 1]:
		for i in 64:
			var xa = lerpf(-2.01, 2.62, float(i) / 64)
			var xb = lerpf(-2.01, 2.62, float(i + 1) / 64)
			var a = crown(xa, side)
			var b = crown(xb, side)
			var c = Vector3(xb, arch_bottom(xb), side * (width_at(xb) - .025))
			var d = Vector3(xa, arch_bottom(xa), side * (width_at(xa) - .025))
			# The front grille and rear diffuser are separate open structures.
			if xa > 2.20 or xb < -1.72:
				c.y = maxf(c.y, .46)
				d.y = maxf(d.y, .46)
			# Authored vertex shading gives the concave lower flanks depth under the night grade.
			var mid_a = a.lerp(d, .62)
			var mid_b = b.lerp(c, .62)
			mid_a.z -= side * .025
			mid_b.z -= side * .025
			face(st, [a, b, mid_b, mid_a], paint, Vector3(0, 0, side))
			face(st, [mid_a, mid_b, c, d], paint.darkened(.18), Vector3(0, 0, side))
	finish(st, "WheelArchSideSkins", null, true)
	# Thin folded arch lips, rather than tires poking through a closed body.
	for axle in [p.a, -p.b]:
		for side in [-1, 1]:
			st = begin()
			for i in 28:
				var points = []
				for pair in [[i, 0], [i + 1, 0], [i + 1, .025], [i, .025]]:
					var angle = lerpf(-.37, PI + .37, float(pair[0]) / 28)
					var r = p.wheelR + .057 + pair[1]
					var x = axle + cos(angle) * r
					points.append(Vector3(x, p.wheelR + sin(angle) * r, side * (width_at(x) + .004)))
				face(st, points, paint, Vector3(0, 0, side))
			finish(st, "RolledArchLip", null, true)


func cockpit():
	# Low, wide roof; clearly defined A pillars and a short side-window aperture.
	var rows = [
		[-.75, .85, .67],
		[-.46, 1.15, .60],
		[-.18, 1.22, .58],
		[.36, 1.20, .57],
		[.56, 1.13, .59],
		[1.14, .78, .75]
	]
	var st = begin()
	var rounded_rows = []
	for i in rows.size() - 1:
		for step in 4:
			var t = float(step) / 4
			var x = lerpf(rows[i][0], rows[i + 1][0], t)
			var y = lerpf(rows[i][1], rows[i + 1][1], t)
			# Leave the windshield straight but gently crown the painted roof fore/aft.
			if i > 0 and i < 4:
				y += sin(t * PI) * .012
			rounded_rows.append([x, y, lerpf(rows[i][2], rows[i + 1][2], t)])
	rounded_rows.append(rows[-1])
	rows = rounded_rows
	for i in rows.size() - 1:
		for j in 12:
			var points = []
			for ij in [[i, j], [i + 1, j], [i + 1, j + 1], [i, j + 1]]:
				var row = rows[ij[0]]
				var t = lerpf(-1, 1, float(ij[1]) / 12)
				points.append(Vector3(row[0], row[1] - .05 * t * t, row[2] * t))
			face(st, points, glass if i < 4 or i >= 16 else paint, Vector3.UP)
	finish(st, "RoofAndRakedWindscreen", null, true)
	for side in [-1, 1]:
		var outward = Vector3(0, 0, side)
		panel(
			"CabinSide",
			[
				Vector3(-.75, .81, side * .74),
				Vector3(-.46, 1.10, side * .6),
				Vector3(.36, 1.15, side * .57),
				Vector3(.56, 1.08, side * .59),
				Vector3(1.14, .78, side * .75)
			],
			paint,
			outward
		)
		var window = [
			Vector3(-.56, .86, side * .724),
			Vector3(-.38, 1.08, side * .62),
			Vector3(.34, 1.115, side * .602),
			Vector3(.47, 1.06, side * .626),
			Vector3(.93, .817, side * .755),
			Vector3(-.05, .828, side * .751)
		]
		panel("SideWindow", window, glass, outward)
		for i in window.size():
			line(window[i], window[(i + 1) % window.size()], .014, black)
		line(
			Vector3(-.17, .854, side * .749), Vector3(-.20, 1.099, side * .623), .025, black, "WindowDivider"
		)
		# Polycarbonate sliding vent and visible fasteners.
		var vent = [
			Vector3(-.05, .90, side * .730),
			Vector3(-.07, 1.025, side * .662),
			Vector3(.22, 1.022, side * .664),
			Vector3(.34, .894, side * .735)
		]
		for i in 4:
			line(vent[i], vent[(i + 1) % 4], .008, "758391", "WindowSlider")
		# Flying buttress around the inset engine cover, iconic 296 shoulder transition.
		panel(
			"FlyingButtress",
			[
				Vector3(-.42, 1.12, side * .61),
				Vector3(-.65, .91, side * .8),
				Vector3(-1.47, .83, side * .76),
				Vector3(-.77, .84, side * .57)
			],
			paint,
			Vector3(0, 1, side)
		)
	# Windshield perimeter and single endurance wiper.
	for side in [-1, 1]:
		line(Vector3(.56, 1.08, side * .59), Vector3(1.14, .73, side * .75), .024, paint, "APillar")
	line(Vector3(1.15, .786, -.12), Vector3(.63, 1.101, .1), .017, black, "Wiper")
	var banner = text_label("Ferrari", Vector3(.68, 1.084, 0), Vector3.ZERO, .0018, "f2eee0")
	banner.basis = Basis(Vector3(0, 0, -1), Vector3(-.855, .519, 0), Vector3(.519, .855, 0))
	line(Vector3(-.15, 1.22, 0), Vector3(-.15, 1.48, 0), .008, black, "Antenna")
	# Rear engine glazing is recessed between the buttresses.
	panel(
		"EngineCover",
		[
			Vector3(-.75, .875, -.54),
			Vector3(-1.73, .842, -.57),
			Vector3(-1.73, .842, .57),
			Vector3(-.75, .875, .54)
		],
		glass,
		Vector3.UP
	)
	for i in 9:
		block(Vector3(-1.65 + i * .097, .862, 0), Vector3(.031, .013, .94), black, "EngineLouver")


func front_clip():
	var nose = 2.64
	var led = preload("res://scripts/night_style.gd").glow("d3edff", .65)
	# Broad open radiator grille, swept bumper corners and a curved splitter outline.
	panel(
		"RadiatorMouth",
		[
			Vector3(nose, .43, -.81),
			Vector3(nose, .43, .81),
			Vector3(nose - .08, .16, .71),
			Vector3(nose - .08, .16, -.71)
		],
		black,
		Vector3.RIGHT
	)
	for side in [-1, 1]:
		panel(
			"BumperCheek",
			[
				Vector3(2.57, .44, side * .81),
				Vector3(2.30, .56, side * .99),
				Vector3(2.29, .19, side * 1.01),
				Vector3(2.55, .18, side * .78)
			],
			paint,
			Vector3(1, 0, side)
		)
		panel(
			"CornerDuct",
			[
				Vector3(2.583, .405, side * .74),
				Vector3(2.40, .455, side * .93),
				Vector3(2.42, .25, side * .92),
				Vector3(2.57, .23, side * .75)
			],
			black,
			Vector3(1, 0, side)
		)
		line(Vector3(2.65, .42, side * .65), Vector3(2.59, .17, side * .61), .022, black, "GrilleStrut")
		# Recessed swept headlamp pods; luminous blades sit within the lens perimeter.
		var pts = [
			Vector3(2.05, .774, side * .72),
			Vector3(2.14, .726, side * .95),
			Vector3(2.46, .563, side * .86),
			Vector3(2.49, .54, side * .57),
			Vector3(2.27, .65, side * .58)
		]
		panel("HeadlampRecess", pts, Color("07121d"), Vector3(1, 1, side))
		line(
			Vector3(2.39, .602, side * .595),
			Vector3(2.32, .642, side * .83),
			.024,
			"ffffff",
			"LEDRunningLight",
			led
		)
		for z in [.67, .80]:
			line(
				Vector3(2.22, .707, side * z), Vector3(2.26, .685, side * z), .029, "a9d7ed", "Projector", led
			)
		# Two thin shaped dive planes at each bumper corner.
		for h in [.25, .39]:
			panel(
				"FrontCanard",
				[
					Vector3(2.50, h, side * .84),
					Vector3(2.25, h + .10, side * 1.04),
					Vector3(2.09, h + .09, side * 1.08),
					Vector3(2.4, h - .012, side * 1.02)
				],
				black,
				Vector3.UP
			)
		# Vents across the top of each front wheel housing.
		for i in 7:
			var x = 1.08 + i * .082
			var a = crown(x, side * .76) + Vector3.UP * .009
			var b = crown(x + .023, side * .93) + Vector3.UP * .009
			line(a, b, .022, black, "FenderLouver")
	var outline = [
		Vector3(2.76, .115, -.75),
		Vector3(2.76, .115, .75),
		Vector3(2.53, .115, 1.065),
		Vector3(2.02, .115, 1.085),
		Vector3(2.02, .115, -1.085),
		Vector3(2.53, .115, -1.065)
	]
	panel("FrontSplitter", outline, black, Vector3.UP)
	for i in outline.size() - 1:
		line(outline[i], outline[i + 1], .012, "66727b", "SplitterEdge")
	# Central S-duct opening is a trapezoid sunk into the hood, with a raised aft lip.
	panel(
		"HoodExtractionDuct",
		[
			Vector3(1.02, .781, -.38),
			Vector3(1.02, .781, .38),
			Vector3(1.70, .636, .32),
			Vector3(1.70, .636, -.32)
		],
		black,
		Vector3.UP
	)
	panel(
		"DuctInnerRamp",
		[
			Vector3(1.1, .789, -.33),
			Vector3(1.1, .789, .33),
			Vector3(1.4, .703, .30),
			Vector3(1.4, .703, -.30)
		],
		Color("8e1922"),
		Vector3.UP
	)
	line(Vector3(1.09, .79, -.36), Vector3(1.09, .79, .36), .018, paint, "DuctLip")
	# Small enamel nose badge and hood catches, placed on the actual crown surface.
	panel(
		"NoseBadge",
		[
			Vector3(2.39, .483, -.021),
			Vector3(2.39, .483, .021),
			Vector3(2.46, .465, .021),
			Vector3(2.46, .465, -.021)
		],
		Color("f4cf42"),
		Vector3.UP
	)
	for side in [-1, 1]:
		block(crown(1.94, side * .45) + Vector3.UP * .012, Vector3(.074, .015, .031), black, "HoodCatch")


func sides():
	for side in [-1, 1]:
		var out = Vector3(0, 0, side)
		# Deep intake crescent behind the door; painted upper shoulder bridges over it.
		panel(
			"SideAirChannel",
			[
				Vector3(-.86, .85, side * 1.01),
				Vector3(-.61, .87, side * .975),
				Vector3(-.34, .72, side * .947),
				Vector3(.61, .70, side * .946),
				Vector3(.78, .79, side * .952),
				Vector3(.55, .53, side * .947),
				Vector3(-.35, .56, side * .96)
			],
			black,
			out
		)
		panel(
			"DoorSculpture",
			[
				Vector3(-.37, .76, side * .954),
				Vector3(.59, .75, side * .951),
				Vector3(.86, .79, side * .952),
				Vector3(.55, .60, side * .956),
				Vector3(-.22, .63, side * .965)
			],
			paint,
			out
		)
		line(Vector3(.91, .77, side * .956), Vector3(.93, .25, side * .944), .009, black, "DoorCut")
		line(Vector3(-.46, .59, side * .976), Vector3(-.52, .24, side * .97), .009, black, "DoorCut")
		block(Vector3(-.32, .74, side * .973), Vector3(.12, .014, .016), black, "DoorHandle")
		panel(
			"CarbonSill",
			[
				Vector3(-.66, .21, side * 1.02),
				Vector3(.99, .21, side * .99),
				Vector3(.92, .105, side * 1.055),
				Vector3(-.69, .105, side * 1.07)
			],
			black,
			Vector3(0, 1, side)
		)
		# Italian tricolour sill stripe from the launch car.
		for i in 3:
			line(
				Vector3(-.66 + i * .50, .226, side * 1.025),
				Vector3(-.16 + i * .50, .226, side * 1.014),
				.026,
				["16874f", "eeeada", "bd1c27"][i],
				"Tricolore"
			)
		# Race mirror stalk attaches ahead of the side window, not behind the cabin.
		line(Vector3(.87, .86, side * .75), Vector3(.78, .96, side * 1.01), .021, black, "MirrorStalk")
		var mirror = SphereMesh.new()
		mirror.radius = .5
		mirror.height = 1
		mirror.radial_segments = 12
		mirror.rings = 6
		v.shape(body, mirror, Vector3(.78, .98, side * 1.035), Vector3(.20, .085, .14), "242d37", .5, .3)
		# Ferrari shield: small yellow enamel field, preserving the silhouette at game distance.
		panel(
			"FenderShield",
			[
				Vector3(1.01, .69, side * .969),
				Vector3(1.13, .70, side * .978),
				Vector3(1.105, .60, side * .979),
				Vector3(1.065, .57, side * .974)
			],
			Color("edc82c"),
			out
		)
		text_label(
			"296 GT3",
			Vector3(-1.15, .823, side * 1.039),
			Vector3(0, 0 if side > 0 else PI, 0),
			.00145,
			"eee9df"
		)
		text_label(
			str(p.get("num", "51")),
			Vector3(.15, .456, side * .946),
			Vector3(0, 0 if side > 0 else PI, 0),
			.0027,
			"eee9df"
		)


func rear_clip(brakes):
	# Full-width black rear fascia with inset pill-shaped lamps (the 296 has no round rings).
	panel(
		"RearFascia",
		[
			Vector3(-2.023, .775, -.90),
			Vector3(-2.023, .775, .90),
			Vector3(-2.033, .34, .87),
			Vector3(-2.033, .34, -.87)
		],
		black,
		Vector3.LEFT
	)
	var perimeter = [
		Vector3(-2.041, .77, -.86),
		Vector3(-2.041, .79, 0),
		Vector3(-2.041, .77, .86),
		Vector3(-2.041, .65, .94),
		Vector3(-2.041, .44, .81),
		Vector3(-2.041, .425, -.81),
		Vector3(-2.041, .65, -.94),
		Vector3(-2.041, .77, -.86)
	]
	for i in perimeter.size() - 1:
		line(perimeter[i], perimeter[i + 1], .022, paint, "RearSurround")
	for side in [-1, 1]:
		var lamp_points = [
			Vector3(-2.05, .699, side * .47),
			Vector3(-2.05, .722, side * .78),
			Vector3(-2.05, .705, side * .85),
			Vector3(-2.05, .674, side * .81),
			Vector3(-2.05, .666, side * .49),
			Vector3(-2.05, .699, side * .47)
		]
		for i in lamp_points.size() - 1:
			line(lamp_points[i], lamp_points[i + 1], .019, "ff2b14", "TailLight", brakes)
		# Dual high central exhausts with dark open bores.
		var tube = CylinderMesh.new()
		tube.top_radius = .066
		tube.bottom_radius = .066
		tube.height = .13
		tube.radial_segments = 16
		var exhaust = v.shape(body, tube, Vector3(-2.10, .573, side * .15), Vector3.ONE, "8c9295", .7, .4)
		exhaust.rotation.z = PI / 2
		var bore = v.shape(body, tube, Vector3(-2.172, .573, side * .15), Vector3(.78, .035, .78), "080b11")
		bore.rotation.z = PI / 2
		# Swan-neck wing brackets follow a bent profile over the aerofoil.
		var path = [
			Vector3(-1.49, .85, side * .48),
			Vector3(-1.48, 1.17, side * .48),
			Vector3(-1.60, 1.40, side * .48),
			Vector3(-1.90, 1.43, side * .48),
			Vector3(-2.04, 1.33, side * .48)
		]
		for i in path.size() - 1:
			line(path[i], path[i + 1], .055, black, "SwanNeckSupport")
		panel(
			"WingEndplate",
			[
				Vector3(-1.81, 1.41, side * 1.045),
				Vector3(-2.28, 1.38, side * 1.045),
				Vector3(-2.23, 1.20, side * 1.045),
				Vector3(-1.96, 1.20, side * 1.045),
				Vector3(-1.81, 1.27, side * 1.045)
			],
			black,
			Vector3(0, 0, side)
		)
	panel(
		"RearWing",
		[
			Vector3(-1.81, 1.32, -1.06),
			Vector3(-1.81, 1.32, 1.06),
			Vector3(-2.27, 1.34, 1.06),
			Vector3(-2.27, 1.34, -1.06)
		],
		black,
		Vector3.UP
	)
	line(Vector3(-2.27, 1.34, -1.06), Vector3(-2.27, 1.34, 1.06), .029, black, "WingGurney")
	text_label("Ferrari", Vector3(-2.06, 1.236, 0), Vector3(-PI / 2, -PI / 2, 0), .0028, "b5bfc6")
	panel(
		"DiffuserRamp",
		[
			Vector3(-1.62, .11, -.86),
			Vector3(-1.62, .11, .86),
			Vector3(-2.22, .29, .87),
			Vector3(-2.22, .29, -.87)
		],
		black,
		Vector3.UP
	)
	for z in [-.85, -.57, -.28, 0, .28, .57, .85]:
		panel(
			"DiffuserFence",
			[Vector3(-1.62, .11, z), Vector3(-2.23, .10, z), Vector3(-2.23, .36, z), Vector3(-1.94, .20, z)],
			black,
			Vector3(0, 0, 1)
		)
	for side in [-1, 1]:
		for y in [.28, .34, .40]:
			block(Vector3(-1.95, y, side * .96), Vector3(.32, .025, .18), black, "RearAeroStrake")
	block(Vector3(-2.07, .43, 0), Vector3(.018, .063, .065), "ff371c", "RainLight").material_override = brakes


func text_label(text, pos, rot, pixel, color):
	var label = Label3D.new()
	label.text = text
	label.font_size = 96
	label.pixel_size = pixel
	label.outline_size = 0
	label.modulate = Color(color)
	label.position = pos
	label.rotation = rot
	if text == "Ferrari":
		var font = SystemFont.new()
		font.font_names = PackedStringArray(["Georgia", "Times New Roman"])
		font.font_weight = 700
		label.font = font
	body.add_child(label)
	return label


## Launch-car-inspired fender graphics are geometry laid on the actual curved crown.
## They are not flat floating decals, and therefore survive different camera elevations.
func livery():
	var st = begin()
	for side in [-1, 1]:
		for i in 15:
			var x = -1.70 + i * .071
			# Subdivide across the shoulder; one flat quad would intersect the curved fender.
			for segment in 12:
				var a = float(segment) / 12
				var b = float(segment + 1) / 12
				var points = []
				for uv in [[a, 0], [a, .026], [b, .026], [b, 0]]:
					points.append(
						crown(x + uv[0] * .124 + uv[1], side * lerpf(.69, .97, uv[0])) + Vector3.UP * .009
					)
				face(st, points, Color("29222b"), Vector3.UP)
	finish(st, "RearQuarterLivery")


## 18-inch-style ten-spoke forged rim: open spokes, brake rotor, center lock, raised tire lettering.
## All spin parts remain children of spin, while the caliper remains on the steering pivot.
static func wheel_details(visuals, spin, pivot, radius, outer, rim, caliper):
	var cylinder = CylinderMesh.new()
	cylinder.top_radius = .5
	cylinder.bottom_radius = .5
	cylinder.height = 1
	cylinder.radial_segments = 16
	cylinder.rings = 1
	var rubber = TorusMesh.new()
	rubber.inner_radius = radius * .735
	rubber.outer_radius = radius * .995
	rubber.rings = 24
	rubber.ring_segments = 4
	var wall = visuals.shape(spin, rubber, Vector3(0, 0, outer * .13), Vector3(1, .28, 1), "24262b")
	wall.rotation.x = PI / 2
	var dish = visuals.shape(
		spin, cylinder, Vector3(0, 0, outer * .115), Vector3(radius * 1.49, .024, radius * 1.49), "171e25"
	)
	dish.rotation.x = PI / 2
	var rotor = visuals.shape(
		spin,
		cylinder,
		Vector3(0, 0, outer * .142),
		Vector3(radius * 1.19, .013, radius * 1.19),
		"78818b",
		.45,
		.6
	)
	rotor.rotation.x = PI / 2
	var lip = TorusMesh.new()
	lip.inner_radius = radius * .705
	lip.outer_radius = radius * .758
	lip.rings = 24
	lip.ring_segments = 4
	var ring = visuals.shape(spin, lip, Vector3(0, 0, outer * .17), Vector3(1, .52, 1), rim, .55, .32)
	ring.rotation.x = PI / 2
	var cube = BoxMesh.new()
	for spoke in 10:
		var angle = TAU * spoke / 10
		var a = Vector3(cos(angle) * radius * .16, sin(angle) * radius * .16, outer * .185)
		var b = Vector3(cos(angle + .05) * radius * .71, sin(angle + .05) * radius * .71, outer * .169)
		var bar = visuals.shape(spin, cube, (a + b) / 2, Vector3(.017, a.distance_to(b), .024), rim, .55, .32)
		bar.quaternion = Quaternion(Vector3.UP, (b - a).normalized())
		# A short fork where each spoke meets the barrel gives a forged Y cross-section.
		var c = a.lerp(b, .64)
		var d = Vector3(cos(angle - .075) * radius * .71, sin(angle - .075) * radius * .71, outer * .169)
		bar = visuals.shape(spin, cube, (c + d) / 2, Vector3(.012, c.distance_to(d), .023), rim, .55, .32)
		bar.quaternion = Quaternion(Vector3.UP, (d - c).normalized())
	for hole in 20:
		var angle = TAU * hole / 20
		visuals.shape(
			spin,
			cube,
			Vector3(cos(angle) * radius * .50, sin(angle) * radius * .50, outer * .152),
			Vector3(.012, .012, .005),
			"222a31"
		)
	var hub = visuals.shape(
		spin, cylinder, Vector3(0, 0, outer * .185), Vector3(.086, .04, .086), "bfc6ca", .55, .4
	)
	hub.rotation.x = PI / 2
	var lock = visuals.shape(
		spin, cylinder, Vector3(0, 0, outer * .211), Vector3(.046, .014, .046), "262c34", .5, .4
	)
	lock.rotation.x = PI / 2
	visuals.shape(
		pivot,
		cube,
		Vector3(-radius * .43, radius * .15, outer * .158),
		Vector3(.085, .15, .03),
		caliper,
		.2,
		.5
	)
	for legend in [["PIRELLI", PI / 2], ["P ZERO", -PI / 2]]:
		for i in legend[0].length():
			var angle = legend[1] - (i - (legend[0].length() - 1) * .5) * .14 * outer
			var label = Label3D.new()
			label.text = legend[0][i]
			label.font_size = 40
			label.pixel_size = .0010
			label.outline_size = 0
			label.modulate = Color("d0bd66")
			label.position = Vector3(cos(angle) * radius * .87, sin(angle) * radius * .87, outer * .173)
			label.rotation = Vector3(
				0, 0 if outer > 0 else PI, angle - PI / 2 if outer > 0 else PI / 2 - angle
			)
			spin.add_child(label)
