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

const ChicagoFurniture = preload("res://trackgen/chicago_furniture.gd")
const PropMesh = preload("res://scripts/track/prop_mesh.gd")
## Street Asset Pack by vmatthew (CC BY 4.0), split by tools/blender/extract_props.py (ASSET-02).
const STREET_PACK = "res://assets/chicago/street-pack/"
## City Props Collection vol. 1 by TampaJoey (Sketchfab licence, personal use) and PSX Barrels by Shazly (CC BY 4.0).
const CITY_PROPS = "res://assets/chicago/city-props/"
const BARRELS = "res://assets/chicago/barrels/"
const CITY_KINDS = [
	"atm",
	"bench",
	"bus_stop",
	"park_bench",
	"dumpster",
	"fire_hydrant",
	"parking_meter",
	"post_box",
	"trash_can",
	"trash_can_cap",
	"trash_commercial",
	"utility_box",
	"pallets",
	"tarp_crates",
	"post_barrier"
]

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


## `buildings`: [[ring, height, index, flat_roof]]; measured stepped roofs keep their own silhouette.
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
				# LOOK-15: street-level shopfront glass only. The kit's wall panels read as pale suburban siding,
				# and a second kit storey clashed with the facade shader's window grid behind it. Loop blocks
				# are shopfronts at street level with masonry windows above, which the shader already draws.
				var storey = basis.scaled_local(Vector3(1.0, STOREY_SCALE, 1.3))
				_add(groups, shop[0], Transform3D(storey, Vector3(at.x, STREET_Y, at.y)))
				stats.kit_instances += 1
				if h >= 9.0 and h <= CORNICE_MAX_H and entry[3]:
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


## Rooftop clutter (CHI-LOOK-02) on low and mid-rise roofs: wooden water tanks, kit AC units and stair/lift
## boxes. `buildings` is [[ring, height m, index, flat_roof]]; LiDAR roofs retain their measured equipment. One MultiMesh per kind and 600 m
## chunk, culled beyond ROOF_CULL_M.
const ROOF_CHUNK = 600.0
const ROOF_CULL_M = 800.0
const TANK_MIN_H = 18.0
const TANK_MAX_H = 90.0


static func roof_clutter(asset: Node3D, holder: Node, buildings: Array) -> Dictionary:
	var meshes = {"tank": _tank_mesh(), "ac": _mesh("Prop_ACUnit"), "box": _box_mesh()}
	var groups = {}
	var count = 0
	for entry in buildings:
		var ring: PackedVector2Array = entry[0]
		var h: float = entry[1]
		var idx: int = entry[2]
		if h < 8.0 or h > 120.0 or ring.size() < 3 or not entry[3]:
			continue
		var tris = Geometry2D.triangulate_polygon(ring)
		if tris.size() < 3:
			continue
		# The roof point: the centroid of the largest triangle, always inside the footprint.
		var best = Vector2.ZERO
		var best_area = 0.0
		for t in range(0, tris.size() - 2, 3):
			var a = ring[tris[t]]
			var b = ring[tris[t + 1]]
			var c = ring[tris[t + 2]]
			var area = absf((b - a).cross(c - a)) * 0.5
			if area > best_area:
				best_area = area
				best = (a + b + c) / 3.0
		if best_area < 30.0:
			continue
		var y = STREET_Y + h
		var yaw = _hash(idx, 41) * TAU
		var spread = minf(6.0, sqrt(best_area) * 0.25)
		if h >= TANK_MIN_H and h <= TANK_MAX_H and _hash(idx, 43) < 0.4:
			_roof_add(groups, "tank", best, y, yaw, 1.0)
			count += 1
		if _hash(idx, 47) < 0.7:
			var o = Vector2.from_angle(yaw + 1.0) * spread
			_roof_add(groups, "ac", best + o, y, yaw, 2.4)
			count += 1
		if _hash(idx, 53) < 0.4:
			var o2 = Vector2.from_angle(yaw + 3.6) * spread
			_roof_add(groups, "box", best + o2, y, yaw, 1.0 + _hash(idx, 59) * 0.6)
			count += 1
	for id in groups:
		var group = groups[id]
		var instances = MultiMesh.new()
		instances.transform_format = MultiMesh.TRANSFORM_3D
		instances.mesh = meshes[group.kind]
		instances.instance_count = group.list.size()
		for n in group.list.size():
			instances.set_instance_transform(n, group.list[n])
		var node = MultiMeshInstance3D.new()
		node.name = "Roof_%s_%d_%d" % [group.kind, group.x, group.z]
		node.multimesh = instances
		node.visibility_range_end = ROOF_CULL_M
		node.visibility_range_end_margin = 80.0
		node.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		holder.add_child(node)
		node.owner = asset
	return {"roof_props": count}


