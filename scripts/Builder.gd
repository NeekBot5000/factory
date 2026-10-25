class_name Builder
extends Node
## The hammer's build mode. Click with the hammer to open the build menu, pick something, then a hologram follows
## your aim: Q / E / scroll turn it, Shift + scroll makes it bigger or smaller (bigger costs more), click to set it
## down, right-click to cancel. The placed plan becomes a Blueprint that you fill by dropping materials into it.

const REACH := 9.0

var player: Player
var main: Node
var build_id := "basket"
var size_i := 2               # index into Builds.SIZES (1.0x)
var state := "idle"           # idle | place
var turn := 0.0               # extra rotation you've given the hologram (Q / E / scroll)
var _holo: Node3D
var _holo_parts: Array = []
var _holo_label: Label3D
var _valid := false
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
			_confirm()


## Picked from the menu: start placing it.
func start(id: String) -> void:
	build_id = id
	size_i = Builds.SIZES.find(1.0)
	state = "place"
	turn = 0.0
	_make_holo()
	Sfx.play("click")


## Q / E / mouse wheel while placing: turn it in 15 degree steps.
func rotate(step: int) -> void:
	if state != "place":
		return
	turn += deg_to_rad(15.0) * step
	Sfx.play("click", 1.2, -6.0)


## Shift + mouse wheel while placing: resize.
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
			return "[Q / E / Scroll] turn    [Shift+Scroll] size %sx    [Click] place    [Right-click] cancel" % str(size())
	return ""


func _make_holo() -> void:
	if _holo != null:
		_holo.queue_free()
	_holo = Node3D.new()
	main.add_child(_holo)
	_holo_parts = Builds.make(build_id, _holo, Builds.HOOP_DEFAULT * size(), size())
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
	bp.setup(build_id, Builds.HOOP_DEFAULT * size(), main, size())
	cancel()
	Game.save_game()
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
		# front of the build faces you, plus however much you've turned it
		_holo.global_transform = Transform3D(Basis.looking_at(flat, Vector3.UP).rotated(Vector3.UP, turn), pos)
		_paint(_valid)
