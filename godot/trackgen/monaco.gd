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
const PropMesh = preload("res://scripts/track/prop_mesh.gd")
## Corners with escape roads / run-off that carry red and white impact blocks (Commons "Portier" photo).
const BLOCK_CORNERS = [
	"Sainte-Devote", "Mirabeau Haute", "Grand Hotel Hairpin", "Portier", "Nouvelle Chicane", "La Rascasse"
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
	return Vector3((lon - ORIGIN.y) * 111320.0 * cos(deg_to_rad(ORIGIN.x)), 0.0, (ORIGIN.x - lat) * 111320.0)


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
	asset.version = 5
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
	# OSM raceway entry/exit, not an arbitrary radius round the Piscine label.
	var pool_gap = Vector2(
		road.curve.get_closest_offset(world_of(43.7355741, 7.421779) + Vector3.UP * 2.0) - 12.0,
		road.curve.get_closest_offset(world_of(43.7338035, 7.4222185) + Vector3.UP * 2.0) + 70.0
	)
	road.sections.append(RoadSection.make(0.0, _section(START_HALF_WIDTH, false)))
	for c in CORNERS:
		if c[0] == "Nouvelle Chicane":
			continue  # its own keys below
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
	# Owner: Nouvelle Chicane is open asphalt with kerbs, not a walled channel: tarmac runoff both sides and no
	# road-following barrier or fence through it (offset 7 m out, their lines folded back across the track on
	# the inside of its bends), the same as the Swimming Pool gap.
	var chicane = Vector2(corners["Nouvelle Chicane"] - 40.0, corners["Nouvelle Chicane"] + 70.0)
	for at in [chicane.x, chicane.x + 20.0, chicane.y - 20.0, chicane.y]:
		var section = _section(5.0, true)
		section.kerb_width = 1.0
		if at > chicane.x and at < chicane.y:
			section.runoff_left = 7.0
			section.runoff_right = 7.0
		road.sections.append(RoadSection.make(at, section))
	road.sections.sort_custom(func(a, b): return a.at < b.at)
	asset.set_meta("chicane", chicane)
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
		var spans = [Vector2(0, chicane.x), Vector2(chicane.y, pool_gap.x), Vector2(pool_gap.y, length)]
		for k in spans.size():
			var span = spans[k]
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
				("LeftBarrier" if side == WallPath.Side.LEFT else "RightBarrier") + ["", "B", "C"][k]
			)
			wall.bake()
	var scenery = Node3D.new()
	attach(asset, asset, scenery, "Scenery")
	# Debris fencing on both barriers, as at every street circuit; none inside the tunnel.
	for barrier in ["LeftBarrier", "RightBarrier"]:
		for span in [[0.0, tunnel.x], [tunnel.y, chicane.x], [chicane.y, pool_gap.x], [pool_gap.y, length]]:
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
	_retaining_walls(asset, scenery, d.ground, tunnel, d.buildings)
	_fairmont_island(asset, scenery, road, corners["Grand Hotel Hairpin"], d.ground)
	_buildings(asset, scenery, d.buildings)
	_frontage(asset, scenery)
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
		gs.solid_front = true
		gs.open_structure = not gs.solid_front
		attach(asset, asset, gs, st[0])
		gs.bake()
	_yachts(asset, scenery, d.piers, d.ground)
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
		"route_description", "Sainte-Devote / Casino / Mirabeau / tunnel / chicane / Piscine / Rascasse"
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
					Vector3(g.x0 + (ix + o[0]) * cell, h[iz + o[1]][ix + o[0]], g.z0 + (iz + o[1]) * cell)
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
						var tx = (p.x - q[0].x) / cell
						var tz = (p.z - q[0].z) / cell
						p.y = (
							q[0].y + (q[1].y - q[0].y) * tx + (q[2].y - q[1].y) * tz
							if tx >= tz
							else q[0].y + (q[2].y - q[3].y) * tx + (q[3].y - q[0].y) * tz
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
	# Paved Monaco: pale slab pavements, dressed-stone faces on the steep cells (Poly Haven CC0).
	for pair in [
		# Grey-toned: beige slabs read as sand across the open pool quay.
		[flat, _pbr("rectangular_paving", 3.0, Color(0.62, 0.64, 0.68)), "Ground"],
		[steep, _pbr("sandstone_blocks_05", 1.2), "RetainingWalls"],
		[garden, ChicagoCity.material("park"), "Gardens"]
	]:
		pair[0].generate_normals()
		var node = MeshInstance3D.new()
		node.mesh = pair[0].commit()
		node.material_override = pair[1]
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		attach(asset, parent, node, pair[2])
	return trees


## Low, non-colliding planting island inside the Fairmont hairpin (official trackside reference).
static func _fairmont_island(
	asset: Node3D, parent: Node, road: Node, station: float, terrain: Dictionary
) -> void:
	var curve: Curve3D = road.working_curve()
	# The named OSM corner marker is near the exit. Centre the bed on the actual tightest bend.
	var bend = 0.0
	var apex = station
	for offset in range(-40, 41, 2):
		var at = station + offset
		var before = curve.sample_baked(at - 4.0, true)
		var point = curve.sample_baked(at, true)
		var after = curve.sample_baked(at + 4.0, true)
		var angle = absf(
			Vector2(point.x - before.x, point.z - before.z).angle_to(
				Vector2(after.x - point.x, after.z - point.z)
			)
		)
		if angle > bend:
			bend = angle
			apex = at
	station = apex
	asset.set_meta("fairmont_apex", apex)
	var p0 = curve.sample_baked(station - 8.0, true)
	var p1 = curve.sample_baked(station, true)
	var p2 = curve.sample_baked(station + 8.0, true)
	var a = Vector2(p0.x, p0.z)
	var b = Vector2(p1.x, p1.z)
	var c = Vector2(p2.x, p2.z)
	var det = 2.0 * (a.x * (b.y - c.y) + b.x * (c.y - a.y) + c.x * (a.y - b.y))
	if absf(det) < 1e-4:
		return
	var aa = a.length_squared()
	var bb = b.length_squared()
	var cc = c.length_squared()
	var center = Vector2(
		(aa * (b.y - c.y) + bb * (c.y - a.y) + cc * (a.y - b.y)) / det,
		(aa * (c.x - b.x) + bb * (a.x - c.x) + cc * (b.x - a.x)) / det
	)
	var ground_y = _ground_y(terrain, center.x, center.y)

	var bed = CylinderMesh.new()
	bed.top_radius = 2.7
	bed.bottom_radius = 2.9
	bed.height = 0.32
	bed.radial_segments = 24
	var rim_mat = StandardMaterial3D.new()
	rim_mat.albedo_color = Color(0.56, 0.48, 0.36)
	rim_mat.roughness = 0.9
	bed.material = rim_mat
	var rim = MeshInstance3D.new()
	rim.mesh = bed
	rim.position = Vector3(center.x, ground_y + 0.16, center.y)
	attach(asset, parent, rim, "FairmontPlanter")
	var soil = CylinderMesh.new()
	soil.top_radius = 2.62
	soil.bottom_radius = 2.62
	soil.height = 0.04
	soil.radial_segments = 24
	var soil_mat = StandardMaterial3D.new()
	soil_mat.albedo_color = Color(0.24, 0.20, 0.14)
	soil_mat.roughness = 1.0
	soil.material = soil_mat
	var planting = MeshInstance3D.new()
	planting.mesh = soil
	planting.position = Vector3(center.x, ground_y + 0.34, center.y)
	attach(asset, parent, planting, "FairmontPlanting")
	var palm = MeshInstance3D.new()
	palm.mesh = PropMesh.mesh("res://assets/nature/kenney/palm.glb")
	for surface in palm.mesh.get_surface_count():
		var material = palm.mesh.surface_get_material(surface).duplicate()
		material.albedo_color = Color("556b2f") if material.resource_name == "leafsGreen" else Color("77614b")
		material.metallic = 0.0
		material.roughness = 0.9
		palm.set_surface_override_material(surface, material)
	palm.scale = Vector3.ONE * 4.5
	palm.position = Vector3(center.x, ground_y + 0.58, center.y)
	attach(asset, parent, palm, "FairmontPalm")
	var shrub = PropMesh.mesh("res://assets/nature/rocks-foliage/grass_bush.glb")
	for i in 7:
		var bush = MeshInstance3D.new()
		bush.mesh = shrub
		var angle = TAU * i / 6.0
		var radius = 0.0 if i == 6 else 1.55
		bush.position = Vector3(
			center.x + cos(angle) * radius, ground_y + 0.36, center.y + sin(angle) * radius
		)
		bush.rotation.y = angle
		bush.scale = Vector3.ONE * (1.3 if i == 6 else 1.1)
		bush.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		attach(asset, parent, bush, "FairmontShrub%d" % i)


static func _sea(asset: Node3D, parent: Node, g: Dictionary) -> void:
	var plane = PlaneMesh.new()
	plane.size = Vector2(6000, 6000)
	var mat = ShaderMaterial.new()
	mat.shader = WATER_SHADER
	mat.set_shader_parameter("deep_color", Color(0.08, 0.42, 0.52))
	plane.material = mat
	var node = MeshInstance3D.new()
	node.mesh = plane
	node.position = Vector3(g.x0 + g.nx * g.cell * 0.5, SEA_Y, g.z0 + g.nz * g.cell * 0.5 + 1500.0)
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	attach(asset, parent, node, "Sea")


## OSM footprints extruded from their ground base; facade shader (lit windows at night) in Riviera tints.
static func _buildings(asset: Node3D, parent: Node, list: Array) -> void:
	var chunks = {}
	var cornices = {}
	var rng = RandomNumberGenerator.new()
	rng.seed = 98000
	for b in list:
		# Frontage (b[4]) and the Casino: modelled in Blender, placed by _frontage().
		if (b.size() > 4 and b[4] >= 1) or b[3] == "casino":
			continue
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
		var seed = rng.randf()
		_extrude(chunks[key], ring, float(b[1]) - 0.5, float(b[1]) + float(b[2]), seed, layer, tint)
		# Past 250 m the painted facade carries the windows; a modelled cornice gives the skyline its roofline.
		var outer = Geometry2D.offset_polygon(ring, 0.45)
		if b[2] > 7.0 and b[3] != "roof" and not outer.is_empty():
			if not cornices.has(key):
				var band = SurfaceTool.new()
				band.begin(Mesh.PRIMITIVE_TRIANGLES)
				cornices[key] = band
			var top = float(b[1]) + float(b[2])
			_extrude(cornices[key], outer[0], top - 1.1, top - 0.65, seed, layer, tint)
	for key in chunks:
		var st: SurfaceTool = chunks[key]
		st.generate_normals()
		# On the surface, not as an override: NightGlow.set_night toggles `afterhours` on mesh materials.
		st.set_material(_facade_material())
		var node = MeshInstance3D.new()
		node.mesh = st.commit()
		attach(asset, parent, node, "Buildings_%d_%d" % [key.x, key.y])
	var cornice_mat = StandardMaterial3D.new()
	cornice_mat.albedo_color = Color("e6dfd2")
	cornice_mat.roughness = 0.8
	for key in cornices:
		var band: SurfaceTool = cornices[key]
		band.generate_normals()
		band.set_material(cornice_mat)
		var node = MeshInstance3D.new()
		node.mesh = band.commit()
		attach(asset, parent, node, "Cornices_%d_%d" % [key.x, key.y])


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
	st.set_color(Color(seed, layer / 8.0, 1, code))
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


## Blender exteriors in world coordinates: every non-landmark building within 30 m of the lap (frontage)
## and the Casino's square elevation (tools/blender/monaco_frontage.py, monaco_casino.py).
static func _frontage(asset: Node3D, parent: Node) -> void:
	# [glb, node, visibility range end (0 = always)]: the 120-250 m tier is culled past 1.5 km.
	for pair in [
		["frontage", "Frontage", 0],
		["mid", "FrontageMid", 0],
		["far", "FrontageFar", 1500],
		["monaco_casino", "Casino", 0]
	]:
		var node = load("res://assets/monaco/%s.glb" % pair[0]).instantiate()
		attach(asset, parent, node, pair[1])
		for child in node.find_children("*", "", true, false):
			child.owner = asset
			if pair[2] > 0 and child is GeometryInstance3D:
				child.visibility_range_end = pair[2]
	# Glass gains the night toggle (NightGlow walks mesh surface materials with an fterhours uniform).
	var windows = {}
	for pair in [
		["Dark window glass", 0.35, 1.6], ["Shopfront glass", 0.7, 0.7], ["Casino dark glass", 0.5, 1.2]
	]:
		var mat = ShaderMaterial.new()
		mat.shader = preload("res://shaders/monaco_window.gdshader")
		mat.set_shader_parameter("lit_share", pair[1])
		mat.set_shader_parameter("glow", pair[2])
		windows[pair[0]] = mat
	for mesh_node in (
		parent.get_node("Frontage").find_children("*", "MeshInstance3D", true, false)
		+ parent.get_node("FrontageMid").find_children("*", "MeshInstance3D", true, false)
		+ parent.get_node("FrontageFar").find_children("*", "MeshInstance3D", true, false)
		+ parent.get_node("Casino").find_children("*", "MeshInstance3D", true, false)
	):
		for i in mesh_node.mesh.get_surface_count():
			var mat = mesh_node.mesh.surface_get_material(i)
			if mat and windows.has(mat.resource_name):
				mesh_node.mesh.surface_set_material(i, windows[mat.resource_name])


## The baked barrier line on one side as [road metres, inner-face base point, outward] every 2 m. Dressing
## mounted on the armco reads this, so it can never part from the barrier where the road width blends.
static func _barrier_line(asset: Node3D, side: int) -> Array:
	var out = []
	var prefix = "LeftBarrier" if side == WallPath.Side.LEFT else "RightBarrier"
	for title in [prefix, prefix + "B", prefix + "C"]:
		var wall = asset.get_node_or_null(title)
		if wall == null:
			continue
		var line: PackedVector3Array = wall.last_bake.line
		var count = line.size() - 1
		for i in line.size():
			var s = wall.from_m + (wall.to_m - wall.from_m) * i / maxf(count, 1)
			out.append([s, line[i], wall.last_bake.outward[i]])
	return out


## Ground height from the city grid (bilinear), as the ground mesh draws it.
static func _ground_y(g: Dictionary, x: float, z: float) -> float:
	var gx = (x - float(g.x0)) / float(g.cell)
	var gz = (z - float(g.z0)) / float(g.cell)
	var ix = clampi(floori(gx), 0, int(g.nx) - 2)
	var iz = clampi(floori(gz), 0, int(g.nz) - 2)
	var tx = clampf(gx - ix, 0.0, 1.0)
	var tz = clampf(gz - iz, 0.0, 1.0)
	var h: Array = g.h
	return lerpf(lerpf(h[iz][ix], h[iz][ix + 1], tx), lerpf(h[iz + 1][ix], h[iz + 1][ix + 1], tx), tz)


## Dressed-stone retaining walls right behind the armco wherever the hillside stands above the road
## (Mirabeau, the Fairmont hairpin, Portier, Beau Rivage), plus escarpment walls where the ground steps up
## between two legs of the lap (_escarpment). Visual only.
static func _retaining_walls(
	asset: Node3D, parent: Node, g: Dictionary, tunnel: Vector2, buildings: Array
) -> void:
	# Footprints by 10 m cell: no wall where a building fronts the pavement.
	var cells = {}
	for b in buildings:
		var ring = PackedVector2Array()
		for i in range(0, b[0].size() - 1, 2):
			ring.append(Vector2(b[0][i], b[0][i + 1]))
		var box = Rect2(ring[0], Vector2.ZERO)
		for p in ring:
			box = box.expand(p)
		for cx in range(floori(box.position.x / 10.0), floori(box.end.x / 10.0) + 1):
			for cz in range(floori(box.position.y / 10.0), floori(box.end.y / 10.0) + 1):
				cells.get_or_add(Vector2i(cx, cz), []).append(ring)
	var built = func(p: Vector3) -> bool:
		for ring in cells.get(Vector2i(floori(p.x / 10.0), floori(p.z / 10.0)), []):
			if Geometry2D.is_point_in_polygon(Vector2(p.x, p.z), ring):
				return true
		return false
	var curve: Curve3D = asset.get_node("Main").working_curve()
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for side in [WallPath.Side.LEFT, WallPath.Side.RIGHT]:
		var line = _barrier_line(asset, side)
		var u = 0.0
		var run = []
		for i in line.size() - 1:
			var a = line[i]
			var b = line[i + 1]
			var step = a[1].distance_to(b[1])
			if step > 6.0 or (a[0] > tunnel.x - 2.0 and a[0] < tunnel.y + 2.0):
				_wall_run(st, run)
				run = []
				continue
			# Right behind the armco: between two legs at different heights (the hairpin exit under Mirabeau)
			# the slope starts at the barrier, and a wall set further back stood inside it.
			var pa: Vector3 = a[1] + a[2] * 0.4
			var pb: Vector3 = b[1] + b[2] * 0.4
			# Height: the highest ground in the next 12 m behind, capped (Monaco's roadside walls stand 5-15 m).
			var top_a = minf(_ground_max(g, a[1], a[2]) + 0.6, pa.y + 12.0)
			var top_b = minf(_ground_max(g, b[1], b[2]) + 0.6, pb.y + 12.0)
			var fronted = [2.0, 5.0, 9.0, 14.0, 20.0].any(func(k): return built.call(pa + a[2] * k))
			# On the inside of a tight bend the offset line folds back over the road: a wall must stand
			# farther from the centreline than its barrier, at both ends.
			var folded = (
				_off_centre(curve, pa) < _off_centre(curve, a[1]) + 0.3
				or _off_centre(curve, pb) < _off_centre(curve, b[1]) + 0.3
			)
			if fronted or folded or minf(top_a - pa.y, top_b - pb.y) < 1.5:
				_wall_run(st, run)
				run = []
				u += step
				continue
			run.append([pa, pb, top_a, top_b, a[2], b[2], u, u + step])
			u += step
		_wall_run(st, run)
	_escarpment(asset, st, g, tunnel, built)
	st.generate_normals()
	var node = MeshInstance3D.new()
	node.mesh = st.commit()
	node.material_override = _pbr("sandstone_blocks_05", 0.4)
	attach(asset, parent, node, "StoneWalls")


## Highest ground 4-12 m out from p along outward.
static func _ground_max(g: Dictionary, p: Vector3, outward: Vector3) -> float:
	var top = -INF
	for k in [4.0, 8.0, 12.0]:
		var q = p + outward * k
		top = maxf(top, _ground_y(g, q.x, q.z))
	return top


## Escarpment walls where the ground actually steps up beside the lap: build_city.py keeps it flat around
## each road, so between two legs at different heights (the harbour straight under Beau Rivage, the hairpin
## exit under Mirabeau) it steps up midway, where the 8 m grid drew stone pyramids between the buildings.
## Walking out from 5.5 m to 34 m, the first rise of 1 m places the wall; its top is the ground 4-12 m beyond.
static func _escarpment(
	asset: Node3D, st: SurfaceTool, g: Dictionary, tunnel: Vector2, built: Callable
) -> void:
	var c: Curve3D = asset.get_node("Main").working_curve()
	var length = c.get_baked_length()
	for side in [-1.0, 1.0]:
		var run = []
		var s = 0.0
		var prev = null
		while s < length:
			var f = _level_frame(c, s)
			var out: Vector3 = f[1] * side
			var hit = null
			var k = 5.5
			while k <= 34.0:
				var q: Vector3 = f[0] + out * k
				if _ground_y(g, q.x, q.z) > f[0].y + 1.0:
					hit = f[0] + out * (k - 0.6)
					break
				k += 1.0
			var keep = (
				hit != null
				and prev != null
				and not (s > tunnel.x - 20.0 and s < tunnel.y + 20.0)
				# Not on another road (the wall line stands between them), not inside a building.
				and _off_centre(c, hit) > 4.8
				and not built.call(hit)
			)
			if keep:
				var top_a = minf(_ground_max(g, prev[0], prev[1]) + 0.3, prev[0].y + 25.0)
				var top_b = minf(_ground_max(g, hit, out) + 0.3, hit.y + 25.0)
				run.append([prev[0], hit, top_a, top_b, prev[1], out, s - 2.0, s])
			else:
				_wall_run(st, run)
				run = []
			prev = [hit, out] if hit != null else null
			s += 2.0
		_wall_run(st, run)


## Horizontal distance from p to the lap's centreline.
static func _off_centre(curve: Curve3D, p: Vector3) -> float:
	var on = curve.get_closest_point(p)
	return Vector2(p.x - on.x, p.z - on.z).length()


## One continuous wall: face and coping per segment. Runs under 6 m (a slot between two buildings) read as
## free-standing spires, so they are left to the buildings either side.
static func _wall_run(st: SurfaceTool, run: Array) -> void:
	if run.size() < 3:
		return
	# Level copings in 1.5 m steps (the highest ground within three segments, rounded up): a coping that
	# followed the hill rose and fell along each run and read as stone pyramids from the road.
	var tops = []
	for i in run.size():
		var high = -INF
		for k in range(maxi(i - 3, 0), mini(i + 4, run.size())):
			high = maxf(high, maxf(run[k][2], run[k][3]))
		var base = minf(run[i][0].y, run[i][1].y)
		tops.append(base + ceilf((high - base) / 1.5) * 1.5)
	for i in run.size():
		var r = run[i]
		var crown_a = Vector3(r[0].x, tops[i], r[0].z)
		var crown_b = Vector3(r[1].x, tops[i], r[1].z)
		_quad(st, r[0] - Vector3(0, 0.3, 0), r[1] - Vector3(0, 0.3, 0), crown_b, crown_a, r[6], r[7])
		# Coping: a 0.6 m deep cap back towards the hill.
		_quad(st, crown_a, crown_b, crown_b + r[5] * 0.6, crown_a + r[4] * 0.6, r[6], r[7])


## Advertising panels flat on the armco face, both sides, end to end, as on the F1 onboards; none in the
## tunnel. One MultiMesh with per-panel colour.
static func _ad_panels(asset: Node3D, parent: Node, road, tunnel: Vector2) -> void:
	var rng = RandomNumberGenerator.new()
	rng.seed = 98010
	var xforms = []
	var colors = []
	var customs = []
	for side in [WallPath.Side.LEFT, WallPath.Side.RIGHT]:
		var line = _barrier_line(asset, side)
		# One 6 m panel per three 2 m barrier points, centred on the middle one.
		for i in range(1, line.size() - 1, 3):
			var s = line[i][0]
			if s > tunnel.x - 5.0 and s < tunnel.y + 5.0:
				continue
			var a: Vector3 = line[i - 1][1]
			var b: Vector3 = line[i + 1][1]
			# Follow the barrier's pitch so panels on the Beau Rivage climb run with it, not in steps.
			var along = (b - a).normalized()
			var outward: Vector3 = line[i][2]
			if along.length() < 0.5 or a.distance_to(b) > 6.0:
				continue
			var up = along.cross(outward).normalized()
			if up.y < 0.0:
				up = -up
			var normal = along.cross(up).normalized()
			var p = line[i][1] - outward * 0.05 + up * 0.55
			xforms.append(
				Transform3D(Basis(along, up, normal) * Basis.from_scale(Vector3(5.9, 0.9, 0.04)), p)
			)
			colors.append(AD_COLORS[rng.randi() % AD_COLORS.size()])
			customs.append(Color((rng.randi() % 4 + 0.5) / 4.0, rng.randf(), 0, 0))
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
		var outside = WallPath.Side.LEFT if f0[1].cross(f1[1]).y < 0.0 else WallPath.Side.RIGHT
		# Stacked against the armco's inner face (the baked barrier line), one 1.9 m block per 2 m point.
		var k = 0
		for q in _barrier_line(asset, outside):
			var d = fposmod(q[0] - apex + length * 0.5, length) - length * 0.5
			if absf(d) > 25.0:
				continue
			var outward: Vector3 = q[2]
			var p: Vector3 = q[1] - outward * 0.36 + Vector3(0, 0.45, 0)
			var xf = Transform3D(
				(
					Basis(outward.cross(Vector3.UP), Vector3.UP, outward)
					* Basis.from_scale(Vector3(1.9, 0.9, 0.7))
				),
				p
			)
			(red if k % 2 == 0 else white).append(xf)
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
static func _yachts(asset: Node3D, parent: Node, piers: Array, g: Dictionary) -> void:
	var curve: Curve3D = asset.get_node("Main").working_curve()
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
				var length = rng.randf_range(12.0, 40.0) if rng.randf() < 0.3 else rng.randf_range(12.0, 22.0)
				var beam = length * 0.26
				for side in [-1.0, 1.0]:
					if rng.randf() < 0.15:
						continue
					var c = a + along * t + out * side * (2.0 + length * 0.5)
					if outlines.any(func(r): return Geometry2D.is_point_in_polygon(c, r)):
						continue
					# Afloat only, and clear of the lap: by Nouvelle Chicane some pontoon berths fell on the
					# quay and the runoff, and the hulls stood in the asphalt.
					if _ground_y(g, c.x, c.y) > -1.0 or _off_centre(curve, Vector3(c.x, SEA_Y, c.y)) < 15.0:
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


## Unit yacht (1 m long along +X, 1 m beam, real heights) from tools/blender/monaco_yacht.py: lofted hull,
## tapered deckhouses with dark window bands, radar arch. The box hull and cabin read as white slabs.
static func _yacht_mesh() -> ArrayMesh:
	var scene = load("res://assets/monaco/monaco_yacht.glb").instantiate()
	var out = ArrayMesh.new()
	for part in scene.find_children("*", "MeshInstance3D", true, false):
		for i in part.mesh.get_surface_count():
			out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, part.mesh.surface_get_arrays(i))
			out.surface_set_material(out.get_surface_count() - 1, part.mesh.surface_get_material(i))
	scene.free()
	return out


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


