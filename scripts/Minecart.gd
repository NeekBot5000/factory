class_name Minecart
extends Machine
## A rolling platform 1-4 grid squares long that runs on rails. Drop a charged battery cell into the cradle at its
## back (E with empty hands takes it out again): while the cell has charge the cart powers every machine on its deck
## (place them with the hammer like anywhere else). It moves one square at a time while a Go (or Reverse) block on
## its deck is powered, and stops where the track ends. Anything sitting on the deck rides along.

const SPEED := 1.6            # m/s
const DRAIN_MOVE := 0.008     # of a full cell per second per deck square while rolling
const DRAIN_IDLE := 0.0005    # while it powers its deck
const DECK_Y := 0.45          # deck top, above the rail
const SETTLE := 0.12          # after a step, wait for the circuit to catch up before the next one

var length := 1
var cell: Product = null      # the battery cell in the cradle
var _from := Vector3.ZERO
var _to := Vector3.ZERO
var _t := -1.0                # 0..1 while rolling to the next square
var _forward := true
var _lift_cell := Vector2i(999999, 0)
var _settle := 0.0
var _arrive := Vector2i.ZERO
var deck: Array = []          # machines built on the deck (they ride along and share the battery)


func activate(p_size: float) -> void:
	length = clampi(int(String(get_meta("build").id).trim_prefix("minecart_")), 1, 4) if has_meta("build") else 1
	super(p_size)
	add_to_group("carts")
	add_lamp(Vector3(0.38, DECK_Y + 0.05, length - 0.6))


## Where the battery cell sits: a little cradle hanging off the back of the cart.
func cradle() -> Vector3:
	return Vector3(0, 0.42, length - 0.28)


## Its socket is the cradle: the cell stands in it, and a wire plugs in there when there's no cell.
func port_local() -> Vector3:
	return cradle() - Vector3(0, CELL_H * 0.5 - 0.055, 0)


func accepts_cell() -> bool:
	return false


func plugged() -> Product:
	return cell if cell != null and is_instance_valid(cell) else null


func is_source() -> bool:
	return cell != null and is_instance_valid(cell) and cell.charge > 0.0


func terminal() -> Vector3:
	return Vector3(0.3, DECK_Y + 0.05, length - 0.45)


func hint_text() -> String:
	var what := "no battery cell" if cell == null else "battery %d%%" % int(cell.charge * 100.0)
	var take := "    [E] take the cell out" if cell != null else "    drop a charged battery cell in the cradle at the back"
	return "Minecart (%d long)  ·  %s%s" % [length, what, take]


func on_use(_player: Node) -> void:
	if cell == null or not is_instance_valid(cell):
		cell = null
		return
	var c := cell
	cell = null
	c.reparent(get_parent(), true)
	c.freeze = false
	c.collision_layer = 2
	c.add_to_group("grabbable")
	c.linear_velocity = global_basis.z * 1.5 + Vector3.UP * 1.0
	Sfx.play("pickup", 0.9, -4.0)


## Which way is forward, on the grid.
func dir() -> Vector2i:
	var f := -global_basis.z
	return Vector2i(int(round(f.x)), int(round(f.z)))


func front_cell() -> Vector2i:
	return Rail.cell_of(global_position)


func rear_cell() -> Vector2i:
	return front_cell() - dir() * (length - 1)


func deck_machines() -> Array:
	deck = deck.filter(func(m): return is_instance_valid(m) and not (m as Node).is_queued_for_deletion() and (m as Node).is_in_group("machines"))
	return deck


## Whether a deck machine gets the cart's battery power without a wire. Go/Reverse don't (wire a switch into them,
## or the cart would never stop), nor logic blocks (their inputs and output are sides), transmitters (a signal) or
## crates (power opens a crate's door, so that's for unloading at home).
static func auto_linked(m: Node) -> bool:
	if m is Crate:
		return false
	if m is CartPart and ((m as CartPart).kind == "cart_go" or (m as CartPart).kind == "cart_back"):
		return false
	if m is Gate:
		return false
	if m is Wireless and (m as Wireless).kind == "transmitter":
		return false
	return true


