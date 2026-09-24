extends RefCounted
## Look-2 sodium lamps for TrackAssets ("Afterhours", docs/ART-DIRECTION.md). A road-following
## placement helper that generators (and Look-4's scenery dressing) call with a RoadPath, a base
## spacing and denser zones:
##
##   var lamps = TrackLights.place(road, 60.0, [{"from_m": 6800.0, "to_m": 200.0, "spacing": 24.0}])
##   TrackLights.build(asset, road, lamps)
##
## `build` bakes Lights/ under the asset: poles, arms and emissive heads as one MultiMesh per ~400 m
## chunk (two surfaces), and camera-facing halos (shaders/sodium_halo.gdshader) as another. No light
## nodes are baked; the game moves a small pool of SpotLight3Ds to the lamps nearest the camera
## (`make_pool` / `update_pool`). The road's amber streaks (shaders/road_v2.gdshader) are read from a
## per-road lamp texture written here, so each streak sits under a lamp that is really there.
## Lights/ is hidden by day (`set_night`).

const Ps2Materials = preload("res://scripts/track/ps2_materials.gd")
const RoadBuilder = preload("res://scripts/track/road_builder.gd")
const HALO_SHADER = preload("res://shaders/sodium_halo.gdshader")
const SODIUM = Color("ffb45a")
## Pole height to the arm, arm reach towards the road, metres.
const HEIGHT = 9.0
const ARM = 2.4
## Metres of road per lamp-texture texel, lamps per texel (two per RGBA row), and streak half-length.
const CELL = 4.0
const ROWS = 3
const REACH = 29.0
## Lamps are grouped into chunks this long (metres of road) so each MultiMesh can be culled.
const CHUNK = 400.0
## Pooled real lights: count, and how far each reaches.
const POOL = 4
const POOL_RANGE = 32.0


## Lamp placements along `road` every `spacing` metres, alternating sides. `zones` override spacing and
## sides over a range of stations: {from_m, to_m (wraps on a closed road), spacing, sides}, where sides
## is "alternate" (default), "both", "left" or "right". `extra` is how far beyond the verge edge the
## pole stands (keep it outside the walls; a zone may override it). `height_at` (Callable(Vector3) ->
## float) drops the pole base onto terrain. Lamps that would stand on another part of the road are
## dropped. Returns [{s, side, base, basis, head, strength}] with `side` -1 left, +1 right and
## `strength` the lamp's share of the road glow (lower in dense zones, whose streaks overlap).
static func place(
	road: Node, spacing: float, zones: Array = [], extra = 5.5, height_at = Callable()
) -> Array:
	var curve = road.working_curve()
	var length = curve.get_baked_length()
	var keys = road.sections.duplicate()
	keys.sort_custom(func(a, b): return a.at < b.at)
	var spline = (
		RoadBuilder.elevation_spline(road.elevation_keys, length, road.closed)
		if not road.elevation_keys.is_empty()
		else []
	)
	var clearance = _clearance_grid(road)
	var out = []
	var turn = 0
	var s = 0.0
	while s < length - 1e-3:
		var zone = zone_at(zones, s, length)
		var step = float(zone.get("spacing", spacing))
		var sides = str(zone.get("sides", "alternate"))
		var signs = [-1, 1] if sides == "both" else ([-1] if sides == "left" else [1])
		if sides == "alternate":
			signs = [-1 if turn % 2 == 0 else 1]
			turn += 1
		for sign in signs:
			var lamp = _lamp(road, curve, keys, spline, s, sign, float(zone.get("extra", extra)), height_at)
			# Dense rows overlap their streaks, so each lamp there is dimmer on the road.
			lamp["strength"] = clampf(step / 50.0, .4, 1.0) / (1.4 if signs.size() > 1 else 1.0)
			if _clear(clearance, lamp.base, s, length, road.closed):
				out.append(lamp)
		if road.closed and length - s < step * .5:
			break
		s += step
	return out


