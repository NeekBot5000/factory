class_name Rock
extends StaticBody3D
## A boulder. Hitting it kicks up dust and stone chips; metal tools also throw sparks.

var _color := Color("8a8780")


func build(rng: RandomNumberGenerator, s: float) -> void:
	collision_layer = 1
	collision_mask = 0
	_color = Color("8a8780").lerp(Color("a39f95"), rng.randf())
	LowPoly.mesh_instance(self, LowPoly.blob(1.0, 0.3, rng.randi() % 40), LowPoly.mat(_color, 1.0), Vector3.ZERO, Vector3(0, rng.randf() * 360.0, 0), Vector3(s * 1.3, s * 0.7, s))
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(s * 2.0, s * 0.9, s * 1.6)
	cs.shape = sh
	add_child(cs)


func hint_text() -> String:
	return "Rock"


func on_hit(pos: Vector3, normal: Vector3, tool: String) -> void:
	var parent := get_parent()
	Nature.burst(parent, pos, normal, _color.darkened(0.15), 14, 2.8, 0.05, 9.0, 0.8, 55.0)
	Nature.burst(parent, pos, normal + Vector3.UP, Color("d8d2c4"), 18, 1.0, 0.07, -0.5, 1.2, 80.0)   # dust drifting up
	if tool == "hands":
		Sfx.play("thud", 1.3, -2.0)
	else:
		Nature.burst(parent, pos, normal, Color("ffd36a"), 12, 4.5, 0.015, 6.0, 0.35, 40.0, 3.0)  # sparks
		Sfx.play("clink", randf_range(0.9, 1.15))
