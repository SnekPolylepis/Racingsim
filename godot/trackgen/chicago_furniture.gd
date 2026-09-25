extends RefCounted
## Street furniture for the Chicago circuit (CHI-LOOK-01): a mast-arm traffic signal, a zebra crossing and a
## stop line at every street that crosses the street-level route. Crossings come from the OSM streets in
## city.json (cross streets only, not the ones running alongside the route). Batched into one mesh per
## 500 m chunk with a visibility range, so the whole set is a handful of draw calls near the car and none
## far from it. Presentation only: no collision, nothing on the drivable surface but paint above it.

const DATA = "res://trackgen/data/chicago/city.json"
const CROSS_CLASSES = ["secondary", "tertiary", "residential", "living_street"]
const STREET_Y = 8.0
const CELL = 10.0
const CHUNK = 500.0
const VISIBLE_M = 900.0
## A street counts as a crossing when it comes within this distance of the route and is more than about 30
## degrees off its direction; crossings closer than DEDUPE_M along the route are one.
const HIT_M = 5.0
const DEDUPE_M = 40.0
const MAX_ALIGN = 0.85
const POLE_OFFSET = 10.4
const ARM_HEIGHT = 6.6
## Every L_EVERY-th crossing carries an elevated "L" line over the street (visual only, no collision).
const L_EVERY = 6
const L_PHASE = 2
const L_HEIGHT = 7.2
const SURFACES = ["paint", "metal", "housing", "red", "amber", "green"]


## Crossing stations as indices into `stations`. `dirs`, if given, receives each crossing's street direction
## (horizontal unit vector), keyed by station index.
static func find_crossings(stations: Array, dirs: Dictionary = {}) -> Array:
	var grid = {}
	for i in stations.size():
		var p: Vector3 = stations[i].pos
		if p.y < STREET_Y - 2.0:
			continue
		var key = Vector2i(floori(p.x / CELL), floori(p.z / CELL))
		if not grid.has(key):
			grid[key] = []
		grid[key].append(i)
	var doc = JSON.parse_string(FileAccess.get_file_as_string(DATA))
	if not doc is Dictionary:
		return []
	var found = []
	for r in doc.roads:
		if not CROSS_CLASSES.has(str(r.c)) or int(r.get("b", 0)) == 1:
			continue
		var pts = r.p
		for k in pts.size() - 1:
			var a = Vector2(pts[k][0], pts[k][1])
			var b = Vector2(pts[k + 1][0], pts[k + 1][1])
			var span = a.distance_to(b)
			if span < 0.5:
				continue
			var dir = (b - a) / span
			var steps = maxi(1, ceili(span / 3.0))
			for j in steps + 1:
				var at = a.lerp(b, float(j) / steps)
				var hit = _nearest(stations, grid, at)
				if hit < 0:
					continue
				var t: Vector3 = stations[hit].tangent
				if absf(dir.dot(Vector2(t.x, t.z).normalized())) > MAX_ALIGN:
					continue
				var s: float = stations[hit].s
				var fresh = true
				for other in found:
					if absf(stations[other].s - s) < DEDUPE_M:
						fresh = false
						break
				if fresh:
					found.append(hit)
					dirs[hit] = Vector3(dir.x, 0.0, dir.y)
	found.sort()
	return found


static func _nearest(stations: Array, grid: Dictionary, at: Vector2) -> int:
	var best = HIT_M
	var index = -1
	var cx = floori(at.x / CELL)
	var cz = floori(at.y / CELL)
	for dx in range(-1, 2):
		for dz in range(-1, 2):
			for i in grid.get(Vector2i(cx + dx, cz + dz), []):
				var p: Vector3 = stations[i].pos
				var d = at.distance_to(Vector2(p.x, p.z))
				if d < best:
					best = d
					index = i
	return index


## Adds the crossings' signals and paint under `parent`. `helpers` are Chicago's own box, material and
## attach functions, passed in so this file does not preload chicago.gd back.
static func build(
	asset: Node3D, parent: Node, stations: Array, box: Callable, night_material: Callable, attach: Callable
) -> int:
	var dirs = {}
	var crossings = find_crossings(stations, dirs)
	var mats = [
		_plain(Color("d9d6c8")),
		_plain(Color("4a4d50")),
		_plain(Color("111214")),
		night_material.call(Color("ff2a1a"), 2.4),
		night_material.call(Color("ffb020"), 2.4),
		night_material.call(Color("36ff6c"), 2.4)
	]
	var chunks = {}
	for i in crossings:
		var at = stations[i]
		var key = Vector2i(floori(at.pos.x / CHUNK), floori(at.pos.z / CHUNK))
		if not chunks.has(key):
			var tools = []
			for n in SURFACES.size():
				var tool = SurfaceTool.new()
				tool.begin(Mesh.PRIMITIVE_TRIANGLES)
				tools.append(tool)
			chunks[key] = tools
		_crossing(chunks[key], at, i, box)
		if crossings.find(i) % L_EVERY == L_PHASE:
			_elevated(chunks[key], at, dirs[i], box)
	for key in chunks:
		var mesh = ArrayMesh.new()
		for n in SURFACES.size():
			var tool: SurfaceTool = chunks[key][n]
			tool.generate_normals()
			var arrays = tool.commit_to_arrays()
			if arrays[Mesh.ARRAY_VERTEX] == null or arrays[Mesh.ARRAY_VERTEX].is_empty():
				continue
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			mesh.surface_set_material(mesh.get_surface_count() - 1, mats[n])
		var node = MeshInstance3D.new()
		node.mesh = mesh
		node.visibility_range_end = VISIBLE_M
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		attach.call(asset, parent, node, "StreetFurniture_%d_%d" % [key.x, key.y])
	return crossings.size()


