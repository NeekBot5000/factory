class_name DeliveryBox
extends RigidBody3D
## A TimberMart cardboard box. Its sides carry a bordered outline drawing of what's inside.
## Left click it to open it: the tape tears, the flaps swing open, the item rises out and the box folds flat.

const SIZE := Vector3(0.7, 0.5, 0.7)

var item := ""
var opened := false
var main: Node
var _flaps: Array[Node3D] = []
var _sides: Array[Node3D] = []
var _visual: Node3D


func setup(p_item: String, p_main: Node, art: Texture2D) -> void:
	item = p_item
	main = p_main
	collision_layer = 2
	collision_mask = 1 | 2
	mass = 3.0
	add_to_group("grabbable")
	var pm := PhysicsMaterial.new()
	pm.friction = 1.0
	physics_material_override = pm
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = SIZE
	cs.shape = sh
	add_child(cs)
	_visual = Node3D.new()
	add_child(_visual)
	var card := LowPoly.mat(Color("c79a62"), 1.0)
	var card_dark := LowPoly.mat(Color("a87d4a"), 1.0)
	var h := SIZE * 0.5
	# bottom + four sides, each hinged at the bottom edge so they can fold outward
	LowPoly.mesh_instance(_visual, LowPoly.box(Vector3(SIZE.x, 0.02, SIZE.z)), card_dark, Vector3(0, -h.y + 0.01, 0))
	var side_defs := [[Vector3(0, -h.y, h.z), 0.0], [Vector3(0, -h.y, -h.z), 180.0], [Vector3(h.x, -h.y, 0), 90.0], [Vector3(-h.x, -h.y, 0), -90.0]]
	for sd in side_defs:
		var pivot := Node3D.new()
		pivot.position = sd[0]
		pivot.rotation_degrees.y = sd[1]
		_visual.add_child(pivot)
		var w: float = SIZE.x
		LowPoly.mesh_instance(pivot, LowPoly.box(Vector3(w, SIZE.y, 0.02)), card, Vector3(0, h.y, -0.01))
		if art != null:
			var decal := MeshInstance3D.new()
			var q := QuadMesh.new()
			q.size = Vector2(w * 0.86, SIZE.y * 0.86)
			decal.mesh = q
			var dm := StandardMaterial3D.new()
			dm.albedo_texture = art
			dm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			dm.roughness = 1.0
			decal.material_override = dm
			decal.position = Vector3(0, h.y, 0.002)
			pivot.add_child(decal)
		_sides.append(pivot)
	# top flaps hinged on the top edges
	for s in [-1, 1]:
		var fp := Node3D.new()
		fp.position = Vector3(s * h.x, h.y, 0)
		_visual.add_child(fp)
		LowPoly.mesh_instance(fp, LowPoly.box(Vector3(h.x, 0.02, SIZE.z)), card, Vector3(-s * h.x * 0.5, 0.0, 0))
		_flaps.append(fp)
	# packing tape across the seam
	var tape := LowPoly.mesh_instance(_visual, LowPoly.box(Vector3(0.1, 0.025, SIZE.z + 0.02)), LowPoly.mat(Color("d9c48f"), 0.4), Vector3(0, h.y + 0.004, 0))
	tape.name = "Tape"
	var lbl := Label3D.new()
	lbl.text = "TimberMart"
	lbl.font_size = 40
	lbl.pixel_size = 0.003
	lbl.modulate = Color("8a3b1c")
	lbl.rotation_degrees.x = -90
	lbl.position = Vector3(0, h.y + 0.02, h.z * 0.6)
	_visual.add_child(lbl)


func display_name() -> String:
	return "TimberMart box (%s)" % Tools.SHOP[item].name


func hint_text() -> String:
	if opened:
		return ""
	return "TimberMart box: %s    [Left click] open    [E] carry" % Tools.SHOP[item].name


func on_click(_player: Node) -> void:
	open()


func open() -> void:
	if opened:
		return
	opened = true
	remove_from_group("grabbable")
	if main.player.held == self:
		main.player.drop_held()
	# settle upright, then animate
	freeze = true
	var up := Transform3D(Basis(Vector3.UP, global_basis.get_euler().y), global_position)
	var tw := create_tween()
	tw.tween_property(self, "global_transform", up, 0.25).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(func():
		Sfx.play("rip")
		var tape: Node3D = _visual.get_node("Tape")
		var tt := tape.create_tween()
		tt.tween_property(tape, "scale", Vector3(1, 1, 0.01), 0.2))
	tw.tween_interval(0.15)
	tw.set_parallel(true)
	tw.tween_property(_flaps[0], "rotation_degrees:z", -120.0, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_flaps[1], "rotation_degrees:z", 120.0, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(0.08)
	tw.set_parallel(false)
	tw.tween_callback(_reveal)


func _reveal() -> void:
	var pick := ItemPickup.new()
	main.add_child(pick)
	pick.setup(item)
	pick.global_position = global_position + Vector3(0, -0.1, 0)
	pick.rise_from_box(global_position + Vector3(0, 0.75, 0))
	var burst := CPUParticles3D.new()
	burst.one_shot = true
	burst.explosiveness = 0.9
	burst.amount = 30
	burst.lifetime = 0.9
	burst.mesh = LowPoly.box(Vector3(0.03, 0.03, 0.005))
	burst.material_override = LowPoly.mat(Color("ffe08a"), 0.4, 1.5)
	burst.direction = Vector3.UP
	burst.spread = 50.0
	burst.initial_velocity_min = 1.5
	burst.initial_velocity_max = 3.0
	burst.gravity = Vector3(0, -4, 0)
	main.add_child(burst)
	burst.global_position = global_position + Vector3(0, 0.3, 0)
	burst.emitting = true
	Sfx.play("reveal")
	# fold the sides down flat, then shrink the empty box away
	var tw := create_tween()
	tw.tween_interval(0.5)
	tw.set_parallel(true)
	for i in _sides.size():
		tw.tween_property(_sides[i], "rotation_degrees:x", 88.0, 0.4).set_delay(i * 0.06).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	for f in _flaps:
		tw.tween_property(f, "scale", Vector3(0.01, 1, 1), 0.3).set_delay(0.1)
	tw.set_parallel(false)
	tw.tween_interval(1.2)
	tw.tween_property(_visual, "scale", Vector3(0.01, 0.01, 0.01), 0.4)
	tw.tween_callback(func():
		burst.queue_free()
		queue_free())
