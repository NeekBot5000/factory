class_name Lever
extends Machine
## Flip it with E. While it's on, power passes through it to the machines on its other wires.

var on := false
var _handle: Node3D


func activate(p_size: float) -> void:
	super(p_size)
	_handle = get_node("Model/Handle")
	add_lamp(Vector3(0.18, 0.21, 0.12))


func conducts() -> bool:
	return on


func terminal() -> Vector3:
	return Vector3(-0.18, 0.2, 0) * size


func hint_text() -> String:
	return "[E] switch off" if on else "[E] switch on"


func on_use(_player: Node) -> void:
	set_on(not on)
	Sfx.play("clink", 0.9 if on else 0.75, -2.0)
	Sfx.play("thud", 1.6, -8.0)


func set_on(v: bool) -> void:
	on = v
	if _handle != null:
		var tw := create_tween()
		tw.tween_property(_handle, "rotation_degrees:x", -35.0 if on else 35.0, 0.15).set_trans(Tween.TRANS_BACK)


func save_state() -> Dictionary:
	return {"on": on}


func load_state(d: Dictionary) -> void:
	set_on(bool(d.get("on", false)))
