extends SceneTree
## CHI-01. Authored race route on Chicago's geographic scaffold, with explicit game-only connectors.
## Source/provenance: trackgen/data/chicago/README.md. Heights and corner easing are authored.
const TrackAsset = preload("res://scripts/track/track_asset.gd")
const RoadPath = preload("res://scripts/track/road_path.gd")
const RoadScatter = preload("res://scripts/track/road_scatter.gd")
const RoadSection = preload("res://scripts/track/road_section.gd")
const WallPath = preload("res://scripts/track/wall_path.gd")
const TrackLights = preload("res://scripts/track/track_lights.gd")
const NightGlow = preload("res://scripts/track/night_glow.gd")
const Gantry = preload("res://scripts/track/gantry.gd")
const RoadBuilder = preload("res://scripts/track/road_builder.gd")
const ChicagoCity = preload("res://trackgen/chicago_city.gd")
const ChicagoFurniture = preload("res://trackgen/chicago_furniture.gd")
const ChicagoKit = preload("res://trackgen/chicago_kit.gd")
const PropMesh = preload("res://scripts/track/prop_mesh.gd")
const CatchFence = preload("res://scripts/track/catch_fence.gd")
## Kenney Car Kit (CC0) parked-car models, copied from the CHI-assets-prep staging (assets/chicago/cars).
const NO_SHADOW = [
	"CityBase",
	"LakeMichigan",
	"River",
	"MillenniumPark",
	"GrantPark",
	"Lakefront",
	"Riverwalk",
	"LaneMarkings",
	"CloudGatePlaza",
	"ChicagoBridgeDecks"
]
const PARKED = ["taxi", "taxi", "sedan", "sedan", "hatch", "suv", "police", "sports", "sports2"]
const GRID_DATA = "res://trackgen/data/chicago/route-grid.json"
const DATA = "res://trackgen/data/chicago/route.json"
## Named corners for the visual review: [route.json point index, name]. Stations are found on the road.
const CORNERS = [
	[2, "Jackson Turn"],
	[3, "Lakefront Turn"],
	[5, "Lake Shore Drive"],
	[8, "Navy Pier View"],
	[9, "Harbor Connector"],
	[11, "Lower Wacker Portal"],
	[14, "Michigan Crossing"],
	[17, "River Bend"],
	[20, "Wacker West Bend"],
	[23, "South Connector"],
	[26, "Upper Wacker Portal"],
	[27, "Willis Tower View"],
	[29, "Upper Wacker Bend"],
	[33, "Upper River Bend"],
	[36, "Michigan Turn"]
]
const HALF_WIDTH = 8.0
const WACKER_SOFFIT_Y = 7.6198
const WACKER_RIB_BOTTOM_Y = 7.3396
# Lateral column axes digitized from the CDOT 140 ft cross-section, relative to its SB through lane.
# Positive is east in that drawing; the southbound driver's right is west.
const WACKER_NS_COLUMNS = [-14.386, -4.63, 4.63, 8.915, 18.175, 25.525]
const CACHE_REVISION = 132
const TEXTURE_ROOT = "res://assets/textures/chicago/"
const WATER_SHADER = preload("res://shaders/chicago_water.gdshader")


static func data(grid: bool = false) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(GRID_DATA if grid else DATA))


static func world(row: Array) -> Vector3:
	# Local tangent plane, +X east / +Z south, in metres. No float32 world-state accumulation.
	return Vector3((row[1] + 87.6244) * 82860.0, row[2], (41.8848 - row[0]) * 111320.0)


static func points(grid: bool = false) -> Array[Vector3]:
	var out: Array[Vector3] = []
	for row in data(grid).points:
		out.append(world(row))
	return out


static func covered_wacker(p: Vector3) -> bool:
	return p.y <= ChicagoCity.LOW_ROAD_Y + .1 and p.z <= 720.0


static func route_curve(grid: bool = false) -> Curve3D:
	# Tangent-continuous fillets; 55 m setback on broad junctions, reduced on short blocks.
	var p = points(grid)
	var c = Curve3D.new()
	c.bake_interval = .25
	for i in p.size():
		var before = p[i] - p[posmod(i - 1, p.size())]
		var after = p[(i + 1) % p.size()] - p[i]
		var a = before.normalized()
		var b = after.normalized()
		var angle = acos(clampf(a.dot(b), -1.0, 1.0))
		var limit = 18.0 if grid and p[i].y > 7.0 and p[i].z > -250.0 else 55.0
		var cut = minf(limit, minf(before.length(), after.length()) * .3)
		var handle = cut * (4.0 / 3.0) * tan(angle / 4.0) / maxf(.00001, tan(angle / 2.0))
		if angle < .015:
			c.add_point(p[i])
		else:
			c.add_point(p[i] - a * cut, Vector3.ZERO, a * handle)
			c.add_point(p[i] + b * cut, -b * handle, Vector3.ZERO)
	# Collinear straight segment handles preserve their exact shape and smooth interpolation.
	for i in c.point_count:
		var j = (i + 1) % c.point_count
		if c.get_point_out(i).is_zero_approx() and c.get_point_in(j).is_zero_approx():
			var delta = (c.get_point_position(j) - c.get_point_position(i)) / 3.0
			c.set_point_out(i, delta)
			c.set_point_in(j, -delta)
	return c


static func attach(asset: Node3D, parent: Node, node: Node, title: String) -> void:
	node.name = title
	parent.add_child(node)
	node.owner = asset


static func material(color: Color, unshaded: bool = false) -> StandardMaterial3D:
	var m = StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = .85
	if unshaded:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m


static func mesh_node(asset: Node3D, parent: Node, title: String, mesh: Mesh, pos: Vector3) -> MeshInstance3D:
	var n = MeshInstance3D.new()
	n.mesh = mesh
	n.position = pos
	attach(asset, parent, n, title)
	return n


static func box(
	asset: Node3D, parent: Node, title: String, pos: Vector3, size: Vector3, mat: Material
) -> MeshInstance3D:
	var m = BoxMesh.new()
	m.size = size
	m.material = mat
	return mesh_node(asset, parent, title, m, pos)


static func multimesh_boxes(
	asset: Node3D, parent: Node, title: String, mat: Material, entries: Array
) -> void:
	if entries.is_empty():
		return
	var mesh = BoxMesh.new()
	mesh.size = Vector3.ONE
	mesh.material = mat
	var instances = MultiMesh.new()
	instances.transform_format = MultiMesh.TRANSFORM_3D
	instances.mesh = mesh
	instances.instance_count = entries.size()
	for i in entries.size():
		var entry = entries[i]
		var basis: Basis = entry[2] if entry.size() > 2 else Basis.IDENTITY
		instances.set_instance_transform(i, Transform3D(basis * Basis.from_scale(entry[1]), entry[0]))
	var node = MultiMeshInstance3D.new()
	node.multimesh = instances
	attach(asset, parent, node, title)


static func solid_box(asset: Node3D, title: String, xform: Transform3D, size: Vector3) -> void:
	var body = StaticBody3D.new()
	body.collision_layer = 2
	body.collision_mask = 0
	body.transform = xform
	body.set_meta("wall_kind", "concrete")
	attach(asset, asset.get_node("Walls"), body, title)
	var col = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = size
	col.shape = shape
	attach(asset, body, col, "Shape")


