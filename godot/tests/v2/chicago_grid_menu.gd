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
		check(
			app.track.get_meta("city").get("physical_windows", 0) > 1000,
			"Loop Grid includes native frames and glazing on generic measured facades"
		)
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
		var tribune = app.track.get_node_or_null("Scenery/TribuneTower")
		check(
			tribune is MeshInstance3D and tribune.mesh.get_surface_count() >= 5,
			"Tribune Tower loads its authored limestone and open crown exterior"
		)
		var excluded_tribune = false
		for entry in app.track.get_meta("city").excluded:
			if entry.osm_id == "w150407241" and entry.reason == "separate landmark proximity":
				excluded_tribune = true
		check(excluded_tribune, "Mapped Tribune footprint is excluded from generic city geometry")
		var wrigley = app.track.get_node_or_null("Scenery/WrigleyBuilding")
		check(
			wrigley is MeshInstance3D and wrigley.mesh.get_surface_count() == 12,
			"Wrigley loads its mapped Blender exterior"
		)
		var excluded_wrigley = 0
		for entry in app.track.get_meta("city").excluded:
			if entry.osm_id == "r17460539" and entry.reason == "authored Wrigley exterior":
				excluded_wrigley += 1
		check(excluded_wrigley == 2, "Both mapped Wrigley blocks are replaced, without generic duplicates")
		var jewelers = app.track.get_node_or_null("Scenery/JewelersBuilding")
		check(
			jewelers is MeshInstance3D and jewelers.mesh.get_surface_count() == 10,
			"Jewelers Building loads its authored domed exterior"
		)
		var excluded_jewelers = 0
		for entry in app.track.get_meta("city").excluded:
			if entry.osm_id == "w124865488" and entry.reason == "authored Jewelers exterior":
				excluded_jewelers += 1
		check(excluded_jewelers == 1, "Mapped Jewelers block is replaced exactly once")
		var carbide = app.track.get_node_or_null("Scenery/CarbideCarbon")
		check(
			carbide is MeshInstance3D and carbide.mesh.get_surface_count() == 8,
			"Authored Carbide and Carbon loads"
		)
		var excluded_carbide = 0
		for entry in app.track.get_meta("city").excluded:
			if entry.osm_id == "w148544831" and entry.reason == "authored Carbide and Carbon exterior":
				excluded_carbide += 1
		check(excluded_carbide == 1, "Mapped Carbide and Carbon block is replaced exactly once")
		var reliance = app.track.get_node_or_null("Scenery/RelianceBuilding")
		check(
			reliance is MeshInstance3D and reliance.mesh.get_surface_count() == 8, "Authored Reliance loads"
		)
		var excluded_reliance = 0
		var neighboring_block_kept = true
		for entry in app.track.get_meta("city").excluded:
			if entry.osm_id == "w124865461" and entry.reason == "authored Reliance exterior":
				excluded_reliance += 1
			neighboring_block_kept = neighboring_block_kept and entry.osm_id != "w145625877"
		check(
			excluded_reliance == 1 and neighboring_block_kept,
			"Historic Reliance replaced once; larger neighbor retained"
		)

		var board = app.track.get_node_or_null("Scenery/BoardOfTrade")
		check(
			board is MeshInstance3D and board.mesh.get_surface_count() == 10,
			"Board of Trade loads its complete authored compound"
		)
		var excluded_board = 0
		for entry in app.track.get_meta("city").excluded:
			if entry.osm_id == "w28951633" and entry.reason == "authored Board of Trade exterior":
				excluded_board += 1
		check(excluded_board == 1, "Mapped Board of Trade compound is excluded exactly once")
		var chicago_buildings = [
			"ChicagoTheatre",
			"PageBrothers",
			"CulturalCenter",
			"RailwayExchange",
			"AthleticAssociation",
			"UniversityClub",
			"OrchestraHall"
		]
		for name in chicago_buildings:
			var building = app.track.get_node_or_null("Scenery/City/" + name)
			check(
				building is MeshInstance3D and building.mesh.get_surface_count() >= 5,
				name + " loads the authored multi-material 3D exterior"
			)
			if building is MeshInstance3D:
				var no_photo = true
				for surface in building.mesh.get_surface_count():
					var texture = building.mesh.surface_get_material(surface).albedo_texture
					no_photo = (
						no_photo
						and (
							texture == null
							or not texture.resource_path.begins_with("res://assets/chicago/facade-photos/")
						)
					)
				check(no_photo, name + " no longer renders a full-building photo panel")
		await physics_frame
		app.v2_bot = app.BotDriver.new(app.track.get_node("BotLine"), app.car, app.v2_surface)
		var engine_bus = AudioServer.get_bus_index("Engine")
		var capture = AudioEffectCapture.new()
		capture.buffer_length = 6.0
		var capture_index = AudioServer.get_bus_effect_count(engine_bus)
		AudioServer.add_bus_effect(engine_bus, capture)
		var effects_on_engine = []
		for key in app.sound.players:
			var player = app.sound.players[key]
			if player.bus == "Engine" and not (key.begins_with("engine_") or key.begins_with("coast_")):
				effects_on_engine.append(player)
				player.bus = "World"
		var start = app.car.pos
		await create_timer(5.0).timeout
		var engine_peak = 0.0
		for frame in capture.get_buffer(capture.get_frames_available()):
			engine_peak = maxf(engine_peak, maxf(absf(frame.x), absf(frame.y)))
		print("CHICAGO gameplay engine peak ", engine_peak)
		check(engine_peak > .001, "Gameplay engine bus produces audio while driving")
		var engine_voices_playing = true
		for band in app.sound.current_engine_bands:
			for prefix in ["engine_", "coast_"]:
				engine_voices_playing = engine_voices_playing and app.sound.players[prefix + band[0]].playing
		check(engine_voices_playing, "All gameplay engine loops remain playing after car voice selection")
		for player in effects_on_engine:
			player.bus = "Engine"
		AudioServer.remove_bus_effect(engine_bus, capture_index)
		check(
			app.car.pos.distance_to(start) > 5.0 and app.car.speed > 1.0,
			"Selected variant drives in the real game loop"
		)
		app.v2_bot = null
		check(
			app.load_v2_track("chicago") and app.track.record_key() == "chicago@v3",
			"Original Chicago remains available with its record identity"
		)
		check(app.track.has_node("Scenery/TribuneTower"), "Authored Tribune Tower loads in original Chicago")
		check(app.track.has_node("Scenery/WrigleyBuilding"), "Authored Wrigley loads in original Chicago")
		check(app.track.has_node("Scenery/BoardOfTrade"), "Authored Board of Trade loads in original Chicago")
		check(app.track.has_node("Scenery/JewelersBuilding"), "Authored Jewelers loads in original Chicago")
		check(
			app.track.has_node("Scenery/CarbideCarbon"),
			"Authored Carbide and Carbon loads in original Chicago"
		)
		check(app.track.has_node("Scenery/RelianceBuilding"), "Authored Reliance loads in original Chicago")
		for name in chicago_buildings:
			check(app.track.has_node("Scenery/City/" + name), name + " also loads in original Chicago")
		check(
			app.track.get_meta("city").get("physical_windows", 0) > 1000,
			"Original Chicago includes native generic facade windows"
		)
	for player in app.find_children("*", "AudioStreamPlayer", true, false):
		player.stop()
		player.stream = null
	app.queue_free()
	await process_frame
	await create_timer(.25).timeout
	print("CHICAGO GRID MENU RESULTS ", JSON.stringify({"checks": checks, "failures": failures}))
	call_deferred("quit", 0 if failures.is_empty() else 1)
