extends Node
## Serial background JSON writer. Jobs contain immutable snapshots and absolute
## destinations; workers never touch the scene tree or mutable gameplay state.
const Storage = preload("res://scripts/storage.gd")
var jobs = []
var worker: Thread
var errors = []
var failed_jobs = 0


func enqueue(job):
	jobs.append(job)
	_start_next()


func _start_next():
	if worker == null and not jobs.is_empty():
		var job = jobs.pop_front()
		worker = Thread.new()
		var status = worker.start(_write.bind(job))
		if status != OK:
			worker = null
			failed_jobs += 1
			errors.append("Could not start record save: " + str(status))


static func _write(job):
	var storage = Storage.new()
	if not storage.write_json(job.path, job.data):
		return storage.error
	if job.has("legacy"):
		var old = storage.read_json(job.legacy) if FileAccess.file_exists(job.legacy) else null
		if old == null or not storage.validate_ghost(old).is_empty() or job.data.time < float(old.time):
			if not storage.write_json(job.legacy, job.data):
				return storage.error
	return ""


func _collect():
	var result = worker.wait_to_finish()
	worker = null
	if not str(result).is_empty():
		failed_jobs += 1
		errors.append(str(result))


func _process(_dt):
	if worker != null and not worker.is_alive():
		_collect()
	_start_next()


## Reads, imports, deletion and shutdown must observe all earlier writes.
func flush():
	while worker != null or not jobs.is_empty():
		_start_next()
		if worker != null:
			_collect()


func _exit_tree():
	flush()