static func build_asset(grid: bool = false) -> Node3D:
	var asset = TrackAsset.new()
	asset.name = "Chicago"
	asset.id = "chicago_grid" if grid else "chicago"
	asset.display_name = "Chicago — Loop Grid" if grid else "Chicago — River & Lake"
	asset.version = 1 if grid else 3
	asset.set_meta("wacker_floor_y", ChicagoCity.LOW_ROAD_Y)
	asset.default_time_of_day = "day"
	var road = RoadPath.new()
	road.name = "Main"
	road.curve = route_curve(grid)
	road.set_meta("loop_grid", grid)
	road.along_step = 1.5
	road.road_stations = 9
	road.grid_first_m = 35.0
	road.grid_spacing_m = 12.0
	road.grid_offset_m = 2.5
	road.sections.append(
		RoadSection.make(
			0.0,
			{
				"width_left": HALF_WIDTH,
				"width_right": HALF_WIDTH,
				"crown": 0.0,
				"kerb_left": RoadSection.Kerb.RAMP,
				"kerb_right": RoadSection.Kerb.RAMP,
				"kerb_width": .4,
				"kerb_height": .025,
				"verge_left": 1.0,
				"verge_right": 1.0,
				"verge_slope_deg": 0.0,
				"verge_surface": 4
			}
		)
	)
	# The N–S section's through-lane bay is 26 ft wide (CDOT 2012 section).
	var narrow_from = road.curve.get_closest_offset(world(data(grid).points[26 if grid else 19]))
	var narrow_to = road.curve.get_closest_offset(Vector3(-1035.75, ChicagoCity.LOW_ROAD_Y, 720))
	for key in [
		[narrow_from - 40.0, HALF_WIDTH],
		[narrow_from, 3.9624],
		[narrow_to, 3.9624],
		[narrow_to + 50.0, HALF_WIDTH]
	]:
		var section = road.sections[0].duplicate()
		section.at = key[0]
		section.width_left = key[1]
		section.width_right = key[1]
		if key[1] < 4.5:
			section.kerb_left = RoadSection.Kerb.NONE
			section.kerb_right = RoadSection.Kerb.NONE
			section.kerb_width = 0.0
			section.verge_left = 0.0
			section.verge_right = 0.0
		road.sections.append(section)
	attach(asset, asset, road, "Main")
	road.bake()
	var corners = {}
	if grid:
		for row in data(true).points:
			corners[row[3]] = road.curve.get_closest_offset(world(row))
		for alias in [
			[8, "Jackson Turn"],
			[11, "Lakefront Turn"],
			[12, "Lake Shore Drive"],
			[15, "Navy Pier View"],
			[16, "Harbor Connector"],
			[18, "Lower Wacker Portal"],
			[21, "Michigan Crossing"],
			[24, "River Bend"],
			[27, "Wacker West Bend"],
			[30, "South Connector"],
			[33, "Upper Wacker Portal"],
			[34, "Willis Tower View"],
			[42, "Upper River Bend"],
			[45, "Michigan Turn"]
		]:
			corners[alias[1]] = road.curve.get_closest_offset(world(data(true).points[alias[0]]))
	else:
		for corner in CORNERS:
			corners[corner[1]] = road.curve.get_closest_offset(world(data().points[corner[0]]))
	asset.set_meta("corners", corners)
	var timing = asset.get_node("TimingLine")
	timing.set_meta("sector_offsets", [road.last_bake.length / 3.0, road.last_bake.length * 2.0 / 3.0])
	var bot = Path3D.new()
	bot.curve = road.working_curve()
	attach(asset, asset, bot, "BotLine")
	for side in [WallPath.Side.LEFT, WallPath.Side.RIGHT]:
		var wall = WallPath.new()
		wall.follow_road = NodePath("../Main")
		wall.side = side
		wall.kind = 2
		wall.height = .65
		wall.offset = .1
		wall.step_m = 3.0
		attach(asset, asset, wall, "LeftBarrier" if side == WallPath.Side.LEFT else "RightBarrier")
		wall.bake()
	var scenery = Node3D.new()
	attach(asset, asset, scenery, "Scenery")
	# CHI-SC-1: debris fencing on top of both barriers, the look of a street circuit (Long Beach, Macau, NFSU's
	# closed-street courses); without it the route read as a grey blockout. Visual only (the barrier keeps
	# collision). Baked after Scenery exists: CatchFence parents its mesh under Scenery and would otherwise
	# create its own, renaming the city's node (and losing Scenery/CentennialWheel etc.).
	# Along Upper Wacker's riverfront the river is on the left: no debris fence there, so the river shows.
	var river = river_span(road)
	# Commons Randolph exit driver photo: concrete divider with an open service bay, no catch fence.
	var lower_from = INF
	var lower_to = 0.0
	for station in road.last_bake.stations:
		if covered_wacker(station.pos):
			lower_from = minf(lower_from, station.s)
			lower_to = maxf(lower_to, station.s)
	var fence_pieces = []
	for piece in [
		["LeftBarrier", 0.0, river.x],
		["LeftBarrier", river.y, road.last_bake.length],
		["RightBarrier", 0.0, road.last_bake.length]
	]:
		for open_span in [[0.0, lower_from], [lower_to, road.last_bake.length]]:
			var begin = maxf(piece[1], open_span[0])
			var end = minf(piece[2], open_span[1])
			if end > begin:
				fence_pieces.append([piece[0], begin, end])
	for piece in fence_pieces:
		var barrier = piece[0]
		var fence = CatchFence.new()
		# CatchFence's wall-following path ignores from/to; use the existing road-range path.
		fence.follow_road = NodePath("../Main")
		fence.side = WallPath.Side.LEFT if barrier == "LeftBarrier" else WallPath.Side.RIGHT
		fence.offset = asset.get_node(barrier).offset + asset.get_node(barrier).dimensions().y
		fence.post_spacing = 4.0
		fence.fence_height = 3.85
		fence.solid = false
		fence.from_m = piece[1]
		fence.to_m = piece[2]
		attach(asset, asset, fence, barrier + "Fence" + str(int(piece[1])))
		fence.bake()
	add_water_and_parks(asset, scenery)
	# CHI-02: the real downtown from OpenStreetMap (buildings, every street, water, parks) replaces the
	# procedural skyline. add_city() stays for reference but is no longer called.
	var city = ChicagoCity.build(asset, scenery, road, data().landmarks, world)
	asset.set_meta("city", city)
	add_landmarks(asset, scenery)
	add_river_bridges(asset, scenery)
	add_lower_deck(asset, scenery, road)
	add_road_details(asset, scenery, road)
	# CHI-LOOK-01: signals, crosswalks and stop lines at the cross streets.
	ChicagoFurniture.build(asset, scenery, road.last_bake.stations, facade_box, night_material, attach)
	ChicagoKit.sidewalk_props(asset, scenery, road.last_bake.stations)
	# Ground-like scenery casts no useful shadow; it only costs shadow-pass draws (CHI-LOOK-02).
	for node in scenery.get_children():
		for prefix in NO_SHADOW:
			if node is GeometryInstance3D and str(node.name).begins_with(prefix):
				node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Trees are the real mapped ones (ChicagoCity._trees); the old random park/lakefront bands are gone.
	# Prelim city dressing from the CHI-assets-prep CC0 staging: textured street walls and parked cars.
	add_parked_cars(asset, scenery, road)
	# Headless and windowed scenes have distinct caches (TrackDrive). No runtime downloads.
	var lamps = TrackLights.place(road, 42.0, lower_level_zones(road), 1.2)
	var lamp_frame = road_frame(road)
	var lamp_curve: Curve3D = lamp_frame[0]
	# Mast clearance rejects stacked roads correctly; ceiling fixtures need their own covered-road walk.
	lamps = lamps.filter(func(lamp): return not covered_wacker(lamp.base))
	var lamp_s = 0.0
	while lamp_s < lamp_curve.get_baked_length():
		var at = RoadBuilder.station_at(
			lamp_curve, road.closed, lamp_curve.get_baked_length(), lamp_frame[2], lamp_s
		)
		if covered_wacker(at.pos):
			var basis = Basis.looking_at(at.tangent, Vector3.UP)
			for side in [-1, 1]:
				var base = at.pos + basis.x * side * 3.2
				base.y = WACKER_SOFFIT_Y + .06
				lamps.append(
					{
						"s": lamp_s,
						"side": side,
						"base": base,
						"basis": basis,
						"head": base - Vector3.UP * .18,
						"height": 0.0,
						"kind": "ceiling",
						"glow": true,
						"strength": .4,
						"step": 16.0
					}
				)
		lamp_s += 16.0
	TrackLights.build(asset, road, lamps)
	add_night_details(asset, scenery, road, lamps)
	var gantry = Gantry.new()
	gantry.follow_road = NodePath("../Main")
	gantry.clearance_height = 6.0
	attach(asset, asset, gantry, "StartGantry")
	gantry.bake()
	var landmarks = Node3D.new()
	attach(asset, asset, landmarks, "Landmarks")
	for title in data().landmarks:
		var marker = Marker3D.new()
		marker.position = world(data().landmarks[title])
		attach(asset, landmarks, marker, title.replace(" ", ""))
	asset.set_meta(
		"route_description", "Michigan Avenue / Jackson / Lake Shore Drive / Lower Wacker / Upper Wacker"
	)
	return asset


static func pbr_texture_set(folder: String, stem: String, albedo_suffix: String) -> StandardMaterial3D:
	var mat = material(Color.WHITE)
	mat.albedo_texture = load(TEXTURE_ROOT + folder + "/" + stem + "_" + albedo_suffix + "_1k.jpg")
	mat.normal_enabled = true
	mat.normal_texture = load(TEXTURE_ROOT + folder + "/" + stem + "_nor_gl_1k.jpg")
	mat.roughness_texture = load(TEXTURE_ROOT + folder + "/" + stem + "_rough_1k.jpg")
	mat.uv1_scale = Vector3(5, 5, 1)
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	return mat


