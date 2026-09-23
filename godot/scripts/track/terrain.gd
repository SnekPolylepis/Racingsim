@tool
class_name TerrainPatch
extends Node3D
## Authored or imported terrain (REBUILD-PLAN.md P3-03).
##
## Imports a heightmap Image (16-bit PNG or EXR grayscale) or a plain 32-bit float .raw with width/height,
## scales and offsets heights, and stitches seamlessly to any RoadPath crossing the patch:
##   - Outside each road's outer verge edge: blends height smoothly toward the verge edge height within `blend_m`
##     so terrain meets the road verge with zero gap or step.
##   - Under the road footprint (road + kerbs + runoff + verge): lowers terrain at least 0.3 m below
##     the road surface so it never pokes through.
##
## Output under the enclosing TrackAsset:
##   Terrain/<name>/Chunk_<x>_<z>   ArrayMesh instances chunked for rendering (default 64x64 cells).
##   Surfaces/<name>_c<x>_<z>       StaticBody3D collision on layer 1, metadata "surface" = 2 (grass),
##                                  so TrackSurface rays hit it.
##
## To produce a 32-bit float .raw file from a GeoTIFF using GDAL:
##   gdal_translate -ot Float32 -of ENVI input.tif output.raw
## (the raw file contains width * height 32-bit IEEE floats in row-major order).

const SurfaceTable = preload("res://scripts/track.gd")
const RoadBuilder = preload("res://scripts/track/road_builder.gd")
const RoadSection = preload("res://scripts/track/road_section.gd")

const MAX_EXTENT = 5000.0
const CELL_GRID = 50.0

@export_group("Heightmap")
## Grayscale or HDR heightmap texture (EXR or 16-bit PNG).
@export var heightmap: Texture2D
## Optional path to a 32-bit float raw elevation file.
@export var raw_file: String = ""
## Width (columns) in samples of raw_file.
@export var raw_width: int = 0
## Height (rows) in samples of raw_file.
@export var raw_height: int = 0
## Horizontal spacing between adjacent samples, in metres.
@export_range(0.1, 50.0, 0.1) var metres_per_pixel: float = 1.0
## Vertical scale multiplier applied to raw sample values.
@export var height_scale: float = 1.0
## Vertical offset in metres added to scaled heights.
@export var height_offset: float = 0.0
## (x, z) origin in TrackAsset space corresponding to pixel (0, 0).
@export var origin_offset: Vector2 = Vector2.ZERO

@export_group("Road Stitching")
## RoadPaths to stitch against. If empty, all RoadPaths under the enclosing TrackAsset are used.
@export var road_paths: Array[NodePath] = []
## Distance outside the outer verge edge over which terrain blends toward verge height, metres.
@export var blend_m: float = 8.0
## Minimum distance below the road surface for terrain vertices under the road footprint, metres.
@export var under_road_drop_m: float = 0.3

@export_group("Chunking")
## Number of cells per chunk along x and z.
@export_range(16, 128, 16) var chunk_size: int = 64
## Drivable surface index (SURF table index, 2 = grass).
@export var surface_id: int = 2

@export_group("")
@export_tool_button("Bake terrain", "Callable") var bake_button = bake

## Programmatic Image alternative to heightmap texture.
var image: Image
var last_bake: Dictionary = {}


