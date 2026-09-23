extends RefCounted
## Minimal road ribbon baker: a closed centreline to road and verge triangles (Godot axes, +Y up).
## The seed of the P3-02 road tool; today it has a flat cross-section, no bank, camber or kerbs.
## Tessellation follows P3-00: road stations every width/8 across; along the road, whatever spacing
## the centreline has (keep it <= 1.5 m).


## Faces (3 vertices per triangle) for the road (|lat| <= half_width) and for flat verges out to
## half_width + verge on both sides. `center` is a closed loop that does not repeat its first point.
static func bake(center: PackedVector3Array, half_width: float, verge: float) -> Dictionary:
	var n = center.size()
	var rows = []
	var lats = [-half_width - verge]
	for k in 9:
		lats.append(-half_width + half_width * 2 * k / 8.0)
	lats.append(half_width + verge)
	for i in n:
		var tangent = (center[(i + 1) % n] - center[posmod(i - 1, n)]).normalized()
		var right = tangent.cross(Vector3.UP).normalized()
		var row = PackedVector3Array()
		for lat in lats:
			row.append(center[i] + right * lat)
		rows.append(row)
	var road = PackedVector3Array()
	var verges = PackedVector3Array()
	var last = lats.size() - 1
	for i in n:
		var r0 = rows[i]
		var r1 = rows[(i + 1) % n]
		for k in last:
			var quad = [r0[k], r1[k], r0[k + 1], r0[k + 1], r1[k], r1[k + 1]]
			var target = verges if k == 0 or k == last - 1 else road
			target.append_array(PackedVector3Array(quad))
	return {"road": road, "verge": verges}


static func mesh(faces: PackedVector3Array) -> ArrayMesh:
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for v in faces:
		st.add_vertex(v)
	st.generate_normals()
	return st.commit()
