extends RefCounted
## Roof crowns for sourced Chicago landmarks (trackgen/data/chicago/landmarks.json "crown").
## Each entry: [footprint ring (x, z), roof y, crown dict]. Only shapes the cited source describes.


static func build(asset: Node3D, holder: Node3D, crowns: Array) -> void:
	var i = 0
	for entry in crowns:
		var ring: PackedVector2Array = entry[0]
		var top: float = entry[1]
		var cr: Dictionary = entry[2]
		var c = centroid(ring)
		var node: Node3D = null
		match str(cr.type):
			"spire":
				node = cylinder(float(cr.r), 0.05, float(cr.h), metal(Color(cr.c)))
				node.position = Vector3(c.x, top + float(cr.h) * .5, c.y)
			"mast":
				node = cylinder(float(cr.r), 0.25, float(cr.h), metal(Color("9a9ea2")))
				node.position = Vector3(c.x, top + float(cr.h) * .5, c.y)
			"pyramid":
				node = pyramid(ring, top, float(cr.h), metal(Color(cr.c)))
				if cr.has("beacon"):
					var b = cr.beacon
					var glow = StandardMaterial3D.new()
					glow.albedo_color = Color(b.c)
					glow.emission = Color(b.c)
					glow.emission_energy_multiplier = 6.0
					glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
					glow.albedo_color.a = 0.8
					glow.set_meta("chicago_night", true)
					var hive = cylinder(float(b.r) * .6, float(b.r), float(b.h), glow)
					hive.position = Vector3(c.x, top + float(cr.h) + float(b.h) * .5, c.y)
					node.add_child(hive)
					hive.position -= node.position
			"slant":
				node = slant(ring, top, float(cr.h), glass(Color("c8ccd0")))
			"gable":
				node = gable(ring, top, float(cr.h), tiles(Color(cr.c)))
			"cupola":
				node = cylinder(float(cr.r), float(cr.r), float(cr.h) * .6, stone())
				node.position = Vector3(c.x, top + float(cr.h) * .3, c.y)
				var dome = hemisphere(float(cr.r) * 1.05, stone())
				dome.position = Vector3(0, float(cr.h) * .3, 0)
				node.add_child(dome)
			"twin_domes":
				node = Node3D.new()
				var ax = long_axis(ring)
				for t in [-0.25, 0.25]:
					var d = hemisphere(float(cr.r), glass(Color("8fb0b8")))
					d.position = Vector3(c.x + ax.x * t, top, c.y + ax.y * t)
					node.add_child(d)
			"sign":
				var label = Label3D.new()
				label.text = str(cr.text)
				label.font = preload("res://assets/fonts/Rajdhani-Bold.ttf")
				label.font_size = 160
				label.pixel_size = 0.05
				label.double_sided = true
				label.shaded = false
				label.modulate = Color(cr.c) * 2.5
				label.position = Vector3(c.x, top + 4.0, c.y)
				node = label
		if node == null:
			continue
		node.name = "Crown%d" % i
		i += 1
		holder.add_child(node)
		node.owner = asset
		for child in node.find_children("*", "", true, false):
			child.owner = asset


static func centroid(ring: PackedVector2Array) -> Vector2:
	var c = Vector2.ZERO
	for p in ring:
		c += p
	return c / ring.size()


## The footprint's longer bounding-box axis, full length.
static func long_axis(ring: PackedVector2Array) -> Vector2:
	var lo = ring[0]
	var hi = ring[0]
	for p in ring:
		lo = lo.min(p)
		hi = hi.max(p)
	var size = hi - lo
	return Vector2(size.x, 0) if size.x > size.y else Vector2(0, size.y)


static func metal(c: Color) -> StandardMaterial3D:
	var m = StandardMaterial3D.new()
	m.albedo_color = c
	m.metallic = 0.8
	m.roughness = 0.3
	return m


static func glass(c: Color) -> StandardMaterial3D:
	var m = StandardMaterial3D.new()
	m.albedo_color = c
	m.metallic = 0.4
	m.roughness = 0.12
	return m


static func tiles(c: Color) -> StandardMaterial3D:
	var m = StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.7
	return m


