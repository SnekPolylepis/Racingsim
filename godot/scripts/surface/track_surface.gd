extends RefCounted
## Surface contract (REBUILD-PLAN.md 5.2) for an authored track: Godot physics-server rays against the
## TrackAsset's Surfaces/ collision (decided in P3-00). Returns the same dictionary as TestSurface.
##
## Must be called inside a physics frame (_physics_process), where direct_space_state is valid; that
## includes headless tests. Rays see only collision layer 1 (drivable surfaces), never walls.
## The returned normal always faces back along the ray, whatever the triangle winding.

const SURFACE_LAYER = 1

var asset
var params = PhysicsRayQueryParameters3D.new()
var warned = false


func _init(track_asset):
	asset = track_asset
	params.collision_mask = 1 << (SURFACE_LAYER - 1)
	params.hit_back_faces = true
	params.hit_from_inside = false


func contact(origin: Vector3, direction: Vector3, max_dist: float, hint: int = -1) -> Dictionary:
	if not Engine.is_in_physics_frame():
		if not warned:
			push_error("TrackSurface.contact() called outside a physics frame; queries return no hit")
			warned = true
		return {}
	var space = asset.get_world_3d().direct_space_state
	params.from = origin
	params.to = origin + direction * max_dist
	var r = space.intersect_ray(params)
	if r.is_empty():
		return {}
	var n = r.normal
	if n.dot(direction) > 0:
		n = -n
	return {
		"point": r.position,
		"normal": n,
		"distance": origin.distance_to(r.position),
		"surface": int(r.collider.get_meta("surface", 0)),
		"hint": hint
	}
