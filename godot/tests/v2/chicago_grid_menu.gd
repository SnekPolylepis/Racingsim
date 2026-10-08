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
		check(identity == "chicago_grid@v4", "Variant has independent record identity")
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
		var restrained = true
		for surface in tower.mesh.get_surface_count():
			var mat = tower.mesh.surface_get_material(surface)
			restrained = restrained and mat.metallic_texture == null and mat.roughness_texture == null
			restrained = (
				restrained and mat.metallic == 0.0 and mat.roughness >= 0.4 and mat.metallic_specular <= 0.15
			)
		check(restrained, "Willis dark facade avoids imported gloss-map glare")
		var tips = [Vector3(-17.484, 525.144, -11.483), Vector3(-17.485, 527.408, 15.980)]
		for i in tips.size():
			var beacon = app.track.get_node("Scenery/WillisBeacon%d" % (-1 if i == 0 else 1))
			check(
				(
					beacon.global_position.distance_to(tower.global_position + tips[i]) < 0.05
					and beacon.mesh.get_aabb().size.length() < 1.0
				),
				"Willis antenna %d beacon is attached and small" % i
			)

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
		var monroe = app.track.get_node_or_null("Scenery/MonroeBuilding")
		check(
			monroe is MeshInstance3D and monroe.mesh.get_surface_count() == 14,
			"Monroe authored exterior loads beside the route"
		)
		var excluded_monroe = 0
		for entry in app.track.get_meta("city").excluded:
			if entry.osm_id == "w145498713" and entry.reason == "authored Monroe exterior":
				excluded_monroe += 1
		check(excluded_monroe == 1, "Mapped Monroe replaced exactly once")
		var peoples = app.track.get_node_or_null("Scenery/PeoplesGas")
		check(
			peoples is MeshInstance3D and peoples.mesh.get_surface_count() == 10,
			"Peoples Gas exterior beside route"
		)
		var excluded_peoples = 0
		for entry in app.track.get_meta("city").excluded:
			if entry.osm_id == "r15953438" and entry.reason == "authored Peoples Gas exterior":
				excluded_peoples += 1
		check(excluded_peoples == 1, "Mapped Peoples Gas replaced exactly once")
		var old_republic = app.track.get_node_or_null("Scenery/OldRepublic")
		check(
			old_republic != null and old_republic.mesh.get_surface_count() == 11,
			"Old Republic exterior beside route"
		)
		var excluded_old_republic = 0
		for entry in app.track.get_meta("city").excluded:
			if entry.osm_id == "w127107033" and entry.reason == "authored Old Republic exterior":
				excluded_old_republic += 1
		check(excluded_old_republic == 1, "Mapped Old Republic replaced exactly once")
		var michigan_333 = app.track.get_node_or_null("Scenery/Michigan333")
		check(
			michigan_333 != null and michigan_333.mesh.get_surface_count() == 11,
			"333 North Michigan exterior beside route"
		)
		var excluded_michigan_333 = 0
		for entry in app.track.get_meta("city").excluded:
			if entry.osm_id == "w144710192" and entry.reason == "authored 333 North Michigan exterior":
				excluded_michigan_333 += 1
		check(excluded_michigan_333 == 1, "Mapped 333 North Michigan replaced exactly once")
		var michigan_323 = app.track.get_node_or_null("Scenery/Michigan323")
		check(
			michigan_323 != null and michigan_323.mesh.get_surface_count() == 8,
			"323 North Michigan exterior beside route"
		)
		var excluded_michigan_323 = 0
		for entry in app.track.get_meta("city").excluded:
			if entry.osm_id == "w144710187" and entry.reason == "authored 323 North Michigan exterior":
				excluded_michigan_323 += 1
		check(excluded_michigan_323 == 1, "Mapped 323 North Michigan replaced exactly once")
		var chapin_gore = app.track.get_node_or_null("Scenery/ChapinGore")
		check(
			chapin_gore != null and chapin_gore.mesh.get_surface_count() == 8,
			"Chapin and Gore exterior beside route"
		)
		var excluded_chapin_gore = 0
		for entry in app.track.get_meta("city").excluded:
			if entry.osm_id == "w145493033" and entry.reason == "authored Chapin and Gore exterior":
				excluded_chapin_gore += 1
		check(excluded_chapin_gore == 1, "Mapped Chapin and Gore replaced exactly once")
		check(app.track.has_node("Scenery/Equitable"), "Equitable loads in Grid")
		check(app.track.has_node("Scenery/HyattPlace"), "Authored Hyatt Place loads in Grid")
		check(app.track.has_node("Scenery/CityHall"), "Authored City Hall west half loads in Grid")
		check(app.track.has_node("Scenery/CountyBuilding"), "Authored County east half loads in Grid")
		check(app.track.has_node("Scenery/WashingtonBlock"), "Washington Block loads in Grid")
		check(app.track.has_node("Scenery/IAMTemple"), "I AM Temple loads in Grid")
		var depaul_cdm = app.track.get_node_or_null("Scenery/DePaulCDM")
		check(
			depaul_cdm != null and depaul_cdm.mesh.get_surface_count() == 8,
			"DePaul CDM exterior beside route"
		)
		var excluded_depaul_cdm = 0
		for entry in app.track.get_meta("city").excluded:
			if entry.osm_id == "w35601477" and entry.reason == "authored DePaul CDM exterior":
				excluded_depaul_cdm += 1
		check(excluded_depaul_cdm == 1, "Mapped DePaul CDM replaced exactly once")
		var london = app.track.get_node_or_null("Scenery/LondonGuarantee")
		check(
			london is MeshInstance3D and london.mesh.get_surface_count() == 11,
			"London Guarantee loads its authored historic exterior"
		)
		var london_excluded = 0
		for entry in app.track.get_meta("city").excluded:
			if entry.osm_id == "w147399567" and entry.reason == "authored London Guarantee exterior":
				london_excluded += 1
		check(london_excluded == 1, "Mapped London Guarantee replaced once without generic cupola")
		var brooks = app.track.get_node_or_null("Scenery/BrooksBuilding")
		check(
			brooks is MeshInstance3D and brooks.mesh.get_surface_count() == 10,
			"Authored Brooks exterior loads"
		)
		var excluded_brooks = 0
		for entry in app.track.get_meta("city").excluded:
			if entry.osm_id == "w73766157" and entry.reason == "authored Brooks exterior":
				excluded_brooks += 1
		check(excluded_brooks == 1, "Mapped Brooks replaced exactly once")
		var garage = app.track.get_node_or_null("Scenery/FranklinGarage")
		check(
			garage is MeshInstance3D and garage.mesh.get_surface_count() == 7,
			"Authored Franklin garage loads"
		)
		var excluded_garage = 0
		for entry in app.track.get_meta("city").excluded:
			if entry.osm_id == "w74268219" and entry.reason == "authored Franklin Van Buren garage exterior":
				excluded_garage += 1
		check(excluded_garage == 1, "Mapped Franklin garage replaced exactly once")
		var wacker225 = app.track.get_node_or_null("Scenery/Wacker225")
		check(
			wacker225 is MeshInstance3D and wacker225.mesh.get_surface_count() == 9,
			"Authored 225 Wacker loads"
		)
		var excluded_wacker225 = 0
		for entry in app.track.get_meta("city").excluded:
			if entry.osm_id == "w64391366" and entry.reason == "authored 225 West Wacker exterior":
				excluded_wacker225 += 1
		check(excluded_wacker225 == 1, "Mapped 225 Wacker replaced exactly once")
		var wacker125 = app.track.get_node_or_null("Scenery/Wacker125")
		check(
			wacker125 is MeshInstance3D and wacker125.mesh.get_surface_count() == 10,
			"Authored 125 Wacker loads"
		)
		var excluded_wacker125 = 0
		for entry in app.track.get_meta("city").excluded:
			if entry.osm_id == "w147350191" and entry.reason == "authored 125 South Wacker exterior":
				excluded_wacker125 += 1
		check(excluded_wacker125 == 1, "Mapped 125 Wacker replaced exactly once")
		var wacker71 = app.track.get_node_or_null("Scenery/Wacker71")
		check(
			wacker71 is MeshInstance3D and wacker71.mesh.get_surface_count() == 11, "Authored 71 Wacker loads"
		)
		var excluded_wacker71 = 0
		for entry in app.track.get_meta("city").excluded:
			if entry.osm_id == "w148685510" and entry.reason == "authored 71 South Wacker exterior":
				excluded_wacker71 += 1
		check(excluded_wacker71 == 1, "Mapped 71 Wacker replaced exactly once")
		var wacker111 = app.track.get_node_or_null("Scenery/Wacker111")
		check(
			wacker111 is MeshInstance3D and wacker111.mesh.get_surface_count() == 9,
			"Authored 111 Wacker loads"
		)
		var excluded_wacker111 = 0
		for entry in app.track.get_meta("city").excluded:
			if entry.osm_id == "w64887962" and entry.reason == "authored 111 South Wacker exterior":
				excluded_wacker111 += 1
		check(excluded_wacker111 == 1, "Mapped 111 Wacker replaced exactly once")
		var wacker155 = app.track.get_node_or_null("Scenery/Wacker155")
		check(
			wacker155 is MeshInstance3D and wacker155.mesh.get_surface_count() == 9,
			"Authored 155 Wacker loads"
		)
		var excluded_wacker155 = 0
		for entry in app.track.get_meta("city").excluded:
			if entry.osm_id == "w136662656" and entry.reason == "authored 155 North Wacker exterior":
				excluded_wacker155 += 1
		check(excluded_wacker155 == 1, "Mapped 155 Wacker replaced exactly once")
		var wacker = app.track.get_node_or_null("Scenery/Wacker191")
		check(wacker is MeshInstance3D and wacker.mesh.get_surface_count() == 10, "Authored 191 Wacker loads")
		var excluded_wacker = 0
		for entry in app.track.get_meta("city").excluded:
			if entry.osm_id == "w147013355" and entry.reason == "authored 191 North Wacker exterior":
				excluded_wacker += 1
		check(excluded_wacker == 1, "Mapped 191 Wacker replaced exactly once")
		var monadnock = app.track.get_node_or_null("Scenery/MonadnockBuilding")
		check(
			monadnock is MeshInstance3D and monadnock.mesh.get_surface_count() == 9,
			"Authored Monadnock loads"
		)
		var excluded_monadnock = 0
		for entry in app.track.get_meta("city").excluded:
			if entry.osm_id == "w73671128" and entry.reason == "authored Monadnock exterior":
				excluded_monadnock += 1
		check(excluded_monadnock == 1, "Historic Monadnock block replaced exactly once")
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
			app.load_v2_track("chicago") and app.track.record_key() == "chicago@v6",
			"Original Chicago remains available with its record identity"
		)
		check(app.track.has_node("Scenery/HyattPlace"), "Authored Hyatt Place loads in Original Chicago")
		check(
			app.track.has_node("Scenery/CityHall"), "Authored City Hall west half loads in Original Chicago"
		)
		check(
			app.track.has_node("Scenery/CountyBuilding"),
			"Authored County east half loads in Original Chicago"
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
		check(app.track.has_node("Scenery/MonroeBuilding"), "Authored Monroe loads in original Chicago")
		check(app.track.has_node("Scenery/PeoplesGas"), "Authored Peoples Gas loads in original Chicago")
		check(app.track.has_node("Scenery/OldRepublic"), "Authored Old Republic loads in original Chicago")
		check(
			app.track.has_node("Scenery/Michigan323"), "Authored 323 North Michigan loads in original Chicago"
		)
		check(app.track.has_node("Scenery/ChapinGore"), "Authored Chapin and Gore loads in original Chicago")
		check(app.track.has_node("Scenery/Equitable"), "Equitable loads in Original")
		check(app.track.has_node("Scenery/WashingtonBlock"), "Washington Block loads in Original")
		check(app.track.has_node("Scenery/IAMTemple"), "I AM Temple loads in Original")
		check(app.track.has_node("Scenery/DePaulCDM"), "Authored DePaul CDM loads in original Chicago")
		check(
			app.track.has_node("Scenery/Michigan333"), "Authored 333 North Michigan loads in original Chicago"
		)
		check(app.track.has_node("Scenery/MonadnockBuilding"), "Authored Monadnock loads in original Chicago")
		check(app.track.has_node("Scenery/Wacker191"), "Authored 191 Wacker loads in original Chicago")
		check(app.track.has_node("Scenery/Wacker155"), "Authored 155 Wacker loads in original Chicago")
		check(
			app.track.has_node("Scenery/LondonGuarantee"),
			"Authored London Guarantee loads in original Chicago"
		)
		check(app.track.has_node("Scenery/Wacker125"), "Authored 125 Wacker loads in original Chicago")
		check(app.track.has_node("Scenery/Wacker71"), "Authored 71 Wacker loads in original Chicago")
		check(app.track.has_node("Scenery/Wacker111"), "Authored 111 Wacker loads in original Chicago")
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
