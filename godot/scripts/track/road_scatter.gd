@tool
class_name RoadScatter
extends Node3D
## Scenery scattered beside a road (REBUILD-PLAN.md P3-04): trees, posts or any mesh, placed in a band
## `offset_min`..`offset_max` metres beyond the outer edge of a RoadPath's verge, on one or both sides,
## `per_100m` instances per 100 m per side, with random yaw and scale. Deterministic from `random_seed`: the
## same settings always bake the same layout. Bakes to Scenery/<name> of the enclosing TrackAsset as a
## single MultiMeshInstance3D (one draw call). Scenery has no collision.
## Ground height beyond the verge continues the verge's fall; terrain (P3-03) will replace that.

enum Sides { LEFT, RIGHT, BOTH }

const RoadBuilder = preload("res://scripts/track/road_builder.gd")

@export var follow_road: NodePath
## Sides: 0 left, 1 right, 2 both.
@export_enum("Left", "Right", "Both") var sides = 2
@export var offset_min = 4.0
@export var offset_max = 30.0
@export var per_100m = 12.0
@export var from_m = 0.0
## Range end along the road, metres; < 0 means the road's end. from_m > to_m wraps a closed road.
@export var to_m = -1.0
@export var random_seed = 1
@export var scale_min = .8
@export var scale_max = 1.3
## Mesh to scatter; empty scatters photographic tree cards (assets/trees/tree_atlas.png) of mixed species and
## heights, one MultiMesh and one draw call. Cards ignore scale_min/scale_max and use CARDS' own heights.
@export var mesh: Mesh
## Multiplies every card's height, to raise or lower a whole band.
@export var height_scale = 1.0
@export_tool_button("Bake scatter", "Callable") var bake_button = bake

var last_bake = {}


## Instance transforms, in the host's space: [Transform3D], plus each instance's distance beyond the
## verge edge and its station, for tests.
func layout() -> Dictionary:
	var road = get_node_or_null(follow_road) if not follow_road.is_empty() else null
	var out = {"xforms": [], "beyond": [], "s": [], "cards": [], "tint": []}
	if road == null:
		return out
	var c = road.working_curve()
	var length = c.get_baked_length()
	var keys = road.sections.duplicate()
	keys.sort_custom(func(a, b): return a.at < b.at)
	var spline = (
		RoadBuilder.elevation_spline(road.elevation_keys, length, road.closed)
		if not road.elevation_keys.is_empty()
		else []
	)
	var start = clampf(from_m, 0.0, length)
	var stop = length if to_m < 0 else clampf(to_m, 0.0, length)
	var span = stop - start
	if road.closed and stop <= start:
		span += length
	var rng = RandomNumberGenerator.new()
	rng.seed = random_seed
	var signs = [-1, 1] if sides == Sides.BOTH else ([-1] if sides == Sides.LEFT else [1])
	for side_sign in signs:
		var count = int(round(span * per_100m / 100.0))
		for i in count:
			var s = start + rng.randf() * span
			var beyond = rng.randf_range(offset_min, offset_max)
			var e = RoadBuilder.beyond_edge(c, keys, road.closed, spline, s, side_sign, beyond)
			var yaw = rng.randf() * TAU
			var basis: Basis
			if mesh == null:
				var pick = pick_card(rng)
				var card = CARDS[pick.card]
				var height = pick.height * height_scale
				var width = height * (1.0 + SINK) * card[2] / card[3] * rng.randf_range(1.0, 1.4)
				basis = Basis(Vector3.UP, yaw) * Basis.from_scale(Vector3(width, height, width))
				out.cards.append(Color(card[0], card[1], card[2], card[3]))
				out.tint.append(pick.tint)
			else:
				var size = rng.randf_range(scale_min, scale_max)
				basis = Basis(Vector3.UP, yaw) * Basis.from_scale(Vector3.ONE * size)
			out.xforms.append(Transform3D(basis, road.transform * e.point))
			out.beyond.append(beyond)
			out.s.append(fposmod(s, length))
	return out