static func add_water_and_parks(asset: Node3D, parent: Node) -> void:
	var concrete = material(Color("686b68"))
	var lawn = material(Color("526744"))
	var water = ShaderMaterial.new()
	water.shader = WATER_SHADER
	var pier_walk = pbr_texture_set("large_square_pattern_01", "large_square_pattern_01", "diff")
	# World metres keep paving square across long, rotated promenade slabs.
	pier_walk.uv1_triplanar = true
	pier_walk.uv1_world_triplanar = true
	pier_walk.uv1_scale = Vector3.ONE * .5
	box(asset, parent, "CityBase", Vector3(-500, -3.8, 0), Vector3(4000, 1, 4000), concrete)
	# Open lake beyond city.json's clipped lake ring (x 2700), at the lake level in ChicagoCity.LAKE_Y.
	var lake = box(asset, parent, "LakeMichigan", Vector3(4600, 6.35, 0), Vector3(3900, .2, 6500), water)
	lake.material_override = water
	# River ribbon follows the main and south branches; 80 m wide, below both Wacker decks.
	var river = [
		[41.8893, -87.606, -3],
		[41.8893, -87.621, -3],
		[41.8890, -87.625, -3],
		[41.88765, -87.6275, -3],
		[41.88765, -87.6355, -3],
		[41.8863, -87.638, -3],
		[41.877, -87.6382, -3],
		[41.873, -87.636, -3]
	]
	for i in river.size() - 1:
		var a = world(river[i])
		var b = world(river[i + 1])
		var n = box(
			asset, parent, "River%d" % i, (a + b) * .5, Vector3(105, .2, a.distance_to(b) + 40), water
		)
		n.rotation.y = atan2(b.x - a.x, b.z - a.z)
		n.material_override = water
	box(asset, parent, "MillenniumPark", world([41.8821, -87.6226, 7.6]), Vector3(210, .6, 380), lawn)
	box(asset, parent, "GrantPark", world([41.8800, -87.6210, 7.3]), Vector3(440, .5, 260), lawn)
	box(asset, parent, "Lakefront", world([41.8800, -87.6166, 6.8]), Vector3(65, .5, 470), pier_walk)
	# Riverwalk follows the mapped south bank at river level, below Upper Wacker.
	# The old two floating rectangles sat below WATER_Y and never read as a promenade.
	var bank = [
		Vector3(-945.5, 2.65, -244.7),
		Vector3(-914.5, 2.65, -263.5),
		Vector3(-813.3, 2.65, -266.4),
		Vector3(-695.1, 2.65, -267.4),
		Vector3(-566.3, 2.65, -265.7),
		Vector3(-447.5, 2.65, -270.4),
		Vector3(-321.8, 2.65, -270.5),
		Vector3(-282.3, 2.65, -274.2)
	]
	var rails: Array = []
	var deck: Array = []
	var stone_cap: Array = []
	for i in bank.size() - 1:
		var a: Vector3 = bank[i]
		var b: Vector3 = bank[i + 1]
		var tangent = (b - a).normalized()
		var south = tangent.cross(Vector3.UP)
		var basis = Basis.looking_at(tangent, Vector3.UP)
		var mid = (a + b) * .5 - south * 4.0
		deck.append([mid, Vector3(8, .5, a.distance_to(b) + .2), basis])
		var edge = mid - south * 3.65
		stone_cap.append([edge, Vector3(.55, .55, a.distance_to(b)), basis])
		rails.append([edge + Vector3.UP * 1.05, Vector3(.08, .08, a.distance_to(b)), basis])
		var n = ceili(a.distance_to(b) / 3.0)
		for k in n:
			var at = a.lerp(b, float(k) / n) - south * 7.65
			rails.append([at + Vector3.UP * .6, Vector3(.08, 1.1, .08)])
	multimesh_boxes(asset, parent, "RiverwalkPromenade", pier_walk, deck)
	multimesh_boxes(asset, parent, "RiverwalkCoping", cc0_material("Travertine009"), stone_cap)
	multimesh_boxes(asset, parent, "RiverwalkRailings", material(Color("253c38")), rails)


static func add_city(asset: Node3D, parent: Node, road: RoadPath) -> void:
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng = RandomNumberGenerator.new()
	rng.seed = 250901
	var curve = road.working_curve()
	# Batched original low-poly massing with modelled window strips, no downloaded city models.
	for x in range(-1450, 700, 110):
		for z in range(-700, 1000, 110):
			var p = Vector3(x + rng.randf_range(-15, 15), 8, z + rng.randf_range(-15, 15))
			# Keep parks, the river corridor, the lakefront, and landmark sightlines open.
			if p.x > 20 and p.z > -210:
				continue
			if p.z < -250 and p.x > -50:
				continue
			if p.z < -285 and p.z > -400:
				continue
			if p.x < -1110 and p.x > -1250:
				continue
			var nearest = curve.get_closest_point(p)
			if Vector2(nearest.x - p.x, nearest.z - p.z).length() < 65:
				continue
			if p.distance_to(world(data().landmarks["Willis Tower"])) < 115:
				continue
			var w = rng.randf_range(35, 65)
			var d = rng.randf_range(35, 65)
			var h = rng.randf_range(35, 150)
			var shade = rng.randf_range(.22, .46)
			# Brick commercial blocks fill the older near-river west side; high-rises frame the Loop.
			if p.x < -450 and p.z > -200 and p.z < 500 and h < 90:
				continue
			facade_box(
				st,
				p + Vector3(0, h * .5 - 5, 0),
				Vector3(w, h + 10, d),
				Color(shade, shade * .97, shade * .92)
			)
			for floor_i in range(2, int(h / 4.0)):
				var y = floor_i * 4.0
				var col = Color("526c79") if floor_i % 3 else Color("84908d")
				facade_box(st, p + Vector3(0, y, 0), Vector3(w + .15, 1.6, d + .15), col)
	st.generate_normals()
	var mesh = st.commit()
	var facade = NightGlow.facade_material().duplicate()
	facade.set_shader_parameter("window_scale", 3.8)
	facade.set_shader_parameter("lit_chance", .22)
	facade.set_shader_parameter("glow_energy", .45)
	mesh.surface_set_material(0, facade)
	mesh_node(asset, parent, "LoopSkyline", mesh, Vector3.ZERO)

	var brick = pbr_texture_set("red_brick_03", "red_brick_03", "diff")
	var tan_brick = pbr_texture_set("brick_wall_003", "brick_wall_003", "diffuse")
	var pavement = pbr_texture_set("concrete_floor_damaged_01", "concrete_floor_damaged_01", "diff")
	var iron = material(Color("4c5353"))
	var iron_boxes: Array = []
	# Small masonry street wall with deep window openings and steel fire escapes.
	for block in [Vector3(-780, 0, 170), Vector3(-890, 0, 280), Vector3(-670, 0, 390)]:
		textured_building(asset, parent, "NearRiverBrickStreetfront", block, Vector3(58, 46, 50), brick)
		for floor_i in range(3):
			var y = 7.0 + floor_i * 12.0
			iron_boxes.append([block + Vector3(30, y, 0), Vector3(9, .4, 2), Basis(Vector3.UP, .12)])
			for side in [-1, 1]:
				iron_boxes.append([block + Vector3(30, y + .9, side * .9), Vector3(9, .12, .12)])
				iron_boxes.append(
					[
						block + Vector3(30 + side * 3, y + 5.7, 0),
						Vector3(.12, 11.5, .12),
						Basis(Vector3.FORWARD, -.45)
					]
				)
	for block in [Vector3(-560, 0, 610), Vector3(-350, 0, 720)]:
		textured_building(asset, parent, "LoopTerraCottaStreetfront", block, Vector3(72, 58, 48), tan_brick)
	# Broadly repeated sidewalk slabs stay outside the unchanged road surface.
	var walk = box(
		asset, parent, "LoopStoneSidewalk", Vector3(-350, 1.1, 520), Vector3(460, .24, 18), pavement
	)
	walk.material_override = pavement
	multimesh_boxes(asset, parent, "FireEscapeMetalwork", iron, iron_boxes)


static func textured_building(
	asset: Node3D, parent: Node, title: String, pos: Vector3, size: Vector3, mat: Material
) -> void:
	var building = BoxMesh.new()
	building.size = size
	building.material = mat
	building.material.uv1_scale = Vector3(4.0, 3.0, 1.0)
	mesh_node(asset, parent, title, building, pos + Vector3(0, size.y * .5, 0))


