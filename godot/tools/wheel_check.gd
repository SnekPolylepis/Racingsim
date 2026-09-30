extends SceneTree
## Run windowed: Godot.exe --path godot --script res://tools/wheel_check.gd
## Creates a real constant-force effect with zero magnitude; never drives the wheel.
var rig = preload("res://scripts/wheel_bridge.gd").new()
var elapsed = 0.0
var force_seen = false


func _initialize():
	root.title = "Racing Sim: zero-force CSL DD check"
	call_deferred("begin")


func begin():
	root.show()
	root.grab_focus()
	rig.start(root)


func _process(dt):
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