static func _roof_add(
	groups: Dictionary, kind: String, at: Vector2, y: float, yaw: float, scale: float
) -> void:
	var cx = floori(at.x / ROOF_CHUNK)
	var cz = floori(at.y / ROOF_CHUNK)
	var id = "%s|%d|%d" % [kind, cx, cz]
	if not groups.has(id):
		groups[id] = {"kind": kind, "x": cx, "z": cz, "list": []}
	var basis = Basis(Vector3.UP, yaw).scaled(Vector3.ONE * scale)
	groups[id].list.append(Transform3D(basis, Vector3(at.x, y, at.y)))


static func _plain(c: Color) -> StandardMaterial3D:
	var m = StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.95
	return m


## A Chicago wooden water tank: barrel on four legs with a conical roof, about 3 m wide and 5 m tall.
static func _tank_mesh() -> Mesh:
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var barrel = CylinderMesh.new()
	barrel.top_radius = 1.5
	barrel.bottom_radius = 1.5
	barrel.height = 2.6
	barrel.radial_segments = 10
	barrel.rings = 1
	st.append_from(barrel, 0, Transform3D(Basis.IDENTITY, Vector3(0, 2.6, 0)))
	var cone = CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 1.75
	cone.height = 1.0
	cone.radial_segments = 10
	cone.rings = 1
	st.append_from(cone, 0, Transform3D(Basis.IDENTITY, Vector3(0, 4.4, 0)))
	var leg = BoxMesh.new()
	leg.size = Vector3(0.22, 1.4, 0.22)
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			st.append_from(leg, 0, Transform3D(Basis.IDENTITY, Vector3(sx * 1.1, 0.7, sz * 1.1)))
	var mesh = st.commit()
	mesh.surface_set_material(0, _plain(Color(0.36, 0.25, 0.16)))
	return mesh


static func _box_mesh() -> Mesh:
	var box = BoxMesh.new()
	box.size = Vector3(3.2, 2.6, 3.0)
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.append_from(box, 0, Transform3D(Basis.IDENTITY, Vector3(0, 1.3, 0)))
	var mesh = st.commit()
	mesh.surface_set_material(0, _plain(Color(0.45, 0.45, 0.43)))
	return mesh


## Sidewalk props (CHI-LOOK-02) beside the street-level route: kit planters and bollards plus procedural fire
## hydrants, newspaper boxes, benches and bins, at random spacing and clear of the cross streets. One
## MultiMesh per kind and 500 m chunk, culled beyond PROP_CULL_M.
const PROP_LAT_M = 11.0
const PROP_CHUNK = 500.0
const PROP_CULL_M = 260.0
const PROP_KINDS = [
	"planter",
	"bollard",
	"fire_hydrant",
	"fire_hydrant",
	"paper",
	"bench",
	"park_bench",
	"bin",
	"trash_bag",
	"cardboard",
	"crowd_fence",
	"crowd_fence",
	"parking_meter",
	"parking_meter",
	"parking_meter",
	"post_box",
	"atm",
	"trash_can",
	"trash_can_cap",
	"trash_commercial",
	"utility_box",
	"bus_stop",
	"dumpster",
	"post_barrier"
]
const LOWER_KINDS = [
	"drum",
	"drum",
	"cone",
	"jersey",
	"plastic_barrier",
	"trash_bag2",
	"cardboard",
	"bin",
	"pallets",
	"tarp_crates",
	"dumpster",
	"barrel_blue",
	"barrel_rusty",
	"barrel_yellow",
	"barrel_oil",
	"utility_box"
]


