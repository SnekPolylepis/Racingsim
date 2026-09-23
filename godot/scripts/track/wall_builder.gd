extends RefCounted
## Bakes barriers (REBUILD-PLAN.md P3-04): a closed prism along a base polyline. Pure data, headless-safe.
##
## The wall's inner face (the side facing the track) runs along the base line; its thickness extends
## away from the track along each vertex's horizontal `outward` direction. Walls stand vertical (world
## up) whatever the road's bank, and reach WALL_FOOTING below their base so a wall on a slope or bank
## never shows a gap underneath. Faces: inner, outer, top and both end caps (open loops only).

enum Kind { ARMCO, TYRE, CONCRETE }

const NAMES = ["armco", "tyre", "concrete"]
## Default [height, thickness] per kind, metres: a W-beam guardrail, a stack of tyres, a concrete wall.
const SIZE = [[.75, .15], [1.0, .9], [1.0, .4]]
const COLORS = [Color(.72, .74, .76), Color(.1, .1, .11), Color(.62, .6, .56)]
const WALL_FOOTING = .3


## Faces (3 vertices per triangle) of a wall along `base` points with per-point horizontal `outward`
## vectors. `closed` joins the last point back to the first (no end caps).
static func faces(
	base: PackedVector3Array, outward: PackedVector3Array, height: float, thickness: float, closed: bool
) -> PackedVector3Array:
	var n = base.size()
	var out = PackedVector3Array()
	if n < 2:
		return out
	var up = Vector3.UP
	var rows = []
	for i in n:
		var inner_low = base[i] - up * WALL_FOOTING
		var inner_high = base[i] + up * height
		var outer_low = inner_low + outward[i] * thickness
		var outer_high = inner_high + outward[i] * thickness
		rows.append([inner_low, inner_high, outer_high, outer_low])
	var count = n if closed else n - 1
	for i in count:
		var a = rows[i]
		var b = rows[(i + 1) % n]
		# Four sides of the tube between two cross-sections: inner, top, outer, bottom.
		for k in 4:
			var k2 = (k + 1) % 4
			out.append_array(PackedVector3Array([a[k], b[k], a[k2], a[k2], b[k], b[k2]]))
	if not closed:
		for cap in [[rows[0], false], [rows[n - 1], true]]:
			var r = cap[0]
			var tri = [r[0], r[1], r[2], r[0], r[2], r[3]]
			if cap[1]:
				tri.reverse()
			out.append_array(PackedVector3Array(tri))
	return out


static func mesh(face_list: PackedVector3Array, kind: int) -> ArrayMesh:
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for v in face_list:
		st.add_vertex(v)
	st.generate_normals()
	var mat = StandardMaterial3D.new()
	mat.albedo_color = COLORS[kind]
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	st.set_material(mat)
	return st.commit()
