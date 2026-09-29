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


static func build(asset: Node3D, parent: Node, tracks: Array) -> int:
	var st = {}
	for key in ["steel", "rail", "body", "glass", "door", "bonnet", "sign"]:
		st[key] = SurfaceTool.new()
		st[key].begin(Mesh.PRIMITIVE_TRIANGLES)
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
				box(st.steel, mid + basis.x * side * (TRACK_W * .5 - .15) + Vector3(0, -GIRDER_H * .5, 0), Vector3(0.3, GIRDER_H, seg + 0.3), basis)
				box(st.rail, mid + basis.x * side * 0.72 + Vector3(0, 0.08, 0), Vector3(0.08, 0.16, seg + 0.3), basis)
			# Columns down to the street at a steady spacing along the track.
			var d = fmod(COLUMN_EVERY - fmod(run, COLUMN_EVERY), COLUMN_EVERY)
			while d < seg:
				var at = a.lerp(b, d / seg)
				box(st.steel, Vector3(at.x, STREET_Y + (DECK_TOP - GIRDER_H) * .5, at.z), Vector3(0.5, DECK_TOP - GIRDER_H, 0.5), basis)
				d += COLUMN_EVERY
			run += seg
		if t % TRAIN_EVERY == 0 and run > CAR_L * TRAIN_CARS + 10.0:
			_train(st, line, (run - CAR_L * TRAIN_CARS) * .5)
			trains += 1
	var mats = {
		"steel": _mat(Color("4a4f52"), 0.6, 0.55),
		"rail": _mat(Color("6e6a66"), 0.9, 0.4),
		"body": _mat(Color("b9bdc0"), 0.9, 0.28),
		"glass": _mat(Color("1c2126"), 0.2, 0.1),
		"door": _mat(Color("9ea2a5"), 0.9, 0.3),
		"bonnet": _mat(Color("d8d8d4"), 0.0, 0.5),
		"sign": _mat(Color("ff9a2a"), 0.0, 0.5),
	}
	# Interior lights and the orange LED destination sign glow at night (chicago_night toggles emission).
	for key in ["glass", "sign"]:
		mats[key].emission = Color("ffe2b0") if key == "glass" else Color("ff9a2a")
		mats[key].emission_energy_multiplier = 1.2 if key == "glass" else 3.0
		mats[key].set_meta("chicago_night", true)
	var mesh = ArrayMesh.new()
	for key in st:
		st[key].generate_normals()
		st[key].set_material(mats[key])
		st[key].commit(mesh)
	var node = MeshInstance3D.new()
	node.name = "ElevatedL"
	node.mesh = mesh
	parent.add_child(node)
	node.owner = asset
	return trains


## Eight cars along the polyline from arc length `start`, each aligned to its own chord.
static func _train(st: Dictionary, line: PackedVector3Array, start: float) -> void:
	for car in TRAIN_CARS:
		var s0 = start + car * CAR_L + 0.3
		var s1 = s0 + CAR_L - 0.6
		var a = _at(line, s0)
		var b = _at(line, s1)
		var basis = Basis.looking_at(b - a, Vector3.UP)
		var c = (a + b) * .5 + Vector3(0, 0.55 + (CAR_H - 0.55) * .5, 0)
		var body_h = CAR_H - 0.55
		box(st.body, c, Vector3(CAR_W, body_h, CAR_L - 1.6), basis)
		# Fibreglass end bonnets with the window and sign on the leading/trailing ends of the pair.
		for e in [-1, 1]:
			box(st.bonnet, c + basis.z * e * (CAR_L * .5 - 0.5), Vector3(CAR_W - 0.05, body_h, 1.0), basis)
			box(st.sign, c + basis.z * e * (CAR_L * .5 - 0.02) + Vector3(0, body_h * .38, 0), Vector3(1.4, 0.22, 0.05), basis)
		for side in [-1, 1]:
			# Window band and two door pairs per side.
			box(st.glass, c + basis.x * side * (CAR_W * .5 + 0.01) + Vector3(0, 0.45, 0), Vector3(0.02, 0.9, CAR_L - 3.0), basis)
			for dz in [-0.25, 0.25]:
				box(st.door, c + basis.x * side * (CAR_W * .5 + 0.02) + basis.z * dz * CAR_L + Vector3(0, -0.2, 0), Vector3(0.02, 2.0, 1.4), basis)
		# Bogies.
		for e in [-1, 1]:
			box(st.rail, c + basis.z * e * (CAR_L * .5 - 2.4) - Vector3(0, body_h * .5 + 0.25, 0), Vector3(2.2, 0.5, 2.4), basis)


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
