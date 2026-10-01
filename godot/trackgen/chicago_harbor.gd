extends RefCounted
## Lakefront dressing from real data (city.json):
## - a moored sailboat on every OSM mooring point (Monroe Harbor, Navy Pier marina); boats share one
##   heading as moored boats swing together to the wind (ponytail: fixed heading, no wind model);
## - OSM piers and breakwaters as concrete decks just above the lake;
## - LiDAR-measured sculptural steel (Pritzker Pavilion headdress, Great Lawn trellis) as thin shells.

const LAKE_Y = 6.5
const STREET_Y = 8.0
const HULL_L = 9.0
const HULL_W = 3.0
const MAST_H = 13.0


static func build(asset: Node3D, parent: Node, doc: Dictionary) -> Dictionary:
	var box = preload("res://trackgen/chicago_l.gd").box
	# Boats.
	var st = {}
	for key in ["hull", "deck", "mast"]:
		st[key] = SurfaceTool.new()
		st[key].begin(Mesh.PRIMITIVE_TRIANGLES)
	box.call(st.hull, Vector3(0, 0.35, 0), Vector3(HULL_W, 1.1, HULL_L * 0.8), Basis.IDENTITY)
	box.call(
		st.hull, Vector3(0, 0.45, -HULL_L * 0.45), Vector3(HULL_W * 0.55, 0.9, HULL_L * 0.2), Basis.IDENTITY
	)
	box.call(st.deck, Vector3(0, 1.2, 0.8), Vector3(HULL_W * 0.6, 0.7, HULL_L * 0.35), Basis.IDENTITY)
	box.call(st.mast, Vector3(0, 0.9 + MAST_H * .5, -0.6), Vector3(0.14, MAST_H, 0.14), Basis.IDENTITY)
	box.call(st.mast, Vector3(0, 3.0, 0.9), Vector3(0.1, 0.1, 3.4), Basis.IDENTITY)
	var mats = {
		"hull": _mat(Color("eef0ee"), 0.0, 0.35),
		"deck": _mat(Color("c9c3b6"), 0.0, 0.6),
		"mast": _mat(Color("b8bcc0"), 0.8, 0.3)
	}
	var boat = ArrayMesh.new()
	for key in st:
		st[key].generate_normals()
		st[key].set_material(mats[key])
		st[key].commit(boat)
	var moorings: Array = doc.get("moorings", [])
	var mm = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = boat
	mm.instance_count = moorings.size()
	var rng = RandomNumberGenerator.new()
	rng.seed = 60611
	for i in moorings.size():
		var yaw = deg_to_rad(200.0 + rng.randf_range(-12.0, 12.0))
		mm.set_instance_transform(
			i,
			Transform3D(
				Basis(Vector3.UP, yaw) * rng.randf_range(0.8, 1.25),
				Vector3(moorings[i][0], LAKE_Y - 0.2, moorings[i][1])
			)
		)
	var boats = MultiMeshInstance3D.new()
	boats.name = "MooredBoats"
	boats.multimesh = mm
	parent.add_child(boats)
	boats.owner = asset
	# Piers and breakwaters.
	var pier = SurfaceTool.new()
	pier.begin(Mesh.PRIMITIVE_TRIANGLES)
	var areas = {}
	for p in doc.get("piers", []):
		if p.get("area", 0):
			var ring = PackedVector2Array()
			for q in p.p.slice(0, -1):
				ring.append(Vector2(q[0], q[1]))
			areas[p.o] = ring
	for p in doc.get("piers", []):
		var pts: Array = p.p
		if p.get("area", 0):
			var ring: PackedVector2Array = areas[p.o]
			for index in Geometry2D.triangulate_polygon(ring):
				pier.add_vertex(Vector3(ring[index].x, LAKE_Y + 1.4, ring[index].y))
			# Retain the previous vertical envelope until dock levels/supports are sourced.
			for k in ring.size():
				var a = ring[k]
				var b = ring[(k + 1) % ring.size()]
				var vertices = [
					Vector3(a.x, LAKE_Y - .2, a.y),
					Vector3(b.x, LAKE_Y - .2, b.y),
					Vector3(b.x, LAKE_Y + 1.4, b.y),
					Vector3(a.x, LAKE_Y + 1.4, a.y)
				]
				for index in [0, 1, 2, 0, 2, 3]:
					pier.add_vertex(vertices[index])
			continue
		# OSM footway centre lines inside a mapped pier area describe the same deck.
		var covered = false
		for ring in areas.values():
			var inside = true
			for k in pts.size() - 1:
				var a = Vector2(pts[k][0], pts[k][1])
				var b = Vector2(pts[k + 1][0], pts[k + 1][1])
				for q in [a, (a + b) * .5, b]:
					if not Geometry2D.is_point_in_polygon(q, ring):
						inside = false
			if inside:
				covered = true
				break
		if covered:
			continue
		for k in pts.size() - 1:
			var a = Vector3(pts[k][0], LAKE_Y + 0.6, pts[k][1])
			var b = Vector3(pts[k + 1][0], LAKE_Y + 0.6, pts[k + 1][1])
			if a.distance_to(b) < 0.1:
				continue
			box.call(
				pier,
				(a + b) * .5,
				Vector3(float(p.w), 1.6, a.distance_to(b) + 0.2),
				Basis.looking_at(b - a, Vector3.UP)
			)
	pier.generate_normals()
	var pier_node = MeshInstance3D.new()
	pier_node.name = "Piers"
	pier_node.mesh = pier.commit()
	pier_node.material_override = _mat(Color("a8a59c"), 0.0, 0.85)
	parent.add_child(pier_node)
	pier_node.owner = asset
	# Published concrete core dimensions; variable stainless covers remain to be sourced.
	var pavilion: Dictionary = doc.get("pavilion", {})
	var pylons: Array = pavilion.get("pylons", [])
	if not pylons.is_empty():
		var core = CylinderMesh.new()
		core.top_radius = float(pavilion.diameter) * .5
		core.bottom_radius = core.top_radius
		core.height = float(pavilion.height)
		core.radial_segments = 24
		core.material = _mat(Color("a8a59c"), 0.0, 0.85)
		var cores = MultiMesh.new()
		cores.transform_format = MultiMesh.TRANSFORM_3D
		cores.mesh = core
		cores.instance_count = pylons.size()
		for i in pylons.size():
			cores.set_instance_transform(
				i,
				Transform3D(Basis.IDENTITY, Vector3(pylons[i][0], STREET_Y + core.height * .5, pylons[i][1]))
			)
		var supports = MultiMeshInstance3D.new()
		supports.name = "PritzkerPylonCores"
		supports.multimesh = cores
		parent.add_child(supports)
		supports.owner = asset
	# LiDAR steel shells.
	var steel = SurfaceTool.new()
	steel.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cells = 0
	for sh in doc.get("shells", []):
		var x0 = float(sh[0])
		var z0 = float(sh[1])
		var w = int(sh[2])
		var h = int(sh[3])
		var c = float(sh[4])
		var thick = float(sh[6])
		var raw = Marshalls.base64_to_raw(str(sh[5]))
		var at = func(i: int, j: int) -> float:
			return raw.decode_u16((j * w + i) * 2) * 0.1 if i >= 0 and j >= 0 and i < w and j < h else 0.0
		for j in h:
			for i in w:
				var y = at.call(i, j)
				if y <= 0.0:
					continue
				var p = Vector3(x0 + (i + .5) * c, STREET_Y + y - thick * .5, z0 + (j + .5) * c)
				box.call(steel, p, Vector3(c, thick, c), Basis.IDENTITY)
				cells += 1
	steel.generate_normals()
	var steel_node = MeshInstance3D.new()
	steel_node.name = "PritzkerSteel"
	steel_node.mesh = steel.commit()
	steel_node.material_override = _mat(Color("c7cbcf"), 0.9, 0.22)
	parent.add_child(steel_node)
	steel_node.owner = asset
	var trellis: Dictionary = pavilion.get("trellis", {})
	if not trellis.is_empty():
		var pipe = CylinderMesh.new()
		pipe.height = 1.0
		pipe.top_radius = float(trellis.diameter) * .5
		pipe.bottom_radius = pipe.top_radius
		pipe.radial_segments = 8
		pipe.cap_top = false
		pipe.cap_bottom = false
		var tubes = SurfaceTool.new()
		tubes.begin(Mesh.PRIMITIVE_TRIANGLES)
		for edge in trellis.edges:
			var pa: Array = trellis.nodes[edge[0]]
			var pb: Array = trellis.nodes[edge[1]]
			var a = Vector3(pa[0], STREET_Y + pa[1], pa[2])
			var b = Vector3(pb[0], STREET_Y + pb[1], pb[2])
			var basis = Basis.looking_at(b - a, Vector3.UP) * Basis(Vector3.RIGHT, PI * .5)
			basis *= Basis.from_scale(Vector3(1, a.distance_to(b), 1))
			tubes.append_from(pipe, 0, Transform3D(basis, (a + b) * .5))
		var network = MeshInstance3D.new()
		network.name = "PritzkerMeasuredPipes"
		network.mesh = tubes.commit()
		network.material_override = steel_node.material_override
		parent.add_child(network)
		network.owner = asset
	return {"boats": moorings.size(), "steel_cells": cells, "pavilion_pylons": pylons.size()}


static func _mat(c: Color, metal: float, rough: float) -> StandardMaterial3D:
	var m = StandardMaterial3D.new()
	m.albedo_color = c
	m.metallic = metal
	m.roughness = rough
	return m
