class_name Log
extends RigidBody3D
## A sawn piece of trunk. It keeps the tree's real bark layers (so axes can still strip it), can be sawn into
## shorter pieces, carried when short enough, and sold in the log truck. Origin = middle of the log, axis = +Y.

const CARRY_MAX := 3.0      # metres; longer logs are too heavy to pick up

var trunk: ForestTree
var length := 1.0
var radius := 0.4
var kind := "oak"
var _crown: Node3D
var locked := false
var _bands: Node3D


func setup_from(src: ForestTree, j0: int, j1: int, base: Transform3D) -> void:
	kind = src.kind
	radius = src.radius
	length = (j1 - j0) * ForestTree.BAND_H
	global_transform = base * Transform3D(Basis(), Vector3(0, length * 0.5, 0))
	trunk = ForestTree.new()
	add_child(trunk)
	trunk.position = Vector3(0, -length * 0.5, 0)
	trunk.setup_section(src, j0, j1)
	collision_layer = 1 | 2
	collision_mask = 1 | 2
	mass = clampf(length * radius * radius * 70.0, 2.0, 90.0)
	angular_damp = 0.6
	linear_damp = 0.1
	var pm := PhysicsMaterial.new()
	pm.friction = 0.9
	pm.bounce = 0.05
	physics_material_override = pm
	var cs := CollisionShape3D.new()
	var sh := CylinderShape3D.new()
	sh.radius = radius
	sh.height = length
	cs.shape = sh
	add_child(cs)
	add_to_group("logs")
	if length <= CARRY_MAX:
		add_to_group("grabbable")
	# heavier, longer logs thud lower
	ImpactSound.attach(self, "thud", clampf(1.3 - length * 0.15, 0.5, 1.2), 4.0, 2.0)


func attach_crown(c: Node3D) -> void:
	c.reparent(self, true)
	_crown = c
	remove_from_group("grabbable")      # too unwieldy with the whole crown on it
	c.tree_exited.connect(func():
		if is_instance_valid(self) and is_inside_tree() and length <= CARRY_MAX:
			add_to_group("grabbable"))


## Hammer: nail it in place. A locked log never moves (nothing can push, carry or suck it away) until unlocked.
func set_locked(on: bool) -> void:
	locked = on
	freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
	freeze = on
	if on:
		remove_from_group("grabbable")
		linear_velocity = Vector3.ZERO
		angular_velocity = Vector3.ZERO
		if _bands == null:
			_bands = Node3D.new()
			add_child(_bands)
			var iron := LowPoly.mat(Color("3a3d44"), 0.5)
			var nail := LowPoly.mat(Color("c9ced6"), 0.3)
			for end in [-1.0, 1.0]:
				var y: float = end * (length * 0.5 - minf(0.25, length * 0.2))
				LowPoly.mesh_instance(_bands, LowPoly.cyl(radius * 1.06, radius * 1.06, 0.07, 16), iron, Vector3(0, y, 0))
				for k in 4:
					var a := TAU * k / 4.0
					var nl := LowPoly.mesh_instance(_bands, LowPoly.cyl(0.018, 0.018, 0.02, 6), nail, Vector3(cos(a), 0, sin(a)) * radius * 1.08 + Vector3(0, y, 0))
					nl.basis = Basis(Vector3.UP.cross(Vector3(cos(a), 0, sin(a))).normalized(), PI * 0.5)
		_bands.visible = true
	else:
		if _bands != null:
			_bands.visible = false
		if length <= CARRY_MAX and not is_instance_valid(_crown):
			add_to_group("grabbable")
		sleeping = false


## Tip the freshly felled trunk over, away from the sawyer.
func topple(dir: Vector3) -> void:
	dir.y = 0.0
	dir = dir.normalized() if dir.length() > 0.01 else Vector3.FORWARD
	apply_impulse(dir * mass * 0.9, global_basis.y * length * 0.45)
	# a falling tree lands with a deep thump and a rush of leaves (once)
	contact_monitor = true
	max_contacts_reported = 4
	body_entered.connect(_landed)


func _landed(_b: Node) -> void:
	if angular_velocity.length() < 0.4 and linear_velocity.length() < 1.0:
		return      # just settling
	body_entered.disconnect(_landed)
	var at := global_position
	Sfx.play_at("crumble", at, 0.55, 6.0)
	Sfx.play_at("rustle", at + global_basis.y * length * 0.4, 0.7, 4.0)


## Saws the log in two at the band nearest `world_point`. Returns the two new logs (or [] if too close to an end).
func cut_at(world_point: Vector3) -> Array[Log]:
	var out: Array[Log] = []
	var j := int(round(trunk.to_local(world_point).y / ForestTree.BAND_H))
	if j < 1 or j > trunk.bands - 1:
		return out
	var base := trunk.global_transform
	var parts := [[0, j, base], [j, trunk.bands, base * Transform3D(Basis(), Vector3(0, j * ForestTree.BAND_H + 0.02, 0))]]
	for p in parts:
		var lg := Log.new()
		get_parent().add_child(lg)
		lg.setup_from(trunk, p[0], p[1], p[2])
		lg.linear_velocity = linear_velocity
		lg.angular_velocity = angular_velocity * 0.5
		out.append(lg)
	if is_instance_valid(_crown):
		out[1].attach_crown(_crown)      # the leafy top stays with the top piece
	if locked:
		for lg in out:
			lg.set_locked(true)
	queue_free()
	return out


## Buck saw: cuts the whole log into rounds of `section` bands (the last one takes the leftover).
func buck(section: int) -> Array[Log]:
	var out: Array[Log] = []
	var n := trunk.bands
	if n <= section:
		return out
	var base := trunk.global_transform
	var j := 0
	while j < n:
		var j1 := mini(j + section, n)
		if n - j1 < 3:
			j1 = n                     # don't leave a tiny stub
		var lg := Log.new()
		get_parent().add_child(lg)
		lg.setup_from(trunk, j, j1, base * Transform3D(Basis(), Vector3(0, j * ForestTree.BAND_H + 0.02 * out.size(), 0)))
		lg.linear_velocity = linear_velocity
		out.append(lg)
		j = j1
	if is_instance_valid(_crown):
		out[out.size() - 1].attach_crown(_crown)
	if locked:
		for lg in out:
			lg.set_locked(true)
	queue_free()
	return out


## What the mill pays: clean timber is worth a lot, but bark left on drags the price right down - a log still
## in all its bark fetches only 15% of what the same log stripped bare would.
func value() -> float:
	var clean := 60.0 * length * pow(radius / 0.4, 2.0)
	var total := 0
	var left := 0
	for l in 2:
		total += trunk.layers[l].size()
		for b in trunk.layers[l]:
			left += b
	var bark := float(left) / float(maxi(total, 1))
	return clean * (1.0 - 0.85 * bark)


## What the HUD says when you look at it: what you can do with it, and what the mill would pay for it.
func hint_text() -> String:
	var worth := "worth $%.2f" % value()
	var p: Node = get_tree().get_first_node_in_group("player")
	if p != null and String(p.get("tool")) == "hammer":
		return "%s    %s" % ["[Click] unlock" if locked else "[Click] lock in place", worth]
	if is_in_group("grabbable"):
		return "[E] grab    %s" % worth
	return worth if locked else "Too heavy to lift - cut it up    %s" % worth
