extends RefCounted
## Procedural wheel details retained for Visuals.finish_car; the exterior uses cars/f296gt3.gd.


static func wheel_details(visuals, spin, pivot, radius, outer, rim, caliper):
	var cylinder = CylinderMesh.new()
	cylinder.top_radius = .5
	cylinder.bottom_radius = .5
	cylinder.height = 1
	cylinder.radial_segments = 16
	cylinder.rings = 1
	var rubber = TorusMesh.new()
	rubber.inner_radius = radius * .735
	rubber.outer_radius = radius * .995
	rubber.rings = 24
	rubber.ring_segments = 4
	var wall = visuals.shape(spin, rubber, Vector3(0, 0, outer * .13), Vector3(1, .28, 1), "24262b")
	wall.rotation.x = PI / 2
	var dish = visuals.shape(
		spin, cylinder, Vector3(0, 0, outer * .115), Vector3(radius * 1.49, .024, radius * 1.49), "171e25"
	)
	dish.rotation.x = PI / 2
	var rotor = visuals.shape(
		spin,
		cylinder,
		Vector3(0, 0, outer * .142),
		Vector3(radius * 1.19, .013, radius * 1.19),
		"78818b",
		.45,
		.6
	)
	rotor.rotation.x = PI / 2
	var lip = TorusMesh.new()
	lip.inner_radius = radius * .705
	lip.outer_radius = radius * .758
	lip.rings = 24
	lip.ring_segments = 4
	var ring = visuals.shape(spin, lip, Vector3(0, 0, outer * .17), Vector3(1, .52, 1), rim, .55, .32)
	ring.rotation.x = PI / 2
	var cube = BoxMesh.new()
	for spoke in 10:
		var angle = TAU * spoke / 10
		var a = Vector3(cos(angle) * radius * .16, sin(angle) * radius * .16, outer * .185)
		var b = Vector3(cos(angle + .05) * radius * .71, sin(angle + .05) * radius * .71, outer * .169)
		var bar = visuals.shape(spin, cube, (a + b) / 2, Vector3(.017, a.distance_to(b), .024), rim, .55, .32)
		bar.quaternion = Quaternion(Vector3.UP, (b - a).normalized())
		# A short fork where each spoke meets the barrel gives a forged Y cross-section.
		var c = a.lerp(b, .64)
		var d = Vector3(cos(angle - .075) * radius * .71, sin(angle - .075) * radius * .71, outer * .169)
		bar = visuals.shape(spin, cube, (c + d) / 2, Vector3(.012, c.distance_to(d), .023), rim, .55, .32)
		bar.quaternion = Quaternion(Vector3.UP, (d - c).normalized())
	for hole in 20:
		var angle = TAU * hole / 20
		visuals.shape(
			spin,
			cube,
			Vector3(cos(angle) * radius * .50, sin(angle) * radius * .50, outer * .152),
			Vector3(.012, .012, .005),
			"222a31"
		)
	var hub = visuals.shape(
		spin, cylinder, Vector3(0, 0, outer * .185), Vector3(.086, .04, .086), "bfc6ca", .55, .4
	)
	hub.rotation.x = PI / 2
	var lock = visuals.shape(
		spin, cylinder, Vector3(0, 0, outer * .211), Vector3(.046, .014, .046), "262c34", .5, .4
	)
	lock.rotation.x = PI / 2
	visuals.shape(
		pivot,
		cube,
		Vector3(-radius * .43, radius * .15, outer * .158),
		Vector3(.085, .15, .03),
		caliper,
		.2,
		.5
	)
	for legend in [["PIRELLI", PI / 2], ["P ZERO", -PI / 2]]:
		for i in legend[0].length():
			var angle = legend[1] - (i - (legend[0].length() - 1) * .5) * .14 * outer
			var label = Label3D.new()
			label.text = legend[0][i]
			label.font_size = 40
			label.pixel_size = .0010
			label.outline_size = 0
			label.modulate = Color("d0bd66")
			label.position = Vector3(cos(angle) * radius * .87, sin(angle) * radius * .87, outer * .173)
			label.rotation = Vector3(
				0, 0 if outer > 0 else PI, angle - PI / 2 if outer > 0 else PI / 2 - angle
			)
			spin.add_child(label)
