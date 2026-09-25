extends RefCounted
## Procedural 3D presentation. Does not integrate or own physics.
## Maps simulation (x,y,height) to Godot (x,height,y); model +X forward, +Z right.
## Generated scenery and cone references belong to the current world rebuild.
# All assets are procedural and bundled. Physics remains independent of Godot rigid bodies.
const NightStyle = preload("res://scripts/night_style.gd")
const RetroAssets = preload("res://scripts/retro_assets.gd")
var materials = {}
var paint_materials = []
var shadow_materials = []
var night = false
## Contact-patch occlusion. After dark the amber lamps model the ground themselves, so a
## full-strength patch reads as a hard black hole under the car. Once the sun casts real
## shadows the patch is only needed for close contact under the floor, so it backs off
## rather than doubling up with the shadow map.
const DAY_CONTACT = 1.0
const NIGHT_CONTACT = 0.45
const CAST_SHADOW_CONTACT = 0.5
var cast_shadows = false
var headlights = []
## Ground builder for the current circuit; its height()/ground_height() place scenery on the terrain.
var world
var cone_nodes = []
var flags = []


func material(color, metallic = 0.0, roughness = .8):
	var key = str(color) + str(metallic) + str(roughness)
	if materials.has(key):
		return materials[key]
	var m = StandardMaterial3D.new()
	# Per-pixel rather than per-vertex. The presentation keeps its low-resolution raster and
	# dither, but lighting is evaluated properly, which is what makes the surface normal maps
	# on the road and ground contribute at all.
	m.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	m.albedo_color = Color(color)
	m.metallic = metallic
	m.roughness = roughness
	m.metallic_specular = .22
	if m.albedo_color.a < 1:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.no_depth_test = false
	materials[key] = m
	return m


func box(parent, pos, size, color, metallic = 0.0):
	var node = MeshInstance3D.new()
	var mesh = BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.material_override = material(color, metallic, .35 if metallic > 0 else .85)
	node.position = pos
	parent.add_child(node)
	return node


func cylinder(parent, pos, radius, height, color, top = -1.0):
	var node = MeshInstance3D.new()
	var mesh = CylinderMesh.new()
	mesh.bottom_radius = radius
	mesh.top_radius = radius if top < 0 else top
	mesh.height = height
	mesh.radial_segments = 12
	node.mesh = mesh
	node.material_override = material(color)
	node.position = pos
	parent.add_child(node)
	return node


func triangle(st, a, b, c, color):
	# Godot clockwise winding: normal is opposite the geometric cross product.
	if (b - a).cross(c - a).y > 0:
		var temp = b
		b = c
		c = temp
	for v in [a, b, c]:
		st.set_color(color)
		st.set_uv(Vector2(v.x, v.z) * .22)
		st.add_vertex(v)


func quad(st, a, b, c, d, color):
	triangle(st, a, b, c, color)
	triangle(st, a, c, d, color)


func mesh_node(parent, st, textured = false):
	st.generate_normals()
	st.index()
	var node = MeshInstance3D.new()
	node.mesh = st.commit()
	var mat = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	mat.roughness = .92
	if textured:
		var noise = FastNoiseLite.new()
		noise.frequency = .6
		noise.fractal_octaves = 2
		var tex = NoiseTexture2D.new()
		tex.width = 256
		tex.height = 256
		tex.noise = noise
		tex.seamless = true
		var ramp = Gradient.new()
		ramp.set_color(0, Color(.65, .65, .65))
		ramp.set_color(1, Color(1, 1, 1))
		tex.color_ramp = ramp
		mat.albedo_texture = tex
	node.material_override = mat
	parent.add_child(node)
	return node


