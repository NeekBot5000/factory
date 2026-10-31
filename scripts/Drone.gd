class_name Drone
extends Machine
## A flying platform in three sizes. It runs on a battery cell (drop one into the cradle on its back; E with empty
## hands takes it out) and, while it has charge, hovers at a fixed height over whatever is below it.
## It has no wires: five dials on it are wireless receivers. While the channel on its front dial is on (a powered
## transmitter on that channel anywhere), it flies forward; the same for its right, back and left dials - two at once
## flies diagonally. The dial on top works its pad: on, it goes down and picks up the thing under it; off, it lets go.
## It carries one thing, and only as heavy as its size can lift: too heavy and it can't get off the ground.

const SIZES := {
	"drone_small": {"name": "Small Drone", "w": 0.6, "lift": 3.5, "drain": 0.002},
	"drone_medium": {"name": "Medium Drone", "w": 0.85, "lift": 9.0, "drain": 0.003},
	"drone_large": {"name": "Large Drone", "w": 1.15, "lift": 40.0, "drain": 0.0045},
}
const DIALS := ["front", "right", "back", "left", "pad"]
const DIR := [Vector3(0, 0, -1), Vector3(1, 0, 0), Vector3(0, 0, 1), Vector3(-1, 0, 0)]
const CRUISE := 3.0           # metres above whatever is under it
const SPEED := 3.0
const CLIMB := 1.6
const MOVE_DRAIN := 1.6       # draining this much faster while it flies along

var kind := "drone_small"
var dial: Array = [0, 1, 2, 3, 4]   # wireless channel per dial (-1 = off)
var cell: Product = null
var carried: RigidBody3D = null
var _carry_off := Vector3.ZERO
var _rotors: Array = []
var _spin := 0.0
var _ground := 0.0            # height of what's under it
var _fx := 0.0


func activate(p_size: float) -> void:
	kind = String(get_meta("build").id) if has_meta("build") else kind
	super(p_size)
	add_to_group("drones")
	var model := get_node_or_null("Model")
	if model != null:
		for k in 4:
			var r := model.get_node_or_null("Rotor%d" % k)
			if r != null:
				_rotors.append(r)
	_paint()


func w() -> float:
	return float(SIZES[kind].w)


func lift() -> float:
	return float(SIZES[kind].lift)


func cradle() -> Vector3:
	return Vector3(0, 0.42, w() * 0.5 - 0.12)


## Where each dial sits on the body (front, right, back, left, and the pad dial on top).
func dial_pos(i: int) -> Vector3:
	var h := w() * 0.5
	match i:
		0: return Vector3(0, 0.18, -h - 0.02)
		1: return Vector3(h + 0.02, 0.18, 0)
		2: return Vector3(-0.15, 0.18, h + 0.02)
		3: return Vector3(-h - 0.02, 0.18, 0)
	return Vector3(-0.12, 0.3, -0.05)


func conducts() -> bool:
	return false


func charged() -> bool:
	return cell != null and is_instance_valid(cell) and cell.charge > 0.0


func channel_on(i: int) -> bool:
	return int(dial[i]) >= 0 and Wireless.channel_on(get_tree(), int(dial[i]))


func too_heavy() -> bool:
	return carried != null and is_instance_valid(carried) and carried.mass > lift()


func hint_text() -> String:
	var p := get_tree().get_first_node_in_group("player")
	var parts: Array[String] = [String(SIZES[kind].name)]
	parts.append("no battery cell" if cell == null else "battery %d%%" % int(cell.charge * 100.0))
	parts.append("lifts up to %.1f kg" % lift())
	if too_heavy():
		parts.append("too heavy to lift!")
	var i := _aimed_dial(p)
	var text := "  ·  ".join(parts)
	if i >= 0:
		text += "\n%s dial: %s    [E] change" % [String(DIALS[i]).capitalize(), _ch_name(int(dial[i]))]
	elif cell != null and p != null and String(p.get("tool")) == "hands":
		text += "    [E] take the cell out"
	return text


func _ch_name(c: int) -> String:
	return "off" if c < 0 else String(Wireless.NAMES[c]) + " channel"


## The dial you're looking at (nearest to where your aim hits the drone), or -1.
func _aimed_dial(p: Node) -> int:
	if p == null or not p.has_method("look_ray"):
		return -1
	var hit: Dictionary = p.call("look_ray", 4.0, 1)
	if hit.is_empty() or Machine.of(hit.collider) != self:
		return -1
	var lp := to_local(hit.position)
	var best := -1
	var bd := 0.3
	for i in DIALS.size():
		var d := lp.distance_to(dial_pos(i))
		if d < bd:
			bd = d
			best = i
	return best


func on_use(player: Node) -> void:
	var i := _aimed_dial(player)
	if i >= 0:
		dial[i] = int(dial[i]) + 1
		if int(dial[i]) >= Wireless.CHANNELS.size():
			dial[i] = -1
		_paint()
		Sfx.play("click", 0.9 + (int(dial[i]) + 1) * 0.06, -4.0)
		return
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


