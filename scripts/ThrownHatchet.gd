class_name ThrownHatchet
extends Node3D
## The throwing hatchet in flight: it spins end over end along your aim, bites a patch of bark off the trunk it
## hits and sticks there for a moment (with a little wobble), then pulls itself out and flies back to your hand.

const SPEED := 20.0
const DROP := 3.0            # it falls a little on the way out
const STICK_TIME := 0.32
const HANG := 0.22           # the model hangs off its balance point (it spins about that)

var player: Player
var vel := Vector3.ZERO
var state := 0               # 0 flying out, 1 stuck in a trunk, 2 coming back
var hits := 0                # trunks it took bark off (tests read this)
var _range := 12.0
var _travel := 0.0
var _spin := 0.0
var _t := 0.0
var _model: Node3D
var _back_from := Vector3.ZERO
var _back_side := Vector3.ZERO


func launch(p: Player, from: Vector3, dir: Vector3, range_m: float) -> void:
	player = p
	_range = range_m
	top_level = true
	global_position = from
	vel = dir.normalized() * SPEED
	_model = Tools.build_model("throwing", self)
	_model.position = Vector3(0, -HANG, 0)
	_face(dir)


func _face(dir: Vector3) -> void:
	if dir.length() < 0.001:
		return
	var up := Vector3.UP if absf(dir.normalized().y) < 0.98 else Vector3.BACK
	basis = Basis.looking_at(dir.normalized(), up)


func _physics_process(delta: float) -> void:
	_t += delta
	if player == null or not is_instance_valid(player):
		queue_free()
		return
	match state:
		0: _fly(delta)
		1: _stuck(delta)
		2: _come_back(delta)


func _fly(delta: float) -> void:
	var step := vel * delta
	var q := PhysicsRayQueryParameters3D.create(global_position, global_position + step + step.normalized() * 0.15, 1)
	q.exclude = [player.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty():
		_hit(hit)
		return
	global_position += step
	vel += Vector3.DOWN * DROP * delta
	_face(vel)
	_travel += step.length()
	_spin += delta * 24.0
	_model.basis = Basis(Vector3.RIGHT, -_spin)
	if _travel > _range:
		_return()


func _hit(hit: Dictionary) -> void:
	var c: Object = hit.collider
	var dir := vel.normalized()
	var t := Player.trunk_of(c)
	if t != null and player.throw_hit(t, c, hit.position, dir) > 0:
		hits += 1
		# stuck in the wood: blade first, handle sticking back out
		state = 1
		_t = 0.0
		_face(Vector3(dir.x, 0.0, dir.z) if Vector2(dir.x, dir.z).length() > 0.1 else dir)
		_model.basis = Basis()
		# the blade sits at (0, 0.34 - HANG, -0.13) in this node; put its edge just inside the bark
		global_position = (hit.position as Vector3) + basis.z * 0.1 - basis.y * (0.34 - HANG)
		return
	# bare wood, a rock, the ground: it clanks off and comes straight back
	Sfx.play_at("clink" if not (c is Terrain) else "thud", hit.position, 1.1, -4.0)
	if t != null:
		Sfx.play_at("chop_wood", hit.position, 1.1, -2.0)
	Nature.burst(get_parent(), hit.position, hit.normal, Color("ffd36a") if c is Rock else Color("8a6a45"), 8, 2.0, 0.02, 6.0, 0.4)
	global_position = (hit.position as Vector3) + (hit.normal as Vector3) * 0.15
	_return()


func _stuck(_delta: float) -> void:
	# a quick, dying wobble about the side axis
	var w := sin(_t * 46.0) * exp(-_t * 9.0) * 0.22
	_model.basis = Basis(Vector3.RIGHT, w)
	if _t >= STICK_TIME:
		_return()


func _return() -> void:
	state = 2
	_t = 0.0
	_back_from = global_position
	# it comes home on a gentle curve, not a dead straight line
	var to := player.hand_world() - global_position
	_back_side = to.cross(Vector3.UP).normalized() * clampf(to.length() * 0.12, 0.2, 1.2)
	Sfx.play_at("whoosh", global_position, 0.8, -4.0)


func _come_back(delta: float) -> void:
	var target := player.hand_world()
	var total := maxf(_back_from.distance_to(target), 0.5)
	# progress along the way home: quick at first, easing into the catch
	var dur := clampf(total / 17.0, 0.18, 0.9)
	var k := clampf(_t / dur, 0.0, 1.0)
	var e := 1.0 - pow(1.0 - k, 2.2)
	var p := _back_from.lerp(target, e) + _back_side * sin(e * PI)
	var moved := p - global_position
	global_position = p
	if moved.length() > 0.0005:
		_face(-moved)       # handle first: the blade trails behind, safe to catch
	_spin += delta * lerpf(24.0, 6.0, e)
	# it stops spinning just before the catch, handle into the palm
	_model.basis = Basis(Vector3.RIGHT, -_spin * (1.0 - e * e))
	if k >= 1.0 or _t > 3.0:
		player.catch_hatchet()
		queue_free()
