class_name Windmill
extends Machine
## Free power whenever there's enough wind. The wind rises and falls over a few minutes, so a windmill on its own
## stops now and then: pair it with a battery to smooth it out.

const MIN_WIND := 0.35

var _rotor: Node3D


## How windy it is right now, 0..1 (the same for every windmill).
static func wind() -> float:
	var t := Time.get_ticks_msec() * 0.001
	return clampf(0.55 + 0.3 * sin(t / 37.0) + 0.2 * sin(t / 11.0 + 1.0) + 0.08 * sin(t / 3.1), 0.0, 1.0)


func activate(p_size: float) -> void:
	super(p_size)
	_rotor = get_node_or_null("Model/Rotor")
	add_lamp(Vector3(0.3, 0.25, 0.3))


func is_source() -> bool:
	return wind() >= MIN_WIND


func terminal() -> Vector3:
	return Vector3(0.3, 0.35, 0.3) * size


func hint_text() -> String:
	return "Windmill  ·  %s  ·  wind %d%%" % ["turning" if is_source() else "too calm", int(wind() * 100.0)]


func _physics_process(delta: float) -> void:
	if _rotor != null:
		_rotor.rotation.z += delta * wind() * 4.0