func _paint() -> void:
	for i in DIALS.size():
		var g := get_node_or_null("Model/Dial%d" % i) as MeshInstance3D
		if g == null:
			continue
		var c: Color = Color("2b2d33") if int(dial[i]) < 0 else Wireless.CHANNELS[int(dial[i])]
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		if int(dial[i]) >= 0:
			m.emission_enabled = true
			m.emission = c
			m.emission_energy_multiplier = 0.8
		g.material_override = m


## What's under it: the ground, a roof, a belt... (not the thing it carries or loose items).
func _floor_below() -> float:
	var from := global_position + Vector3.UP * 0.05
	var q := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 30.0, 1)
	q.exclude = [get_rid()]
	for k in 4:
		var hit := get_world_3d().direct_space_state.intersect_ray(q)
		if hit.is_empty():
			break
		if Machine.of(hit.collider) is Drone:
			q.exclude = q.exclude + [hit.rid]
			continue
		return (hit.position as Vector3).y
	var t = get_parent().get("terrain")
	return (t as Terrain).height_at(global_position.x, global_position.z) if t is Terrain else global_position.y - CRUISE


## The loose thing right under the pad, if any.
func _under_pad() -> RigidBody3D:
	var bottom := global_position.y - _ground
	for b in bodies_in(Vector3(0, -bottom * 0.5, 0), Vector3(w() * 0.9, bottom + 0.1, w() * 0.9)):
		var rb := b as RigidBody3D
		if rb != null and rb != cell and rb.is_in_group("grabbable") and not rb.freeze:
			return rb
	return null


func _physics_process(delta: float) -> void:
	# a battery cell dropped in the cradle snaps in
	if cell == null:
		for b in bodies_in(cradle(), Vector3(0.4, 0.45, 0.36)):
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
	_ground = _floor_below()
	var up := charged()
	var pad := up and channel_on(4)
	var target := _ground
	var move := Vector3.ZERO
	if up:
		target = _ground + CRUISE
		for i in 4:
			if channel_on(i):
				move += DIR[i]
		if pad and carried == null:
			target = _ground + 0.35        # go down for it
		if too_heavy():
			target = _ground + 0.05 + absf(sin(Time.get_ticks_msec() * 0.006)) * 0.15    # straining, bobbing
			move = Vector3.ZERO
	# let go when the pad switches off (or the battery dies)
	if carried != null and (not pad or not is_instance_valid(carried)):
		_release()
	# pick up
	if pad and carried == null and global_position.y - _ground < 0.9:
		var rb := _under_pad()
		if rb != null:
			_grab(rb)
	var y := global_position.y
	var dy := clampf(target - y, -CLIMB * delta, CLIMB * delta)
	var step := Vector3.ZERO
	if move != Vector3.ZERO and y - _ground > CRUISE * 0.6:
		step = global_basis * move.normalized() * SPEED * delta
	var was := global_position
	global_position += step + Vector3(0, dy, 0)
	# never through the ground
	global_position.y = maxf(global_position.y, _floor_below() if step != Vector3.ZERO else _ground)
	if carried != null:
		carried.global_position = global_transform * _carry_off
		carried.global_rotation = global_rotation
	if up:
		var flying := global_position.y - _ground > 0.1
		var rate := float(SIZES[kind].drain) * (MOVE_DRAIN if step != Vector3.ZERO else 1.0)
		if flying or pad:
			cell.set_charge(cell.charge - rate * delta)
		_spin = minf(1.0, _spin + delta * 2.0)
	else:
		_spin = maxf(0.0, _spin - delta * 0.7)
	for r in _rotors:
		(r as Node3D).rotation.y += _spin * 40.0 * delta
	if _spin > 0.5 and was.distance_to(global_position) > 0.0:
		_fx -= delta
		if _fx <= 0.0:
			_fx = 1.2
			Sfx.play_at("whoosh", global_position, 1.8 + w() * -0.5, -14.0)


func _grab(rb: RigidBody3D) -> void:
	carried = rb
	rb.freeze = true
	rb.set_meta("carried", rb.collision_layer)
	rb.collision_layer = 0
	rb.remove_from_group("grabbable")
	var h := 0.15
	for c in rb.get_children():
		if c is CollisionShape3D and (c as CollisionShape3D).shape is BoxShape3D:
			h = maxf(h, ((c as CollisionShape3D).shape as BoxShape3D).size.y * 0.5)
	_carry_off = Vector3(0, -0.05 - h, 0)
	Sfx.play_at("clink", global_position, 1.1, -6.0)


func _release() -> void:
	if carried != null and is_instance_valid(carried):
		carried.freeze = false
		carried.collision_layer = int(carried.get_meta("carried", 2))
		carried.remove_meta("carried")
		carried.add_to_group("grabbable")
		carried.linear_velocity = Vector3.ZERO
		carried.sleeping = false
	carried = null


func on_take_down() -> void:
	_release()
	if cell != null:
		on_use(null)


func save_state() -> Dictionary:
	return {"dial": dial.duplicate(), "cell": snappedf(cell.charge, 0.001) if cell != null else -1.0}


func load_state(d: Dictionary) -> void:
	var dl: Array = d.get("dial", [])
	if dl.size() == DIALS.size():
		for i in DIALS.size():
			dial[i] = clampi(int(dl[i]), -1, Wireless.CHANNELS.size() - 1)
	_paint()
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
