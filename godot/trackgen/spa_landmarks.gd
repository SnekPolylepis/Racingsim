extends RefCounted
## Authored Spa paddock silhouettes based on the circuit's F1 terrace and 2023 Endurance photos.
## Visual only: the surveyed road, runoff, timing and collision stay with spa.gd.
const Builder = preload("res://scripts/track/scenery_builder.gd")
const RoadBuilder = preload("res://scripts/track/road_builder.gd")
const Scatter = preload("res://scripts/track/road_scatter.gd")
const NightGlow = preload("res://scripts/track/night_glow.gd")


static func frame(road: Node3D, station: float, side: int, offset: float) -> Transform3D:
	var curve = road.working_curve()
	var length = curve.get_baked_length()
	var keys = road.sections.duplicate()
	keys.sort_custom(func(a, b): return a.at < b.at)
	var spline = RoadBuilder.elevation_spline(road.elevation_keys, length, road.closed)
	var edge = RoadBuilder.beyond_edge(curve, keys, road.closed, spline, station, side, offset)
	var outward: Vector3 = edge.outward
	return Transform3D(Basis(Vector3.UP.cross(outward), Vector3.UP, outward), edge.point)


static func finish(asset: Node3D, title: String, st: SurfaceTool, xf: Transform3D) -> void:
	st.generate_normals()
	st.set_material(NightGlow.facade_material())
	var instance = MeshInstance3D.new()
	instance.name = title
	instance.mesh = st.commit()
	instance.transform = xf
	asset.get_node("Scenery").add_child(instance)
	instance.owner = asset


static func signboard(
	asset: Node3D, title: String, text: String, xf: Transform3D, pos: Vector3, size: int
) -> void:
	var label = Label3D.new()
	label.name = title
	label.text = text
	label.font_size = size
	label.pixel_size = .018
	label.modulate = Color("eee9df")
	label.outline_modulate = Color("21302e")
	label.outline_size = 4
	label.no_depth_test = false
	label.transform = xf * Transform3D(Basis(Vector3.UP, PI), pos)
	asset.get_node("Scenery").add_child(label)
	label.owner = asset


static func pit_terrace(asset: Node3D, road: Node3D, length: float) -> void:
	# Segmented F1 upper terrace: deep glazing, pale slab overhangs, mullions and rooftop balustrade.
	# Each section follows the actual straight's elevation instead of hovering a long rigid box.
	for i in 23:
		var xf = frame(road, length - 270.0 + i * 10.0, 1, 12.0)
		var st = SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		Builder.add_box(st, Vector3(0, 4.55, 5), Vector3(10, .32, 12), Color("b8bcb4"))
		Builder.add_box(st, Vector3(0, 6.0, 5.0), Vector3(10, 2.65, 9.0), Color("303f46"))
		Builder.add_box(st, Vector3(0, 7.4, 5), Vector3(10.1, .3, 12.4), Color("d4d4c7"))
		Builder.add_box(st, Vector3(0, 5.95, -.15), Vector3(9.7, 2.45, .22), Color("47616c"))
		for x in [-4.8, -2.4, 0.0, 2.4, 4.8]:
			Builder.add_box(st, Vector3(x, 6, -.31), Vector3(.09, 2.8, .18), Color("c1c7c4"))
			Builder.add_box(st, Vector3(x, 8.0, -.9), Vector3(.08, 1.0, .08), Color("c1c7c4"))
		Builder.add_box(st, Vector3(0, 8.45, -.9), Vector3(10, .08, .08), Color("c1c7c4"))
		# Garage shutters now read as actual individual bays under the terrace, with concrete jambs.
		for x in [-4.8, 0.0, 4.8]:
			Builder.add_box(st, Vector3(x, 1.7, -.12), Vector3(.22, 3.4, .38), Color("b3b6b0"))
		for h in [0.6, 1.2, 1.8, 2.4]:
			Builder.add_box(st, Vector3(0, h, .25), Vector3(9.6, .06, .06), Color("657075"))
		finish(asset, "F1Terrace%02d" % i, st, xf)
		if i % 3 == 0:
			signboard(asset, "GarageNumber%02d" % i, "%02d  |  SPA" % (i + 1), xf, Vector3(0, 3.95, -.22), 36)
	var xf = frame(road, length - 145, 1, 12)
	signboard(asset, "PitCircuitSign", "CIRCUIT DE SPA-FRANCORCHAMPS", xf, Vector3(0, 7.75, -1.1), 52)


