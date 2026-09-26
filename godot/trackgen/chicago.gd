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
const PARKED = ["taxi", "sedan", "sedan-sports", "suv", "police", "delivery", "van"]
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
const CACHE_REVISION = 110
const TEXTURE_ROOT = "res://assets/textures/chicago/"
const WATER_SHADER = preload("res://shaders/chicago_water.gdshader")


static func data() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(DATA))


static func world(row: Array) -> Vector3:
	# Local tangent plane, +X east / +Z south, in metres. No float32 world-state accumulation.
	return Vector3((row[1] + 87.6244) * 82860.0, row[2], (41.8848 - row[0]) * 111320.0)


static func points() -> Array[Vector3]:
	var out: Array[Vector3] = []
	for row in data().points:
		out.append(world(row))
	return out


static func route_curve() -> Curve3D:
	# Tangent-continuous fillets; 55 m setback on broad junctions, reduced on short blocks.
	var p = points()
	var c = Curve3D.new()
	c.bake_interval = .25
	for i in p.size():
		var before = p[i] - p[posmod(i - 1, p.size())]
		var after = p[(i + 1) % p.size()] - p[i]
		var a = before.normalized()
		var b = after.normalized()
		var angle = acos(clampf(a.dot(b), -1.0, 1.0))
		var cut = minf(55.0, minf(before.length(), after.length()) * .3)
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
	mesh.material = mat
	var instances = MultiMesh.new()
	instances.transform_format = MultiMesh.TRANSFORM_3D
	instances.mesh = mesh
	instances.instance_count = entries.size()
	for i in entries.size():
		var entry = entries[i]
		var basis: Basis = entry[2] if entry.size() > 2 else Basis.IDENTITY
		instances.set_instance_transform(i, Transform3D(basis.scaled(entry[1]), entry[0]))
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