## Car body styles. Keyframes are [u, value] with u=0 at the rear bumper and u=1 at the nose; heights are metres
## above the road, half widths metres from the centreline. fo/ro are front/rear overhangs beyond the axles.
## Cabins are lofted separately: roof keyframes rise from the beltline; roofspan is where the roof is painted.
const BODIES = {
	"roadster":
	{
		"fo": .74,
		"ro": .58,
		"floor": .15,
		"sill": .34,
		"e": 3.2,
		"taper": .22,
		"top":
		[[0, .58], [.04, .72], [.14, .79], [.3, .79], [.55, .8], [.64, .79], [.84, .71], [.95, .6], [1, .47]],
		"half":
		[[0, .66], [.08, .8], [.17, .86], [.3, .8], [.5, .79], [.72, .83], [.81, .85], [.92, .8], [1, .6]],
		"cabin": null,
		"screen": .57,
		"open": [.3, .52]
	},
	"coupe":
	{
		"fo": .95,
		"ro": .8,
		"floor": .15,
		"sill": .36,
		"e": 3.4,
		"taper": .28,
		"top": [[0, .62], [.045, .84], [.12, .93], [.3, .94], [.62, .93], [.8, .82], [.94, .7], [1, .55]],
		"half":
		[
			[0, .66],
			[.08, .88],
			[.19, .92],
			[.35, .86],
			[.55, .86],
			[.74, .9],
			[.84, .9],
			[.95, .82],
			[1, .66]
		],
		"cabin": [[.16, .93], [.24, 1.1], [.38, 1.25], [.47, 1.27], [.53, 1.24], [.64, .93]],
		"roofspan": [.34, .52],
		"cabin_half": .8
	},
	"gt3":
	{
		"fo": .98,
		"ro": .86,
		"floor": .12,
		"sill": .32,
		"e": 3.0,
		"taper": .3,
		"top":
		[
			[0, .82],
			[.035, .90],
			[.1, .93],
			[.3, .9],
			[.42, .86],
			[.66, .84],
			[.82, .74],
			[.94, .64],
			[1, .58]
		],
		"half":
		[[0, .92], [.06, .96], [.2, 1.0], [.34, .9], [.55, .86], [.7, .93], [.81, .95], [.93, .91], [1, .86]],
		"cabin": [[.28, .9], [.37, 1.13], [.46, 1.27], [.55, 1.25], [.68, .85]],
		"roofspan": [.4, .56],
		"cabin_half": .74,
		"splitter": true,
		"diffuser": true,
		"intakes": true
	}
}


func keyframe(frames, u):
	if u <= frames[0][0]:
		return frames[0][1]
	for k in range(1, frames.size()):
		if u <= frames[k][0]:
			var t = (u - frames[k - 1][0]) / maxf(frames[k][0] - frames[k - 1][0], .0001)
			t = t * t * (3 - 2 * t)
			return lerpf(frames[k - 1][1], frames[k][1], t)
	return frames[-1][1]


## Superellipse cross-section; taper narrows the upper half (tumblehome). Returns [points, py values].
func ring(x, y0, y1, hw, taper, e, n):
	var pts = []
	var pys = []
	var yc = (y0 + y1) / 2
	var hh = (y1 - y0) / 2
	for k in n:
		var th = TAU * k / n
		var c = cos(th)
		var s = sin(th)
		var px = signf(c) * pow(absf(c), 2.0 / e)
		var py = signf(s) * pow(absf(s), 2.0 / e)
		pts.append(Vector3(x, yc + py * hh, px * hw * (1 - taper * maxf(0, py))))
		pys.append(py)
	return [pts, pys]


