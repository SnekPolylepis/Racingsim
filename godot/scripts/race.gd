extends RefCounted
## Lap/checkpoint state and approximately 30 Hz best-lap ghost recording.
## No filesystem access: game.gd saves when update_asset returns true for a new best.
## Ghost sample contract (update_asset, P4-02; the 5.4 pose): [seconds, x, y, z, qx, qy, qz, qw,
## lap_distance_m], world metres and the body rotation quaternion.
const TrackAsset = preload("res://scripts/track/track_asset.gd")
var lap_time = 0.0
var active = false
var valid = true
var next_cp = 0
var prev_s = -1.0
var last = 0.0
var last_valid = false
var best = 0.0
var ghost = []
var recording = []
var last_recording = []
var record_t = 0.0
var completed = 0
var off_track_invalidate = true
var collision_invalidate = false
var delta = null
var invalid_reason = ""
## Sectors: the lap is split into three equal-distance sectors from the start line.
## sectors = this lap's completed split times (0 = not yet); flags = "purple" (all-time best for this
## car/setup/rules record), "green" (session best), "yellow" (slower) or "invalid" (lap already invalid).
## best_sectors persist beside the record; sectors_dirty tells game.gd to save them.
var sectors = [0.0, 0.0, 0.0]
var flags = ["", "", ""]
var last_sectors = [0.0, 0.0, 0.0]
var last_flags = ["", "", ""]
var best_sectors = [0.0, 0.0, 0.0]
var session_sectors = [0.0, 0.0, 0.0]
var sector_idx = 0
var sector_start = 0.0
var sectors_dirty = false
## TrackAsset mode (update_asset): the asset's gates (start first, then sector and checkpoint gates in
## lap order), the car's position last tick, and the lap-line projection hint.
var asset_gates = []
var gates_of = null
var prev_pos = null
var asset_hint = -1


## Sum of the best individual sectors, or 0 until all three have been set.
func ideal():
	if best_sectors.min() <= 0:
		return 0.0
	return best_sectors[0] + best_sectors[1] + best_sectors[2]


func complete_sector(i, t):
	sectors[i] = t
	if not valid:
		flags[i] = "invalid"
	else:
		flags[i] = "yellow"
		if session_sectors[i] <= 0 or t < session_sectors[i]:
			session_sectors[i] = t
			flags[i] = "green"
		if best_sectors[i] <= 0 or t < best_sectors[i]:
			best_sectors[i] = t
			flags[i] = "purple"
			sectors_dirty = true
	sector_idx = i + 1
	sector_start = lap_time


## Why the last completed lap was invalid ("" when valid). invalid_reason describes the lap in progress.
var last_reason = ""


## Clear the current attempt without deleting best/ghost or last-lap history.
func reset():
	lap_time = 0
	active = false
	valid = true
	next_cp = 0
	prev_s = -1
	prev_pos = null
	recording = []
	record_t = 0
	delta = null
	invalid_reason = ""
	sectors = [0.0, 0.0, 0.0]
	flags = ["", "", ""]
	sector_idx = 0
	sector_start = 0.0


