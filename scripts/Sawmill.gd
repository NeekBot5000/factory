class_name Sawmill
extends Machine
## Lay a log on its table and power it: the blade turns the log into planks, which drop out of the chute at the
## front. Planks are worth half as much again as the log - more if the bark was stripped off first.

const PLANK_LEN := 0.55

var _work := 0.0
var _log: Log = null
var _blade: Node3D
var _fx := 0.0


func activate(p_size: float) -> void:
	super(p_size)
	_blade = get_node_or_null("Model/Blade")
	add_lamp(Vector3(0.42, 0.3, 0.42))


func terminal() -> Vector3:
	return Vector3(0.42, 0.45, 0.42) * size


func hint_text() -> String:
	return "Sawmill  ·  %s" % ("cutting" if _log != null else "lay a log on the table and power it")


func _physics_process(delta: float) -> void:
	if _blade != null and powered:
		_blade.rotation.x += delta * 20.0
	if not powered:
		_work = 0.0
		_log = null
		return
	var found: Log = null
	for b in bodies_in(Vector3(0, 0.85, 0), Vector3(1.1, 0.7, 1.1)):
		if b is Log:
			found = b
			break
	if found != _log:
		_log = found
		_work = 0.0
	if _log == null:
		return
	_work += delta
	_fx -= delta
	if _fx <= 0.0:
		_fx = 0.08
		Nature.burst(get_parent(), global_transform * Vector3(0, 0.75, 0), Vector3.UP, _log.trunk.wood_color.lightened(0.1), 6, 1.6, 0.018, 6.0, 0.5, 70.0)
		Sfx.play_at("saw", global_position, 1.5, -6.0)
	if _work >= 0.8 + _log.length * 0.4:
		_cut(_log)
		_log = null
		_work = 0.0


func _cut(lg: Log) -> void:
	var n := clampi(int(round(lg.length / PLANK_LEN)), 1, 14)
	var each := lg.value() * 1.5 / n
	var col := lg.trunk.wood_color
	var world := get_parent()
	for k in n:
		var p := Product.new()
		world.add_child(p)
		p.setup("plank", snappedf(each, 0.01), col)
		p.global_transform = global_transform * Transform3D(Basis(), Vector3(randf_range(-0.15, 0.15), 0.6 + k * 0.06, -0.75))
		p.linear_velocity = -global_basis.z * 1.5 + Vector3.UP * 0.5
	Sfx.play_at("thud", global_position, 1.2, 0.0)
	lg.queue_free()
