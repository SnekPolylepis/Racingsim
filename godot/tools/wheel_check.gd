extends SceneTree
## Run windowed: Godot.exe --path godot --script res://tools/wheel_check.gd
## Creates a real constant-force effect with zero magnitude; never drives the wheel.
var rig = preload("res://scripts/wheel_bridge.gd").new()
var elapsed = 0.0
var force_seen = false
var menu_check = false


func _initialize():
	menu_check = "--menu-clicks" in OS.get_cmdline_user_args()
	if menu_check:
		call_deferred("menu_probe")
		return
	root.title = "Racing Sim: zero-force CSL DD check"
	call_deferred("begin")


func begin():
	root.show()
	root.grab_focus()
	rig.start(root)


func _process(dt):
	if menu_check:
		return false
	elapsed += dt
	rig.poll()
	if elapsed > 1.0 and elapsed < 3.0:
		rig.active = true
		rig.torque = 0.0
		force_seen = force_seen or rig.force_ready
	if elapsed > 3.0:
		var failures = []
		if rig.present != 3:
			failures.append("Wheel and pedals were not both readable")
		if not force_seen:
			failures.append("Constant-force effect failed: 0x%08x" % rig.force_status)
		print(
			"WHEEL HARDWARE RESULTS ",
			JSON.stringify({"checks": 2, "failures": failures, "axes": Array(rig.axes)})
		)
		rig.close()
		quit(0 if failures.is_empty() else 1)
	return false


func menu_probe():
	var app = load("res://main.tscn").instantiate()
	root.add_child(app)
	await create_timer(3.0).timeout
	var check = preload("res://scripts/presentation_check.gd").new()
	root.add_child(check)
	check.app = app
	check.retro = app.retro
	check.check(app.wheel.present == 3, "live wheel and pedals")
	app.frontend.show_page("main")
	await check.frames(3)
	await check.click(check.button_named(app.frontend, "Race"))
	check.check(app.frontend.page == "car", "mouse opens car selection")
	app.frontend.show_page("main")
	await check.frames(3)
	await check.click(check.button_named(app.frontend, "Settings"))
	check.check(app.frontend.v2_panels.is_open(), "mouse opens settings")
	await check.frames(2)
	await check.click(check.button_named(app.frontend.v2_panels, "Close · Esc"))
	check.check(not app.frontend.v2_panels.is_open(), "mouse closes settings")
	var failures = []
	for name in check.checks:
		if not check.checks[name]:
			failures.append(name)
	print("WHEEL MENU RESULTS ", JSON.stringify({"checks": 4, "failures": failures}))
	app.queue_free()
	check.queue_free()
	await process_frame
	await process_frame
	quit(0 if failures.is_empty() else 1)
