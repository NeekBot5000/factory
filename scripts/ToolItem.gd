class_name ToolItem
extends RigidBody3D
## A tool you dropped (Q). It lies around as a physical object until you pick it back up with E.

var tool := ""


func setup(p_tool: String) -> void:
	tool = p_tool
	collision_layer = 2
	collision_mask = 1 | 2
	mass = 1.2
	angular_damp = 0.8
	var holder := Node3D.new()
	add_child(holder)
	var model := Tools.build_model(tool, holder)
	for m in model.find_children("*", "MeshInstance3D", true, false):
		(m as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	var aabb := AABB()
	var first := true
	for m in model.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		var a: AABB = mi.transform * mi.get_aabb()
		aabb = a if first else aabb.merge(a)
		first = false
	holder.position = -aabb.get_center()
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = aabb.size.max(Vector3.ONE * 0.04)
	cs.shape = sh
	add_child(cs)
	add_to_group("tool_items")


func hint_text() -> String:
	return "[E] take"


func on_use(player: Node) -> void:
	Game.set_dropped(tool, false)
	player.call("equip", tool)
	Sfx.play("pickup")
	queue_free()
