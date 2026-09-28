extends RefCounted
## Ground clutter for forest circuits (ASSET-02): grass clumps and bushes, stones and mossy boulders from
## Helindu's "Rocks and Foliage" (CC BY 4.0, split by tools/blender/extract_props.py) scattered beside the road on
## the terrain. One MultiMesh per kind and 500 m chunk with a per-kind visibility range. Presentation only.

const PropMesh = preload("res://scripts/track/prop_mesh.gd")
const DIR = "res://assets/nature/rocks-foliage/"
const CHUNK = 500.0
## [mesh, per 100 m, lateral min, lateral max (m from the centre line), scale min, scale max, visible to]
const KINDS = {
	"grass_clump": ["grass_clump", 26.0, 7.5, 22.0, 0.8, 1.6, 140.0],
	"grass_bush": ["grass_bush", 10.0, 8.0, 26.0, 0.8, 1.5, 180.0],
	"stone_a": ["stone_a", 5.0, 7.5, 30.0, 0.5, 1.4, 220.0],
	"stone_b": ["stone_b", 5.0, 7.5, 30.0, 0.5, 1.4, 220.0],
	"boulder_a": ["boulder_a", 0.7, 12.0, 45.0, 0.25, 0.7, 700.0],
	"boulder_b": ["boulder_b", 0.7, 12.0, 45.0, 0.25, 0.7, 700.0],
	"boulder_c": ["boulder_c", 0.5, 12.0, 45.0, 0.25, 0.7, 700.0],
	"boulder_d": ["boulder_d", 0.5, 12.0, 45.0, 0.25, 0.7, 700.0],
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
			var flat = Vector3(at.tangent.x, 0.0, at.tangent.z).normalized()
			var side = -1.0 if rng.randf() < 0.5 else 1.0
			var p: Vector3 = at.pos + flat.cross(Vector3.UP) * side * rng.randf_range(k[2], k[3])
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