## Loads the 2D height grid into a 64-bit float array.
func load_heights() -> Dictionary:
	var img: Image = image
	if img == null and heightmap != null:
		img = heightmap.get_image()
	if img != null:
		var w = img.get_width()
		var h = img.get_height()
		var total = w * h
		var data = PackedFloat64Array()
		data.resize(total)
		var is_rf = img.get_format() == Image.FORMAT_RF
		if is_rf:
			var floats = img.get_data().to_float32_array()
			if is_zero_approx(height_offset) and is_equal_approx(height_scale, 1.0):
				for i in total:
					data[i] = float(floats[i])
			else:
				for i in total:
					data[i] = float(height_offset + floats[i] * height_scale)
		else:
			var idx = 0
			for y in h:
				for x in w:
					var px = img.get_pixel(x, y)
					data[idx] = float(height_offset + px.r * height_scale)
					idx += 1
		return {"width": w, "height": h, "data": data}
	elif raw_file != "" and FileAccess.file_exists(raw_file) and raw_width > 0 and raw_height > 0:
		var bytes = FileAccess.get_file_as_bytes(raw_file)
		var floats = bytes.to_float32_array()
		var w = raw_width
		var h = raw_height
		var total = mini(floats.size(), w * h)
		var data = PackedFloat64Array()
		data.resize(w * h)
		if is_zero_approx(height_offset) and is_equal_approx(height_scale, 1.0):
			for i in total:
				data[i] = float(floats[i])
		else:
			for i in total:
				data[i] = float(height_offset + floats[i] * height_scale)
		return {"width": w, "height": h, "data": data}
	return {}


## Road surface height along the banked up axis at signed lateral distance lat.
static func road_surface_height_at(sec: Dictionary, lat: float) -> float:
	var left = lat < 0.0
	var w = sec.width_left if left else sec.width_right
	var lat_mag = absf(lat)
	if lat_mag <= w:
		return RoadBuilder.road_height(sec, lat)
	var kw = maxf(sec.kerb_width, RoadBuilder.MIN_BAND)
	var slope = tan(deg_to_rad(sec.verge_slope_deg))
	var d_kerb = lat_mag - w
	var kerb = sec.kerb_left if left else sec.kerb_right
	if d_kerb <= kw:
		if kerb != RoadSection.Kerb.NONE:
			return RoadBuilder.kerb_shape(kerb, sec.kerb_height, d_kerb / kw)
		return -slope * d_kerb
	var top = (
		RoadBuilder.kerb_shape(kerb, sec.kerb_height, 1.0) if kerb != RoadSection.Kerb.NONE else -slope * kw
	)
	var d_after = d_kerb - kw
	return top - slope * d_after


