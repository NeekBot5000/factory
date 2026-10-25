class_name Truck
extends AnimatableBody3D
## A drivable-looking truck that follows the forest road.
## role "ship": a green log truck parked by the cabin. Drop bark in its bed, press E to send it off; it sells
##              the load in town and comes back.
## role "deliver": the orange TimberMart van. Drives in, rolls up its rear door, unloads order boxes, backs out.
## Truck model faces -Z (cab at the front).

signal shipped(value: float)
signal arrived

const SPEED := 10.0
const AWAY_TIME := 4.0

var role := "ship"
var main: Node
var state := "parked"
var park_xform := Transform3D.IDENTITY
var route_out: Array[Vector3] = []     # from the cabin, over the crest at the end of the road (out of sight)
var route_in: Array[Vector3] = []      # from behind the crest back to the parking / unloading spot
var route_dock: Array[Vector3] = []    # van only: the short back-up onto the loading dock
var _reverse := false
var _beep := 0.0
var wheels: Array[Node3D] = []
var bed_area: Area3D
var sign: Label3D
var rear_door: Node3D
var cargo: Array[Node3D] = []
var cargo_value := 0.0
var engine: AudioStreamPlayer3D

var _track := PackedVector3Array()    # smoothed, densely sampled path being driven
var _cum := PackedFloat32Array()       # distance along _track at each sample
var _s := 0.0
var _wait := 0.0
var _speed := 0.0
var _on_done := Callable()


func build(p_role: String, p_main: Node, park: Transform3D, out: Array[Vector3], back: Array[Vector3]) -> void:
	role = p_role
	main = p_main
	park_xform = park
	route_out = out
	route_in = back
	sync_to_physics = true
	collision_layer = 1
	collision_mask = 0
	var body_col := Color("2f7d4a") if role == "ship" else Color("e8792b")
	_chassis(body_col)
	if role == "ship":
		_flatbed()
	else:
		_van()
	engine = AudioStreamPlayer3D.new()
	engine.stream = Sfx.engine_stream()
	engine.unit_size = 6.0
	engine.volume_db = -6.0
	add_child(engine)
	if role == "ship":
		global_transform = park
	else:
		global_transform = Transform3D(Basis.IDENTITY, route_in[0])
		visible = false
		state = "away"


# ------------------------------------------------------------------ model

func _col(size: Vector3, pos: Vector3) -> void:
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	cs.position = pos
	add_child(cs)


func _chassis(body_col: Color) -> void:
	var dark := LowPoly.mat(Color("2b2d33"), 0.8)
	var paint := LowPoly.mat(body_col, 0.45)
	var glass := LowPoly.mat(Color("9fd3f0"), 0.1, 0.15)
	var chrome := Tools.steel(Color("dfe3e8"), 0.2)
	# frame + cab
	LowPoly.mesh_instance(self, LowPoly.box(Vector3(2.0, 0.35, 6.2)), dark, Vector3(0, 0.75, 0))
	LowPoly.mesh_instance(self, LowPoly.box(Vector3(2.1, 1.35, 1.9)), paint, Vector3(0, 1.6, -2.1))
	LowPoly.mesh_instance(self, LowPoly.box(Vector3(2.1, 0.75, 1.0)), paint, Vector3(0, 1.28, -3.4))
	LowPoly.mesh_instance(self, LowPoly.box(Vector3(1.9, 0.6, 0.05)), glass, Vector3(0, 1.95, -3.06), Vector3(-12, 0, 0))
	for s in [-1, 1]:
		LowPoly.mesh_instance(self, LowPoly.box(Vector3(0.05, 0.55, 1.0)), glass, Vector3(s * 1.06, 1.95, -2.2))
		LowPoly.mesh_instance(self, LowPoly.box(Vector3(0.3, 0.18, 0.06)), LowPoly.mat(Color("fff6c8"), 0.3, 1.5), Vector3(s * 0.75, 1.25, -3.92))
		LowPoly.mesh_instance(self, LowPoly.box(Vector3(0.08, 0.25, 0.12)), chrome, Vector3(s * 1.15, 2.0, -2.9))
	LowPoly.mesh_instance(self, LowPoly.box(Vector3(1.2, 0.35, 0.05)), chrome, Vector3(0, 1.0, -3.92))
	LowPoly.mesh_instance(self, LowPoly.box(Vector3(2.2, 0.22, 0.25)), chrome, Vector3(0, 0.7, -3.95))
	# wheels
	for z in [-2.6, 1.4, 2.4]:
		for s in [-1, 1]:
			var w := Node3D.new()
			w.position = Vector3(s * 1.0, 0.48, z)
			add_child(w)
			LowPoly.mesh_instance(w, LowPoly.cyl(0.48, 0.48, 0.38, 10), dark, Vector3.ZERO, Vector3(0, 0, 90))
			LowPoly.mesh_instance(w, LowPoly.cyl(0.24, 0.24, 0.4, 8), chrome, Vector3.ZERO, Vector3(0, 0, 90))
			wheels.append(w)
	_col(Vector3(2.1, 2.2, 2.9), Vector3(0, 1.4, -2.6))
	_col(Vector3(2.0, 0.6, 6.2), Vector3(0, 0.75, 0))


