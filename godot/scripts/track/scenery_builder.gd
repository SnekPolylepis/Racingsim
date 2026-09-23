@tool
class_name SceneryBuilder
extends RefCounted
## Procedural mesh and collision helpers for trackside scenery kit (REBUILD-PLAN.md P3-04 / scenery-kit).
## Builds low-poly geometry via SurfaceTool, MultiMesh instances for repeated items, and layer-2 StaticBody3D
## collisions for solid barriers (wall_kind armco or concrete).

const WallBuilder = preload("res://scripts/track/wall_builder.gd")


## Resolve the host (enclosing TrackAsset or self) and container ("Scenery" or "Walls").
static func prepare_container(item: Node3D, container_name: String) -> Dictionary:
	var host = (
		item.get_parent()
		if item.get_parent() != null and item.get_parent().has_method("record_key")
		else item
	)
	var owner_node = host.owner if host.owner != null else host
	if Engine.is_editor_hint() and item.is_inside_tree() and item.get_tree().edited_scene_root != null:
		owner_node = item.get_tree().edited_scene_root
	var container = host.get_node_or_null(container_name)
	if container == null:
		container = Node3D.new()
		container.name = container_name
		host.add_child(container)
		container.owner = owner_node
	var old = container.get_node_or_null(NodePath(str(item.name)))
	if old != null:
		container.remove_child(old)
		old.free()
	return {"host": host, "container": container, "owner": owner_node}


## Appends a colored 3D box (6 faces, 12 triangles) to a SurfaceTool.
static func add_box(st: SurfaceTool, center: Vector3, size: Vector3, col: Color) -> void:
	var h = size * 0.5
	st.set_color(col)
	var corners = [
		center + Vector3(-h.x, -h.y, -h.z),  # 0: left bottom back
		center + Vector3(h.x, -h.y, -h.z),  # 1: right bottom back
		center + Vector3(h.x, -h.y, h.z),  # 2: right bottom front
		center + Vector3(-h.x, -h.y, h.z),  # 3: left bottom front
		center + Vector3(-h.x, h.y, -h.z),  # 4: left top back
		center + Vector3(h.x, h.y, -h.z),  # 5: right top back
		center + Vector3(h.x, h.y, h.z),  # 6: right top front
		center + Vector3(-h.x, h.y, h.z)  # 7: left top front
	]
	# 6 faces: front, back, top, bottom, left, right (CCW winding when viewed from outside)
	var quads = [[3, 2, 6, 7], [1, 0, 4, 5], [4, 5, 6, 7], [0, 1, 2, 3], [0, 3, 7, 4], [2, 1, 5, 6]]  # Front (+Z)  # Back (-Z)  # Top (+Y)  # Bottom (-Y)  # Left (-X)  # Right (+X)
	for q in quads:
		for idx in [q[0], q[1], q[2], q[0], q[2], q[3]]:
			st.add_vertex(corners[idx])


## Low-poly box mesh.
static func box_mesh(size: Vector3, col: Color) -> ArrayMesh:
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	add_box(st, Vector3.ZERO, size, col)
	st.generate_normals()
	var mat = StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.cull_mode = BaseMaterial3D.CULL_BACK
	st.set_material(mat)
	return st.commit()


## Low-poly prism/wedge mesh (e.g. for stepped grandstands or roof peaks).
static func add_quad(st: SurfaceTool, p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, col: Color) -> void:
	st.set_color(col)
	st.add_vertex(p0)
	st.add_vertex(p1)
	st.add_vertex(p2)
	st.add_vertex(p0)
	st.add_vertex(p2)
	st.add_vertex(p3)


## Build a MultiMeshInstance3D with TRANSFORM_3D format.
static func make_multimesh(mesh: Mesh, xforms: Array) -> MultiMeshInstance3D:
	var mm = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
	var inst = MultiMeshInstance3D.new()
	inst.multimesh = mm
	return inst


## StaticBody3D on layer 2 only, with wall metadata and ConcavePolygonShape3D.
static func make_wall_body(
	body_name: String,
	face_list: PackedVector3Array,
	kind_name: String,
	wall_line: PackedVector3Array,
	wall_outward: PackedVector3Array,
	wall_h: float,
	wall_t: float
) -> StaticBody3D:
	var body = StaticBody3D.new()
	body.name = body_name
	body.set_collision_layer_value(1, false)
	body.set_collision_layer_value(2, true)
	body.collision_mask = 0
	body.set_meta("wall_kind", kind_name)
	body.set_meta("wall_line", wall_line)
	body.set_meta("wall_outward", wall_outward)
	body.set_meta("wall_height", wall_h)
	body.set_meta("wall_thickness", wall_t)
	var shape = ConcavePolygonShape3D.new()
	shape.set_faces(face_list)
	var col = CollisionShape3D.new()
	col.name = "Collision"
	col.shape = shape
	body.add_child(col)
	return body
