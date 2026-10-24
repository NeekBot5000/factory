class_name Part
extends Node3D
## Base class for every placed part. One grid cell; origin = bottom-centre of the cell; forward = -Z.
## Static visuals go into the shared Batcher (MultiMesh), moving pieces are individual MeshInstance3D nodes.

const DECK_COLOR := Color("2a2f3d")
const FRAME_COLOR := Color("3a4155")
const STEEL := Color("8d97a8")

var world: Node
var type_id := ""
var def: Dictionary
var cell := Vector3i.ZERO
var rot := 0
var paid := 0.0
var ghost := false
var level := 0
var uid := 0
var config := {}

var body: StaticBody3D

# signals
var sig_out := false
var sig_in := false
var in_on := 0
var in_total := 0
var wired_in := false
var _prev_in := false

var _handles: Array = []
var _pips: Array = []


static func create(id: String) -> Part:
	var kind: String = Defs.PARTS[id].kind
	var script: Script = load(Defs.SCRIPTS[kind])
	return script.new()


func setup(p_world: Node, p_type: String, p_cell: Vector3i, p_rot: int, p_ghost: bool = false) -> void:
	world = p_world
	type_id = p_type
	def = Defs.PARTS[p_type]
	cell = p_cell
	rot = posmod(p_rot, 4) if Defs.is_directional(p_type) else 0
	ghost = p_ghost
	uid = get_instance_id()
	position = Vector3(cell.x + 0.5, cell.y, cell.z + 0.5)
	rotation_degrees.y = -90.0 * rot
	init_config()
	build()
	apply_speed()


# ------------------------------------------------------------------ virtuals

func init_config() -> void:
	pass


func build() -> void:
	pass


func needs_tick() -> bool:
	return false


func tick(_delta: float) -> void:
	pass


func needs_anim() -> bool:
	return false


func animate(_delta: float) -> void:
	pass


func on_placed() -> void:
	pass


func on_removed() -> void:
	pass


func on_neighbor_changed() -> void:
	pass


func apply_speed() -> void:
	pass


## Called by the world when the input signal changes (or wiring changes).
func on_signal() -> void:
	apply_speed()


## Logic parts update sig_out here (once per physics tick, after inputs were gathered).
func update_output(_delta: float) -> void:
	pass


## Direct click in interact mode. Return true if handled (otherwise the inspector opens).
func interact() -> bool:
	return false


## Inspector options: [{key, label, values: Array, names: Array(optional)}]
func config_options() -> Array:
	return []


func on_config_changed() -> void:
	pass


func info_lines() -> Array:
	return []


# ------------------------------------------------------------------ helpers

func kind() -> String:
	return String(def.kind)


func enabled() -> bool:
	return not wired_in or sig_in


func rising_edge() -> bool:
	var r := sig_in and not _prev_in
	return r


func end_signal_tick() -> void:
	_prev_in = sig_in


func dir_vec() -> Vector3:
	return Vector3(Defs.DIRS[rot])


func right_vec() -> Vector3:
	return Vector3(Defs.DIRS[posmod(rot + 1, 4)])


func local_to_world(p: Vector3) -> Vector3:
	return _xf() * p


func level_mult() -> float:
	return 1.0 + level_bonus() * level


func level_bonus() -> float:
	match kind():
		"source": return 0.2
		"seller": return 0.08
		"block", "logic", "door", "teleporter": return 0.0
	return 0.15


func belt_speed() -> float:
	return float(def.get("speed", 2.0)) * Game.belt_mult() * (level_mult() if kind() in ["belt", "ramp", "splitter", "grate"] else 1.0)


func machine_mult() -> float:
	return Game.machine_mult() * (level_mult() if kind() not in ["belt", "ramp", "splitter", "grate"] else 1.0)


func set_rot(r: int) -> void:
	if not Defs.is_directional(type_id):
		return
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
	for h in _pips:
		world.batcher.remove(h)
	_pips.clear()
	for h in _handles:
		world.batcher.remove(h)
	_handles.clear()


func upgrade_cost() -> float:
	return Game.part_upgrade_cost(type_id, level)


func can_upgrade() -> bool:
	return level_bonus() > 0.0 and level < Defs.LEVEL_MAX


func set_level(l: int) -> void:
	level = clampi(l, 0, Defs.LEVEL_MAX)
	refresh_pips()
	apply_speed()


func refresh_pips() -> void:
	if ghost or level_bonus() <= 0.0:
		return
	for h in _pips:
		world.batcher.remove(h)
	_pips.clear()
	var mesh := Meshes.box_mesh(Vector3(0.06, 0.06, 0.06))
	var m := Meshes.mat(Color("ff7ad9") if level >= Defs.LEVEL_MAX else Color("ffd23f"), 1.0, 0.3)
	for i in level:
		var local := Transform3D(Basis.IDENTITY, Vector3(-0.47, 0.36, 0.42 - i * 0.085))
		_pips.append(world.batcher.add(mesh, m, _xf() * local, local))


