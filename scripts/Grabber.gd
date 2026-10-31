class_name Grabber
extends Machine
## A swinging arm: while powered, it picks up whatever is in the grid square in front of it and drops it in the
## square behind. Use it to feed machines, move things between belts, or load the truck.

const EVERY := 1.1

var _cd := 0.0
var _arm: Node3D
var _carry: RigidBody3D = null


func activate(p_size: float) -> void:
	super(p_size)
	_arm = get_node_or_null("Model/Arm")
	add_lamp(Vector3(0.3, 0.2, 0.3))


func terminal() -> Vector3:
	return Vector3(0.3, 0.3, 0.3) * size


func hint_text() -> String:
	return "Grabber Arm  ·  moves things from in front (the arrow's tail) to behind it, while powered"


func _physics_process(delta: float) -> void:
	_cd -= delta
	if not powered or _cd > 0.0 or _carry != null:
		return
	for b in bodies_in(Vector3(0, 0.5, -1.0), Vector3(0.9, 1.0, 0.9)):
		var rb := b as RigidBody3D
		if rb == null or rb.is_in_group("baskets") or (rb is Log and (rb as Log).length > 2.2):
			continue
		_cd = EVERY
		_swing(rb)
		return


func _swing(rb: RigidBody3D) -> void:
	_carry = rb
	rb.freeze = true
	var from := rb.global_position
	var to := global_transform * Vector3(0, 0.75, 1.0)
	var top := global_transform * Vector3(0, 1.6, 0)
	var tw := create_tween()
	tw.tween_method(func(k: float):
		if not is_instance_valid(rb):
			return
		var a := from.lerp(top, k)
		var b := top.lerp(to, k)
		rb.global_position = a.lerp(b, k)
		if _arm != null:
			_arm.rotation.x = lerpf(0.0, PI, k), 0.0, 1.0, 0.55).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(func():
		if is_instance_valid(rb):
			rb.freeze = false
			rb.linear_velocity = Vector3.ZERO
		_carry = null
		Sfx.play_at("click", global_position, 0.8, -8.0))
	if _arm != null:
		tw.tween_property(_arm, "rotation:x", 0.0, 0.35)
	Sfx.play_at("hiss", global_position, 1.5, -12.0)
