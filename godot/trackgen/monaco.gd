extends SceneTree
## Circuit de Monaco (3.32 km), built from real data in trackgen/data/monaco/ (README there):
##   Lap        the OpenStreetMap streets and raceway ways of the Grand Prix lap, chained in race order
##              (build_route.py): Boulevard Albert 1er, Sainte-Devote, Avenue d'Ostende (Beau Rivage),
##              Massenet, Casino, Mirabeau, the Fairmont hairpin, Portier, the tunnel under the Fairmont,
##              Nouvelle Chicane, Tabac, the Swimming Pool, La Rascasse, Anthony Noghes
##   Height     Copernicus GLO-30 DSM low envelope, tunnel bridged, smoothed, grade <= 12 % (build_profile.py)
##   City       OSM building footprints on the DEM ground, heights from OSM or measured from the DSM;
##              mapped trees, parks and piers; the sea and Port Hercule (build_city.py -> city.json)
## Widths and kerbs per corner are authored from the circuit's published layout (no survey was acquired).
## Rebuild data: python3 build_route.py && python3 build_profile.py && python3 build_city.py (in the data folder).
const TrackAsset = preload("res://scripts/track/track_asset.gd")
const RoadPath = preload("res://scripts/track/road_path.gd")
const RoadSection = preload("res://scripts/track/road_section.gd")
const RoadScatter = preload("res://scripts/track/road_scatter.gd")
const WallPath = preload("res://scripts/track/wall_path.gd")
const TrackLights = preload("res://scripts/track/track_lights.gd")
const Gantry = preload("res://scripts/track/gantry.gd")
const CatchFence = preload("res://scripts/track/catch_fence.gd")
const Grandstand = preload("res://scripts/track/grandstand.gd")
## Corners with escape roads / run-off that carry red and white impact blocks (Commons "Portier" photo).
const BLOCK_CORNERS = [
	"Sainte-Devote",
	"Mirabeau Haute",
	"Grand Hotel Hairpin",
	"Portier",
	"Nouvelle Chicane",
	"La Rascasse"
]
const ChicagoCity = preload("res://trackgen/chicago_city.gd")
const WATER_SHADER = preload("res://shaders/chicago_water.gdshader")
const DATA = "res://trackgen/data/monaco/city.json"
const ORIGIN = Vector2(43.735, 7.4225)
const SEA_Y = 0.3
const CHUNK = 300.0
## Corner name -> [lat, lon, road half-width from here (m), kerbs]. Widths follow the published layout:
## the pit straight on Boulevard Albert 1er is the widest, the Fairmont hairpin and Rascasse the narrowest.
const CORNERS = [
	["Sainte-Devote", 43.73690, 7.42170, 5.2, true],
	["Beau Rivage", 43.73740, 7.42420, 5.0, false],
	["Massenet", 43.73900, 7.42770, 5.2, true],
	["Casino Square", 43.73965, 7.42728, 6.0, true],
	["Mirabeau Haute", 43.74105, 7.42875, 4.8, true],
	["Grand Hotel Hairpin", 43.74035, 7.42973, 4.6, true],
	["Mirabeau Bas", 43.74095, 7.42953, 4.8, true],
	["Portier", 43.74102, 7.43012, 4.8, true],
	["Tunnel", 43.73950, 7.42950, 5.2, false],
	["Nouvelle Chicane", 43.73712, 7.42530, 5.0, true],
	["Tabac", 43.73686, 7.42303, 5.0, true],
	["Piscine", 43.73530, 7.42200, 5.0, true],
	["La Rascasse", 43.73245, 7.42275, 4.6, true],
	["Anthony Noghes", 43.73280, 7.42225, 5.2, true],
]
const START_HALF_WIDTH = 6.0
## Grandstands as at the Grand Prix (F1 TV onboard and Commons "Virage de la Piscine" photos): the main
## stand opposite the pits, Casino (B), the harbour stands along Tabac and the pool, the pool-side T stand
## and Rascasse. [name, corner or "" for the start line, metres from it, length, side, rows]
const STANDS = [
	["MainStand", "", 30.0, 170.0, 0, 12],
	["CasinoStand", "Casino Square", -30.0, 50.0, 0, 8],
	["TabacStand", "Tabac", -90.0, 110.0, 0, 10],
	["HarbourStand", "Piscine", -70.0, 170.0, 0, 12],
	["PoolStand", "Piscine", -20.0, 90.0, 1, 10],
	["RascasseStand", "La Rascasse", -70.0, 60.0, 0, 8]
]
## Riviera render colours for the facade palette: cream, ochre, salmon, white, pale yellow, terracotta.
const TINTS = [
	Color(0.94, 0.9, 0.8),
	Color(0.88, 0.74, 0.52),
	Color(0.9, 0.7, 0.6),
	Color(0.96, 0.95, 0.92),
	Color(0.95, 0.88, 0.62),
	Color(0.8, 0.55, 0.42)
]


static func data() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(DATA))