static func build_asset() -> Node3D:
	var asset = TrackAsset.new()
	asset.name = "Chicago"
	asset.id = "chicago"
	asset.display_name = "Chicago — River & Lake"
	asset.version = 2
	asset.default_time_of_day = "day"
	var road = RoadPath.new()
	road.name = "Main"
	road.curve = route_curve()
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
	attach(asset, asset, road, "Main")
	road.bake()
	var corners = {}
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
		wall.offset = .4
		wall.step_m = 3.0
		attach(asset, asset, wall, "LeftBarrier" if side == WallPath.Side.LEFT else "RightBarrier")
		wall.bake()
	var scenery = Node3D.new()
	attach(asset, asset, scenery, "Scenery")
	# CHI-SC-1: debris fencing on top of both barriers, the look of a street circuit (Long Beach, Macau, NFSU's
	# closed-street courses); without it the route read as a grey blockout. Visual only (the barrier keeps
	# collision). Baked after Scenery exists: CatchFence parents its mesh under Scenery and would otherwise
	# create its own, renaming the city's node (and losing Scenery/CentennialWheel etc.).
	for barrier in ["LeftBarrier", "RightBarrier"]:
		var fence = CatchFence.new()
		fence.follow_wall = NodePath("../" + barrier)
		fence.side = WallPath.Side.LEFT if barrier == "LeftBarrier" else WallPath.Side.RIGHT
		fence.offset = 0.0
		fence.post_spacing = 4.0
		fence.fence_height = 3.2
		fence.solid = false
		attach(asset, asset, fence, barrier + "Fence")
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
	add_night_details(asset, scenery, road)
	# CHI-LOOK-01: signals, crosswalks and stop lines at the cross streets.
	ChicagoFurniture.build(asset, scenery, road.last_bake.stations, facade_box, night_material, attach)
	ChicagoKit.sidewalk_props(asset, scenery, road.last_bake.stations)
	# Ground-like scenery casts no useful shadow; it only costs shadow-pass draws (CHI-LOOK-02).
	for node in scenery.get_children():
		for prefix in NO_SHADOW:
			if node is GeometryInstance3D and str(node.name).begins_with(prefix):
				node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_park_trees(asset)
	add_lakefront_trees(asset)
	# Prelim city dressing from the CHI-assets-prep CC0 staging: textured street walls and parked cars.
	add_parked_cars(asset, scenery, road)
	# Headless and windowed scenes have distinct caches (TrackDrive). No runtime downloads.
	var lamps = TrackLights.place(road, 42.0, lower_level_zones(road), 1.2)
	# Lower Wacker's fixtures hang below the deck; no 10 m poles through the upper roadway.
	for lamp in lamps:
		if lamp.base.y < 3.0:
			lamp.head.y -= lamp.height - 4.8
			lamp.height = 4.8
	TrackLights.build(asset, road, lamps)
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
	# The Riverwalk runs along the water below both road levels (CHI-SC-4): at street height (8.2) these slabs
	# crossed Upper Wacker 0.4 m above the road.
	box(
		asset, parent, "RiverwalkPromenade", world([41.8871, -87.6261, -1.5]), Vector3(22, .3, 170), pier_walk
	)
	box(
		asset,
		parent,
		"RiverwalkPromenadeWest",
		world([41.8870, -87.6309, -1.5]),
		Vector3(16, .3, 135),
		pier_walk
	)


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
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Recognizable nine-tube stepped silhouette with twin antennae, original geometry.
	for x in 3:
		for z in 3:
			var h = 442.0 if x == 1 and z == 1 else (350.0 if x == 1 or z == 1 else 220.0)
			var p = willis + Vector3((x - 1) * 22, h * .5, (z - 1) * 22)
			facade_box(st, p, Vector3(22, h, 22), Color("252c31"))
			for floor_i in range(1, int(h / 4.0)):
				facade_box(
					st,
					Vector3(p.x, willis.y + floor_i * 4.0, p.z),
					Vector3(22.12, .7, 22.12),
					Color("697778")
				)
	st.generate_normals()
	var mesh = st.commit()
	var facade = NightGlow.facade_material().duplicate()
	facade.set_shader_parameter("window_scale", 3.8)
	facade.set_shader_parameter("lit_chance", .22)
	facade.set_shader_parameter("glow_energy", .45)
	mesh.surface_set_material(0, facade)
	mesh_node(asset, parent, "WillisTower", mesh, Vector3.ZERO)
	for side in [-1, 1]:
		box(
			asset,
			parent,
			"WillisAntenna%d" % side,
			willis + Vector3(side * 9, 475, 0),
			Vector3(2, 66, 2),
			silver
		)
	# The Bean: a deliberately stylized reflective arch, open underneath; no scanned sculpture asset.
	var bean = world(data().landmarks["Bean"])
	box(asset, parent, "CloudGatePlaza", bean + Vector3(0, -.1, 0), Vector3(70, .3, 60), stone)
	var sphere = SphereMesh.new()
	sphere.radius = 5.0
	sphere.height = 10.0
	sphere.radial_segments = 40
	sphere.rings = 24
	var arrays = sphere.get_mesh_arrays()
	var vertices = arrays[Mesh.ARRAY_VERTEX]
	for i in vertices.size():
		var v = vertices[i]
		var underside = 5.5 * pow(maxf(0.0, -v.y / 5.0), 4.0)
		vertices[i] = Vector3(v.x * 3.0, v.y + underside, v.z * 1.8)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	var bean_mesh = ArrayMesh.new()
	bean_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var bean_tool = SurfaceTool.new()
	bean_tool.create_from(bean_mesh, 0)
	bean_tool.generate_normals()
	bean_mesh = bean_tool.commit()
	bean_mesh.surface_set_material(0, silver)
	mesh_node(asset, parent, "BeanArch", bean_mesh, bean + Vector3(0, 2.5, 0))
	# Navy Pier: long low pier, pavilion sheds and the Centennial Wheel silhouette.
	var pier = world(data().landmarks["Navy Pier"])
	box(asset, parent, "NavyPier", pier + Vector3(190, -.5, 0), Vector3(800, 2, 80), stone)
	for i in 6:
		box(asset, parent, "PierPavilion%d" % i, pier + Vector3(i * 95, 9, 0), Vector3(80, 18, 48), stone)
	var wheel = TorusMesh.new()
	wheel.inner_radius = 28
	wheel.outer_radius = 29.5
	wheel.rings = 48
	wheel.ring_segments = 6
	wheel.material = night_material(Color("b5dce6"), 2.2)
	var wn = mesh_node(asset, parent, "CentennialWheel", wheel, pier + Vector3(0, 33, 0))
	wn.rotation_degrees.x = 90
	for i in 16:
		var ang = TAU * i / 16.0
		var end = pier + Vector3(cos(ang) * 28, 33 + sin(ang) * 28, 0)
		var spoke = box(
			asset,
			parent,
			"WheelSpoke%d" % i,
			(end + pier + Vector3(0, 33, 0)) * .5,
			Vector3(.5, 28, .5),
			night_material(Color("96c8e0"), 1.3)
		)
		spoke.rotation.z = ang - PI / 2
		box(
			asset,
			parent,
			"WheelCabin%d" % i,
			end,
			Vector3(3.2, 3.8, 3.2),
			night_material(Color("77b6cc"), 1.0)
		)
	for side in [-1, 1]:
		var support = box(
			asset, parent, "WheelSupport%d" % side, pier + Vector3(side * 7, 15, 0), Vector3(2, 33, 2), silver
		)
		support.rotation.z = side * .4
	add_loop_landmarks(asset, parent, stone, dark, silver)


