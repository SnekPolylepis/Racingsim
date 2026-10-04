extends RefCounted
## The real downtown Chicago around the CHI-01 circuit (CHI-02), from OpenStreetMap
## (trackgen/data/chicago/city.json, written by build_city.py). Presentation only: nothing here collides or
## is driven on. The circuit's barriers keep the car on the route, so every other street is visible
## but not drivable.
##   Buildings  measured LiDAR roof cells and OSM footprints/parts, plus sourced landmark overrides;
##              class facade shaders light windows at night
##   Streets    every road as an asphalt carriageway on a concrete sidewalk ribbon, cut back where it meets
##              or runs along the circuit so the circuit's own surface shows
##   Ground     street-level concrete everywhere else, left open over water and over the circuit's lower
##              (Lower Wacker) and ramp sections
##   Water      separate measured river and authored lakefront levels, with concrete river walls
##   Parks      parks, gardens and lawns in grass
## Geometry is batched per 600 m chunk and material, so the whole city is a few hundred draw calls at most.
const ChicagoKit = preload("res://trackgen/chicago_kit.gd")
const ChicagoWindows = preload("res://trackgen/chicago_windows.gd")
const PropMesh = preload("res://scripts/track/prop_mesh.gd")
const ChicagoCrowns = preload("res://trackgen/chicago_crowns.gd")
const ChicagoL = preload("res://trackgen/chicago_l.gd")
const RoadScatter = preload("res://scripts/track/road_scatter.gd")
const ChicagoHarbor = preload("res://trackgen/chicago_harbor.gd")
const Ps2Materials = preload("res://scripts/track/ps2_materials.gd")
const FACADE_SHADER = preload("res://shaders/chicago_facade.gdshader")
const DATA = "res://trackgen/data/chicago/city.json"
const TEX = "res://assets/textures/chicago/"
const STREET_Y = 8.0
## Chicago River surface: USGS LiDAR puts it ~5.9 m below Upper Wacker (street here at STREET_Y).
const WATER_Y = 2.1
## Lake Michigan and its harbours sit just below the lakefront (the Chicago Harbor Lock separates them from
## the river). At the river's WATER_Y, 10.8 m under the street, the lake was hidden in a pit and Lake
## Shore Drive looked out over a bare concrete plain.
const LAKE_Y = 6.5
## CDOT section: 13 in slab + 2 in overlay above 13 ft 9 in clear space, upper road at y 8.
const LOW_ROAD_Y = 3.4288
const LOW_FLOOR_Y = LOW_ROAD_Y - .08
## Candidate tiles for exact shoreline clipping; this does not assign a land cover.
const SHORE_CLIP_M = 150.0
const CHUNK = 600.0
## The route's half width plus verge: streets and buildings keep this far (plus their own margin) from it.
const ROUTE_CLEAR = 9.5
## Facade set, tint and glassiness per building class (build_city.py kind_of()).
## [texture set, tint, glassiness, metres per texture repeat]: real brick repeats every couple of metres,
## a curtain-wall panel set every several.
const ARRAY = "res://assets/chicago/facade-array/"
const KIND_ORDER = ["glass", "glass2", "stone", "terracotta", "brick", "concrete"]
const KINDS = {
	"glass": ["Facade001", Color(0.95, 0.98, 1.0), 1.0, 7.5],
	"glass2": ["Facade009", Color(1.0, 1.0, 1.0), 1.0, 7.5],
	"stone": ["Travertine009", Color(1.0, 0.97, 0.92), 0.0, 2.5],
	"terracotta": ["GlazedTerracotta001", Color(1.0, 0.96, 0.9), 0.0, 2.5],
	"brick": ["Bricks097", Color(0.95, 0.9, 0.88), 0.0, 1.8],
	"concrete": ["Concrete034", Color(0.92, 0.92, 0.9), 0.0, 3.5],
}
## CHI-01 models these landmarks itself: OSM outlines within this distance (m) of them are left out.
## Mapped Tribune Tower footprint w150407241 (route-inventory.csv), not the old eastward POI pin.
const TRIBUNE_POSITION = Vector3(67.1, STREET_Y, -632.6)
## Historic north tower; the OSM compound centroid also includes two later wings.
const BOARD_POSITION = Vector3(-653, STREET_Y, 788)
## 35 East Wacker mapped footprint w124865488, north face slightly angled along Wacker.
const JEWELERS_POSITION = Vector3(-198.2, STREET_Y, -192.35)
const JEWELERS_YAW = .006
## Mapped Pendry / Carbide and Carbon footprint w148544831.
const CARBIDE_POSITION = Vector3(-50.4, STREET_Y, -192.2)
const CARBIDE_YAW = .0114
## Historic Reliance / 1 West Washington, not the larger neighboring OSM alias.
const RELIANCE_POSITION = Vector3(-317.6, STREET_Y, 195.65)
const RELIANCE_YAW = .0074
## Full historic Monadnock block, mapped w73671128.
const MONADNOCK_POSITION = Vector3(-426.9, STREET_Y, 808.275)
const MONADNOCK_YAW = .0246
const WACKER_191_POSITION = Vector3(-1001.2, STREET_Y, -63.55)
const WACKER_191_YAW = .0202
const OWN_LANDMARKS = {
	"Willis Tower": 55.0, "Wrigley Building": 35.0, "Tribune Tower": 35.0, "Chicago Board of Trade": 35.0
}
const AUTHORED_BUILDINGS = {
	"w124873919": ["ChicagoTheatre", "chicago_theatre"],
	"w124873930": ["PageBrothers", "page_brothers"],
	"r15899437": ["CulturalCenter", "cultural_center"],
	"w124873931": ["RailwayExchange", "railway_exchange"],
	"w147476152": ["AthleticAssociation", "athletic_association"],
	"w126982632": ["UniversityClub", "university_club"],
	"w145493030": ["OrchestraHall", "orchestra_hall"],
}

