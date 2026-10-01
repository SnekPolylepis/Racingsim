extends RefCounted
## The real elevated "L": OSM railway=subway bridge tracks (city.json "elevated"), deck at the LiDAR-measured
## 6.3 m above the street, and 8-car trains of CTA 5000-series cars (14.63 x 2.84 x 3.66 m, stainless steel,
## fibreglass end bonnets, two door pairs a side: en.wikipedia.org/wiki/5000-series_(CTA)).
## Visual only; the structure has no collision.

const STREET_Y = 8.0
const DECK_TOP = 6.3
const TRACK_W = 4.0
const GIRDER_H = 1.1
const COLUMN_EVERY = 15.0
const CAR_L = 14.63
const CAR_W = 2.84
const CAR_H = 3.66
const TRAIN_CARS = 8
const TRAIN_EVERY = 5


static func build(asset: Node3D, parent: Node, tracks: Array, train_lines: Array = []) -> int:
	var st = {}
	for key in ["steel", "rail", "body", "glass", "door", "bonnet", "sign"]:
		st[key] = SurfaceTool.new()
		st[key].begin(Mesh.PRIMITIVE_TRIANGLES)
	var road = asset.get_node("Main")
	var stations: Array = road.last_bake.stations
	var keys: Array = road.sections.duplicate()
	keys.sort_custom(func(a, b): return a.at < b.at)
	var widths = PackedFloat32Array()
	for station in stations:
		var sec = road.RoadBuilder.section_at(keys, station.s, road.last_bake.length, road.closed)
		widths.append(maxf(sec.width_left, sec.width_right) + 1.0)
	var deck_y = STREET_Y + DECK_TOP
	var trains = 0
	for t in tracks.size():
		var pts: Array = tracks[t].p
		var line = PackedVector3Array()
		for p in pts:
			line.append(Vector3(p[0], deck_y, p[1]))
		var run = 0.0
		for i in line.size() - 1:
			var a = line[i]
			var b = line[i + 1]
			var seg = a.distance_to(b)
			if seg < 0.05:
				continue
			var mid = (a + b) * .5
			var basis = Basis.looking_at(b - a, Vector3.UP)
			# Deck and the two plate girders under the rails; two rails on top.
			box(st.steel, mid + Vector3(0, -0.2, 0), Vector3(TRACK_W, 0.4, seg + 0.3), basis)
			for side in [-1, 1]:
				box(
					st.steel,
					mid + basis.x * side * (TRACK_W * .5 - .15) + Vector3(0, -GIRDER_H * .5, 0),
					Vector3(0.3, GIRDER_H, seg + 0.3),
					basis
				)
				box(
					st.rail,
					mid + basis.x * side * 0.72 + Vector3(0, 0.08, 0),
					Vector3(0.08, 0.16, seg + 0.3),
					basis
				)
			# Columns down to the street at a steady spacing along the track.
			var d = fmod(COLUMN_EVERY - fmod(run, COLUMN_EVERY), COLUMN_EVERY)
			while d < seg:
				var at = a.lerp(b, d / seg)
				# Keep the trestle deck continuous, but bridge the race road without a support in its lanes.
				if column_clear(Vector3(at.x, STREET_Y, at.z), stations, widths):
					box(
						st.steel,
						Vector3(at.x, STREET_Y + (DECK_TOP - GIRDER_H) * .5, at.z),
						Vector3(0.5, DECK_TOP - GIRDER_H, 0.5),
						basis
					)
				d += COLUMN_EVERY
			run += seg
	var mats = {
		"steel": _mat(Color("4a4f52"), 0.6, 0.55),
		"rail": _mat(Color("6e6a66"), 0.9, 0.4),
		"body": _mat(Color("a1a6a9"), 0.55, 0.6),
		"glass": _mat(Color("1c2126"), 0.2, 0.1),
		"door": _mat(Color("969b9e"), 0.5, 0.58),
		"bonnet": _mat(Color("d8d8d4"), 0.0, 0.5),
		"sign": _mat(Color("ff9a2a"), 0.0, 0.5),
	}
	# Interior lights and the orange LED destination sign glow at night (chicago_night toggles emission).
	for key in ["glass", "sign"]:
		mats[key].emission = Color("ffe2b0") if key == "glass" else Color("ff9a2a")
		mats[key].emission_energy_multiplier = 1.2 if key == "glass" else 3.0
		mats[key].set_meta("chicago_night", true)
	trains = _moving_trains(asset, parent, train_lines, mats)
	var mesh = ArrayMesh.new()
	for key in ["steel", "rail"]:
		st[key].generate_normals()
		st[key].set_material(mats[key])
		st[key].commit(mesh)
	var node = MeshInstance3D.new()
	node.name = "ElevatedL"
	node.mesh = mesh
	parent.add_child(node)
	node.owner = asset
	return trains


static func column_clear(foot: Vector3, stations: Array, widths: PackedFloat32Array) -> bool:
	for i in stations.size():
		var p: Vector3 = stations[i].pos
		if (
			p.y + 3.0 >= foot.y
			and p.y <= foot.y + DECK_TOP - GIRDER_H
			and Vector2(p.x - foot.x, p.z - foot.z).length_squared() < widths[i] * widths[i]
		):
			return false
	return true


