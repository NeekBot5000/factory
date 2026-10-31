class_name Rail
extends StaticBody3D
## A laid piece of track: one 1 m grid square, straight (along X or along Z) or a curve joining two neighbouring
## sides. Minecarts roll along rails. With the hammer: click a loose rail to lay it, click a laid rail to pick it up
## again, R to turn it. A rail switch built beside a straight rail turns it into a branch while powered.

const DIRS := [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]

static var _map := {}       # Vector2i cell -> Rail
static var switches := {}   # Vector2i cell -> the TrackPart (rail switch) working the rail there

var cell := Vector2i.ZERO
var along_x := false
var curve := -1              # -1 straight; 0..3 a curve joining DIRS[curve] and DIRS[curve + 1]
var value := Product.RAIL_VALUE   # what the rail item was worth (it is again when picked up)


## The two directions (out of this square) the track here leads.
func links() -> Array:
	if curve >= 0:
		return [DIRS[curve], DIRS[(curve + 1) % 4]]
	var sw: TrackPart = switches.get(cell)
	if sw != null and is_instance_valid(sw) and sw.powered and sw.switch_target() == cell:
		return sw.switch_links()
	return [Vector2i(1, 0), Vector2i(-1, 0)] if along_x else [Vector2i(0, 1), Vector2i(0, -1)]


func item_kind() -> String:
	return "curved_rail" if curve >= 0 else "rail"


## Lays a curve. It joins up with the rails next to it if two of them meet here at a right angle (or one does, turning
## the way you're facing); otherwise it comes in from behind you and turns right. R turns it afterwards.
static func lay_curve(world: Node, c: Vector2i, facing: Vector2i, near_y := NAN) -> Rail:
	if at(c) != null:
		return null
	var open: Array[int] = []
	for i in 4:
		var n := at(c + DIRS[i])
		if n != null and n.links().has(-DIRS[i]):
			open.append(i)
	var fi := maxi(0, DIRS.find(facing))
	var k := (fi + 1) % 4         # nothing to join: in from behind you, out to your right
	if open.size() >= 2:
		for a in open:
			if open.has((a + 1) % 4):
				k = a
				break
	elif open.size() == 1:
		var a := open[0]
		k = (a + 3) % 4 if (a + 3) % 4 == fi else a     # the free end turns the way you face, if it can
	var r := Rail.new()
	world.add_child(r)
	r.curve = k
	r.setup(c, false, _ground(world, c, near_y))
	return r


## R with the hammer: a straight rail swaps between along X and along Z; a curve turns a quarter.
func turn() -> void:
	if curve >= 0:
		curve = (curve + 1) % 4
	else:
		along_x = not along_x
	for ch in get_children():
		ch.queue_free()
	setup(cell, along_x, global_position.y)


static func cell_of(p: Vector3) -> Vector2i:
	return Vector2i(int(round(p.x)), int(round(p.z)))


static func at(c: Vector2i) -> Rail:
	var r: Rail = _map.get(c)
	return r if r != null and is_instance_valid(r) and not r.is_queued_for_deletion() else null


## Lays a rail on a grid square (lined up with a neighbouring rail if there is one). Returns it, or null if taken.
## `near_y` is roughly how high (where the item lay, or the cart's track): the rail goes on whatever is under that.
static func lay(world: Node, c: Vector2i, x_dir: bool, near_y := NAN) -> Rail:
	if at(c) != null:
		return null
	var y := _ground(world, c, near_y)
	# line up with track that leads into this square
	for d: Vector2i in DIRS:
		var n := at(c + d)
		if n != null and n.links().has(-d):
			x_dir = d.x != 0
	var r := Rail.new()
	world.add_child(r)
	r.setup(c, x_dir, y)
	return r