func _flatbed() -> void:
	var boards := LowPoly.mat(Color("8a5a36"), 0.95)
	var boards2 := LowPoly.mat(Color("6f4728"), 0.95)
	LowPoly.mesh_instance(self, LowPoly.box(Vector3(2.2, 0.12, 4.0)), boards, Vector3(0, 1.0, 1.0))
	for s in [-1, 1]:
		LowPoly.mesh_instance(self, LowPoly.box(Vector3(0.08, 0.7, 4.0)), boards2, Vector3(s * 1.08, 1.4, 1.0))
		_col(Vector3(0.12, 0.8, 4.0), Vector3(s * 1.08, 1.45, 1.0))
		for k in 3:
			LowPoly.mesh_instance(self, LowPoly.box(Vector3(0.1, 0.8, 0.08)), LowPoly.mat(Color("3a3d44")), Vector3(s * 1.1, 1.4, -0.7 + k * 1.7))
	LowPoly.mesh_instance(self, LowPoly.box(Vector3(2.2, 0.7, 0.08)), boards2, Vector3(0, 1.4, 3.0))
	LowPoly.mesh_instance(self, LowPoly.box(Vector3(2.2, 0.9, 0.1)), LowPoly.mat(Color("3a3d44")), Vector3(0, 1.5, -1.0))
	_col(Vector3(2.2, 0.15, 4.0), Vector3(0, 1.0, 1.0))
	_col(Vector3(2.2, 0.8, 0.12), Vector3(0, 1.45, 3.0))
	_col(Vector3(2.2, 0.9, 0.12), Vector3(0, 1.5, -1.0))
	bed_area = Area3D.new()
	bed_area.collision_layer = 0
	bed_area.collision_mask = 2
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(2.0, 1.4, 3.8)
	cs.shape = sh
	cs.position = Vector3(0, 1.75, 1.0)
	bed_area.add_child(cs)
	add_child(bed_area)
	sign = Label3D.new()
	sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sign.font_size = 48
	sign.pixel_size = 0.005
	sign.outline_size = 12
	sign.position = Vector3(0, 2.7, 1.0)
	sign.modulate = Color("ffe28a")
	sign.no_depth_test = true          # always readable, even behind a full load
	sign.render_priority = 10
	add_child(sign)