static func add_landmarks(asset: Node3D, parent: Node) -> void:
	var dark = material(Color("242b30"))
	var silver = material(Color("abbfc8"))
	silver.metallic = .85
	silver.roughness = .22
	var stone = material(Color("c9bca1"))
	var willis = world(data().landmarks["Willis Tower"])
	# ASSET-02: BoldlyBuilding's CC BY 4.0 Willis Tower (527 m with antennas), its own window textures by day
	# and the same textures glowing warm after hours (chicago_night.gd toggles the emission).
	var tower = PropMesh.mesh("res://assets/chicago/landmarks/willis_tower.glb").duplicate()
	for i in tower.get_surface_count():
		var mat = tower.surface_get_material(i)
		if mat is StandardMaterial3D:
			mat = mat.duplicate()
			mat.emission = Color("ffd9a0")
			mat.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY
			mat.emission_texture = mat.albedo_texture
			mat.emission_energy_multiplier = 0.9
			mat.set_meta("chicago_night", true)
			tower.surface_set_material(i, mat)
	mesh_node(asset, parent, "WillisTower", tower, willis)
	# ASSET-02: 99.Miles' low-poly night skyline blocks (CC BY 4.0) as a far backdrop beyond the OSM city
	# (west, south-west and north; the lake is east).
	var skyline = PropMesh.mesh("res://assets/chicago/landmarks/night_skyline.glb")
	for spot in [
		[-2400.0, -1500.0, 0.3], [-2500.0, 900.0, 1.9], [-1000.0, -2500.0, 3.4], [300.0, -2600.0, 4.6]
	]:
		var block = mesh_node(asset, parent, "Skyline", skyline, Vector3(spot[0], 7.9, spot[1]))
		block.rotation.y = spot[2]
		block.scale = Vector3.ONE * 1.6
	# The Bean: John Helman's CC BY 4.0 Cloud Gate model (20 x 13 x 10 m) in the chrome material.
	var bean = world(data().landmarks["Bean"])
	box(asset, parent, "CloudGatePlaza", bean + Vector3(0, -.1, 0), Vector3(70, .3, 60), stone)
	# A paved west approach connects the plaza to Michigan Avenue through the park trees.
	box(
		asset,
		parent,
		"CloudGateWestApproach",
		Vector3((12.0 + bean.x - 35.0) * .5, bean.y - .1, bean.z),
		Vector3(bean.x - 47.0, .3, 12.0),
		stone
	)
	var bean_mesh = PropMesh.mesh("res://assets/chicago/landmarks/bean.glb").duplicate()
	for i in bean_mesh.get_surface_count():
		bean_mesh.surface_set_material(i, silver)
	mesh_node(asset, parent, "BeanArch", bean_mesh, bean + Vector3(0, 0.05, 0))
	# Navy Pier: official hub 104 ft above deck, 21 spokes and 42 enclosed blue gondolas.
	# Anchor to the dressed pier deck, rather than route.json's old submerged y2 landmark height.
	var pier = world(data().landmarks["Navy Pier"])
	pier.y = ChicagoCity.LAKE_Y + .8
	var hub = pier + Vector3(0, 31.7, 0)
	var wheel = TorusMesh.new()
	wheel.inner_radius = 27.85
	wheel.outer_radius = 28.15
	wheel.rings = 84
	wheel.ring_segments = 6
	wheel.material = night_material(Color("b5dce6"), 1.6)
	var wn = mesh_node(asset, parent, "CentennialWheel", wheel, hub)
	wn.rotation_degrees.x = 90
	var spokes: Array = []
	for i in 21:
		var ang = TAU * i / 21.0
		spokes.append(
			[
				hub + Vector3(cos(ang), sin(ang), 0) * 14,
				Vector3(.18, 28, .18),
				Basis(Vector3.BACK, ang - PI * .5)
			]
		)
	multimesh_boxes(asset, parent, "WheelSpokes", night_material(Color("96c8e0"), .65), spokes)
	var cabins: Array = []
	var roofs: Array = []
	var frames: Array = []
	var glass = material(Color("365c72"))
	glass.metallic = .12
	glass.roughness = .23
	for i in 42:
		var ang = TAU * i / 42.0
		var end = hub + Vector3(cos(ang) * 28, sin(ang) * 28, 0)
		cabins.append([end + Vector3(0, -.65, 0), Vector3(1.9, .5, 1.9)])
		roofs.append([end + Vector3(0, 1.05, 0), Vector3(2.0, .15, 2.0)])
		for x in [-.9, .9]:
			for z in [-.9, .9]:
				frames.append([end + Vector3(x, .2, z), Vector3(.08, 1.65, .08)])
		box(asset, parent, "WheelCabin%d" % i, end + Vector3(0, .2, 0), Vector3(1.8, 1.5, 1.8), glass)
	var blue = material(Color("194778"))
	multimesh_boxes(asset, parent, "WheelCabinBases", blue, cabins)
	multimesh_boxes(asset, parent, "WheelCabinRoofs", blue, roofs)
	multimesh_boxes(asset, parent, "WheelCabinFrames", material(Color("b7c8cb")), frames)
	# Six structural legs meet the axle; feet stand on the deck, clear of the loading platform.
	for side in [-1, 1]:
		for z in [-6.0, 0.0, 6.0]:
			var foot = pier + Vector3(side * 18.2, 0, z)
			var axle = hub + Vector3(0, 0, z * .3)
			var leg = box(
				asset,
				parent,
				"WheelSupport",
				(foot + axle) * .5,
				Vector3(1.1, 1.1, foot.distance_to(axle)),
				silver
			)
			leg.basis = Basis.looking_at(axle - foot, Vector3.UP)
	var axle = CylinderMesh.new()
	axle.top_radius = 1.65
	axle.bottom_radius = 1.65
	axle.height = 4.5
	axle.material = material(Color("d6e0df"))
	var axle_node = mesh_node(asset, parent, "WheelAxle", axle, hub)
	axle_node.rotation_degrees.x = 90

	add_loop_landmarks(asset, parent)


## Authored landmark exteriors share mapped positions and native night toggles.
static func add_loop_landmarks(asset: Node3D, parent: Node) -> void:
	# Mapped west-of-Michigan office blocks, bridges and four-sided clock tower.
	var wrigley = PropMesh.mesh("res://assets/chicago/landmarks/wrigley_building.glb").duplicate()
	for surface in wrigley.get_surface_count():
		var mat = wrigley.surface_get_material(surface)
		if mat is StandardMaterial3D and mat.resource_name.begins_with("Night"):
			mat = mat.duplicate()
			mat.set_meta("chicago_night", true)
			mat.emission_enabled = false
			wrigley.surface_set_material(surface, mat)
	mesh_node(asset, parent, "WrigleyBuilding", wrigley, ChicagoCity.WRIGLEY_POSITION)
	# Blender-authored limestone shaft, inset windows and open Gothic buttress crown.
	var tribune = PropMesh.mesh("res://assets/chicago/landmarks/tribune_tower.glb").duplicate()
	for surface in tribune.get_surface_count():
		var mat = tribune.surface_get_material(surface)
		if mat is StandardMaterial3D and mat.resource_name.begins_with("Night"):
			mat = mat.duplicate()
			mat.set_meta("chicago_night", true)
			mat.emission_enabled = false
			tribune.surface_set_material(surface, mat)
	mesh_node(asset, parent, "TribuneTower", tribune, ChicagoCity.TRIBUNE_POSITION)
	# Authored historic north tower and later south/east annexes at their mapped site.
	var board = PropMesh.mesh("res://assets/chicago/landmarks/board_of_trade.glb").duplicate()
	for surface in board.get_surface_count():
		var mat = board.surface_get_material(surface)
		if mat is StandardMaterial3D:
			var floodlit = (
				mat.resource_name in ["Grey Indiana limestone", "Raised pale limestone", "Ceres aluminum"]
			)
			if floodlit or mat.resource_name.begins_with("Night"):
				mat = mat.duplicate()
				mat.set_meta("chicago_night", true)
				if floodlit:
					mat.emission = mat.albedo_color
					mat.emission_energy_multiplier = .16
				mat.emission_enabled = false
				board.surface_set_material(surface, mat)
	mesh_node(asset, parent, "BoardOfTrade", board, ChicagoCity.BOARD_POSITION)
	# 35 East Wacker: four open corner turrets, tall drum and carved dome.
	var jewelers = PropMesh.mesh("res://assets/chicago/landmarks/jewelers_building.glb").duplicate()
	for surface in jewelers.get_surface_count():
		var mat = jewelers.surface_get_material(surface)
		if mat is StandardMaterial3D:
			var floodlit = mat.resource_name in ["Raised classical ornament", "Carved terra cotta dome"]
			if floodlit or mat.resource_name.begins_with("Night"):
				mat = mat.duplicate()
				mat.set_meta("chicago_night", true)
				if floodlit:
					mat.emission = mat.albedo_color
					mat.emission_energy_multiplier = .12
				elif mat.resource_name == "Night recessed office glazing":
					mat.emission = Color(.68, .50, .25)
					mat.emission_energy_multiplier = .55
				mat.emission_enabled = false
				jewelers.surface_set_material(surface, mat)
	var jewelers_node = mesh_node(asset, parent, "JewelersBuilding", jewelers, ChicagoCity.JEWELERS_POSITION)
	jewelers_node.rotation.y = ChicagoCity.JEWELERS_YAW