static func _plain(c: Color) -> StandardMaterial3D:
	var m = StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.85
	return m


static func _crossing(tools: Array, at: Dictionary, index: int, box: Callable) -> void:
	var flat = Vector3(at.tangent.x, 0.0, at.tangent.z).normalized()
	var basis = Basis.looking_at(flat, Vector3.UP)
	var right = basis.x
	var base: Vector3 = at.pos
	# Zebra bars and a stop line on the approach side, above the surface (paint only).
	var lead = -9.0
	for k in range(-6, 7):
		box.call(
			tools[0],
			base + flat * lead + right * (k * 1.15) + Vector3(0, 0.022, 0),
			Vector3(0.55, 0.01, 2.8),
			Color.WHITE,
			basis
		)
	box.call(
		tools[0],
		base + flat * (lead - 3.2) + Vector3(0, 0.022, 0),
		Vector3(15.0, 0.01, 0.5),
		Color.WHITE,
		basis
	)
	# Mast arm on the far right corner, reaching over the lanes.
	var foot = base + flat * 9.0 + right * POLE_OFFSET
	box.call(
		tools[1], foot + Vector3(0, ARM_HEIGHT * 0.5, 0), Vector3(0.32, ARM_HEIGHT, 0.32), Color.WHITE, basis
	)
	var top = foot + Vector3(0, ARM_HEIGHT - 0.3, 0)
	box.call(tools[1], top - right * 4.9, Vector3(9.8, 0.24, 0.24), Color.WHITE, basis)
	# Two heads over the two right-hand lanes, facing the driver (local +Z faces back along the route).
	var roll = (index * 7 + 3) % 10
	var state = 5 if roll < 5 else (3 if roll < 8 else 4)
	var lens_y = {3: 0.4, 4: 0.0, 5: -0.4}[state]
	for lane in [4.4, 8.4]:
		var head = top - right * lane + Vector3(0, -0.75, 0)
		box.call(tools[2], head, Vector3(0.45, 1.25, 0.4), Color.WHITE, basis)
		box.call(
			tools[state],
			head + basis.z * 0.22 + Vector3(0, lens_y, 0),
			Vector3(0.28, 0.28, 0.06),
			Color.WHITE,
			basis
		)


## An elevated railway over the route: a steel deck along the cross street `along` with side girders and
## paired lattice-style piers outside the road, and a two-car train on it (window strip glows at night).
static func _elevated(tools: Array, at: Dictionary, along: Vector3, box: Callable) -> void:
	var flat = Vector3(at.tangent.x, 0.0, at.tangent.z).normalized()
	var basis = Basis.looking_at(along, Vector3.UP)
	var centre: Vector3 = at.pos + flat * 24.0
	var deck_y = L_HEIGHT + 0.5
	# Deck slab, two side girders, two rails.
	box.call(tools[1], centre + Vector3(0, deck_y, 0), Vector3(7.0, 0.7, 70.0), Color.WHITE, basis)
	for side in [-1, 1]:
		box.call(
			tools[1],
			centre + basis.x * side * 3.4 + Vector3(0, deck_y + 0.7, 0),
			Vector3(0.3, 1.5, 70.0),
			Color.WHITE,
			basis
		)
		box.call(
			tools[2],
			centre + basis.x * side * 0.9 + Vector3(0, deck_y + 0.5, 0),
			Vector3(0.12, 0.14, 70.0),
			Color.WHITE,
			basis
		)
	# Piers on both sides of the 20 m wide carriageway, and an X brace between each pair.
	for pos in [-19.0, 19.0]:
		for side in [-1, 1]:
			box.call(
				tools[1],
				centre + basis.z * pos + basis.x * side * 3.0 + Vector3(0, deck_y * 0.5, 0),
				Vector3(0.6, deck_y, 0.6),
				Color.WHITE,
				basis
			)
		box.call(
			tools[1],
			centre + basis.z * pos + Vector3(0, deck_y - 0.6, 0),
			Vector3(7.0, 0.6, 0.6),
			Color.WHITE,
			basis
		)
	# Train: body plus a lit window band, along the deck.
	for car in [-1, 1]:
		var pos = centre + basis.z * car * 9.5 + Vector3(0, deck_y + 2.4, 0)
		box.call(tools[1], pos, Vector3(3.1, 3.0, 17.0), Color.WHITE, basis)
		for side in [-1, 1]:
			box.call(
				tools[4],
				pos + basis.x * side * 1.56 + Vector3(0, 0.5, 0),
				Vector3(0.06, 0.8, 15.0),
				Color.WHITE,
				basis
			)