const TREE_ATLAS_PATH = "res://assets/trees/tree_atlas.png"
const RETRO_TREE_SHADER = preload("res://shaders/retro_tree.gdshader")
## Atlas cells as [u, v, w, h] in 0..1 (tools/finish_tree_cards.py writes assets/trees/tree_atlas.json), by
## kind: 0-2 spruce, 3-4 fir, 5 beech, 6-7 bush. CC0 Poly Haven models rendered to cut-outs (THIRD-PARTY.md).
const CARDS = [
	[0.00293, 0.06543, 0.24414, 0.43164],
	[0.25293, 0.05176, 0.24414, 0.44531],
	[0.50293, 0.16162, 0.24414, 0.33545],
	[0.75293, 0.12061, 0.24414, 0.37646],
	[0.01758, 0.50293, 0.21436, 0.49414],
	[0.25293, 0.61670, 0.24414, 0.38037],
	[0.53027, 0.75293, 0.17920, 0.24414],
	[0.78516, 0.50293, 0.17920, 0.24414],
]
## Species mix: [weight, first card, card count, min height m, max height m]. Mixed heights make the
## canopy overlap into one wall.
const SPECIES = [
	[0.32, 0, 3, 9.0, 24.0],
	[0.22, 3, 2, 15.0, 30.0],
	[0.26, 5, 1, 8.0, 19.0],
	[0.20, 6, 2, 2.5, 5.5],
]

## Fraction of a card's height that sits below the ground.
const SINK = 0.11

static var _tree_mat: ShaderMaterial = null
static var _card_mesh: ArrayMesh = null


static func tree_material() -> ShaderMaterial:
	if _tree_mat != null:
		return _tree_mat
	var mat = ShaderMaterial.new()
	mat.shader = RETRO_TREE_SHADER
	if ResourceLoader.exists(TREE_ATLAS_PATH):
		mat.set_shader_parameter("tree_atlas", load(TREE_ATLAS_PATH))
	_tree_mat = mat
	return mat


## One species, card and height from the weighted table, plus an instance tint.
static func pick_card(rng: RandomNumberGenerator) -> Dictionary:
	var r = rng.randf()
	var sp = SPECIES[SPECIES.size() - 1]
	for row in SPECIES:
		r -= row[0]
		if r <= 0.0:
			sp = row
			break
	var card = sp[1] + rng.randi() % int(sp[2])
	var height = lerpf(sp[3], sp[4], pow(rng.randf(), 1.25))
	# Near white: the photographs carry the colour; the tint only varies value and a little hue.
	var val = rng.randf_range(0.7, 1.0)
	var hue_shift = rng.randf_range(-0.05, 0.05)
	var tint = Color(val * (0.82 + hue_shift), val * 0.92, val * (0.84 - hue_shift))
	if sp[1] == 5 and rng.randf() < 0.3:
		tint = Color(val * 1.15, val * 1.0, val * 0.65)
	return {"card": card, "height": height, "tint": tint}


func bake():
	var l = layout()
	last_bake = l
	var host = get_parent() if get_parent() != null and get_parent().has_method("record_key") else self
	var owner_node = host.owner if host.owner != null else host
	if Engine.is_editor_hint() and is_inside_tree() and get_tree().edited_scene_root != null:
		owner_node = get_tree().edited_scene_root
	var scenery = host.get_node_or_null("Scenery")
	if scenery == null:
		scenery = Node3D.new()
		scenery.name = "Scenery"
		host.add_child(scenery)
		scenery.owner = owner_node
	var old = scenery.get_node_or_null(NodePath(str(name)))
	if old != null:
		scenery.remove_child(old)
		old.free()
	var mm = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.use_custom_data = mesh == null
	mm.mesh = mesh if mesh != null else card_mesh()
	mm.instance_count = l.xforms.size()

	for i in l.xforms.size():
		mm.set_instance_transform(i, l.xforms[i])
		if mesh == null:
			mm.set_instance_custom_data(i, l.cards[i])
			mm.set_instance_color(i, l.tint[i])

	var inst = MultiMeshInstance3D.new()
	inst.name = name
	inst.multimesh = mm
	if mesh == null:
		inst.material_override = tree_material()
	scenery.add_child(inst)
	inst.owner = owner_node


## Three alpha-tested cards crossed at 60 degrees, one unit wide and tall, its foot SINK units below the origin
## so the bare trunk base sits in the ground instead of floating on it. The instance
## transform scales it to the tree; INSTANCE_CUSTOM selects the atlas cell (shaders/retro_tree.gdshader).
## Normals point up so foliage takes the same light from every side instead of a flat card's facing.
static func card_mesh() -> ArrayMesh:
	if _card_mesh != null:
		return _card_mesh
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3.UP)
	for k in 3:
		var turn = Basis(Vector3.UP, k * PI / 3.0)
		var p = [Vector3(-.5, -SINK, 0), Vector3(.5, -SINK, 0), Vector3(.5, 1, 0), Vector3(-.5, 1, 0)]
		var uv = [Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)]
		for i in [0, 1, 2, 0, 2, 3]:
			st.set_uv(uv[i])
			st.add_vertex(turn * p[i])
	_card_mesh = st.commit()
	_card_mesh.surface_set_material(0, tree_material())
	return _card_mesh
