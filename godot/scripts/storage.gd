extends RefCounted
## Filesystem/JSON boundary, deliberately independent of the scene tree and gameplay.
## root selects racing-data storage; settings location is managed separately by game.gd.
## Check return values and error. Validate parsed Variants before constructing models.
## See docs/DATA-CONTRACTS.md for schemas and limits of validation.
var root = "user://"
var error = ""


func initialize(folder = "user://"):
	error = ""
	root = folder
	for sub in ["tracks", "setups", "ghosts", "records"]:
		if DirAccess.make_dir_recursive_absolute(path(sub)) != OK:
			error = "Cannot write to " + path(sub)
	return error.is_empty()


func path(sub, file = ""):
	return root.path_join(sub).path_join(file) if not file.is_empty() else root.path_join(sub)


func read_json(file):
	error = ""
	var f = FileAccess.open(file, FileAccess.READ)
	if not f:
		error = "Could not read " + file.get_file()
		return null
	var parser = JSON.new()
	if parser.parse(f.get_as_text()) != OK:
		error = "Invalid JSON: " + parser.get_error_message()
		return null
	return parser.data


## Write/flush a temporary sibling, then replace the destination; return success or set error.
func write_json(file, value):
	error = ""
	var f = FileAccess.open(file + ".tmp", FileAccess.WRITE)
	if not f:
		error = "Could not save " + file.get_file()
		return false
	f.store_string(JSON.stringify(value, "  "))
	f.flush()
	var status = f.get_error()
	f.close()
	if status != OK:
		error = "Write failed: " + file.get_file()
		return false
	if DirAccess.rename_absolute(file + ".tmp", file) != OK:
		error = "Could not replace " + file.get_file()
		return false
	return true


func list_files(sub):
	var files = []
	for name in DirAccess.get_files_at(path(sub)):
		if name.ends_with(".json"):
			files.append(path(sub, name))
	files.sort()
	return files


func safe_name(value):
	var result = str(value).strip_edges().validate_filename().left(80)
	while result.ends_with(".") or result.ends_with(" "):
		result = result.left(-1)
	if result.is_empty():
		result = "Untitled"
	var base = result.get_slice(".", 0).to_upper()
	if (
		base
		in [
			"CON",
			"PRN",
			"AUX",
			"NUL",
			"COM1",
			"COM2",
			"COM3",
			"COM4",
			"COM5",
			"COM6",
			"COM7",
			"COM8",
			"COM9",
			"LPT1",
			"LPT2",
			"LPT3",
			"LPT4",
			"LPT5",
			"LPT6",
			"LPT7",
			"LPT8",
			"LPT9"
		]
	):
		result += "_"
	return result


static func numeric(v):
	return (v is float or v is int) and is_finite(float(v))


## Structural format validation allows incomplete editor drafts. Track.validate gates save/drive.
## Optional presentation metadata is not exhaustively validated here.
func validate_track(d):
	if not d is Dictionary or not d.get("points") is Array:
		return "Not a track document."
	if d.points.size() > 2000:
		return "Track exceeds 2000 control points."
	for p in d.points:
		if not p is Dictionary:
			return "Invalid point."
		for k in ["x", "y", "w"]:
			if not numeric(p.get(k)):
				return "Point coordinates and width must be numbers."
		if absf(p.x) > 100000 or absf(p.y) > 100000 or p.w < 4 or p.w > 40:
			return "Point coordinates or width outside supported range."
		for k in ["z", "bank"]:
			if p.has(k) and not numeric(p[k]):
				return "Invalid elevation or banking."
	if (
		not d.get("objects", []) is Array
		or not d.get("paint", {}) is Dictionary
		or not d.get("curbOverride", {}) is Dictionary
	):
		return "Invalid objects, paint or curbs."
	for o in d.get("objects", []):
		if not o is Dictionary or not o.get("type") in ["wall", "tire", "cone"]:
			return "Unknown track object."
		for k in ["x", "y"] if o.type == "cone" else ["x1", "y1", "x2", "y2"]:
			if not numeric(o.get(k)):
				return "Invalid object coordinates."
	for k in d.get("paint", {}):
		var parts = str(k).split(",")
		if (
			parts.size() != 2
			or not parts[0].is_valid_int()
			or not parts[1].is_valid_int()
			or not numeric(d.paint[k])
			or not float(d.paint[k]) in [1.0, 2.0, 3.0]
		):
			return "Invalid surface paint cell."
	for k in ["startS", "gridS"]:
		if d.get(k) != null and not numeric(d[k]):
			return "Invalid start or grid distance."
	return ""


## Validate numeric samples and ordered times; does not certify the recorded lap was legitimate.
func validate_ghost(d):
	if (
		not d is Dictionary
		or not numeric(d.get("time"))
		or d.time <= 0
		or not d.get("samples") is Array
		or d.samples.size() < 2
	):
		return "Not a ghost lap."
	var previous = -1.0
	for sample in d.samples:
		if not sample is Array or sample.size() < 6:
			return "Invalid ghost sample."
		for v in sample:
			if not numeric(v):
				return "Invalid ghost coordinates."
		if sample[0] < previous:
			return "Ghost times must be ordered."
		previous = sample[0]
	return ""
