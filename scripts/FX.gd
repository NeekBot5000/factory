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


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 8:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
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
	_popup_budget = minf(_popup_budget + delta * 16.0, 16.0)
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