## Blender model origin for mapped Wrigley blocks, OSM relation r17460539.
const WRIGLEY_POSITION = Vector3(-40, STREET_Y, -530)

## Buildings under this height, and flat surfaces, are culled beyond these distances (m); fog ends at 1900-2800.
const LOW_BUILDING_M = 40.0
const LOW_RANGE_M = 900.0
const FLAT_RANGE_M = 2400.0

static var _mats = {}


static func build(asset: Node3D, parent: Node, road, landmarks: Dictionary, world_of: Callable) -> Dictionary:
	var doc = JSON.parse_string(FileAccess.get_file_as_string(DATA))
	if not doc is Dictionary:
		push_warning("Chicago city data missing: " + DATA)
		return {}
	var route = _route_index(road)
	var wheel = world_of.call(landmarks["Navy Pier"])
	var wheel_plaza = PackedVector2Array(
		[
			Vector2(wheel.x - 32, wheel.z - 45),
			Vector2(wheel.x + 32, wheel.z - 45),
			Vector2(wheel.x + 32, wheel.z + 45),
			Vector2(wheel.x - 32, wheel.z + 45)
		]
	)
	var skip_at = []
	for name in OWN_LANDMARKS:
		if landmarks.has(name):
			var p = world_of.call(landmarks[name])
			if name == "Wrigley Building":
				p = WRIGLEY_POSITION
			elif name == "Tribune Tower":
				p = TRIBUNE_POSITION
			elif name == "Chicago Board of Trade":
				p = BOARD_POSITION
			skip_at.append([Vector2(p.x, p.z), OWN_LANDMARKS[name]])
	var chunks = {}
	# LOD (CHI-LOOK-01): low buildings and flat ground/street surfaces go to their own chunk sets with a
	# visibility range; towers stay in `chunks` so the skyline reaches the fog.
	var low_chunks = {}
	var flat_chunks = {}
	var stats = {"buildings": 0, "roads": 0, "ground_tiles": 0, "water": 0, "parks": 0, "excluded": []}
	var holder = Node3D.new()
	holder.name = "City"
	parent.add_child(holder)
	holder.owner = asset
	# Buildings.
	var crowns = []
	var i = 0
	for b in doc.buildings:
		var ring = _ring(b.f)
		# Facade bands (landmarks.json) share the building's footprint; 0.25 m proud so the walls don't fight.
		if b.has("band"):
			var bc = _centroid(ring)
			for j in ring.size():
				ring[j] += (ring[j] - bc).normalized() * 0.25
		i += 1
		var exclusion = ""
		if ring.size() < 3:
			exclusion = "invalid footprint"
		elif b.get("o", "") == "w147013355":
			exclusion = "authored 191 North Wacker exterior"
		elif b.get("o", "") == "w73671128":
			exclusion = "authored Monadnock exterior"
		elif b.get("o", "") == "w124865461":
			exclusion = "authored Reliance exterior"
		elif b.get("o", "") == "w148544831":
			exclusion = "authored Carbide and Carbon exterior"
		elif b.get("o", "") == "w124865488":
			exclusion = "authored Jewelers exterior"
		elif b.get("o", "") == "w28951633":
			exclusion = "authored Board of Trade exterior"
		elif b.get("o", "") == "r17460539":
			exclusion = "authored Wrigley exterior"
		# Authored exteriors have checked overhangs; retain 1 m beyond the 8 m carriageway.
		elif _touches_route(route, ring, -.5 if AUTHORED_BUILDINGS.has(b.get("o", "")) else 0.0):
			exclusion = "authored route clearance"
		elif _near_any(skip_at, _centroid(ring)):
			exclusion = "separate landmark proximity"
		if not exclusion.is_empty():
			stats.excluded.append({"city_index": i - 1, "osm_id": b.get("o", ""), "reason": exclusion})
			continue
		# The authored wheel/loading plaza replaces mapped low halls across this footprint.
		# Centroid-only landmark filtering misses long halls that extend beneath the wheel.
		if not Geometry2D.intersect_polygons(ring, wheel_plaza).is_empty():
			continue
		if AUTHORED_BUILDINGS.has(b.get("o", "")):
			var authored: Array = AUTHORED_BUILDINGS[b.o]
			var wall = ChicagoCrowns.exterior_wall(ring, b.ph)
			var along: Vector2 = (wall[1] - wall[0]).normalized()
			var outward: Vector2 = wall[2]
			var theatre = MeshInstance3D.new()
			theatre.name = authored[0]
			theatre.mesh = (
				PropMesh
				. mesh("res://assets/chicago/buildings/chicago_theatre/%s.glb" % authored[1])
				. duplicate()
			)
			for surface in theatre.mesh.get_surface_count():
				var mat = theatre.mesh.surface_get_material(surface)
				if mat is StandardMaterial3D and mat.resource_name.begins_with("Night"):
					mat = mat.duplicate()
					mat.set_meta("chicago_night", true)
					mat.emission_enabled = false
					theatre.mesh.surface_set_material(surface, mat)
			var center: Vector2 = (wall[0] + wall[1]) * .5
			theatre.transform = Transform3D(
				Basis(Vector3(along.x, 0, along.y), Vector3.UP, Vector3(outward.x, 0, outward.y)),
				Vector3(center.x, STREET_Y, center.y)
			)
			holder.add_child(theatre)
			theatre.owner = asset
			stats.buildings += 1
			continue
		var kind = str(b.k) if KINDS.has(str(b.k)) else "concrete"
		var target = low_chunks if float(b.h) < LOW_BUILDING_M else chunks
		var facade = _st(
			target,
			_centroid(ring),
			"glassblock" if b.has("gl") else ("pavilion" if b.has("pk") else "facade")
		)
		# Real OSM data: building:part base height ("m") and facade colour ("c") where tagged.
		var bottom = STREET_Y + float(b.m) if b.has("m") else 0.0
		var tint = Color(str(b.c)) if b.has("c") else Color(0, 0, 0, 0)
		if b.has("plan"):
			_plan_building(facade, ring, b.plan, kind_layer(kind), tint)
		elif b.has("L"):
			_lidar_building(facade, b.L, fmod(i * 0.6180339, 1.0), kind_layer(kind), tint, ring)
		else:
			_building(
				facade, facade, ring, float(b.h), fmod(i * 0.6180339, 1.0), bottom, kind_layer(kind), tint
			)
		if b.has("cr"):
			crowns.append([ring, STREET_Y + float(b.h), b.cr])
		stats.buildings += 1
	# Building details must come from mapped/cited overrides. Hash-selected kit
	# cornices and roof props float over stepped roofs and invent architecture.
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
			_flat(_st(flat_chunks, _centroid(ring), "water"), ring, wy)
			_walls(_st(flat_chunks, _centroid(ring), "wall"), ring, wy - 0.4, STREET_Y - 0.04)
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
			_flat(_st(flat_chunks, _centroid(ring), "park"), ring, STREET_Y + 0.02)
			stats.parks += 1
	# Street-level ground, in 20 m tiles, open over water and around the circuit's lower level and ramps.
	var lo = Vector2(INF, INF)
	var hi = Vector2(-INF, -INF)
	for b in doc.buildings:
		for p in b.f:
			lo = lo.min(Vector2(p[0], p[1]))
			hi = hi.max(Vector2(p[0], p[1]))
	var tile = 20.0
	var shore = _lakefront_cells(water_polys, tile, SHORE_CLIP_M)
	var water_cells = {}
	var low_cells = {}
	var x = floorf(lo.x / tile) * tile
	while x < hi.x:
		var z = floorf(lo.y / tile) * tile
		while z < hi.y:
			var c = Vector2(x + tile * 0.5, z + tile * 0.5)
			var cell = Vector2i(floori(c.x / tile), floori(c.y / tile))
			if _in_water(water_polys, c) and not shore.has(cell):
				water_cells[cell] = true
			elif _near_low_route(route, c, 26.0):
				low_cells[cell] = true
			else:
				var pieces = [
					PackedVector2Array(
						[
							Vector2(x, z),
							Vector2(x + tile, z),
							Vector2(x + tile, z + tile),
							Vector2(x, z + tile)
						]
					)
				]
				if shore.has(cell):
					# Clip shore tiles even when their centres are water: land corners still exist.
					for water in water_polys:
						var remaining = []
						for piece in pieces:
							remaining.append_array(Geometry2D.clip_polygons(piece, water))
						pieces = remaining
				for piece in pieces:
					_flat(_st(flat_chunks, c, "ground"), piece, STREET_Y - 0.04)
					# A thin overlay follows the actual park polygon, not a tile-centre classification.
					for park in crossed_parks:
						for lawn in Geometry2D.intersect_polygons(piece, park):
							_flat(_st(flat_chunks, c, "park"), lawn, STREET_Y - 0.035)
				if not pieces.is_empty():
					stats.ground_tiles += 1
			z += tile
		x += tile
	# LOOK-13: the lower-level cut (Lower Wacker and its portal ramps) was a hole in the street down to CityBase
	# at y -3, with the street tiles' raw edge floating above the lower road. It is now a trench: a floor at
	# the lower level and retaining walls up to the street wherever it meets street-level ground.
	for cell in low_cells:
		var at = Vector2(cell.x * tile, cell.y * tile)
		var mid = at + Vector2(tile, tile) * 0.5
		_quad_flat(_st(flat_chunks, mid, "ground"), at, tile, LOW_FLOOR_Y)
		var sides = [
			[Vector2i(1, 0), Vector2(tile, 0), Vector2(tile, tile)],
			[Vector2i(-1, 0), Vector2(0, tile), Vector2(0, 0)],
			[Vector2i(0, 1), Vector2(tile, tile), Vector2(0, tile)],
			[Vector2i(0, -1), Vector2(0, 0), Vector2(tile, 0)]
		]
		for side in sides:
			var next = cell + side[0]
			if low_cells.has(next):
				continue
			var a = at + side[1]
			var b = at + side[2]
			# A two-point ring gives both faces (a->b, then b->a).
			_walls(_st(chunks, mid, "wall"), PackedVector2Array([a, b]), LOW_FLOOR_Y, STREET_Y - 0.04)
	# Footpaths must be populated before chunk meshes commit, and sit above the park surface.
	# Clip short pieces near the course so a park path cannot paint over the racing asphalt.
	for pth in doc.get("paths", []):
		var pts = _ring(pth.p)
		for k in pts.size() - 1:
			var segments = maxi(1, ceili(pts[k].distance_to(pts[k + 1]) / 3.0))
			for j in segments:
				var a = pts[k].lerp(pts[k + 1], float(j) / segments)
				var b = pts[k].lerp(pts[k + 1], float(j + 1) / segments)
				var clear = ROUTE_CLEAR + float(pth.w) * .5 + 2.0
				if a.distance_to(b) < .05 or _route_dist(route, (a + b) * .5, clear) < clear:
					continue
				var side = (b - a).orthogonal().normalized() * float(pth.w) * .5
				var surface = str(pth.get("surface", ""))
				var kind = (
					"pavilion"
					if surface.begins_with("concrete")
					else (
						"road"
						if surface == "asphalt"
						else ("sidewalk" if surface == "paving_stones" else "path")
					)
				)
				var st = _st(flat_chunks, a, kind)
				for v in [a - side, a + side, b + side, a - side, b + side, b - side]:
					st.set_normal(Vector3.UP)
					st.set_uv(v)
					st.add_vertex(Vector3(v.x, STREET_Y + .04, v.y))
	# Commit every chunk's surfaces.
	var window_walls = {}
	var window_coverage = {}
	for group in [
		[chunks, 0.0, "Chunk"], [low_chunks, LOW_RANGE_M, "Low"], [flat_chunks, FLAT_RANGE_M, "Flat"]
	]:
		for key in group[0]:
			var mesh = ArrayMesh.new()
			for mat_name in group[0][key]:
				var st: SurfaceTool = group[0][key][mat_name]
				var arrays = st.commit_to_arrays()
				if mat_name == "facade":
					ChicagoWindows.collect(arrays, route, window_walls, window_coverage)
				mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
				mesh.surface_set_material(mesh.get_surface_count() - 1, material(mat_name))
			var node = MeshInstance3D.new()
			node.name = "%s_%d_%d" % [group[2], key.x, key.y]
			node.mesh = mesh
			node.visibility_range_end = group[1]
			# Flat streets and ground cast nothing (CHI-LOOK-02): they only cost shadow-pass draws.
			node.cast_shadow = (
				GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				if group[2] == "Flat"
				else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			)
			holder.add_child(node)
			node.owner = asset
	stats["physical_windows"] = ChicagoWindows.build(asset, holder, window_walls)
	_trees(asset, holder, doc.get("trees", []), route, world_of.call(landmarks["Bean"]))
	stats.merge(ChicagoHarbor.build(asset, holder, doc))
	ChicagoCrowns.build(asset, holder, crowns)
	stats["l_trains"] = ChicagoL.build(asset, holder, doc.get("elevated", []), doc.get("l_lines", []))
	stats["crowns"] = crowns.size()
	return stats