static func world_of(lat: float, lon: float) -> Vector3:
	return Vector3(
		(lon - ORIGIN.y) * 111320.0 * cos(deg_to_rad(ORIGIN.x)), 0.0, (ORIGIN.x - lat) * 111320.0
	)


## Closed Catmull-Rom through the 3 m road points (y is the authored DSM approximation).
static func route_curve(road_pts: Array) -> Curve3D:
	var p: Array[Vector3] = []
	for r in road_pts:
		p.append(Vector3(r[0], r[1], r[2]))
	var c = Curve3D.new()
	c.bake_interval = 0.25
	var n = p.size()
	for i in n:
		var h = (p[(i + 1) % n] - p[posmod(i - 1, n)]) / 6.0
		c.add_point(p[i], -h, h)
	c.add_point(p[0], -(p[1] - p[n - 1]) / 6.0, Vector3.ZERO)
	return c


static func attach(asset: Node3D, parent: Node, node: Node, title: String) -> void:
	node.name = title
	parent.add_child(node)
	node.owner = asset


static func build_asset() -> Node3D:
	var d = data()
	var asset = TrackAsset.new()
	asset.name = "Monaco"
	asset.id = "monaco"
	asset.display_name = "Circuit de Monaco"
	asset.version = 2
	asset.default_time_of_day = "day"
	var road = RoadPath.new()
	road.curve = route_curve(d.road)
	road.closed = true
	road.along_step = 1.5
	road.road_stations = 9
	road.grid_first_m = 20.0
	road.grid_spacing_m = 8.0
	road.grid_offset_m = 2.2
	var corners = {}
	for c in CORNERS:
		corners[c[0]] = road.curve.get_closest_offset(world_of(c[1], c[2]) + Vector3(0, 5, 0))
	var pool_gap = Vector2(corners["Piscine"] - 180.0, corners["Piscine"] + 230.0)
	road.sections.append(RoadSection.make(0.0, _section(START_HALF_WIDTH, false)))
	for c in CORNERS:
		var section = _section(c[3], c[4])
		if c[0] == "Piscine":
			section.runoff_left = 4.0
			section.runoff_right = 4.0
		road.sections.append(RoadSection.make(maxf(corners[c[0]] - 25.0, 1.0), section))
	for at in [pool_gap.x, pool_gap.x + 25.0, pool_gap.y - 25.0, pool_gap.y]:
		var section = _section(5.0, true)
		if at > pool_gap.x and at < pool_gap.y:
			section.runoff_left = 4.0
			section.runoff_right = 4.0
		road.sections.append(RoadSection.make(at, section))
	road.sections.sort_custom(func(a, b): return a.at < b.at)
	attach(asset, asset, road, "Main")
	road.bake()
	asset.set_meta("corners", corners)
	var length = road.last_bake.length
	var timing = asset.get_node("TimingLine")
	timing.set_meta("sector_offsets", [corners["Mirabeau Haute"], corners["Tabac"]])
	var bot = Path3D.new()
	bot.curve = road.working_curve()
	attach(asset, asset, bot, "BotLine")
	var tunnel = Vector2(
		road.curve.get_closest_offset(_pt(d.road[d.tunnel[0]])),
		road.curve.get_closest_offset(_pt(d.road[d.tunnel[1]]))
	)
	asset.set_meta("tunnel", tunnel)
	# Owner: both Swimming Pool chicanes are open. Share the gap across collision and dressing.
	asset.set_meta("pool_gap", pool_gap)
	for side in [WallPath.Side.LEFT, WallPath.Side.RIGHT]:
		for span in [Vector2(0, pool_gap.x), Vector2(pool_gap.y, length)]:
			var wall = WallPath.new()
			wall.follow_road = NodePath("../Main")
			wall.side = side
			wall.kind = 0
			wall.offset = 0.2
			wall.step_m = 2.0
			wall.from_m = span.x
			wall.to_m = span.y
			attach(
				asset,
				asset,
				wall,
				(
					("LeftBarrier" if side == WallPath.Side.LEFT else "RightBarrier")
					+ ("B" if span.x > 0 else "")
				)
			)
			wall.bake()
	var scenery = Node3D.new()
	attach(asset, asset, scenery, "Scenery")
	# Debris fencing on both barriers, as at every street circuit; none inside the tunnel.
	for barrier in ["LeftBarrier", "RightBarrier"]:
		for span in [[0.0, tunnel.x], [tunnel.y, pool_gap.x], [pool_gap.y, length]]:
			var fence = CatchFence.new()
			# Road metres (a wall-following fence measures along the barrier, which is longer on the outside).
			fence.follow_road = NodePath("../Main")
			fence.side = WallPath.Side.LEFT if barrier == "LeftBarrier" else WallPath.Side.RIGHT
			fence.offset = 0.2
			fence.post_spacing = 4.0
			fence.fence_height = 3.0
			fence.solid = false
			fence.from_m = span[0] + (8.0 if span[0] > 0.0 else 0.0)
			fence.to_m = span[1] - 8.0 if span[1] > 0.0 else -1.0
			attach(asset, asset, fence, barrier + "Fence" + str(int(span[0])))
			fence.bake()
	_ad_panels(asset, scenery, road, tunnel)
	_impact_blocks(asset, scenery, road, corners)
	var garden_trees = _ground(asset, scenery, d.ground)
	_sea(asset, scenery, d.ground)
	var casino = _buildings(asset, scenery, d.buildings)
	if not casino.is_empty():
		_casino_towers(
			asset, scenery, casino, road.working_curve().sample_baked(corners["Casino Square"])
		)
	_flats(asset, scenery, d.piers, 1.4, "sidewalk", "Piers")
	_pools(asset, scenery, d.get("pools", []))
	for st in STANDS:
		var gs = Grandstand.new()
		gs.follow_road = NodePath("../Main")
		gs.station = (corners[st[1]] if st[1] != "" else 0.0) + st[2]
		gs.length_m = st[3]
		gs.side = st[4]
		gs.rows = st[5]
		# Monaco's temporary stands are open; the builder's cantilever roof reached out over the track.
		gs.has_roof = false
		gs.offset = 3.0
		gs.solid_front = st[0] not in ["HarbourStand", "PoolStand"]
		attach(asset, asset, gs, st[0])
		gs.bake()
	_yachts(asset, scenery, d.piers)
	_trees(asset, scenery, d.trees + garden_trees)
	_tunnel(asset, scenery, road, tunnel)
	# Street lamps outside only: the tunnel has its own lamp strip and lights (_tunnel).
	var lamps = TrackLights.place(road, 34.0, [], 1.0).filter(
		func(lamp):
			var s = road.curve.get_closest_offset(lamp.base)
			return s < tunnel.x - 10.0 or s > tunnel.y + 10.0
	)
	TrackLights.build(asset, road, lamps)
	var gantry = Gantry.new()
	gantry.follow_road = NodePath("../Main")
	gantry.clearance_height = 6.0
	attach(asset, asset, gantry, "StartGantry")
	gantry.bake()
	asset.set_meta(
		"route_description",
		"Sainte-Devote / Casino / Mirabeau / tunnel / chicane / Piscine / Rascasse"
	)
	print("MONACO length %.0f m, tunnel %.0f-%.0f m" % [length, tunnel.x, tunnel.y])
	return asset