static func sidewalk_props(asset: Node3D, parent: Node, stations: Array) -> int:
	var meshes = {
		"planter": _mesh("Prop_Planter_Single"),
		"bollard": _mesh("Prop_Bollard"),
		"paper": _paper_mesh(),
		"bin": PropMesh.mesh(STREET_PACK + "bin.glb"),
		"trash_bag": PropMesh.mesh(STREET_PACK + "trash_bag.glb"),
		"trash_bag2": PropMesh.mesh(STREET_PACK + "trash_bag2.glb"),
		"cardboard": PropMesh.mesh(STREET_PACK + "cardboard.glb"),
		"drum": PropMesh.mesh(STREET_PACK + "drum.glb"),
		"cone": PropMesh.mesh(STREET_PACK + "cone.glb"),
		"jersey": PropMesh.mesh(STREET_PACK + "jersey.glb"),
		"plastic_barrier": PropMesh.mesh(STREET_PACK + "plastic_barrier.glb"),
		"crowd_fence": PropMesh.mesh(STREET_PACK + "crowd_fence.glb"),
	}
	for kind in CITY_KINDS:
		meshes[kind] = PropMesh.mesh(CITY_PROPS + kind + ".glb")
	for kind in ["barrel_blue", "barrel_rusty", "barrel_yellow", "barrel_oil"]:
		meshes[kind] = PropMesh.mesh(BARRELS + kind + ".glb")
	var scales = {"planter": 1.0, "bollard": 1.5, "paper": 1.0}
	var crossings = []
	for i in ChicagoFurniture.find_crossings(stations):
		crossings.append(stations[i].s)
	var rng = RandomNumberGenerator.new()
	rng.seed = 41707
	var groups = {}
	var count = 0
	var i = 0
	while i < stations.size():
		var at = stations[i]
		var step = int(rng.randf_range(5.0, 12.0) / 1.5)
		i += maxi(1, step)
		# Street level gets sidewalk furniture; Lower Wacker (y about 0) gets road-works clutter.
		var lower = at.pos.y <= 3.5288
		if not lower and (at.pos.y < 7.0 or at.pos.y > 9.0):
			continue
		var near_cross = false
		for c in crossings:
			if absf(c - at.s) < 22.0:
				near_cross = true
				break
		if near_cross:
			continue
		var flat = Vector3(at.tangent.x, 0.0, at.tangent.z).normalized()
		var right = flat.cross(Vector3.UP)
		var side = -1.0 if rng.randf() < 0.5 else 1.0
		var pos = at.pos + right * side * (PROP_LAT_M + rng.randf() * 0.5)
		var kinds = LOWER_KINDS if lower else PROP_KINDS
		var kind = kinds[rng.randi() % kinds.size()]
		# Faces the road: local +Z toward the street; imported props get a little yaw jitter.
		var basis = Basis.looking_at(right * side, Vector3.UP)
		if (
			kind
			in ["crowd_fence", "jersey", "plastic_barrier", "bus_stop", "bench", "park_bench", "post_barrier"]
		):
			# Barriers run along the kerb.
			basis = Basis.looking_at(flat, Vector3.UP)
		elif not scales.has(kind):
			basis = basis.rotated(Vector3.UP, rng.randf_range(-0.5, 0.5))
		basis = basis.scaled(Vector3.ONE * scales.get(kind, 1.0))
		# Imported pivots vary: put the actual mesh base on the sidewalk/service bay.
		var bounds = meshes[kind].get_aabb()
		if lower and bounds.size.y * scales.get(kind, 1.0) > 3.7:
			continue
		pos.y -= bounds.position.y * scales.get(kind, 1.0)
		var radius = Vector2(bounds.size.x, bounds.size.z).length() * .5 * scales.get(kind, 1.0)
		var clear = true
		for station in stations:
			if (
				absf(station.pos.y - at.pos.y) < 2.0
				and Vector2(station.pos.x - pos.x, station.pos.z - pos.z).length() < 9.0 + radius
			):
				clear = false
				break
		if not clear:
			continue
		var cx = floori(pos.x / PROP_CHUNK)
		var cz = floori(pos.z / PROP_CHUNK)
		var id = "%s|%d|%d" % [kind, cx, cz]
		if not groups.has(id):
			groups[id] = {"kind": kind, "x": cx, "z": cz, "list": []}
		groups[id].list.append(
			Transform3D(basis, Vector3(pos.x, (at.pos.y if lower else STREET_Y) + 0.04, pos.z))
		)
		count += 1
	# Manholes and storm drains: flat castings in the lanes and at the kerb (no collision, 1.5 cm proud).
	meshes["manhole"] = PropMesh.mesh(CITY_PROPS + "manhole.glb")
	meshes["storm_drain"] = PropMesh.mesh(CITY_PROPS + "storm_drain.glb")
	for j in range(0, stations.size(), 60):
		var at = stations[(j + rng.randi() % 20) % stations.size()]
		var flat = Vector3(at.tangent.x, 0.0, at.tangent.z).normalized()
		var right = flat.cross(Vector3.UP)
		var kind = "manhole" if rng.randf() < 0.6 else "storm_drain"
		var lat = (
			rng.randf_range(-2.5, 2.5)
			if kind == "manhole"
			else (3.2 if at.pos.y < 7.0 else 7.4) * (-1.0 if rng.randf() < .5 else 1.0)
		)
		var bounds = meshes[kind].get_aabb()
		# The casting top sits flush with the road; imported pivots are not a height reference.
		var pos = at.pos + right * lat - Vector3.UP * (bounds.position.y + bounds.size.y - .008)
		var id = "%s|%d|%d" % [kind, floori(pos.x / PROP_CHUNK), floori(pos.z / PROP_CHUNK)]
		if not groups.has(id):
			groups[id] = {
				"kind": kind, "x": floori(pos.x / PROP_CHUNK), "z": floori(pos.z / PROP_CHUNK), "list": []
			}
		groups[id].list.append(Transform3D(Basis.looking_at(flat, Vector3.UP), pos))
		count += 1
	for id in groups:
		var group = groups[id]
		var instances = MultiMesh.new()
		instances.transform_format = MultiMesh.TRANSFORM_3D
		instances.mesh = meshes[group.kind]
		instances.instance_count = group.list.size()
		for n in group.list.size():
			instances.set_instance_transform(n, group.list[n])
		var node = MultiMeshInstance3D.new()
		node.name = "Prop_%s_%d_%d" % [group.kind, group.x, group.z]
		node.multimesh = instances
		node.visibility_range_end = PROP_CULL_M
		node.visibility_range_end_margin = 40.0
		node.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(node)
		node.owner = asset
	return count