## Layer of a facade kind in the texture array (the order of KIND_ORDER).
static func kind_layer(kind: String) -> float:
	return float(maxi(0, KIND_ORDER.find(kind)))


static func material(name: String) -> Material:
	if KINDS.has(name):
		name = "facade"
	if _mats.has(name):
		return _mats[name]
	var mat: Material
	if name == "facade":
		var sm = ShaderMaterial.new()
		sm.shader = FACADE_SHADER
		sm.set_shader_parameter("albedo_tex", load(ARRAY + "albedo.png"))
		sm.set_shader_parameter("normal_tex", load(ARRAY + "normal.png"))
		sm.set_shader_parameter("rough_tex", load(ARRAY + "rough.png"))
		var tints = PackedVector3Array()
		var glassy = PackedFloat32Array()
		var tiles = PackedFloat32Array()
		for kind in KIND_ORDER:
			var k = KINDS[kind]
			tints.append(Vector3(k[1].r, k[1].g, k[1].b))
			glassy.append(k[2])
			tiles.append(k[3])
		sm.set_shader_parameter("kind_tint", tints)
		sm.set_shader_parameter("kind_glassy", glassy)
		sm.set_shader_parameter("kind_tile", tiles)
		mat = sm
	elif name == "roof":
		mat = _plain(Color(0.24, 0.25, 0.26), 0.9)
	elif name == "pavilion":
		# Park structures (pavilions, kiosks, fountain housings): pale stone, no office window grid.
		mat = _triplanar(TEX + "Concrete034/Concrete034_color.jpg", 3.0, Color(0.86, 0.85, 0.82))
	elif name == "glassblock":
		# Crown Fountain: glass brick lit from within; the LED faces glow at night (chicago_night).
		# Owner: plain blue, no faces; glows day and night.
		var gb = _plain(Color(0.25, 0.5, 0.95), 0.2)
		gb.emission_enabled = true
		gb.emission = Color(0.2, 0.45, 1.0)
		gb.emission_energy_multiplier = 1.8
		mat = gb
	elif name == "path":
		mat = _triplanar(TEX + "Granite002A/Granite002A_color.jpg", 2.0, Color(0.9, 0.88, 0.84))
	elif name == "road":
		var road = StandardMaterial3D.new()
		road.albedo_texture = load("res://assets/chicago/surfaces/worn_asphalt/worn_asphalt_diff_1k.jpg")
		road.normal_enabled = true
		road.normal_texture = load("res://assets/chicago/surfaces/worn_asphalt/worn_asphalt_nor_gl_1k.jpg")
		road.roughness_texture = load("res://assets/chicago/surfaces/worn_asphalt/worn_asphalt_rough_1k.jpg")
		road.uv1_triplanar = true
		road.uv1_world_triplanar = true
		road.uv1_scale = Vector3.ONE / 4.0
		road.albedo_color = Color(0.74, 0.74, 0.76)
		road.roughness = 0.9
		road.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		mat = road
	elif name == "sidewalk":
		var pavement = StandardMaterial3D.new()
		pavement.albedo_texture = load("res://assets/chicago/surfaces/pavement_05/pavement_05_diff_1k.jpg")
		pavement.normal_enabled = true
		pavement.normal_texture = load("res://assets/chicago/surfaces/pavement_05/pavement_05_nor_gl_1k.jpg")
		pavement.roughness_texture = load(
			"res://assets/chicago/surfaces/pavement_05/pavement_05_rough_1k.jpg"
		)
		pavement.uv1_triplanar = true
		pavement.uv1_world_triplanar = true
		pavement.uv1_scale = Vector3.ONE / 3.0
		pavement.albedo_color = Color(0.78, 0.77, 0.74)
		pavement.roughness = 0.9
		pavement.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		mat = pavement
	elif name == "ground":
		var pavement_ground = StandardMaterial3D.new()
		pavement_ground.albedo_texture = load(
			"res://assets/chicago/surfaces/pavement_05/pavement_05_diff_1k.jpg"
		)
		pavement_ground.normal_enabled = true
		pavement_ground.normal_texture = load(
			"res://assets/chicago/surfaces/pavement_05/pavement_05_nor_gl_1k.jpg"
		)
		pavement_ground.roughness_texture = load(
			"res://assets/chicago/surfaces/pavement_05/pavement_05_rough_1k.jpg"
		)
		pavement_ground.uv1_triplanar = true
		pavement_ground.uv1_world_triplanar = true
		pavement_ground.uv1_scale = Vector3.ONE / 3.0
		pavement_ground.albedo_color = Color(0.44, 0.45, 0.46)
		pavement_ground.roughness = 0.95
		pavement_ground.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		mat = pavement_ground
	elif name == "wall":
		# CHI-SC-2: poured-concrete retaining/river walls (panels, coping, grime, streaks), not a flat tint.
		var wall = ShaderMaterial.new()
		wall.shader = preload("res://shaders/chicago_wall.gdshader")
		wall.set_shader_parameter("concrete_tex", load(TEX + "Concrete034/Concrete034_color.jpg"))
		wall.set_shader_parameter("street_y", STREET_Y)
		mat = wall
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
				# Clear street-level tiles over the entire ramp, including its last metre of rise.
				if low_only and q.y >= STREET_Y - .02:
					continue
				best = minf(best, p.distance_to(Vector2(q.x, q.z)))
	return best