## Stitches terrain heights to nearby roads.
func stitch_heights(grid: Dictionary, roads: Array) -> void:
	if roads.is_empty():
		return
	var w: int = grid.width
	var h: int = grid.height
	var data: PackedFloat64Array = grid.data
	for road in roads:
		if road == null or not (road is RoadPath):
			continue
		var c = road.working_curve()
		if c == null or c.point_count < 2:
			continue
		var length = c.get_baked_length()
		var closed = road.closed
		var keys = road.sections.duplicate()
		keys.sort_custom(func(a, b): return a.at < b.at)
		var spline = (
			RoadBuilder.elevation_spline(road.elevation_keys, length, closed)
			if not road.elevation_keys.is_empty()
			else []
		)
		var st = RoadBuilder.stations(c, closed, road.along_step, road.elevation_keys)
		var n_st = st.size()
		if n_st < 2:
			continue
		var stations_data = []
		for i in n_st:
			var s_val = st[i].s
			var sec = RoadBuilder.section_at(keys, s_val, length, closed)
			var fr = RoadBuilder.frame(st[i].tangent, sec.bank_deg)
			var e_left = RoadBuilder.beyond_edge(c, keys, closed, spline, s_val, -1, 0.0)
			var e_right = RoadBuilder.beyond_edge(c, keys, closed, spline, s_val, 1, 0.0)
			(
				stations_data
				. append(
					{
						"s": s_val,
						"sec": sec,
						"pos": road.transform * st[i].pos,
						"fr0": (road.transform.basis * fr[0]).normalized(),
						"fr1": (road.transform.basis * fr[1]).normalized(),
						"lat_left": e_left.lat,
						"lat_right": e_right.lat,
						"pt_left": road.transform * e_left.point,
						"pt_right": road.transform * e_right.point,
					}
				)
			)
		var seg_count = n_st if closed else n_st - 1
		var spatial_grid = {}
		for seg_idx in seg_count:
			var s0 = stations_data[seg_idx]
			var s1 = stations_data[(seg_idx + 1) % n_st]
			var max_w = (
				maxf(absf(s0.lat_left), maxf(absf(s0.lat_right), maxf(absf(s1.lat_left), absf(s1.lat_right))))
				+ blend_m
				+ 4.0
			)
			var p0 = Vector2(s0.pos.x, s0.pos.z)
			var p1 = Vector2(s1.pos.x, s1.pos.z)
			var gx0 = int(floor((minf(p0.x, p1.x) - max_w) / CELL_GRID))
			var gx1 = int(floor((maxf(p0.x, p1.x) + max_w) / CELL_GRID))
			var gz0 = int(floor((minf(p0.y, p1.y) - max_w) / CELL_GRID))
			var gz1 = int(floor((maxf(p0.y, p1.y) + max_w) / CELL_GRID))
			var seg_record = {"s0": s0, "s1": s1, "p0": p0, "p1": p1, "max_w": max_w}
			for gz in range(gz0, gz1 + 1):
				for gx in range(gx0, gx1 + 1):
					var key = Vector2i(gx, gz)
					if not spatial_grid.has(key):
						spatial_grid[key] = []
					spatial_grid[key].append(seg_record)
		for gz in h:
			var vz = origin_offset.y + gz * metres_per_pixel
			var cell_z = int(floor(vz / CELL_GRID))
			for gx in w:
				var vx = origin_offset.x + gx * metres_per_pixel
				var cell_x = int(floor(vx / CELL_GRID))
				var cell_key = Vector2i(cell_x, cell_z)
				if not spatial_grid.has(cell_key):
					continue
				var cand_list = spatial_grid[cell_key]
				var best_seg = null
				var best_dist_sq = INF
				var best_t = 0.0
				var v2 = Vector2(vx, vz)
				for seg in cand_list:
					var ab = seg.p1 - seg.p0
					var l2 = ab.length_squared()
					if l2 < 1e-9:
						continue
					var t = clampf((v2 - seg.p0).dot(ab) / l2, 0.0, 1.0)
					var proj = seg.p0 + t * ab
					var d2 = (v2 - proj).length_squared()
					if d2 < best_dist_sq:
						best_dist_sq = d2
						best_seg = seg
						best_t = t
				if best_seg == null or best_dist_sq > best_seg.max_w * best_seg.max_w:
					continue
				var s_interp = lerpf(best_seg.s0.s, best_seg.s1.s, best_t)
				if closed and best_seg.s1.s < best_seg.s0.s:
					s_interp = fposmod(lerpf(best_seg.s0.s, best_seg.s1.s + length, best_t), length)
				var st_eval = RoadBuilder.station_at(c, closed, length, spline, s_interp)
				var sec_eval = RoadBuilder.section_at(keys, s_interp, length, closed)
				var fr_eval = RoadBuilder.frame(st_eval.tangent, sec_eval.bank_deg)
				var st_pos = road.transform * st_eval.pos
				var fr_right = (road.transform.basis * fr_eval[0]).normalized()
				var delta = Vector3(vx, 0.0, vz) - Vector3(st_pos.x, 0.0, st_pos.z)
				var lat = delta.x * fr_right.x + delta.z * fr_right.z
				var sign_lat = 1 if lat >= 0.0 else -1
				var lat_mag = absf(lat)
				var e_outer = RoadBuilder.beyond_edge(c, keys, closed, spline, s_interp, sign_lat, 0.0)
				var edge_lat = absf(e_outer.lat)
				var edge_pt = road.transform * e_outer.point
				var v_idx = gz * w + gx
				var h_orig = data[v_idx]
				if lat_mag < edge_lat - 1e-4:
					var h_loc = road_surface_height_at(sec_eval, lat)
					var p_surf = st_eval.pos + fr_eval[0] * lat + fr_eval[1] * h_loc
					var y_road_surf = (road.transform * p_surf).y
					data[v_idx] = minf(h_orig, y_road_surf - under_road_drop_m)
				else:
					var d_out = maxf(0.0, lat_mag - edge_lat)
					if d_out <= blend_m:
						var tb = clampf(d_out / maxf(blend_m, 1e-6), 0.0, 1.0)
						var wb = smoothstep(0.0, 1.0, tb)
						data[v_idx] = lerpf(edge_pt.y, h_orig, wb)