## A pitched roof over the footprint's bounding box, ridge along the long axis.
static func gable(ring: PackedVector2Array, top: float, h: float, mat: Material) -> MeshInstance3D:
	var lo = ring[0]
	var hi = ring[0]
	for p in ring:
		lo = lo.min(p)
		hi = hi.max(p)
	var along_x = hi.x - lo.x > hi.y - lo.y
	var mid = (lo + hi) * .5
	var a = Vector3(lo.x, top, lo.y)
	var b = Vector3(hi.x, top, lo.y)
	var c = Vector3(hi.x, top, hi.y)
	var d = Vector3(lo.x, top, hi.y)
	var r0 = Vector3(lo.x, top + h, mid.y) if along_x else Vector3(mid.x, top + h, lo.y)
	var r1 = Vector3(hi.x, top + h, mid.y) if along_x else Vector3(mid.x, top + h, hi.y)
	var tris = (
		[a, b, r1, a, r1, r0, d, r0, r1, d, r1, c, a, r0, d, b, c, r1]
		if along_x
		else [a, r0, r1, a, r1, d, b, c, r1, b, r1, r0, a, b, r0, d, r1, c]
	)
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for v in tris:
		st.add_vertex(v)
	st.generate_normals()
	var node = MeshInstance3D.new()
	node.mesh = st.commit()
	node.material_override = mat
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return node


static func stone() -> StandardMaterial3D:
	var m = StandardMaterial3D.new()
	m.albedo_color = Color("bdb8ac")
	m.roughness = 0.85
	return m


static func cylinder(bottom: float, top_r: float, h: float, mat: Material) -> MeshInstance3D:
	var mesh = CylinderMesh.new()
	mesh.bottom_radius = bottom
	mesh.top_radius = top_r
	mesh.height = h
	mesh.material = mat
	var node = MeshInstance3D.new()
	node.mesh = mesh
	return node


static func hemisphere(r: float, mat: Material) -> MeshInstance3D:
	var mesh = SphereMesh.new()
	mesh.radius = r
	mesh.height = r * 2.0
	mesh.is_hemisphere = true
	mesh.material = mat
	var node = MeshInstance3D.new()
	node.mesh = mesh
	return node


## Footprint edges up to an apex over the centroid.
static func pyramid(ring: PackedVector2Array, top: float, h: float, mat: Material) -> MeshInstance3D:
	var c = centroid(ring)
	var apex = Vector3(c.x, top + h, c.y)
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in ring.size():
		var a = ring[i]
		var b = ring[(i + 1) % ring.size()]
		st.add_vertex(Vector3(a.x, top, a.y))
		st.add_vertex(Vector3(b.x, top, b.y))
		st.add_vertex(apex)
	st.generate_normals()
	var node = MeshInstance3D.new()
	node.mesh = st.commit()
	node.material_override = mat
	return node


## The footprint extruded to a roof plane rising h metres along its long axis (the Crain 'diamond' cut).
static func slant(ring: PackedVector2Array, top: float, h: float, mat: Material) -> MeshInstance3D:
	var ax = long_axis(ring).normalized()
	var lo = INF
	var hi = -INF
	for p in ring:
		lo = minf(lo, p.dot(ax))
		hi = maxf(hi, p.dot(ax))
	var y = func(p: Vector2) -> float: return top + h * (p.dot(ax) - lo) / maxf(hi - lo, 0.1)
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in ring.size():
		var a = ring[i]
		var b = ring[(i + 1) % ring.size()]
		for v in [
			Vector3(a.x, top, a.y), Vector3(b.x, top, b.y), Vector3(b.x, y.call(b), b.y),
			Vector3(a.x, top, a.y), Vector3(b.x, y.call(b), b.y), Vector3(a.x, y.call(a), a.y)
		]:
			st.add_vertex(v)
	for idx in Geometry2D.triangulate_polygon(ring):
		st.add_vertex(Vector3(ring[idx].x, y.call(ring[idx]), ring[idx].y))
	st.generate_normals()
	var node = MeshInstance3D.new()
	node.mesh = st.commit()
	node.material_override = mat
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return node