## Smooth-shaded loft through equal-size rings with flat end caps. colors[i][k] matches rings[i][k].
## rear_cap, when given, colours the first (rear) cap, e.g. a dark rear panel.
func loft(st, rings, colors, rear_cap = null):
	var n = rings[0].size()
	var base = 0
	for i in rings.size():
		for k in n:
			st.set_color(colors[i][k])
			st.add_vertex(rings[i][k])
	for i in rings.size() - 1:
		for k in n:
			var a = i * n + k
			var b = i * n + (k + 1) % n
			var c = (i + 1) * n + (k + 1) % n
			var d = (i + 1) * n + k
			for idx in [a, b, c, a, c, d]:
				st.add_index(idx)
	st.generate_normals()
	var caps = SurfaceTool.new()
	caps.begin(Mesh.PRIMITIVE_TRIANGLES)
	for end in [0, rings.size() - 1]:
		var center = Vector3.ZERO
		for v in rings[end]:
			center += v / n
		for k in n:
			var a = rings[end][k]
			var b = rings[end][(k + 1) % n]
			var tri = [center, a, b] if end == 0 else [center, b, a]
			for v in tri:
				caps.set_color(rear_cap if end == 0 and rear_cap != null else colors[end][k])
				caps.add_vertex(v)
	caps.generate_normals()
	return caps


func paint_material(color, ghost):
	if ghost:
		var g = StandardMaterial3D.new()
		g.albedo_color = Color(.35, .8, 1, .28)
		g.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		g.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		return g
	var m = ShaderMaterial.new()
	m.shader = preload("res://shaders/retro_paint.gdshader")
	m.set_shader_parameter("environment_map", RetroAssets.panorama(night, true))
	paint_materials.append(weakref(m))
	return m


func mesh_instance(parent, meshes, mat):
	for mesh in meshes:
		var node = MeshInstance3D.new()
		node.mesh = mesh.commit()
		node.material_override = mat
		parent.add_child(node)


func shape(parent, mesh, pos, scale, color, metallic = 0.0, rough = .6):
	var node = MeshInstance3D.new()
	node.mesh = mesh
	node.position = pos
	node.scale = scale
	node.material_override = material(color, metallic, rough)
	parent.add_child(node)
	return node


## Merge compatible static surfaces in the car body before it reaches the renderer.
## Animated wheels and registered night lamps stay outside each merged group.
func merge_static(body):
	var dynamic = {}
	for ref in headlights:
		var node = ref.get_ref()
		if node != null:
			dynamic[node.get_instance_id()] = true
	var groups = {}
	for part in body.find_children("*", "MeshInstance3D", true, false):
		if not part.visible or dynamic.has(part.get_instance_id()) or part.mesh == null:
			continue
		if part.mesh.get_surface_count() != 1:
			continue
		var mat = part.material_override
		if mat == null:
			mat = part.mesh.surface_get_material(0)
		if mat == null:
			continue
		var key = mat.get_instance_id()
		if not groups.has(key):
			groups[key] = {"material": mat, "parts": []}
		groups[key].parts.append(part)
	for group in groups.values():
		if group.parts.size() < 2:
			continue
		var surface = SurfaceTool.new()
		for part in group.parts:
			var relative = Transform3D.IDENTITY
			var cursor = part
			while cursor != body:
				relative = cursor.transform * relative
				cursor = cursor.get_parent()
			surface.append_from(part.mesh, 0, relative)
		var merged = MeshInstance3D.new()
		merged.name = "MergedStatic"
		merged.mesh = surface.commit()
		merged.material_override = group.material
		body.add_child(merged)
		for part in group.parts:
			part.get_parent().remove_child(part)
			part.free()


