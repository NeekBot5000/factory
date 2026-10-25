class_name TruckCaller
extends Machine
## A signal post by the road: whenever it gets power, it sends the log truck off to the mill with whatever is on it.


func activate(p_size: float) -> void:
	super(p_size)
	add_lamp(Vector3(0.22, 1.68, 0.12))


func terminal() -> Vector3:
	return Vector3(0, 0.3, 0.2) * size


func _power_on() -> void:
	var main := get_parent()
	var truck: Truck = main.get("ship_truck") if "ship_truck" in main else null
	if truck != null and truck.ship():
		Sfx.play("clink", 1.4, -2.0)
	else:
		Sfx.play("click", 0.5, -4.0)


func hint_text() -> String:
	return "Sends the log truck when powered"