static func raidillon_canopy(asset: Node3D, road: Node3D, station: float) -> void:
	# Follow the hillside like the seating mesh; one horizontal 130 m roof buried its uphill end.
	for i in 26:
		var xf = frame(road, station - 62.5 + i * 5.0, -1, 12.0)
		var st = SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		Builder.add_box(st, Vector3(0, 10.8, 7.4), Vector3(5.3, .34, 22), Color("c8cec7"))
		Builder.add_box(st, Vector3(0, 10.35, 16.8), Vector3(5.3, 1.0, .25), Color("8a9393"))
		Builder.add_box(st, Vector3(0, 7.7, 15.2), Vector3(5.2, 3, 3.8), Color("405560"))
		Builder.add_box(st, Vector3(0, 7.7, 13.2), Vector3(.12, 3.0, .16), Color("c5cec9"))
		if i % 2 == 0:
			Builder.add_box(st, Vector3(0, 5.4, 16.8), Vector3(.3, 10.8, .35), Color("a9b0a9"))
			Builder.add_box(st, Vector3(0, 10.0, 5.5), Vector3(.2, .26, 19), Color("89918d"))
		finish(asset, "RaidillonCanopy" if i == 0 else "RaidillonCanopy%02d" % i, st, xf)
	var xf = frame(road, station, -1, 12)
	signboard(asset, "RaidillonSign", "SPA-FRANCORCHAMPS  /  RAIDILLON", xf, Vector3(0, 10.15, -3.65), 58)


static func paddock_detail(asset: Node3D, road: Node3D, length: float) -> void:
	# Transporters with cab/wheels and peaked team awnings give the paddock human scale.
	for i in 9:
		var xf = frame(road, length - 210 + i * 17, 1, 36)
		var st = SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var team = [Color("dddaca"), Color("47747a"), Color("b84836")][i % 3]
		Builder.add_box(st, Vector3(0, 2.6, 0), Vector3(12, 2.9, 2.7), Color("d4d3c6"))
		Builder.add_box(st, Vector3(0, 1.0, 0), Vector3(12.2, .28, 2.5), Color("424b4b"))
		Builder.add_box(st, Vector3(0, 3.95, 0), Vector3(12.1, .12, 2.8), Color("aab3b2"))
		Builder.add_box(st, Vector3(-7, 1.95, 0), Vector3(2.5, 2.4, 2.7), team)
		Builder.add_box(st, Vector3(-6.7, 3.25, 0), Vector3(1.9, .3, 2.6), team)
		Builder.add_box(st, Vector3(-8.29, 2.45, 0), Vector3(.08, 1.0, 2.45), Color("354b53"))
		Builder.add_box(st, Vector3(-8.31, 1.35, 0), Vector3(.1, .5, 1.65), Color("293437"))
		Builder.add_box(st, Vector3(-8.35, .83, 0), Vector3(.16, .25, 2.75), Color("a9b3b2"))
		for z in [-1.0, 1.0]:
			Builder.add_box(st, Vector3(-8.34, 1.28, z), Vector3(.12, .28, .46), Color("eee4bb"))
		for z in [-1.38, 1.38]:
			Builder.add_box(st, Vector3(-7.5, 2.45, z), Vector3(1.0, .85, .06), Color("354b53"))
			Builder.add_box(st, Vector3(-7.05, 1.63, z), Vector3(.25, .08, .09), Color("bbc4bf"))
			Builder.add_box(st, Vector3(-7.95, 2.25, z * 1.15), Vector3(.3, .5, .14), Color("313b3d"))
			Builder.add_box(st, Vector3(-6.8, .75, z), Vector3(1.2, .18, .25), Color("828e8f"))
		Builder.add_box(st, Vector3(0, 2.1, -1.4), Vector3(11.5, .45, .06), team)
		for x in [-7.4, -4.4, 3.4, 4.6]:
			for z in [-1.32, 1.32]:
				wheel(st, Vector3(x, .55, z), .55, .34, Color("252a2b"))
				wheel(st, Vector3(x, .55, z * 1.13), .29, .045, Color("899595"))
		# Rear loading doors, centre seam, latch bars, tail lamps and lower side rails.
		for z in [-.66, .66]:
			Builder.add_box(st, Vector3(6.04, 2.62, z), Vector3(.09, 2.68, 1.24), Color("bcc5bd"))
			Builder.add_box(st, Vector3(6.12, 2.62, z), Vector3(.06, 2.45, .065), Color("657272"))
			Builder.add_box(st, Vector3(6.16, 1.13, z), Vector3(.08, .16, .3), Color("8f2f26"))
		for z in [-1.38, 1.38]:
			Builder.add_box(st, Vector3(-.8, .75, z), Vector3(6.2, .12, .1), Color("909e9c"))
			for x in [-5.0, 0.0, 5.0]:
				Builder.add_box(st, Vector3(x, 1.25, z), Vector3(.14, .08, .06), Color("c69b41"))
		for x in [-4, 4]:
			for z in [-7, -3]:
				Builder.add_box(st, Vector3(x, 1.5, z), Vector3(.08, 3, .08), Color("bcc1b9"))
		Builder.add_quad(
			st, Vector3(-4.5, 3, -7.5), Vector3(4.5, 3, -7.5), Vector3(4.5, 4, -5), Vector3(-4.5, 4, -5), team
		)
		Builder.add_quad(
			st, Vector3(-4.5, 4, -5), Vector3(4.5, 4, -5), Vector3(4.5, 3, -2.5), Vector3(-4.5, 3, -2.5), team
		)
		finish(asset, "PaddockTeam%02d" % i, st, xf)