## The zone covering station s (the last matching one), or an empty dictionary.
static func zone_at(zones: Array, s: float, length: float) -> Dictionary:
	var found = {}
	for zone in zones:
		var a = fposmod(float(zone.from_m), length)
		var b = fposmod(float(zone.to_m), length)
		if (s >= a and s < b) if a <= b else (s >= a or s < b):
			found = zone
	return found


static func _lamp(road, curve, keys, spline, s, sign, extra, height_at) -> Dictionary:
	var e = RoadBuilder.beyond_edge(curve, keys, road.closed, spline, s, sign, extra)
	var base = road.transform * e.point
	if height_at.is_valid():
		base.y = height_at.call(base)
	var inward = -(road.transform.basis * e.outward)
	inward.y = 0.0
	inward = inward.normalized()
	var basis = Basis(Vector3.UP.cross(inward), Vector3.UP, inward)
	var head = base + Vector3.UP * (HEIGHT - .32) + inward * ARM
	return {"s": s, "side": sign, "base": base, "basis": basis, "head": head}


## Road centre points bucketed on a 24 m grid, with their stations, for the lamp clearance test.
static func _clearance_grid(road) -> Dictionary:
	var grid = {}
	var center = road.last_bake.get("center", PackedVector3Array())
	var stations = road.last_bake.get("stations", [])
	for i in mini(center.size(), stations.size()):
		var p = road.transform * center[i]
		var key = Vector2i(floori(p.x / 24.0), floori(p.z / 24.0))
		if not grid.has(key):
			grid[key] = []
		grid[key].append(Vector3(p.x, p.z, stations[i].s))
	return grid


## A lamp is clear unless a part of the road more than 80 m away along it passes within 13 m.
static func _clear(grid: Dictionary, base: Vector3, s: float, length: float, closed: bool) -> bool:
	var cx = floori(base.x / 24.0)
	var cz = floori(base.z / 24.0)
	for dx in range(-1, 2):
		for dz in range(-1, 2):
			for p in grid.get(Vector2i(cx + dx, cz + dz), []):
				var ds = absf(p.z - s)
				if closed:
					ds = minf(ds, length - ds)
				if ds > 80.0 and Vector2(p.x - base.x, p.y - base.z).length() < 13.0:
					return false
	return true


## Bake `lamps` into the asset's Lights/ node (created if missing; later calls add to it) and write the
## road's streak texture. Pass `streaks` false for lamps that do not light `road` (car parks, paddock).
static func build(asset: Node3D, road: Node, lamps: Array, streaks = true) -> Node3D:
	var lights = asset.get_node_or_null("Lights")
	if lights == null:
		lights = Node3D.new()
		lights.name = "Lights"
		asset.add_child(lights)
		lights.owner = asset
	var heads: PackedVector3Array = lights.get_meta("lamp_heads", PackedVector3Array())
	var chunks = {}
	for lamp in lamps:
		var key = floori(lamp.s / CHUNK)
		if not chunks.has(key):
			chunks[key] = []
		chunks[key].append(lamp)
		heads.append(lamp.head)
	var first = lights.get_child_count()
	var fixture = fixture_mesh()
	var halo = QuadMesh.new()
	halo.size = Vector2(6.0, 6.0)
	halo.material = halo_material()
	var index = 0
	for key in chunks:
		var group = Node3D.new()
		group.name = "Lamps%03d" % (first + index)
		lights.add_child(group)
		group.owner = asset
		var xforms = []
		var halos = []
		for lamp in chunks[key]:
			xforms.append(Transform3D(lamp.basis, lamp.base))
			halos.append(Transform3D(Basis.IDENTITY, lamp.head - Vector3.UP * .12))
		_multimesh(group, "Fixtures", fixture, xforms, asset)
		_multimesh(group, "Halos", halo, halos, asset)
		index += 1
	lights.set_meta("lamp_heads", heads)
	lights.set_meta("lamp_count", heads.size())
	if streaks:
		var meta = "streaks_" + str(road.name)
		var packed: PackedVector3Array = lights.get_meta(meta, PackedVector3Array())
		for lamp in lamps:
			packed.append(Vector3(lamp.s, lamp.side, lamp.get("strength", 1.0)))
		lights.set_meta(meta, packed)
		apply_streaks(asset, road, packed)
	return lights


