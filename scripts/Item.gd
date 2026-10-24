class_name Item
extends RigidBody3D
## A physical resource with a material, shape and real dimensions. Pooled by the world.
## shape: "box" | "cyl" (log, length along local Z) | "chunk" (irregular rock, box collider).

static var _pm: PhysicsMaterial

var mat := "oak"
var shape := "box"
var size := Vector3(0.3, 0.3, 0.3)
var purity := 1.0
var refined := false
var quality := 1.0
var heat := 0.0
var washed := false
var polished := false
var broken := false
var crate_value := 0.0
var variant := 0
var form := ""
var visited := {}
var age := 0.0
var still_time := 0.0
var active := false

var _mesh: MeshInstance3D
var _col: CollisionShape3D
var _box := BoxShape3D.new()
var _cyl := CylinderShape3D.new()
var _heat_lvl := -1


func _init() -> void:
	if _pm == null:
		_pm = PhysicsMaterial.new()
		_pm.friction = 4.0
		_pm.bounce = 0.0
	collision_layer = 0
	collision_mask = 0
	can_sleep = false
	linear_damp = 0.05
	angular_damp = 3.0
	physics_material_override = _pm
	continuous_cd = true
	_col = CollisionShape3D.new()
	add_child(_col)
	_mesh = MeshInstance3D.new()
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_mesh)
	freeze = true
	visible = false


# ---------------------------------------------------------------- lifecycle

func activate(props: Dictionary, xf: Transform3D, vel: Vector3 = Vector3.ZERO) -> void:
	mat = props.get("mat", "oak")
	shape = props.get("shape", "box")
	size = props.get("size", Vector3(0.3, 0.3, 0.3))
	purity = props.get("purity", 1.0)
	refined = props.get("refined", false)
	quality = props.get("quality", 1.0)
	heat = props.get("heat", 0.0)
	washed = props.get("washed", false)
	polished = props.get("polished", false)
	broken = props.get("broken", false)
	crate_value = props.get("crate_value", 0.0)
	variant = props.get("variant", randi() % 4)
	form = props.get("form", "")
	visited = (props.get("visited", {}) as Dictionary).duplicate()
	age = 0.0
	still_time = 0.0
	active = true
	_heat_lvl = -1
	freeze = true
	global_transform = xf
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	_apply_geometry()
	collision_layer = 2
	collision_mask = 1
	visible = true
	freeze = false
	linear_velocity = vel


func props() -> Dictionary:
	return {
		"mat": mat, "shape": shape, "size": size, "purity": purity, "refined": refined,
		"quality": quality, "heat": heat, "washed": washed, "polished": polished, "broken": broken,
		"crate_value": crate_value, "variant": variant, "form": "crate" if form == "crate" else "",
		"visited": visited,
	}


func deactivate() -> void:
	active = false
	visible = false
	collision_layer = 0
	collision_mask = 0
	freeze = true
	_mesh.material_overlay = null
	global_position = Vector3(0, -100, 0)


# ---------------------------------------------------------------- geometry

func set_geometry(p_shape: String, p_size: Vector3) -> void:
	shape = p_shape
	size = p_size
	_apply_geometry()


func _apply_geometry() -> void:
	_col.rotation = Vector3.ZERO
	match shape:
		"cyl":
			_cyl.radius = maxf(0.02, size.x * 0.5)
			_cyl.height = maxf(0.04, size.z)
			_col.shape = _cyl
			_col.rotation_degrees.x = 90.0
		"chunk":
			_box.size = (size * 0.82).max(Vector3(0.03, 0.03, 0.03))
			_col.shape = _box
		_:
			_box.size = size.max(Vector3(0.02, 0.02, 0.02))
			_col.shape = _box
	mass = clampf(volume() * 6.0, 0.05, 4.0)
	if form != "crate":
		form = classify()
	refresh_look()


func volume() -> float:
	match shape:
		"cyl": return PI * size.x * 0.5 * size.y * 0.5 * size.z
		"chunk": return 0.55 * size.x * size.y * size.z
	return size.x * size.y * size.z


func dims_sorted() -> Array:
	var d := [size.x, size.y, size.z]
	d.sort()
	return d


func max_dim() -> float:
	return maxf(size.x, maxf(size.y, size.z))


func cat() -> String:
	if form == "crate":
		return "crate"
	var c := Defs.mat_cat(mat)
	if c == "ore" and refined:
		return "metal"
	if c == "sand":
		return "glass" if refined else "sand"
	return c


func classify() -> String:
	var c := Defs.mat_cat(mat)
	var d := dims_sorted()
	if c == "wood":
		if shape == "chunk":
			return "chips"
		if shape == "cyl":
			return "log"
		if d[2] < 0.3:
			return "offcut"
		if d[0] <= 0.09:
			return "plank"
		return "timber"
	if c == "ore" or c == "sand":
		if c == "sand" and not refined:
			return "sand"
		if refined:
			if broken or d[2] < 0.12:
				return "scrap"
			if d[0] <= 0.035:
				return "sheet"
			if d[0] <= 0.07:
				return "plate"
			return "ingot"
		return "boulder" if d[2] > 0.3 else "chunk"
	# gem
	if not refined:
		return "geode"
	return "polished" if polished else "shard"


func value() -> float:
	if form == "crate":
		return crate_value
	var m: Dictionary = Defs.MATERIALS[mat]
	var v: float = float(m.price) * volume() * float(Defs.FORM_MULT.get(form, 1.0)) * quality
	if not refined and Defs.mat_cat(mat) != "wood":
		v *= purity
	if form == "scrap" and Defs.mat_cat(mat) == "sand":
		v *= 0.5
	return v


func product_key() -> String:
	return "crate" if form == "crate" else mat + ":" + form


func display_name() -> String:
	return Defs.product_name(mat, form)


# ---------------------------------------------------------------- visuals

func refresh_look() -> void:
	match shape:
		"cyl":
			_mesh.mesh = Meshes.log_mesh()
			_mesh.scale = size
			_mesh.material_override = null
			_mesh.set_surface_override_material(0, Meshes.mat((Defs.MATERIALS[mat].bark as Color), 0.0, 0.95))
			_mesh.set_surface_override_material(1, Meshes.mat((Defs.MATERIALS[mat].color as Color).lightened(0.1), 0.0, 0.9))
		"chunk":
			_mesh.mesh = Meshes.chunk_mesh(variant)
			_mesh.scale = size
			_mesh.material_override = Meshes.item_mat(self)
		_:
			_mesh.mesh = Meshes.crate_mesh() if form == "crate" else Meshes.unit_box()
			_mesh.scale = size
			_mesh.material_override = Meshes.item_mat(self)
	_update_heat_look()


func set_heat(h: float) -> void:
	heat = clampf(h, 0.0, 1.0)
	_update_heat_look()


func _update_heat_look() -> void:
	var lvl := 0
	if heat > 0.75:
		lvl = 3
	elif heat > 0.5:
		lvl = 2
	elif heat > 0.25:
		lvl = 1
	if lvl == _heat_lvl:
		return
	_heat_lvl = lvl
	_mesh.material_overlay = Meshes.heat_overlay(lvl) if lvl > 0 else null


func mark(machine_uid: int) -> bool:
	## Returns true the first time a given machine processes this item.
	if visited.has(machine_uid):
		return false
	visited[machine_uid] = true
	return true
