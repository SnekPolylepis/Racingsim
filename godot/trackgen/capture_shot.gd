extends SceneTree
## Screenshot capture tool for track drive scene.
## Run: tools/Godot.exe --path . --script trackgen/capture_shot.gd -- --track=spa --out=docs/rebuild/look-4/spa-before.png

const TrackAsset = preload("res://scripts/track/track_asset.gd")
const SpaGen = preload("res://trackgen/spa.gd")
const NordschleifeGen = preload("res://trackgen/nordschleife_s1.gd")
const ProvingGroundGen = preload("res://trackgen/proving_ground.gd")
const TrackDriveScene = preload("res://scenes/proving/track_drive.tscn")

var track_id = "spa"
var out_path = "docs/rebuild/look-4/spa-before.png"
var drive_inst: Node3D
var frames = 0
var shot_taken = false


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--track="):
			track_id = arg.trim_prefix("--track=")
		elif arg.begins_with("--out="):
			out_path = arg.trim_prefix("--out=")

	drive_inst = TrackDriveScene.instantiate()

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://tracks3d"))
	var asset: Node3D = null
	if track_id == "nordschleife_s1":
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
		_take_shot()
	return false


func _take_shot() -> void:
	await RenderingServer.frame_post_draw
	var img = root.get_viewport().get_texture().get_image()
	var global_out = ProjectSettings.globalize_path("res://" + out_path)
	var err = img.save_png(global_out)
	print("CAPTURE %s -> %s (err=%d)" % [track_id, global_out, err])
	quit(0 if err == OK else 1)
