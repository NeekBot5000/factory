class_name TrackPart
extends Machine
## Builds that go beside the track (and the drone pad):
##   rail_switch   - built next to a straight rail, its front pointing along it: while powered, that rail branches -
##                   carts coming from the switch's front side turn off to the side away from the switch
##   rail_buffer   - a barrier across the rail in front of it: carts stop there while it's off; power it to let them by
##   cart_unloader - its back to the track: while powered, it takes things out of a crate on the cart beside it, one at
##                   a time, and drops them out of its front (onto a belt)
##   drone_pad     - a landing square: while powered it charges the battery of a drone above it (and cells left on it)

const UNLOAD_EVERY := 0.4
const PAD_RATE := 0.08

var kind := "rail_switch"
var _t := 0.0
var _arm: Node3D


func activate(p_size: float) -> void:
	super(p_size)
	kind = String(get_meta("build").id) if has_meta("build") else kind
	_arm = get_node_or_null("Model/Arm")
	if kind == "rail_buffer":
		add_to_group("buffers")
	add_lamp(Vector3(0.3, 0.12, 0.3) if kind == "drone_pad" else Vector3(0.2, 0.3, 0.2))


func terminal() -> Vector3:
	return Vector3(0.3, 0.15, 0.3) if kind == "drone_pad" else Vector3(0.2, 0.4, 0.2)


func _cell_at(local: Vector3) -> Vector2i:
	return Rail.cell_of(global_transform * local)


## The switch's stem: which way along the rail its front points.
func _front_dir() -> Vector2i:
	var f := -global_basis.z
	return Vector2i(int(round(f.x)), int(round(f.z)))


## The rail a switch works: the straight rail beside it (left first, then right) that runs the way it points.
func switch_target() -> Vector2i:
	var f := _front_dir()
	var me := Rail.cell_of(global_position)
	for side: Vector2i in [Vector2i(f.y, -f.x), Vector2i(-f.y, f.x)]:
		var r := Rail.at(me + side)
		if r != null and r.curve < 0 and r.along_x == (f.x != 0):
			return me + side
	return Vector2i(999999, 999999)


## While powered: the rail leads from the switch's front side round to the side away from the switch.
func switch_links() -> Array:
	var away := switch_target() - Rail.cell_of(global_position)
	return [_front_dir(), away]


## The rail square a buffer blocks (the one in front of it).
func guards() -> Vector2i:
	return _cell_at(Vector3(0, 0, -1))


func hint_text() -> String:
	match kind:
		"rail_switch":
			var ok := switch_target().x != 999999
			return "Rail Switch  ·  %s" % (("branching" if powered else "straight on - power it to branch") if ok else "build it beside a straight rail, pointing along it")
		"rail_buffer":
			return "Rail Buffer  ·  %s" % ("open - carts go by" if powered else "down - carts stop here (power it to open)")
		"cart_unloader":
			return "Cart Unloader  ·  %s" % ("emptying the crate on the cart behind it" if powered else "power it to empty a cart's crate out of its front")
	var d := _drone()
	return "Drone Pad  ·  %s" % (("charging the drone (%d%%)" % int(d.cell.charge * 100.0)) if d != null and d.cell != null and powered else "power it to charge drones over it")


func _drone() -> Drone:
	for n in get_tree().get_nodes_in_group("drones"):
		var d := n as Drone
		var lp := to_local(d.global_position)
		if absf(lp.x) < 0.6 and absf(lp.z) < 0.6 and lp.y > -0.2 and lp.y < Drone.CRUISE + 1.0:
			return d
	return null


func _physics_process(delta: float) -> void:
	if _arm != null:
		match kind:
			"rail_buffer":
				_arm.rotation.x = lerpf(_arm.rotation.x, PI * 0.45 if powered else 0.0, 0.15)
			"rail_switch":
				_arm.rotation.x = lerpf(_arm.rotation.x, -0.6 if powered else 0.6, 0.2)
	if kind == "rail_switch":
		var c := switch_target()
		if c.x != 999999:
			Rail.switches[c] = self
	if not powered:
		return
	match kind:
		"cart_unloader":
			_t -= delta
			if _t <= 0.0:
				_t = UNLOAD_EVERY
				_unload_one()
		"drone_pad":
			var d := _drone()
			if d != null and d.cell != null and is_instance_valid(d.cell):
				d.cell.set_charge(d.cell.charge + PAD_RATE * delta)
			for b in bodies_in(Vector3(0, 0.35, 0), Vector3(0.9, 0.5, 0.9)):
				if b is Product and (b as Product).kind == "battery_cell":
					(b as Product).set_charge((b as Product).charge + PAD_RATE * delta)


func _unload_one() -> void:
	var behind := _cell_at(Vector3(0, 0, 1))
	for n in get_tree().get_nodes_in_group("carts"):
		var cart := n as Minecart
		if cart._t >= 0.0:
			continue     # not while it's rolling
		for m in cart.deck_machines():
			if m is Crate and Rail.cell_of((m as Node3D).global_position) == behind:
				var stuff := (m as Crate).contents()
				if stuff.is_empty():
					continue
				var b := stuff[0] as RigidBody3D
				b.global_position = global_transform * Vector3(0, 0.7, -0.75)
				b.linear_velocity = -global_basis.z * 1.0
				b.sleeping = false
				Sfx.play_at("thud", global_position, 1.3, -8.0)
				return
