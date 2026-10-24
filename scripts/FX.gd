extends Node
## Procedural audio and floating text. No external assets.

var _sounds := {}
var _players: Array[AudioStreamPlayer] = []
var _next_player := 0
var _cooldowns := {}
var _popups: Array[Label3D] = []
var _popup_root: Node3D = null
var _popup_i := 0
var _popup_budget := 0.0
var _emitters: Array[CPUParticles3D] = []
var _emit_i := 0
var _burst_budget := 0.0
var _burst_root: Node3D = null
var music: AudioStreamPlayer
var _mus_bytes := PackedByteArray()
var _mus_i := 0
var _mus_total := 0
const MUS_RATE := 16000
const BPM := 84.0
const CHORDS := [[261.63, 329.63, 392.0], [220.0, 261.63, 329.63], [174.61, 220.0, 261.63], [196.0, 246.94, 293.66]]

const BURSTS := {
	"sawdust": {"color": Color("e8c890"), "amount": 22, "vel": 2.2, "life": 0.6, "size": 0.035, "gravity": -9.0, "spread": 70.0, "emit": 0.0},
	"chips": {"color": Color("b08050"), "amount": 18, "vel": 2.6, "life": 0.7, "size": 0.05, "gravity": -9.0, "spread": 80.0, "emit": 0.0},
	"sparks": {"color": Color("ffb040"), "amount": 26, "vel": 3.4, "life": 0.4, "size": 0.025, "gravity": -6.0, "spread": 80.0, "emit": 3.0},
	"dust": {"color": Color("9a9080"), "amount": 26, "vel": 1.4, "life": 0.9, "size": 0.07, "gravity": -2.0, "spread": 90.0, "emit": 0.0},
	"splash": {"color": Color("a8dcff"), "amount": 18, "vel": 1.8, "life": 0.5, "size": 0.04, "gravity": -9.0, "spread": 60.0, "emit": 0.4},
	"coins": {"color": Color("ffd23f"), "amount": 8, "vel": 2.6, "life": 0.6, "size": 0.06, "gravity": -9.0, "spread": 35.0, "emit": 0.6},
	"magic": {"color": Color("c07bff"), "amount": 24, "vel": 1.6, "life": 0.6, "size": 0.04, "gravity": 1.0, "spread": 180.0, "emit": 2.0},
	"shine": {"color": Color("ffffff"), "amount": 14, "vel": 1.2, "life": 0.5, "size": 0.03, "gravity": 0.0, "spread": 180.0, "emit": 2.0},
}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 8:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	music = AudioStreamPlayer.new()
	add_child(music)
	var beat := 60.0 / BPM
	_mus_total = int(MUS_RATE * beat * 16.0)
	_mus_bytes.resize(_mus_total * 2)
	_sounds["place"] = _tone([300.0, 450.0], 0.09, 0.35, 14.0)
	_sounds["remove"] = _tone([380.0, 240.0], 0.1, 0.3, 14.0)
	_sounds["sell"] = _tone([1046.0, 1568.0], 0.12, 0.22, 16.0)
	_sounds["buy"] = _tone([523.0, 659.0, 784.0], 0.2, 0.3, 9.0)
	_sounds["error"] = _tone([160.0, 140.0], 0.16, 0.35, 10.0, true)
	_sounds["levelup"] = _tone([523.0, 659.0, 784.0, 1046.0], 0.5, 0.35, 4.0)
	_sounds["quest"] = _tone([659.0, 880.0, 1175.0], 0.35, 0.3, 6.0)
	_sounds["click"] = _tone([700.0], 0.04, 0.25, 40.0)
	_sounds["thud"] = _tone([90.0, 60.0], 0.25, 0.5, 9.0, false, 0.5)
	_sounds["saw"] = _tone([620.0, 540.0, 600.0], 0.28, 0.22, 6.0, true, 0.35)
	_sounds["crush"] = _tone([120.0, 80.0, 140.0, 70.0], 0.35, 0.4, 5.0, true, 0.8)
	_sounds["cast"] = _tone([300.0, 200.0], 0.4, 0.25, 4.0, false, 0.6)
	_sounds["press"] = _tone([70.0, 50.0], 0.22, 0.6, 12.0, false, 0.6)
	_sounds["piston"] = _tone([200.0, 150.0], 0.12, 0.3, 18.0, false, 0.7)
	_sounds["polish"] = _tone([2200.0, 2600.0], 0.18, 0.12, 10.0, false, 0.6)
	_sounds["teleport"] = _tone([400.0, 800.0, 1600.0], 0.22, 0.25, 6.0)


func _process(delta: float) -> void:
	if _mus_i < _mus_total:
		_gen_music_chunk(12000)
	_popup_budget = minf(_popup_budget + delta * 16.0, 16.0)
	_burst_budget = minf(_burst_budget + delta * 30.0, 30.0)
	for k in _cooldowns.keys():
		_cooldowns[k] = maxf(0.0, float(_cooldowns[k]) - delta)