static func _pt(r: Array) -> Vector3:
	return Vector3(r[0], r[1], r[2])


## Street circuit cross-section: tarmac to the kerb line, a pavement strip, barrier right behind it.
static func _section(half: float, kerbs: bool) -> Dictionary:
	return {
		"width_left": half,
		"width_right": half,
		"crown": 0.02,
		"kerb_left": RoadSection.Kerb.RAMP if kerbs else RoadSection.Kerb.NONE,
		"kerb_right": RoadSection.Kerb.RAMP if kerbs else RoadSection.Kerb.NONE,
		"kerb_width": 0.5,
		"kerb_height": 0.03,
		"runoff_left": 0.0,
		"runoff_right": 0.0,
		"verge_left": 0.5,
		"verge_right": 0.5,
		"verge_slope_deg": 0.0,
		"verge_surface": 4
	}


## DEM ground (8 m grid), pulled under the road by build_city.py. Presentation only. Slopes steeper than
## ~40 deg are Monaco's masonry retaining walls (reference: "Circuit de Monaco - Sortie du Tunnel").
static func _ground(asset: Node3D, parent: Node, g: Dictionary) -> Array:
	var rng = RandomNumberGenerator.new()
	rng.seed = 98003
	var trees = []
	var flat = SurfaceTool.new()
	flat.begin(Mesh.PRIMITIVE_TRIANGLES)
	var steep = SurfaceTool.new()
	steep.begin(Mesh.PRIMITIVE_TRIANGLES)
	var garden = SurfaceTool.new()
	garden.begin(Mesh.PRIMITIVE_TRIANGLES)
	var paved: Array = g.get("paved", [])
	var h: Array = g.h
	var cell = float(g.cell)
	for iz in int(g.nz) - 1:
		for ix in int(g.nx) - 1:
			var q = []
			for o in [[0, 0], [1, 0], [1, 1], [0, 1]]:
				q.append(
					Vector3(
						g.x0 + (ix + o[0]) * cell,
						h[iz + o[1]][ix + o[0]],
						g.z0 + (iz + o[1]) * cell
					)
				)
			if maxf(maxf(q[0].y, q[1].y), maxf(q[2].y, q[3].y)) < SEA_Y:
				continue
			for tri in [[0, 1, 2], [0, 2, 3]]:
				var n = (q[tri[2]] - q[tri[0]]).cross(q[tri[1]] - q[tri[0]]).normalized()
				var st = steep if absf(n.y) < 0.77 else flat
				# Away from the road the hillside is gardens between the buildings, not bare earth.
				if st == flat and not paved.is_empty() and paved[iz][ix] == 0:
					st = garden
					# Terraced gardens carry pines, cypresses and palms, not open lawn.
					if tri[1] == 1 and rng.randf() < 0.3:
						var p = (
							(q[0] + q[1] + q[2] + q[3]) * 0.25
							+ Vector3(rng.randf_range(-3, 3), 0, rng.randf_range(-3, 3))
						)
						trees.append([p.x, p.y, p.z])
				for k in tri:
					# Walls take UVs across the slope so the masonry courses run level.
					st.set_uv(
						(
							Vector2(q[k].x + q[k].z, q[k].y) / 3.0
							if st == steep
							else Vector2(q[k].x, q[k].z) / 6.0
						)
					)
					st.add_vertex(q[k])
	for pair in [
		[flat, "ground", "Ground"], [steep, "wall", "RetainingWalls"], [garden, "park", "Gardens"]
	]:
		pair[0].generate_normals()
		var node = MeshInstance3D.new()
		node.mesh = pair[0].commit()
		node.material_override = ChicagoCity.material(pair[1])
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		attach(asset, parent, node, pair[2])
	return trees