static func add_river_bridges(asset: Node3D, parent: Node) -> void:
	# Closed bascule bridges: riveted red-brown girders below the boulevard, not overhead trusses.
	# DuSable's Beaux Arts bridgehouses / pylons follow the Chicago Architecture Center reference.
	var steel = material(Color("593d32"))
	steel.metallic = .55
	steel.roughness = .6
	var stone = cc0_material("Travertine009")
	var spans = [
		["MichiganAvenueBridge", 41.88865, -87.6245, 90.0],
		["StateStreetBridge", 41.8888, -87.6270, 60.0],
		["LaSalleStreetBridge", 41.8888, -87.6290, 58.0]
	]
	var steel_boxes: Array = []
	var deck_boxes: Array = []
	var house_boxes: Array = []
	var window_boxes: Array = []
	for span in spans:
		var anchor = world([span[1], span[2], 8]) + Vector3(0, -1.25, 0)
		var length: float = span[3]
		deck_boxes.append([anchor, Vector3(23, 2.4, length)])
		for side in [-1, 1]:
			# Low pedestrian rail over a deep side girder; lower-deck bracing visible from the river.
			steel_boxes.append([anchor + Vector3(side * 11.1, -.6, 0), Vector3(.5, 2.0, length)])
			for y in [1.65, 2.6]:
				steel_boxes.append([anchor + Vector3(side * 11.1, y, 0), Vector3(.22, .18, length)])
			for i in range(0, int(length), 3):
				var z = -length * .5 + i
				steel_boxes.append([anchor + Vector3(side * 11.1, 2.0, z), Vector3(.18, 1.3, .18)])
				if i % 6 == 0:
					steel_boxes.append([anchor + Vector3(side * 11.1, -.6, z), Vector3(.18, 2.5, .18)])
		for side in [-1, 1]:
			# Keep the southern houses clear of the fictional Lower Wacker racing approach.
			var house = anchor + Vector3(side * 19, 0, -(length * .5 + 9))
			house_boxes.append([house + Vector3(0, 4.0, 0), Vector3(9, 8, 10)])
			house_boxes.append([house + Vector3(0, 8.3, 0), Vector3(10.2, .7, 11.2)])
			house_boxes.append([house + Vector3(0, 9.0, 0), Vector3(9.5, .5, 10.5)])
			for x in [-3.75, 3.75]:
				house_boxes.append([house + Vector3(x, 4.6, 5.15), Vector3(.7, 7.0, .5)])
			for x in [-2.4, 0.0, 2.4]:
				window_boxes.append([house + Vector3(x, 5.8, 5.04), Vector3(1.35, 2.5, .12)])
				house_boxes.append([house + Vector3(x, 4.4, 5.2), Vector3(1.65, .3, .4)])
			# Compact copper roof, ornamental cap and sculptural panel instead of a fantasy spire.
			var roof = PrismMesh.new()
			roof.size = Vector3(10, 2.6, 11)
			roof.material = material(Color("42564f"))
			mesh_node(asset, parent, span[0] + "BridgeHouseRoof", roof, house + Vector3(0, 10.45, 0))
			house_boxes.append([house + Vector3(0, 2.2, 5.2), Vector3(5.0, 2.2, .25)])
			for x in [-3.7, 3.7]:
				house_boxes.append([house + Vector3(x, 9.7, 0), Vector3(.8, 1.0, .8)])
	multimesh_boxes(asset, parent, "ChicagoBridgeDecks", material(Color("4b5352")), deck_boxes)
	multimesh_boxes(asset, parent, "ChicagoBridgeSteel", steel, steel_boxes)
	multimesh_boxes(asset, parent, "ChicagoBridgeHouses", stone, house_boxes)
	multimesh_boxes(asset, parent, "ChicagoBridgeHouseWindows", material(Color("1d2e33")), window_boxes)


static func add_lower_deck(asset: Node3D, parent: Node, road: RoadPath) -> void:
	var concrete = pbr_texture_set("concrete_floor_damaged_01", "concrete_floor_damaged_01", "diff")
	concrete.uv1_triplanar = true
	concrete.uv1_world_triplanar = true
	concrete.uv1_scale = Vector3.ONE / 3.0
	var st = road.last_bake.stations
	var count = 0
	var column_height = WACKER_RIB_BOTTOM_Y - ChicagoCity.LOW_ROAD_Y
	var deck_tool = SurfaceTool.new()
	deck_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Post-tensioned concrete: 13 in slab, 2 in overlay, 4 ft wide / 2 ft deep longitudinal ribs.
	var beam_tool = SurfaceTool.new()
	beam_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(0, st.size(), 8):
		var at = st[i]
		# Only the lower Wacker road, not the exposed game-only connector at the south end.
		if not covered_wacker(at.pos):
			continue
		var tangent = at.tangent
		var basis = Basis.looking_at(tangent, Vector3.UP)
		var north_south = at.pos.x <= -900.0
		var width = 42.672 if north_south else 23.0
		var deck_at = at.pos - basis.x * (5.18 if north_south else 0.0)
		var p = Vector3(deck_at.x, WACKER_SOFFIT_Y + .1651, deck_at.z)
		facade_box(deck_tool, p, Vector3(width, .3302, 13), Color.WHITE, basis)
		solid_box(asset, "Ceiling%d" % count, Transform3D(basis, p), Vector3(width, .3302, 13))
		# Side/service bays occupy the whole section beside the single racing through lane.
		if north_south:
			facade_box(
				deck_tool,
				Vector3(deck_at.x, ChicagoCity.LOW_ROAD_Y - .045, deck_at.z),
				Vector3(width, .03, 13),
				Color.WHITE,
				basis
			)
		var ribs = WACKER_NS_COLUMNS if north_south else [-5.0, 5.0]
		for offset in ribs:
			var girder = at.pos - basis.x * offset
			girder.y = WACKER_RIB_BOTTOM_Y + .3048
			facade_box(beam_tool, girder, Vector3(1.2192, .6096, 13), Color.WHITE, basis)
		count += 1
	deck_tool.generate_normals()
	var deck_mesh = deck_tool.commit()
	deck_mesh.surface_set_material(0, concrete)
	mesh_node(asset, parent, "WackerDeckAndColumns", deck_mesh, Vector3.ZERO)
	beam_tool.generate_normals()
	var beam_mesh = beam_tool.commit()
	beam_mesh.surface_set_material(0, concrete)
	mesh_node(asset, parent, "WackerBeams", beam_mesh, Vector3.ZERO)
	# CDOT / Benesch, ASPIRE Fall 2012: N–S viaduct's 3 ft round columns, roughly 32 ft centres.
	# N–S axes follow the published section; E–W retains its map corridor pending its variable sections.
	var frame = road_frame(road)
	var curve: Curve3D = frame[0]
	var length = curve.get_baked_length()
	var positions: Array[Vector3] = []
	var s = 0.0
	while s < length:
		var at = RoadBuilder.station_at(curve, road.closed, length, frame[2], s)
		if covered_wacker(at.pos):
			var basis = Basis.looking_at(at.tangent, Vector3.UP)
			var offsets = WACKER_NS_COLUMNS if at.pos.x <= -900.0 else [-10.5, 10.5]
			for offset in offsets:
				var p = at.pos - basis.x * offset
				p.y = ChicagoCity.LOW_ROAD_Y + column_height * .5
				positions.append(p)
		s += 9.7536
	var column = CylinderMesh.new()
	column.top_radius = .4572
	column.bottom_radius = .4572
	column.height = column_height
	column.radial_segments = 16
	column.material = concrete
	var instances = MultiMesh.new()
	instances.transform_format = MultiMesh.TRANSFORM_3D
	instances.mesh = column
	instances.instance_count = positions.size()
	for i in positions.size():
		instances.set_instance_transform(i, Transform3D(Basis.IDENTITY, positions[i]))
		var body = StaticBody3D.new()
		body.position = positions[i]
		body.collision_layer = 2
		body.collision_mask = 0
		body.set_meta("wall_kind", "concrete")
		var shape = CollisionShape3D.new()
		shape.shape = CylinderShape3D.new()
		shape.shape.radius = .4572
		shape.shape.height = column_height
		body.add_child(shape)
		attach(asset, asset, body, "WackerRoundColumn%d" % i)
		shape.owner = asset
	var columns = MultiMeshInstance3D.new()
	columns.multimesh = instances
	attach(asset, parent, columns, "WackerRoundColumns")


