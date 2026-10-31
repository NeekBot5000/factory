class_name Machine
extends StaticBody3D
## Base for everything that runs on wires. Power spreads from active sources (a wound crank, later generators)
## along wires to every connected machine; switches (lever, button, sensors...) only pass it on while they're on.
## Each machine reads `powered` and does its thing.

var uid := 0
var size := 1.0
var powered := false
var _was_powered := false

var _lamp_shown := -1

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


## Where a wire's plug goes: into the socket, or on top of the cell in it.
func terminal_world() -> Vector3:
	var c := plugged()
	if c != null:
		return c.global_transform * Vector3(0, CELL_H * 0.5, 0)
	return global_transform * port_local()


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


## What the HUD shows when you look at it: its name and whether it has power.
func hint_text() -> String:
	return "%s  ·  %s" % [display_name(), "powered" if powered else "no power"]


func display_name() -> String:
	return String(Builds.BUILDS[get_meta("build").id].name) if has_meta("build") else "Machine"


## Extra state for the save file (lever position, what's stuck to a rotator...).
func save_state() -> Dictionary:
	return {}


func load_state(_d: Dictionary) -> void:
	pass


## Loose things (and, with mask 4, the player) inside a box given in this machine's own space: hoppers, sensors.
## Whatever the player is holding doesn't count until they let go of it.
func bodies_in(center: Vector3, box: Vector3, mask := 2) -> Array:
	var q := PhysicsShapeQueryParameters3D.new()
	var sh := BoxShape3D.new()
	sh.size = box * size
	q.shape = sh
	q.transform = global_transform * Transform3D(Basis(), center * size)
	q.collision_mask = mask
	q.exclude = [get_rid()]
	var held: Node = null
	var p := get_tree().get_first_node_in_group("player")
	if p != null:
		held = p.get("held")
	var out: Array = []
	for r in get_world_3d().direct_space_state.intersect_shape(q, 32):
		var c: Object = r.collider
		if out.has(c) or c == held:
			continue
		if c is RigidBody3D and not (c as RigidBody3D).freeze:
			out.append(c)
		elif c is CharacterBody3D:
			out.append(c)
	return out


## Called when the hammer takes this machine down (give back anything inside it).
func on_take_down() -> void:
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
	# only touch the material when the light actually changes (material writes aren't free, and this runs 20x a second)
	if _lamp_shown == int(powered):
		return
	_lamp_shown = int(powered)
	var lamp := get_node_or_null("Lamp") as MeshInstance3D
	if lamp != null:
		var m := lamp.material_override as StandardMaterial3D
		m.emission_energy_multiplier = 2.5 if powered else 0.0
		m.albedo_color = Color("ffcf6a") if powered else Color("3a3d44")


# ------------------------------------------------------------------ the power port
# Every machine has one socket, where its wire plugs in. A battery cell fits the same socket: drop one on it and it
# clicks in, standing up. A plugged-in cell powers the machine (and everything wired to it) when there's no other
# power about, and charges from the network when there is.

const PORT_DRAIN := 0.002      # of a full cell per second while it's powering things
const PORT_CHARGE := 0.03      # while the network around it has other power
const SOCKET := 0.2            # inside width: a battery cell (and a wire's plug) fits it exactly
const CELL_H := 0.32

var port_cell: Product = null
var port_feeding := false
var _port := Vector3.INF


## Where the socket's mouth is, in the machine's own space. It sits on top of whatever is under the wire point.
func port_local() -> Vector3:
	if _port == Vector3.INF:
		var p := terminal()
		var top := 0.0
		for c in get_children():
			var cs := c as CollisionShape3D
			if cs == null or not (cs.shape is BoxShape3D) or cs.name.begins_with("Door"):
				continue
			var s := (cs.shape as BoxShape3D).size
			var o := cs.position
			if absf(p.x - o.x) <= s.x * 0.5 + 0.02 and absf(p.z - o.z) <= s.z * 0.5 + 0.02:
				top = maxf(top, o.y + s.y * 0.5)
		_port = Vector3(p.x, top + 0.07, p.z)
	return _port


## Can a battery cell go in the socket? (Carts and drones have their own cradle, logic blocks only take wires.)
func accepts_cell() -> bool:
	return true


## The cell sitting in the socket, if any.
func plugged() -> Product:
	return port_cell if port_cell != null and is_instance_valid(port_cell) else null


func gives_power() -> bool:
	return is_source() or port_feeding


## Builds the socket: a dark collar with copper contacts, just big enough for a cell or a plug.
func make_port() -> void:
	if get_node_or_null("Port") != null:
		return
	var n := Node3D.new()
	n.name = "Port"
	add_child(n)
	n.position = port_local()
	Machine.socket_mesh(n)


static func socket_mesh(n: Node3D) -> void:
	var dark := LowPoly.mat(Color("23252b"), 0.6)
	var rim := LowPoly.mat(Color("4a4e57"), 0.4)
	var copper := LowPoly.mat(Color("d8893f"), 0.3)
	var w := SOCKET + 0.06
	for sgn: float in [-1.0, 1.0]:
		LowPoly.mesh_instance(n, LowPoly.box(Vector3(w, 0.07, 0.03)), rim, Vector3(0, -0.035, sgn * (SOCKET * 0.5 + 0.015)))
		LowPoly.mesh_instance(n, LowPoly.box(Vector3(0.03, 0.07, SOCKET)), rim, Vector3(sgn * (SOCKET * 0.5 + 0.015), -0.035, 0))
	LowPoly.mesh_instance(n, LowPoly.box(Vector3(SOCKET, 0.012, SOCKET)), dark, Vector3(0, -0.064, 0))
	for sx: float in [-0.05, 0.05]:
		LowPoly.mesh_instance(n, LowPoly.box(Vector3(0.025, 0.03, 0.025)), copper, Vector3(sx, -0.045, 0))
	# little notch so you can see which way round it goes
	LowPoly.mesh_instance(n, LowPoly.box(Vector3(0.06, 0.012, 0.012)), copper, Vector3(0, 0.002, -(SOCKET * 0.5 + 0.015)))


## The cell clicks into the socket.
func plug(c: Product) -> void:
	port_cell = c
	c.freeze = true
	c.linear_velocity = Vector3.ZERO
	c.angular_velocity = Vector3.ZERO
	c.reparent(self, true)
	c.position = port_local() + Vector3(0, CELL_H * 0.5 - 0.055, 0)
	c.rotation = Vector3.ZERO
	c.set_meta("in_port", self)
	Sfx.play_at("clink", global_position, 1.5, -2.0)


## Takes the cell back out (when you grab it, or the machine comes down). Returns it.
func unplug() -> Product:
	var c := plugged()
	port_cell = null
	port_feeding = false
	if c == null:
		return null
	c.remove_meta("in_port")
	c.reparent(get_parent(), true)
	c.freeze = false
	c.sleeping = false
	return c
