class_name Rail
extends StaticBody3D
## A laid piece of track: one 1 m grid square, running along X or along Z. Minecarts roll along rails.
## With the hammer: click a loose rail to lay it, click a laid rail to pick it up again.

static var _map := {}       # Vector2i cell -> Rail

var cell := Vector2i.ZERO
var along_x := false
var value := Product.RAIL_VALUE   # what the rail item was worth (it is again when picked up)


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
	for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0)]:
		if at(c + d) != null and at(c + d).along_x:
			x_dir = true
	for d: Vector2i in [Vector2i(0, 1), Vector2i(0, -1)]:
		if at(c + d) != null and not at(c + d).along_x:
			x_dir = false
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
	global_transform = Transform3D(Basis(Vector3.UP, PI * 0.5 if along_x else 0.0), Vector3(c.x, y, c.y))
	var iron := Tools.steel(Color("8d949e"), 0.4)
	var wood := LowPoly.mat(Color("6b4a32"), 0.95)
	for k in 3:
		LowPoly.mesh_instance(self, LowPoly.box(Vector3(0.8, 0.06, 0.14)), wood, Vector3(0, 0.03, -0.33 + k * 0.33))
	for sx: float in [-0.25, 0.25]:
		LowPoly.mesh_instance(self, LowPoly.box(Vector3(0.06, 0.07, 1.0)), iron, Vector3(sx, 0.09, 0))
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(0.8, 0.12, 1.0)
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
	p.setup("rail", 0.0, Color("8d949e"))
	p.value = value
	p.global_position = global_position + Vector3.UP * 0.4
	queue_free()
	return p


func top() -> float:
	return global_position.y + 0.13


func hint_text() -> String:
	var p := get_tree().get_first_node_in_group("player")
	if p != null and String(p.get("tool")) == "hammer":
		return "Rail    [Click] pick it up"
	return "Rail"
