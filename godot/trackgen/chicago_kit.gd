extends RefCounted
## Quaternius Downtown City MegaKit pieces (CC0, baked by tools/build_downtown_kit.gd) on Chicago's buildings
## near the circuit (CHI-LOOK-02): a shopfront ground floor and a cornice along every footprint edge that faces
## the route, within RANGE_M of it. One MultiMesh per piece and 300 m chunk, culled beyond CULL_M, so it
## costs a handful of draw calls near the car and none far away. Presentation only: no collision.

const KIT = "res://assets/chicago/downtown-kit/meshes/"
const STREET_Y = 8.0
const MODULE_M = 2.0
const RANGE_M = 55.0
const CULL_M = 320.0
const CHUNK = 300.0
const MIN_EDGE_M = 5.0
## The kit sits recessed 0.2-0.3 m behind its front plane; stand it off the wall by its (scaled) depth.
const WALL_OFFSET_M = 0.36
## Chunky PS2 proportions: the kit's 3 m storey is stretched so shopfronts and cornices read from the car.
const STOREY_SCALE = 1.4
const CORNICE_SCALE = Vector3(1.0, 2.2, 2.4)
const CORNICE_MAX_H = 110.0
const SHOP_SETS = [
	["Metal_FirstFloor_Window", "Metal_FirstFloor_Wall"],
	["Trim_FirstFloor_Window_001", "Trim_FirstFloor_Wall"]
]
const CORNICES = ["Cornice_Brick_Center", "Cornice_Metal_Center", "Cornice_Trim_Center"]

static var _meshes = {}


static func _mesh(name: String) -> Mesh:
	if not _meshes.has(name):
		_meshes[name] = load(KIT + name + ".res")
	return _meshes[name]


static func _hash(a: int, b: int) -> float:
	return fposmod(sin(float(a) * 127.1 + float(b) * 311.7) * 43758.5453, 1.0)


## `route` is ChicagoCity's 25 m cell index of route points ({Vector2i: [Vector3]}).
static func nearest_route(route: Dictionary, p: Vector2, reach: float) -> Vector2:
	var best = INF
	var at = Vector2.ZERO
	var cx = floori(p.x / 25.0)
	var cz = floori(p.y / 25.0)
	var r = ceili(reach / 25.0)
	for dx in range(-r, r + 1):
		for dz in range(-r, r + 1):
			for q in route.get(Vector2i(cx + dx, cz + dz), []):
				var d = p.distance_to(Vector2(q.x, q.z))
				if d < best:
					best = d
					at = Vector2(q.x, q.z)
	return at if best < INF else Vector2(INF, INF)


## `buildings`: [[ring PackedVector2Array, height m, index int]] for buildings near the route.
static func build(asset: Node3D, holder: Node, buildings: Array, route: Dictionary) -> Dictionary:
	var groups = {}
	var stats = {"kit_instances": 0}
	for entry in buildings:
		var ring: PackedVector2Array = entry[0]
		var h: float = entry[1]
		var idx: int = entry[2]
		var centre = Vector2.ZERO
		for p in ring:
			centre += p
		centre /= ring.size()
		var shop = SHOP_SETS[int(_hash(idx, 5) * SHOP_SETS.size()) % SHOP_SETS.size()]
		var cornice = CORNICES[int(_hash(idx, 9) * CORNICES.size()) % CORNICES.size()]
		for i in ring.size():
			var a = ring[i]
			var b = ring[(i + 1) % ring.size()]
			var length = a.distance_to(b)
			if length < MIN_EDGE_M:
				continue
			var mid = (a + b) * 0.5
			var out = Vector2(b.y - a.y, a.x - b.x).normalized()
			# Outward = the side of the edge that is not inside the footprint (robust for L and U shapes).
			if Geometry2D.is_point_in_polygon(mid + out * 0.4, ring):
				out = -out
			var q = nearest_route(route, mid, RANGE_M)
			if q.x == INF:
				continue
			var to_route = q - mid
			if to_route.length() > RANGE_M or out.dot(to_route.normalized()) < 0.3:
				continue
			var dir = (b - a) / length
			var count = int(length / MODULE_M)
			var start = mid - dir * (count * MODULE_M * 0.5) + dir * (MODULE_M * 0.5)
			# The kit faces +Z; the edge's outward normal becomes local +Z, its direction local +X.
			var basis = Basis(Vector3(dir.x, 0, dir.y), Vector3.UP, Vector3(out.x, 0, out.y))
			if basis.determinant() < 0.0:
				# Mirrored: walk the edge the other way so the kit's front face stays outward.
				dir = -dir
				start = mid - dir * (count * MODULE_M * 0.5) + dir * (MODULE_M * 0.5)
				basis = Basis(Vector3(dir.x, 0, dir.y), Vector3.UP, Vector3(out.x, 0, out.y))
			for k in count:
				var at = start + dir * (k * MODULE_M) + out * WALL_OFFSET_M
				var roll = _hash(idx * 31 + k, i)
				var name = shop[0] if roll < 0.7 else shop[1]
				var storey = basis.scaled_local(Vector3(1.0, STOREY_SCALE, 1.3))
				_add(groups, name, Transform3D(storey, Vector3(at.x, STREET_Y, at.y)))
				stats.kit_instances += 1
				if h >= 14.0:
					var second = shop[0] if _hash(idx * 17 + k, i + 3) < 0.6 else shop[1]
					_add(
						groups,
						second,
						Transform3D(storey, Vector3(at.x, STREET_Y + 3.0 * STOREY_SCALE, at.y))
					)
					stats.kit_instances += 1
				if h >= 9.0 and h <= CORNICE_MAX_H:
					var top = basis.scaled_local(CORNICE_SCALE)
					_add(groups, cornice, Transform3D(top, Vector3(at.x, STREET_Y + h - 2.2, at.y)))
					stats.kit_instances += 1
	for id in groups:
		var key = groups[id]
		var list: Array = key.list
		var instances = MultiMesh.new()
		instances.transform_format = MultiMesh.TRANSFORM_3D
		instances.mesh = _mesh(key.name)
		instances.instance_count = list.size()
		for n in list.size():
			instances.set_instance_transform(n, list[n])
		var node = MultiMeshInstance3D.new()
		node.name = "Kit_%s_%d_%d" % [key.name, key.x, key.z]
		node.multimesh = instances
		node.visibility_range_end = CULL_M
		node.visibility_range_end_margin = 40.0
		node.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		holder.add_child(node)
		node.owner = asset
	return stats


static func _add(groups: Dictionary, name: String, xform: Transform3D) -> void:
	var cx = floori(xform.origin.x / CHUNK)
	var cz = floori(xform.origin.z / CHUNK)
	var id = "%s|%d|%d" % [name, cx, cz]
	if not groups.has(id):
		groups[id] = {"name": name, "x": cx, "z": cz, "list": []}
	groups[id].list.append(xform)