static func _touches_route(route: Dictionary, ring: PackedVector2Array, margin: float) -> bool:
	# CHI-SC-4: walk every edge (at most 3 m apart), not just the corners. A footprint with a long wall across
	# the route but corners far from it passed, and the building stood in the track.
	var reach = ROUTE_CLEAR + margin
	for i in ring.size():
		var a = ring[i]
		var b = ring[(i + 1) % ring.size()]
		var n = maxi(1, ceili(a.distance_to(b) / 3.0))
		for k in n:
			if _route_dist(route, a.lerp(b, float(k) / n), reach) < reach:
				return true
	# A nearby building centroid does not mean the road is inside the footprint.
	# Check actual route samples in the footprint's indexed bounding cells instead.
	var bounds = Rect2(ring[0], Vector2.ZERO)
	for p in ring:
		bounds = bounds.expand(p)
	for x in range(floori(bounds.position.x / 25.0), floori(bounds.end.x / 25.0) + 1):
		for z in range(floori(bounds.position.y / 25.0), floori(bounds.end.y / 25.0) + 1):
			for q in route.get(Vector2i(x, z), []):
				if Geometry2D.is_point_in_polygon(Vector2(q.x, q.z), ring):
					return true
	return false


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
	walls: SurfaceTool,
	roof: SurfaceTool,
	ring: PackedVector2Array,
	h: float,
	seed: float,
	bottom: float = 0.0,
	layer: float = 0.0,
	tint: Color = Color(0, 0, 0, 0)
) -> void:
	var top = STREET_Y + h
	var c = _centroid(ring)
	var u = 0.0
	# UV2 carries sourced red/green; colour alpha carries blue. Wall blue=.25
	# distinguishes tagged facades from untagged walls (0) and roofs (1).
	walls.set_uv2(Vector2(tint.r, tint.g))
	walls.set_color(Color(seed, layer / 8.0, .25 if tint.a > 0.0 else 0.0, tint.b))
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
			[Vector3(a.x, bottom, a.y), Vector2(u, bottom - STREET_Y)],
			[Vector3(b.x, bottom, b.y), Vector2(u + seg_len, bottom - STREET_Y)],
			[Vector3(b.x, top, b.y), Vector2(u + seg_len, h)],
			[Vector3(a.x, top, a.y), Vector2(u, h)],
		]
		for idx in [0, 1, 2, 0, 2, 3]:
			walls.set_normal(n)
			walls.set_uv(v[idx][1])
			walls.add_vertex(v[idx][0])
		u += seg_len
	# Roofs share the facade surface; blue = 1 selects the flat roof colour in the shader.
	roof.set_color(Color(0, 0, 1))
	_flat(roof, ring, top)