static func add_road_details(asset: Node3D, parent: Node, road: RoadPath) -> void:
	var paint = material(Color("d3ceb3"))
	var green = material(Color("16493d"))
	var st = road.last_bake.stations
	# Low-cost batched dashed lane dividers, broken at junctions. Surfaces remain authoritative.
	var tool = SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(0, st.size(), 10):
		var at = st[i]
		var right = at.tangent.cross(Vector3.UP).normalized()
		var section = RoadBuilder.section_at(road.sections, at.s, road.last_bake.length, road.closed)
		var dividers = [0.0] if section.width_left < 4.5 else [-4.0, 4.0]
		for offset in dividers:
			var pos = at.pos + right * offset + Vector3(0, .012, 0)
			var a = at.tangent * 2.5
			var b = right * .07
			tool.set_color(Color("d3ceb3"))
			for vertex in [pos - a - b, pos + a - b, pos + a + b, pos - a - b, pos + a + b, pos - a + b]:
				tool.add_vertex(vertex)
	tool.generate_normals()
	var mesh = tool.commit()
	mesh.surface_set_material(0, paint)
	mesh_node(asset, parent, "LaneMarkings", mesh, Vector3.ZERO)
	# Driver-readable district signs face approaching traffic, outside the racing corridor.
	var labels = [[0, "MICHIGAN AVE"], [4, "LAKE SHORE DR"], [11, "LOWER WACKER"], [24, "UPPER WACKER"]]
	for row in labels:
		var p = world(data().points[row[0]])
		var s = road.working_curve().get_closest_offset(p)
		var a = road.working_curve().sample_baked(s)
		var b = road.working_curve().sample_baked(s + 2)
		var basis = Basis.looking_at((b - a).normalized(), Vector3.UP)
		var sign_pos = a + basis.x * 11 + Vector3(0, 4, 0)
		var panel = box(asset, parent, "SignPanel%d" % row[0], sign_pos, Vector3(8, 1.6, .15), green)
		panel.basis = basis
		var label = Label3D.new()
		label.text = row[1]
		label.font_size = 48
		label.pixel_size = .025
		label.no_depth_test = false
		label.position = sign_pos + basis.z * .1
		label.basis = basis
		attach(asset, parent, label, "StreetSign%d" % row[0])


func _initialize() -> void:
	var asset = build_asset()
	var errors = asset.validate()
	print("CHICAGO BAKE length=%.1f errors=%s" % [asset.length, errors])
	asset.free()
	quit(0 if errors.is_empty() else 1)


## Clockwise exterior triangles and flat face normals. Keep this local to Chicago; the shared
## scenery helper's opposite winding would expose the back of the city blocks through the windows.
static func facade_box(
	st: SurfaceTool, center: Vector3, size: Vector3, color: Color, basis: Basis = Basis.IDENTITY
) -> void:
	var h = size * .5
	var v = [
		Vector3(-h.x, -h.y, -h.z),
		Vector3(h.x, -h.y, -h.z),
		Vector3(h.x, -h.y, h.z),
		Vector3(-h.x, -h.y, h.z),
		Vector3(-h.x, h.y, -h.z),
		Vector3(h.x, h.y, -h.z),
		Vector3(h.x, h.y, h.z),
		Vector3(-h.x, h.y, h.z)
	]
	st.set_color(color)
	st.set_smooth_group(-1)
	for q in [[3, 2, 6, 7], [1, 0, 4, 5], [4, 7, 6, 5], [0, 1, 2, 3], [0, 3, 7, 4], [2, 1, 5, 6]]:
		for i in [q[0], q[2], q[1], q[0], q[3], q[2]]:
			st.add_vertex(center + basis * v[i])


static func add_park_trees(asset: Node3D) -> void:
	# Leave the Bean sightline (middle of the Michigan straight) open.
	for band in [[0.0, 150.0], [360.0, 640.0], [760.0, 1150.0]]:
		var trees = RoadScatter.new()
		trees.follow_road = NodePath("../Main")
		trees.sides = RoadScatter.Sides.LEFT
		trees.from_m = band[0]
		trees.to_m = band[1]
		trees.offset_min = 26.0
		trees.offset_max = 42.0
		trees.per_100m = 6.0
		trees.random_seed = 251
		trees.species_indices = PackedInt32Array([2, 3, 4])
		attach(asset, asset, trees, "ParkTrees%d" % int(band[0]))
		trees.bake()


## LOOK-18: Lower Wacker is lit by close-set fixtures on both sides. At the route's 42 m alternating spacing
## (and LOOK-NIGHT-01's softer streaks) the lower level was nearly black at night. Lamp zones for every stretch
## below 3 m: 16 m spacing, both sides.
static func lower_level_zones(road: RoadPath) -> Array:
	var f = road_frame(road)
	var c = f[0]
	var length = c.get_baked_length()
	var zones = []
	var start = -1.0
	var s = 0.0
	while s < length:
		var low = covered_wacker(RoadBuilder.station_at(c, road.closed, length, f[2], s).pos)
		if low and start < 0.0:
			start = s
		elif not low and start >= 0.0:
			zones.append({"from_m": start, "to_m": s, "spacing": 16.0, "sides": "both", "extra": 0.6})
			start = -1.0
		s += 5.0
	if start >= 0.0:
		zones.append({"from_m": start, "to_m": length, "spacing": 16.0, "sides": "both", "extra": 0.6})
	return zones


## Grant Park and lakefront trees (LOOK-13): Jackson Drive crosses the park and Lake Shore Drive runs between
## the park (left, beyond LSD's own carriageways) and the lakefront trail (right, short of the harbour wall).
## They were bare lawn to the horizon.
static func add_lakefront_trees(asset: Node3D) -> void:
	var at = asset.get_meta("corners", {})
	if not (at.has("Jackson Turn") and at.has("Lakefront Turn") and at.has("Navy Pier View")):
		return
	var bands = [
		[at["Jackson Turn"] + 30.0, at["Lakefront Turn"] - 20.0, RoadScatter.Sides.BOTH, 14.0, 90.0, 16.0],
		[at["Lakefront Turn"] + 30.0, at["Navy Pier View"] - 40.0, RoadScatter.Sides.LEFT, 45.0, 130.0, 18.0],
		[at["Lakefront Turn"] + 30.0, at["Navy Pier View"] - 40.0, RoadScatter.Sides.RIGHT, 12.0, 42.0, 10.0],
	]
	for i in bands.size():
		var b = bands[i]
		if b[1] <= b[0]:
			continue
		var trees = RoadScatter.new()
		trees.follow_road = NodePath("../Main")
		trees.sides = b[2]
		trees.from_m = b[0]
		trees.to_m = b[1]
		trees.offset_min = b[3]
		trees.offset_max = b[4]
		trees.per_100m = b[5]
		trees.random_seed = 3101 + i
		trees.species_indices = PackedInt32Array([2, 3, 4])
		attach(asset, asset, trees, "LakefrontTrees%d" % i)
		trees.bake()


## Local accent materials retain their daylight appearance; runtime toggles emission on cached scenes.
static func night_material(color: Color, energy: float) -> StandardMaterial3D:
	var mat = material(color)
	mat.emission = color
	mat.emission_energy_multiplier = energy
	mat.set_meta("chicago_night", true)
	return mat


