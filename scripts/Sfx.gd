extends Node
## Procedural sound effects and a gentle forest ambience. No audio files.

const RATE := 22050

var _sounds := {}        # name -> built sound
var _recipes := {}       # name -> [duration, generator]: built in the background after startup, or on first use
var _warm: Array = []
var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _bird_timer := 3.0
var _lp := 0.0        # low-pass state for warmer noise (reset at the start of every sound)
var _lp2 := 0.0
var _wind: AudioStreamPlayer
var _players3d: Array[AudioStreamPlayer3D] = []
var _next3d := 0
var _hum: AudioStreamWAV


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 20:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	_recipe("chop", 0.16, func(t): return _soft(0.5) * exp(-t * 32.0) * 0.7 + sin(TAU * 140.0 * t) * exp(-t * 25.0) * 0.45)
	_recipe("chop_wood", 0.12, func(t): return sin(TAU * 220.0 * t) * exp(-t * 40.0) * 0.55 + _soft(0.55) * exp(-t * 60.0) * 0.35)
	_recipe("whoosh", 0.18, func(t): return _noise() * sin(PI * t / 0.18) * 0.25)
	_recipe("ouch", 0.22, func(t): return sin(TAU * (190.0 - t * 300.0) * t) * exp(-t * 9.0) * 0.5)
	_recipe("pickup", 0.08, func(t): return sin(TAU * 660.0 * t) * exp(-t * 40.0) * 0.4)
	_recipe("drop", 0.1, func(t): return _soft(0.35) * exp(-t * 50.0) * 0.6)
	# footsteps: a soft crunch on grass, a hollow knock on wooden floors
	_recipe("step", 0.11, func(t): return _soft(0.25) * exp(-t * 38.0) * 0.32 + _soft(0.6) * exp(-t * 90.0) * 0.12)
	_recipe("step_wood", 0.12, func(t): return sin(TAU * 150.0 * t) * exp(-t * 45.0) * 0.35 + sin(TAU * 310.0 * t) * exp(-t * 60.0) * 0.12 + _soft(0.4) * exp(-t * 80.0) * 0.15)
	_recipe("step_stone", 0.1, func(t): return _soft(0.7) * exp(-t * 55.0) * 0.25 + sin(TAU * 520.0 * t) * exp(-t * 90.0) * 0.06)
	_recipe("thud", 0.14, func(t): return sin(TAU * 90.0 * t) * exp(-t * 30.0) * 0.6 + _noise() * exp(-t * 70.0) * 0.2)
	_recipe("faint", 0.9, func(t): return sin(TAU * (300.0 - t * 200.0) * t) * exp(-t * 2.5) * 0.4)
	# a solid bite into bark: a woody knock, a bright edge, and a crunch of fibres
	_recipe("axe", 0.2, func(t): return _soft(0.55) * exp(-t * 28.0) * 0.45 + sin(TAU * 260.0 * t) * exp(-t * 18.0) * 0.4 + sin(TAU * 820.0 * t) * exp(-t * 40.0) * 0.12 + sin(TAU * 130.0 * t) * exp(-t * 22.0) * 0.2)
	_recipe("drill", 0.17, func(t): return (sin(TAU * 180.0 * t) * 0.4 + signf(sin(TAU * 90.0 * t)) * 0.15 + _noise() * 0.25) * minf(1.0, t * 40.0) * minf(1.0, (0.17 - t) * 40.0))
	_recipe("equip", 0.14, func(t): return sin(TAU * 420.0 * t) * exp(-t * 25.0) * 0.3 + _noise() * exp(-t * 60.0) * 0.15)
	_recipe("buy", 0.5, func(t): return (sin(TAU * 1318.0 * t) * (1.0 if t < 0.12 else 0.0) + sin(TAU * 1760.0 * t) * (1.0 if t >= 0.12 else 0.0)) * exp(-t * 6.0) * 0.3)
	_recipe("rip", 0.3, func(t): return _soft(0.55) * (0.6 + 0.4 * sin(t * 300.0)) * exp(-t * 8.0) * 0.7)
	_recipe("reveal", 0.6, func(t): return sin(TAU * (523.0 if t < 0.15 else (659.0 if t < 0.3 else 784.0)) * t) * exp(-fmod(t, 0.15) * 8.0) * 0.3)
	_recipe("horn", 0.5, func(t): return (signf(sin(TAU * 220.0 * t)) * 0.5 + sin(TAU * 277.0 * t) * 0.5) * minf(1.0, t * 30.0) * minf(1.0, (0.5 - t) * 20.0) * 0.25)
	_recipe("rustle", 0.35, func(t): return _soft(0.5) * (0.5 + 0.5 * sin(t * 90.0 + sin(t * 37.0) * 3.0)) * sin(PI * t / 0.35) * 0.5)
	_recipe("clink", 0.25, func(t): return (sin(TAU * 2100.0 * t) * 0.5 + sin(TAU * 3170.0 * t) * 0.3) * exp(-t * 22.0) * 0.5 + _noise() * exp(-t * 90.0) * 0.4)
	_recipe("saw", 0.2, func(t): return _soft(0.6) * (0.55 + 0.45 * signf(sin(TAU * 38.0 * t))) * sin(PI * t / 0.2) * 0.55)
	# stone: a sharp crack with grit for each chunk, a deep crumble when a rock gives way
	_recipe("crack", 0.22, func(t): return sin(TAU * 1400.0 * t) * exp(-t * 70.0) * 0.25 + _soft(0.65) * exp(-t * 30.0) * 0.5 + sin(TAU * 95.0 * t) * exp(-t * 35.0) * 0.4)
	_recipe("crumble", 0.7, func(t): return (_soft(0.3) * 0.7 + sin(TAU * (70.0 - t * 30.0) * t) * 0.4) * exp(-t * 4.5) * minf(1.0, t * 60.0))
	_recipe("gravel", 0.12, func(t): return _soft(0.5) * exp(-t * 40.0) * 0.35 + sin(TAU * 700.0 * t) * exp(-t * 80.0) * 0.08)
	# rock drill: a hammering grind
	_recipe("grind", 0.25, func(t): return (_soft(0.7) * 0.45 + signf(sin(TAU * 24.0 * t)) * sin(TAU * 160.0 * t) * 0.25) * minf(1.0, t * 50.0) * minf(1.0, (0.25 - t) * 50.0))
	# machines
	_recipe("thunk", 0.3, func(t): return sin(TAU * (80.0 - t * 60.0) * t) * exp(-t * 14.0) * 0.6 + _soft(0.3) * exp(-t * 40.0) * 0.25 + sin(TAU * 1800.0 * t) * exp(-t * 60.0) * 0.06)
	_recipe("hiss", 0.35, func(t): return _soft(0.85) * sin(PI * t / 0.35) * 0.18)
	_recipe("snip", 0.08, func(t): return sin(TAU * 2600.0 * t) * exp(-t * 90.0) * 0.25 + _soft(0.8) * exp(-t * 120.0) * 0.2)
	_recipe("timber", 0.9, func(t): return (_soft(0.5) * exp(-t * 6.0) * 0.7 + sin(TAU * (120.0 - t * 60.0) * t) * exp(-t * 3.0) * 0.4) * minf(1.0, t * 40.0))
	_recipe("click", 0.04, func(t): return sin(TAU * 900.0 * t) * exp(-t * 80.0) * 0.3)
	_recipe("boot", 0.5, func(t): return sin(TAU * (300.0 + t * 600.0) * t) * exp(-t * 4.0) * 0.25)
	# the second wave of tools
	_recipe("beep", 0.07, func(t): return sin(TAU * 1500.0 * t) * minf(1.0, t * 400.0) * minf(1.0, (0.07 - t) * 200.0) * 0.28)
	_recipe("boom", 1.6, func(t): return (_soft(0.25) * 0.9 + sin(TAU * (55.0 - t * 20.0) * t) * 0.6) * exp(-t * 2.6) * minf(1.0, t * 300.0) + _soft(0.8) * exp(-t * 18.0) * 0.5)
	_recipe("thunder", 2.0, func(t): return _soft(0.9) * exp(-t * 14.0) * 0.8 + (_soft(0.12) * 1.1 + sin(TAU * (48.0 - t * 10.0) * t) * 0.3) * exp(-t * 1.6) * (0.7 + 0.3 * sin(t * 23.0)) * minf(1.0, t * 30.0))
	_recipe("crackle", 0.2, func(t): return _soft(0.95) * (1.0 if fmod(t * 37.0, 1.0) < 0.3 else 0.15) * sin(PI * t / 0.2) * 0.25)
	_recipe("pour", 0.9, func(t): return (_soft(0.5) * 0.35 + sin(TAU * (380.0 + sin(t * 70.0) * 90.0) * t) * 0.05) * minf(1.0, t * 12.0) * minf(1.0, (0.9 - t) * 6.0))
	_recipe("rake", 0.3, func(t): return _soft(0.55) * (0.5 + 0.5 * sin(t * 160.0)) * sin(PI * t / 0.3) * 0.4)
	_recipe("catch", 0.12, func(t): return sin(TAU * 180.0 * t) * exp(-t * 45.0) * 0.45 + _soft(0.4) * exp(-t * 60.0) * 0.3)
	for k in 3:
		var base := 2200.0 + k * 500.0
		_recipe("bird%d" % k, 0.35, func(t): return sin(TAU * (base + sin(t * 60.0) * 300.0) * t) * sin(PI * clampf(t / 0.35, 0.0, 1.0)) * 0.08 * (1.0 if fmod(t, 0.12) < 0.08 else 0.0))
	for i in 12:
		var p3 := AudioStreamPlayer3D.new()
		p3.unit_size = 4.0
		p3.max_distance = 45.0
		add_child(p3)
		_players3d.append(p3)
	# the breeze plays under everything, quietly
	_wind = AudioStreamPlayer.new()
	_wind.stream = _make_wind()
	_wind.volume_db = -17.0
	add_child(_wind)
	_wind.play()


