extends SceneTree
## P2-08: test surfaces proving ground debug scene test (REBUILD-PLAN.md P2-08).
## Verifies that scenes/proving/test_surfaces.tscn loads headless, scripted 5 s drive
## (throttle 0.5, no steer) stays finite with 4 wheels down on flat and ramp, all 8 shapes
## teleport cleanly, presets cycle, and HUD toggles.
## Run: tools/Godot.exe --headless --path . --script tests/v2/test_surfaces_scene.gd

const SCENE_PATH = "res://scenes/proving/test_surfaces.tscn"
const DT = 1.0 / 240.0

var scene
var failures = []
var checks = 0
var frames = 0
var ran = false
var results = {}


func check(ok: bool, what: String) -> void:
	checks += 1
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		failures.append(what)


func _initialize() -> void:
	var res = load(SCENE_PATH)
	check(res != null, "scenes/proving/test_surfaces.tscn loads")
	scene = res.instantiate()
	check(scene != null, "test_surfaces scene instantiates")
	root.add_child(scene)


func _physics_process(_delta: float) -> bool:
	frames += 1
	if frames < 3:
		return false
	if ran:
		print("TEST SURFACES SCENE RESULTS aborted by a script error (see stderr)")
		quit(1)
		return true
	ran = true

	run_checks()

	print(
		"TEST SURFACES SCENE RESULTS ",
		JSON.stringify({"checks": checks, "failures": failures, "results": results})
	)
	quit(0 if failures.is_empty() else 1)
	return true


func run_checks() -> void:
	check(scene.surface != null and scene.surface.zones.size() == 8, "8 analytic surface zones present")
	check(scene.car != null, "CarBody instance exists in scene")

	drive_flat()
	drive_ramp()
	teleport_all_shapes()
	preset_cycling()
	hud_toggle()


func drive_flat() -> void:
	scene.teleport_to_zone(0)
	var c = scene.car
	var start_x = c.pos_x

	var all_contacts_down = true
	var stays_finite = true

	# Scripted 5 s drive: 5 * 240 = 1200 ticks
	for i in 1200:
		c.input = {"throttle": 0.5, "brake": 0.0, "steer": 0.0, "clutch": 0.0, "handbrake": 0.0}
		c.step(DT, scene.surface, true)
		if not (is_finite(c.pos_x) and is_finite(c.pos_y) and is_finite(c.pos_z) and is_finite(c.speed)):
			stays_finite = false
			break
		if c.contacts < 4:
			all_contacts_down = false

	var dist = c.pos_x - start_x
	check(stays_finite, "Flat: state remains finite throughout 5 s drive")
	check(dist > 15.0, "Flat: car accelerates forward (moved %.2f m)" % dist)
	check(all_contacts_down, "Flat: all 4 wheels remain in contact with the surface")


func drive_ramp() -> void:
	scene.teleport_to_zone(1)
	var c = scene.car
	var start_x = c.pos_x
	var start_y = c.pos_y

	var all_contacts_down = true
	var stays_finite = true

	# Scripted 5 s drive on 8° ramp
	for i in 1200:
		c.input = {"throttle": 0.5, "brake": 0.0, "steer": 0.0, "clutch": 0.0, "handbrake": 0.0}
		c.step(DT, scene.surface, true)
		if not (is_finite(c.pos_x) and is_finite(c.pos_y) and is_finite(c.pos_z) and is_finite(c.speed)):
			stays_finite = false
			break
		if c.contacts < 4:
			all_contacts_down = false

	var dx = c.pos_x - start_x
	var dy = c.pos_y - start_y
	check(stays_finite, "Ramp 8°: state remains finite throughout 5 s drive")
	check(dx > 10.0 and dy > 1.0, "Ramp 8°: car climbs ramp (dx = %.2f m, dy = %.2f m)" % [dx, dy])
	check(all_contacts_down, "Ramp 8°: all 4 wheels remain in contact climbing ramp")


func teleport_all_shapes() -> void:
	var ok = true
	for i in 8:
		scene.teleport_to_zone(i)
		var c = scene.car
		# Settle for 60 ticks
		for t in 60:
			c.input = {"throttle": 0.0, "brake": 1.0, "steer": 0.0, "clutch": 0.0, "handbrake": 0.0}
			c.step(DT, scene.surface, true)
		if not (is_finite(c.pos_x) and is_finite(c.pos_y) and is_finite(c.pos_z)):
			ok = false
			break
		if c.contacts < 4:
			ok = false
			break
	check(ok, "Teleport to all 8 shapes settles with finite pose and 4 wheels down")


func preset_cycling() -> void:
	var start_preset = scene.preset_keys[scene.preset_idx]
	scene.cycle_preset()
	var next_preset = scene.preset_keys[scene.preset_idx]
	check(
		start_preset != next_preset,
		"cycle_preset switches car preset (%s -> %s)" % [start_preset, next_preset]
	)

	var ok_presets = true
	for p in ["roadster", "gt", "f296gt3"]:
		scene.set_preset(p)
		if scene.car == null or scene.model.is_empty():
			ok_presets = false
	check(ok_presets, "all 3 car presets configure and spawn visual models")


func hud_toggle() -> void:
	var init_vis = scene.hud_visible
	scene.toggle_hud()
	var next_vis = scene.hud_visible
	scene.toggle_hud()
	var restored_vis = scene.hud_visible
	check(init_vis != next_vis and restored_vis == init_vis, "toggle_hud flips HUD visibility correctly")
