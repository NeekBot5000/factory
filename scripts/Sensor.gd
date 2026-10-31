class_name Sensor
extends Machine
## A switch worked by the world instead of your hand. While it senses something it lets power through.
##   pressure_plate - something heavy (or you) standing on it
##   item_sensor    - something loose in the grid square in front of it

var kind := "pressure_plate"
var _on := false


func activate(p_size: float) -> void:
	super(p_size)
	kind = String(get_meta("build").id) if has_meta("build") else kind
	add_lamp(Vector3(0.3, 0.06, 0.3) if kind == "pressure_plate" else Vector3(0, 0.75, 0.08))


func conducts() -> bool:
	return _on


func terminal() -> Vector3:
	return (Vector3(0.36, 0.08, 0.36) if kind == "pressure_plate" else Vector3(0, 0.5, 0.1)) * size


func hint_text() -> String:
	if kind == "pressure_plate":
		return "Pressure Plate  ·  %s" % ("pressed" if _on else "lets power through while something stands on it")
	return "Item Sensor  ·  %s" % ("sees something" if _on else "lets power through while something is in front of it")


func _physics_process(_delta: float) -> void:
	var was := _on
	if kind == "pressure_plate":
		_on = not bodies_in(Vector3(0, 0.2, 0), Vector3(0.8, 0.3, 0.8), 2 | 4).is_empty()
		var plate := get_node_or_null("Model/Plate") as Node3D
		if plate != null:
			plate.position.y = lerpf(plate.position.y, 0.03 if _on else 0.06, 0.3)
	else:
		_on = not bodies_in(Vector3(0, 0.5, -0.9), Vector3(0.9, 1.0, 0.8)).is_empty()
	if _on != was:
		Sfx.play_at("click", global_position, 1.2 if _on else 0.8, -8.0)