static func add_night_details(asset: Node3D, parent: Node, road: RoadPath, lamps: Array) -> void:
	var warm = night_material(Color("ffd19a"), 1.7)
	var cool = night_material(Color("a6d6ef"), 1.5)
	# High-pressure sodium orange for Lower Wacker's ceiling fixtures (lower-wacker-drive.jpg).
	var sodium = night_material(Color("ffa540"), 2.0)
	var fixtures = SurfaceTool.new()
	fixtures.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Batched ceiling luminaires stay above the unchanged driving clearance.
	for lamp in lamps:
		if lamp.kind != "ceiling":
			continue
		facade_box(fixtures, lamp.base, Vector3(.45, .12, 3.6), Color.WHITE, lamp.basis)
	fixtures.generate_normals()
	var mesh = fixtures.commit()
	mesh.surface_set_material(0, sodium)
	mesh_node(asset, parent, "WackerCeilingLuminaires", mesh, Vector3.ZERO)
	# OSM supplies business names/positions, not sign colours, dimensions or heights.
	# Keep those records and the old helper until the final audit; source-faithful
	# photographic signs remain in the landmark facades.
	asset.set_meta("neon_signs", 0)
	var pier = world(data().landmarks["Navy Pier"])
	pier.y = ChicagoCity.LAKE_Y + .8
	for i in range(1, 6):
		box(
			asset,
			parent,
			"PierRoofLight%d" % i,
			pier + Vector3(i * 95, 14.6, 23.1),
			Vector3(80, .15, .2),
			warm
		)
	var willis = world(data().landmarks["Willis Tower"])
	for side in [-1, 1]:
		box(
			asset,
			parent,
			"WillisBeacon%d" % side,
			willis + Vector3(side * 9, 508, 0),
			Vector3(2.5, 1.5, 2.5),
			night_material(Color("ed6050"), 2.0)
		)
	var bean = world(data().landmarks["Bean"])
	for side in [-1, 1]:
		var light = SpotLight3D.new()
		light.position = bean + Vector3(side * 23, 7, -15)
		light.light_color = Color("d0e2f3")
		light.light_energy = 7.0
		light.spot_range = 65.0
		light.spot_angle = 48.0
		light.shadow_enabled = false
		light.visible = false
		light.set_meta("chicago_night", true)
		attach(asset, parent, light, "PlazaFlood%d" % side)
		light.basis = Basis.looking_at(bean + Vector3(0, 4, 0) - light.position)
		for i in 7:
			box(
				asset,
				parent,
				"PlazaBollard%d_%d" % [side, i],
				bean + Vector3(side * 30, .8, (i - 3) * 8),
				Vector3(.5, 1.6, .5),
				warm
			)


## NFSU street neon (owner 2026-09-28): storefront bars and blade signs on the building line either side of
## the route, one batched mesh per colour, plus a coloured light every few signs so the wet road picks them
## up. Night only (chicago_night meta).
const SIGN_FONT = preload("res://assets/fonts/Rajdhani-Bold.ttf")
## Real businesses from OpenStreetMap (build: see signs.json "source"), in the world() frame.
const SIGNS = "res://trackgen/data/chicago/signs.json"
## Category -> colour index: bars/clubs magenta, food red/amber, cafes green, hotels violet, shops cyan.
const SIGN_COLOR = {
	"bar": 0,
	"pub": 0,
	"nightclub": 0,
	"casino": 0,
	"shop": 1,
	"pharmacy": 1,
	"bank": 1,
	"cafe": 2,
	"ice_cream": 2,
	"restaurant": 3,
	"fast_food": 5,
	"hotel": 4,
	"cinema": 4,
	"theatre": 4,
	"museum": 4
}


## Stable 0..1 per position, so a rebuild keeps each sign's height.
static func randf_seeded(p: Vector3) -> float:
	return fposmod(sin(p.x * 12.9898 + p.z * 78.233) * 43758.5453, 1.0)


static func add_neon(asset: Node3D, parent: Node, road: RoadPath) -> void:
	var colors = [
		Color("ff2a8a"), Color("21e0ff"), Color("5dff6a"), Color("ff3b2f"), Color("7a5cff"), Color("ffb020")
	]
	var tools = []
	for c in colors:
		var st = SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		tools.append(st)
	var stations = road.last_bake.stations
	var lights = 0
	var edges = facade_edges()
	# Route stations in 25 m cells (street level only; Lower Wacker is a tunnel).
	var route = {}
	for at in stations:
		if at.pos.y > 3.0:
			route.get_or_add(Vector2i(floori(at.pos.x / 25.0), floori(at.pos.z / 25.0)), []).append(at)
	var placed = []
	var signs = JSON.parse_string(FileAccess.get_file_as_string(SIGNS)).signs
	for poi in signs:
		var p = Vector2(poi.x, poi.z)
		# Nearest street-level station within 60 m of the business.
		var at = null
		var best = 60.0
		for dx in [-2, -1, 0, 1, 2]:
			for dz in [-2, -1, 0, 1, 2]:
				for st in route.get(Vector2i(floori(p.x / 25.0) + dx, floori(p.y / 25.0) + dz), []):
					var d = p.distance_to(Vector2(st.pos.x, st.pos.z))
					if d < best:
						best = d
						at = st
		if at == null:
			continue
		# The wall nearest the business's real OSM position (no sliding along the street). The sign faces the
		# route; a wall more than 45 m from it is not visible from the road, so the business gets no sign.
		var wall = nearest_wall(edges, p)
		if wall.is_empty():
			continue
		var hit: Vector2 = wall[0]
		if hit.distance_to(p) > 15.0 or hit.distance_to(Vector2(at.pos.x, at.pos.z)) > 45.0:
			continue
		var out = Vector3(at.pos.x - hit.x, 0, at.pos.z - hit.y).normalized()
		var along = Vector3(wall[1].x, 0, wall[1].y)
		var base = Vector3(hit.x, ChicagoCity.STREET_Y, hit.y) + out * 0.25
		var crowded = false
		for q in placed:
			if q.distance_to(base) < 9.0:
				crowded = true
				break
		if crowded:
			continue
		placed.append(base)
		var k = SIGN_COLOR.get(str(poi.c), 5)
		var big = str(poi.c) in ["hotel", "cinema", "theatre", "casino", "museum"]
		var y = (9.0 + randf_seeded(base) * 6.0) if big else (3.4 + randf_seeded(base) * 1.8)
		var sign = Label3D.new()
		sign.text = str(poi.n).to_upper()
		sign.font = SIGN_FONT
		sign.font_size = 96
		sign.pixel_size = 0.018 if big else 0.011
		sign.outline_size = 18
		sign.shaded = false
		sign.double_sided = false
		sign.modulate = colors[k] * 3.5
		sign.outline_modulate = Color(colors[k].r, colors[k].g, colors[k].b, 0.35)
		sign.position = base + Vector3(0, y + .5, 0)
		sign.basis = Basis.looking_at(-out, Vector3.UP)
		sign.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		sign.visible = false
		sign.set_meta("chicago_night", true)
		attach(asset, parent, sign, "Sign%d" % placed.size())
		var basis = Basis.looking_at(along, Vector3.UP)
		facade_box(
			tools[k],
			base + Vector3(0, y, 0),
			Vector3(.1, .08, 3.0 + sign.text.length() * .35),
			Color.WHITE,
			basis
		)
		if lights < 120 and placed.size() % 2 == 0:
			lights += 1
			var light = OmniLight3D.new()
			light.position = base + out * 3.0 + Vector3(0, 4.5, 0)
			light.light_color = colors[k]
			light.light_energy = 3.0
			light.omni_range = 16.0
			light.omni_attenuation = 1.4
			light.shadow_enabled = false
			light.visible = false
			light.set_meta("chicago_night", true)
			attach(asset, parent, light, "NeonSpill%d" % lights)
	asset.set_meta("neon_signs", placed.size())
	for k in colors.size():
		tools[k].generate_normals()
		var mesh = tools[k].commit()
		if mesh.get_surface_count() == 0:
			continue
		mesh.surface_set_material(0, night_material(colors[k], 5.0))
		var node = mesh_node(asset, parent, "Neon%d" % k, mesh, Vector3.ZERO)
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.set_meta("chicago_night", true)


## OSM building edges in 25 m cells (by edge midpoint), for snapping signs onto real facades.
static func facade_edges() -> Dictionary:
	var doc = JSON.parse_string(FileAccess.get_file_as_string(ChicagoCity.DATA))
	var cells = {}
	for b in doc.buildings:
		var ring = ChicagoCity._ring(b.f)
		for j in ring.size():
			var a = ring[j]
			var c = ring[(j + 1) % ring.size()]
			var k = Vector2i(floori((a.x + c.x) * .5 / 25.0), floori((a.y + c.y) * .5 / 25.0))
			cells.get_or_add(k, []).append([a, c])
	return cells


## Closest point on any OSM building edge to p (within the 3x3 cells): [point, edge direction], or [].
static func nearest_wall(cells: Dictionary, p: Vector2) -> Array:
	var best = INF
	var out = []
	for dx in [-1, 0, 1]:
		for dz in [-1, 0, 1]:
			for e in cells.get(Vector2i(floori(p.x / 25.0) + dx, floori(p.y / 25.0) + dz), []):
				var q = Geometry2D.get_closest_point_to_segment(p, e[0], e[1])
				if q.distance_to(p) < best:
					best = q.distance_to(p)
					out = [q, (e[1] - e[0]).normalized()]
	return out


