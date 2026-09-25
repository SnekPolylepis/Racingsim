extends RefCounted
## The real downtown Chicago around the CHI-01 circuit (CHI-02), from OpenStreetMap
## (trackgen/data/chicago/city.json, written by build_city.py). Presentation only: nothing here collides or
## is driven on. The circuit's barriers keep the car on the route, so every other street is visible
## but not drivable.
##   Buildings  each footprint extruded from the lower level (y 0) to street level (y 8) plus its height,
##              in the photo facade of its class (chicago_facade.gdshader: windows lit at night), flat roofs
##   Streets    every road as an asphalt carriageway on a concrete sidewalk ribbon, cut back where it meets
##              or runs along the circuit so the circuit's own surface shows
##   Ground     street-level concrete everywhere else, left open over water and over the circuit's lower
##              (Lower Wacker) and ramp sections
##   Water      the river and lake at y -2.8 in the circuit's water shader, with concrete river walls
##   Parks      parks, gardens and lawns in grass
## Geometry is batched per 600 m chunk and material, so the whole city is a few hundred draw calls at most.
const Ps2Materials = preload("res://scripts/track/ps2_materials.gd")
const FACADE_SHADER = preload("res://shaders/chicago_facade.gdshader")
const DATA = "res://trackgen/data/chicago/city.json"
const TEX = "res://assets/textures/chicago/"
const STREET_Y = 8.0
const WATER_Y = -2.8
## Lake Michigan and its harbours sit just below the lakefront (the Chicago Harbor Lock separates them from
## the river). At the river's WATER_Y, 10.8 m under the street, the lake was hidden in a pit and Lake
## Shore Drive looked out over a bare concrete plain.
const LAKE_Y = 6.5
## Open ground this close to the lake is lakefront lawn (the Lakefront Trail strip OSM leaves unmapped).
const LAKEFRONT_M = 150.0
const CHUNK = 600.0
## The route's half width plus verge: streets and buildings keep this far (plus their own margin) from it.
const ROUTE_CLEAR = 9.5
## Facade set, tint and glassiness per building class (build_city.py kind_of()).
## [texture set, tint, glassiness, metres per texture repeat]: real brick repeats every couple of metres,
## a curtain-wall panel set every several.
const KINDS = {
	"glass": ["Facade001", Color(0.95, 0.98, 1.0), 1.0, 7.5],
	"glass2": ["Facade009", Color(1.0, 1.0, 1.0), 1.0, 7.5],
	"stone": ["Travertine009", Color(1.0, 0.97, 0.92), 0.0, 2.5],
	"terracotta": ["GlazedTerracotta001", Color(1.0, 0.96, 0.9), 0.0, 2.5],
	"brick": ["Bricks097", Color(0.95, 0.9, 0.88), 0.0, 1.8],
	"concrete": ["Concrete034", Color(0.92, 0.92, 0.9), 0.0, 3.5],
}
## CHI-01 models these landmarks itself: OSM outlines within this distance (m) of them are left out.
const OWN_LANDMARKS = {
	"Willis Tower": 55.0, "Wrigley Building": 35.0, "Tribune Tower": 35.0, "Chicago Board of Trade": 35.0
}

## The Wrigley Building stands this far east of its route.json point (CHI-LOOK-01), clear of the road.
const WRIGLEY_SHIFT = 58.0

## Buildings under this height, and flat surfaces, are culled beyond these distances (m); fog ends at 1900-2800.
const LOW_BUILDING_M = 40.0
const LOW_RANGE_M = 900.0
const FLAT_RANGE_M = 1800.0

static var _mats = {}


