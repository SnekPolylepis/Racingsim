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
const DATA = "res://trackgen/data/chicago/route.json"
const HALF_WIDTH = 8.0
const CACHE_REVISION = 3


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
	asset.version = 1
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
	add_water_and_parks(asset, scenery)
	add_city(asset, scenery, road)
	add_landmarks(asset, scenery)
	add_lower_deck(asset, scenery, road)
	add_road_details(asset, scenery, road)
	add_night_details(asset, scenery, road)
	add_park_trees(asset)
	# Headless and windowed scenes have distinct caches (TrackDrive). No runtime downloads.
	var lamps = TrackLights.place(road, 42.0, [], 1.2)
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


static func add_water_and_parks(asset: Node3D, parent: Node) -> void:
	var concrete = material(Color("686b68"))
	var lawn = material(Color("526744"))
	var water = material(Color("285760"))
	water.roughness = .3
	water.metallic = .35
	box(asset, parent, "CityBase", Vector3(-500, -3.8, 0), Vector3(4000, 1, 4000), concrete)
	box(asset, parent, "LakeMichigan", Vector3(2600, -3, 0), Vector3(3900, .2, 6500), water)
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
			asset, parent, "River%d" % i, (a + b) * .5, Vector3(130, .2, a.distance_to(b) + 40), water
		)
		n.rotation.y = atan2(b.x - a.x, b.z - a.z)
	box(asset, parent, "MillenniumPark", world([41.8821, -87.6226, 7.6]), Vector3(210, .6, 380), lawn)
	box(asset, parent, "GrantPark", world([41.8800, -87.6210, 7.3]), Vector3(440, .5, 260), lawn)
	# Lakefront promenade, remaining east of the race surface.
	box(asset, parent, "Lakefront", world([41.8800, -87.6166, 6.8]), Vector3(65, .5, 470), lawn)


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
	# Michigan bridgehouse silhouettes and riverfront towers mark the transition into the Loop.
	for offset in [-35, 35]:
		var p = world([41.88865, -87.6245, 8]) + Vector3(offset, 0, 0)
		box(asset, parent, "Bridgehouse%d" % offset, p + Vector3(0, 7, 0), Vector3(15, 14, 15), stone)
		var roof = PrismMesh.new()
		roof.size = Vector3(18, 6, 18)
		roof.material = dark
		mesh_node(asset, parent, "BridgeRoof%d" % offset, roof, p + Vector3(0, 17, 0))


static func add_lower_deck(asset: Node3D, parent: Node, road: RoadPath) -> void:
	var concrete = material(Color("737b79"))
	var st = road.last_bake.stations
	var count = 0
	var deck_tool = SurfaceTool.new()
	deck_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(0, st.size(), 8):
		var at = st[i]
		# Only the lower Wacker road, not the exposed game-only connector at the south end.
		if at.pos.y > .1 or at.pos.z > 720:
			continue
		var tangent = at.tangent
		var basis = Basis.looking_at(tangent, Vector3.UP)
		var p = at.pos + Vector3(0, 6.7, 0)
		facade_box(deck_tool, p, Vector3(23, 1.1, 13), Color.WHITE, basis)
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
	mesh.surface_set_material(0, warm)
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