static func _sea(asset: Node3D, parent: Node, g: Dictionary) -> void:
	var plane = PlaneMesh.new()
	plane.size = Vector2(6000, 6000)
	var mat = ShaderMaterial.new()
	mat.shader = WATER_SHADER
	plane.material = mat
	var node = MeshInstance3D.new()
	node.mesh = plane
	node.position = Vector3(g.x0 + g.nx * g.cell * 0.5, SEA_Y, g.z0 + g.nz * g.cell * 0.5 + 1500.0)
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	attach(asset, parent, node, "Sea")


## OSM footprints extruded from their ground base; facade shader (lit windows at night) in Riviera tints.
static func _buildings(asset: Node3D, parent: Node, list: Array) -> Dictionary:
	var casino = {}
	var chunks = {}
	var rng = RandomNumberGenerator.new()
	rng.seed = 98000
	for b in list:
		var flat: Array = b[0]
		var ring = PackedVector2Array()
		for i in range(0, flat.size() - 1, 2):
			ring.append(Vector2(flat[i], flat[i + 1]))
		if ring.size() > 1 and ring[0].distance_to(ring[-1]) < 0.05:
			ring.remove_at(ring.size() - 1)
		if ring.size() < 3:
			continue
		var c = Vector2.ZERO
		for p in ring:
			c += p
		c /= ring.size()
		var key = Vector2i(floori(c.x / CHUNK), floori(c.y / CHUNK))
		if not chunks.has(key):
			var st = SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			chunks[key] = st
		var tint = TINTS[rng.randi() % TINTS.size()]
		var layer = ChicagoCity.kind_layer("stone" if rng.randf() < 0.7 else "concrete")
		if b[3] == "casino":
			casino = {"ring": ring, "top": float(b[1]) + float(b[2])}
		if b[3] in ["casino", "hotel_de_paris"]:
			# Casino Square's Belle Epoque stone (Garnier's Casino, the Hotel de Paris).
			tint = Color(0.96, 0.9, 0.76)
			layer = ChicagoCity.kind_layer("stone")
		_extrude(
			chunks[key],
			ring,
			float(b[1]) - 0.5,
			float(b[1]) + float(b[2]),
			rng.randf(),
			layer,
			tint
		)
	for key in chunks:
		var st: SurfaceTool = chunks[key]
		st.generate_normals()
		# On the surface, not as an override: NightGlow.set_night toggles `afterhours` on mesh materials.
		st.set_material(_facade_material())
		var node = MeshInstance3D.new()
		node.mesh = st.commit()
		attach(asset, parent, node, "Buildings_%d_%d" % [key.x, key.y])
	return casino


## The Casino de Monte-Carlo's square-side towers (Garnier, 1878): a square tower at each end of the facade
## that faces Casino Square, rising above the roof under a verdigris copper pyramid.
static func _casino_towers(
	asset: Node3D, parent: Node, casino: Dictionary, square: Vector3
) -> void:
	var ring: PackedVector2Array = casino.ring
	var top: float = casino.top
	var c = Vector2.ZERO
	for p in ring:
		c += p
	c /= ring.size()
	var best = -1
	var best_d = INF
	for i in ring.size():
		var a = ring[i]
		var b = ring[(i + 1) % ring.size()]
		var d = ((a + b) * 0.5).distance_to(Vector2(square.x, square.z))
		if a.distance_to(b) > 12.0 and d < best_d:
			best_d = d
			best = i
	if best < 0:
		return
	var a = ring[best]
	var b = ring[(best + 1) % ring.size()]
	var dir = (b - a).normalized()
	var inward = (c - (a + b) * 0.5).normalized()
	var stone = StandardMaterial3D.new()
	stone.albedo_color = Color(0.93, 0.86, 0.72)
	stone.roughness = 0.8
	var copper = StandardMaterial3D.new()
	copper.albedo_color = Color(0.36, 0.56, 0.47)
	copper.roughness = 0.6
	for k in 2:
		var at = (a + dir * 4.5 if k == 0 else b - dir * 4.5) + inward * 4.0
		var tower = MeshInstance3D.new()
		var box = BoxMesh.new()
		box.size = Vector3(7.0, 14.0, 7.0)
		box.material = stone
		tower.mesh = box
		tower.position = Vector3(at.x, top + 0.0, at.y)
		tower.rotation.y = -dir.angle()
		attach(asset, parent, tower, "CasinoTower%d" % k)
		var cap = MeshInstance3D.new()
		var pyramid = CylinderMesh.new()
		pyramid.top_radius = 0.0
		pyramid.bottom_radius = 5.2
		pyramid.height = 6.0
		pyramid.radial_segments = 4
		pyramid.rings = 1
		pyramid.material = copper
		cap.mesh = pyramid
		cap.position = Vector3(at.x, top + 10.0, at.y)
		cap.rotation.y = -dir.angle() + PI / 4.0
		attach(asset, parent, cap, "CasinoTowerRoof%d" % k)


