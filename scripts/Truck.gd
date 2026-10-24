class_name Truck
extends AnimatableBody3D
## A drivable-looking truck that follows the forest road.
## role "ship": a green log truck parked by the cabin. Drop bark in its bed, press E to send it off; it sells
##              the load in town and comes back.
## role "deliver": the orange TimberMart van. Drives in, rolls up its rear door, unloads order boxes, backs out.
## Truck model faces -Z (cab at the front).

signal shipped(value: float)
signal arrived

const SPEED := 8.0

var role := "ship"
var main: Node
var state := "parked"
var park_xform := Transform3D.IDENTITY
var route_out: Array[Vector3] = []     # from the parking spot out to the edge of the map
var wheels: Array[Node3D] = []
var bed_area: Area3D
var sign: Label3D
var rear_door: Node3D
var cargo: Array[Node3D] = []
var cargo_value := 0.0
var engine: AudioStreamPlayer3D

var _path: Array[Vector3] = []
var _path_i := 0
var _forward := true
var _wait := 0.0
var _speed := 0.0
var _on_done := Callable()


func build(p_role: String, p_main: Node, park: Transform3D, out: Array[Vector3]) -> void:
	role = p_role
	main = p_main
	park_xform = park
	route_out = out
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
		global_transform = Transform3D(Basis.IDENTITY, route_out[route_out.size() - 1] + Vector3(0, -50, 0))
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
	sign.font_size = 64
	sign.pixel_size = 0.006
	sign.outline_size = 12
	sign.position = Vector3(0, 3.0, -1.2)
	sign.modulate = Color("ffe28a")
	add_child(sign)
	var logo := Label3D.new()
	logo.text = "PINEWOOD\nTIMBER CO."
	logo.font_size = 48
	logo.pixel_size = 0.004
	logo.position = Vector3(1.07, 1.65, -2.1)
	logo.rotation_degrees.y = 90
	logo.modulate = Color("f5f0e0")
	add_child(logo)


func _van() -> void:
	var box_col := LowPoly.mat(Color("f2efe6"), 0.6)
	LowPoly.mesh_instance(self, LowPoly.box(Vector3(2.3, 2.3, 4.3)), box_col, Vector3(0, 2.05, 0.95))
	LowPoly.mesh_instance(self, LowPoly.box(Vector3(2.32, 0.25, 4.32)), LowPoly.mat(Color("e8792b"), 0.5), Vector3(0, 1.0, 0.95))
	_col(Vector3(2.3, 2.3, 4.3), Vector3(0, 2.05, 0.95))
	for s in [-1, 1]:
		var logo := Label3D.new()
		logo.text = "TimberMart\nDelivery"
		logo.font_size = 72
		logo.pixel_size = 0.006
		logo.modulate = Color("e8792b")
		logo.outline_size = 0
		logo.position = Vector3(s * 1.16, 2.2, 0.9)
		logo.rotation_degrees.y = 90 * s
		add_child(logo)
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
		if b is Chip and not (b as Chip).freeze:
			v += (b as Chip).value
	return v


func hint_text() -> String:
	if role == "deliver":
		return "TimberMart delivery van"
	match state:
		"parked":
			var v := load_value()
			if v <= 0.0:
				return "Log truck - throw or drop bark into the bed, then [E] to ship it"
			return "Log truck - load worth $%.2f    [E] ship it to town" % v
		_:
			return "The log truck is on its way to town"
	return ""


func on_use(_player: Node) -> void:
	if role == "ship":
		ship()


func ship() -> bool:
	if role != "ship" or state != "parked":
		return false
	var v := load_value()
	if v <= 0.0:
		Game.toast.emit("The truck bed is empty - load some bark first", Color("ffd27a"))
		return false
	cargo.clear()
	cargo_value = v
	for b in bed_area.get_overlapping_bodies():
		if b is Chip and not (b as Chip).freeze:
			var c := b as Chip
			if main.player.held == c:
				main.player.drop_held()
			c.freeze = true
			c.remove_from_group("grabbable")
			c.reparent(self, true)
			cargo.append(c)
	Sfx.play("horn")
	state = "leaving"
	_drive(route_out, true, func():
		state = "away"
		_wait = 6.0)
	return true


# ------------------------------------------------------------------ delivery van

func deliver() -> void:
	if role != "deliver" or state != "away":
		return
	visible = true
	var back: Array[Vector3] = route_out.duplicate()
	back.reverse()
	# backs up to the cabin so the rear door faces the porch, then drives off forwards
	global_transform = Transform3D(Basis(Vector3.UP, PI), back[0])
	state = "arriving"
	_drive(back, false, func():
		state = "unloading"
		_unload())


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
		_drive(route_out, true, func():
			state = "away"
			visible = false
			arrived.emit()))


## Where boxes come out (world space, just behind the rear door).
func rear_point() -> Vector3:
	return global_transform * Vector3(0, 1.4, 3.6)


# ------------------------------------------------------------------ driving

func _drive(path: Array[Vector3], forward: bool, done: Callable) -> void:
	_path = path.duplicate()   # copy: the path is cleared when finished, and callers pass route_out itself
	_path_i = 0
	_forward = forward
	_on_done = done
	_speed = 0.0
	if not engine.playing:
		engine.play()


func _physics_process(delta: float) -> void:
	if role == "ship" and state == "parked" and sign != null:
		var v := load_value()
		sign.text = "LOAD  $%.2f\n[E] SHIP" % v if v > 0.0 else "LOAD BARK HERE"
	if role == "ship" and state == "away":
		_wait -= delta
		if _wait <= 0.0:
			for c in cargo:
				if is_instance_valid(c):
					c.queue_free()
			cargo.clear()
			Game.add_money(cargo_value)
			Game.toast.emit("Sold a truckload of bark for $%.2f" % cargo_value, Color("7aff9a"))
			Sfx.play("buy")
			shipped.emit(cargo_value)
			state = "returning"
			var back: Array[Vector3] = route_out.duplicate()
			back.reverse()
			_drive(back, false, func():
				state = "parked"
				global_transform = park_xform
				engine.stop())
	if _path.is_empty():
		return
	if _path_i >= _path.size():
		_path.clear()
		var cb := _on_done
		_on_done = Callable()
		if role == "deliver" and state == "leaving":
			engine.stop()
		if cb.is_valid():
			cb.call()
		return
	var target: Vector3 = _path[_path_i]
	var pos := global_position
	var to := target - pos
	var dist := Vector2(to.x, to.z).length()
	var remaining := dist
	for k in range(_path_i, _path.size() - 1):
		remaining += _path[k].distance_to(_path[k + 1])
	var want := minf(SPEED, maxf(1.5, remaining * 1.2))
	_speed = move_toward(_speed, want, delta * 5.0)
	var step := _speed * delta
	if dist <= step or dist < 0.05:
		global_position = target
		_path_i += 1
	else:
		var dir := Vector3(to.x, 0, to.z).normalized()
		var face := dir if _forward else -dir
		var b := Basis.looking_at(face, Vector3.UP)
		var q := global_basis.get_rotation_quaternion().slerp(b.get_rotation_quaternion(), minf(1.0, delta * 4.0))
		var np := pos + dir * step
		np.y = lerpf(pos.y, target.y, step / maxf(dist, 0.001))
		global_transform = Transform3D(Basis(q), np)
	for w in wheels:
		w.rotation.x -= _speed * delta / 0.48 * (1.0 if _forward else -1.0)
	engine.pitch_scale = 0.7 + _speed / SPEED * 0.5
