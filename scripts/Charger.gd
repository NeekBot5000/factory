class_name Charger
extends Machine
## Drop battery cells into its cradle and power it: they charge up (their stripe fills green).

const RATE := 0.1             # of a full charge per second


func activate(p_size: float) -> void:
	super(p_size)
	add_lamp(Vector3(0.36, 0.2, 0.36))


func terminal() -> Vector3:
	return Vector3(0.36, 0.3, 0.36) * size


func hint_text() -> String:
	var n := 0
	for b in bodies_in(Vector3(0, 0.75, 0), Vector3(0.7, 0.5, 0.7)):
		if b is Product and (b as Product).kind == "battery_cell":
			n += 1
	return "Charger  ·  %s" % ("charging %d cell%s" % [n, "" if n == 1 else "s"] if n > 0 and powered else "drop battery cells in and power it")


func _physics_process(delta: float) -> void:
	if not powered:
		return
	for b in bodies_in(Vector3(0, 0.75, 0), Vector3(0.7, 0.5, 0.7)):
		if b is Product and (b as Product).kind == "battery_cell":
			(b as Product).set_charge((b as Product).charge + RATE * delta)