static func build(asset: Node3D, parent: Node, road, landmarks: Dictionary, world_of: Callable) -> Dictionary:
	var doc = JSON.parse_string(FileAccess.get_file_as_string(DATA))
	if not doc is Dictionary:
		push_warning("Chicago city data missing: " + DATA)
		return {}
	var route = _route_index(road)
	var skip_at = []
	for name in OWN_LANDMARKS:
		if landmarks.has(name):
			var p = world_of.call(landmarks[name])
			if name == "Wrigley Building":
				p.x += WRIGLEY_SHIFT
			skip_at.append([Vector2(p.x, p.z), OWN_LANDMARKS[name]])
	var chunks = {}
	# LOD (CHI-LOOK-01): low buildings and flat ground/street surfaces go to their own chunk sets with a
	# visibility range; towers stay in `chunks` so the skyline reaches the fog.
	var low_chunks = {}
	var flat_chunks = {}
	var stats = {"buildings": 0, "roads": 0, "ground_tiles": 0, "water": 0, "parks": 0}
	var holder = Node3D.new()
	holder.name = "City"
	parent.add_child(holder)
	holder.owner = asset
	# Buildings.
	var i = 0
	for b in doc.buildings:
		var ring = _ring(b.f)
		i += 1
		if ring.size() < 3 or _touches_route(route, ring, 6.0) or _near_any(skip_at, _centroid(ring)):
			continue
		var kind = str(b.k) if KINDS.has(str(b.k)) else "concrete"
		var target = low_chunks if float(b.h) < LOW_BUILDING_M else chunks
		_building(
			_st(target, _centroid(ring), kind),
			_st(target, _centroid(ring), "roof"),
			ring,
			float(b.h),
			fmod(i * 0.6180339, 1.0)
		)
		stats.buildings += 1
	# Streets: sidewalk ribbon under the carriageway.
	for r in doc.roads:
		var pts = _ring(r.p)
		var w = float(r.w)
		var kept = _road(flat_chunks, route, pts, w)
		if kept:
			stats.roads += 1
	# Water, river walls and parks.
	var water_polys = []
	for poly in doc.water:
		var ring = _ring(poly)
		if ring.size() >= 3:
			water_polys.append(ring)
			var wy = _water_level(ring)
			_flat(_st(chunks, _centroid(ring), "water"), ring, wy)
			_walls(_st(chunks, _centroid(ring), "wall"), ring, wy - 0.4, STREET_Y - 0.04)
			stats.water += 1
	# A park the circuit crosses (Grant Park) can't be one raised polygon over the road; its ground tiles
	# below turn to lawn instead, so it no longer falls back to bare concrete.
	var crossed_parks = []
	for poly in doc.parks:
		var ring = _ring(poly)
		if ring.size() < 3:
			continue
		if _touches_route(route, ring, 2.0):
			crossed_parks.append(ring)
		else:
			_flat(_st(chunks, _centroid(ring), "park"), ring, STREET_Y + 0.02)
			stats.parks += 1
	# Street-level ground, in 20 m tiles, open over water and around the circuit's lower level and ramps.
	var lo = Vector2(INF, INF)
	var hi = Vector2(-INF, -INF)
	for b in doc.buildings:
		for p in b.f:
			lo = lo.min(Vector2(p[0], p[1]))
			hi = hi.max(Vector2(p[0], p[1]))
	var tile = 20.0
	var shore = _lakefront_cells(water_polys, tile, LAKEFRONT_M)
	var x = floorf(lo.x / tile) * tile
	while x < hi.x:
		var z = floorf(lo.y / tile) * tile
		while z < hi.y:
			var c = Vector2(x + tile * 0.5, z + tile * 0.5)
			if not _in_water(water_polys, c) and not _near_low_route(route, c, 26.0):
				var cell = Vector2i(floori(c.x / tile), floori(c.y / tile))
				var lawn = shore.has(cell) or _in_water(crossed_parks, c)
				var kind = "park" if lawn else "ground"
				_quad_flat(_st(flat_chunks, c, kind), Vector2(x, z), tile, STREET_Y - 0.04)
				stats.ground_tiles += 1
			z += tile
		x += tile
	# Commit every chunk's surfaces.
	for group in [
		[chunks, 0.0, "Chunk"], [low_chunks, LOW_RANGE_M, "Low"], [flat_chunks, FLAT_RANGE_M, "Flat"]
	]:
		for key in group[0]:
			var mesh = ArrayMesh.new()
			for mat_name in group[0][key]:
				var st: SurfaceTool = group[0][key][mat_name]
				st.set_material(material(mat_name))
				st.commit(mesh)
			var node = MeshInstance3D.new()
			node.name = "%s_%d_%d" % [group[2], key.x, key.y]
			node.mesh = mesh
			node.visibility_range_end = group[1]
			node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			holder.add_child(node)
			node.owner = asset
	return stats


static func material(name: String) -> Material:
	if _mats.has(name):
		return _mats[name]
	var mat: Material
	if KINDS.has(name):
		var k = KINDS[name]
		var sm = ShaderMaterial.new()
		sm.shader = FACADE_SHADER
		sm.set_shader_parameter("albedo_tex", load(TEX + k[0] + "/" + k[0] + "_color.jpg"))
		sm.set_shader_parameter("normal_tex", load(TEX + k[0] + "/" + k[0] + "_normal.jpg"))
		sm.set_shader_parameter("rough_tex", load(TEX + k[0] + "/" + k[0] + "_roughness.jpg"))
		sm.set_shader_parameter("tint", k[1])
		sm.set_shader_parameter("glassy", k[2])
		sm.set_shader_parameter("tile_m", Vector2(k[3], k[3]))
		mat = sm
	elif name == "roof":
		mat = _plain(Color(0.24, 0.25, 0.26), 0.9)
	elif name == "road":
		mat = _triplanar(
			"res://assets/textures_hd/asphalt_pit_lane/asphalt_pit_lane_diff.jpg",
			4.0,
			Color(0.62, 0.62, 0.64)
		)
	elif name == "sidewalk" or name == "ground" or name == "wall":
		mat = _triplanar(
			TEX + "Concrete034/Concrete034_color.jpg",
			3.0,
			Color(0.85, 0.85, 0.83) if name != "wall" else Color(0.7, 0.7, 0.68)
		)
	elif name == "park":
		mat = Ps2Materials.ground(2)
	elif name == "water":
		var w = ShaderMaterial.new()
		w.shader = preload("res://shaders/chicago_water.gdshader")
		mat = w
	else:
		mat = _plain(Color.MAGENTA, 1.0)
	_mats[name] = mat
	return mat