## Approved-plan parts in metres, relative to the mapped footprint centre.
## Parts use [x, z, width, depth, bottom, top]; surfaces use local XYZ vertices.
static func _plan_building(
	st: SurfaceTool, footprint: PackedVector2Array, plan: Dictionary, layer: float, tint: Color
) -> void:
	var origin = _centroid(footprint)
	for part in plan.parts:
		var a = origin + Vector2(part[0], part[1])
		var ring = PackedVector2Array(
			[a, a + Vector2(part[2], 0), a + Vector2(part[2], part[3]), a + Vector2(0, part[3])]
		)
		_building(st, st, ring, part[5], 0.0, STREET_Y + part[4], layer, tint)
	st.set_color(Color(0, 0, 1))
	for surface in plan.surfaces:
		var vertices = PackedVector3Array()
		var outline = PackedVector2Array()
		for p in surface:
			vertices.append(Vector3(origin.x + p[0], STREET_Y + p[1], origin.y + p[2]))
			outline.append(Vector2(p[0], p[2]))
		var indices = Geometry2D.triangulate_polygon(outline)
		# Both sides: the balcony deck is also the covered breezeway's ceiling.
		for side in [false, true]:
			for j in range(0, indices.size(), 3):
				var triangle = [vertices[indices[j]], vertices[indices[j + 1]], vertices[indices[j + 2]]]
				if side:
					triangle.reverse()
				st.set_normal((triangle[1] - triangle[0]).cross(triangle[2] - triangle[0]).normalized())
				for vertex in triangle:
					st.set_uv(Vector2(vertex.x, vertex.z))
					st.add_vertex(vertex)


