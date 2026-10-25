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


func attach_crown(c: Node3D) -> void:
	c.reparent(self, true)
	_crown = c
	remove_from_group("grabbable")      # too unwieldy with the whole crown on it
	c.tree_exited.connect(func():
		if is_instance_valid(self) and is_inside_tree() and length <= CARRY_MAX:
			add_to_group("grabbable"))


## Tip the freshly felled trunk over, away from the sawyer.
func topple(dir: Vector3) -> void:
	dir.y = 0.0
	dir = dir.normalized() if dir.length() > 0.01 else Vector3.FORWARD
	apply_impulse(dir * mass * 0.9, global_basis.y * length * 0.45)


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
	queue_free()
	return out


## What the mill pays: timber by volume, plus a quarter of the price for any bark still on it (strip it first!).
func value() -> float:
	var v := 25.0 * length * pow(radius / 0.4, 2.0)
	for l in 2:
		var per: float = Chip.PANEL_VALUE.outer if l == 0 else Chip.PANEL_VALUE.inner
		if kind == "birch" and l == 0:
			per *= 1.6
		var n := 0
		for b in trunk.layers[l]:
			n += b
		v += n * per * 0.25
	return v


func hint_text() -> String:
	return "[E] grab" if is_in_group("grabbable") else ""
