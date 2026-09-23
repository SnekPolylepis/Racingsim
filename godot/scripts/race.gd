extends RefCounted
## Lap/checkpoint state and approximately 30 Hz best-lap ghost recording.
## No filesystem access: game.gd saves when update returns true for a new best.
## Ghost sample contract: [seconds, x, y, heading_rad, steer_rad, lap_distance_m].
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


func sector_marks(track):
	var start = float(track.data.get("startS", 0.0))
	return [
		fposmod(start + track.length / 3, track.length), fposmod(start + track.length * 2 / 3, track.length)
	]


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
	recording = []
	record_t = 0
	delta = null
	invalid_reason = ""
	sectors = [0.0, 0.0, 0.0]
	flags = ["", "", ""]
	sector_idx = 0
	sector_start = 0.0


func crossed(a, b, target, length):
	var distance = fposmod(b - a, length)
	return (
		distance > 0
		and distance < 30
		and fposmod(target - a, length) > 0
		and fposmod(target - a, length) <= distance
	)


## Consume post-collision car state; return true only when a completed valid lap beats best.
func update(car, track, dt):
	if track.samples.is_empty() or track.data.startS == null:
		return false
	var pr = track.project(car.x, car.y, car.wheels[0].sIdx)
	var s = pr.s
	var start = float(track.data.get("startS", 0.0))
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
			delta = lap_time - ghost_time_at(fposmod(s - start, track.length))
		record_t += dt
		if record_t >= 1.0 / 30:
			record_t = 0
			recording.append(
				[lap_time, car.x, car.y, car.h, car.steer_angle, fposmod(s - start, track.length)]
			)
	car.collided = false
	# Checkpoint gate: tight when off-track laps are invalid anyway, wide (runoff allowed) when they are not.
	var gate = pr.width / 2 + (4.4 if off_track_invalidate else 25.0)
	if (
		prev_s >= 0
		and active
		and next_cp < track.checkpoints.size()
		and crossed(prev_s, s, track.checkpoints[next_cp], track.length)
	):
		if absf(pr.lat) >= gate and valid:
			valid = false
			invalid_reason = "missed CP %d" % (next_cp + 1)
		next_cp += 1
	if (
		prev_s >= 0
		and active
		and sector_idx < 2
		and crossed(prev_s, s, sector_marks(track)[sector_idx], track.length)
	):
		complete_sector(sector_idx, lap_time - sector_start)
	if prev_s >= 0 and absf(pr.lat) < pr.width / 2 + 4.4:
		if crossed(prev_s, s, start, track.length):
			if active:
				if next_cp != track.checkpoints.size():
					valid = false
				if sector_idx == 2:
					complete_sector(2, lap_time - sector_start)
				last_sectors = sectors.duplicate()
				last_flags = flags.duplicate()
				last = lap_time
				# Completed sample arrays are immutable. Transfer ownership; the next
				# lap gets a new array below, avoiding thousands of deep copies here.
				last_recording = recording
				last_valid = valid and next_cp == track.checkpoints.size()
				completed += 1
				last_reason = (
					""
					if last_valid
					else (
						invalid_reason
						if not invalid_reason.is_empty()
						else "CP %d/%d" % [next_cp, track.checkpoints.size()]
					)
				)
				if last_valid and (best == 0 or lap_time < best):
					best = lap_time
					ghost = recording
					new_best = true
			lap_time = 0
			active = true
			valid = true
			next_cp = 0
			recording = []
			record_t = 0
			invalid_reason = ""
			sectors = [0.0, 0.0, 0.0]
			flags = ["", "", ""]
			sector_idx = 0
			sector_start = 0.0
			for o in track.data.objects:
				if o.type == "cone":
					o.x = o.get("ox", o.x)
					o.y = o.get("oy", o.y)
					o.vx = 0
					o.vy = 0
	prev_s = s
	return new_best


func ghost_pose():
	if ghost.size() < 2 or not active or lap_time > best:
		return []
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
	return [lerpf(a[1], b[1], t), lerpf(a[2], b[2], t), lerp_angle(a[3], b[3], t)]


static func time_text(t):
	if t <= 0:
		return "--:--.---"
	return "%d:%06.3f" % [int(t / 60), fmod(t, 60)]


## Interpolate ghost elapsed time by lap distance for the live delta.
## This binary lookup assumes recorded distance is ordered; reversing is not a robust comparison case.
func ghost_time_at(distance):
	var lo = 0
	var hi = ghost.size() - 1
	while lo < hi:
		var mid = (lo + hi + 1) >> 1
		if ghost[mid][5] <= distance:
			lo = mid
		else:
			hi = mid - 1
	var a = ghost[lo]
	var b = ghost[mini(lo + 1, ghost.size() - 1)]
	return lerpf(a[0], b[0], clampf((distance - a[5]) / maxf(.00001, b[5] - a[5]), 0, 1))