## A landmark tower with the city's window-grid facade shader (perimeter UVs) instead of a plain box.
## `center` is the middle of the block at half its height, as for `box`.
static func facade_block(
	asset: Node3D,
	parent: Node,
	title: String,
	center: Vector3,
	size: Vector2,
	h: float,
	kind: String,
	seed: float
) -> void:
	var ring = PackedVector2Array(
		[
			Vector2(center.x - size.x * .5, center.z - size.y * .5),
			Vector2(center.x + size.x * .5, center.z - size.y * .5),
			Vector2(center.x + size.x * .5, center.z + size.y * .5),
			Vector2(center.x - size.x * .5, center.z + size.y * .5)
		]
	)
	var base_y = center.y - h * .5
	var facade = SurfaceTool.new()
	facade.begin(Mesh.PRIMITIVE_TRIANGLES)
	# ChicagoCity's top is STREET_Y + its h; the block starts at its own base (kept off the lower level).
	var layer = ChicagoCity.kind_layer(kind)
	ChicagoCity._building(facade, facade, ring, h + base_y - ChicagoCity.STREET_Y, seed, base_y, layer)
	facade.set_material(ChicagoCity.material(kind))
	var mesh = facade.commit()
	mesh_node(asset, parent, title, mesh, Vector3.ZERO)


static func add_loop_landmarks(
	asset: Node3D, parent: Node, stone: Material, dark: Material, silver: Material
) -> void:
	# Wrigley Building: twin cream glazed-terra-cotta towers and clock crown.
	# CHI-LOOK-01: on the east side of Michigan Avenue, as in the city; it stood on the Michigan turn's road.
	var wrigley = world([41.8882, -87.6246, 8]) + ChicagoCity.WRIGLEY_OFFSET
	var terra_cotta_bands: Array = []
	for tower in [[-31.0, 138.0, 35.0], [27.0, 91.0, 31.0]]:
		var center = wrigley + Vector3(tower[0], tower[1] * .5, 0)
		facade_block(asset, parent, "WrigleyTower", center, Vector2(24, 28), tower[1], "stone", 0.31)
		for floor_i in range(4, int(tower[1] / 4.0), 4):
			terra_cotta_bands.append([wrigley + Vector3(tower[0], floor_i, 0), Vector3(25, .65, 29)])
		var cap = PrismMesh.new()
		cap.size = Vector3(28, 8, 32)
		cap.material = stone
		mesh_node(asset, parent, "WrigleyCrown", cap, wrigley + Vector3(tower[0], tower[1] + 4, 0))
	multimesh_boxes(asset, parent, "WrigleyTerraCottaBands", material(Color("e5ddc7")), terra_cotta_bands)
	box(
		asset,
		parent,
		"WrigleyClock",
		wrigley + Vector3(-30, 112, 15),
		Vector3(7, 7, .8),
		night_material(Color("f0dfb1"), .75)
	)
	# Tribune Tower: pale neo-Gothic vertical piers with a steep central spire.
	var tribune = world([41.8905, -87.6230, 8])
	var tribune_piers: Array = []
	var tribune_spandrels: Array = []
	facade_block(
		asset, parent, "TribuneTower", tribune + Vector3(0, 61, 0), Vector2(42, 50), 122.0, "stone", 0.62
	)
	for x in [-19.0, 19.0]:
		for z in [-23.0, 23.0]:
			tribune_piers.append([tribune + Vector3(x, 64, z), Vector3(4, 128, 4)])
	for floor_i in range(8, 112, 12):
		tribune_spandrels.append([tribune + Vector3(0, floor_i, 0), Vector3(44, 2, 52)])
	multimesh_boxes(asset, parent, "TribuneGothicPiers", material(Color("d8d3c5")), tribune_piers)
	multimesh_boxes(asset, parent, "TribuneSpandrels", material(Color("dcd6c8")), tribune_spandrels)
	var spire = PrismMesh.new()
	spire.size = Vector3(27, 40, 32)
	spire.material = dark
	mesh_node(asset, parent, "TribuneSpire", spire, tribune + Vector3(0, 139, 0))
	# Board of Trade at LaSalle: symmetrical Art Deco setbacks and pyramid crown.
	var board = world([41.8787, -87.6325, 8])
	var tiers = [[0.0, 100.0, 84.0], [100.0, 48.0, 66.0], [148.0, 36.0, 44.0]]
	for tier in tiers:
		box(
			asset,
			parent,
			"BoardOfTradeSetback",
			board + Vector3(0, tier[1] * .5 + tier[0], 0),
			Vector3(tier[2], tier[1], tier[2] * .78),
			material(Color("b9aa8e"))
		)
		box(
			asset,
			parent,
			"BoardOfTradeCornice",
			board + Vector3(0, tier[1] + tier[0], 0),
			Vector3(tier[2] + 2, 1.8, tier[2] * .78 + 2),
			stone
		)
	var pyramid = PrismMesh.new()
	pyramid.size = Vector3(39, 34, 32)
	pyramid.material = material(Color("8f7959"))
	mesh_node(asset, parent, "BoardOfTradePyramid", pyramid, board + Vector3(0, 169, 0))