static func wheel(st: SurfaceTool, center: Vector3, radius: float, width: float, colour: Color) -> void:
	# Native low-poly cylinders replace the original box wheels; tyre axes run across the trailer.
	var cylinder = CylinderMesh.new()
	cylinder.top_radius = radius
	cylinder.bottom_radius = radius
	cylinder.height = width
	cylinder.radial_segments = 12
	cylinder.rings = 1
	var arrays = cylinder.surface_get_arrays(0)
	var turn = Basis(Vector3.RIGHT, PI * .5)
	for index in arrays[Mesh.ARRAY_INDEX]:
		st.set_color(colour)
		st.add_vertex(center + turn * arrays[Mesh.ARRAY_VERTEX][index])


static func build(asset: Node3D, road: Node3D, corners: Dictionary, length: float) -> void:
	pit_terrace(asset, road, length)
	raidillon_canopy(asset, road, corners["Raidillon"] + 40)
	paddock_detail(asset, road, length)
	race_control(asset, road, corners["Bus Stop"] + 135)
	clear_building_trees(asset, road, corners, length)
	event_boards(asset, road, corners, length)
	runoff_colours(asset, road, corners["Eau Rouge"] - 50, corners["Raidillon"] + 130)
	runoff_colours(asset, road, corners["Bus Stop"] - 100, corners["Bus Stop"] + 130)


static func kerb_colours(asset: Node3D) -> void:
	# Spa's red/yellow Wallonia kerbs, isolated from the other circuits' shared red/white material.
	var stripe = Image.create(1, 2, false, Image.FORMAT_RGB8)
	stripe.set_pixel(0, 0, Color("c52c23"))
	stripe.set_pixel(0, 1, Color("f1cb36"))
	var texture = ImageTexture.create_from_image(stripe)
	var mesh = asset.get_node("Road/Main").mesh
	for i in mesh.get_surface_count():
		var mat = mesh.surface_get_material(i)
		if mat is StandardMaterial3D and mat.albedo_texture != null:
			var local = mat.duplicate()
			local.albedo_texture = texture
			mesh.surface_set_material(i, local)


static func runoff_colours(asset: Node3D, road: Node3D, from_m: float, to_m: float) -> void:
	# The circuit added Belgian black/yellow/red perimeter paint to these showcase corners in 2022.
	var curve = road.working_curve()
	var length = curve.get_baked_length()
	var keys = road.sections.duplicate()
	keys.sort_custom(func(a, b): return a.at < b.at)
	var spline = RoadBuilder.elevation_spline(road.elevation_keys, length, road.closed)
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var colours = [Color("232a28"), Color("e9be32"), Color("bc362b")]
	for side in [-1, 1]:
		var previous = []
		var s = from_m
		while s <= to_m + 2.0:
			var at = minf(s, to_m)
			var sec = RoadBuilder.section_at(keys, fposmod(at, length), length, true)
			var verge = sec.verge_left if side < 0 else sec.verge_right
			var edge = RoadBuilder.beyond_edge(curve, keys, true, spline, at, side, -verge - 3.4)
			var points = []
			for band in 4:
				points.append(edge.point + edge.outward * (band * 1.05) + edge.up * .045)
			if not previous.is_empty():
				for band in 3:
					Builder.add_quad(
						st, previous[band], previous[band + 1], points[band + 1], points[band], colours[band]
					)
			previous = points
			s += 2.0
	st.generate_normals()
	var mat = StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = .85
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	st.set_material(mat)
	var inst = MeshInstance3D.new()
	inst.name = "BelgianRunoff%04d" % int(from_m)
	inst.mesh = st.commit()
	asset.get_node("Scenery").add_child(inst)
	inst.owner = asset