var _engine: AudioStreamWAV = null


## Looping diesel rumble for the trucks.
func engine_stream() -> AudioStreamWAV:
	if _engine == null:
		var dur := 1.0
		_engine = _make(dur, func(t): return sin(TAU * 55.0 * t) * 0.35 + sin(TAU * 110.0 * t) * 0.15 + signf(sin(TAU * 27.5 * t)) * 0.08 + _noise() * 0.05)
		_engine.loop_mode = AudioStreamWAV.LOOP_FORWARD
		_engine.loop_end = int(RATE * dur)
	return _engine


func _recipe(name: String, dur: float, f: Callable) -> void:
	_recipes[name] = [dur, f]
	_warm.append(name)


## The sound called `name`, building it now if it hasn't been yet (null if there's no such sound).
func stream(name: String) -> AudioStreamWAV:
	if not _sounds.has(name):
		if not _recipes.has(name):
			return null
		var r: Array = _recipes[name]
		_sounds[name] = _make(float(r[0]), r[1])
	return _sounds[name]


func _noise() -> float:
	return randf_range(-1.0, 1.0)


## Low-passed noise: `bright` 0..1 (0 = a dull rumble, 1 = close to white noise). Much less harsh than raw noise.
func _soft(bright: float) -> float:
	var k := lerpf(0.04, 0.9, bright)
	_lp += (_noise() - _lp) * k
	_lp2 += (_lp - _lp2) * k
	return _lp2 * (1.6 - bright * 0.6)