## Walls and a flat roof; vertex colour and UVs as chicago_city._building sets them for the facade shader.
static func _extrude(
	st: SurfaceTool,
	ring: PackedVector2Array,
	bottom: float,
	top: float,
	seed: float,
	layer: float,
	tint: Color
) -> void:
	var code = (roundi(tint.r * 5) * 36 + roundi(tint.g * 5) * 6 + roundi(tint.b * 5) + 1) / 255.0
	var c = Vector2.ZERO
	for p in ring:
		c += p
	c /= ring.size()
	var u = 0.0
	st.set_color(Color(seed, layer / 8.0, 0, code))
	for i in ring.size():
		var a = ring[i]
		var b = ring[(i + 1) % ring.size()]
		var len = a.distance_to(b)
		if len < 0.05:
			continue
		var v = [
			[Vector3(a.x, bottom, a.y), Vector2(u, 0.0)],
			[Vector3(b.x, bottom, b.y), Vector2(u + len, 0.0)],
			[Vector3(b.x, top, b.y), Vector2(u + len, top - bottom)],
			[Vector3(a.x, top, a.y), Vector2(u, top - bottom)]
		]
		var n = Vector3(b.y - a.y, 0.0, a.x - b.x)
		var order = (
			[0, 1, 2, 0, 2, 3]
			if n.dot(Vector3((a.x + b.x) * 0.5 - c.x, 0, (a.y + b.y) * 0.5 - c.y)) >= 0.0
			else [0, 2, 1, 0, 3, 2]
		)
		for k in order:
			st.set_uv(v[k][1])
			st.add_vertex(v[k][0])
		u += len
	st.set_color(Color(0, 0, 1))
	var tris = Geometry2D.triangulate_polygon(ring)
	for i in range(0, tris.size(), 3):
		for k in [0, 2, 1]:
			var p = ring[tris[i + k]]
			st.set_uv(p)
			st.add_vertex(Vector3(p.x, top, p.y))


## Generic sponsor colours for the barrier panels (no real brands).
const AD_COLORS = [
	Color(0.75, 0.08, 0.1),
	Color(0.05, 0.2, 0.55),
	Color(0.95, 0.75, 0.1),
	Color(0.1, 0.45, 0.2),
	Color(0.92, 0.92, 0.9),
	Color(0.08, 0.08, 0.1),
	Color(0.95, 0.45, 0.05)
]


## Road half-width at `s` (the last section key at or before it).
static func _half_at(road, s: float) -> float:
	var half = START_HALF_WIDTH
	for sec in road.sections:
		if sec.at <= s:
			half = sec.width_right
	return half


## Advertising panels flat on the armco face, both sides, end to end, as on the F1 onboards; none in the
## tunnel. One MultiMesh with per-panel colour.
static func _ad_panels(asset: Node3D, parent: Node, road, tunnel: Vector2) -> void:
	var c: Curve3D = road.working_curve()
	var length = c.get_baked_length()
	var rng = RandomNumberGenerator.new()
	rng.seed = 98010
	var xforms = []
	var colors = []
	var customs = []
	var at = 3.0
	var pool_gap: Vector2 = asset.get_meta("pool_gap")
	while at < length:
		if (
			(at < tunnel.x - 5.0 or at > tunnel.y + 5.0)
			and (at < pool_gap.x - 3.0 or at > pool_gap.y + 3.0)
		):
			var f = _level_frame(c, at)
			# Follow the road's pitch so panels on the Beau Rivage climb run with the barrier, not in steps.
			var along = (
				(c.sample_baked(minf(at + 3.0, length)) - c.sample_baked(maxf(at - 3.0, 0.0)))
				. normalized()
			)
			var up = f[1].cross(along).normalized()
			for side in [-1.0, 1.0]:
				var p = f[0] + f[1] * side * (_half_at(road, at) + 1.08) + up * 0.55
				xforms.append(
					Transform3D(
						Basis(along, up, f[1]) * Basis.from_scale(Vector3(5.9, 0.9, 0.04)), p
					)
				)
				colors.append(AD_COLORS[rng.randi() % AD_COLORS.size()])
				customs.append(Color((rng.randi() % 4 + 0.5) / 4.0, rng.randf(), 0, 0))
		at += 6.0
	var mat = ShaderMaterial.new()
	mat.shader = preload("res://shaders/ad_panel.gdshader")
	var mesh = BoxMesh.new()
	mesh.material = mat
	var mm = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.use_custom_data = true
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
		mm.set_instance_color(i, colors[i])
		mm.set_instance_custom_data(i, customs[i])
	var node = MultiMeshInstance3D.new()
	node.multimesh = mm
	attach(asset, parent, node, "AdPanels")