static func clear_building_trees(asset: Node3D, road: Node3D, corners: Dictionary, length: float) -> void:
	# Reserve the full paddock/stand footprint plus crown margin, rather than clearing only trunks.
	var reservations = [
		[frame(road, length - 160, 1, 12), Vector2(148, 42)],
		[frame(road, length - 120, -1, 8), Vector2(92, 30)],
		[frame(road, corners["La Source"] + 20, -1, 9), Vector2(42, 22)],
		[frame(road, (corners["La Source"] + corners["Eau Rouge"]) * .5, -1, 12), Vector2(95, 30)],
		[frame(road, corners["Eau Rouge"] - 40, 1, 8), Vector2(40, 23)],
		[frame(road, corners["Raidillon"] + 40, -1, 12), Vector2(83, 30)],
		[frame(road, corners["Bus Stop"] - 30, 1, 8), Vector2(50, 24)],
		[frame(road, corners["Bus Stop"] + 135, 1, 18), Vector2(42, 38)]
	]
	for scatter in asset.get_children():
		if not scatter is Scatter or scatter.last_bake.is_empty():
			continue
		var mm = asset.get_node("Scenery/" + str(scatter.name)).multimesh
		for i in scatter.last_bake.xforms.size():
			var xf: Transform3D = scatter.last_bake.xforms[i]
			for reserve in reservations:
				var p = reserve[0].affine_inverse() * xf.origin
				if absf(p.x) < reserve[1].x and p.z > -12 and p.z < reserve[1].y:
					mm.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ZERO), xf.origin))
					break


static func event_boards(asset: Node3D, road: Node3D, corners: Dictionary, length: float) -> void:
	var placements = [
		[corners["La Source"] - 100, -1, "LA SOURCE  /  SPA 24 HOURS"],
		[corners["Raidillon"] + 330, -1, "KEMMEL  /  ARDENNES MOTORSPORT"],
		[corners["Les Combes"] - 130, 1, "CIRCUIT DE SPA-FRANCORCHAMPS"],
		[corners["Pouhon"] - 70, 1, "POUHON  /  TOTALENERGIES"],
		[corners["Fagnes"] + 90, -1, "SPA 24 HOURS  /  PIRELLI"],
		[corners["Stavelot"] - 100, 1, "STAVELOT  /  SPA-FRANCORCHAMPS"],
		[corners["Blanchimont"] - 140, 1, "BLANCHIMONT  /  SPA 24 HOURS"],
		[length - 390, -1, "WELCOME TO SPA-FRANCORCHAMPS"]
	]
	for i in placements.size():
		var item = placements[i]
		var xf = frame(road, item[0], item[1], 3)
		var st = SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var colour = Color("18443d") if i % 2 == 0 else Color("a2362b")
		Builder.add_box(st, Vector3(0, 1.5, 0), Vector3(20, 2.0, .15), colour)
		for x in [-8.0, 0.0, 8.0]:
			Builder.add_box(st, Vector3(x, .7, .15), Vector3(.12, 1.4, .12), Color("6e7571"))
		finish(asset, "SpaEventPanel%02d" % i, st, xf)
		signboard(asset, "SpaEventTitle%02d" % i, item[2], xf, Vector3(0, 1.5, -.13), 42)


static func race_control(asset: Node3D, road: Node3D, station: float) -> void:
	var xf = frame(road, station, 1, 18)
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Paddock-side operations and hospitality silhouette visible through the Bus Stop sightline.
	Builder.add_box(st, Vector3(0, 5.0, 8), Vector3(42, 10, 16), Color("bfc2b6"))
	for level in [3.5, 6.5, 9.0]:
		Builder.add_box(st, Vector3(0, level, -.12), Vector3(39, 1.5, .22), Color("405660"))
		Builder.add_box(st, Vector3(0, level + .85, -.3), Vector3(43, .18, 1.2), Color("d6d4c8"))
	for x in range(-18, 19, 3):
		Builder.add_box(st, Vector3(x, 6.6, -.3), Vector3(.12, 6.8, .15), Color("d1d4c8"))
	Builder.add_box(st, Vector3(0, 10.2, 8), Vector3(45, .35, 19), Color("717c79"))
	Builder.add_box(st, Vector3(-12, 11.5, 9), Vector3(8, 2.5, 7), Color("798c8c"))
	finish(asset, "SpaRaceControl", st, xf)
	signboard(asset, "SpaRaceControlTitle", "CIRCUIT DE SPA-FRANCORCHAMPS", xf, Vector3(0, 1.8, -.25), 58)