func _van() -> void:
	var box_col := LowPoly.mat(Color("f2efe6"), 0.6)
	LowPoly.mesh_instance(self, LowPoly.box(Vector3(2.3, 2.3, 4.3)), box_col, Vector3(0, 2.05, 0.95))
	LowPoly.mesh_instance(self, LowPoly.box(Vector3(2.32, 0.25, 4.32)), LowPoly.mat(Color("e8792b"), 0.5), Vector3(0, 1.0, 0.95))
	_col(Vector3(2.3, 2.3, 4.3), Vector3(0, 2.05, 0.95))
	rear_door = Node3D.new()
	rear_door.position = Vector3(0, 3.15, 3.12)
	add_child(rear_door)
	LowPoly.mesh_instance(rear_door, LowPoly.box(Vector3(2.1, 2.1, 0.05)), LowPoly.mat(Color("c9c4b8"), 0.6), Vector3(0, -1.05, 0))
	for k in 6:
		LowPoly.mesh_instance(rear_door, LowPoly.box(Vector3(2.1, 0.02, 0.06)), LowPoly.mat(Color("9a958a")), Vector3(0, -0.2 - k * 0.33, 0.01))


# ------------------------------------------------------------------ shipping (log truck)

func load_value() -> float:
	if bed_area == null:
		return 0.0
	var v := 0.0
	for b in bed_area.get_overlapping_bodies():
		v += sale_value(b)
	return v


## What the mill pays for something in the bed (bark, leaves, logs); 0 for anything else.
static func sale_value(b: Node) -> float:
	if not (b is RigidBody3D) or (b as RigidBody3D).freeze:
		return 0.0
	if b is Chip:
		return (b as Chip).value
	if b is Leaf:
		return (b as Leaf).value
	if b is Log:
		return (b as Log).value()
	if b is Ore:
		return (b as Ore).value
	if b.has_meta("sale_value"):
		return float(b.get_meta("sale_value"))     # built things (baskets, balls...)
	return 0.0


func hint_text() -> String:
	if role == "ship" and state == "parked":
		var v := load_value()
		if v > 0.0:
			return "[E] ship  $%.2f" % v
	return ""


func on_use(_player: Node) -> void:
	if role == "ship":
		ship()


func ship() -> bool:
	if role != "ship" or state != "parked":
		return false
	var v := load_value()
	if v <= 0.0:
		return false
	cargo.clear()
	cargo_value = v
	for b in bed_area.get_overlapping_bodies():
		if sale_value(b) > 0.0:
			var c := b as RigidBody3D
			if main.player.held == c:
				main.player.drop_held()
			c.freeze = true
			c.remove_from_group("grabbable")
			c.reparent(self, true)
			cargo.append(c)
	Sfx.play("horn")
	state = "leaving"
	sign.visible = false
	_drive(route_out, func():
		state = "away"
		visible = false
		engine.stop()
		_wait = AWAY_TIME)
	return true


# ------------------------------------------------------------------ delivery van

func deliver() -> void:
	if role != "deliver" or state != "away":
		return
	visible = true
	state = "arriving"
	# drives in forwards and U-turns in the clearing so the rear door ends up facing the cabin
	_drive(route_in, func():
		# then back up onto the loading dock, beeping
		_drive(route_dock, func():
			state = "unloading"
			_unload(), true))


func _unload() -> void:
	var tw := create_tween()
	tw.tween_property(rear_door, "rotation_degrees:x", -95.0, 0.6)
	tw.tween_callback(func():
		main.call("unload_boxes", self)
		Sfx.play("drop", 0.7))
	tw.tween_interval(2.0)
	tw.tween_property(rear_door, "rotation_degrees:x", 0.0, 0.6)
	tw.tween_callback(func():
		state = "leaving"
		_drive(route_out, func():
			state = "away"
			visible = false
			engine.stop()
			arrived.emit()))


## Where boxes come out (world space, just behind the rear door).
func rear_point() -> Vector3:
	return global_transform * Vector3(0, 1.4, 3.6)


# ------------------------------------------------------------------ driving

