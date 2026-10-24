extends Part
## Sender pads teleport items to receiver pads on the same colour channel (round-robin).

var _ring: MeshInstance3D
var _rr := 0
var _queue: Array[Item] = []
var _flash := 0.0


func init_config() -> void:
	config = {"channel": 0}


func is_sender() -> bool:
	return String(def.role) == "send"


func build() -> void:
	var c: Color = Defs.CHANNEL_COLORS[int(config.channel)]
	_box(Vector3(0.96, 0.2, 0.96), Vector3(0, 0.1, 0), Meshes.mat(DECK_COLOR))
	_cyl(0.42, 0.04, Vector3(0, 0.215, 0), Meshes.mat(Color("1b2030")), Vector3.ZERO, 12)
	for sx in [-1, 1]:
		_box(Vector3(0.1, 0.9, 0.1), Vector3(0.42 * sx, 0.55, 0), Meshes.metal_mat(STEEL))
	_box(Vector3(0.94, 0.1, 0.12), Vector3(0, 1.0, 0), Meshes.metal_mat(STEEL))
	if not is_sender():
		_box(Vector3(0.16, 0.06, 0.3), Vector3(0, 0.24, -0.3), Meshes.mat(Color("ffffff"), 0.6))
	_ring = _anim(Meshes.cyl_mesh(0.36, 0.36, 0.05, 12), Meshes.mat(c, 1.2, 0.3), Vector3(0, 0.25, 0))
	if not ghost:
		body = _make_body()
		_add_shape(body, Vector3(1.0, 0.2, 1.0), Vector3(0, 0.1, 0))
		(body.physics_material_override as PhysicsMaterial).friction = 0.3
		if is_sender():
			_make_area(Vector3(1.04, 0.5, 1.04), Vector3(0, 0.45, 0), _on_enter)


func on_placed() -> void:
	world.register_teleporter(self)


func on_removed() -> void:
	world.unregister_teleporter(self)


func needs_tick() -> bool:
	return is_sender()


func needs_anim() -> bool:
	return true


func config_options() -> Array:
	return [{"key": "channel", "label": "Channel", "values": range(Defs.CHANNEL_COLORS.size()), "names": Defs.CHANNEL_NAMES}]


func on_config_changed() -> void:
	_ring.material_override = Meshes.mat(Defs.CHANNEL_COLORS[int(config.channel)], 1.2, 0.3)


func interact() -> bool:
	config.channel = (int(config.channel) + 1) % Defs.CHANNEL_COLORS.size()
	on_config_changed()
	Game.toast.emit("Channel: %s" % Defs.CHANNEL_NAMES[int(config.channel)], Defs.CHANNEL_COLORS[int(config.channel)])
	return true


func info_lines() -> Array:
	var n: int = 0 if ghost else world.receivers(int(config.channel)).size()
	return ["Channel %s  -  %s" % [Defs.CHANNEL_NAMES[int(config.channel)], ("%d receivers" % n) if is_sender() else "receiver"], "Click to change channel"]


func _on_enter(b: Node3D) -> void:
	var it := b as Item
	if it != null and it.active:
		_queue.append(it)


func tick(_delta: float) -> void:
	if _queue.is_empty():
		return
	var outs: Array = world.receivers(int(config.channel))
	for it in _queue:
		if not is_instance_valid(it) or not it.active:
			continue
		if outs.is_empty() or not enabled():
			continue
		var r: Part = outs[_rr % outs.size()]
		_rr += 1
		it.global_position = r.global_position + Vector3(0, 0.45, 0)
		it.linear_velocity = r.dir_vec() * 2.5
		it.angular_velocity = Vector3.ZERO
		_flash = 1.0
		r.set("_flash", 1.0)
		FX.play("teleport", randf_range(0.95, 1.1), 0.08)
	_queue.clear()


func animate(delta: float) -> void:
	_flash = maxf(0.0, _flash - delta * 3.0)
	_ring.rotation.y += delta * (2.0 + _flash * 12.0)
	_ring.position.y = 0.25 + sin(Time.get_ticks_msec() * 0.003) * 0.03 + _flash * 0.3
	_ring.scale = Vector3.ONE * (1.0 + _flash * 0.4)