## Car visuals: imported NA roadster and procedural race bodies.
## The returned dictionary interface (root/body/pivots/spins/brakes/wheel_r) is posed by game.gd.
func make_car(p, ghost = false):
	match p.get("body", ""):
		"roadster":
			return preload("res://scripts/cars/mx5.gd").new().build(self, p, ghost)
		"coupe":
			return preload("res://scripts/cars/gt.gd").new().build(self, p, ghost)
		"gt3":
			return preload("res://scripts/cars/f296gt3.gd").new().build(self, p, ghost)
	var root = Node3D.new()
	var body = Node3D.new()
	root.add_child(body)
	var style = BODIES.get(p.get("body", "gt3" if p.get("wing", false) else "roadster"), BODIES.roadster)
	var paint = Color(p.get("color", "#e34c32"))
	var trim = Color("1b2126")
	var glass = Color("1d2c36")
	var interior = Color("15191c")
	var x_rear = -p.b - style.ro
	var length = p.a + p.b + style.fo + style.ro
	var R = p.wheelR
	var arch = R + .07
	var stations = 48
	var n = 20
	var rings = []
	var colors = []
	for i in stations + 1:
		var u = float(i) / stations
		var x = x_rear + u * length
		var top = keyframe(style.top, u)
		var hw = keyframe(style.half, u)
		var y0 = style.floor
		for ax in [p.a, -p.b]:
			var dx = x - ax
			if absf(dx) < arch:
				y0 = maxf(y0, R + sqrt(arch * arch - dx * dx) * .92)
		y0 = minf(y0, top - .09)
		var r = ring(x, y0, top, hw, style.taper, style.e, n)
		rings.append(r[0])
		var c = []
		for k in n:
			var color = trim if r[0][k].y < style.sill else paint
			if p.get("body", "") == "gt3" and u > .70 and r[1][k] > .55:
				if absf(r[0][k].z) < .13:
					color = Color("f5e5bd")
				elif absf(r[0][k].z) < .20:
					color = Color("151c2c")
			c.append(color)
		colors.append(c)
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var caps = loft(st, rings, colors, trim)
	var meshes = [st, caps]
	# Cabin / windscreen loft on top of the beltline.
	var cf = style.cabin
	var c0 = style.get("screen", .5) - .04 if cf == null else cf[0][0]
	var c1 = c0 + .08 if cf == null else cf[-1][0]
	rings = []
	colors = []
	for i in 0 if cf == null else 25:
		var u = lerpf(c0, c1, i / 24.0)
		var x = x_rear + u * length
		var belt = keyframe(style.top, u) - .015
		var roof = maxf(keyframe(cf, u), belt + .012)
		var hw = keyframe(style.half, u) * style.cabin_half
		var r = ring(x, belt - .06, roof, hw, .52, 2.6, n)
		rings.append(r[0])
		var c = []
		var roofed = u >= style.roofspan[0] and u <= style.roofspan[1]
		for k in n:
			c.append(paint if roofed and r[1][k] > .55 else glass)
		colors.append(c)
	if not rings.is_empty():
		st = SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		caps = loft(st, rings, colors)
		meshes.append(st)
		meshes.append(caps)
	mesh_instance(body, meshes, paint_material(paint, ghost))
	var ux = func(u): return x_rear + u * length
	var sphere = SphereMesh.new()
	sphere.radial_segments = 16
	sphere.rings = 8
	sphere.radius = .5
	sphere.height = 1
	var cyl = CylinderMesh.new()
	cyl.radial_segments = 12
	cyl.top_radius = .5
	cyl.bottom_radius = .5
	cyl.height = 1
	var cube = BoxMesh.new()
	if style.has("screen"):
		# Raked windscreen in a thin frame for the open car.
		var us = style.screen
		var ts = keyframe(style.top, us)
		var ws = keyframe(style.half, us) * 1.55
		var frame = Node3D.new()
		frame.position = Vector3(ux.call(us), ts + .16, 0)
		frame.rotation.z = .62
		body.add_child(frame)
		shape(frame, cube, Vector3.ZERO, Vector3(.02, .28, ws), glass, .3, .1)
		shape(frame, cube, Vector3(0, .14, 0), Vector3(.035, .03, ws), trim)
		for side in [-1, 1]:
			shape(frame, cube, Vector3(0, 0, side * ws / 2), Vector3(.035, .3, .03), trim)
	if style.has("open"):
		# Open cockpit: dark tub, two seats with headrest fairings and roll hoops.
		var o = style.open
		var mid = ux.call((o[0] + o[1]) / 2)
		var len_o = (o[1] - o[0]) * length
		var top_o = keyframe(style.top, (o[0] + o[1]) / 2)
		shape(
			body,
			cube,
			Vector3(mid, top_o + .005, 0),
			Vector3(len_o, .03, keyframe(style.half, (o[0] + o[1]) / 2) * 1.3),
			interior
		)
		for side in [-1, 1]:
			shape(body, cube, Vector3(mid - .12, top_o + .08, side * .3), Vector3(.1, .18, .4), interior)
			shape(
				body,
				sphere,
				Vector3(ux.call(o[0]) - .12, top_o, side * .3),
				Vector3(.5, .16, .26),
				paint,
				.2,
				.34
			)
			shape(
				body,
				cyl,
				Vector3(ux.call(o[0]) + .08, top_o + .2, side * .3),
				Vector3(.05, .4, .05),
				"b8c0c4",
				.7,
				.3
			)
		shape(
			body, cube, Vector3(ux.call(o[0]) + .08, top_o + .4, 0), Vector3(.05, .05, .65), "b8c0c4", .7, .3
		)
	# Lights: headlamps pick up a faint glow, tail lamps share the brake emission material.
	var lamp = material(Color("f4efe0"), .1, .15).duplicate()
	lamp.emission_enabled = true
	lamp.emission = Color(1, .95, .85) * .35
	var brake_material = material(Color("c3221a"), .1, .25).duplicate()
	brake_material.emission_enabled = true
	for side in [-1, 1]:
		var uf = .955
		var hl = shape(
			body,
			sphere,
			Vector3(ux.call(uf), keyframe(style.top, uf) - .07, side * keyframe(style.half, uf) * .62),
			Vector3(.2, .07, .24),
			"ffffff"
		)
		hl.material_override = lamp
		hl.visible = p.get("body", "") != "gt3"
		var ur = .012
		var tl = shape(
			body,
			cube,
			Vector3(ux.call(ur) - .01, keyframe(style.top, ur) - .1, side * keyframe(style.half, ur) * .6),
			Vector3(.05, .07, .34),
			"ffffff"
		)
		tl.material_override = brake_material
		tl.visible = p.get("body", "") != "gt3"
		# Mirrors on stalks at the front of the cabin.
		var um = c0 + (c1 - c0) * .18
		var belt = keyframe(style.top, um)
		var hwm = keyframe(style.half, um)
		shape(body, cube, Vector3(ux.call(um), belt + .1, side * (hwm * .86)), Vector3(.05, .03, .22), trim)
		shape(
			body,
			sphere,
			Vector3(ux.call(um) - .02, belt + .13, side * (hwm * .86 + .14)),
			Vector3(.12, .1, .17),
			paint,
			.35,
			.28
		)
		if style.get("intakes", false):
			shape(
				body,
				sphere,
				Vector3(ux.call(.3), .55, side * keyframe(style.half, .3) * .97),
				Vector3(.55, .2, .08),
				trim
			)
		if not p.get("wing", false):
			shape(body, cyl, Vector3(ux.call(0) - .03, .3, side * .25), Vector3(.09, .12, .09), "9aa3a8", .8, .25).rotation.z = (
				PI / 2
			)
	if style.get("splitter", false) or p.get("wing", false):
		shape(
			body,
			cube,
			Vector3(ux.call(1) - .22, .1, 0),
			Vector3(.5, .025, keyframe(style.half, .97) * 1.9),
			trim
		)
	if style.get("diffuser", false):
		shape(body, cube, Vector3(ux.call(0) + .25, .2, 0), Vector3(.5, .03, keyframe(style.half, .04) * 1.5), trim).rotation.z = -.18
		for f in [-.45, -.15, .15, .45]:
			shape(body, cube, Vector3(ux.call(0) + .2, .17, f), Vector3(.45, .12, .015), trim)
	if p.get("wing", false):
		var wx = ux.call(.045)
		var wy = keyframe(style.top, .05) + .36
		var span = keyframe(style.half, .08) * 2
		for side in [-1, 1]:
			shape(body, cube, Vector3(wx + .05, wy - .18, side * .42), Vector3(.18, .38, .03), trim)
			shape(body, cube, Vector3(wx - .02, wy + .02, side * span / 2), Vector3(.42, .2, .02), trim)
		shape(body, cube, Vector3(wx, wy + .02, 0), Vector3(.36, .035, span), trim).rotation.z = -.12
		shape(body, cube, Vector3(wx - .2, wy + .08, 0), Vector3(.14, .02, span), trim).rotation.z = -.5
	if p.has("num") and not ghost:
		for side in [-1, 1]:
			var label = Label3D.new()
			label.text = str(p.num)
			label.font_size = 96
			label.pixel_size = .0034
			label.outline_size = 18
			label.modulate = Color("f7f3e8")
			label.outline_modulate = Color("111")
			var uu = .47
			label.position = Vector3(
				ux.call(uu),
				(style.sill + keyframe(style.top, uu)) / 2 + .03,
				side * (keyframe(style.half, uu) * (1 - style.taper * .2) + .012)
			)
			label.rotation.y = 0.0 if side > 0 else PI
			body.add_child(label)
		var roof_label = Label3D.new()
		roof_label.text = str(p.num)
		roof_label.font_size = 96
		roof_label.pixel_size = .004
		roof_label.modulate = Color("f7f3e8")
		roof_label.outline_size = 0
		if style.cabin != null and p.get("body", "") != "gt3":
			var ur = (style.roofspan[0] + style.roofspan[1]) / 2
			roof_label.position = Vector3(ux.call(ur), keyframe(style.cabin, ur) + .012, 0)
			roof_label.rotation = Vector3(-PI / 2, PI / 2, 0)
			body.add_child(roof_label)
		else:
			roof_label.free()
	return finish_car(root, body, p, ghost, brake_material, style.fo)