static func _compose(parts: Array, color: Color) -> Mesh:
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for part in parts:
		st.append_from(part[0], 0, part[1])
	var mesh = st.commit()
	mesh.surface_set_material(0, _plain(color))
	return mesh


static func _box(size: Vector3) -> BoxMesh:
	var b = BoxMesh.new()
	b.size = size
	return b


static func _cyl(r_top: float, r_bottom: float, h: float) -> CylinderMesh:
	var c = CylinderMesh.new()
	c.top_radius = r_top
	c.bottom_radius = r_bottom
	c.height = h
	c.radial_segments = 8
	c.rings = 1
	return c


static func _paper_mesh() -> Mesh:
	var body = _compose(
		[
			[_box(Vector3(0.12, 0.22, 0.12)), Transform3D(Basis.IDENTITY, Vector3(0, 0.11, 0))],
			[_box(Vector3(0.48, 0.7, 0.42)), Transform3D(Basis.IDENTITY, Vector3(0, 0.57, 0))],
			[_box(Vector3(0.5, 0.08, 0.46)), Transform3D(Basis(Vector3.RIGHT, 0.22), Vector3(0, 0.95, 0.0))]
		],
		Color(0.12, 0.28, 0.6)
	)
	var door = _compose(
		[[_box(Vector3(0.36, 0.3, 0.02)), Transform3D(Basis.IDENTITY, Vector3(0, 0.7, 0.215))]],
		Color(0.72, 0.74, 0.7)
	)
	var mesh = body as ArrayMesh
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, door.surface_get_arrays(0))
	mesh.surface_set_material(1, door.surface_get_material(0))
	return mesh