static func _plain(c: Color, rough: float) -> StandardMaterial3D:
	var m = StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	return m


static func _triplanar(path: String, metres: float, tint: Color) -> StandardMaterial3D:
	var m = StandardMaterial3D.new()
	m.albedo_texture = load(path)
	m.albedo_color = tint
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3.ONE / metres
	m.roughness = 0.9
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	return m


static func _st(chunks: Dictionary, at: Vector2, mat_name: String) -> SurfaceTool:
	var key = Vector2i(floori(at.x / CHUNK), floori(at.y / CHUNK))
	if not chunks.has(key):
		chunks[key] = {}
	if not chunks[key].has(mat_name):
		var st = SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		chunks[key][mat_name] = st
	return chunks[key][mat_name]


static func _ring(src) -> PackedVector2Array:
	var out = PackedVector2Array()
	for p in src:
		out.append(Vector2(p[0], p[1]))
	return out


static func _centroid(ring: PackedVector2Array) -> Vector2:
	var c = Vector2.ZERO
	for p in ring:
		c += p
	return c / ring.size()


static func _near_any(list: Array, p: Vector2) -> bool:
	for e in list:
		if p.distance_to(e[0]) < e[1]:
			return true
	return false


## Route centreline points in 25 m cells: [cells {Vector2i: [Vector3]}].
static func _route_index(road) -> Dictionary:
	var cells = {}
	for p in road.last_bake.center:
		var k = Vector2i(floori(p.x / 25.0), floori(p.z / 25.0))
		if not cells.has(k):
			cells[k] = []
		cells[k].append(p)
	return cells


static func _route_dist(route: Dictionary, p: Vector2, reach: float, low_only: bool = false) -> float:
	var best = INF
	var cx = floori(p.x / 25.0)
	var cz = floori(p.y / 25.0)
	var r = ceili(reach / 25.0)
	for dx in range(-r, r + 1):
		for dz in range(-r, r + 1):
			for q in route.get(Vector2i(cx + dx, cz + dz), []):
				if low_only and q.y > STREET_Y - 1.0:
					continue
				best = minf(best, p.distance_to(Vector2(q.x, q.z)))
	return best


static func _touches_route(route: Dictionary, ring: PackedVector2Array, margin: float) -> bool:
	for p in ring:
		if _route_dist(route, p, ROUTE_CLEAR + margin) < ROUTE_CLEAR + margin:
			return true
	# A footprint can straddle the route between its corners: test the centroid too.
	var c = _centroid(ring)
	return Geometry2D.is_point_in_polygon(c, ring) and _route_dist(route, c, 60.0) < 30.0


static func _near_low_route(route: Dictionary, p: Vector2, reach: float) -> bool:
	return _route_dist(route, p, reach, true) < reach


## Tile cells within `reach` of a lake-level shoreline, marked by walking each lake ring edge.
static func _lakefront_cells(polys: Array, tile: float, reach: float) -> Dictionary:
	var cells = {}
	var r = ceili(reach / tile)
	for ring in polys:
		if _water_level(ring) != LAKE_Y:
			continue
		for i in ring.size():
			var a: Vector2 = ring[i]
			var b: Vector2 = ring[(i + 1) % ring.size()]
			var steps = maxi(1, ceili(a.distance_to(b) / tile))
			for k in steps + 1:
				var p = a.lerp(b, float(k) / steps)
				var c = Vector2i(floori(p.x / tile), floori(p.y / tile))
				for dx in range(-r, r + 1):
					for dz in range(-r, r + 1):
						if dx * dx + dz * dz <= r * r:
							cells[c + Vector2i(dx, dz)] = true
	return cells


## Lake level for the lake and harbours (east of the lock, or south of the river), else the river's level.
static func _water_level(ring: PackedVector2Array) -> float:
	var c = _centroid(ring)
	return LAKE_Y if c.x > 850.0 or c.y > 0.0 else WATER_Y


