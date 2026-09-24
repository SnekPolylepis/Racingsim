extends RefCounted
## NA MX-5: short tail, long low bonnet, pop-up lamp lids and open two-seat cockpit.
const Kit = preload("res://scripts/cars/car_kit.gd")


func build(visuals, preset, ghost):
	var k = Kit.new()
	var root = k.start(visuals, preset, ghost, "MazdaMX5NA")
	var p = preset
	var xr = -p.b - .70
	var xf = p.a + .73
	var w = p.track * .5 + .065
	var widths = [[xr, .57], [-p.b, w], [-.52, w * .96], [.36, w * .93], [p.a, w], [xf, .52]]
	var heights = [[xr, .61], [-p.b, .68], [-.42, .66], [.05, .65], [.58, .62], [p.a, .58], [xf, .43]]
	k.coachwork(xr, xf, widths, heights, .17, .58)
	# The open tub is recessed into the deck. A black surround makes its silhouette readable
	# even at the 640x448 presentation resolution.
	k.box("CockpitWell", Vector3(-.39, .674, 0), Vector3(1.08, .022, 1.11), "151b21")
	for side in [-1, 1]:
		k.box("SeatBack", Vector3(-.58, .82, side * .28), Vector3(.15, .30, .42), "25292b")
		k.box("Headrest", Vector3(-.67, 1.02, side * .28), Vector3(.13, .14, .20), "24292c")
		k.box("DoorTop", Vector3(-.36, .70, side * .59), Vector3(1.08, .055, .06), k.paint)
		k.box("BeltlineChrome", Vector3(-.38, .73, side * .60), Vector3(.92, .015, .012), "9ba5a9", .6)
		# Unmistakable upright NA windscreen, with a dark glazed panel and silver frame.
		k.line(
			"WindscreenPillar", Vector3(.16, .72, side * .61), Vector3(.02, 1.25, side * .57), .032, "2b3034"
		)
		k.box("MirrorStalk", Vector3(.10, .79, side * .72), Vector3(.045, .04, .24), "262a2e")
		k.box("DoorMirror", Vector3(.09, .85, side * .87), Vector3(.16, .10, .19), k.paint)
		# Closed painted pop-up lids; a smaller illuminated lens emerges after dark.
		k.box(
			"PopUpHeadlightLid",
			Vector3(p.a + .37, .595, side * .47),
			Vector3(.34, .018, .31),
			k.paint.darkened(.10)
		)
		k.lamp(
			"RaisedHeadlightLens",
			Vector3(p.a + .39, .65, side * .48),
			Vector3(.12, .10, .25),
			"fff0cf",
			"fff8e2",
			true
		)
		k.lamp(
			"AmberFrontIndicator",
			Vector3(xf + .012, .39, side * .47),
			Vector3(.018, .09, .18),
			"d97d28",
			"f8a443"
		)
		# Paired round taillamps are the NA's most useful chase-camera signature.
		for dz in [-.12, .12]:
			var lamp = SphereMesh.new()
			lamp.radial_segments = 12
			lamp.rings = 6
			lamp.radius = .5
			var node = visuals.shape(
				k.body, lamp, Vector3(xr - .018, .46, side * (.34 + dz)), Vector3(.035, .125, .125), "b31c23"
			)
			node.name = "RoundTailLamp"
			node.material_override = visuals.material("b31c23", .1, .22)
			if not ghost:
				var glow = node.duplicate()
				glow.name = "RoundTailNightGlow"
				glow.position.x -= .012
				var glow_mat = visuals.material("e62722", .08, .2).duplicate()
				glow_mat.emission_enabled = true
				glow_mat.emission = Color("ff321e")
				glow_mat.emission_energy_multiplier = 1.4
				glow.material_override = glow_mat
				glow.visible = visuals.night
				k.body.add_child(glow)
				visuals.headlights.append(weakref(glow))
		k.box("RearReflector", Vector3(xr - .025, .25, side * .46), Vector3(.02, .055, .17), "8b1716")
	k.glass_panel(
		"Windscreen",
		[
			Vector3(.155, .76, -.58),
			Vector3(.155, .76, .58),
			Vector3(.015, 1.23, .54),
			Vector3(.015, 1.23, -.54)
		],
		Vector3.RIGHT
	)
	k.line("WindscreenHeader", Vector3(.015, 1.24, -.56), Vector3(.015, 1.24, .56), .028, "34393d")
	k.box("NoseIntake", Vector3(xf + .016, .29, 0), Vector3(.022, .10, .71), "151b20")
	k.box("FrontBumperLine", Vector3(xf + .024, .23, 0), Vector3(.025, .015, .88), "393b3d")
	k.box("RearPlate", Vector3(xr - .028, .42, 0), Vector3(.02, .13, .29), "d2cfc1")
	k.box("ExhaustTip", Vector3(xr - .18, .17, -.36), Vector3(.19, .06, .08), "788184", .8)
	return k.finish(root, .68)
