extends SceneTree
## Exercise the actual circuit button, independent records and a short runtime drive.
var failures = []
var checks = 0


func check(ok: bool, label: String) -> void:
	checks += 1
	print(("PASS " if ok else "FAIL ") + label)
	if not ok:
		failures.append(label)


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var app = load("res://main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	app.frontend.show_page("circuit")
	await process_frame
	var button = null
	for candidate in app.frontend.buttons:
		if candidate.text.begins_with("Chicago — Loop Grid"):
			button = candidate
	check(button != null, "Loop Grid is selectable in the circuit picker")
	if button != null:
		button.pressed.emit()
		while app.frontend.loading:
			await process_frame
		check(
			app.v2_track_id == "chicago_grid" and not app.in_menu,
			"Circuit button loads Loop Grid and starts driving"
		)
		var identity = app.track.record_key()
		check(identity == "chicago_grid@v1", "Variant has independent record identity")
		var lower = app.track.station(app.track.get_meta("corners")["Lower Wacker Portal"] + 250.0)
		app.TrackLights.update_pool(app.lamp_pool, app.track, lower.pos, true)
		var shadowed = true
		for light in app.lamp_pool:
			if light.visible:
				shadowed = shadowed and light.shadow_enabled
		check(shadowed, "Chicago lamps cast deck shadows")
		var tower = app.track.get_node("Scenery/WillisTower")
		var textured = true
		for surface in tower.mesh.get_surface_count():
			textured = (
				textured
				and (
					tower.mesh.surface_get_material(surface).emission_operator
					== BaseMaterial3D.EMISSION_OP_MULTIPLY
				)
			)
		check(textured, "Willis night glow preserves facade textures")
		await physics_frame
		app.v2_bot = app.BotDriver.new(app.track.get_node("BotLine"), app.car, app.v2_surface)
		var start = app.car.pos
		await create_timer(5.0).timeout
		check(
			app.car.pos.distance_to(start) > 5.0 and app.car.speed > 1.0,
			"Selected variant drives in the real game loop"
		)
		app.v2_bot = null
		check(
			app.load_v2_track("chicago") and app.track.record_key() == "chicago@v3",
			"Original Chicago remains available with its record identity"
		)
	for player in app.find_children("*", "AudioStreamPlayer", true, false):
		player.stop()
		player.stream = null
	app.queue_free()
	await process_frame
	await create_timer(.25).timeout
	print("CHICAGO GRID MENU RESULTS ", JSON.stringify({"checks": checks, "failures": failures}))
	call_deferred("quit", 0 if failures.is_empty() else 1)
