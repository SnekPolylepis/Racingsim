extends SceneTree
## P4-07 / section 6 "Laps": the bot (scripts/vehicle/bot_driver.gd) on each generated track, every car,
## both handling models: a valid flying lap (gates in order), zero wheels off the track (grass, gravel,
## runoff), zero wall contacts, finite throughout. Lap times are compared with the recorded baseline in
## docs/rebuild/laps-v2-baseline.json (within 2 %); `-- --record` writes it. The car starts at rest on
## grid slot 1 and the lap is timed from its first start-line crossing to the next.
## Tracks: every trackgen/*.gd generator listed in TRACKS that exists (proving ground now; Spa when it lands).
## `-- --car key` runs one car (tools/run_gates.ps1 splits by car).
## Run: tools/Godot.exe --headless --path . --script tests/v2/laps.gd
const CarBody = preload("res://scripts/vehicle/car_body.gd")
const BotDriver = preload("res://scripts/vehicle/bot_driver.gd")
const TrackAsset = preload("res://scripts/track/track_asset.gd")
const WallQuery = preload("res://scripts/surface/wall_query.gd")
const WallContact = preload("res://scripts/vehicle/wall_contact.gd")
const GatesEnv = preload("res://tests/v2/gates_env.gd")
const DT = 1.0 / 240
const BASELINE = "res://docs/rebuild/laps-v2-baseline.json"
const TRACKS = {"proving_ground": "res://trackgen/proving_ground.gd", "spa": "res://trackgen/spa.gd"}
var presets
var assets = {}
var failures = []
var checks = 0
var results = {}
var frames = 0
var ran = false


func check(ok, what):
	checks += 1
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		failures.append(what)


func _initialize():
	presets = GatesEnv.only_car(JSON.parse_string(FileAccess.get_file_as_string("res://data/cars.json")))
	for id in TRACKS:
		if not ResourceLoader.exists(TRACKS[id]):
			continue
		var asset = load(TRACKS[id]).build_asset()
		asset.prepare()
		root.add_child(asset)
		assets[id] = asset


func _physics_process(_delta):
	frames += 1
	if frames < 3:
		return false
	if ran:
		print("LAPS RESULTS aborted by a script error (see stderr)")
		quit(1)
		return true
	ran = true
	var baseline = {}
	if FileAccess.file_exists(BASELINE):
		baseline = JSON.parse_string(FileAccess.get_file_as_string(BASELINE))
	var record = "--record" in OS.get_cmdline_user_args()
	for id in assets:
		for key in presets:
			for simcade in [false, true]:
				var r = lap(assets[id], key, simcade)
				var name = "%s %s %s" % [id, key, "simcade" if simcade else "simulation"]
				results[name] = r
				var base = baseline.get(name, -1.0)
				var timing = "no baseline yet (run with -- --record)"
				var timing_ok = true
				if base > 0 and r.lap > 0:
					timing = "baseline %.2f s (%+.2f%%)" % [base, (r.lap / base - 1) * 100]
					timing_ok = absf(r.lap / base - 1) < .02
				check(
					r.ok and r.lap > 0 and r.off == 0 and r.walls == 0 and timing_ok,
					(
						"%s: lap %.2f s, %d off-track wheel-ticks, %d wall-contact ticks, max %.1f m off the line, top %.0f km/h; %s"
						% [name, r.lap, r.off, r.walls, r.max_off_line, r.top * 3.6, timing]
					)
				)
	if record:
		var out = baseline.duplicate()
		for name in results:
			if results[name].lap > 0:
				out[name] = snappedf(results[name].lap, .001)
		var f = FileAccess.open(BASELINE, FileAccess.WRITE)
		f.store_string(JSON.stringify(out, "  ", true) + "\n")
		f.close()
		print("RECORDED %s" % BASELINE)
	print("LAPS RESULTS ", JSON.stringify({"checks": checks, "failures": failures, "results": results}))
	quit(0 if failures.is_empty() else 1)
	return true


func lap(asset, key, simcade):
	var c = CarBody.new()
	c.simcade_enabled = simcade
	c.configure(presets[key])
	c.wear_enabled = false
	var pole = asset.grid_slots()[0]
	var fwd = -pole.basis.z
	c.place(pole.origin, atan2(fwd.z, fwd.x), pole.origin.y)
	var surf = asset.surface()
	var walls = WallQuery.new(asset, c.hull_half)
	var bot = BotDriver.new(asset.get_node("BotLine"), c, surf)
	var gates = asset.gates()
	var next_gate = 0
	var started = -1.0
	var lap_time = -1.0
	var off = 0
	var wall_ticks = 0
	var max_off_line = 0.0
	var top = 0.0
	var ok = true
	var prev = c.pos
	var time = 0.0
	# Out-lap from the grid plus one flying lap, with a generous cap.
	var cap = 2.5 * asset.length / 15.0 + 60.0
	while time < cap:
		c.input = bot.command(c)
		c.step(DT, surf, true)
		if WallContact.step(c, walls) > 0:
			wall_ticks += 1
		time += DT
		for w in c.wheels:
			if w.load > 0 and w.surf.id >= 2:
				off += 1
				if OS.get_cmdline_user_args().has("--diag") and off % 120 == 1:
					print(
						(
							"  OFF %s %s t=%.1f s=%.0f v=%.1f plan=%.1f lat=%.2f contacts=%d surf=%d"
							% [
								key,
								simcade,
								time,
								bot.s,
								c.speed,
								bot.planned(bot.s, 1.0),
								bot.lateral,
								c.contacts,
								w.surf.id
							]
						)
					)
		top = maxf(top, c.speed)
		if started >= 0:
			max_off_line = maxf(max_off_line, bot.off_line)
		if TrackAsset.crossed(gates[next_gate], prev, c.pos):
			if next_gate == 0:
				if started >= 0:
					lap_time = time - started
					break
				started = time
				next_gate = 1 % gates.size()
			else:
				next_gate = (next_gate + 1) % gates.size()
		prev = c.pos
		if not is_finite(c.pos_x + c.pos_y + c.pos_z) or bot.off_line > 30.0:
			ok = false
			break
	return {
		"ok": ok, "lap": lap_time, "off": off, "walls": wall_ticks, "max_off_line": max_off_line, "top": top
	}