## Red and white impact blocks along the outside barrier of the corners with escape roads, 25 m either side
## of the apex. Visual only: the armco behind keeps collision.
static func _impact_blocks(asset: Node3D, parent: Node, road, corners: Dictionary) -> void:
	var c: Curve3D = road.working_curve()
	var length = c.get_baked_length()
	var red = []
	var white = []
	for name in BLOCK_CORNERS:
		var apex = corners[name]
		var f0 = _level_frame(c, fposmod(apex - 10.0, length))
		var f1 = _level_frame(c, fposmod(apex + 10.0, length))
		# Turning right when the right vector swings toward the tangent's old side: outside is the left.
		var outside = -1.0 if f0[1].cross(f1[1]).y < 0.0 else 1.0
		var at = apex - 25.0
		var k = 0
		while at < apex + 25.0:
			var f = _level_frame(c, fposmod(at, length))
			var p = (
				f[0]
				+ f[1] * outside * (_half_at(road, fposmod(at, length)) + 0.85)
				+ Vector3(0, 0.45, 0)
			)
			var xf = Transform3D(
				(
					Basis(f[1].cross(Vector3.UP), Vector3.UP, f[1])
					* Basis.from_scale(Vector3(1.4, 0.9, 0.7))
				),
				p
			)
			(red if k % 2 == 0 else white).append(xf)
			at += 1.5
			k += 1
	for batch in [
		[red, Color(0.78, 0.08, 0.07), "ImpactBlocksRed"],
		[white, Color(0.92, 0.92, 0.9), "ImpactBlocksWhite"]
	]:
		var mat = StandardMaterial3D.new()
		mat.albedo_color = batch[1]
		mat.roughness = 0.5
		var mesh = BoxMesh.new()
		mesh.material = mat
		var mm = MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = mesh
		mm.instance_count = batch[0].size()
		for i in batch[0].size():
			mm.set_instance_transform(i, batch[0][i])
		var node = MultiMeshInstance3D.new()
		node.multimesh = mm
		attach(asset, parent, node, batch[2])


## Port Hercule's moored yachts: stern-to along both sides of every OSM pontoon (man_made=pier lines),
## 12-40 m motor yachts, one MultiMesh.
static func _yachts(asset: Node3D, parent: Node, piers: Array) -> void:
	var rng = RandomNumberGenerator.new()
	rng.seed = 98002
	var xforms = []
	var outlines = []
	for flat in piers:
		var ring = PackedVector2Array()
		for i in range(0, flat.size() - 1, 2):
			ring.append(Vector2(flat[i], flat[i + 1]))
		if ring.size() > 3 and ring[0].distance_to(ring[-1]) < 0.5:
			outlines.append(ring)
	for flat in piers:
		for i in range(0, flat.size() - 3, 2):
			var a = Vector2(flat[i], flat[i + 1])
			var b = Vector2(flat[i + 2], flat[i + 3])
			var along = (b - a).normalized()
			var out = Vector2(-along.y, along.x)
			var t = 4.0
			while t < a.distance_to(b) - 4.0:
				var length = (
					rng.randf_range(12.0, 40.0)
					if rng.randf() < 0.3
					else rng.randf_range(12.0, 22.0)
				)
				var beam = length * 0.26
				for side in [-1.0, 1.0]:
					if rng.randf() < 0.15:
						continue
					var c = a + along * t + out * side * (2.0 + length * 0.5)
					if outlines.any(func(r): return Geometry2D.is_point_in_polygon(c, r)):
						continue
					var dir = out * side
					var basis = (
						Basis(Vector3(dir.x, 0, dir.y), Vector3.UP, Vector3(-dir.y, 0, dir.x))
						* Basis.from_scale(Vector3(length, 1, beam))
					)
					xforms.append(Transform3D(basis, Vector3(c.x, SEA_Y, c.y)))
				t += 12.0 * 0.26 + 1.5 + rng.randf() * 2.0
	if xforms.is_empty():
		return
	var mm = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = _yacht_mesh()
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
	var node = MultiMeshInstance3D.new()
	node.multimesh = mm
	node.visibility_range_end = 1200.0
	attach(asset, parent, node, "Yachts")


