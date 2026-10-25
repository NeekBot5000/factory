class_name PushButton
extends Machine
## Press it with E: lets power through for a moment, then pops back out.

const HOLD := 1.5

var _t := 0.0
var _cap: Node3D


func activate(p_size: float) -> void:
	super(p_size)
	_cap = get_node("Model/Cap")
	add_lamp(Vector3(0, 1.03, 0.0))


func conducts() -> bool:
	return _t > 0.0


func terminal() -> Vector3:
	return Vector3(0, 0.6, -0.08) * size


func hint_text() -> String:
	return "[E] press"


func on_use(_player: Node) -> void:
	press()


func press() -> void:
	_t = HOLD
	_cap.position.z = 0.12
	Sfx.play("click", 0.6, 0.0)


func _physics_process(delta: float) -> void:
	if _t > 0.0:
		_t -= delta
		if _t <= 0.0:
			_cap.position.z = 0.15
			Sfx.play("click", 0.9, -6.0)