## Shared animated running gear. Dedicated bodies must preserve axle positions and this return contract.
func finish_car(root, body, p, ghost, brake_material, nose = 0.9):
	if not ghost:
		var shadow = MeshInstance3D.new()
		shadow.name = "CarDropShadow"
		var quad = PlaneMesh.new()
		quad.size = Vector2(p.a + p.b + 1.7, p.track + .9)
		shadow.mesh = quad
		shadow.position.y = .025
		var ink = ShaderMaterial.new()
		ink.shader = preload("res://shaders/blob_shadow.gdshader")
		ink.set_shader_parameter("strength", contact_strength())
		shadow.material_override = ink
		shadow_materials.append(weakref(ink))
		shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(shadow)
		var light = SpotLight3D.new()
		light.name = "Headlights"
		light.position = Vector3(p.a + nose, .95, 0)
		light.rotation = Vector3(deg_to_rad(-3.0), -PI / 2, 0)
		light.light_color = Color("c9e5ff")
		# Look-2: a cheap forward beam (no shadows). It sits above the lamp lenses and pitches down 3 degrees:
		# from bumper height it met the road at ~3 degrees and lit almost nothing. Bright enough to show on
		# dark night tarmac 8-40 m ahead; the angle falloff keeps a soft edge.
		light.light_energy = 16
		light.spot_attenuation = .5
		light.spot_range = 80
		light.spot_angle = 20
		light.spot_angle_attenuation = 1.4
		light.shadow_enabled = false
		light.visible = night
		body.add_child(light)
		headlights.append(weakref(light))

	var pivots = []
	var spins = []
	var R = p.wheelR
	var cube = BoxMesh.new()
	var cyl = CylinderMesh.new()
	cyl.top_radius = .5
	cyl.bottom_radius = .5
	cyl.height = 1
	var paint = Color(p.get("color", "#e34c32"))
	# Wheels: tire, disc, caliper (non-spinning), twin-spoke rim and centre lock.
	var rim = Color(p.get("rim", "#aeb6bb"))
	var caliper = Color(p.get("caliper", "#d0a23a"))
	var tire_mesh = CylinderMesh.new()
	tire_mesh.radial_segments = 20
	tire_mesh.rings = 1
	tire_mesh.top_radius = R
	tire_mesh.bottom_radius = R
	tire_mesh.height = .3
	for i in 4:
		var outer = -1.0 if i % 2 == 0 else 1.0
		var pivot = Node3D.new()
		root.add_child(pivot)
		pivot.position = Vector3(p.a if i < 2 else -p.b, R, outer * p.track / 2)
		var spin = Node3D.new()
		pivot.add_child(spin)
		var tire = MeshInstance3D.new()
		tire.mesh = tire_mesh
		tire.material_override = material(Color("16191b"), 0, .92)
		tire.rotation.x = PI / 2
		spin.add_child(tire)
		if p.get("body", "") == "gt3":
			preload("res://scripts/ferrari_296.gd").wheel_details(self, spin, pivot, R, outer, rim, caliper)
			pivots.append(pivot)
			spins.append(spin)
			continue
		var wall = shape(spin, cyl, Vector3(0, 0, outer * .151), Vector3(R * 1.94, .01, R * 1.94), "2a2f33")
		wall.rotation.x = PI / 2
		var disc = shape(
			spin, cyl, Vector3(0, 0, outer * .08), Vector3(R * 1.25, .03, R * 1.25), "585d60", .6, .4
		)
		disc.rotation.x = PI / 2
		var barrel = shape(
			spin, cyl, Vector3(0, 0, outer * .155), Vector3(R * 1.4, .012, R * 1.4), "3a4046", .6, .35
		)
		barrel.rotation.x = PI / 2
		for spoke in 10:
			var angle = spoke * TAU / 10 + (0.12 if spoke % 2 else -0.12)
			var part = shape(
				spin,
				cube,
				Vector3(cos(angle) * R * .36, sin(angle) * R * .36, outer * .165),
				Vector3(R * .62, .035, .03),
				rim,
				.75,
				.3
			)
			part.rotation.z = angle
		var hub = shape(spin, cyl, Vector3(0, 0, outer * .17), Vector3(.1, .04, .1), rim, .8, .25)
		hub.rotation.x = PI / 2
		shape(pivot, cube, Vector3(-R * .42, R * .3, outer * .12), Vector3(.12, .14, .06), caliper, .2, .4)
		pivots.append(pivot)
		spins.append(spin)
	if ghost:
		var ghost_mat = paint_material(paint, true)
		for node in root.find_children("*", "MeshInstance3D", true, false):
			node.material_override = ghost_mat
		for node in root.find_children("*", "Label3D", true, false):
			node.visible = false
	return {
		"root": root, "body": body, "pivots": pivots, "spins": spins, "brakes": brake_material, "wheel_r": R
	}


func set_time(value):
	night = value
	var live = []
	for ref in paint_materials:
		var mat = ref.get_ref()
		if mat:
			mat.set_shader_parameter("environment_map", RetroAssets.panorama(night, true))
			live.append(ref)
	paint_materials = live
	refresh_contacts()
	var lit = []
	for ref in headlights:
		var light = ref.get_ref()
		if light:
			light.visible = night
			lit.append(ref)
	headlights = lit


## Directional shadows carry the grounding when they are on; the patch then only adds contact.
func set_cast_shadows(value):
	cast_shadows = value
	refresh_contacts()


func contact_strength():
	var base = NIGHT_CONTACT if night else DAY_CONTACT
	return base * (CAST_SHADOW_CONTACT if cast_shadows else 1.0)


func refresh_contacts():
	var live_shadows = []
	for ref in shadow_materials:
		var mat = ref.get_ref()
		if mat:
			mat.set_shader_parameter("strength", contact_strength())
			live_shadows.append(ref)
	shadow_materials = live_shadows