## A building from its measured USGS LiDAR roof: [x0, z0, w, h, cell, base64 u16 decimetres], row-major
## over its footprint (0 = outside). Roof runs of equal height become one quad; walls step down to each
## lower neighbour. UVs are world metres along the wall and height, so the window grid lines up.
static func _lidar_building(
	st: SurfaceTool,
	grid: Array,
	seed: float,
	layer: float,
	tint: Color,
	ring: PackedVector2Array = PackedVector2Array()
) -> void:
	var x0 = float(grid[0])
	var z0 = float(grid[1])
	var w = int(grid[2])
	var h = int(grid[3])
	var c = float(grid[4])
	var raw = Marshalls.base64_to_raw(str(grid[5]))
	var hgt = PackedFloat32Array()
	hgt.resize(w * h)
	for k in w * h:
		hgt[k] = raw.decode_u16(k * 2) * 0.1
	var at = func(i: int, j: int) -> float:
		return hgt[j * w + i] if i >= 0 and j >= 0 and i < w and j < h else 0.0
	st.set_uv2(Vector2(tint.r, tint.g))
	var wall_color = Color(seed, layer / 8.0, .25 if tint.a > 0.0 else 0.0, tint.b)
	if not ring.is_empty():
		_lidar_footprint(st, ring, x0, z0, w, h, c, at, wall_color)
		return
	for j in h:
		var i = 0
		while i < w:
			var y = at.call(i, j)
			if y <= 0.0:
				i += 1
				continue
			var run = i
			while run + 1 < w and absf(at.call(run + 1, j) - y) < 0.05:
				run += 1
			var top = STREET_Y + y
			var ax = x0 + i * c
			var bx = x0 + (run + 1) * c
			var az = z0 + j * c
			var bz = az + c
			st.set_color(Color(0, 0, 1))
			for v in [
				Vector3(ax, top, az),
				Vector3(bx, top, az),
				Vector3(bx, top, bz),
				Vector3(ax, top, az),
				Vector3(bx, top, bz),
				Vector3(ax, top, bz)
			]:
				st.set_normal(Vector3.UP)
				st.set_uv(Vector2(v.x, v.z))
				st.add_vertex(v)
			st.set_color(wall_color)
			for k in range(i, run + 1):
				var cx = x0 + k * c
				# North (-z) and south (+z) faces per cell; west/east only at the run ends.
				_lidar_wall(
					st, Vector3(cx + c, 0, az), Vector3(cx, 0, az), Vector3(0, 0, -1), at.call(k, j - 1), y
				)
				_lidar_wall(
					st, Vector3(cx, 0, bz), Vector3(cx + c, 0, bz), Vector3(0, 0, 1), at.call(k, j + 1), y
				)
				if k == i or absf(at.call(k - 1, j) - y) >= 0.05:
					_lidar_wall(
						st,
						Vector3(cx, 0, az),
						Vector3(cx, 0, bz),
						Vector3(-1, 0, 0),
						at.call(k - 1, j),
						at.call(k, j)
					)
				if k == run or absf(at.call(k + 1, j) - y) >= 0.05:
					_lidar_wall(
						st,
						Vector3(cx + c, 0, bz),
						Vector3(cx + c, 0, az),
						Vector3(1, 0, 0),
						at.call(k + 1, j),
						at.call(k, j)
					)
			i = run + 1