## One tick on a TrackAsset (P4-02); returns true only when a completed valid lap beats best. Timing uses
## the asset's 3D gates (TrackAsset.gates()/crossed(): the CG crossing each gate's vertical plane forwards,
## within 15 m either side of the lap line and 3 m above or below it, so another deck never counts).
## Every gate must be met in order: a cut that passes outside a gate's bounds, or crosses the gate after
## the one expected, invalidates the lap. Sectors end at the two sector gates and at the line. Off-track
## (car.all_off) and contact (car.collided) rules work as on legacy tracks.
func update_asset(car, asset, dt):
	if gates_of != asset:
		asset_gates = asset.gates()
		gates_of = asset
		asset_hint = -1
	var pos = car.pos
	var pr = asset.project(pos, asset_hint)
	asset_hint = pr.idx
	var d = asset.lap_distance(pr.s)
	var new_best = false
	if active:
		lap_time += dt
		if off_track_invalidate and car.all_off:
			valid = false
			invalid_reason = "off track"
		if collision_invalidate and car.collided:
			valid = false
			invalid_reason = "contact"
		if ghost.size() > 1:
			delta = lap_time - ghost_time_at(d)
		record_t += dt
		if record_t >= 1.0 / 30:
			record_t = 0
			var q = car.rot
			recording.append([lap_time, pos.x, pos.y, pos.z, q.x, q.y, q.z, q.w, d])
	car.collided = false
	var count = asset_gates.size()
	if prev_pos != null and active:
		for skip in 2:
			# The expected gate, or the one after it (which means the expected one was missed).
			var k = next_cp + skip
			if k >= count or not TrackAsset.crossed(asset_gates[k], prev_pos, pos):
				continue
			if skip == 1 and valid:
				valid = false
				invalid_reason = "missed %s %d" % [asset_gates[next_cp].kind, next_cp]
			# A missed sector gate still ends its sector here (the lap is already invalid).
			for g in range(next_cp, k + 1):
				if asset_gates[g].kind == "sector" and sector_idx < 2:
					complete_sector(sector_idx, lap_time - sector_start)
			next_cp = k + 1
			break
	if prev_pos != null and TrackAsset.crossed(asset_gates[0], prev_pos, pos):
		if active:
			var all_gates = next_cp == count
			if not all_gates and valid:
				valid = false
				invalid_reason = "missed %s %d" % [asset_gates[next_cp].kind, next_cp]
			if sector_idx == 2:
				complete_sector(2, lap_time - sector_start)
			last_sectors = sectors.duplicate()
			last_flags = flags.duplicate()
			last = lap_time
			last_recording = recording
			last_valid = valid and all_gates
			completed += 1
			last_reason = "" if last_valid else invalid_reason
			if last_valid and (best == 0 or lap_time < best):
				best = lap_time
				ghost = recording
				new_best = true
		lap_time = 0
		active = true
		valid = true
		next_cp = 1
		recording = []
		record_t = 0
		invalid_reason = ""
		sectors = [0.0, 0.0, 0.0]
		flags = ["", "", ""]
		sector_idx = 0
		sector_start = 0.0
	prev_pos = pos
	return new_best


## The best-lap ghost's pose now on a TrackAsset (5.4 samples), or null when there is none to show:
## position lerped and rotation slerped between the two samples around lap_time.
func ghost_xform():
	if ghost.size() < 2 or ghost[0].size() < 9 or not active or lap_time > best:
		return null
	var lo = 0
	var hi = ghost.size() - 1
	while lo < hi:
		var mid = (lo + hi + 1) >> 1
		if ghost[mid][0] <= lap_time:
			lo = mid
		else:
			hi = mid - 1
	var a = ghost[lo]
	var b = ghost[mini(lo + 1, ghost.size() - 1)]
	var t = clampf((lap_time - a[0]) / maxf(.00001, b[0] - a[0]), 0, 1)
	var qa = Quaternion(a[4], a[5], a[6], a[7]).normalized()
	var qb = Quaternion(b[4], b[5], b[6], b[7]).normalized()
	return Transform3D(Basis(qa.slerp(qb, t)), Vector3(a[1], a[2], a[3]).lerp(Vector3(b[1], b[2], b[3]), t))


static func time_text(t):
	if t <= 0:
		return "--:--.---"
	return "%d:%06.3f" % [int(t / 60), fmod(t, 60)]


## Interpolate ghost elapsed time by lap distance for the live delta.
## This binary lookup assumes recorded distance is ordered; reversing is not a robust comparison case.
func ghost_time_at(distance):
	var di = 8
	var lo = 0
	var hi = ghost.size() - 1
	while lo < hi:
		var mid = (lo + hi + 1) >> 1
		if ghost[mid][di] <= distance:
			lo = mid
		else:
			hi = mid - 1
	var a = ghost[lo]
	var b = ghost[mini(lo + 1, ghost.size() - 1)]
	return lerpf(a[0], b[0], clampf((distance - a[di]) / maxf(.00001, b[di] - a[di]), 0, 1))
