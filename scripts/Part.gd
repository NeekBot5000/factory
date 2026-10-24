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
var spin: Node3D
var drop_accum := 0.0
var uid := 0
var sold := 0


func setup(p_world: Node, p_type: String, p_cell: Vector3i, p_rot: int, p_ghost: bool = false) -> void:
	world = p_world
	type_id = p_type
	def = Defs.PARTS[p_type]
	cell = p_cell
	rot = posmod(p_rot, 4)
	ghost = p_ghost
	uid = get_instance_id()
	position = Vector3(cell.x + 0.5, cell.y, cell.z + 0.5)
	rotation_degrees.y = -90.0 * rot
	match String(def.kind):
		"belt": _build_belt()
		"ramp": _build_ramp()
		"processor": _build_processor()
		"dropper": _build_dropper()
		"seller": _build_seller()
		"block": _build_block()
	apply_speed()


func set_rot(r: int) -> void:
	rot = posmod(r, 4)
	rotation_degrees.y = -90.0 * rot
	apply_speed()


func dir_vec() -> Vector3:
	return Vector3(Defs.DIRS[rot])


func apply_speed() -> void:
	if body == null:
		return
	var k: String = def.kind
	var spd: float = float(def.get("speed", 0.0)) * Game.belt_mult()
	if k == "belt" or k == "processor":
		body.constant_linear_velocity = dir_vec() * spd
	elif k == "ramp":
		var s := sin(PI / 4.0)
		body.constant_linear_velocity = (dir_vec() * s + Vector3.UP * s) * spd


func processor_mult() -> float:
	return Game.proc_mult(float(def.mult))


func info_text() -> String:
	var k: String = def.kind
	var t: String = def.name
	match k:
		"dropper":
			var r: Dictionary = Defs.RESOURCES[def.res]
			t += "\nDrops %s: %s each" % [r.name, Util.money(float(r.value) * Game.sell_mult())]
			t += "\nRate: %.2f/s" % (float(r.rate) * Game.drop_rate_mult())
		"belt", "ramp":
			t += "\nSpeed: %.1f u/s" % (float(def.speed) * Game.belt_mult())
		"processor":
			t += "\nValue x%.2f" % processor_mult()
		"seller":
			t += "\nSells at x%.2f (market x%.2f)" % [float(def.mult), Game.sell_mult()]
	t += "\nLayer %d  |  Refund %s" % [cell.y, Util.money(paid)]
	return t


func set_overlay(m: Material) -> void:
	for c in find_children("*", "MeshInstance3D", true, false):
		(c as MeshInstance3D).material_overlay = m
		(c as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


# ------------------------------------------------------------ builders

func _box(size: Vector3, pos: Vector3, m: Material, rot_deg: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = Meshes.box_mesh(size)
	mi.material_override = m
	mi.position = pos
	mi.rotation_degrees = rot_deg
	add_child(mi)
	return mi


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


func _build_ramp() -> void:
	var m := MeshInstance3D.new()
	m.mesh = Meshes.wedge(0.96, 1.0, 0.917)
	m.material_override = Meshes.mat(Color("2a2f3d"))
	add_child(m)
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
	var body_m := Meshes.mat(Color("3b4256"), 0.0, 0.6)
	var post_m := Meshes.mat(Color("586079"))
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			_box(Vector3(0.07, 0.35, 0.07), Vector3(0.41 * sx, 0.175, 0.41 * sz), post_m)
	var funnel := MeshInstance3D.new()
	funnel.mesh = Meshes.cyl_mesh(0.46, 0.13, 0.5, 8)
	funnel.material_override = body_m
	funnel.position = Vector3(0, 0.75, 0)
	add_child(funnel)
	var band := MeshInstance3D.new()
	band.mesh = Meshes.cyl_mesh(0.47, 0.47, 0.1, 8)
	band.material_override = Meshes.mat(c, 0.25, 0.5)
	band.position = Vector3(0, 0.93, 0)
	add_child(band)
	var neck := MeshInstance3D.new()
	neck.mesh = Meshes.cyl_mesh(0.13, 0.13, 0.12, 8)
	neck.material_override = Meshes.mat(c.darkened(0.2), 0.2, 0.5)
	neck.position = Vector3(0, 0.41, 0)
	add_child(neck)
	var gem := MeshInstance3D.new()
	gem.mesh = Meshes.item_mesh(def.res)
	gem.material_override = Meshes.item_mat(def.res, 1)
	gem.position = Vector3(0, 1.1, 0)
	gem.scale = Vector3.ONE * 1.2
	add_child(gem)
	spin = gem
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
	var coin := MeshInstance3D.new()
	coin.mesh = Meshes.cyl_mesh(0.2, 0.2, 0.05, 8)
	coin.material_override = Meshes.mat(Color("ffd23f"), 0.5, 0.3)
	coin.position = Vector3(0, 0.62, 0)
	var holder := Node3D.new()
	holder.position = Vector3(0, 0.62, 0)
	coin.position = Vector3.ZERO
	coin.rotation_degrees.x = 90
	holder.add_child(coin)
	add_child(holder)
	spin = holder
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