## Clip measured cells to the mapped footprint, retaining every measured roof step.
## All measured exteriors follow mapped walls rather than an outward raster staircase.
static func _lidar_footprint(
	st: SurfaceTool,
	ring: PackedVector2Array,
	x0: float,
	z0: float,
	w: int,
	h: int,
	cell: float,
	at: Callable,
	wall_color: Color
) -> void:
	for j in h:
		for i in w:
			var height: float = at.call(i, j)
			if height <= 0.0:
				continue
			var a = Vector2(x0 + i * cell, z0 + j * cell)
			var square = PackedVector2Array(
				[a, a + Vector2(cell, 0), a + Vector2(cell, cell), a + Vector2(0, cell)]
			)
			for poly in Geometry2D.intersect_polygons(square, ring):
				st.set_color(Color(0, 0, 1))
				_flat(st, poly, STREET_Y + height)
				st.set_color(wall_color)
				var centre = _centroid(poly)
				for k in poly.size():
					var p: Vector2 = poly[k]
					var q: Vector2 = poly[(k + 1) % poly.size()]
					var normal = Vector2(q.y - p.y, p.x - q.x).normalized()
					var mid = (p + q) * .5
					if normal.dot(mid - centre) < 0:
						normal = -normal
					var outside = mid + normal * .01
					var lo = 0.0
					if Geometry2D.is_point_in_polygon(outside, ring):
						lo = at.call(floori((outside.x - x0) / cell), floori((outside.y - z0) / cell))
					_lidar_wall(
						st,
						Vector3(p.x, 0, p.y),
						Vector3(q.x, 0, q.y),
						Vector3(normal.x, 0, normal.y),
						lo,
						height
					)


