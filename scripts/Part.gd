class_name Part
extends Node3D
## A placed factory part occupying one grid cell. Origin = bottom-centre of the cell, forward = -Z.

var world: Node
var type_id := ""
var def: Dictionary
var cell := Vector3i.ZERO
var rot := 0
var paid := 0.0
var ghost := false
var body: StaticBody3D
var area: Area3D
var drop_accum := 0.0
var uid := 0
var sold := 0
var level := 0
var split_i := 0
var _inside := {}
var route_counts := {}
var _pips: Array = []
var _handles: Array = []


func setup(p_world: Node, p_type: String, p_cell: Vector3i, p_rot: int, p_ghost: bool = false) -> void:
	world = p_world
	type_id = p_type
	def = Defs.PARTS[p_type]
	cell = p_cell
	rot = posmod(p_rot, 4)
	ghost = p_ghost
	uid = get_instance_id()
	set_physics_process(false)
	position = Vector3(cell.x + 0.5, cell.y, cell.z + 0.5)
	rotation_degrees.y = -90.0 * rot
	match String(def.kind):
		"belt": _build_belt()
		"splitter": _build_splitter()
		"ramp": _build_ramp()
		"processor": _build_processor()
		"dropper": _build_dropper()
		"seller": _build_seller()
		"block": _build_block()
	apply_speed()


func set_rot(r: int) -> void:
	rot = posmod(r, 4)
	rotation_degrees.y = -90.0 * rot
	for h in _handles:
		world.batcher.move(h, _xf())
	for h in _pips:
		world.batcher.move(h, _xf())
	apply_speed()


func _xf() -> Transform3D:
	return Transform3D(Basis(Vector3.UP, deg_to_rad(-90.0 * rot)), position)


func release_visuals() -> void:
	release_pips()
	for h in _handles:
		world.batcher.remove(h)
	_handles.clear()


func dir_vec() -> Vector3:
	return Vector3(Defs.DIRS[rot])


func level_mult() -> float:
	var b: float = Defs.LEVEL_BONUS.get(String(def.kind), 0.0)
	return 1.0 + b * level


func apply_speed() -> void:
	if body == null:
		return
	var k: String = def.kind
	var spd: float = float(def.get("speed", 0.0)) * Game.belt_mult() * level_mult()
	if k == "belt" or k == "processor":
		body.constant_linear_velocity = dir_vec() * spd
	elif k == "ramp":
		var s := sin(PI / 4.0)
		body.constant_linear_velocity = (dir_vec() * s + Vector3.UP * s) * spd
	elif k == "splitter":
		body.constant_linear_velocity = Vector3.ZERO


func processor_mult() -> float:
	return Game.proc_mult(float(def.mult)) * level_mult()


func upgrade_cost() -> float:
	return Game.part_upgrade_cost(type_id, level)


func can_upgrade() -> bool:
	return String(def.kind) != "block" and level < Defs.LEVEL_MAX


func set_level(l: int) -> void:
	level = clampi(l, 0, Defs.LEVEL_MAX)
	refresh_pips()
	apply_speed()


func _pip_origin() -> Vector3:
	match String(def.kind):
		"dropper": return Vector3(-0.4, 1.03, 0.0)
		"seller": return Vector3(-0.4, 0.28, 0.44)
		"processor": return Vector3(-0.4, 0.95, 0.0)
		"splitter", "belt": return Vector3(-0.4, 0.27, -0.47)
	return Vector3.ZERO


func refresh_pips() -> void:
	if ghost or String(def.kind) == "ramp" or String(def.kind) == "block":
		return
	for h in _pips:
		world.batcher.remove(h)
	_pips.clear()
	var o := _pip_origin()
	var along_z := String(def.kind) == "belt" or String(def.kind) == "splitter"
	var mesh := Meshes.box_mesh(Vector3(0.07, 0.07, 0.07))
	var m := Meshes.mat(Color("ff7ad9") if level >= Defs.LEVEL_MAX else Color("ffd23f"), 1.0, 0.3)
	for i in level:
		var pos := o + (Vector3(0, 0, i * 0.09) if along_z else Vector3(i * 0.09, 0, 0))
		if along_z:
			pos.x = -0.47
			pos.z = -0.4 + i * 0.09
		var local := Transform3D(Basis.IDENTITY, pos)
		_pips.append(world.batcher.add(mesh, m, _xf() * local, local))


