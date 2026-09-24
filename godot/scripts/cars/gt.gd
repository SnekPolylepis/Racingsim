extends RefCounted
## Front-engined high-downforce GT: stretched bonnet, swept cabin and broad rear wing.
const Kit = preload("res://scripts/cars/car_kit.gd")


func build(visuals, preset, ghost):
	var k = Kit.new()
	var root = k.start(visuals, preset, ghost, "HighDownforceGT")
	var p = preset
	var xr = -p.b - .89
	var xf = p.a + .94
	var w = p.track * .5 + .10
	var widths = [[xr, .74], [-p.b, w], [-.65, w], [.25, w * .92], [.92, w * .98], [p.a, w], [xf, .76]]
	var heights = [[xr, .63], [-p.b, .78], [-.75, .81], [-.10, .79], [.54, .74], [p.a, .76], [xf, .47]]
	k.coachwork(xr, xf, widths, heights, .16, .68)
	var shade = Color(p.get("shade", "#746326"))
	# A compact, swept greenhouse sits behind the unusually long bonnet.
	var front = .12
	var rear = -1.39
	var roof_front = -.37
	var roof_rear = -1.04
	var glass_top = 1.28
	for side in [-1, 1]:
		k.glass_panel(
			"SideGlazing",
			[
				Vector3(front, .71, side * .76),
				Vector3(roof_front, glass_top, side * .58),
				Vector3(roof_rear, glass_top, side * .59),
				Vector3(rear, .77, side * .81)
			],
			Vector3(0, 0, side)
		)
		k.line(
			"FrontPillar",
			Vector3(front, .71, side * .77),
			Vector3(roof_front, glass_top, side * .59),
			.038,
			"171a1d"
		)
		k.line(
			"RearPillar",
			Vector3(rear, .77, side * .81),
			Vector3(roof_rear, glass_top, side * .60),
			.045,
			k.paint.darkened(.2)
		)
		k.box("MirrorStalk", Vector3(.05, .82, side * .87), Vector3(.07, .04, .24), "191f22")
		k.box("AeroMirror", Vector3(.04, .88, side * 1.02), Vector3(.20, .10, .17), k.paint)
		k.box("SideSkirt", Vector3(-.08, .19, side * .91), Vector3(1.80, .09, .13), "111820")
		k.box("DoorLiverySweep", Vector3(-.27, .48, side * .914), Vector3(1.05, .075, .012), shade)
		k.box("FrontCanard", Vector3(xf - .28, .28, side * .73), Vector3(.43, .022, .31), "111820")
		k.lamp(
			"GTHeadlight",
			Vector3(xf + .012, .48, side * .52),
			Vector3(.024, .075, .37),
			"e4ebde",
			"fff7d0",
			true
		)
		k.lamp(
			"GTTailCluster", Vector3(xr - .02, .56, side * .52), Vector3(.035, .12, .37), "ad1720", "f42c21"
		)
		k.box("WingPylon", Vector3(xr + .23, 1.02, side * .53), Vector3(.10, .42, .045), "1a2025")
		k.box("WingEndplate", Vector3(xr + .15, 1.27, side * .91), Vector3(.48, .22, .026), "1a2025")
		k.box("DiffuserFence", Vector3(xr + .23, .17, side * .43), Vector3(.52, .17, .023), "111820")
	k.glass_panel(
		"RakedWindscreen",
		[
			Vector3(front, .73, -.76),
			Vector3(front, .73, .76),
			Vector3(roof_front, glass_top, .58),
			Vector3(roof_front, glass_top, -.58)
		],
		Vector3.RIGHT
	)
	k.glass_panel(
		"RearWindow",
		[
			Vector3(roof_rear, glass_top, -.59),
			Vector3(roof_rear, glass_top, .59),
			Vector3(rear, .77, .81),
			Vector3(rear, .77, -.81)
		],
		Vector3.LEFT
	)
	k.panel(
		"PaintedRoof",
		[
			Vector3(roof_front, glass_top + .012, -.59),
			Vector3(roof_front, glass_top + .012, .59),
			Vector3(roof_rear, glass_top + .012, .59),
			Vector3(roof_rear, glass_top + .012, -.59)
		],
		k.paint,
		Vector3.UP
	)
	k.box("DeepFrontIntake", Vector3(xf + .020, .30, 0), Vector3(.03, .23, .95), "111820")
	k.box("FrontSplitter", Vector3(xf - .17, .12, 0), Vector3(.61, .035, 1.75), "111820")
	k.box("RearDiffuser", Vector3(xr + .18, .15, 0), Vector3(.50, .035, 1.48), "111820")
	k.box("RearWingBlade", Vector3(xr + .15, 1.29, 0), Vector3(.48, .055, 1.83), "1a2025")
	k.box("WingGurney", Vector3(xr - .075, 1.35, 0), Vector3(.025, .10, 1.77), "1a2025")
	k.box("BonnetVent", Vector3(.76, .785, 0), Vector3(.46, .017, .78), "1b2228")
	k.number_plate(p.get("num", "07"), -.37, .47, .925)
	return k.finish(root, .84)
