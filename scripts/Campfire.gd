class_name Campfire
extends StaticBody3D
## A crackling fire. Anything dropped on it burns away (logs take a while) - and its value goes up in smoke.

const BURN_TIME := {"log": 7.0, "chip": 1.8, "leaf": 0.9, "other": 3.0}

var _flames: Array[MeshInstance3D] = []
var _light: OmniLight3D
var _area: Area3D
var _burning := {}          # body -> [seconds left, total]
var _t := 0.0
var _crackle := 0.0


func light_up() -> void:
	var fire := LowPoly.mat(Color("ff8a2b"), 0.5, 2.5)
	var core := LowPoly.mat(Color("ffd36a"), 0.5, 3.0)
	for k in 5:
		var a := TAU * k / 5.0
		var mi := LowPoly.mesh_instance(self, LowPoly.cyl(0.0, 0.09, 0.45, 5), fire, Vector3(cos(a) * 0.1, 0.35, sin(a) * 0.1))
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_flames.append(mi)
	var c := LowPoly.mesh_instance(self, LowPoly.cyl(0.0, 0.1, 0.35, 5), core, Vector3(0, 0.3, 0))
	c.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_flames.append(c)
	_light = OmniLight3D.new()
	_light.light_color = Color("ffa04a")
	_light.light_energy = 1.6
	_light.omni_range = 5.0
	_light.position = Vector3(0, 0.6, 0)
	add_child(_light)
	var smoke := Nature.Smoke.new()
	smoke.position = Vector3(0, 0.7, 0)
	smoke.scale = Vector3.ONE * 0.6
	add_child(smoke)
	_area = Area3D.new()
	_area.collision_layer = 0
	_area.collision_mask = 2
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(0.9, 0.7, 0.9)
	cs.shape = sh
	cs.position = Vector3(0, 0.45, 0)
	_area.add_child(cs)
	add_child(_area)


func _physics_process(delta: float) -> void:
	if _area == null:
		return
	_t += delta
	for i in _flames.size():
		var f := _flames[i]
		f.scale = Vector3(1.0, 0.8 + 0.35 * sin(_t * (9.0 + i) + i * 1.7) + randf() * 0.15, 1.0)
	_light.light_energy = 1.4 + sin(_t * 13.0) * 0.2 + randf() * 0.25
	_crackle -= delta
	if _crackle <= 0.0:
		_crackle = randf_range(0.25, 0.9)
		Sfx.play("chop_wood", randf_range(1.6, 2.4), -16.0)
		Nature.burst(get_parent(), global_position + Vector3(0, 0.5, 0), Vector3.UP, Color("ffb347"), 3, 1.5, 0.015, -0.5, 0.8, 30.0, 3.0)
	for b in _area.get_overlapping_bodies():
		if not (b is RigidBody3D) or (b as RigidBody3D).freeze or _burning.has(b) or b.is_in_group("tool_items"):
			continue
		var kind := "other"
		if b is Log:
			kind = "log"
		elif b is Chip:
			kind = "chip"
		elif b is Leaf:
			kind = "leaf"
		_burning[b] = [BURN_TIME[kind], BURN_TIME[kind]]
	for b in _burning.keys():
		if not is_instance_valid(b):
			_burning.erase(b)
			continue
		var body := b as Node3D
		if body.global_position.distance_to(global_position + Vector3(0, 0.4, 0)) > 1.2:
			_burning.erase(b)          # pulled out of the fire in time
			continue
		var st: Array = _burning[b]
		st[0] = float(st[0]) - delta
		# it chars and shrinks as it burns
		var k := clampf(float(st[0]) / float(st[1]), 0.0, 1.0)
		for c in body.get_children():
			if c is Node3D and not (c is CollisionShape3D):
				(c as Node3D).scale = Vector3.ONE * lerpf(0.35, 1.0, k)
		if randf() < delta * 6.0:
			Nature.burst(get_parent(), body.global_position, Vector3.UP, Color("ff8a2b"), 2, 1.2, 0.02, -1.0, 0.6, 40.0, 2.5)
		if float(st[0]) <= 0.0:
			Nature.burst(get_parent(), body.global_position, Vector3.UP, Color("3a3a3a"), 14, 1.2, 0.04, -0.3, 1.4, 120.0)
			Nature.burst(get_parent(), body.global_position, Vector3.UP, Color("ffb347"), 10, 2.0, 0.02, 2.0, 0.6, 90.0, 3.0)
			Sfx.play("rustle", 0.5, -6.0)
			var main := get_parent()
			if b is Chip and "chips" in main:
				main.chips.erase(b)
			body.queue_free()
			_burning.erase(b)