static func _multimesh(parent: Node3D, title: String, mesh: Mesh, xforms: Array, owner_node: Node) -> void:
	var mm = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
	var node = MultiMeshInstance3D.new()
	node.name = title
	node.multimesh = mm
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.visibility_range_end = 700.0
	node.extra_cull_margin = 4.0
	parent.add_child(node)
	node.owner = owner_node


## One lamp in its local frame (origin at the verge point, +Y up, +Z towards the road): a galvanised
## pole reaching 6 m below the verge so it meets falling ground, an arm, and the sodium lens under the head as a second, emissive surface.
static func fixture_mesh() -> ArrayMesh:
	var mesh = ArrayMesh.new()
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_box(st, Vector3(0, (HEIGHT - 6.0) * .5, 0), Vector3(.22, HEIGHT + 6.0, .22))
	_box(st, Vector3(0, HEIGHT - .08, ARM * .5), Vector3(.13, .15, ARM + .2))
	_box(st, Vector3(0, HEIGHT - .16, ARM), Vector3(.62, .2, 1.05))
	st.generate_normals()
	var metal = StandardMaterial3D.new()
	metal.albedo_color = Color("2a2c33")
	metal.metallic = .4
	metal.roughness = .6
	st.set_material(metal)
	st.commit(mesh)
	st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_box(st, Vector3(0, HEIGHT - .3, ARM), Vector3(.5, .08, .88))
	st.generate_normals()
	var lens = StandardMaterial3D.new()
	lens.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	lens.albedo_color = Color("ffd08a")
	lens.disable_fog = true
	st.set_material(lens)
	st.commit(mesh)
	return mesh


static func halo_material() -> ShaderMaterial:
	var mat = ShaderMaterial.new()
	mat.shader = HALO_SHADER
	mat.set_shader_parameter("lamp_colour", Color("ffbf70"))
	return mat


static func _box(st: SurfaceTool, c: Vector3, size: Vector3) -> void:
	var h = size * .5
	var faces = [
		[Vector3(1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, 1)],
		[Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 1, 0)],
		[Vector3(0, 1, 0), Vector3(0, 0, 1), Vector3(1, 0, 0)],
		[Vector3(0, -1, 0), Vector3(1, 0, 0), Vector3(0, 0, 1)],
		[Vector3(0, 0, 1), Vector3(1, 0, 0), Vector3(0, 1, 0)],
		[Vector3(0, 0, -1), Vector3(0, 1, 0), Vector3(1, 0, 0)],
	]
	for f in faces:
		var n = f[0] * h
		var u = f[1] * h
		var v = f[2] * h
		var a = c + n - u - v
		var b = c + n + u - v
		var d = c + n + u + v
		var e = c + n - u + v
		# u x v = n for every face, so a, d, b winds clockwise seen from outside (Godot's front face).
		for p in [a, d, b, a, e, d]:
			st.add_vertex(p)


## Nearest-lamp texture for road_v2.gdshader: texel x covers CELL metres of station; each of ROWS rows
## holds two lamps (station, side * strength), the ROWS * 2 nearest within reach, nearest first.
static func streak_texture(lamps: PackedVector3Array, length: float, closed: bool) -> ImageTexture:
	var width = maxi(1, ceili(length / CELL))
	var candidates = []
	candidates.resize(width)
	for i in width:
		candidates[i] = []
	var span = ceili((REACH + CELL) / CELL)
	for lamp in lamps:
		var centre = floori(lamp.x / CELL)
		for k in range(centre - span, centre + span + 1):
			var i = posmod(k, width) if closed else k
			if i < 0 or i >= width:
				continue
			var at = (i + .5) * CELL
			var d = absf(at - lamp.x)
			if closed:
				d = minf(d, length - d)
			if d <= REACH + CELL:
				candidates[i].append([d, lamp])
	var image = Image.create(width, ROWS, false, Image.FORMAT_RGBAF)
	for i in width:
		var near = candidates[i]
		near.sort_custom(func(a, b): return a[0] < b[0])
		for row in ROWS:
			var c = Color(-1e5, 0.0, -1e5, 0.0)
			if near.size() > row * 2:
				var l = near[row * 2][1]
				c.r = l.x
				c.g = l.y * l.z
			if near.size() > row * 2 + 1:
				var l = near[row * 2 + 1][1]
				c.b = l.x
				c.a = l.y * l.z
			image.set_pixel(i, row, c)
	return ImageTexture.create_from_image(image)