## A slow, endless breeze through the trees (loops seamlessly: it fades the loop's ends into each other).
func _make_wind() -> AudioStreamWAV:
	# a soft low rumble: half the sample rate is plenty, and it builds 3x faster at startup (slow in a browser)
	var rate := RATE / 2
	var dur := 5.0
	var n := int(rate * dur)
	var raw := PackedFloat32Array()
	raw.resize(n)
	_lp = 0.0
	_lp2 = 0.0
	for i in n:
		var t := float(i) / rate
		var gust := 0.55 + 0.3 * sin(TAU * t / dur) + 0.15 * sin(TAU * 3.0 * t / dur + 1.3)
		raw[i] = _soft(0.15) * gust
	var fade := int(rate * 0.5)
	var bytes := PackedByteArray()
	bytes.resize(n * 2)
	for i in n:
		var v := raw[i]
		if i < fade:
			var w := float(i) / fade
			v = v * w + raw[n - fade + i] * (1.0 - w)
		bytes.encode_s16(i * 2, int(clampf(v * 0.9, -1.0, 1.0) * 32767.0))
	var ws := AudioStreamWAV.new()
	ws.format = AudioStreamWAV.FORMAT_16_BITS
	ws.mix_rate = rate
	ws.data = bytes
	ws.loop_mode = AudioStreamWAV.LOOP_FORWARD
	ws.loop_begin = 0
	ws.loop_end = n - fade
	return ws