static func _lidar_wall(st: SurfaceTool, a: Vector3, b: Vector3, n: Vector3, lo: float, hi: float) -> void:
	if hi <= lo + 0.05:
		return
	var along_a = a.x if absf(n.z) > 0.5 else a.z
	var along_b = b.x if absf(n.z) > 0.5 else b.z
	var y0 = STREET_Y + lo if lo > 0.0 else 0.0
	var y1 = STREET_Y + hi
	var v = [
		[Vector3(a.x, y0, a.z), Vector2(along_a, y0 - STREET_Y)],
		[Vector3(b.x, y0, b.z), Vector2(along_b, y0 - STREET_Y)],
		[Vector3(b.x, y1, b.z), Vector2(along_b, hi)],
		[Vector3(a.x, y1, a.z), Vector2(along_a, hi)],
	]
	for idx in [0, 1, 2, 0, 2, 3]:
		st.set_normal(n)
		st.set_uv(v[idx][1])
		st.add_vertex(v[idx][0])


## Real mapped trees (OSM natural=tree) within 350 m of the route, kept off the carriageway. Height from the
## LiDAR canopy where measured, else the broadleaf card's own range. Same photographic cards as RoadScatter.
static func _trees(asset: Node3D, holder: Node3D, trees: Array, route: Dictionary, bean: Vector3) -> void:
	var rng = RandomNumberGenerator.new()
	rng.seed = 60602
	var xforms = []
	var cards = []
	var tints = []
	var atlas = RoadScatter.cards_for(RoadScatter.AtlasKind.TREES)
	for t in trees:
		var p = Vector2(t[0], t[1])
		var d = _route_dist(route, p, 350.0)
		if d > 350.0 or d < 12.0:
			continue
		var pick = RoadScatter.pick_card(rng, RoadScatter.AtlasKind.TREES, PackedInt32Array([2, 3, 4]))
		var card = atlas[pick.card]
		var h = float(t[2]) if float(t[2]) > 0.0 else pick.height * 0.65
		var w = h * 1.15 * card[2] / card[3]
		var basis = Basis(Vector3.UP, rng.randf() * TAU) * Basis.from_scale(Vector3(w, h, w))
		# Cloud Gate is on a paved 70 x 60 m plaza: keep crowns, not only trunks, outside it.
		var crown = w * 0.71
		if d < 10.0 + crown:
			continue
		if absf(p.x - bean.x) < 35.0 + crown and absf(p.y - bean.z) < 30.0 + crown:
			continue
		# Short paved west entrance from Michigan Avenue to the plaza; retain trees either side.
		if p.x > 12.0 - crown and p.x < bean.x - 35.0 + crown and absf(p.y - bean.z) < 6.0 + crown:
			continue
		xforms.append(Transform3D(basis, Vector3(p.x, STREET_Y - 0.04, p.y)))
		cards.append(Color(card[0], card[1], card[2], card[3]))
		tints.append(pick.tint)
	var mm = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.use_custom_data = true
	mm.mesh = RoadScatter.card_mesh()
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
		mm.set_instance_custom_data(i, cards[i])
		mm.set_instance_color(i, tints[i])
	var node = MultiMeshInstance3D.new()
	node.name = "RealTrees"
	node.multimesh = mm
	node.material_override = RoadScatter.tree_material(RoadScatter.AtlasKind.TREES)
	holder.add_child(node)
	node.owner = asset


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
		st.set_uv(p[idx])
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
	# LOOK-19: pieces of at most 10 m, and none over the lower-level cut. Long segments were only tested at their
	# ends and middle, so streets crossing the Lower Wacker trench floated over it as street-level slabs.
	var pieces = []
	for i in pts.size() - 1:
		var n = maxi(1, ceili(pts[i].distance_to(pts[i + 1]) / 10.0))
		for k in n:
			pieces.append([pts[i].lerp(pts[i + 1], float(k) / n), pts[i].lerp(pts[i + 1], float(k + 1) / n)])
	for piece in pieces:
		var a: Vector2 = piece[0]
		var b: Vector2 = piece[1]
		var mid = (a + b) * 0.5
		# The ribbon's full half-width is the road plus a 3 m sidewalk; all of it must clear the circuit
		# (CHI-SC-4: wide streets overhung the track by several metres).
		var clear = ROUTE_CLEAR + 1.0 + w * 0.5 + 3.0
		if (
			_route_dist(route, mid, clear) < clear
			or _route_dist(route, a, clear) < clear
			or _route_dist(route, b, clear) < clear
			or _near_low_route(route, mid, 26.0 + w * 0.5)
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
		st.set_uv(p[idx])
		st.add_vertex(Vector3(p[idx].x, y, p[idx].y))