func release_pips() -> void:
	for h in _pips:
		world.batcher.remove(h)
	_pips.clear()


func info_text() -> String:
	var k: String = def.kind
	var t: String = def.name
	match k:
		"dropper":
			var r: Dictionary = Defs.RESOURCES[def.res]
			t += "\nDrops %s: %s each" % [r.name, Util.money(float(r.value) * Game.sell_mult())]
			t += "\nRate: %.2f/s" % (float(r.rate) * Game.drop_rate_mult() * level_mult())
		"belt", "ramp", "splitter":
			t += "\nSpeed: %.1f u/s" % (float(def.speed) * Game.belt_mult() * level_mult())
		"processor":
			t += "\nValue x%.2f" % processor_mult()
		"seller":
			t += "\nSells at x%.2f (market x%.2f)" % [float(def.mult) * level_mult(), Game.sell_mult()]
	if String(def.kind) != "block":
		t += "\nLevel %d / %d (x%.2f)" % [level, Defs.LEVEL_MAX, level_mult()]
		if level < Defs.LEVEL_MAX:
			t += "  -  upgrade %s" % Util.money(upgrade_cost())
	t += "\nLayer %d  |  Refund %s" % [cell.y, Util.money(paid)]
	return t


func set_overlay(m: Material) -> void:
	for c in find_children("*", "MeshInstance3D", true, false):
		(c as MeshInstance3D).material_overlay = m
		(c as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


# ------------------------------------------------------------ builders

func _vis(mesh: Mesh, m: Material, pos: Vector3, rot_deg: Vector3 = Vector3.ZERO) -> void:
	var local := Transform3D(Basis.from_euler(Vector3(deg_to_rad(rot_deg.x), deg_to_rad(rot_deg.y), deg_to_rad(rot_deg.z))), pos)
	if ghost:
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.material_override = m
		mi.transform = local
		add_child(mi)
	else:
		_handles.append(world.batcher.add(mesh, m, _xf() * local, local))


func _box(size: Vector3, pos: Vector3, m: Material, rot_deg: Vector3 = Vector3.ZERO) -> void:
	_vis(Meshes.box_mesh(size), m, pos, rot_deg)


func _make_body() -> StaticBody3D:
	var b := StaticBody3D.new()
	b.collision_layer = 1
	b.collision_mask = 0
	b.set_meta("part", self)
	var pm := PhysicsMaterial.new()
	pm.friction = 4.0
	b.physics_material_override = pm
	add_child(b)
	return b


func _add_shape(b: Node3D, size: Vector3, pos: Vector3, rot_deg: Vector3 = Vector3.ZERO) -> void:
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	cs.position = pos
	cs.rotation_degrees = rot_deg
	b.add_child(cs)


func _make_area(size: Vector3, pos: Vector3) -> Area3D:
	var a := Area3D.new()
	a.collision_layer = 0
	a.collision_mask = 2
	a.monitoring = true
	a.monitorable = false
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	cs.position = pos
	a.add_child(cs)
	add_child(a)
	return a


func _belt_visual(tint: Color, key: String, base_speed: float) -> void:
	_box(Vector3(1.0, 0.16, 1.0), Vector3(0, 0.08, 0), Meshes.mat(Color("2a2f3d")))
	_box(Vector3(0.84, 0.045, 1.0), Vector3(0, 0.1775, 0), Meshes.belt_mat(key, tint, base_speed))
	# little side studs so rows of belts read as a belt
	_box(Vector3(0.06, 0.1, 1.0), Vector3(0.47, 0.19, 0), Meshes.mat(Color("3a4155")))
	_box(Vector3(0.06, 0.1, 1.0), Vector3(-0.47, 0.19, 0), Meshes.mat(Color("3a4155")))


func _build_belt() -> void:
	_belt_visual(def.tint, type_id, float(def.speed))
	if not ghost:
		body = _make_body()
		_add_shape(body, Vector3(1.0, 0.2, 1.0), Vector3(0, 0.1, 0))


func _build_splitter() -> void:
	var tint: Color = def.tint
	_box(Vector3(1.0, 0.16, 1.0), Vector3(0, 0.08, 0), Meshes.mat(Color("2a2f3d")))
	_box(Vector3(0.86, 0.045, 1.0), Vector3(0, 0.1775, 0), Meshes.mat(tint.darkened(0.45), 0.0, 0.6))
	var mk := Meshes.mat(tint, 0.6, 0.4)
	_box(Vector3(0.1, 0.03, 0.4), Vector3(0, 0.215, -0.1), mk)
	_box(Vector3(0.1, 0.03, 0.34), Vector3(-0.18, 0.215, 0.0), mk, Vector3(0, 55, 0))
	_box(Vector3(0.1, 0.03, 0.34), Vector3(0.18, 0.215, 0.0), mk, Vector3(0, -55, 0))
	_box(Vector3(0.06, 0.1, 1.0), Vector3(0.47, 0.19, 0), Meshes.mat(Color("3a4155")))
	_box(Vector3(0.06, 0.1, 1.0), Vector3(-0.47, 0.19, 0), Meshes.mat(Color("3a4155")))
	if not ghost:
		body = _make_body()
		_add_shape(body, Vector3(1.0, 0.2, 1.0), Vector3(0, 0.1, 0))
		(body.physics_material_override as PhysicsMaterial).friction = 0.15
		area = _make_area(Vector3(0.9, 0.5, 0.9), Vector3(0, 0.4, 0))
		area.body_entered.connect(_on_splitter_entered)
		area.body_exited.connect(_on_splitter_exited)
		set_physics_process(true)


func _on_splitter_entered(b: Node3D) -> void:
	var it := b as Item
	if it == null or not it.active:
		return
	# round-robin among connected outputs: left, forward, right (relative to rotation)
	var outs: Array[int] = []
	for off in [-1, 0, 1]:
		var d: Vector3i = Defs.DIRS[posmod(rot + off, 4)]
		var n: Part = world.cells.get(cell + d)
		if n != null and String(n.def.kind) != "dropper" and String(n.def.kind) != "block":
			outs.append(off)
	if outs.is_empty():
		outs.append(0)
	var nxt: int = outs[(outs.find(split_i) + 1) % outs.size()] if outs.has(split_i) else outs[0]
	split_i = nxt
	route_counts[nxt] = int(route_counts.get(nxt, 0)) + 1
	_inside[it] = Vector3(Defs.DIRS[posmod(rot + nxt, 4)])


func _on_splitter_exited(b: Node3D) -> void:
	_inside.erase(b)


func _physics_process(_delta: float) -> void:
	# steer each item inside the splitter toward its assigned output
	var spd := float(def.speed) * Game.belt_mult() * level_mult()
	for it in _inside.keys():
		if not is_instance_valid(it) or not (it as Item).active:
			_inside.erase(it)
			continue
		var dv: Vector3 = _inside[it]
		var perp := Vector3(dv.z, 0, dv.x)
		var err := (global_position - (it as Item).global_position).dot(perp)
		var target: Vector3 = dv * spd + perp * clampf(err * 8.0, -2.5, 2.5)
		var v: Vector3 = (it as Item).linear_velocity
		(it as Item).linear_velocity = Vector3(lerpf(v.x, target.x, 0.5), v.y, lerpf(v.z, target.z, 0.5))


func _build_ramp() -> void:
	_vis(Meshes.wedge_mesh(), Meshes.mat(Color("2a2f3d")), Vector3.ZERO)
	var n := Vector3(0, 0.7071, 0.7071)
	var top_center := Vector3(0, 0.7, 0)
	var rx := Vector3(45, 0, 0)
	_box(Vector3(0.96, 0.16, 1.4142), top_center - n * 0.12, Meshes.mat(Color("2a2f3d")), rx)
	_box(Vector3(0.84, 0.045, 1.4142), top_center - n * 0.0225, Meshes.belt_mat(type_id, def.tint, float(def.speed)), rx)
	_box(Vector3(0.06, 0.1, 1.4142), top_center - n * 0.0225 + Vector3(0.47, 0, 0) + n * 0.02, Meshes.mat(Color("3a4155")), rx)
	_box(Vector3(0.06, 0.1, 1.4142), top_center - n * 0.0225 + Vector3(-0.47, 0, 0) + n * 0.02, Meshes.mat(Color("3a4155")), rx)
	if not ghost:
		body = _make_body()
		_add_shape(body, Vector3(1.0, 0.2, 1.4142), top_center - n * 0.1, rx)
		# side rails keep items from rolling off the slope
		for sx in [-0.5, 0.5]:
			_add_shape(body, Vector3(0.1, 0.45, 1.4142), top_center + Vector3(sx, 0, 0) + n * 0.12, rx)


func _build_processor() -> void:
	var tint: Color = def.tint
	_belt_visual(tint, type_id, float(def.speed))
	var frame := Meshes.mat(tint.darkened(0.35), 0.0, 0.5)
	_box(Vector3(0.14, 0.8, 0.14), Vector3(0.46, 0.4, 0), frame)
	_box(Vector3(0.14, 0.8, 0.14), Vector3(-0.46, 0.4, 0), frame)
	_box(Vector3(1.0, 0.16, 0.3), Vector3(0, 0.84, 0), Meshes.mat(tint, 0.5, 0.4))
	_box(Vector3(0.8, 0.55, 0.05), Vector3(0, 0.5, 0), Meshes.glass(tint, 0.3))
	if not ghost:
		body = _make_body()
		_add_shape(body, Vector3(1.0, 0.2, 1.0), Vector3(0, 0.1, 0))
		area = _make_area(Vector3(0.7, 0.6, 0.4), Vector3(0, 0.5, 0))
		area.body_entered.connect(_on_processor_entered)


func _on_processor_entered(b: Node3D) -> void:
	var it := b as Item
	if it != null and it.active:
		it.apply_pass(uid, processor_mult())


func _build_dropper() -> void:
	var r: Dictionary = Defs.RESOURCES[def.res]
	var c: Color = r.color
	var body_m := Meshes.mat(Color("3b4256").lerp(c, 0.35), 0.0, 0.6)
	var post_m := Meshes.mat(Color("586079"))
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			_box(Vector3(0.07, 0.35, 0.07), Vector3(0.41 * sx, 0.175, 0.41 * sz), post_m)
	_vis(Meshes.cyl_mesh(0.46, 0.13, 0.5, 8), body_m, Vector3(0, 0.75, 0))
	_vis(Meshes.cyl_mesh(0.47, 0.47, 0.1, 8), Meshes.mat(c, 0.25, 0.5), Vector3(0, 0.93, 0))
	_vis(Meshes.cyl_mesh(0.13, 0.13, 0.12, 8), Meshes.mat(c.darkened(0.2), 0.2, 0.5), Vector3(0, 0.41, 0))
	_vis(Meshes.item_mesh(def.res), Meshes.spin_mat(c), Vector3(0, 1.12, 0))
	if not ghost:
		body = _make_body()
		_add_shape(body, Vector3(0.84, 0.65, 0.84), Vector3(0, 0.675, 0))


func _build_seller() -> void:
	var tint: Color = def.tint
	_box(Vector3(0.96, 0.2, 0.96), Vector3(0, 0.1, 0), Meshes.mat(Color("2a2f3d")))
	_box(Vector3(0.8, 0.05, 0.8), Vector3(0, 0.215, 0), Meshes.mat(tint, 0.7, 0.4))
	_box(Vector3(0.08, 0.5, 0.08), Vector3(0.42, 0.45, 0.42), Meshes.mat(tint.darkened(0.3)))
	_box(Vector3(0.08, 0.5, 0.08), Vector3(-0.42, 0.45, 0.42), Meshes.mat(tint.darkened(0.3)))
	_box(Vector3(0.08, 0.5, 0.08), Vector3(0.42, 0.45, -0.42), Meshes.mat(tint.darkened(0.3)))
	_box(Vector3(0.08, 0.5, 0.08), Vector3(-0.42, 0.45, -0.42), Meshes.mat(tint.darkened(0.3)))
	_vis(Meshes.coin_mesh(), Meshes.spin_mat(Color("ffd23f")), Vector3(0, 0.62, 0))
	if not ghost:
		body = _make_body()
		_add_shape(body, Vector3(0.96, 0.2, 0.96), Vector3(0, 0.1, 0))
		area = _make_area(Vector3(0.8, 0.6, 0.8), Vector3(0, 0.45, 0))
		area.body_entered.connect(_on_seller_entered)


func _on_seller_entered(b: Node3D) -> void:
	var it := b as Item
	if it != null and it.active:
		world.sell(it, self)


func _build_block() -> void:
	_box(Vector3(1, 1, 1), Vector3(0, 0.5, 0), Meshes.mat(Color("7b8497"), 0.0, 0.9))
	_box(Vector3(0.96, 0.06, 0.96), Vector3(0, 1.0, 0), Meshes.mat(Color("98a2b8"), 0.0, 0.9))
	if not ghost:
		body = _make_body()
		_add_shape(body, Vector3(1, 1, 1), Vector3(0, 0.5, 0))