func _make(dur: float, f: Callable) -> AudioStreamWAV:
	_lp = 0.0
	_lp2 = 0.0
	var n := int(RATE * dur)
	var bytes := PackedByteArray()
	bytes.resize(n * 2)
	for i in n:
		var t := float(i) / RATE
		var s: float = f.call(t)
		# soft limiting: loud peaks round off instead of clipping into a harsh buzz
		bytes.encode_s16(i * 2, int(tanh(s * 1.1) / tanh(1.1) * 0.92 * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.data = bytes
	return w


## A sound that comes from a place in the world: louder close by, quieter (and gone) far away.
var played := {}      # name -> times played (tests check sounds actually fire)


func play_at(name: String, pos: Vector3, pitch: float = 1.0, volume_db: float = 0.0) -> void:
	var st := stream(name)
	if st == null:
		return
	played[name] = int(played.get(name, 0)) + 1
	var p := _players3d[_next3d]
	_next3d = (_next3d + 1) % _players3d.size()
	p.stream = st
	p.global_position = pos
	p.pitch_scale = pitch * randf_range(0.94, 1.06)
	p.volume_db = volume_db
	p.play()


var _chainsaw: AudioStreamWAV
var _vacuum: AudioStreamWAV
var _washer: AudioStreamWAV


## The pressure washer: a hard hiss of spray over a pump's buzz (loops).
func washer_stream() -> AudioStreamWAV:
	if _washer == null:
		_washer = _loop(1.0, func(t): return _soft(0.9) * 0.4 + _soft(0.6) * 0.15 + signf(sin(TAU * 50.0 * t)) * sin(TAU * 100.0 * t) * 0.06)
	return _washer


func _loop(dur: float, f: Callable) -> AudioStreamWAV:
	var w := _make(dur, f)
	w.loop_mode = AudioStreamWAV.LOOP_FORWARD
	w.loop_end = int(RATE * dur)
	return w


## Two-stroke chainsaw engine (loops; pitch it up when it's cutting).
func chainsaw_stream() -> AudioStreamWAV:
	if _chainsaw == null:
		_chainsaw = _loop(1.0, func(t):
			var ph := fmod(t * 120.0, 1.0)
			return (ph * 2.0 - 1.0) * 0.3 + sin(TAU * 240.0 * t) * 0.15 + sin(TAU * 360.0 * t) * 0.06 + _soft(0.6) * 0.18 * (0.6 + 0.4 * sin(TAU * 30.0 * t)))
	return _chainsaw


## The leaf vacuum's airy rush with a faint motor whine (loops).
func vacuum_stream() -> AudioStreamWAV:
	if _vacuum == null:
		_vacuum = _loop(1.0, func(t): return _soft(0.55) * 0.5 + _soft(0.2) * 0.25 + sin(TAU * 1100.0 * t) * 0.03 + sin(TAU * 220.0 * t) * 0.05)
	return _vacuum


## Low mechanical hum for running belts (loops).
func hum_stream() -> AudioStreamWAV:
	if _hum == null:
		var dur := 1.0
		_hum = _make(dur, func(t): return sin(TAU * 100.0 * t) * 0.25 + sin(TAU * 200.0 * t) * 0.08 + _soft(0.3) * 0.12 + signf(sin(TAU * 8.0 * t)) * sin(TAU * 400.0 * t) * 0.02)
		_hum.loop_mode = AudioStreamWAV.LOOP_FORWARD
		_hum.loop_end = int(RATE * dur)
	return _hum


func play(name: String, pitch: float = 1.0, volume_db: float = 0.0) -> void:
	var st := stream(name)
	if st == null:
		return
	played[name] = int(played.get(name, 0)) + 1
	var p := _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = st
	p.pitch_scale = pitch * randf_range(0.94, 1.06)
	p.volume_db = volume_db
	p.play()


# ------------------------------------------------------------------ music
# Short, quiet pieces of plucked guitar now and then, with long gaps of just the forest in between.

const PROGRESSIONS := [
	[[48, 55, 60, 64], [45, 52, 57, 60], [41, 48, 53, 57], [43, 50, 55, 59]],      # C  Am F  G
	[[41, 48, 53, 57], [43, 50, 55, 59], [40, 47, 52, 55], [45, 52, 57, 60]],      # F  G  Em Am
	[[48, 55, 60, 64], [43, 50, 55, 59], [45, 52, 57, 60], [41, 48, 53, 57]],      # C  G  Am F
]
const ARP := [0, 1, 2, 3, 2, 1, 2, 3]          # which chord note each eighth plays
const MELODY := [72, 74, 76, 79, 81, 76, 74]
const EIGHTH := 0.4

var music_volume := 0.5
var _mus_players: Array[AudioStreamPlayer] = []
var _mus_next := 0
var _mus_wait := 30.0          # quiet before the first piece
var _mus_step := -1
var _mus_t := 0.0
var _mus_prog := 0
var _mus_queue: Array = []     # notes still to build before a piece can start


static func _midi_hz(m: int) -> float:
	return 440.0 * pow(2.0, (m - 69) / 12.0)


## A soft plucked string: a few harmonics dying away at different rates, and a tiny pick noise.
func _note(m: int) -> AudioStreamWAV:
	var key := "note%d" % m
	if not _sounds.has(key):
		var f := _midi_hz(m)
		_sounds[key] = _make(1.5, func(t):
			var v := sin(TAU * f * t) * exp(-t * 2.2) + sin(TAU * f * 2.0 * t) * 0.38 * exp(-t * 3.6) + sin(TAU * f * 3.0 * t) * 0.16 * exp(-t * 5.5)
			return (v * minf(1.0, t * 250.0) + _soft(0.7) * exp(-t * 70.0) * 0.12) * 0.42)
	return _sounds[key]


func _music_notes(prog: int) -> Array:
	var out: Array = []
	for chord in PROGRESSIONS[prog]:
		for m in chord:
			if not out.has(m):
				out.append(m)
	for m in MELODY:
		if not out.has(m):
			out.append(m)
	return out


func _music(delta: float) -> void:
	if music_volume <= 0.001:
		return
	if _mus_players.is_empty():
		for i in 6:
			var p := AudioStreamPlayer.new()
			add_child(p)
			_mus_players.append(p)
	if _mus_step < 0:
		_mus_wait -= delta
		if _mus_wait > 0.0:
			return
		if _mus_queue.is_empty() and _mus_t == 0.0:
			_mus_prog = randi() % PROGRESSIONS.size()
			_mus_queue = _music_notes(_mus_prog).filter(func(m): return not _sounds.has("note%d" % m))
			_mus_t = 0.001
		# build the notes it needs one per frame, then start
		if not _mus_queue.is_empty():
			_note(_mus_queue.pop_front())
			return
		_mus_step = 0
		_mus_t = 0.0
	_mus_t -= delta
	if _mus_t > 0.0:
		return
	_mus_t += EIGHTH * randf_range(0.97, 1.03)       # a little human timing
	var bars := 8
	if _mus_step >= bars * 8:
		_mus_step = -1
		_mus_t = 0.0
		_mus_wait = randf_range(50.0, 110.0)
		return
	var chord: Array = PROGRESSIONS[_mus_prog][(_mus_step / 8) % 4]
	var i: int = ARP[_mus_step % 8]
	_pluck(int(chord[i]), -16.0 if i == 0 else -19.0)
	# now and then a melody note on the first beat of a bar
	if _mus_step % 8 == 0 and randf() < 0.6:
		_pluck(int(MELODY[randi() % MELODY.size()]), -18.0)
	# the last bar ends on the root, held
	_mus_step += 1


func _pluck(m: int, db: float) -> void:
	var p := _mus_players[_mus_next]
	_mus_next = (_mus_next + 1) % _mus_players.size()
	p.stream = _note(m)
	p.volume_db = db + linear_to_db(maxf(music_volume, 0.0001))
	p.pitch_scale = 1.0
	p.play()


func set_music_volume(v: float) -> void:
	music_volume = v


func _process(delta: float) -> void:
	# build the remaining sounds one per frame after startup, so loading isn't held up by them
	if not _warm.is_empty():
		stream(_warm.pop_front())
	else:
		_music(delta)
	_bird_timer -= delta
	if _bird_timer <= 0.0:
		_bird_timer = randf_range(2.0, 7.0)
		play("bird%d" % (randi() % 3), randf_range(0.9, 1.2), -8.0)


## Master volume, 0..1 (the settings menu sets this; saved with the game).
func set_volume(v: float) -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(v, 0.0001)))
	AudioServer.set_bus_mute(0, v <= 0.001)
