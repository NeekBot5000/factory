class_name Builder
extends Node
## The hammer's build mode. Click with the hammer to open the build menu, pick something, then a hologram follows
## your aim: R turns it, scroll makes it bigger or smaller (bigger costs more), click to set it down, E to cancel. The placed plan becomes a Blueprint that you fill by dropping materials into it.

const REACH := 9.0

var player: Player
var main: Node
var build_id := "basket"
var size_i := 2               # index into Builds.SIZES (1.0x)
var state := "idle"           # idle | place
var turn := 0.0               # extra rotation you've given the hologram (R)
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


## R while placing: turn it in 45 degree steps (machines: 90, so they line up on the grid).
func rotate(step: int) -> void:
	if state != "place":
		return
	turn += deg_to_rad(90.0 if Builds.fixed(build_id) else 45.0) * step
	Sfx.play("click", 1.2, -6.0)


## Mouse wheel while placing: resize.
func scroll(step: int) -> void:
	if state != "place" or Builds.fixed(build_id):
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
			if Builds.fixed(build_id):
				return "[R] turn    [Click] place    [E] cancel"
			return "[R] turn    [Scroll] size %sx    [Click] place    [E] cancel" % str(size())
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
		var mi := p.mi as MeshInstance3D
		mi.material_override = Machines.arrow_mat() if mi.has_meta("arrow") else (_ok_mat if ok else _bad_mat)


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
		# a rotator can also go on the side of something (a pillar, a machine, a rock...), its table facing out
		if build_id == "rotator" and not hit.is_empty() and absf((hit.normal as Vector3).y) < 0.3 \
				and not (hit.collider is RigidBody3D) and not (hit.collider is Truck):
			_place_on_side(hit)
			return
		var pos := from + fwd * 4.0
		_valid = false
		if not hit.is_empty():
			pos = hit.position
			_valid = (hit.normal as Vector3).y > 0.75 and not (hit.collider is ForestTree) and not (hit.collider is Truck)
		else:
			pos.y = main.terrain.height_at(pos.x, pos.z)
		if Builds.fixed(build_id):
			# machines sit on a 1 m grid and face one of the four directions, so belts line up end to end
			var cell := _grid_snap(pos)
			if cell.is_empty():
				_valid = false
			else:
				pos = cell.pos
				_valid = bool(cell.ok)
			var a := snappedf(atan2(flat.x, flat.z), PI * 0.5)
			flat = Vector3(sin(a), 0, cos(a))
		# front of the build faces you, plus however much you've turned it
		_holo.global_transform = Transform3D(Basis.looking_at(flat, Vector3.UP).rotated(Vector3.UP, turn), pos)
		_paint(_valid)


## Side-mounted rotator: flat against the face you're aiming at, lined up with the grid along it, and high
## enough off the ground for the table to turn.
func _place_on_side(hit: Dictionary) -> void:
	var n: Vector3 = hit.normal
	n.y = 0.0
	var a := snappedf(atan2(n.x, n.z), PI * 0.5)
	n = Vector3(sin(a), 0, cos(a))
	var p: Vector3 = hit.position
	var along_axis := Vector3(n.z, 0, -n.x)
	var along := p.dot(along_axis)
	p += along_axis * (snappedf(along, 1.0) - along)
	p.y = maxf(snappedf(p.y, 0.25), main.terrain.height_at(p.x, p.z) + 0.65)
	var basis := Basis(Vector3.UP.cross(n).normalized(), PI * 0.5)     # its up (the spin axis) points out of the face
	# room in front of the face for the base and the table
	var q := PhysicsShapeQueryParameters3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(0.8, 0.36, 0.8)
	q.shape = sh
	q.transform = Transform3D(basis, p + n * 0.24)
	q.collision_mask = 1 | Blueprint.LAYER
	q.exclude = [player.get_rid()]
	_valid = player.get_world_3d().direct_space_state.intersect_shape(q, 1).is_empty()
	_holo.global_transform = Transform3D(basis, p)
	_paint(_valid)


## The grid cell under `p`: its centre, dropped onto whatever is below (ground, or the top of another machine).
func _grid_snap(p: Vector3) -> Dictionary:
	var g := Vector3(snappedf(p.x, 1.0), p.y, snappedf(p.z, 1.0))
	var q := PhysicsRayQueryParameters3D.create(g + Vector3.UP * 1.5, g + Vector3.DOWN * 2.5, 1)
	q.exclude = [player.get_rid()]
	var space := player.get_world_3d().direct_space_state
	var hit := space.intersect_ray(q)
	for k in 4:
		if hit.is_empty() or not (hit.collider is RigidBody3D):
			break
		q.exclude = q.exclude + [hit.rid]
		hit = space.intersect_ray(q)
	if hit.is_empty():
		return {}
	# machines don't stack on machines (aiming at a belt to extend it shouldn't pile one on top); pillars are for that
	var on_machine := Machine.of(hit.collider) != null
	return {"pos": hit.position, "ok": (hit.normal as Vector3).y > 0.75 and not on_machine and not (hit.collider is ForestTree) and not (hit.collider is Truck)}
