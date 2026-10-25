class_name Blueprint
extends StaticBody3D
## A placed build waiting for materials: a see-through hologram of the finished thing. Drop bark / logs into it
## and each one flies into its spot and that part turns solid. E cancels and everything you put in drops out.

const LAYER := 64

var id := ""
var height := Builds.HOOP_DEFAULT
var needs := {}
var have := {}
var _parts: Array = []
var _filled: Array = []          # per part: Color or null
var _stored: Array = []          # bodies swallowed so far (hidden, frozen) so cancel can give them back
var _area: Area3D
var _main: Node
var _t := 0.0

static var _ghost: StandardMaterial3D
static var _ghost_edge: StandardMaterial3D


static func ghost_mat(valid: bool = true) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(0.45, 0.85, 1.0, 0.32) if valid else Color(1.0, 0.35, 0.3, 0.32)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


func setup(p_id: String, p_height: float, main: Node) -> void:
	id = p_id
	height = p_height
	_main = main
	needs = (Builds.BUILDS[id].needs as Dictionary).duplicate()
	for r in needs:
		have[r] = 0
	collision_layer = LAYER
	collision_mask = 0
	if _ghost == null:
		_ghost = ghost_mat(true)
	_parts = Builds.make(id, self, height)
	var aabb := AABB()
	var first := true
	for p in _parts:
		var mi: MeshInstance3D = p.mi
		mi.material_override = _ghost
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_filled.append(null)
		var a: AABB = mi.transform * mi.get_aabb()
		aabb = a if first else aabb.merge(a)
		first = false
	# something to look at (E cancels) and a generous drop zone around the hologram
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = aabb.size.max(Vector3.ONE * 0.3)
	cs.shape = sh
	cs.position = aabb.get_center()
	add_child(cs)
	_area = Area3D.new()
	_area.collision_layer = 0
	_area.collision_mask = 2
	var acs := CollisionShape3D.new()
	var ash := BoxShape3D.new()
	ash.size = aabb.size + Vector3(0.5, 0.4, 0.5)
	acs.shape = ash
	acs.position = aabb.get_center()
	_area.add_child(acs)
	add_child(_area)
	add_to_group("blueprints")


func hint_text() -> String:
	var bits: Array[String] = []
	for r in needs:
		bits.append("%d/%d %s" % [have[r], needs[r], Builds.RES_NAME[r]])
	return "   ".join(bits) + "      [E] cancel"


func on_use(_player: Node) -> void:
	cancel()


func _physics_process(delta: float) -> void:
	_t += delta
	# gentle shimmer on the hologram
	_ghost.albedo_color.a = 0.26 + sin(_t * 3.0) * 0.06
	var held: Node = _main.player.held if _main != null else null
	for b in _area.get_overlapping_bodies():
		if b == held or not (b is RigidBody3D) or (b as RigidBody3D).freeze:
			continue
		var r := Builds.resource_of(b)
		if r.is_empty() or not needs.has(r.res) or int(have[r.res]) >= int(needs[r.res]):
			continue
		_absorb(b as RigidBody3D, r)
		if _done():
			_complete()
			return


func _absorb(b: RigidBody3D, r: Dictionary) -> void:
	var take := mini(int(r.amount), int(needs[r.res]) - int(have[r.res]))
	have[r.res] = int(have[r.res]) + take
	# parts fill in proportion: with 50 bark and 16 bark parts, a part turns solid every ~3 bark
	var idx: Array[int] = []
	var filled := 0
	for p_i in _parts.size():
		if _parts[p_i].res == r.res:
			idx.append(p_i)
			if _filled[p_i] != null:
				filled += 1
	var should := idx.size() if int(have[r.res]) >= int(needs[r.res]) else int(floor(float(have[r.res]) * idx.size() / float(needs[r.res])))
	var target := global_position
	for p_i in idx:
		if filled >= should:
			break
		if _filled[p_i] == null:
			_filled[p_i] = r.color
			var mi: MeshInstance3D = _parts[p_i].mi
			target = mi.global_position
			mi.material_override = LowPoly.mat(r.color, 0.9)
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			var tw := mi.create_tween()
			mi.scale = Vector3.ONE * 1.25
			tw.tween_property(mi, "scale", Vector3.ONE, 0.2).set_trans(Tween.TRANS_BACK)
			filled += 1
	# the material flies into place and disappears into the build
	b.freeze = true
	b.set_meta("bp_layer", b.collision_layer)
	b.collision_layer = 0
	b.collision_mask = 0
	b.set_meta("bp_grab", b.is_in_group("grabbable"))
	b.remove_from_group("grabbable")
	if _main != null and b is Chip:
		_main.chips.erase(b)
	_stored.append(b)
	var tw2 := b.create_tween()
	tw2.tween_property(b, "global_position", target, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw2.tween_callback(func(): b.visible = false)
	Sfx.play("pickup", 0.8)


func _done() -> bool:
	for r in needs:
		if int(have[r]) < int(needs[r]):
			return false
	return true


func _complete() -> void:
	var colors: Array = []
	for p_i in _parts.size():
		if _parts[p_i].res != "":
			colors.append(_filled[p_i] if _filled[p_i] != null else (_parts[p_i].real as StandardMaterial3D).albedo_color)
	var world := get_parent()
	var obj := Builds.finish(id, world, global_transform, height, colors)
	for b in _stored:
		if is_instance_valid(b):
			b.queue_free()
	_stored.clear()
	Nature.burst(world, global_position + Vector3.UP * 0.5, Vector3.UP, Color("ffe08a"), 30, 2.5, 0.04, 4.0, 1.0, 120.0, 1.5)
	Sfx.play("reveal")
	Game.toast.emit(Builds.BUILDS[id].name, Color("7aff9a"))
	# a little pop as it becomes real
	obj.scale = Vector3.ONE * 0.9
	var tw := obj.create_tween()
	tw.tween_property(obj, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_BACK)
	queue_free()


## Gives back everything that was put in: it all tumbles out of the hologram.
func cancel() -> void:
	var c := global_position + Vector3.UP * 0.6
	for b in _stored:
		if not is_instance_valid(b):
			continue
		var rb := b as RigidBody3D
		rb.visible = true
		rb.global_position = c + Vector3(randf_range(-0.4, 0.4), randf_range(0.0, 0.5), randf_range(-0.4, 0.4))
		rb.collision_layer = int(rb.get_meta("bp_layer", 2))
		rb.collision_mask = 1 | 2
		if bool(rb.get_meta("bp_grab", true)):
			rb.add_to_group("grabbable")
		rb.freeze = false
		rb.linear_velocity = Vector3(randf_range(-1.5, 1.5), randf_range(1.5, 3.0), randf_range(-1.5, 1.5))
		if _main != null and rb is Chip:
			_main.chips.append(rb)
	_stored.clear()
	Nature.burst(get_parent(), c, Vector3.UP, Color(0.45, 0.85, 1.0), 20, 2.0, 0.03, 3.0, 0.8, 140.0, 1.0)
	Sfx.play("drop", 0.8)
	queue_free()
