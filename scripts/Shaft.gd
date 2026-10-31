class_name Shaft
extends StaticBody3D
## A hole you've dug straight down. Every hit with a pickaxe (or a drill held on it) takes it deeper and throws out a
## chunk of whatever is at that depth.

var depth := 0.0
var _pit: MeshInstance3D


func setup(at: Vector3) -> void:
	collision_layer = 1
	collision_mask = 0
	global_position = at
	add_to_group("shafts")
	var stone := LowPoly.mat(Color("7d7a73"), 1.0)
	for k in 4:
		var side := [Vector3(0, 0, 0.45), Vector3(0, 0, -0.45), Vector3(0.45, 0, 0), Vector3(-0.45, 0, 0)][k] as Vector3
		var sz := Vector3(1.0, 0.16, 0.12) if k < 2 else Vector3(0.12, 0.16, 0.78)
		LowPoly.mesh_instance(self, LowPoly.box(sz), stone, side + Vector3(0, 0.06, 0))
	var pm := StandardMaterial3D.new()
	pm.albedo_color = Color("3a2c20")
	pm.roughness = 1.0
	_pit = LowPoly.mesh_instance(self, LowPoly.box(Vector3(0.78, 0.02, 0.78)), pm, Vector3(0, 0.02, 0))
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(1.0, 0.14, 1.0)
	cs.shape = sh
	cs.position.y = 0.05
	add_child(cs)
	_update()


func hint_text() -> String:
	if depth >= Mining.MAX_DEPTH:
		return "Mine shaft  ·  %d m deep  ·  as deep as it goes" % int(depth)
	return "Mine shaft  ·  %.1f m deep  ·  %s" % [depth, Mining.layer_name(depth)]


## One dig: a bit deeper, and a chunk flies out.
func dig(power: int, tier: int) -> String:
	if depth >= Mining.MAX_DEPTH:
		Sfx.play_at("clink", global_position, 0.8, -4.0)
		return ""
	depth = minf(Mining.MAX_DEPTH, depth + 0.2 * power)
	var kind := Mining.roll(global_position.x, global_position.z, depth, tier)
	var o := Ore.new()
	get_parent().add_child(o)
	o.setup(kind, randf_range(0.11, 0.16))
	o.global_position = global_position + Vector3(randf_range(-0.2, 0.2), 0.45, randf_range(-0.2, 0.2))
	o.linear_velocity = Vector3(randf_range(-1.5, 1.5), 3.0, randf_range(-1.5, 1.5))
	o.angular_velocity = Vector3(randf_range(-6, 6), randf_range(-6, 6), randf_range(-6, 6))
	Nature.burst(get_parent(), global_position + Vector3.UP * 0.2, Vector3.UP, Color("6b5a44"), 12, 2.4, 0.04, 9.0, 0.7)
	Sfx.play_at("crack" if kind != "stone" else "gravel", global_position, randf_range(0.85, 1.1), 0.0)
	_update()
	return kind


func _update() -> void:
	# the deeper it is, the darker the hole looks
	if _pit != null:
		(_pit.material_override as StandardMaterial3D).albedo_color = Color("3a2c20").lerp(Color("080604"), clampf(depth / 6.0, 0.0, 1.0))
