extends Node
## Renders the game's procedural sounds into ONE audio file (a "sound sheet") for the Roblox version, plus a table of
## where each sound starts and how long it is. Roblox plays a part of a sound with PlaybackRegion, so one upload
## covers every sound (new Roblox accounts may only upload a few audio files a month).
## Run: godot --headless --path . res://tools/ExportSounds.tscn   (then tools/export_sounds.sh makes the .ogg)

const GAP := 0.12        # silence between sounds, so a region never bleeds into the next one


func _ready() -> void:
	seed(20261103)       # the same noise every time, so re-exporting doesn't change the file for nothing
	var names: Array = Sfx._recipes.keys()
	names.sort()
	var parts: Array = []      # [name, AudioStreamWAV, loop]
	for n in names:
		parts.append([n, Sfx.stream(n), false])
	parts.append(["engine", Sfx.engine_stream(), true])
	parts.append(["chainsaw", Sfx.chainsaw_stream(), true])
	parts.append(["vacuum", Sfx.vacuum_stream(), true])
	parts.append(["washer", Sfx.washer_stream(), true])
	parts.append(["hum", Sfx.hum_stream(), true])
	parts.append(["wind", Sfx._make_wind(), true])
	var notes: Array = []
	for p in Sfx.PROGRESSIONS.size():
		for m in Sfx._music_notes(p):
			if not notes.has(m):
				notes.append(m)
	notes.sort()
	for m in notes:
		parts.append(["note%d" % m, Sfx._note(m), false])

	var rate := Sfx.RATE
	var out := PackedByteArray()
	var gap := PackedByteArray()
	gap.resize(int(GAP * rate) * 2)
	var lines: Array[String] = []
	out.append_array(gap)
	for part in parts:
		var w: AudioStreamWAV = part[1]
		var data: PackedByteArray = w.data
		if w.loop_mode != AudioStreamWAV.LOOP_DISABLED and w.loop_end > 0:
			data = data.slice(0, w.loop_end * 2)       # only the part that loops seamlessly
		if w.mix_rate != rate:
			data = _resample(data, w.mix_rate, rate)
		var start := float(out.size() / 2) / rate
		var length := float(data.size() / 2) / rate
		out.append_array(data)
		out.append_array(gap)
		lines.append("\t%s = { %.4f, %.4f%s }," % [part[0], start, length, ", true" if part[2] else ""])
	var dir := ProjectSettings.globalize_path("res://roblox/sounds")
	DirAccess.make_dir_recursive_absolute(dir)
	_write_wav(dir + "/timber-sounds.wav", out, rate)

	var lua := "--!strict\n-- Made by tools/ExportSounds.gd from the Godot game's sounds. Don't edit by hand: run tools/export_sounds.sh.\n"
	lua += "-- Every sound is a stretch of one audio file: name = { start, length, loops } in seconds.\n"
	lua += "return {\n\tlength = %.4f,\n\tnotes = { %s },\n\tsounds = {\n\t%s\n\t},\n}\n" % [float(out.size() / 2) / rate, ", ".join(notes.map(func(m): return str(m))), "\n\t".join(lines)]
	var f := FileAccess.open("res://roblox/src/shared/SoundSheet.luau", FileAccess.WRITE)
	f.store_string(lua)
	f.close()
	print("EXPORT wrote %d sounds (%.1f s) to roblox/sounds/timber-sounds.wav" % [parts.size(), float(out.size() / 2) / rate])
	get_tree().quit()


func _resample(data: PackedByteArray, from: int, to: int) -> PackedByteArray:
	var n := data.size() / 2
	var m := int(float(n) * to / from)
	var out := PackedByteArray()
	out.resize(m * 2)
	for i in m:
		var x := float(i) * from / to
		var a := int(x)
		var b := mini(a + 1, n - 1)
		var v := lerpf(data.decode_s16(a * 2), data.decode_s16(b * 2), x - a)
		out.encode_s16(i * 2, int(v))
	return out


func _write_wav(path: String, pcm: PackedByteArray, rate: int) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_buffer("RIFF".to_ascii_buffer())
	f.store_32(36 + pcm.size())
	f.store_buffer("WAVEfmt ".to_ascii_buffer())
	f.store_32(16)
	f.store_16(1)          # PCM
	f.store_16(1)          # mono
	f.store_32(rate)
	f.store_32(rate * 2)
	f.store_16(2)
	f.store_16(16)
	f.store_buffer("data".to_ascii_buffer())
	f.store_32(pcm.size())
	f.store_buffer(pcm)
	f.close()