func bake() -> void:
	var t0 = Time.get_ticks_msec()
	var grid = load_heights()
	if grid.is_empty():
		push_error("TerrainPatch %s: no valid heightmap or raw file provided" % name)
		return
	var w: int = grid.width
	var h: int = grid.height
	var data: PackedFloat64Array = grid.data
	var p_min = Vector2(origin_offset.x, origin_offset.y)
	var p_max = Vector2(
		origin_offset.x + (w - 1) * metres_per_pixel, origin_offset.y + (h - 1) * metres_per_pixel
	)
	if (
		absf(p_min.x) > MAX_EXTENT
		or absf(p_min.y) > MAX_EXTENT
		or absf(p_max.x) > MAX_EXTENT
		or absf(p_max.y) > MAX_EXTENT
	):
		push_warning("TerrainPatch %s: bounds leave the ±%.0f m precision box (5.1)" % [name, MAX_EXTENT])
	var host = get_parent() if get_parent() != null and get_parent().has_method("record_key") else self
	var owner_node = host.owner if host.owner != null else host
	if Engine.is_editor_hint() and is_inside_tree() and get_tree().edited_scene_root != null:
		owner_node = get_tree().edited_scene_root
	var target_roads = []
	if not road_paths.is_empty():
		for p in road_paths:
			var r = get_node_or_null(p)
			if r != null and r is RoadPath:
				target_roads.append(r)
	else:
		var parent_node = host if host != self else get_parent()
		if parent_node != null:
			for child in parent_node.get_children():
				if child is RoadPath:
					target_roads.append(child)
	stitch_heights(grid, target_roads)
	var terrain_group = group(host, "Terrain", owner_node)
	var surfaces_group = group(host, "Surfaces", owner_node)
	var patch_terrain = group(terrain_group, str(name), owner_node)
	for child in patch_terrain.get_children():
		patch_terrain.remove_child(child)
		child.free()
	for child in surfaces_group.get_children():
		if str(child.name).begins_with(str(name) + "_c"):
			surfaces_group.remove_child(child)
			child.free()
	var chunk_step = maxi(16, chunk_size)
	var n_chunks_x = int(ceil(float(w - 1) / chunk_step))
	var n_chunks_z = int(ceil(float(h - 1) / chunk_step))
	var total_triangles = 0
	var total_chunks = 0
	for cz in n_chunks_z:
		var z_start = cz * chunk_step
		var z_end = mini(z_start + chunk_step, h - 1)
		var ch_size = z_end - z_start
		for cx in n_chunks_x:
			var x_start = cx * chunk_step
			var x_end = mini(x_start + chunk_step, w - 1)
			var cw_size = x_end - x_start
			if cw_size <= 0 or ch_size <= 0:
				continue
			var v_count = (cw_size + 1) * (ch_size + 1)
			var chunk_verts = PackedVector3Array()
			var chunk_normals = PackedVector3Array()
			var chunk_uvs = PackedVector2Array()
			chunk_verts.resize(v_count)
			chunk_normals.resize(v_count)
			chunk_uvs.resize(v_count)
			var v_idx = 0
			for lz in range(ch_size + 1):
				var gz = z_start + lz
				var vz = origin_offset.y + gz * metres_per_pixel
				for lx in range(cw_size + 1):
					var gx = x_start + lx
					var vx = origin_offset.x + gx * metres_per_pixel
					var vy = data[gz * w + gx]
					var gx_prev = maxi(0, gx - 1)
					var gx_next = mini(w - 1, gx + 1)
					var gz_prev = maxi(0, gz - 1)
					var gz_next = mini(h - 1, gz + 1)
					var dx_dist = maxf((gx_next - gx_prev) * metres_per_pixel, 1e-6)
					var dz_dist = maxf((gz_next - gz_prev) * metres_per_pixel, 1e-6)
					var grad_x = (data[gz * w + gx_next] - data[gz * w + gx_prev]) / dx_dist
					var grad_z = (data[gz_next * w + gx] - data[gz_prev * w + gx]) / dz_dist
					var norm = Vector3(-grad_x, 1.0, -grad_z).normalized()
					chunk_verts[v_idx] = Vector3(vx, vy, vz)
					chunk_normals[v_idx] = norm
					chunk_uvs[v_idx] = Vector2(vx, vz)
					v_idx += 1
			var tri_count = cw_size * ch_size * 2
			var chunk_indices = PackedInt32Array()
			chunk_indices.resize(tri_count * 3)
			var chunk_faces = PackedVector3Array()
			chunk_faces.resize(tri_count * 3)
			var i_idx = 0
			var row_pitch = cw_size + 1
			for lz in ch_size:
				var r0 = lz * row_pitch
				var r1 = (lz + 1) * row_pitch
				for lx in cw_size:
					var i00 = r0 + lx
					var i10 = i00 + 1
					var i01 = r1 + lx
					var i11 = i01 + 1
					chunk_indices[i_idx] = i00
					chunk_indices[i_idx + 1] = i10
					chunk_indices[i_idx + 2] = i01
					chunk_indices[i_idx + 3] = i10
					chunk_indices[i_idx + 4] = i11
					chunk_indices[i_idx + 5] = i01
					chunk_faces[i_idx] = chunk_verts[i00]
					chunk_faces[i_idx + 1] = chunk_verts[i10]
					chunk_faces[i_idx + 2] = chunk_verts[i01]
					chunk_faces[i_idx + 3] = chunk_verts[i10]
					chunk_faces[i_idx + 4] = chunk_verts[i11]
					chunk_faces[i_idx + 5] = chunk_verts[i01]
					i_idx += 6
			var arr = []
			arr.resize(Mesh.ARRAY_MAX)
			arr[Mesh.ARRAY_VERTEX] = chunk_verts
			arr[Mesh.ARRAY_NORMAL] = chunk_normals
			arr[Mesh.ARRAY_TEX_UV] = chunk_uvs
			arr[Mesh.ARRAY_INDEX] = chunk_indices
			var arr_mesh = ArrayMesh.new()
			arr_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
			var mesh_node = MeshInstance3D.new()
			mesh_node.name = "Chunk_%d_%d" % [cx, cz]
			mesh_node.mesh = arr_mesh
			patch_terrain.add_child(mesh_node)
			mesh_node.owner = owner_node
			var body = StaticBody3D.new()
			body.name = "%s_c%d_%d" % [name, cx, cz]
			body.collision_layer = 1
			body.collision_mask = 0
			body.set_meta("surface", int(surface_id))
			var col_shape = ConcavePolygonShape3D.new()
			col_shape.set_faces(chunk_faces)
			var col_node = CollisionShape3D.new()
			col_node.name = "Collision"
			col_node.shape = col_shape
			body.add_child(col_node)
			surfaces_group.add_child(body)
			body.owner = owner_node
			col_node.owner = owner_node
			total_triangles += tri_count
			total_chunks += 1
	var bake_dt = Time.get_ticks_msec() - t0
	last_bake = {
		"chunks": total_chunks,
		"cells_x": w - 1,
		"cells_z": h - 1,
		"triangles": total_triangles,
		"bake_ms": bake_dt,
	}


static func group(host: Node, group_name: String, owner_node: Node) -> Node3D:
	var g = host.get_node_or_null(group_name)
	if g == null:
		g = Node3D.new()
		g.name = group_name
		host.add_child(g)
		g.owner = owner_node
	return g
