class_name Machine
extends StaticBody3D
## Base for everything that runs on wires. Power spreads from active sources (a wound crank, later generators)
## along wires to every connected machine; switches (lever, button, sensors...) only pass it on while they're on.
## Each machine reads `powered` and does its thing.

var uid := 0
var size := 1.0
var powered := false
var _was_powered := false

static var _next_uid := 1


## A new id for a machine (wires remember their ends by these in the save file).
static func take_uid() -> int:
	_next_uid += 1
	return _next_uid - 1


## Gives a machine a saved id, and makes sure new ones never collide with it.
func set_uid(v: int) -> void:
	uid = v
	_next_uid = maxi(_next_uid, v + 1)


## The machine a collider belongs to (the machine itself, or a moving part of it like a piston plate).
static func of(c: Object) -> Machine:
	var n := c as Node
	while n != null:
		if n is Machine:
			return n as Machine
		n = n.get_parent()
	return null


## Called once the build is finished. `model` is the Builds model node (parts hang off it).
func activate(p_size: float) -> void:
	size = p_size
	add_to_group("machines")


## Gives power to its wires right now (a crank being wound, a running generator...).
func is_source() -> bool:
	return false


## Lets power pass through it to the other machines wired to it.
func conducts() -> bool:
	return true


## Where wires attach (local).
func terminal() -> Vector3:
	return Vector3(0, 0.4, 0) * size


func terminal_world() -> Vector3:
	return global_transform * terminal()


## Called by the circuit every tick.
func set_powered(on: bool) -> void:
	powered = on
	if on and not _was_powered:
		_power_on()
	elif not on and _was_powered:
		_power_off()
	_was_powered = on


func _power_on() -> void:
	pass


func _power_off() -> void:
	pass


## Extra state for the save file (lever position, what's stuck to a rotator...).
func save_state() -> Dictionary:
	return {}


func load_state(_d: Dictionary) -> void:
	pass


## A small indicator light that glows while powered (machines call this to add one).
func add_lamp(pos: Vector3) -> MeshInstance3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color("3a3d44")
	m.emission_enabled = true
	m.emission = Color("ffcf6a")
	m.emission_energy_multiplier = 0.0
	var mi := LowPoly.mesh_instance(self, LowPoly.box(Vector3(0.06, 0.06, 0.06) * size), m, pos * size)
	mi.name = "Lamp"
	return mi


func _update_lamp() -> void:
	var lamp := get_node_or_null("Lamp") as MeshInstance3D
	if lamp != null:
		var m := lamp.material_override as StandardMaterial3D
		m.emission_energy_multiplier = 2.5 if powered else 0.0
		m.albedo_color = Color("ffcf6a") if powered else Color("3a3d44")