## The cart on its own doesn't pass power along a wire - only its battery does (so a receiver on the deck can't run
## the deck's machines without a charged cell).
func conducts() -> bool:
	return false


func _part_on(kind: String) -> bool:
	for m in deck_machines():
		if m is CartPart and (m as CartPart).kind == kind and (m as CartPart).powered:
			return true
	return false


## Takes machines standing on the deck as part of the cart (after they're built, and after loading).
func adopt() -> void:
	for b in get_tree().get_nodes_in_group("builds"):
		var m := b as Node3D
		if m == self or m is Minecart or m is Drone or not (m is Machine) or deck.has(m):
			continue
		var lp := to_local(m.global_position)
		if absf(lp.x) < 0.5 and lp.z > -0.5 and lp.z < length - 0.5 and lp.y > DECK_Y - 0.15 and lp.y < DECK_Y + 0.3:
			deck.append(m)


static func adopt_all(tree: SceneTree) -> void:
	for c in tree.get_nodes_in_group("carts"):
		(c as Minecart).adopt()


func on_take_down() -> void:
	on_use(null)


func _deck_crate_with(kind: String) -> Crate:
	for m in deck_machines():
		if m is Crate:
			for b in (m as Crate).contents():
				if b is Product and (b as Product).kind == kind:
					return m
	return null


func _a_deck_crate() -> Crate:
	for m in deck_machines():
		if m is Crate:
			return m
	return null


func _physics_process(delta: float) -> void:
	# a battery cell dropped in the cradle snaps in
	if cell == null:
		for b in bodies_in(cradle() + Vector3(0, 0.05, 0), Vector3(0.5, 0.5, 0.36)):
			if b is Product and (b as Product).kind == "battery_cell":
				cell = b
				cell.freeze = true
				cell.remove_from_group("grabbable")
				cell.collision_layer = 0
				cell.reparent(self, true)
				cell.position = cradle()
				cell.rotation = Vector3.ZERO
				Sfx.play_at("clink", global_position, 1.3, -4.0)
				break
	if is_source():
		cell.set_charge(cell.charge - DRAIN_IDLE * delta - (DRAIN_MOVE * length * delta if _t >= 0.0 else 0.0))
	if _t >= 0.0:
		_roll(delta)
		return
	_settle -= delta
	if not is_source() or _settle > 0.0:
		return
	if _part_on("cart_go"):
		_try(true)
	elif _part_on("cart_back"):
		_try(false)


func _try(fwd: bool) -> void:
	var d := dir()
	var m := d if fwd else -d                 # which way the cart moves
	var from_c := front_cell() if fwd else rear_cell()
	var target := from_c + m
	if blocked(target, self):
		return
	var r := Rail.at(target)
	if r == null and fwd and _part_on("rail_layer"):
		var cr := _deck_crate_with("rail")
		if cr != null:
			var item: Product = null
			for b in cr.contents():
				if b is Product and (b as Product).kind == "rail":
					item = b
					break
			r = Rail.lay(get_parent(), target, d.x != 0, global_position.y)
			if r != null and not r.links().has(-m):
				r.lift().global_position = global_transform * Vector3(0, DECK_Y + 0.5, 0)
				r = null
			elif r != null:
				r.value = item.value
				item.queue_free()
				Sfx.play_at("thunk", global_position, 1.4, -4.0)
	if r == null or not r.links().has(-m):
		return
	_forward = fwd
	_arrive = target
	_lift_cell = rear_cell() if fwd else front_cell()
	_from = global_position
	_to = _from + Vector3(m.x, 0, m.y)
	_to.y = r.top() if fwd else _height_at(front_cell() + m)
	_t = 0.0


## Can't roll into a square another cart is on, or past a rail buffer that's down.
static func blocked(c: Vector2i, me: Minecart) -> bool:
	for n in me.get_tree().get_nodes_in_group("carts"):
		var o := n as Minecart
		if o == me:
			continue
		for k in o.length:
			if o.front_cell() - o.dir() * k == c:
				return true
	for n in me.get_tree().get_nodes_in_group("buffers"):
		var bf := n as TrackPart
		if not bf.powered and bf.guards() == c:
			return true
	return false


