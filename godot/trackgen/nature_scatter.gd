extends RefCounted
## Ground clutter for forest circuits (ASSET-02): grass clumps and bushes, stones and mossy boulders from
## Helindu's "Rocks and Foliage" (CC BY 4.0, split by tools/blender/extract_props.py) scattered beside the road on
## the terrain. One MultiMesh per kind and 500 m chunk with a per-kind visibility range. Presentation only.

const PropMesh = preload("res://scripts/track/prop_mesh.gd")
const RoadBuilder = preload("res://scripts/track/road_builder.gd")
const DIR = "res://assets/nature/"
const CHUNK = 500.0
## [mesh, per 100 m, offset min, offset max (m beyond the verge's outer edge), scale min, scale max, visible to]
## The armco stands 0.3-0.45 m beyond that edge and corner tyre walls to 1.2 m, so every minimum clears a barrier
## by the prop's own radius. (Measured from the centre line, props straddled the armco on narrow stretches and
## sat on the verge inside it on wide ones.)
## Grass: "Simple grass chunks" by 3dhdscan (CC BY 4.0), reduced to a 2.5k-triangle patch and a single tuft.
const KINDS = {
	"grass_patch": ["grass/grass_patch", 55.0, 2.2, 22.0, 0.8, 1.4, 170.0],
	"grass_tuft": ["grass/grass_tuft", 90.0, 1.7, 12.0, 0.6, 1.2, 90.0],
	"grass_clump": ["rocks-foliage/grass_clump", 40.0, 2.0, 20.0, 0.8, 1.6, 150.0],
	"grass_bush": ["rocks-foliage/grass_bush", 18.0, 2.6, 26.0, 0.8, 1.5, 190.0],
	"stone_a": ["rocks-foliage/stone_a", 10.0, 1.8, 30.0, 0.5, 1.4, 240.0],
	"stone_b": ["rocks-foliage/stone_b", 10.0, 1.8, 30.0, 0.5, 1.4, 240.0],
	"boulder_a": ["rocks-foliage/boulder_a", 1.4, 6.0, 46.0, 0.25, 0.75, 700.0],
	"boulder_b": ["rocks-foliage/boulder_b", 1.4, 6.0, 46.0, 0.25, 0.75, 700.0],
	"boulder_c": ["rocks-foliage/boulder_c", 1.0, 6.0, 46.0, 0.25, 0.75, 700.0],
	"boulder_d": ["rocks-foliage/boulder_d", 1.0, 6.0, 46.0, 0.25, 0.75, 700.0],
}
const CLEAR_M = 7.0
const CELL = 20.0


## `height` is a Callable(Vector3) -> float giving the ground height at a point.
static func add(asset: Node3D, road, height: Callable, seed_value: int) -> int:
	var centre = {}
	for p in road.last_bake.center:
		var key = Vector2i(floori(p.x / CELL), floori(p.z / CELL))
		if not centre.has(key):
			centre[key] = []
		centre[key].append(Vector2(p.x, p.z))
	var stations: Array = road.last_bake.stations
	var length: float = stations[-1].s
	var c = road.working_curve()
	var keys = road.sections.duplicate()
	keys.sort_custom(func(a, b): return a.at < b.at)
	var spline = (
		RoadBuilder.elevation_spline(road.elevation_keys, c.get_baked_length(), road.closed)
		if not road.elevation_keys.is_empty()
		else []
	)
	var holder = Node3D.new()
	holder.name = "Nature"
	asset.get_node("Scenery").add_child(holder)
	holder.owner = asset
	var rng = RandomNumberGenerator.new()
	rng.seed = seed_value
	var count = 0
	for kind in KINDS:
		var k = KINDS[kind]
		var groups = {}
		var n = int(length / 100.0 * k[1])
		for j in n:
			var at = stations[rng.randi() % stations.size()]
			var side = -1 if rng.randf() < 0.5 else 1
			var off = rng.randf_range(k[2], k[3])
			var p: Vector3 = (
				road.transform * RoadBuilder.beyond_edge(c, keys, road.closed, spline, at.s, side, off).point
			)
			if _near(centre, p):
				continue
			p.y = height.call(p) - 0.08
			var basis = Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(k[4], k[5]))
			var key = Vector2i(floori(p.x / CHUNK), floori(p.z / CHUNK))
			if not groups.has(key):
				groups[key] = []
			groups[key].append(Transform3D(basis, p))
			count += 1
		var mesh = PropMesh.mesh(DIR + k[0] + ".glb")
		for key in groups:
			var list: Array = groups[key]
			var mm = MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.mesh = mesh
			mm.instance_count = list.size()
			for i in list.size():
				mm.set_instance_transform(i, list[i])
			var node = MultiMeshInstance3D.new()
			node.name = "%s_%d_%d" % [kind, key.x, key.y]
			node.multimesh = mm
			node.visibility_range_end = k[6]
			node.visibility_range_end_margin = k[6] * 0.15
			node.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
			node.cast_shadow = (
				GeometryInstance3D.SHADOW_CASTING_SETTING_ON
				if kind.begins_with("boulder")
				else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			)
			holder.add_child(node)
			node.owner = asset
	return count


static func _near(cells: Dictionary, p: Vector3) -> bool:
	var at = Vector2(p.x, p.z)
	var cx = floori(p.x / CELL)
	var cz = floori(p.z / CELL)
	for dx in [-1, 0, 1]:
		for dz in [-1, 0, 1]:
			for q in cells.get(Vector2i(cx + dx, cz + dz), []):
				if at.distance_squared_to(q) < CLEAR_M * CLEAR_M:
					return true
	return false