static func add_river_bridges(asset: Node3D, parent: Node) -> void:
	var steel = material(Color("36474b"))
	steel.metallic = .7
	steel.roughness = .36
	var stone = material(Color("d1c3a6"))
	var spans = [
		["MichiganAvenueBridge", 41.88865, -87.6245, 90.0],
		["StateStreetBridge", 41.8888, -87.6270, 60.0],
		["LaSalleStreetBridge", 41.8888, -87.6290, 58.0]
	]
	var steel_boxes: Array = []
	var deck_boxes: Array = []
	var house_boxes: Array = []
	# CHI-LOOK-01: the bridges run north-south across the east-west river (they were laid along it), and sit
	# under the street level instead of 1.2 m above it. Bridge houses stand at the far (north) corners only,
	# clear of the Michigan turn.
	for span in spans:
		var anchor = world([span[1], span[2], 8]) + Vector3(0, -1.25, 0)
		var length: float = span[3]
		deck_boxes.append([anchor, Vector3(23, 2.4, length)])
		for side in [-1, 1]:
			steel_boxes.append([anchor + Vector3(side * 10.4, 8, 0), Vector3(1.1, 1.1, length)])
			for i in range(0, int(length), 8):
				var z = -length * .5 + i
				steel_boxes.append([anchor + Vector3(side * 10.4, 5.0, z), Vector3(.75, 7.0, .75)])
				steel_boxes.append(
					[
						anchor + Vector3(side * 10.4, 5.0, z + 4),
						Vector3(8.5, .55, .55),
						Basis(Vector3.UP, PI * .5 + 0.74)
					]
				)
		for side in [-1, 1]:
			var house = anchor + Vector3(side * 22, 0, -(length * .5 + 12))
			house_boxes.append([house + Vector3(0, 8, 0), Vector3(18, 16, 21)])
			house_boxes.append([house + Vector3(0, 16.5, 0), Vector3(20, 1.2, 23)])
			var roof = PrismMesh.new()
			roof.size = Vector3(20, 7, 23)
			roof.material = steel
			mesh_node(asset, parent, span[0] + "BridgeHouseRoof", roof, house + Vector3(0, 20, 0))
			steel_boxes.append([house + Vector3(0, 26, 0), Vector3(4, 13, 4)])
			for y in [20.0, 25.0, 31.0]:
				steel_boxes.append([house + Vector3(0, y, 0), Vector3(11, .65, .65)])
	multimesh_boxes(asset, parent, "ChicagoBridgeDecks", material(Color("4b5352")), deck_boxes)
	multimesh_boxes(asset, parent, "ChicagoBridgeSteel", steel, steel_boxes)
	multimesh_boxes(asset, parent, "ChicagoBridgeHouses", stone, house_boxes)