func _height_at(c: Vector2i) -> float:
	var r := Rail.at(c)
	return r.top() if r != null else global_position.y


## The rails under the whole cart, for placing one: they all need to be there, the front one running the cart's way.
static func fits(c: Vector2i, d: Vector2i, n: int) -> bool:
	for k in n:
		var r := Rail.at(c - d * k)
		if r == null or (k == 0 and not (r.links().has(d) or r.links().has(-d))):
			return false
	return true


## Round a curve: the cart swings about the square its leading end just reached, deck and riders with it.
func _turn_at(pivot: Vector2i, new_dir: Vector2i) -> void:
	var nb := Basis.looking_at(Vector3(new_dir.x, 0, new_dir.y), Vector3.UP)
	var rot := nb * global_basis.orthonormalized().inverse()
	var p := Vector3(pivot.x, global_position.y, pivot.y)
	var xf := Transform3D(Basis(), p) * Transform3D(rot, Vector3.ZERO) * Transform3D(Basis(), -p)
	var riders := bodies_in(Vector3(0, DECK_Y + 0.8, (length - 1) * 0.5), Vector3(0.98, 1.6, length + 0.1), 2)
	for mc in deck_machines():
		(mc as Node3D).global_transform = xf * (mc as Node3D).global_transform
	for b in riders:
		var rb := b as RigidBody3D
		if rb != null and rb.get_parent() != self:
			rb.global_transform = xf * rb.global_transform
	global_transform = xf * global_transform
	Sfx.play_at("clink", global_position, 0.7, -6.0)


func _roll(delta: float) -> void:
	var was := global_position
	_t = minf(1.0, _t + delta * SPEED)
	global_position = _from.lerp(_to, _t)
	var moved := global_position - was
	for m in deck_machines():
		(m as Node3D).global_position += moved
	# loose things on the deck (and in its crates), and you, ride along
	for b in bodies_in(Vector3(0, DECK_Y + 0.8, (length - 1) * 0.5), Vector3(0.98, 1.6, length + 0.1), 2 | 4):
		var pb := b as PhysicsBody3D
		if pb != null and pb.get_parent() != self:
			pb.global_position += moved
			if pb is RigidBody3D:
				(pb as RigidBody3D).sleeping = false
	if _t >= 1.0:
		_t = -1.0
		_settle = SETTLE
		# a curve (or a switched rail) turns the cart: the leading end follows the track's other way out
		var ar := Rail.at(_arrive)
		var mv := dir() if _forward else -dir()
		if ar != null and not ar.links().has(mv):
			var out: Vector2i = ar.links()[0] if ar.links()[0] != -mv else ar.links()[1]
			_turn_at(_arrive, out if _forward else -out)
		# the lifter picks up the rail the cart has just left behind
		if _forward and _part_on("rail_lifter"):
			var old := Rail.at(_lift_cell)
			if old != null:
				var item := old.lift()
				var cr := _a_deck_crate()
				item.global_position = cr.global_transform * Vector3(0, 0.6, 0) if cr != null else global_transform * Vector3(0, 0.8, length - 1)
				Sfx.play_at("clink", global_position, 0.9, -6.0)


func save_state() -> Dictionary:
	return {"cell": snappedf(cell.charge, 0.001) if cell != null else -1.0}


func load_state(d: Dictionary) -> void:
	var ch := float(d.get("cell", -1.0))
	if ch >= 0.0:
		var p := Product.new()
		get_parent().add_child(p)
		p.setup("battery_cell", 6.0, Color.WHITE)
		p.set_charge(ch)
		p.global_transform = global_transform * Transform3D(Basis(), cradle())
		cell = p
		cell.freeze = true
		cell.remove_from_group("grabbable")
		cell.collision_layer = 0
		cell.reparent(self, true)
