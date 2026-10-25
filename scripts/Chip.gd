class_name Chip
extends RigidBody3D
## A physical sheet of bark (outer or inner layer), made of one or more panels torn off a tree in one hit.

const PANEL_VALUE := {"outer": 0.6, "inner": 1.0}

var layer := 0
var kind := "oak"
var size := Vector3.ONE * 0.1
var panels := 1
var value := 0.0
var color := Color("5b4030")
var src := {}               # where it came from (to rebuild it from a save)
var panel_list: Array = []
var value_mult := 1.0


func setup(data: Dictionary, p_kind: String) -> void:
	layer = data.layer
	kind = p_kind
	size = data.size
	panels = int(data.get("panels", 1))
	color = data.get("color", color)
	src = data.get("src", {})
	panel_list = data.get("panel_list", [])
	value_mult = float(data.get("value_mult", 1.0))
	var per: float = PANEL_VALUE.outer if layer == 0 else PANEL_VALUE.inner
	if kind == "birch" and layer == 0:
		per *= 1.6
	value = per * panels * float(data.get("value_mult", 1.0))
	collision_layer = 2
	collision_mask = 1 | 2
	mass = clampf(size.x * size.y * size.z * 600.0, 0.03, 4.0)
	linear_damp = 0.2
	angular_damp = 0.8
	continuous_cd = true
	var pm := PhysicsMaterial.new()
	pm.friction = 0.9
	pm.bounce = 0.1
	physics_material_override = pm
	var mi := MeshInstance3D.new()
	mi.mesh = data.mesh
	mi.material_override = LowPoly.vcol_mat(0.95)
	add_child(mi)
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size.max(Vector3(0.02, 0.02, 0.02))
	cs.shape = sh
	cs.position = data.get("box_center", Vector3.ZERO)
	add_child(cs)
	add_to_group("grabbable")
	add_to_group("chips")


func display_name() -> String:
	var what := "%s bark" % kind.capitalize() if layer == 0 else "%s inner bark" % kind.capitalize()
	if panels > 1:
		what += " sheet"
	return "%s ($%.2f)" % [what, value]