static func add_lower_deck(asset: Node3D, parent: Node, road: RoadPath) -> void:
	var concrete = material(Color("737b79"))
	var st = road.last_bake.stations
	var count = 0
	var deck_tool = SurfaceTool.new()
	deck_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	# CHI-LOOK-01: exposed steel beams and girders under the deck (visual only, no collision), as in real
	# Lower Wacker. They stay above the 6.05 m luminaires' clearance line.
	var beam_tool = SurfaceTool.new()
	beam_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(0, st.size(), 8):
		var at = st[i]
		# Only the lower Wacker road, not the exposed game-only connector at the south end.
		if at.pos.y > .1 or at.pos.z > 720:
			continue
		var tangent = at.tangent
		var basis = Basis.looking_at(tangent, Vector3.UP)
		var p = at.pos + Vector3(0, 6.7, 0)
		facade_box(deck_tool, p, Vector3(23, 1.1, 13), Color.WHITE, basis)
		facade_box(beam_tool, at.pos + Vector3(0, 5.85, 0), Vector3(22.6, 0.6, 0.55), Color.WHITE, basis)
		for side in [-1, 1]:
			var girder = at.pos + basis.x * side * 5.0 + Vector3(0, 5.75, 0)
			facade_box(beam_tool, girder, Vector3(0.45, 0.8, 12.6), Color.WHITE, basis)
		solid_box(asset, "Ceiling%d" % count, Transform3D(basis, p), Vector3(23, 1.1, 13))
		if count % 2 == 0:
			for side in [-1, 1]:
				var post_p = at.pos + basis.x * side * 10.5 + Vector3(0, 3, 0)
				facade_box(deck_tool, post_p, Vector3(1.1, 6, 1.1), Color.WHITE)
				solid_box(
					asset,
					"Column%d_%d" % [count, side],
					Transform3D(Basis.IDENTITY, post_p),
					Vector3(1.1, 6, 1.1)
				)
		count += 1
	deck_tool.generate_normals()
	var deck_mesh = deck_tool.commit()
	deck_mesh.surface_set_material(0, concrete)
	mesh_node(asset, parent, "WackerDeckAndColumns", deck_mesh, Vector3.ZERO)
	beam_tool.generate_normals()
	var beam_mesh = beam_tool.commit()
	beam_mesh.surface_set_material(0, material(Color("3f4443")))
	mesh_node(asset, parent, "WackerBeams", beam_mesh, Vector3.ZERO)


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
		for side in [-1, 1]:
			var pos = at.pos + right * side * 4 + Vector3(0, .012, 0)
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
		var low = RoadBuilder.station_at(c, road.closed, length, f[2], s).pos.y < 3.0
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


static func add_night_details(asset: Node3D, parent: Node, road: RoadPath) -> void:
	var warm = night_material(Color("ffd19a"), 1.7)
	var cool = night_material(Color("a6d6ef"), 1.5)
	# High-pressure sodium orange for Lower Wacker's ceiling fixtures (lower-wacker-drive.jpg).
	var sodium = night_material(Color("ffa540"), 2.0)
	var fixtures = SurfaceTool.new()
	fixtures.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Batched ceiling luminaires stay above the unchanged driving clearance.
	for i in range(0, road.last_bake.stations.size(), 16):
		var at = road.last_bake.stations[i]
		if at.pos.y > .1 or at.pos.z > 720:
			continue
		var basis = Basis.looking_at(at.tangent, Vector3.UP)
		for side in [-1, 1]:
			facade_box(
				fixtures,
				at.pos + basis.x * side * 4 + Vector3(0, 6.05, 0),
				Vector3(.45, .12, 3.6),
				Color.WHITE,
				basis
			)
	fixtures.generate_normals()
	var mesh = fixtures.commit()
	mesh.surface_set_material(0, sodium)
	mesh_node(asset, parent, "WackerCeilingLuminaires", mesh, Vector3.ZERO)
	var pier = world(data().landmarks["Navy Pier"])
	for i in 6:
		box(
			asset,
			parent,
			"PierRoofLight%d" % i,
			pier + Vector3(i * 95, 18.2, 24.2),
			Vector3(80, 1.0, .8),
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
	box(asset, parent, "WillisCrown", willis + Vector3(0, 441, 0), Vector3(22.3, 1.5, 22.3), cool)
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
		var root = load("res://assets/chicago/cars/%s.glb" % m).instantiate()
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
			var e = RoadBuilder.beyond_edge(c, f[1], road.closed, f[2], s, side, 3.4)
			var p = road.transform * e.point
			var fwd = b
			fwd.y = 0.0
			if rng.randf() < 0.5:
				fwd = -fwd
			if not keep_clear(p, 40.0) and fwd.length_squared() > 1e-4:
				var model = rng.randi() % pieces.size()
				# Kenney cars are 2.75 m long along +Z; 1.65 makes a 4.5 m car.
				var basis = Basis.looking_at(-fwd.normalized(), Vector3.UP).scaled(Vector3.ONE * 1.65)
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
