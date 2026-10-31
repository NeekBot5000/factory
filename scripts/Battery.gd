class_name Battery
extends Machine
## Stores power. While anything else powers its network it charges up; when that power goes, it takes over and keeps
## the network running until it's empty.

const MAX_CHARGE := 180.0

var charge := 0.0
var feeding := false              # set by the circuit: it's the one powering the network right now


func activate(p_size: float) -> void:
	super(p_size)
	add_lamp(Vector3(0, 0.82, 0.2))


func is_source() -> bool:
	return feeding and charge > 0.0


func terminal() -> Vector3:
	return Vector3(0, 0.82, 0) * size


func step(dt: float) -> void:
	if feeding:
		charge = maxf(0.0, charge - dt)
	elif powered:
		charge = minf(MAX_CHARGE, charge + dt)
	var bar := get_node_or_null("Model/Bar") as Node3D
	if bar != null:
		bar.scale.y = maxf(0.02, charge / MAX_CHARGE)


func hint_text() -> String:
	return "Battery  ·  %d%%  ·  %s" % [int(charge / MAX_CHARGE * 100.0), "powering" if is_source() else ("charging" if powered else "idle")]


func save_state() -> Dictionary:
	return {"charge": snappedf(charge, 0.1)}


func load_state(d: Dictionary) -> void:
	charge = float(d.get("charge", 0.0))
