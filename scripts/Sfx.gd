extends Node
## Procedural sound effects and a gentle forest ambience. No audio files.

const RATE := 22050

var _sounds := {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _bird_timer := 3.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 10:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	_sounds["chop"] = _make(0.16, func(t): return _noise() * exp(-t * 32.0) * 0.9 + sin(TAU * 140.0 * t) * exp(-t * 25.0) * 0.6)
	_sounds["chop_wood"] = _make(0.12, func(t): return sin(TAU * 220.0 * t) * exp(-t * 40.0) * 0.7 + _noise() * exp(-t * 60.0) * 0.4)
	_sounds["whoosh"] = _make(0.18, func(t): return _noise() * sin(PI * t / 0.18) * 0.25)
	_sounds["ouch"] = _make(0.22, func(t): return sin(TAU * (190.0 - t * 300.0) * t) * exp(-t * 9.0) * 0.5)
	_sounds["pickup"] = _make(0.08, func(t): return sin(TAU * 660.0 * t) * exp(-t * 40.0) * 0.4)
	_sounds["drop"] = _make(0.1, func(t): return _noise() * exp(-t * 50.0) * 0.4)
	_sounds["step"] = _make(0.09, func(t): return _noise() * exp(-t * 45.0) * 0.18)
	_sounds["thud"] = _make(0.14, func(t): return sin(TAU * 90.0 * t) * exp(-t * 30.0) * 0.6 + _noise() * exp(-t * 70.0) * 0.2)
	_sounds["faint"] = _make(0.9, func(t): return sin(TAU * (300.0 - t * 200.0) * t) * exp(-t * 2.5) * 0.4)
	for k in 3:
		var base := 2200.0 + k * 500.0
		_sounds["bird%d" % k] = _make(0.35, func(t): return sin(TAU * (base + sin(t * 60.0) * 300.0) * t) * sin(PI * clampf(t / 0.35, 0.0, 1.0)) * 0.08 * (1.0 if fmod(t, 0.12) < 0.08 else 0.0))


func _noise() -> float:
	return randf_range(-1.0, 1.0)


func _make(dur: float, f: Callable) -> AudioStreamWAV:
	var n := int(RATE * dur)
	var bytes := PackedByteArray()
	bytes.resize(n * 2)
	for i in n:
		var t := float(i) / RATE
		var s: float = f.call(t)
		bytes.encode_s16(i * 2, int(clampf(s, -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.data = bytes
	return w


func play(name: String, pitch: float = 1.0, volume_db: float = 0.0) -> void:
	if not _sounds.has(name):
		return
	var p := _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = _sounds[name]
	p.pitch_scale = pitch * randf_range(0.94, 1.06)
	p.volume_db = volume_db
	p.play()


func _process(delta: float) -> void:
	_bird_timer -= delta
	if _bird_timer <= 0.0:
		_bird_timer = randf_range(2.0, 7.0)
		play("bird%d" % (randi() % 3), randf_range(0.9, 1.2), -8.0)
