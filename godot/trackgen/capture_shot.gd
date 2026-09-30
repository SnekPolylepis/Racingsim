extends SceneTree
## Screenshot capture tool for track drive scene.
## Run: tools/Godot.exe --path . --script trackgen/capture_shot.gd -- --track=spa --out=docs/rebuild/look-4/spa-before.png

const TrackAsset = preload("res://scripts/track/track_asset.gd")
const TrackDrive = preload("res://scripts/proving/track_drive.gd")
const SpaGen = preload("res://trackgen/spa.gd")
const NordschleifeGen = preload("res://trackgen/nordschleife.gd")
const ProvingGroundGen = preload("res://trackgen/proving_ground.gd")
const MonacoGen = preload("res://trackgen/monaco.gd")
const TrackLights = preload("res://scripts/track/track_lights.gd")
const TrackDriveScene = preload("res://scenes/proving/track_drive.tscn")

var track_id = "spa"
var out_path = "docs/rebuild/look-4/spa-before.png"
var focus = ""
var car_id = "f296gt3"
var drive_inst: Node3D
var frames = 0
var shot_taken = false


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--track="):
			track_id = arg.trim_prefix("--track=")
		elif arg.begins_with("--out="):
			out_path = arg.trim_prefix("--out=")
		elif arg.begins_with("--focus="):
			focus = arg.trim_prefix("--focus=")
		elif arg.begins_with("--car="):
			car_id = arg.trim_prefix("--car=")

	drive_inst = TrackDriveScene.instantiate()
	drive_inst.preset_idx = TrackDrive.PRESET_KEYS.find(car_id)

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://tracks3d"))
	var asset: Node3D = null
	if track_id == "nordschleife":
		asset = NordschleifeGen.build_asset()
	elif track_id == "spa":
		asset = SpaGen.build_asset()
	elif track_id == "proving_ground":
		asset = ProvingGroundGen.build_asset()

	if asset != null:
		var packed = PackedScene.new()
		packed.pack(asset)
		var cache_file = "user://tracks3d/%s_temp.scn" % track_id
		ResourceSaver.save(packed, cache_file)
		drive_inst.track_scene = cache_file
	else:
		drive_inst.track_id = track_id

	root.add_child(drive_inst)


func _process(_delta: float) -> bool:
	frames += 1
	# Give it ~60 frames to finish deferred track loading and settle the chase camera
	if frames > 60 and not shot_taken:
		shot_taken = true
		if focus.begins_with("monaco-"):
			_focus_monaco()
		_take_shot()
	return false


func _focus_monaco() -> void:
	TrackLights.set_night(drive_inst.asset, false)
	var road = drive_inst.asset.get_node("Main")
	var curve: Curve3D = road.working_curve()
	var at = 0.0
	if focus == "monaco-pool":
		var anchor = MonacoGen.world_of(43.73536, 7.42191) + Vector3.UP * 2.0
		at = curve.get_closest_offset(anchor)
	elif focus == "monaco-hairpin":
		at = drive_inst.asset.get_meta("corners")["Grand Hotel Hairpin"] - 30.0
	var station = drive_inst.asset.station(at)
	var forward = station.tangent
	var right = forward.cross(Vector3.UP).normalized()
	var up = right.cross(forward).normalized()
	TrackDrive.place_on_grid(drive_inst.car, Transform3D(Basis(right, up, -forward), station.pos))
	if focus == "monaco-hairpin":
		drive_inst.car.launch(45.0 / 3.6)
	drive_inst.curr_snapshot = drive_inst.car.snapshot()
	drive_inst.prev_snapshot = drive_inst.curr_snapshot
	drive_inst.telemetry_visible = false
	drive_inst.free_fly = true
	var distance = 16.0 if focus == "monaco-hairpin" else 9.0
	var height = 6.0 if focus == "monaco-hairpin" else 4.0
	drive_inst.camera.position = station.pos - forward * distance + up * height
	drive_inst.camera.look_at(station.pos + forward * 7.0 + up * 1.4, up)


func _take_shot() -> void:
	await RenderingServer.frame_post_draw
	var img = root.get_viewport().get_texture().get_image()
	var global_out = ProjectSettings.globalize_path("res://" + out_path)
	var err = img.save_png(global_out)
	print("CAPTURE %s -> %s (err=%d)" % [track_id, global_out, err])
	quit(0 if err == OK else 1)
