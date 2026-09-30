extends SceneTree
## Screenshot capture tool for track drive scene.
## Run: tools/Godot.exe --path . --script trackgen/capture_shot.gd -- --track=spa --out=docs/rebuild/look-4/spa-before.png

const TrackAsset = preload("res://scripts/track/track_asset.gd")
const SpaGen = preload("res://trackgen/spa.gd")
const NordschleifeGen = preload("res://trackgen/nordschleife.gd")
const ProvingGroundGen = preload("res://trackgen/proving_ground.gd")
const MonacoGen = preload("res://trackgen/monaco.gd")
const TrackDriveScene = preload("res://scenes/proving/track_drive.tscn")

var track_id = "spa"
var out_path = "docs/rebuild/look-4/spa-before.png"
var focus = ""
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

	drive_inst = TrackDriveScene.instantiate()

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
		if focus == "monaco-pool":
			_focus_monaco_pool()
		_take_shot()
	return false


func _focus_monaco_pool() -> void:
	var road = drive_inst.asset.get_node("Main")
	var curve: Curve3D = road.working_curve()
	var anchor = MonacoGen.world_of(43.73536, 7.42191) + Vector3.UP * 2.0
	var station = drive_inst.asset.station(curve.get_closest_offset(anchor))
	var right = station.tangent.cross(Vector3.UP).normalized()
	drive_inst.model.root.visible = false
	drive_inst.telemetry_visible = false
	drive_inst.free_fly = true
	drive_inst.camera.position = station.pos - right * 14.0 - station.tangent * 14.0 + Vector3.UP * 5.0
	drive_inst.camera.look_at(
		station.pos + right * 6.0 + station.tangent * 4.0 + Vector3.UP * 2.0, Vector3.UP
	)


func _take_shot() -> void:
	await RenderingServer.frame_post_draw
	var img = root.get_viewport().get_texture().get_image()
	var global_out = ProjectSettings.globalize_path("res://" + out_path)
	var err = img.save_png(global_out)
	print("CAPTURE %s -> %s (err=%d)" % [track_id, global_out, err])
	quit(0 if err == OK else 1)
