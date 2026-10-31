class_name Sensor
extends Machine
## A switch worked by the world instead of your hand. While it senses something it lets power through.
##   pressure_plate - something heavy (or you) standing on it
##   item_sensor    - something loose in the grid square in front of it
##   level_sensor   - the storage crate in front of it holds at least N things (E changes N)
##   cart_sensor    - a minecart is on the rail in front of it (a station)

const LEVELS := [5, 10, 20, 30]

var kind := "pressure_plate"
var _on := false
var level := 1


func activate(p_size: float) -> void:
	super(p_size)
	kind = String(get_meta("build").id) if has_meta("build") else kind
	add_lamp(Vector3(0.3, 0.06, 0.3) if kind == "pressure_plate" else Vector3(0, 0.75, 0.08))
	_paint_level()


func conducts() -> bool:
	return _on


func terminal() -> Vector3:
	return (Vector3(0.36, 0.08, 0.36) if kind == "pressure_plate" else Vector3(0, 0.5, 0.1)) * size


func hint_text() -> String:
	if kind == "pressure_plate":
		return "Pressure Plate  ·  %s" % ("pressed" if _on else "lets power through while something stands on it")
	match kind:
		"level_sensor":
			var c := _crate()
			var n := c.contents().size() if c != null else 0
			return "Level Sensor  ·  %s  ·  lets power through at %d or more    [E] change" % [("%d in the crate" % n) if c != null else "no crate in front", LEVELS[level]]
		"cart_sensor":
			return "Cart Sensor  ·  %s" % ("a cart is here" if _on else "lets power through while a cart is on the rail in front")
	return "Item Sensor  ·  %s" % ("sees something" if _on else "lets power through while something is in front of it")


func on_use(_player: Node) -> void:
	if kind != "level_sensor":
		return
	level = (level + 1) % LEVELS.size()
	_paint_level()
	Sfx.play("click", 0.9 + level * 0.1, -4.0)


## The level sensor's dial: a needle that points further round the higher it's set.
func _paint_level() -> void:
	var n := get_node_or_null("Model/Needle") as Node3D
	if n != null:
		n.rotation.z = deg_to_rad(60.0 - level * 40.0)


func _crate() -> Crate:
	var q := PhysicsRayQueryParameters3D.create(global_transform * Vector3(0, 0.4, -0.1), global_transform * Vector3(0, 0.4, -1.1), 1)
	q.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	return Machine.of(hit.collider) as Crate if not hit.is_empty() else null


func _cart_in_front() -> bool:
	var c := Rail.cell_of(global_transform * Vector3(0, 0, -1))
	for m in get_tree().get_nodes_in_group("carts"):
		var cart := m as Minecart
		var d := cart.dir()
		for k in cart.length:
			if cart.front_cell() - d * k == c:
				return true
	return false


func _physics_process(_delta: float) -> void:
	var was := _on
	if kind == "pressure_plate":
		_on = not bodies_in(Vector3(0, 0.2, 0), Vector3(0.8, 0.3, 0.8), 2 | 4).is_empty()
		var plate := get_node_or_null("Model/Plate") as Node3D
		if plate != null:
			plate.position.y = lerpf(plate.position.y, 0.03 if _on else 0.06, 0.3)
	elif kind == "level_sensor":
		var c := _crate()
		_on = c != null and c.contents().size() >= int(LEVELS[level])
	elif kind == "cart_sensor":
		_on = _cart_in_front()
	else:
		_on = not bodies_in(Vector3(0, 0.5, -0.9), Vector3(0.9, 1.0, 0.8)).is_empty()
	if _on != was:
		Sfx.play_at("click", global_position, 1.2 if _on else 0.8, -8.0)


func save_state() -> Dictionary:
	return {"level": level} if kind == "level_sensor" else {}


func load_state(d: Dictionary) -> void:
	level = clampi(int(d.get("level", 1)), 0, LEVELS.size() - 1)
	_paint_level()
