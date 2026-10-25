class_name Catapult
extends StaticBody3D
## A log-and-bark catapult with a leaf-rope spring. Put things in the cup and click it: the arm whips over and
## launches everything in the cup forwards (along -Z of the catapult).

const LAUNCH := Vector3(0, 7.5, -11.0)   # local launch velocity

var arm: Node3D
var cup_area: Area3D
var _busy := false


func setup_arm(p_arm: Node3D, cup_local: Vector3) -> void:
	arm = p_arm
	cup_area = Area3D.new()
	cup_area.collision_layer = 0
	cup_area.collision_mask = 2
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(0.6, 0.5, 0.6)
	cs.shape = sh
	cup_area.add_child(cs)
	cup_area.position = cup_local + Vector3(0, 0.2, 0)
	add_child(cup_area)


func hint_text() -> String:
	return "[Click] fire" if not _busy else ""


func on_click(_player: Node) -> void:
	fire()


func fire() -> void:
	if _busy or arm == null:
		return
	_busy = true
	var load := cup_area.get_overlapping_bodies().filter(func(b): return b is RigidBody3D and not (b as RigidBody3D).freeze)
	var held: Node = get_tree().get_first_node_in_group("player").get("held")
	Sfx.play("whoosh", 0.6, 2.0)
	var tw := create_tween()
	tw.tween_property(arm, "rotation_degrees:x", -105.0, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func():
		var v := global_basis * LAUNCH
		for b in load:
			if not is_instance_valid(b) or b == held:
				continue
			var rb := b as RigidBody3D
			rb.sleeping = false
			rb.linear_velocity = v + Vector3(randf_range(-0.6, 0.6), randf_range(-0.5, 0.5), randf_range(-0.6, 0.6))
			rb.angular_velocity = Vector3(randf_range(-6, 6), randf_range(-6, 6), randf_range(-6, 6))
		Sfx.play("thud", 0.8, 2.0))
	tw.tween_interval(0.4)
	tw.tween_property(arm, "rotation_degrees:x", 0.0, 1.1).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(func(): _busy = false)