static func _flats(asset: Node3D, parent: Node, rings: Array, y: float, mat: String, title: String) -> void:
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
		var pick = RoadScatter.pick_card(rng, RoadScatter.AtlasKind.TREES, PackedInt32Array([2, 3, 4]))
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
	var ceiling = SurfaceTool.new()
	ceiling.begin(Mesh.PRIMITIVE_TRIANGLES)
	var lamps = []
	var pillars = []
	var step = 2.0
	var s = span.x
	var n = 0
	while s < span.y - 0.01:
		var e = minf(s + step, span.y)
		var f0 = _level_frame(c, s)
		var f1 = _level_frame(c, e)
		# Ceiling (seen from below), inner tiled wall under a concrete band (the lamp rail and vents), sea-side
		# kerb wall and the beam over the bays.
		_quad(
			ceiling,
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
			f1[0] + f1[1] * 7.0 + Vector3(0, 4.2, 0),
			f0[0] + f0[1] * 7.0 + Vector3(0, 4.2, 0),
			s,
			e
		)
		_quad(
			walls,
			f0[0] + f0[1] * 7.0 + Vector3(0, 4.2, 0),
			f1[0] + f1[1] * 7.0 + Vector3(0, 4.2, 0),
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
						* Basis.from_scale(Vector3(1.1, 3.6, 1.1))
					),
					f0[0] - f0[1] * 7.3 + Vector3(0, 2.9, 0)
				)
			)
		# Floodlight rows every 2 m: on the rail atop the tiled wall and under the sea-side beam.
		for at in [[6.6, 4.95], [-6.7, 4.55]]:
			lamps.append(
				Transform3D(
					(
						Basis(f0[1], Vector3.UP, f0[1].cross(Vector3.UP))
						* Basis.from_scale(Vector3(0.45, 0.2, 0.8))
					),
					f0[0] + f0[1] * at[0] + Vector3(0, at[1], 0)
				)
			)
		if n % 8 == 0:
			var light = OmniLight3D.new()
			light.position = f0[0] + Vector3(0, 4.4, 0)
			light.light_color = Color(1.0, 0.86, 0.65)
			light.light_energy = 1.2
			light.omni_range = 16.0
			attach(asset, parent, light, "TunnelLight%d" % n)
		s = e
		n += 1
	# Portals: a solid face across both ends from the roof up 10 m (the hotel and hillside sit above), and a
	# cheek wall from the tiled wall out to the hill, so the approach never sees sky through the tunnel's top.
	for s_end in [span.x, span.y]:
		var f = _level_frame(c, s_end)
		var up = Vector3.UP
		_quad(
			ceiling,
			f[0] - f[1] * 12.0 + up * 5.4,
			f[0] + f[1] * 12.0 + up * 5.4,
			f[0] + f[1] * 12.0 + up * 15.4,
			f[0] - f[1] * 12.0 + up * 15.4,
			-12.0,
			12.0
		)
		_quad(
			ceiling,
			f[0] + f[1] * 7.0 - up * 0.3,
			f[0] + f[1] * 12.0 - up * 0.3,
			f[0] + f[1] * 12.0 + up * 5.4,
			f[0] + f[1] * 7.0 + up * 5.4,
			7.0,
			12.0
		)
	var concrete = StandardMaterial3D.new()
	concrete.albedo_texture = load("res://assets/textures/chicago/Concrete034/Concrete034_color.jpg")
	concrete.albedo_color = Color(0.82, 0.8, 0.76)
	concrete.uv1_triplanar = true
	concrete.uv1_scale = Vector3.ONE * 0.25
	concrete.roughness = 0.9
	for pair in [
		[walls, ChicagoCity.material("wall"), "Tunnel"],
		[tiles, _tile_material(), "TunnelTiles"],
		[ceiling, concrete, "TunnelCeiling"]
	]:
		pair[0].generate_normals()
		var node = MeshInstance3D.new()
		node.mesh = pair[0].commit()
		node.material_override = pair[1]
		attach(asset, parent, node, pair[2])
	var lamp_mat = StandardMaterial3D.new()
	lamp_mat.albedo_color = Color(1, 0.97, 0.9)
	lamp_mat.emission_enabled = true
	lamp_mat.emission = Color(1.0, 0.88, 0.66)
	lamp_mat.emission_energy_multiplier = 2.2
	for batch in [[pillars, ChicagoCity.material("wall"), "TunnelPillars"], [lamps, lamp_mat, "TunnelLamps"]]:
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
		c.sample_baked(minf(s + 0.5, c.get_baked_length()), true) - c.sample_baked(maxf(s - 0.5, 0.0), true)
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


## A Poly Haven 1K set from assets/textures/monaco/<id>/ (albedo, OpenGL normal, roughness), UVs scaled.
static func _pbr(id: String, scale: float, tint := Color.WHITE) -> StandardMaterial3D:
	var dir = "res://assets/textures/monaco/%s/%s_" % [id, id]
	var mat = StandardMaterial3D.new()
	mat.albedo_texture = load(dir + "diff_1k.jpg")
	mat.albedo_color = tint
	mat.normal_enabled = true
	mat.normal_texture = load(dir + "nor_gl_1k.jpg")
	mat.roughness_texture = load(dir + "rough_1k.jpg")
	mat.uv1_scale = Vector3(scale, scale, 1.0)
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return mat


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
