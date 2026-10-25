class_name Crank
extends Machine
## Wind it with E: every wind stores some seconds of power, and it powers everything wired to it until it runs down.

const PER_WIND := 10.0
const MAX_CHARGE := 60.0

var charge := 0.0
var _handle: Node3D


func activate(p_size: float) -> void:
	super(p_size)
	_handle = get_node("Model/Handle")
	add_lamp(Vector3(-0.14, 0.99, 0.0))


func is_source() -> bool:
	return charge > 0.0


func terminal() -> Vector3:
	return Vector3(0, 0.98, 0) * size


func hint_text() -> String:
	if charge > 0.0:
		return "[E] wind    %ds left" % int(ceil(charge))
	return "[E] wind"


func on_use(_player: Node) -> void:
	wind()


func wind() -> void:
	charge = minf(MAX_CHARGE, charge + PER_WIND)
	Sfx.play("click", 0.7, -2.0)
	Sfx.play("clink", 0.6, -8.0)
	# a hard spin of the handle as you wind it
	var tw := create_tween()
	tw.tween_property(_handle, "rotation:x", _handle.rotation.x - TAU, 0.35).set_trans(Tween.TRANS_QUAD)


func _physics_process(delta: float) -> void:
	if charge > 0.0:
		charge = maxf(0.0, charge - delta)
		_handle.rotation.x -= delta * 3.0


func save_state() -> Dictionary:
	return {"charge": charge}


func load_state(d: Dictionary) -> void:
	charge = float(d.get("charge", 0.0))