func set_overlay(m: Material) -> void:
	for c in find_children("*", "GeometryInstance3D", true, false):
		(c as GeometryInstance3D).material_overlay = m
		(c as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func port_out_pos() -> Vector3:
	return local_to_world(Vector3(0.25, 0.55, 0.25))


func port_in_pos() -> Vector3:
	return local_to_world(Vector3(-0.25, 0.55, 0.25))


func info_text() -> String:
	var t: String = def.name
	for l in info_lines():
		t += "\n" + String(l)
	if Defs.has_input(type_id):
		if wired_in:
			t += "\nInput: %s" % ("ON" if sig_in else "off")
		else:
			t += "\nInput: not wired (always on)"
	if Defs.has_output(type_id):
		t += "\nOutput: %s" % ("ON" if sig_out else "off")
	if level_bonus() > 0.0:
		t += "\nLevel %d / %d (x%.2f)" % [level, Defs.LEVEL_MAX, level_mult()]
		if level < Defs.LEVEL_MAX:
			t += "  -  upgrade %s" % Util.money(upgrade_cost())
	t += "\nRefund %s" % Util.money(paid)
	return t


# ------------------------------------------------------------------ geometry builders

func _vis(mesh: Mesh, m: Material, pos: Vector3, rot_deg: Vector3 = Vector3.ZERO, scl: Vector3 = Vector3.ONE) -> void:
	var b := Basis.from_euler(Vector3(deg_to_rad(rot_deg.x), deg_to_rad(rot_deg.y), deg_to_rad(rot_deg.z))).scaled(scl)
	var local := Transform3D(b, pos)
	if ghost or world == null or not world.has_method("place"):
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.material_override = m
		mi.transform = local
		add_child(mi)
	else:
		_handles.append(world.batcher.add(mesh, m, _xf() * local, local))


func _box(size: Vector3, pos: Vector3, m: Material, rot_deg: Vector3 = Vector3.ZERO) -> void:
	_vis(Meshes.box_mesh(size), m, pos, rot_deg)


func _cyl(r: float, h: float, pos: Vector3, m: Material, rot_deg: Vector3 = Vector3.ZERO, segs: int = 8, r_bottom: float = -1.0) -> void:
	_vis(Meshes.cyl_mesh(r, r if r_bottom < 0.0 else r_bottom, h, segs), m, pos, rot_deg)


## Individually animated mesh (not batched).
func _anim(mesh: Mesh, m: Material, pos: Vector3, rot_deg: Vector3 = Vector3.ZERO, parent: Node3D = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	mi.position = pos
	mi.rotation_degrees = rot_deg
	(parent if parent != null else self).add_child(mi)
	return mi


func _pivot(pos: Vector3, parent: Node3D = null) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	(parent if parent != null else self).add_child(n)
	return n


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


func _add_shape(b: CollisionObject3D, size: Vector3, pos: Vector3, rot_deg: Vector3 = Vector3.ZERO) -> CollisionShape3D:
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	cs.position = pos
	cs.rotation_degrees = rot_deg
	b.add_child(cs)
	return cs


func _make_area(size: Vector3, pos: Vector3, on_enter: Callable = Callable(), on_exit: Callable = Callable()) -> Area3D:
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
	if on_enter.is_valid():
		a.body_entered.connect(on_enter)
	if on_exit.is_valid():
		a.body_exited.connect(on_exit)
	return a


## Standard belt deck: frame + animated belt surface + physics body moving items forward.
func _deck(tint: Color, base_speed: float, with_body: bool = true) -> void:
	_box(Vector3(1.0, 0.14, 1.0), Vector3(0, 0.07, 0), Meshes.mat(DECK_COLOR))
	_box(Vector3(0.86, 0.05, 0.98), Vector3(0, 0.175, 0), Meshes.belt_mat(type_id, tint, base_speed))
	_cyl(0.05, 0.86, Vector3(0, 0.15, 0.47), Meshes.metal_mat(STEEL), Vector3(0, 0, 90), 6)
	_cyl(0.05, 0.86, Vector3(0, 0.15, -0.47), Meshes.metal_mat(STEEL), Vector3(0, 0, 90), 6)
	if with_body and not ghost:
		body = _make_body()
		_add_shape(body, Vector3(1.0, 0.2, 1.0), Vector3(0, 0.1, 0))


func _deck_speed(spd: float) -> void:
	if body != null:
		body.constant_linear_velocity = dir_vec() * spd


## Items currently overlapping an area (only active ones).
func _items_in(a: Area3D) -> Array[Item]:
	var out: Array[Item] = []
	if a == null:
		return out
	for b in a.get_overlapping_bodies():
		var it := b as Item
		if it != null and it.active:
			out.append(it)
	return out
