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
enum AtlasKind { TREES, UNDERGROWTH }

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
## Mesh to scatter; empty scatters photographic cards of mixed species and heights from `atlas_kind`, one
## MultiMesh and one draw call. Cards ignore scale_min/scale_max and use each species' own height range.
@export var mesh: Mesh
## Trees: the canopy atlas (assets/trees/tree_atlas.png). Undergrowth (Look-10): ferns, brambles, long
## grass, bushes and saplings (assets/undergrowth/undergrowth_atlas.png), 0.3-2.5 m tall.
@export_enum("Trees", "Undergrowth") var atlas_kind = AtlasKind.TREES
## Multiplies every card's height, to raise or lower a whole band.
@export var height_scale = 1.0
## Restricts card picks to these indices into `species_for(atlas_kind)` (e.g. UNDERGROWTH_SPECIES' grass
## or bramble/shrub rows), for a band that reads as one kind of plant instead of the full mix. Empty uses
## every species, weighted as usual.
@export var species_indices: PackedInt32Array = []
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
				var cards = cards_for(atlas_kind)
				var pick = pick_card(rng, atlas_kind, species_indices)
				var card = cards[pick.card]
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
## Look-10: low vegetation between and under the trees (ART-DIRECTION.md "Trackside enclosure").
const UNDERGROWTH_ATLAS_PATH = "res://assets/undergrowth/undergrowth_atlas.png"
const RETRO_TREE_SHADER = preload("res://shaders/retro_tree.gdshader")
## Atlas cells as [u, v, w, h] in 0..1 (tools/finish_tree_cards.py writes assets/trees/tree_atlas.json), by
## kind: 0-2 spruce, 3-4 fir, 5 beech, 6 oak, 7 birch, 8-9 bush. CC0 Poly Haven models rendered to
## cut-outs (THIRD-PARTY.md). oak/birch stand in for Poly Haven's lack of a literal oak/birch model:
## island_tree_02/03, the closest broadleaf/multi-stem CC0 renders by inspection.
const CARDS = [
	[0.05615, 0.00391, 0.13770, 0.32552],
	[0.30811, 0.00391, 0.13330, 0.32552],
	[0.53613, 0.00391, 0.17725, 0.32552],
	[0.79590, 0.00391, 0.15820, 0.32552],
	[0.07178, 0.33724, 0.10596, 0.32552],
	[0.29688, 0.33724, 0.15625, 0.32552],
	[0.50293, 0.39909, 0.24414, 0.26367],
	[0.75293, 0.37630, 0.24414, 0.28646],
	[0.03027, 0.67057, 0.18896, 0.32552],
	[0.28516, 0.67057, 0.17920, 0.32552],
]
## Species mix: [weight, first card, card count, min height m, max height m]. Mixed heights make the
## canopy overlap into one wall.
const SPECIES = [
	[0.30, 0, 3, 9.0, 24.0],
	[0.18, 3, 2, 15.0, 30.0],
	[0.10, 5, 1, 8.0, 19.0],
	[0.10, 6, 1, 10.0, 22.0],
	[0.08, 7, 1, 9.0, 20.0],
	[0.24, 8, 2, 2.5, 5.5],
]
## First card index of each deciduous species (beech, oak, birch): eligible for the autumn tint below.
const DECIDUOUS_FIRST_CARDS = [5, 6, 7]

## Atlas cells for undergrowth (assets/undergrowth/undergrowth_atlas.json): 0-1 fern, 2-4 bramble, 5-7
## long grass, 8-10 flowering shrub, 11-13 sapling.
const UNDERGROWTH_CARDS = [
	[0.00293, 0.16016, 0.19385, 0.16699],
	[0.20264, 0.17188, 0.19385, 0.15527],
	[0.40234, 0.14941, 0.19385, 0.17773],
	[0.62305, 0.00586, 0.15186, 0.32129],
	[0.83594, 0.00586, 0.12500, 0.32129],
	[0.00293, 0.46680, 0.19385, 0.19336],
	[0.20264, 0.42773, 0.19385, 0.23242],
	[0.40234, 0.46289, 0.19385, 0.19727],
	[0.64307, 0.33887, 0.11133, 0.32129],
	[0.84326, 0.33887, 0.11035, 0.32129],
	[0.00293, 0.70117, 0.19385, 0.29199],
	[0.25098, 0.67188, 0.09717, 0.32129],
	[0.45850, 0.67188, 0.08105, 0.32129],
	[0.65625, 0.67188, 0.08545, 0.32129],
]
## Even mix, heights within the task's 0.3-2.5 m range for roadside undergrowth.
const UNDERGROWTH_SPECIES = [
	[0.20, 0, 2, 0.30, 0.60],
	[0.20, 2, 3, 0.40, 1.20],
	[0.20, 5, 3, 0.30, 0.70],
	[0.20, 8, 3, 0.50, 1.50],
	[0.20, 11, 3, 1.00, 2.50],
]

## Fraction of a card's height that sits below the ground.
const SINK = 0.11

static var _mats: Dictionary = {}
static var _card_mesh: ArrayMesh = null


static func cards_for(kind: int) -> Array:
	return UNDERGROWTH_CARDS if kind == AtlasKind.UNDERGROWTH else CARDS


static func species_for(kind: int) -> Array:
	return UNDERGROWTH_SPECIES if kind == AtlasKind.UNDERGROWTH else SPECIES


static func tree_material(kind: int = AtlasKind.TREES) -> ShaderMaterial:
	if _mats.has(kind):
		return _mats[kind]
	var mat = ShaderMaterial.new()
	mat.shader = RETRO_TREE_SHADER
	var path = UNDERGROWTH_ATLAS_PATH if kind == AtlasKind.UNDERGROWTH else TREE_ATLAS_PATH
	if ResourceLoader.exists(path):
		mat.set_shader_parameter("tree_atlas", load(path))
	_mats[kind] = mat
	return mat


## One species, card and height from the weighted table, plus an instance tint. `subset`, indices into
## species_for(kind), restricts picks to those rows (re-weighted against just their own weights); empty
## uses the whole table.
static func pick_card(
	rng: RandomNumberGenerator, kind: int = AtlasKind.TREES, subset: PackedInt32Array = []
) -> Dictionary:
	var species = species_for(kind)
	if not subset.is_empty():
		var filtered = []
		for idx in subset:
			filtered.append(species[idx])
		species = filtered
	var total_weight = 0.0
	for row in species:
		total_weight += row[0]
	var r = rng.randf() * total_weight
	var sp = species[species.size() - 1]
	for row in species:
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
	if kind == AtlasKind.TREES and sp[1] in DECIDUOUS_FIRST_CARDS and rng.randf() < 0.3:
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
		inst.material_override = tree_material(atlas_kind)
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