func _tone(freqs: Array, dur: float, vol: float, decay: float, square: bool = false, noise: float = 0.0) -> AudioStreamWAV:
	var rate := 22050
	var n := int(rate * dur)
	var bytes := PackedByteArray()
	bytes.resize(n * 2)
	for i in n:
		var t := float(i) / rate
		var seg := mini(int(t / dur * freqs.size()), freqs.size() - 1)
		var f: float = freqs[seg]
		var env := exp(-decay * t) * minf(1.0, t * 300.0)
		var s: float
		if square:
			s = signf(sin(TAU * f * t)) * 0.5
		else:
			s = sin(TAU * f * t) * 0.75 + sin(TAU * f * 2.0 * t) * 0.2
		if noise > 0.0:
			s = lerpf(s, randf_range(-1.0, 1.0), noise)
		bytes.encode_s16(i * 2, int(clampf(s * env * vol, -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.stereo = false
	w.data = bytes
	return w


func play(sound: String, pitch: float = 1.0, cooldown: float = 0.0) -> void:
	if not _sounds.has(sound):
		return
	if cooldown > 0.0:
		if float(_cooldowns.get(sound, 0.0)) > 0.0:
			return
		_cooldowns[sound] = cooldown
	var p := _players[_next_player]
	_next_player = (_next_player + 1) % _players.size()
	p.stream = _sounds[sound]
	p.pitch_scale = pitch
	p.play()


func popup(pos: Vector3, text: String, color: Color = Color("7aff9a")) -> void:
	if _popup_budget < 1.0 or Game.world == null:
		return
	_popup_budget -= 1.0
	if _popup_root == null or not is_instance_valid(_popup_root):
		_popup_root = Node3D.new()
		Game.world.add_child(_popup_root)
		_popups.clear()
	var l: Label3D
	if _popups.size() < 32:
		l = Label3D.new()
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.no_depth_test = true
		l.fixed_size = false
		l.pixel_size = 0.008
		l.font_size = 40
		l.outline_size = 12
		l.outline_modulate = Color(0, 0, 0, 0.85)
		l.render_priority = 5
		_popup_root.add_child(l)
		_popups.append(l)
	else:
		l = _popups[_popup_i]
		_popup_i = (_popup_i + 1) % _popups.size()
	l.text = text
	l.modulate = color
	l.position = pos
	l.visible = true
	var tw := l.create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "position:y", pos.y + 1.1, 0.8)
	tw.tween_property(l, "modulate:a", 0.0, 0.8).set_delay(0.25)
	tw.chain().tween_callback(func(): l.visible = false)


func burst(kind: String, pos: Vector3, dir: Vector3 = Vector3.UP) -> void:
	if _burst_budget < 1.0 or Game.world == null or not BURSTS.has(kind):
		return
	_burst_budget -= 1.0
	if _burst_root == null or not is_instance_valid(_burst_root):
		_burst_root = Node3D.new()
		Game.world.add_child(_burst_root)
		_emitters.clear()
	var e: CPUParticles3D
	if _emitters.size() < 24:
		e = CPUParticles3D.new()
		e.one_shot = true
		e.explosiveness = 0.95
		e.emitting = false
		e.local_coords = false
		_burst_root.add_child(e)
		_emitters.append(e)
	else:
		e = _emitters[_emit_i]
		_emit_i = (_emit_i + 1) % _emitters.size()
	var b: Dictionary = BURSTS[kind]
	var size: float = b.size
	e.mesh = Meshes.box_mesh(Vector3(size, size, size))
	e.material_override = Meshes.mat(b.color, float(b.emit), 0.8)
	e.amount = int(b.amount)
	e.lifetime = float(b.life)
	e.direction = dir.normalized() if dir != Vector3.ZERO else Vector3.UP
	e.spread = float(b.spread)
	e.initial_velocity_min = float(b.vel) * 0.5
	e.initial_velocity_max = float(b.vel)
	e.gravity = Vector3(0, float(b.gravity), 0)
	e.scale_amount_min = 0.6
	e.scale_amount_max = 1.3
	e.angular_velocity_min = -360.0
	e.angular_velocity_max = 360.0
	e.global_position = pos
	e.restart()
	e.emitting = true


func _gen_music_chunk(n: int) -> void:
	var beat := 60.0 / BPM
	var bar_len := beat * 4.0
	var end := mini(_mus_total, _mus_i + n)
	for i in range(_mus_i, end):
		var t := float(i) / MUS_RATE
		var bar := int(t / bar_len) % 4
		var tb := fmod(t, bar_len)
		var chord: Array = CHORDS[bar]
		var pad_env := minf(1.0, tb / 0.6) * minf(1.0, (bar_len - tb) / 0.4)
		var s := 0.0
		for f in chord:
			s += sin(TAU * float(f) * 0.5 * t) * 0.10 + sin(TAU * float(f) * 0.5 * 1.003 * t) * 0.06
		s *= pad_env
		# soft bass on each beat
		var tbeat := fmod(t, beat)
		s += sin(TAU * float(chord[0]) * 0.25 * t) * exp(-tbeat * 3.0) * 0.22
		# pluck arpeggio on eighth notes
		var eighth := beat * 0.5
		var k := int(t / eighth)
		var te := fmod(t, eighth)
		var note: float = float(chord[k % 3]) * (2.0 if (k / 3) % 2 == 0 else 1.0)
		var pl := sin(TAU * note * t) * 0.6 + sin(TAU * note * 2.0 * t) * 0.2
		s += pl * exp(-te * 7.0) * 0.16
		_mus_bytes.encode_s16(i * 2, int(clampf(s * 0.55, -1.0, 1.0) * 32767.0))
	_mus_i = end
	if _mus_i >= _mus_total:
		var w := AudioStreamWAV.new()
		w.format = AudioStreamWAV.FORMAT_16_BITS
		w.mix_rate = MUS_RATE
		w.stereo = false
		w.data = _mus_bytes
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = _mus_total
		music.stream = w
		apply_music_volume()
		music.play()


func apply_music_volume() -> void:
	if music == null:
		return
	var v: float = float(Game.settings.get("music", 0.45))
	music.volume_db = linear_to_db(maxf(v, 0.0001))
