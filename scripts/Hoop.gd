class_name Hoop
extends StaticBody3D
## A built basketball hoop. Drop the ball through the rim and it celebrates: the net whips, the rim flashes gold,
## confetti bursts out and a ring of light ripples away from the rim. Baskets in a row count up a streak.

var net_parts: Array[MeshInstance3D] = []
var rim_parts: Array[MeshInstance3D] = []
var rim_center := Vector3.ZERO      # local
var scale_hint := 1.0
var _streak := 0
var _last_score := -100.0
var _gold: StandardMaterial3D


func score(ball: RigidBody3D) -> void:
	var now := Time.get_ticks_msec() * 0.001
	if now - _last_score < 0.6:
		return           # same shot bouncing around in the net
	_streak = _streak + 1 if now - _last_score < 12.0 else 1
	_last_score = now
	var c := global_transform * (rim_center * scale_hint)
	ball.linear_velocity *= 0.45          # the net catches it
	ball.angular_velocity *= 0.3
	_whip_net()
	_flash_rim()
	_ripple(c)
	var world := get_parent()
	for col in [Color("ffcf6a"), Color("ff6b6b"), Color("4fc3ff"), Color("7aff9a"), Color("d06ad6")]:
		Nature.burst(world, c, Vector3.UP, col, 10 + _streak * 2, 3.2, 0.035 * scale_hint, 5.0, 1.4, 70.0, 1.5)
	Nature.burst(world, c + Vector3(0, -0.2, 0) * scale_hint, Vector3.DOWN, Color("f2efe6"), 12, 1.5, 0.02, 2.0, 0.8, 50.0)
	Sfx.play("reveal", 1.0 + minf(_streak, 6) * 0.08)
	get_tree().create_timer(0.12).timeout.connect(func(): Sfx.play("buy", 1.2, -4.0))
	Game.toast.emit("Swish!" if _streak < 2 else "Swish!  x%d" % _streak, Color("ffcf6a"))


## The net strips stretch down and swing, then settle.
func _whip_net() -> void:
	for i in net_parts.size():
		var n := net_parts[i]
		if not is_instance_valid(n):
			continue
		var base_rot := n.rotation
		var tw := n.create_tween()
		tw.tween_property(n, "scale", Vector3(1.0, 1.7, 1.0), 0.08).set_trans(Tween.TRANS_QUAD)
		tw.parallel().tween_property(n, "rotation", base_rot * 0.2, 0.08)
		tw.tween_property(n, "scale", Vector3(1.0, 0.85, 1.0), 0.12)
		tw.parallel().tween_property(n, "rotation", base_rot * 1.8, 0.12)
		tw.tween_property(n, "scale", Vector3.ONE, 0.35).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(n, "rotation", base_rot, 0.35).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


## Rim lights up gold and gives a little shake.
func _flash_rim() -> void:
	if _gold == null:
		_gold = StandardMaterial3D.new()
		_gold.albedo_color = Color("ffd36a")
		_gold.emission_enabled = true
		_gold.emission = Color("ffb347")
	_gold.emission_energy_multiplier = 3.0
	var keep: Array = []
	for r in rim_parts:
		keep.append(r.material_override)
		r.material_override = _gold
	var tw := create_tween()
	tw.tween_property(_gold, "emission_energy_multiplier", 0.0, 0.6)
	tw.tween_callback(func():
		for i in rim_parts.size():
			if is_instance_valid(rim_parts[i]):
				rim_parts[i].material_override = keep[i])
	var model := get_node_or_null("Model") as Node3D
	if model != null:
		var tw2 := create_tween()
		for k in 4:
			tw2.tween_property(model, "rotation:x", deg_to_rad(1.2) * pow(0.5, k) * (1.0 if k % 2 == 0 else -1.0), 0.05)
		tw2.tween_property(model, "rotation:x", 0.0, 0.08)


## A ring of light that ripples outward from the rim and fades.
func _ripple(c: Vector3) -> void:
	var ring := Node3D.new()
	get_parent().add_child(ring)
	ring.global_position = c
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(1.0, 0.85, 0.4, 0.9)
	var n := 20
	for i in n:
		var a := TAU * i / n
		var mi := MeshInstance3D.new()
		mi.mesh = LowPoly.box(Vector3(0.06, 0.02, 0.09) * scale_hint)
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.position = Vector3(cos(a), 0, sin(a)) * 0.24 * scale_hint
		mi.rotation.y = -a
		ring.add_child(mi)
	var tw := ring.create_tween()
	tw.tween_property(ring, "scale", Vector3.ONE * 5.0, 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(m, "albedo_color:a", 0.0, 0.7)
	tw.tween_callback(ring.queue_free)