## True when `p` is inside any of `polys` (water rings, or the crossed parks).
static func _in_water(polys: Array, p: Vector2) -> bool:
	for poly in polys:
		if Geometry2D.is_point_in_polygon(p, poly):
			return true
	return false


static func _building(
	walls: SurfaceTool, roof: SurfaceTool, ring: PackedVector2Array, h: float, seed: float
) -> void:
	var top = STREET_Y + h
	var c = _centroid(ring)
	var u = 0.0
	walls.set_color(Color(seed, 0, 0))
	for i in ring.size():
		var a = ring[i]
		var b = ring[(i + 1) % ring.size()]
		var seg_len = a.distance_to(b)
		if seg_len < 0.05:
			continue
		var n = Vector3(b.y - a.y, 0.0, a.x - b.x).normalized()
		var mid = (a + b) * 0.5
		if Vector2(n.x, n.z).dot(mid - c) < 0.0:
			n = -n
		var v = [
			[Vector3(a.x, 0.0, a.y), Vector2(u, -STREET_Y)],
			[Vector3(b.x, 0.0, b.y), Vector2(u + seg_len, -STREET_Y)],
			[Vector3(b.x, top, b.y), Vector2(u + seg_len, h)],
			[Vector3(a.x, top, a.y), Vector2(u, h)],
		]
		for idx in [0, 1, 2, 0, 2, 3]:
			walls.set_normal(n)
			walls.set_uv(v[idx][1])
			walls.add_vertex(v[idx][0])
		u += seg_len
	_flat(roof, ring, top)


static func _flat(st: SurfaceTool, ring: PackedVector2Array, y: float) -> void:
	var tris = Geometry2D.triangulate_polygon(ring)
	for idx in tris:
		st.set_normal(Vector3.UP)
		st.set_uv(ring[idx])
		st.add_vertex(Vector3(ring[idx].x, y, ring[idx].y))


static func _quad_flat(st: SurfaceTool, at: Vector2, size: float, y: float) -> void:
	var p = [at, at + Vector2(size, 0), at + Vector2(size, size), at + Vector2(0, size)]
	for idx in [0, 1, 2, 0, 2, 3]:
		st.set_normal(Vector3.UP)
		st.add_vertex(Vector3(p[idx].x, y, p[idx].y))


static func _walls(st: SurfaceTool, ring: PackedVector2Array, y0: float, y1: float) -> void:
	for i in ring.size():
		var a = ring[i]
		var b = ring[(i + 1) % ring.size()]
		# Skip edges from clipping the lake to the map area (straight lines far out in the water).
		if (absf(a.x - b.x) < 0.5 or absf(a.y - b.y) < 0.5) and a.distance_to(b) > 300.0:
			continue
		var n = Vector3(b.y - a.y, 0.0, a.x - b.x).normalized()
		var v = [Vector3(a.x, y0, a.y), Vector3(b.x, y0, b.y), Vector3(b.x, y1, b.y), Vector3(a.x, y1, a.y)]
		for idx in [0, 1, 2, 0, 2, 3]:
			st.set_normal(n)
			st.add_vertex(v[idx])


## One street: kept segment by segment where it is clear of the circuit. Returns whether any part was kept.
static func _road(chunks: Dictionary, route: Dictionary, pts: PackedVector2Array, w: float) -> bool:
	var kept = false
	for i in pts.size() - 1:
		var a = pts[i]
		var b = pts[i + 1]
		var mid = (a + b) * 0.5
		var clear = ROUTE_CLEAR + 1.0
		if (
			_route_dist(route, mid, clear + w) < clear + w * 0.5
			or _route_dist(route, a, clear) < clear
			or _route_dist(route, b, clear) < clear
		):
			continue
		var d = b - a
		if d.length() < 0.05:
			continue
		var side = Vector2(-d.y, d.x).normalized()
		_ribbon(_st(chunks, mid, "sidewalk"), a, b, side, w * 0.5 + 3.0, STREET_Y + 0.03, 1.2)
		_ribbon(_st(chunks, mid, "road"), a, b, side, w * 0.5, STREET_Y + 0.06, 0.0)
		kept = true
	return kept


## A flat strip from a to b, `half` wide each side, extended `extend` m past both ends to close joints.
static func _ribbon(
	st: SurfaceTool, a: Vector2, b: Vector2, side: Vector2, half: float, y: float, extend: float
) -> void:
	var dir = (b - a).normalized()
	var a2 = a - dir * (extend + half * 0.15)
	var b2 = b + dir * (extend + half * 0.15)
	var p = [a2 - side * half, a2 + side * half, b2 + side * half, b2 - side * half]
	for idx in [0, 1, 2, 0, 2, 3]:
		st.set_normal(Vector3.UP)
		st.add_vertex(Vector3(p[idx].x, y, p[idx].y))
