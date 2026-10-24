class_name Item
extends RigidBody3D
## A physical resource item. Pooled by the world; never freed during play.

const SIZE := 0.28

static var _shape: BoxShape3D
static var _pm: PhysicsMaterial

var kind := ""
var value := 1.0
var passes := 0
var visited := {}
var age := 0.0
var still_time := 0.0
var active := false

var _mesh: MeshInstance3D
var _col: CollisionShape3D


func _init() -> void:
	if _shape == null:
		_shape = BoxShape3D.new()
		_shape.size = Vector3(SIZE, SIZE, SIZE)
		_pm = PhysicsMaterial.new()
		_pm.friction = 4.0
		_pm.bounce = 0.0
	collision_layer = 0
	collision_mask = 0
	mass = 0.2
	can_sleep = false
	linear_damp = 0.05
	angular_damp = 4.0
	physics_material_override = _pm
	continuous_cd = true
	_col = CollisionShape3D.new()
	_col.shape = _shape
	add_child(_col)
	_mesh = MeshInstance3D.new()
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_mesh)
	freeze = true
	visible = false


func activate(p_kind: String, p_value: float, pos: Vector3) -> void:
	kind = p_kind
	value = p_value
	passes = 0
	visited.clear()
	age = 0.0
	still_time = 0.0
	active = true
	_mesh.mesh = Meshes.item_mesh(kind)
	_mesh.scale = Vector3.ONE
	_mesh.material_override = Meshes.item_mat(kind, 0)
	freeze = true
	global_position = pos
	rotation = Vector3(randf() * TAU, randf() * TAU, randf() * TAU)
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	collision_layer = 2
	collision_mask = 1
	visible = true
	freeze = false


func deactivate() -> void:
	active = false
	visible = false
	collision_layer = 0
	collision_mask = 0
	freeze = true
	global_position = Vector3(0, -100, 0)


func apply_pass(part_id: int, mult: float) -> void:
	if visited.has(part_id):
		return
	visited[part_id] = true
	value *= mult
	passes += 1
	var tier := clampi(passes, 0, 3)
	_mesh.material_override = Meshes.item_mat(kind, tier)
	_mesh.scale = Vector3.ONE * (1.0 + 0.08 * tier)