## Smooths the waypoints into a dense Catmull-Rom curve and starts driving along it (always forwards).
func _drive(path: Array[Vector3], done: Callable, reverse := false) -> void:
	_reverse = reverse
	_track = _smooth(path)
	_cum = PackedFloat32Array()
	_cum.resize(_track.size())
	var total := 0.0
	for i in _track.size():
		if i > 0:
			total += _track[i].distance_to(_track[i - 1])
		_cum[i] = total
	_s = 0.0
	_on_done = done
	_speed = 0.0
	global_transform = _pose(0.0)
	if not engine.playing:
		engine.play()


static func _smooth(pts: Array[Vector3]) -> PackedVector3Array:
	var out := PackedVector3Array()
	var n := pts.size()
	for i in n - 1:
		var p0: Vector3 = pts[maxi(i - 1, 0)]
		var p1: Vector3 = pts[i]
		var p2: Vector3 = pts[i + 1]
		var p3: Vector3 = pts[mini(i + 2, n - 1)]
		var steps := maxi(2, int(p1.distance_to(p2) / 0.5))
		for k in steps:
			var t := float(k) / steps
			var t2 := t * t
			var t3 := t2 * t
			out.append(0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3))
	out.append(pts[n - 1])
	return out


func _sample(s: float) -> Vector3:
	var total := _cum[_cum.size() - 1]
	s = clampf(s, 0.0, total)
	var lo := 0
	var hi := _cum.size() - 1
	while hi - lo > 1:
		var mid := (lo + hi) >> 1
		if _cum[mid] <= s:
			lo = mid
		else:
			hi = mid
	var seg := maxf(_cum[hi] - _cum[lo], 0.0001)
	return _track[lo].lerp(_track[hi], (s - _cum[lo]) / seg)


## Position at distance s, facing along the curve (looking a little ahead and behind smooths the steering).
func _pose(s: float) -> Transform3D:
	var p := _sample(s)
	var ahead := _sample(s + 2.5)
	var behind := _sample(s - 2.5)
	var dir := ahead - behind
	if dir.length() < 0.01:
		return Transform3D(global_basis, p)
	return Transform3D(Basis.looking_at(-dir.normalized() if _reverse else dir.normalized(), Vector3.UP), p)


func _physics_process(delta: float) -> void:
	if role == "ship" and sign != null:
		var v := load_value() if state == "parked" else 0.0
		sign.visible = state == "parked" and v > 0.0
		if sign.visible:
			sign.text = "$%.2f" % v
	if role == "ship" and state == "away":
		_wait -= delta
		if _wait <= 0.0:
			for c in cargo:
				if is_instance_valid(c):
					c.queue_free()
			cargo.clear()
			Game.add_money(cargo_value)
			Game.toast.emit("+$%.2f" % cargo_value, Color("7aff9a"))
			Sfx.play("buy")
			shipped.emit(cargo_value)
			state = "returning"
			visible = true
			_drive(route_in, func():
				state = "parked"
				global_transform = park_xform
				engine.stop())
	if _track.is_empty():
		return
	var total := _cum[_cum.size() - 1]
	var remaining := total - _s
	var want := minf(SPEED if not _reverse else 2.2, maxf(1.0, remaining * 0.9))
	if _s < 6.0:
		want = minf(want, 2.0 + _s * 1.2)       # pull away gently
	_speed = move_toward(_speed, want, delta * 4.0)
	_s += _speed * delta
	if _s >= total:
		global_transform = _pose(total)
		_track = PackedVector3Array()
		var cb := _on_done
		_on_done = Callable()
		if cb.is_valid():
			cb.call()
		return
	var target := _pose(_s)
	var q := global_basis.get_rotation_quaternion().slerp(target.basis.get_rotation_quaternion(), minf(1.0, delta * 6.0))
	global_transform = Transform3D(Basis(q), target.origin)
	for w in wheels:
		w.rotation.x -= _speed * delta / 0.48 * (-1.0 if _reverse else 1.0)
	if _reverse:
		_beep -= delta
		if _beep <= 0.0:
			_beep = 0.5
			Sfx.play("click", 1.6, 2.0)
	engine.pitch_scale = 0.7 + _speed / SPEED * 0.5
