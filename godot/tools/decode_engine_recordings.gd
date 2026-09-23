extends SceneTree
## Build-only conversion through Godot's own MP3 decoder; no external codec needed.


func _initialize():
	for stem in ["ferrari-idle", "ferrari-acceleration"]:
		var source = AudioStreamMP3.new()
		source.data = FileAccess.get_file_as_bytes("res://assets/audio-source/" + stem + ".mp3")
		var playback = source.instantiate_playback()
		playback.start()
		var rate = int(AudioServer.get_mix_rate())
		var remaining = int(ceil(source.get_length() * rate))
		var bytes = PackedByteArray()
		while remaining > 0:
			var block = playback.mix_audio(1.0, mini(8192, remaining))
			if block.is_empty():
				break
			var pcm = PackedByteArray()
			pcm.resize(block.size() * 2)
			for i in block.size():
				pcm.encode_s16(i * 2, int(clampf((block[i].x + block[i].y) * .5, -1, 1) * 32767))
			bytes.append_array(pcm)
			remaining -= block.size()
		var wave = AudioStreamWAV.new()
		wave.format = AudioStreamWAV.FORMAT_16_BITS
		wave.mix_rate = rate
		wave.data = bytes
		var status = wave.save_to_wav("res://tests/audio-study/" + stem + ".wav")
		print(stem, " ", source.get_length(), "s at ", rate, " Hz; save=", status)
		if status != OK:
			quit(1)
			return
	quit()
