class_name Builder
extends Node
## The hammer's build mode. Click with the hammer to open the build menu, pick something, then a hologram follows
## your aim: scroll to make it bigger or smaller (bigger costs more), click to set it down (the hoop then takes its
## height from where you look - click again to lock it in). The placed plan becomes a Blueprint that you fill by
## dropping materials into it.

const REACH := 9.0

var player: Player
var main: Node
var build_id := "basket"
var size_i := 2               # index into Builds.SIZES (1.0x)
var state := "idle"           # idle | place | height
var _holo: Node3D
var _holo_parts: Array = []
var _holo_label: Label3D
var _holo_h := Builds.HOOP_DEFAULT
var _valid := false
var _base := Transform3D.IDENTITY
var _ok_mat: StandardMaterial3D
var _bad_mat: StandardMaterial3D


func setup(p: Player, m: Node) -> void:
	player = p
	main = m
	_ok_mat = Blueprint.ghost_mat(true)
	_bad_mat = Blueprint.ghost_mat(false)


func current() -> String:
	return build_id


func size() -> float:
	return Builds.SIZES[size_i]


## Hammer click when nothing is being placed: open the build menu.
func click() -> void:
	match state:
		"idle":
			main.call("open_build_menu")
		"place":
			if not _valid:
				Sfx.play("thud", 1.4, -6.0)
				return
			_base = _holo.global_transform
			if build_id == "hoop":
				state = "height"
				Sfx.play("click")
			else:
				_confirm()
		"height":
			_confirm()


## Picked from the menu: start placing it.
func start(id: String) -> void:
	build_id = id
	size_i = Builds.SIZES.find(1.0)
	state = "place"
	_holo_h = Builds.HOOP_DEFAULT
	_make_holo()
	Sfx.play("click")


## Mouse wheel while placing: resize.
func scroll(step: int) -> void:
	if state != "place":
		return
	var ni := clampi(size_i - step, 0, Builds.SIZES.size() - 1)
	if ni != size_i:
		size_i = ni
		Sfx.play("click", 0.8 + size() * 0.15)
		var keep := _holo.global_transform
		_make_holo()
		_holo.global_transform = keep


func cancel() -> void:
	if _holo != null:
		_holo.queue_free()
		_holo = null
	state = "idle"


func busy() -> bool:
	return state != "idle"


func hint_text() -> String:
	match state:
		"place":
			return "Size %sx    [Scroll] size    [Click] place    [E] cancel" % str(size())
		"height":
			return "Look up / down for height    [Click] build    [E] cancel"
	return ""


func _make_holo() -> void:
	if _holo != null:
		_holo.queue_free()
	_holo = Node3D.new()
	main.add_child(_holo)
	_holo_parts = Builds.make(build_id, _holo, _holo_h, size())
	var top := 0.5
	for p in _holo_parts:
		var mi := p.mi as MeshInstance3D
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		top = maxf(top, (mi.get_parent() as Node3D).scale.y * (mi.position.y + mi.get_aabb().end.y))
	_holo_label = Blueprint.make_label()
	_holo_label.text = Builds.needs_text(build_id, size()).replace("  +  ", "  ·  ")
	_holo_label.position = Vector3(0, top + 0.35, 0)
	_holo.add_child(_holo_label)
	_paint(true)


func _paint(ok: bool) -> void:
	for p in _holo_parts:
		(p.mi as MeshInstance3D).material_override = _ok_mat if ok else _bad_mat


func _confirm() -> void:
	var bp := Blueprint.new()
	main.add_child(bp)
	bp.global_transform = _holo.global_transform
	bp.setup(build_id, _holo_h, main, size())
	cancel()
	player.start_swing()
	Sfx.play("thud", 1.6)


func update(_delta: float) -> void:
	if state == "idle" or _holo == null:
		return
	var cam := player.cam
	var fwd := -cam.global_transform.basis.z
	var flat := Vector3(fwd.x, 0, fwd.z)
	flat = flat.normalized() if flat.length() > 0.01 else Vector3.FORWARD
	if state == "place":
		var from := cam.global_position
		var q := PhysicsRayQueryParameters3D.create(from, from + fwd * REACH * maxf(1.0, size()), 1)
		q.exclude = [player.get_rid()]
		var hit := player.get_world_3d().direct_space_state.intersect_ray(q)
		# look through loose logs and other moving things to the ground underneath
		for k in 4:
			if hit.is_empty() or not (hit.collider is RigidBody3D):
				break
			q.exclude = q.exclude + [hit.rid]
			hit = player.get_world_3d().direct_space_state.intersect_ray(q)
		var pos := from + fwd * 4.0
		_valid = false
		if not hit.is_empty():
			pos = hit.position
			_valid = (hit.normal as Vector3).y > 0.75 and not (hit.collider is ForestTree) and not (hit.collider is Truck)
		else:
			pos.y = main.terrain.height_at(pos.x, pos.z)
		# front of the build faces you
		_holo.global_transform = Transform3D(Basis.looking_at(flat, Vector3.UP), pos)
		_paint(_valid)
	elif state == "height":
		# rim height = where your view ray crosses the vertical plane through the hoop
		var n := -flat
		var o := cam.global_position
		var denom := fwd.dot(n)
		var h := _holo_h
		if absf(denom) > 0.001:
			var t := (_base.origin - o).dot(n) / denom
			if t > 0.0:
				h = clampf((o + fwd * t).y - _base.origin.y, Builds.HOOP_MIN * size(), Builds.HOOP_MAX * size())
		if absf(h - _holo_h) > 0.04:
			_holo_h = snappedf(h, 0.05)
			var keep := _base
			_make_holo()
			_holo.global_transform = keep