## Nearest facade crossing of the ray o + d*t, t in (near, far); null if none.
static func facade_hit(cells: Dictionary, o: Vector2, d: Vector2, near: float, far: float):
	var end = o + d * far
	var best = INF
	var hit = null
	var seen = {}
	var t = 0.0
	while t <= far:
		var p = o + d * t
		for dx in [-1, 0, 1]:
			for dz in [-1, 0, 1]:
				var k = Vector2i(floori(p.x / 25.0) + dx, floori(p.y / 25.0) + dz)
				if seen.has(k) or not cells.has(k):
					continue
				seen[k] = true
				for e in cells[k]:
					var x = Geometry2D.segment_intersects_segment(o, end, e[0], e[1])
					if x != null and o.distance_to(x) > near and o.distance_to(x) < best:
						best = o.distance_to(x)
						hit = x
		t += 25.0
	return hit


## Road sampling helpers shared by the street dressing: [curve, sorted section keys, elevation spline].
static func road_frame(road: RoadPath) -> Array:
	var c = road.working_curve()
	var keys = road.sections.duplicate()
	keys.sort_custom(func(a, b): return a.at < b.at)
	var spline = (
		RoadBuilder.elevation_spline(road.elevation_keys, c.get_baked_length(), road.closed)
		if not road.elevation_keys.is_empty()
		else []
	)
	return [c, keys, spline]


## Open ground add_city() keeps clear (lakefront, parks, river corridor), and landmark sightlines.
## Route offsets [from, to] of the Upper Wacker riverfront (route rows "Upper Wacker riverfront" to the
## Michigan approach), where the river lies on the left of the lap.
static func river_span(road: RoadPath) -> Vector2:
	var grid = road.get_meta("loop_grid", false)
	var rows = data(grid).points
	var a = road.curve.get_closest_offset(world(rows[41 if grid else 30]))
	var b = road.curve.get_closest_offset(world(rows[44 if grid else 35]))
	return Vector2(minf(a, b), maxf(a, b))


static func keep_clear(p: Vector3, margin: float) -> bool:
	if p.x > 20 and p.z > -210:
		return true
	if p.z < -250 and p.x > -50:
		return true
	if p.z < -285 and p.z > -400:
		return true
	if p.x < -1110 and p.x > -1250:
		return true
	for key in data().landmarks:
		if p.distance_to(world(data().landmarks[key])) < margin:
			return true
	return false


## An ambientCG CC0 facade/stone set (Color, NormalGL, Roughness at 1K), tiled about every `tile_m` metres.
static func cc0_material(folder: String) -> StandardMaterial3D:
	var mat = material(Color.WHITE)
	mat.albedo_texture = load(TEXTURE_ROOT + folder + "/" + folder + "_color.jpg")
	mat.normal_enabled = true
	mat.normal_texture = load(TEXTURE_ROOT + folder + "/" + folder + "_normal.jpg")
	mat.roughness_texture = load(TEXTURE_ROOT + folder + "/" + folder + "_roughness.jpg")
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	mat.uv1_triplanar = true
	mat.uv1_world_triplanar = true
	mat.uv1_scale = Vector3(1.0 / 9.0, 1.0 / 9.0, 1.0 / 9.0)
	return mat


## A street wall of textured mid-rise blocks between the road and the skyline massing (which stays 65 m
## back), so the route is lined by buildings as a real Loop street is. No collision: the barriers
## (WallPath, offset .4) already contain the car.
static func add_street_walls(asset: Node3D, parent: Node, road: RoadPath) -> void:
	var f = road_frame(road)
	var c = f[0]
	var length = c.get_baked_length()
	var mats = [
		cc0_material("Facade001"),
		cc0_material("Facade009"),
		cc0_material("Granite002A"),
		cc0_material("Travertine009")
	]
	var rng = RandomNumberGenerator.new()
	rng.seed = 312
	var holder = Node3D.new()
	attach(asset, parent, holder, "StreetWalls")
	var count = 0
	var s = 30.0
	while s < length - 30.0:
		for side in [-1, 1]:
			var e = RoadBuilder.beyond_edge(c, f[1], road.closed, f[2], s, side, 22.0)
			var p = road.transform * e.point
			if p.y < 3.0 or keep_clear(p, 90.0):
				continue
			# Never over another part of the route (bends, the parallel decks).
			var near = c.get_closest_point(p)
			if Vector2(near.x - p.x, near.z - p.z).length() < 17.0:
				continue
			var h = rng.randf_range(18.0, 46.0)
			var size = Vector3(rng.randf_range(34.0, 52.0), h, rng.randf_range(16.0, 22.0))
			var mesh = BoxMesh.new()
			mesh.size = size
			var out = e.outward
			out.y = 0.0
			var basis = Basis.looking_at(-out.normalized(), Vector3.UP)
			var node = MeshInstance3D.new()
			node.mesh = mesh
			node.material_override = mats[rng.randi() % mats.size()]
			node.transform = Transform3D(basis, p + Vector3(0, h * 0.5 - 1.0, 0))
			node.visibility_range_end = 900.0
			attach(asset, holder, node, "Block%03d" % count)
			count += 1
		s += rng.randf_range(58.0, 76.0)
	asset.set_meta("street_walls", count)


## Parked Kenney cars along the kerbside behind the barriers, on straight stretches only.
static func add_parked_cars(asset: Node3D, parent: Node, road: RoadPath) -> void:
	var f = road_frame(road)
	var c = f[0]
	var length = c.get_baked_length()
	# CHI-LOOK-01: one MultiMesh per car model and 400 m chunk instead of a node per car (825 draw calls
	# in the worst view before), still culled beyond 320 m.
	var pieces = []
	for m in PARKED:
		var root = load("res://assets/chicago/cars-q/%s.glb" % m).instantiate()
		var model = []
		for mi in root.find_children("*", "MeshInstance3D", true, false):
			var local = Transform3D.IDENTITY
			var node: Node3D = mi
			while node != null and node != root:
				local = node.transform * local
				node = node.get_parent() as Node3D
			model.append([mi.mesh, local])
		root.free()
		pieces.append(model)
	var rng = RandomNumberGenerator.new()
	rng.seed = 60601
	var holder = Node3D.new()
	attach(asset, parent, holder, "ParkedCars")
	var groups = {}
	var count = 0
	var s = 40.0
	while s < length - 40.0:
		var a = RoadBuilder.station_at(c, road.closed, length, f[2], s - 15.0).tangent
		var b = RoadBuilder.station_at(c, road.closed, length, f[2], s + 15.0).tangent
		if a.dot(b) > 0.995 and rng.randf() < 0.75:
			var side = -1 if rng.randf() < 0.5 else 1
			var river = river_span(road)
			if side == -1 and s > river.x and s < river.y:
				side = 1
			var e = RoadBuilder.beyond_edge(c, f[1], road.closed, f[2], s, side, 3.4)
			var p = road.transform * e.point
			var fwd = b
			fwd.y = 0.0
			if rng.randf() < 0.5:
				fwd = -fwd
			if not keep_clear(p, 40.0) and fwd.length_squared() > 1e-4:
				var model = rng.randi() % pieces.size()
				# Quaternius cars are real-scale (3.3-4.2 m) along +Z.
				var basis = Basis.looking_at(-fwd.normalized(), Vector3.UP).scaled(Vector3.ONE * 1.08)
				var key = Vector3i(model, floori(p.x / 400.0), floori(p.z / 400.0))
				if not groups.has(key):
					groups[key] = []
				groups[key].append(Transform3D(basis, p))
				count += 1
		s += rng.randf_range(11.0, 26.0)
	for key in groups:
		var list: Array = groups[key]
		var piece_index = 0
		for piece in pieces[key.x]:
			var instances = MultiMesh.new()
			instances.transform_format = MultiMesh.TRANSFORM_3D
			instances.mesh = piece[0]
			instances.instance_count = list.size()
			for i in list.size():
				instances.set_instance_transform(i, list[i] * piece[1])
			var node = MultiMeshInstance3D.new()
			node.multimesh = instances
			node.visibility_range_end = 320.0
			node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			attach(asset, holder, node, "Cars_%d_%d_%d_%d" % [key.x, key.y, key.z, piece_index])
			piece_index += 1
	asset.set_meta("parked_cars", count)
