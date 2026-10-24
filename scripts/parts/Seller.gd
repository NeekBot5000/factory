extends Part
## Sells anything that touches the pad. Emits a short output pulse per sale (wire it to a counter!).

var _pulse := 0.0
var _coin: MeshInstance3D
var _flash := 0.0
var sold := 0


func build() -> void:
	var tint: Color = def.tint
	_box(Vector3(0.98, 0.2, 0.98), Vector3(0, 0.1, 0), Meshes.mat(DECK_COLOR))
	_box(Vector3(0.84, 0.04, 0.84), Vector3(0, 0.215, 0), Meshes.mat(tint, 0.7, 0.4))
	_box(Vector3(0.6, 0.05, 0.6), Vector3(0, 0.22, 0), Meshes.mat(tint.darkened(0.3), 0.3, 0.4))
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			_box(Vector3(0.08, 0.55, 0.08), Vector3(0.43 * sx, 0.47, 0.43 * sz), Meshes.mat(tint.darkened(0.35)))
	_box(Vector3(0.94, 0.06, 0.06), Vector3(0, 0.76, 0.43), Meshes.mat(tint.darkened(0.2)))
	_box(Vector3(0.94, 0.06, 0.06), Vector3(0, 0.76, -0.43), Meshes.mat(tint.darkened(0.2)))
	_coin = _anim(Meshes.coin_mesh(), Meshes.metal_mat(Color("ffd23f"), 0.25), Vector3(0, 0.95, 0))
	if not ghost:
		body = _make_body()
		_add_shape(body, Vector3(1.0, 0.2, 1.0), Vector3(0, 0.1, 0))
		(body.physics_material_override as PhysicsMaterial).friction = 0.3
		_make_area(Vector3(1.04, 0.6, 1.04), Vector3(0, 0.45, 0), _on_enter)


func needs_anim() -> bool:
	return true


func info_lines() -> Array:
	return ["Sells at x%.2f (market x%.2f)" % [float(def.mult) * level_mult(), Game.sell_mult()], "Items sold: %d" % sold]


func sell_mult() -> float:
	return float(def.mult) * level_mult()


func _on_enter(b: Node3D) -> void:
	var it := b as Item
	if it != null and it.active:
		world.sell(it, self)
		_pulse = 0.25
		_flash = 1.0
		sold += 1


func update_output(delta: float) -> void:
	_pulse = maxf(0.0, _pulse - delta)
	sig_out = _pulse > 0.0


func animate(delta: float) -> void:
	_flash = maxf(0.0, _flash - delta * 4.0)
	_coin.rotation.y += delta * (2.0 + _flash * 10.0)
	_coin.position.y = 0.95 + _flash * 0.12