## Give `road`'s tarmac its own copy of the road_v2 material carrying this lamp texture.
static func apply_streaks(asset: Node3D, road: Node, lamps: PackedVector3Array) -> void:
	var node = asset.get_node_or_null("Road/" + str(road.name))
	if not (node is MeshInstance3D) or node.mesh == null:
		return
	var length = float(road.last_bake.get("length", road.working_curve().get_baked_length()))
	var texture = streak_texture(lamps, length, road.closed)
	for i in node.mesh.get_surface_count():
		var mat = node.mesh.surface_get_material(i)
		if mat is ShaderMaterial and mat.shader == Ps2Materials.ROAD_SHADER:
			if mat == Ps2Materials.surface(Ps2Materials.TARMAC):
				mat = mat.duplicate()
				node.mesh.surface_set_material(i, mat)
			mat.set_shader_parameter("lamp_data", texture)
			mat.set_shader_parameter("lamp_map", true)
			mat.set_shader_parameter("lamp_cell", CELL)
			mat.set_shader_parameter("lamp_reach", REACH)
			mat.set_shader_parameter("road_length", length if road.closed else 0.0)


## Show the asset's lamps at night only.
static func set_night(asset: Node, night: bool) -> void:
	var lights = asset.get_node_or_null("Lights") if asset != null else null
	if lights is Node3D:
		lights.visible = night


## The real-light pool: a few downward sodium spots, no shadows, parented to `parent`.
static func make_pool(parent: Node, count = POOL) -> Array:
	var pool = []
	for i in count:
		var light = SpotLight3D.new()
		light.name = "SodiumPool%d" % i
		light.rotation.x = -PI / 2
		light.light_color = SODIUM
		light.light_energy = 0.0
		light.light_specular = .6
		light.spot_range = POOL_RANGE
		light.spot_angle = 64.0
		light.spot_attenuation = .8
		light.spot_angle_attenuation = 1.4
		light.shadow_enabled = false
		light.visible = false
		parent.add_child(light)
		pool.append(light)
	return pool


## Move the pool to the lamps nearest `eye`. Each light fades to zero as its lamp's distance reaches the
## next-nearest lamp left out of the pool, so reassigning a light never pops.
static func update_pool(pool: Array, asset: Node, eye: Vector3, night: bool, energy = 3.2) -> void:
	var lights = asset.get_node_or_null("Lights") if asset != null else null
	var heads: PackedVector3Array = (
		lights.get_meta("lamp_heads", PackedVector3Array()) if lights != null else PackedVector3Array()
	)
	if not night or heads.is_empty():
		for light in pool:
			light.visible = false
		return
	var near = []
	for i in heads.size():
		var d = heads[i].distance_squared_to(eye)
		if near.size() <= pool.size() or d < near[-1][0]:
			near.append([d, i])
			near.sort_custom(func(a, b): return a[0] < b[0])
			if near.size() > pool.size() + 1:
				near.pop_back()
	var cutoff = sqrt(near[-1][0]) if near.size() > pool.size() else 1e9
	for k in pool.size():
		var light = pool[k]
		if k >= near.size() or k >= heads.size():
			light.visible = false
			continue
		var d = sqrt(near[k][0])
		var fade = clampf((cutoff - d) / 15.0, 0.0, 1.0) * (1.0 - smoothstep(90.0, 140.0, d))
		light.visible = fade > 0.0
		light.global_position = heads[near[k][1]]
		light.light_energy = energy * fade