## The ground (or platform, or pillar top) under a grid square, near a height; the terrain if nothing's there.
static func _ground(world: Node, c: Vector2i, near_y: float) -> float:
	var t: Terrain = world.get("terrain")
	var fallback := t.height_at(c.x, c.y) if t != null else 0.0
	if is_nan(near_y):
		near_y = fallback
	var w := world as Node3D
	var from := Vector3(c.x, near_y + 1.0, c.y)
	var q := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 4.0, 1)
	for k in 6:
		var hit := w.get_world_3d().direct_space_state.intersect_ray(q)
		if hit.is_empty():
			return fallback
		if Machine.of(hit.collider) != null or hit.collider is Rail or hit.collider is ForestTree or hit.collider is RigidBody3D:
			q.exclude = q.exclude + [hit.rid]
			continue
		return (hit.position as Vector3).y
	return fallback


func setup(c: Vector2i, x_dir: bool, y: float) -> void:
	cell = c
	along_x = x_dir
	collision_layer = 1
	collision_mask = 0
	var iron := Tools.steel(Color("8d949e"), 0.4)
	var wood := LowPoly.mat(Color("6b4a32"), 0.95)
	if curve >= 0:
		# built joining north and east, then turned (clockwise seen from above) to join DIRS[curve] and DIRS[curve+1]
		global_transform = Transform3D(Basis(Vector3.UP, -curve * PI * 0.5), Vector3(c.x, y, c.y))
		var corner := Vector3(0.5, 0, -0.5)
		for k in 3:
			var a := (k + 0.5) / 3.0 * PI * 0.5
			var sl := LowPoly.mesh_instance(self, LowPoly.box(Vector3(0.8, 0.06, 0.14)), wood, corner + Vector3(-cos(a), 0, sin(a)) * 0.5 + Vector3(0, 0.03, 0))
			sl.rotation.y = -a + PI * 0.5
		for rr: float in [0.25, 0.75]:
			var segs := 5
			for k in segs:
				var a0 := float(k) / segs * PI * 0.5
				var a1 := float(k + 1) / segs * PI * 0.5
				var p0 := corner + Vector3(-cos(a0), 0, sin(a0)) * rr
				var p1 := corner + Vector3(-cos(a1), 0, sin(a1)) * rr
				var seg := LowPoly.mesh_instance(self, LowPoly.box(Vector3(0.06, 0.07, p0.distance_to(p1) + 0.02)), iron, (p0 + p1) * 0.5 + Vector3(0, 0.09, 0))
				seg.rotation.y = atan2(p1.x - p0.x, p1.z - p0.z)
	else:
		global_transform = Transform3D(Basis(Vector3.UP, PI * 0.5 if along_x else 0.0), Vector3(c.x, y, c.y))
		for k in 3:
			LowPoly.mesh_instance(self, LowPoly.box(Vector3(0.8, 0.06, 0.14)), wood, Vector3(0, 0.03, -0.33 + k * 0.33))
		for sx: float in [-0.25, 0.25]:
			LowPoly.mesh_instance(self, LowPoly.box(Vector3(0.06, 0.07, 1.0)), iron, Vector3(sx, 0.09, 0))
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(0.9, 0.12, 0.9) if curve >= 0 else Vector3(0.8, 0.12, 1.0)
	cs.shape = sh
	cs.position.y = 0.06
	add_child(cs)
	add_to_group("rails")
	_map[cell] = self


## Picks the rail up: it turns back into a loose rail item. Returns the item.
func lift() -> Product:
	_map.erase(cell)
	remove_from_group("rails")
	var p := Product.new()
	get_parent().add_child(p)
	p.setup(item_kind(), 0.0, Color("8d949e"))
	p.value = value
	p.global_position = global_position + Vector3.UP * 0.4
	queue_free()
	return p


func top() -> float:
	return global_position.y + 0.13


func hint_text() -> String:
	var p := get_tree().get_first_node_in_group("player")
	var nm := "Curved Rail" if curve >= 0 else "Rail"
	if p != null and String(p.get("tool")) == "hammer":
		return "%s    [Click] pick it up    [R] turn it" % nm
	return nm