## Unit yacht (1 m long, 1 m beam, real heights): tapered white hull, cabin, dark window band.
static func _yacht_mesh() -> ArrayMesh:
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var white = Color(0.95, 0.95, 0.93)
	var parts = [
		[Vector3(0.0, 0.8, 0.0), Vector3(1.0, 1.9, 1.0), white],
		[Vector3(-0.08, 2.4, 0.0), Vector3(0.55, 1.2, 0.8), white],
		[Vector3(-0.08, 2.35, 0.0), Vector3(0.56, 0.45, 0.82), Color(0.08, 0.1, 0.14)],
		[Vector3(-0.12, 3.4, 0.0), Vector3(0.3, 0.9, 0.6), white]
	]
	for part in parts:
		var box = BoxMesh.new()
		box.size = part[1]
		var arrays = box.get_mesh_arrays()
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		for k in idx:
			var v = verts[k]
			# Taper the hull's bow (+X half) to a point.
			if part == parts[0] and v.x > 0.0:
				v.z *= 0.35
			st.set_color(part[2])
			st.set_normal(normals[k])
			st.add_vertex(v + part[0])
	var mat = StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.35
	st.set_material(mat)
	return st.commit()


## Pool basins (OSM leisure=swimming_pool): tiled water just under their deck.
static func _pools(asset: Node3D, parent: Node, pools: Array) -> void:
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for p in pools:
		var ring = PackedVector2Array()
		for i in range(0, p[0].size() - 1, 2):
			ring.append(Vector2(p[0][i], p[0][i + 1]))
		var tris = Geometry2D.triangulate_polygon(ring)
		for i in range(0, tris.size(), 3):
			for k in [0, 2, 1]:
				var q = ring[tris[i + k]]
				st.set_normal(Vector3.UP)
				st.add_vertex(Vector3(q.x, float(p[1]) + 0.08, q.y))
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 0.62, 0.78)
	mat.roughness = 0.05
	mat.metallic_specular = 0.9
	var node = MeshInstance3D.new()
	node.mesh = st.commit()
	node.material_override = mat
	attach(asset, parent, node, "Pools")


static func _flats(
	asset: Node3D, parent: Node, rings: Array, y: float, mat: String, title: String
) -> void:
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for flat in rings:
		var ring = PackedVector2Array()
		for i in range(0, flat.size() - 1, 2):
			ring.append(Vector2(flat[i], flat[i + 1]))
		var tris = Geometry2D.triangulate_polygon(ring)
		for i in range(0, tris.size(), 3):
			for k in [0, 2, 1]:
				var p = ring[tris[i + k]]
				st.set_normal(Vector3.UP)
				st.set_uv(p / 4.0)
				st.add_vertex(Vector3(p.x, y, p.y))
	var node = MeshInstance3D.new()
	node.mesh = st.commit()
	node.material_override = ChicagoCity.material(mat)
	attach(asset, parent, node, title)


## The mapped trees (mostly palms and planes along the boulevards) as the shared tree cards.
static func _trees(asset: Node3D, parent: Node, trees: Array) -> void:
	var rng = RandomNumberGenerator.new()
	rng.seed = 98001
	var atlas = RoadScatter.cards_for(RoadScatter.AtlasKind.TREES)
	var mm = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.use_custom_data = true
	mm.mesh = RoadScatter.card_mesh()
	mm.instance_count = trees.size()
	for i in trees.size():
		var t = trees[i]
		var pick = RoadScatter.pick_card(
			rng, RoadScatter.AtlasKind.TREES, PackedInt32Array([2, 3, 4])
		)
		var card = atlas[pick.card]
		var h = pick.height * 0.55
		var w = h * 1.15 * card[2] / card[3]
		mm.set_instance_transform(
			i,
			Transform3D(
				Basis(Vector3.UP, rng.randf() * TAU) * Basis.from_scale(Vector3(w, h, w)),
				Vector3(t[0], t[1], t[2])
			)
		)
		mm.set_instance_custom_data(i, Color(card[0], card[1], card[2], card[3]))
		mm.set_instance_color(i, pick.tint)
	var node = MultiMeshInstance3D.new()
	node.multimesh = mm
	node.material_override = RoadScatter.tree_material(RoadScatter.AtlasKind.TREES)
	attach(asset, parent, node, "Trees")


