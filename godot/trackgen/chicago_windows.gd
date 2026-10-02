extends RefCounted
## Near-route LiDAR facades: measured wall planes, acquired CC0 frames and glazing.
## Generic bay spacing is an interpretation; these are not surveyed landmark elevations.
const Kit = preload("res://trackgen/chicago_kit.gd")
const GLASS = preload("res://shaders/chicago_window_glass.gdshader")
const RANGE_M = 160.0
const CHUNK_M = 100.0
const STREET_Y = 8.0


static func _hash(p: Vector2) -> float:
	return fposmod(sin(p.dot(Vector2(127.1, 311.7))) * 43758.5453, 1.0)


## SurfaceTool's unindexed wall quads are six vertices. Merge adjacent coplanar
## raster cells before placing windows, so a cell boundary never cuts a frame.
static func collect(arrays: Array, route: Dictionary, walls: Dictionary) -> void:
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var colours: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	for i in range(0, vertices.size() - 5, 3):
		# Polygon roofs may use an odd number of triangles between wall quads.
		if (
			not vertices[i].is_equal_approx(vertices[i + 3])
			or not vertices[i + 2].is_equal_approx(vertices[i + 4])
		):
			continue
		var n = normals[i]
		if colours[i].b > .5 or absf(n.y) > .01 or n.length_squared() < .99:
			continue
		var a = vertices[i]
		var b = vertices[i + 1]
		var top = vertices[i + 2]
		if absf(a.y - b.y) > .01 or top.y <= a.y + .05:
			continue
		var mid = (a + top) * .5
		var nearest = Kit.nearest_route(route, Vector2(mid.x, mid.z), RANGE_M)
		var to_route = nearest - Vector2(mid.x, mid.z)
		if (
			nearest.x == INF
			or to_route.length() > RANGE_M
			or Vector2(n.x, n.z).dot(to_route.normalized()) < .15
		):
			continue
		var along = Vector3(n.z, 0, -n.x)
		var plane = n.dot(a)
		var lo = minf(along.dot(a), along.dot(b))
		var hi = maxf(along.dot(a), along.dot(b))
		var colour = colours[i]
		var key = (
			"%d|%d|%d|%d|%d"
			% [
				roundi(n.x * 10000),
				roundi(n.z * 10000),
				roundi(plane * 100),
				roundi(colour.r * 100000),
				roundi(colour.g * 8)
			]
		)
		if not walls.has(key):
			walls[key] = {
				"normal": n,
				"plane": plane,
				"bottom": maxf(a.y, STREET_Y),
				"top": top.y,
				"seed": colour.r,
				"kind": roundi(colour.g * 8),
				"runs": []
			}
		walls[key].bottom = minf(walls[key].bottom, maxf(a.y, STREET_Y))
		walls[key].top = maxf(walls[key].top, top.y)
		walls[key].runs.append(Vector4(lo, hi, maxf(a.y, STREET_Y), top.y))
		# Vertex colours are packed into unsigned bytes; reserve .5/.75 for physical windows.
		for k in range(i, i + 6):
			colours[k].b = .75 if colours[k].b > .1 else .5
	arrays[Mesh.ARRAY_COLOR] = colours


static func build(asset: Node3D, holder: Node, walls: Dictionary) -> int:
	var groups = {}
	var count = 0
	for wall in walls.values():
		wall.runs.sort_custom(func(a, b): return a.x < b.x)
		var seed: float = wall.seed
		var bay = Vector2(
			1.9 * lerpf(.85, 1.28, _hash(Vector2(seed * 61.7, 3.1))),
			3.9 * lerpf(.91, 1.08, _hash(Vector2(seed * 17.3, 9.7)))
		)
		var glassy: bool = wall.kind < 2
		var n: Vector3 = wall.normal
		var along = Vector3(n.z, 0, -n.x)
		for row in range(
			maxi(0, floori((wall.bottom - STREET_Y) / bay.y)), ceili((wall.top - STREET_Y) / bay.y)
		):
			var pane_lo = Vector2(.04, .1) if glassy else Vector2(.21, .2)
			var pane_hi = Vector2(.96, .9) if glassy else Vector2(.79, .8)
			if row == 0:
				pane_lo = Vector2(.05, .12)
				pane_hi = Vector2(.95, .85)
			var scale = Vector3(
				bay.x * (pane_hi.x - pane_lo.x) / 1.805215, bay.y * (pane_hi.y - pane_lo.y) / 2.425318, 1.0
			)
			var y = STREET_Y + (row + pane_lo.y) * bay.y - .515983 * scale.y
			var merged = []
			# Merge only cells that contain this entire storey: slight measured roof noise
			# must not break every floor below into independent two-metre strips.
			for run in wall.runs:
				# The removed kickboard occupied y=0..0.474; the retained frame starts above it.
				if y + .473909 * scale.y < run.z + .02 or y + 3.0 * scale.y > run.w - .02:
					continue
				if not merged.is_empty() and run.x <= merged[-1].y + .02:
					merged[-1].y = maxf(merged[-1].y, run.y)
				else:
					merged.append(Vector2(run.x, run.y))
			for run in merged:
				for column in range(floori(run.x / bay.x), ceili(run.y / bay.x)):
					var u = (column + .5) * bay.x
					if u - scale.x < run.x + .02 or u + scale.x > run.y - .02:
						continue
					var p = n * wall.plane + along * u + Vector3.UP * y
					p += n * .13
					var cell = Vector2(column, row)
					var occupancy = lerpf(.05, .75, _hash(Vector2(row, seed * 53)))
					var lit = (
						row > 0
						and (
							_hash(cell + Vector2.ONE * seed * 97)
							>= 1.0 - occupancy - (.08 if glassy else 0.0)
						)
					)
					var custom = Color(
						lerpf(.24, .72, _hash(cell * 1.7 + Vector2.ONE * seed * 5)) if lit else 0.0,
						1.0 if glassy else 0.0,
						_hash(cell + Vector2.ONE * seed * 7.1),
						1.0
					)
					var key = Vector2i(floori(p.x / CHUNK_M), floori(p.z / CHUNK_M))
					if not groups.has(key):
						groups[key] = []
					groups[key].append(
						[Transform3D(Basis(along, Vector3.UP, n).scaled_local(scale), p), custom]
					)
					count += 1
	var mesh = ArrayMesh.new()
	var source = Kit._mesh("Metal_FirstFloor_Window")
	for surface in [1, 2]:
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, source.surface_get_arrays(surface))
		var mat = source.surface_get_material(surface)
		if surface == 2:
			mat = ShaderMaterial.new()
			mat.shader = GLASS
		mesh.surface_set_material(mesh.get_surface_count() - 1, mat)
	for key in groups:
		var instances = MultiMesh.new()
		instances.transform_format = MultiMesh.TRANSFORM_3D
		instances.use_custom_data = true
		instances.mesh = mesh
		instances.instance_count = groups[key].size()
		for i in instances.instance_count:
			instances.set_instance_transform(i, groups[key][i][0])
			instances.set_instance_custom_data(i, groups[key][i][1])
		var node = MultiMeshInstance3D.new()
		node.name = "Windows3D_%d_%d" % [key.x, key.y]
		node.multimesh = instances
		node.visibility_range_end = 650.0
		node.visibility_range_end_margin = 80.0
		node.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		# Measured building bodies cast street shadows; tiny frames need no extra lamp-shadow draws.
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		holder.add_child(node)
		node.owner = asset
	return count