## Trains that move (scripts/track/l_trains.gd): one shared 5000-series car mesh, 8 instances per train,
## two trains per chained line at opposite ends, ~11 m/s (about 25 mph).
static func _moving_trains(asset: Node3D, parent: Node, train_lines: Array, mats: Dictionary) -> int:
	if train_lines.is_empty():
		return 0
	var lines = []
	var trains = []
	for li in train_lines.size():
		var line = PackedVector3Array()
		for p in train_lines[li]:
			line.append(Vector3(p[0], STREET_Y + DECK_TOP, p[1]))
		lines.append(line)
		var total = 0.0
		for i in line.size() - 1:
			total += line[i].distance_to(line[i + 1])
		trains.append([li, 0.0, 11.0])
		if total > 900.0:
			trains.append([li, total * .5, 11.0])
	var mm = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = _car_mesh(mats)
	mm.instance_count = trains.size() * TRAIN_CARS
	var node = MultiMeshInstance3D.new()
	node.name = "LTrains"
	node.set_script(preload("res://scripts/track/l_trains.gd"))
	node.multimesh = mm
	node.lines = lines
	node.trains = trains
	node.custom_aabb = AABB(Vector3(-5000, -50, -5000), Vector3(10000, 200, 10000))
	parent.add_child(node)
	node.owner = asset
	return trains.size()


## One car in local space: origin on the rail line at mid-car, -Z forward (Basis.looking_at).
static func _car_mesh(mats: Dictionary) -> ArrayMesh:
	var st = {}
	for key in ["body", "glass", "door", "bonnet", "sign", "rail"]:
		st[key] = SurfaceTool.new()
		st[key].begin(Mesh.PRIMITIVE_TRIANGLES)
	var basis = Basis.IDENTITY
	var body_h = CAR_H - 0.55
	var c = Vector3(0, 0.55 + body_h * .5, 0)
	box(st.body, c, Vector3(CAR_W, body_h, CAR_L - 1.6), basis)
	for e in [-1, 1]:
		box(st.bonnet, c + Vector3(0, 0, e * (CAR_L * .5 - 0.5)), Vector3(CAR_W - 0.05, body_h, 1.0), basis)
		box(st.sign, c + Vector3(0, body_h * .38, e * (CAR_L * .5 + .01)), Vector3(1.4, 0.22, 0.05), basis)
		box(st.glass, c + Vector3(0, .45, e * (CAR_L * .5 + .02)), Vector3(2.1, .85, .05), basis)
		box(
			st.rail,
			c + Vector3(0, -body_h * .5 - 0.25, e * (CAR_L * .5 - 2.4)),
			Vector3(2.2, 0.5, 2.4),
			basis
		)
	for side in [-1, 1]:
		# Separate rubber-framed panes and two door pairs, so the car reads as CTA stock rather than a tube.
		for z in [-5.65, -1.8, 0.0, 1.8, 5.65]:
			box(st.glass, c + Vector3(side * (CAR_W * .5 + .025), .45, z), Vector3(.035, .95, 1.25), basis)
		for dz in [-0.25, 0.25]:
			var at = c + Vector3(side * (CAR_W * .5 + .02), -.2, dz * CAR_L)
			box(st.door, at, Vector3(.02, 2.0, 1.4), basis)
			for split in [-1, 1]:
				box(st.glass, at + Vector3(side * .02, .65, split * .34), Vector3(.025, .8, .5), basis)
		# Stainless lower-body fluting catches light gently below the black window line.
		for y in [-.65, -.82, -.99]:
			box(
				st.door,
				c + Vector3(side * (CAR_W * .5 + .025), y, 0),
				Vector3(.025, .045, CAR_L - 1.7),
				basis
			)
	var mesh = ArrayMesh.new()
	for key in st:
		st[key].generate_normals()
		st[key].set_material(mats[key])
		st[key].commit(mesh)
	return mesh


static func _at(line: PackedVector3Array, s: float) -> Vector3:
	for i in line.size() - 1:
		var seg = line[i].distance_to(line[i + 1])
		if s <= seg:
			return line[i].lerp(line[i + 1], s / maxf(seg, 0.01))
		s -= seg
	return line[line.size() - 1]


static func box(st: SurfaceTool, c: Vector3, size: Vector3, basis: Basis) -> void:
	var h = size * .5
	var corners = []
	for sx in [-1, 1]:
		for sy in [-1, 1]:
			for sz in [-1, 1]:
				corners.append(c + basis * Vector3(h.x * sx, h.y * sy, h.z * sz))
	for f in [[0, 1, 3, 2], [4, 6, 7, 5], [0, 4, 5, 1], [2, 3, 7, 6], [0, 2, 6, 4], [1, 5, 7, 3]]:
		for idx in [0, 1, 2, 0, 2, 3]:
			st.add_vertex(corners[f[idx]])


static func _mat(c: Color, metal: float, rough: float) -> StandardMaterial3D:
	var m = StandardMaterial3D.new()
	m.albedo_color = c
	m.metallic = metal
	m.roughness = rough
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m