## The tunnel under the Fairmont, after the reference photos (Commons, "Circuit de Monaco - Tunnel"): a flat
## concrete ceiling 5.4 m up, a tiled inner (right-hand) wall with a strip of lamps along its top, and on the
## sea side a low wall with pillars every 6 m and open bays between them. The frame stays level.
static func _tunnel(asset: Node3D, parent: Node, road, span: Vector2) -> void:
	var c: Curve3D = road.working_curve()
	var walls = SurfaceTool.new()
	walls.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tiles = SurfaceTool.new()
	tiles.begin(Mesh.PRIMITIVE_TRIANGLES)
	var lamps = []
	var pillars = []
	var step = 2.0
	var s = span.x
	var n = 0
	while s < span.y - 0.01:
		var e = minf(s + step, span.y)
		var f0 = _level_frame(c, s)
		var f1 = _level_frame(c, e)
		# Ceiling (seen from below), inner tiled wall, sea-side kerb wall and the beam over the bays.
		_quad(
			walls,
			f0[0] - f0[1] * 7.0 + Vector3(0, 5.4, 0),
			f1[0] - f1[1] * 7.0 + Vector3(0, 5.4, 0),
			f1[0] + f1[1] * 7.0 + Vector3(0, 5.4, 0),
			f0[0] + f0[1] * 7.0 + Vector3(0, 5.4, 0),
			s,
			e
		)
		_quad(
			tiles,
			f0[0] + f0[1] * 7.0 + Vector3(0, -0.3, 0),
			f1[0] + f1[1] * 7.0 + Vector3(0, -0.3, 0),
			f1[0] + f1[1] * 7.0 + Vector3(0, 5.4, 0),
			f0[0] + f0[1] * 7.0 + Vector3(0, 5.4, 0),
			s,
			e
		)
		_quad(
			walls,
			f0[0] - f0[1] * 7.0 + Vector3(0, -0.3, 0),
			f0[0] - f0[1] * 7.0 + Vector3(0, 1.1, 0),
			f1[0] - f1[1] * 7.0 + Vector3(0, 1.1, 0),
			f1[0] - f1[1] * 7.0 + Vector3(0, -0.3, 0),
			s,
			e
		)
		_quad(
			walls,
			f0[0] - f0[1] * 7.0 + Vector3(0, 4.7, 0),
			f0[0] - f0[1] * 7.0 + Vector3(0, 5.4, 0),
			f1[0] - f1[1] * 7.0 + Vector3(0, 5.4, 0),
			f1[0] - f1[1] * 7.0 + Vector3(0, 4.7, 0),
			s,
			e
		)
		if n % 3 == 0:
			pillars.append(
				Transform3D(
					(
						Basis(f0[1], Vector3.UP, f0[1].cross(Vector3.UP))
						* Basis.from_scale(Vector3(0.8, 3.6, 0.8))
					),
					f0[0] - f0[1] * 7.3 + Vector3(0, 2.9, 0)
				)
			)
		if n % 2 == 0:
			lamps.append(
				Transform3D(
					(
						Basis(f0[1], Vector3.UP, f0[1].cross(Vector3.UP))
						* Basis.from_scale(Vector3(0.35, 0.18, 1.1))
					),
					f0[0] + f0[1] * 6.7 + Vector3(0, 5.1, 0)
				)
			)
		if n % 18 == 0:
			var light = OmniLight3D.new()
			light.position = f0[0] + Vector3(0, 4.4, 0)
			light.light_color = Color(1.0, 0.93, 0.8)
			light.light_energy = 1.4
			light.omni_range = 20.0
			attach(asset, parent, light, "TunnelLight%d" % n)
		s = e
		n += 1
	for pair in [
		[walls, ChicagoCity.material("wall"), "Tunnel"], [tiles, _tile_material(), "TunnelTiles"]
	]:
		pair[0].generate_normals()
		var node = MeshInstance3D.new()
		node.mesh = pair[0].commit()
		node.material_override = pair[1]
		attach(asset, parent, node, pair[2])
	var lamp_mat = StandardMaterial3D.new()
	lamp_mat.albedo_color = Color(1, 0.97, 0.9)
	lamp_mat.emission_enabled = true
	lamp_mat.emission = Color(1.0, 0.95, 0.85)
	lamp_mat.emission_energy_multiplier = 4.0
	for batch in [
		[pillars, ChicagoCity.material("wall"), "TunnelPillars"], [lamps, lamp_mat, "TunnelLamps"]
	]:
		var mesh = BoxMesh.new()
		mesh.material = batch[1]
		var mm = MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = mesh
		mm.instance_count = batch[0].size()
		for i in batch[0].size():
			mm.set_instance_transform(i, batch[0][i])
		var node = MultiMeshInstance3D.new()
		node.multimesh = mm
		attach(asset, parent, node, batch[2])


## Centre and level right-hand vector at `s` (tunnel walls stay vertical even where the road banks).
static func _level_frame(c: Curve3D, s: float) -> Array:
	var p = c.sample_baked(s, true)
	var t = (
		c.sample_baked(minf(s + 0.5, c.get_baked_length()), true)
		- c.sample_baked(maxf(s - 0.5, 0.0), true)
	)
	return [p, Vector3(t.x, 0, t.z).normalized().cross(Vector3.UP)]


## Double-sided quad a-b-c-d, UV in metres (along from s0 to s1, up the height).
static func _quad(
	st: SurfaceTool, a: Vector3, b: Vector3, cc: Vector3, d: Vector3, s0: float, s1: float
) -> void:
	var uv = [Vector2(s0, a.y), Vector2(s1, b.y), Vector2(s1, cc.y), Vector2(s0, d.y)]
	var v = [a, b, cc, d]
	for k in [0, 1, 2, 0, 2, 3, 0, 2, 1, 0, 3, 2]:
		st.set_uv(uv[k])
		st.add_vertex(v[k])


static func _facade_material() -> ShaderMaterial:
	var m = ShaderMaterial.new()
	m.shader = preload("res://shaders/monaco_facade.gdshader")
	return m


static func _tile_material() -> ShaderMaterial:
	var m = ShaderMaterial.new()
	m.shader = preload("res://shaders/monaco_tunnel.gdshader")
	return m


func _initialize() -> void:
	var asset = build_asset()
	print("MONACO errors=", asset.validate())
	asset.free()
	quit()
