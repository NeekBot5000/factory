class_name Builds
extends RefCounted
## Things the hammer can build, and their models. Every model is built from parts; a part either needs a
## resource ("bark" = one panel of any bark, "log" = any log) and takes that material's colour when it is
## filled in, or is a finishing part that appears when the build completes.

const BUILDS := {
	"basket": {"name": "Bark Basket", "needs": {"bark": 50}},
	"bench": {"name": "Log Bench", "needs": {"log": 1, "bark": 6}},
	"campfire": {"name": "Campfire", "needs": {"bark": 6, "leaf": 10}},
	"hammock": {"name": "Leaf Hammock", "needs": {"log": 2, "leaf": 30}},
	"chute": {"name": "Bark Chute", "needs": {"log": 3, "bark": 12}},
	"rack": {"name": "Log Rack", "needs": {"log": 4}},
	"compost": {"name": "Compost Pile", "needs": {"leaf": 40}},
	"ball": {"name": "Basketball", "needs": {"leaf": 8}},
	"hoop": {"name": "Basketball Hoop", "needs": {"bark": 12, "log": 1}},
	"catapult": {"name": "Catapult", "needs": {"log": 3, "bark": 10, "leaf": 6}},
}
const ORDER := ["basket", "bench", "campfire", "hammock", "chute", "rack", "compost", "ball", "hoop", "catapult"]
const CATEGORIES := [
	{"name": "Storage", "items": ["basket", "rack"]},
	{"name": "Furniture", "items": ["bench", "hammock"]},
	{"name": "Fire & Garden", "items": ["campfire", "compost"]},
	{"name": "Workshop", "items": ["chute", "catapult"]},
	{"name": "Fun", "items": ["ball", "hoop"]},
]
const SIZES := [0.5, 0.75, 1.0, 1.25, 1.5, 2.0, 2.5, 3.0]

static var _S := 1.0     # scale applied to colliders while finishing a sized build
const RES_NAME := {"bark": "bark", "log": "log", "leaf": "leaves"}

const HOOP_MIN := 1.8
const HOOP_MAX := 4.5
const HOOP_DEFAULT := 3.05


## Bigger builds cost more: materials scale with the footprint (size squared), at least 1 of each.
static func needs_for(id: String, size: float = 1.0) -> Dictionary:
	var out := {}
	var n: Dictionary = BUILDS[id].needs
	for r in n:
		out[r] = maxi(1, int(ceil(float(n[r]) * size * size - 0.001)))
	return out


static func needs_text(id: String, size: float = 1.0) -> String:
	var parts: Array[String] = []
	var n := needs_for(id, size)
	for r in n:
		parts.append("%d %s" % [n[r], RES_NAME[r]])
	return "  +  ".join(parts)


## What a dropped body is worth to a build: {res, amount} or {} if it's no use.
static func resource_of(body: Node) -> Dictionary:
	if body is Chip:
		return {"res": "bark", "amount": (body as Chip).panels, "color": (body as Chip).color}
	if body is Log:
		return {"res": "log", "amount": 1, "color": (body as Log).trunk.bark_color}
	if body is Leaf:
		return {"res": "leaf", "amount": 1, "color": (body as Leaf).color}
	return {}


## Builds the model's parts under `parent`. Returns [{mi, res, real}] - res "" for finishing parts.
## Parts hang off a "Model" node scaled to `size`; the hoop keeps its rim at `height` whatever the size.
static func make(id: String, root: Node3D, height: float = HOOP_DEFAULT, size: float = 1.0) -> Array:
	var parts: Array = []
	var parent := Node3D.new()
	parent.name = "Model"
	parent.scale = Vector3.ONE * size
	root.add_child(parent)
	if id == "hoop":
		height = height / size
	match id:
		"basket": _basket(parent, parts)
		"hoop": _hoop(parent, parts, height)
		"bench": _bench(parent, parts)
		"campfire": _campfire(parent, parts)
		"hammock": _hammock(parent, parts)
		"chute": _chute(parent, parts)
		"rack": _rack(parent, parts)
		"compost": _compost(parent, parts)
		"ball": _ball(parent, parts)
		"catapult": _catapult(parent, parts)
	for p in parts:
		(p.mi as MeshInstance3D).material_override = p.real
	return parts


static func _part(parts: Array, parent: Node3D, mesh: Mesh, pos: Vector3, res: String, real: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := LowPoly.mesh_instance(parent, mesh, real, pos, rot)
	parts.append({"mi": mi, "res": res, "real": real})
	return mi


const BASKET_W := 0.7
const BASKET_D := 0.5
const BASKET_H := 0.44


static func _basket(root: Node3D, parts: Array) -> void:
	var bark := LowPoly.mat(Color("8a5a36"), 0.95)
	var trim := LowPoly.mat(Color("c9875a"), 0.9)
	# floor: 4 slats
	for k in 4:
		_part(parts, root, LowPoly.box(Vector3(BASKET_W, 0.035, BASKET_D / 4.0 - 0.006)), Vector3(0, 0.018, -BASKET_D * 0.5 + BASKET_D / 8.0 + k * BASKET_D / 4.0), "bark", bark)
	# walls: 3 woven strips per side, alternately offset like weaving
	var sh := (BASKET_H - 0.04) / 3.0
	for k in 3:
		var y := 0.04 + sh * (k + 0.5)
		var wob := 0.008 if k % 2 == 0 else -0.008
		for s in [-1.0, 1.0]:
			_part(parts, root, LowPoly.box(Vector3(BASKET_W + 0.03, sh - 0.01, 0.03)), Vector3(0, y, s * (BASKET_D * 0.5 + wob)), "bark", bark)
			_part(parts, root, LowPoly.box(Vector3(0.03, sh - 0.01, BASKET_D)), Vector3(s * (BASKET_W * 0.5 - wob), y, 0), "bark", bark)
	# finishing: rim band + two handles
	_part(parts, root, LowPoly.box(Vector3(BASKET_W + 0.06, 0.04, 0.05)), Vector3(0, BASKET_H, BASKET_D * 0.5), "", trim)
	_part(parts, root, LowPoly.box(Vector3(BASKET_W + 0.06, 0.04, 0.05)), Vector3(0, BASKET_H, -BASKET_D * 0.5), "", trim)
	_part(parts, root, LowPoly.box(Vector3(0.05, 0.04, BASKET_D)), Vector3(BASKET_W * 0.5, BASKET_H, 0), "", trim)
	_part(parts, root, LowPoly.box(Vector3(0.05, 0.04, BASKET_D)), Vector3(-BASKET_W * 0.5, BASKET_H, 0), "", trim)
	for s in [-1.0, 1.0]:
		_part(parts, root, LowPoly.box(Vector3(0.04, 0.12, 0.03)), Vector3(s * (BASKET_W * 0.5 + 0.03), BASKET_H + 0.06, -0.08), "", trim)
		_part(parts, root, LowPoly.box(Vector3(0.04, 0.12, 0.03)), Vector3(s * (BASKET_W * 0.5 + 0.03), BASKET_H + 0.06, 0.08), "", trim)
		_part(parts, root, LowPoly.box(Vector3(0.04, 0.03, 0.19)), Vector3(s * (BASKET_W * 0.5 + 0.03), BASKET_H + 0.125, 0), "", trim)


## Hoop facing +Z. `h` = rim height above the ground.
static func _hoop(root: Node3D, parts: Array, h: float) -> void:
	var log_mat := LowPoly.mat(Color("6b4a32"), 0.9)
	var birch := LowPoly.mat(Color("e8e4da"), 0.9)
	var wood := LowPoly.mat(Color("a0703c"), 0.8)
	var rim := LowPoly.mat(Color("e8642b"), 0.5)
	var net := LowPoly.mat(Color("f2efe6"), 0.9)
	var top := h + 0.6
	# the pole is one log
	_part(parts, root, LowPoly.cyl(0.1, 0.12, top, 8), Vector3(0, top * 0.5, -0.45), "log", log_mat)
	# backboard: 4 x 3 tiles of bark
	var bw := 1.2
	var bh := 0.84
	var cy := h + 0.3
	for row in 3:
		for col in 4:
			var x := -bw * 0.5 + bw / 8.0 + col * bw / 4.0
			var y := cy - bh * 0.5 + bh / 6.0 + row * bh / 3.0
			_part(parts, root, LowPoly.box(Vector3(bw / 4.0 - 0.01, bh / 3.0 - 0.01, 0.04)), Vector3(x, y, -0.2), "bark", birch)
	# finishing: braces, a target square, the rim and a net of bark strips
	_part(parts, root, LowPoly.box(Vector3(0.08, 0.08, 0.28)), Vector3(0, cy + 0.2, -0.33), "", wood)
	_part(parts, root, LowPoly.box(Vector3(0.08, 0.08, 0.28)), Vector3(0, cy - 0.25, -0.33), "", wood)
	_part(parts, root, LowPoly.box(Vector3(0.36, 0.03, 0.01)), Vector3(0, h + 0.36, -0.175), "", rim)
	for s in [-1.0, 1.0]:
		_part(parts, root, LowPoly.box(Vector3(0.03, 0.27, 0.01)), Vector3(s * 0.18, h + 0.23, -0.175), "", rim)
	var n := 14
	var rr := 0.23
	var c := Vector3(0, h, 0.1)
	for i in n:
		var a0 := TAU * i / n
		var a1 := TAU * (i + 1) / n
		var p0 := c + Vector3(cos(a0), 0, sin(a0)) * rr
		var p1 := c + Vector3(cos(a1), 0, sin(a1)) * rr
		var mi := _part(parts, root, LowPoly.box(Vector3(0.025, 0.025, p0.distance_to(p1) + 0.01)), (p0 + p1) * 0.5, "", rim)
		mi.basis = Basis.looking_at((p1 - p0).normalized(), Vector3.UP)
	_part(parts, root, LowPoly.box(Vector3(0.05, 0.03, 0.1)), Vector3(0, h, -0.16), "", rim)
	for i in 8:
		var a := TAU * i / 8.0
		var p := c + Vector3(cos(a), 0, sin(a)) * rr * 0.92
		var mi2 := _part(parts, root, LowPoly.box(Vector3(0.012, 0.36, 0.012)), p + Vector3(0, -0.17, 0) - Vector3(cos(a), 0, sin(a)) * 0.04, "", net)
		mi2.rotation = Vector3(sin(a) * 0.2, 0, -cos(a) * 0.2)


const BARK := Color("8a5a36")
const LOGC := Color("6b4a32")
const LEAF := Color("5aa041")
const STONE := Color("8a8780")


static func _bench(root: Node3D, parts: Array) -> void:
	var bark := LowPoly.mat(BARK, 0.95)
	var logm := LowPoly.mat(LOGC, 0.9)
	for sx in [-0.5, 0.5]:
		_part(parts, root, LowPoly.cyl(0.13, 0.14, 0.42, 8), Vector3(sx, 0.21, 0), "log", logm)
	for k in 6:
		_part(parts, root, LowPoly.box(Vector3(1.4, 0.04, 0.065)), Vector3(0, 0.44, -0.18 + k * 0.072), "bark", bark)


static func _campfire(root: Node3D, parts: Array) -> void:
	var bark := LowPoly.mat(BARK, 0.95)
	var leaf := LowPoly.mat(LEAF, 0.9)
	var stone := LowPoly.mat(STONE, 1.0)
	for k in 9:
		var a := TAU * k / 9.0
		_part(parts, root, LowPoly.blob(0.1, 0.3, 11 + k), Vector3(cos(a) * 0.42, 0.06, sin(a) * 0.42), "", stone)
	for k in 5:
		var a2 := TAU * k / 5.0 + 0.3
		_part(parts, root, LowPoly.blob(0.07, 0.3, 21 + k), Vector3(cos(a2) * 0.12, 0.06, sin(a2) * 0.12), "leaf", leaf)
	for k in 6:
		var a3 := TAU * k / 6.0
		var mi := _part(parts, root, LowPoly.box(Vector3(0.05, 0.6, 0.05)), Vector3(cos(a3) * 0.14, 0.26, sin(a3) * 0.14), "bark", bark)
		mi.basis = Basis(Vector3(-sin(a3), 0, cos(a3)), deg_to_rad(-24.0))


static func _hammock(root: Node3D, parts: Array) -> void:
	var logm := LowPoly.mat(LOGC, 0.9)
	var leaf := LowPoly.mat(LEAF, 0.9)
	var rope := LowPoly.mat(Color("c9b48a"), 0.9)
	for sx in [-1.35, 1.35]:
		_part(parts, root, LowPoly.cyl(0.1, 0.12, 1.75, 8), Vector3(sx, 0.875, 0), "log", logm)
	var n := 10
	for k in n:
		var x := -1.0 + (k + 0.5) * 2.0 / n
		var y := 0.95 - 0.28 * (1.0 - pow(x / 1.1, 2.0))
		_part(parts, root, LowPoly.box(Vector3(2.0 / n + 0.01, 0.05, 0.85)), Vector3(x, y, 0), "leaf", leaf, Vector3(0, 0, -rad_to_deg(atan(0.28 * 2.0 * x / 1.21))))
	for sx in [-1.0, 1.0]:
		var mi := _part(parts, root, LowPoly.box(Vector3(0.42, 0.02, 0.02)), Vector3(sx * 1.17, 1.25, 0), "", rope)
		mi.rotation_degrees.z = 32.0 * -sx


## Trough sloping down away from you (local -Z), resting on three log posts.
const CHUTE_TILT := 20.0
const CHUTE_C := Vector3(0, 0.85, -0.1)


static func _chute_dir() -> Vector3:
	return Vector3(0, -sin(deg_to_rad(CHUTE_TILT)), -cos(deg_to_rad(CHUTE_TILT)))


static func _chute(root: Node3D, parts: Array) -> void:
	var bark := LowPoly.mat(BARK, 0.95)
	var logm := LowPoly.mat(LOGC, 0.9)
	var d := _chute_dir()
	var nrm := Vector3(0, cos(deg_to_rad(CHUTE_TILT)), -sin(deg_to_rad(CHUTE_TILT)))
	var rot := Vector3(-CHUTE_TILT, 0, 0)
	for i in 4:
		var c := CHUTE_C + d * (-1.2 + i * 0.8)
		_part(parts, root, LowPoly.box(Vector3(0.6, 0.04, 0.8)), c, "bark", bark, rot)
		for sx in [-1.0, 1.0]:
			_part(parts, root, LowPoly.box(Vector3(0.04, 0.2, 0.8)), c + Vector3(sx * 0.3, 0, 0) + nrm * 0.1, "bark", bark, rot)
	var top := CHUTE_C - d * 1.4
	var bottom := CHUTE_C + d * 1.4
	for sx in [-0.34, 0.34]:
		_part(parts, root, LowPoly.cyl(0.07, 0.08, top.y, 7), Vector3(sx, top.y * 0.5, top.z), "log", logm)
	_part(parts, root, LowPoly.cyl(0.07, 0.08, bottom.y, 7), Vector3(0, bottom.y * 0.5, bottom.z), "log", logm)


## Two V-shaped cradles; logs lie across them along X.
static func _rack(root: Node3D, parts: Array) -> void:
	var logm := LowPoly.mat(LOGC, 0.9)
	var wood := LowPoly.mat(Color("a0703c"), 0.85)
	for sx in [-0.7, 0.7]:
		for sz in [-1.0, 1.0]:
			_part(parts, root, LowPoly.cyl(0.06, 0.07, 1.0, 7), Vector3(sx, 0.46, sz * 0.24), "log", logm, Vector3(sz * 22.0, 0, 0))
	_part(parts, root, LowPoly.box(Vector3(1.6, 0.08, 0.12)), Vector3(0, 0.05, 0), "", wood)


static func _compost(root: Node3D, parts: Array) -> void:
	var leaf := LowPoly.mat(LEAF.darkened(0.15), 0.95)
	var wood := LowPoly.mat(Color("8a5e38"), 0.9)
	var mound := Node3D.new()
	mound.name = "Mound"
	root.add_child(mound)
	var pts := [Vector3(0, 0.25, 0), Vector3(0.28, 0.18, 0.15), Vector3(-0.28, 0.18, 0.1), Vector3(0.1, 0.18, -0.3),
		Vector3(-0.15, 0.18, 0.3), Vector3(0.0, 0.45, 0.05), Vector3(0.2, 0.36, -0.1), Vector3(-0.2, 0.36, -0.12)]
	for k in pts.size():
		_part(parts, mound, LowPoly.blob(0.24, 0.3, 31 + k), pts[k], "leaf", leaf)
	for sx in [-1.0, 1.0]:
		_part(parts, root, LowPoly.box(Vector3(0.05, 0.35, 1.2)), Vector3(sx * 0.6, 0.175, 0), "", wood)
		_part(parts, root, LowPoly.box(Vector3(1.2, 0.35, 0.05)), Vector3(0, 0.175, sx * 0.6), "", wood)


static func _ball(root: Node3D, parts: Array) -> void:
	var leaf := LowPoly.mat(LEAF, 0.85)
	for k in 8:
		var o := Vector3(1 if k & 1 else -1, 1 if k & 2 else -1, 1 if k & 4 else -1) * 0.045
		_part(parts, root, LowPoly.blob(0.075, 0.2, 41 + k), Vector3(0, Basketball.R, 0) + o, "leaf", leaf)


## Fires along -Z. Arm pivots at the axle, cup at its end, resting back toward you.
const CAT_PIVOT := Vector3(0, 0.38, 0.25)
const CAT_ARM := 1.1


static func _catapult(root: Node3D, parts: Array) -> void:
	var bark := LowPoly.mat(BARK, 0.95)
	var logm := LowPoly.mat(LOGC, 0.9)
	var leaf := LowPoly.mat(LEAF.darkened(0.2), 0.9)
	var wood := LowPoly.mat(Color("a0703c"), 0.85)
	for sx in [-0.45, 0.45]:
		_part(parts, root, LowPoly.cyl(0.09, 0.09, 1.9, 8), Vector3(sx, 0.1, 0.2), "log", logm, Vector3(90, 0, 0))
	_part(parts, root, LowPoly.cyl(0.08, 0.08, 1.05, 8), Vector3(0, 0.95, -0.45), "log", logm, Vector3(0, 0, 90))
	for sx in [-0.45, 0.45]:
		_part(parts, root, LowPoly.box(Vector3(0.08, 0.9, 0.08)), Vector3(sx, 0.5, -0.45), "", wood)
	# the arm (a child node so it can swing); its parts are still listed so they fill in like the rest
	var arm := Node3D.new()
	arm.name = "Arm"
	arm.position = CAT_PIVOT
	root.add_child(arm)
	for k in 4:
		_part(parts, arm, LowPoly.box(Vector3(0.12, 0.05, CAT_ARM / 4.0 - 0.01)), Vector3(0, 0, CAT_ARM * (k + 0.5) / 4.0), "bark", bark)
	_part(parts, arm, LowPoly.box(Vector3(0.42, 0.04, 0.42)), Vector3(0, 0.03, CAT_ARM), "bark", bark)
	_part(parts, arm, LowPoly.box(Vector3(0.42, 0.18, 0.04)), Vector3(0, 0.12, CAT_ARM + 0.2), "bark", bark)
	# leaf-rope torsion spring around the axle
	for sx in [-0.25, 0.25]:
		_part(parts, root, LowPoly.cyl(0.11, 0.11, 0.16, 8), CAT_PIVOT + Vector3(sx, 0, 0), "leaf", leaf, Vector3(0, 0, 90))
	_part(parts, root, LowPoly.cyl(0.03, 0.03, 0.95, 6), CAT_PIVOT, "", wood, Vector3(0, 0, 90))


## The finished object, coloured with the materials that went into it.
static func finish(id: String, world: Node, xform: Transform3D, height: float, colors: Array, size: float = 1.0) -> Node3D:
	_S = size
	var body: Node3D
	match id:
		"basket":
			var rb := RigidBody3D.new()
			rb.collision_layer = 2
			rb.collision_mask = 1 | 2
			rb.mass = 1.5
			rb.angular_damp = 1.0
			body = rb
		"ball":
			var ball := Basketball.new()
			world.add_child(ball)
			ball.global_transform = xform * Transform3D(Basis(), Vector3(0, Basketball.R * size + 0.02, 0))
			ball.setup(colors, size)
			ball.add_to_group("builds")
			return ball
		"campfire":
			body = Campfire.new()
		"hammock":
			body = Hammock.new()
		"compost":
			body = Compost.new()
		"catapult":
			body = Catapult.new()
		_:
			body = StaticBody3D.new()
	if body is StaticBody3D:
		(body as StaticBody3D).collision_layer = 1
	world.add_child(body)
	body.global_transform = xform
	var parts := make(id, body, height, size)
	var k := 0
	for p in parts:
		if p.res != "" and k < colors.size():
			(p.mi as MeshInstance3D).material_override = LowPoly.mat(colors[k], 0.9)
			k += 1
	match id:
		"basket":
			_box_col(body, Vector3(BASKET_W, 0.04, BASKET_D), Vector3(0, 0.02, 0))
			for s in [-1.0, 1.0]:
				_box_col(body, Vector3(BASKET_W + 0.04, BASKET_H, 0.035), Vector3(0, BASKET_H * 0.5, s * BASKET_D * 0.5))
				_box_col(body, Vector3(0.035, BASKET_H, BASKET_D), Vector3(s * BASKET_W * 0.5, BASKET_H * 0.5, 0))
			body.add_to_group("grabbable")
			body.add_to_group("baskets")
			body.set_meta("size", size)
		"hoop":
			var hh := height / size
			var top := hh + 0.6
			_box_col(body, Vector3(0.22, top, 0.22), Vector3(0, top * 0.5, -0.45))
			_box_col(body, Vector3(1.2, 0.84, 0.05), Vector3(0, hh + 0.3, -0.2))
			# a real rim the ball can clang off, and a net sensor to count baskets
			var c := Vector3(0, hh, 0.1) * size
			for i in 12:
				var a := TAU * i / 12.0
				_box_col(body, Vector3(0.04, 0.04, 0.04), c / size + Vector3(cos(a), 0, sin(a)) * 0.24)
			var net := Area3D.new()
			net.collision_layer = 0
			net.collision_mask = 2
			var ncs := CollisionShape3D.new()
			var nsh := CylinderShape3D.new()
			nsh.radius = 0.16 * size
			nsh.height = 0.12 * size
			ncs.shape = nsh
			ncs.position = c + Vector3(0, -0.12, 0) * size
			net.add_child(ncs)
			body.add_child(net)
			net.body_entered.connect(func(b):
				if b is Basketball and (b as RigidBody3D).linear_velocity.y < 0.0:
					Sfx.play("reveal", 1.3)
					Nature.burst(world, (b as Node3D).global_position, Vector3.UP, Color("ffcf6a"), 24, 2.5, 0.03, 3.0, 1.0, 140.0, 1.5)
					Game.toast.emit("Swish!", Color("ffcf6a")))
			body.add_to_group("hoops")
		"bench":
			_box_col(body, Vector3(1.4, 0.06, 0.45), Vector3(0, 0.44, 0))
			for sx in [-0.5, 0.5]:
				_box_col(body, Vector3(0.26, 0.42, 0.26), Vector3(sx, 0.21, 0))
		"campfire":
			_box_col(body, Vector3(0.6, 0.16, 0.6), Vector3(0, 0.08, 0))
			(body as Campfire).light_up(size)
		"hammock":
			(body as Hammock).bed_h = 0.55 * size
			for sx in [-1.35, 1.35]:
				_box_col(body, Vector3(0.22, 1.75, 0.22), Vector3(sx, 0.875, 0))
			_box_col(body, Vector3(2.0, 0.08, 0.85), Vector3(0, 0.72, 0))
		"chute":
			var d := _chute_dir()
			var nrm := Vector3(0, cos(deg_to_rad(CHUTE_TILT)), -sin(deg_to_rad(CHUTE_TILT)))
			var bas := Basis(Vector3.RIGHT, deg_to_rad(-CHUTE_TILT))
			_rot_col(body, Vector3(0.6, 0.04, 3.2), CHUTE_C, bas)
			for sx in [-1.0, 1.0]:
				_rot_col(body, Vector3(0.04, 0.22, 3.2), CHUTE_C + Vector3(sx * 0.3, 0, 0) + nrm * 0.1, bas)
			var top := CHUTE_C - d * 1.4
			for sx in [-0.34, 0.34]:
				_box_col(body, Vector3(0.15, top.y, 0.15), Vector3(sx, top.y * 0.5, top.z))
			var pm := PhysicsMaterial.new()
			pm.friction = 0.04
			(body as StaticBody3D).physics_material_override = pm
		"rack":
			for sx in [-0.7, 0.7]:
				for sz in [-1.0, 1.0]:
					_rot_col(body, Vector3(0.13, 1.0, 0.13), Vector3(sx, 0.46, sz * 0.24), Basis(Vector3.RIGHT, deg_to_rad(sz * 22.0)))
		"compost":
			_box_col(body, Vector3(1.2, 0.3, 1.2), Vector3(0, 0.15, 0))
			(body as Compost).activate(body.get_node("Model/Mound"), size)
		"catapult":
			for sx in [-0.45, 0.45]:
				_box_col(body, Vector3(0.18, 0.18, 1.9), Vector3(sx, 0.1, 0.2))
			_box_col(body, Vector3(1.05, 0.16, 0.16), Vector3(0, 0.95, -0.45))
			var cup := CAT_PIVOT + Vector3(0, 0, CAT_ARM)
			_box_col(body, Vector3(0.42, 0.04, 0.42), cup + Vector3(0, 0.03, 0))
			_box_col(body, Vector3(0.42, 0.18, 0.04), cup + Vector3(0, 0.12, 0.2))
			(body as Catapult).setup_arm(body.get_node("Model/Arm"), cup * size, size)
	body.add_to_group("builds")
	return body


static func _rot_col(body: Node3D, size: Vector3, pos: Vector3, basis: Basis) -> void:
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size * _S
	cs.shape = sh
	cs.transform = Transform3D(basis, pos * _S)
	body.add_child(cs)


static func _box_col(body: Node3D, size: Vector3, pos: Vector3) -> void:
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size * _S
	cs.shape = sh
	cs.position = pos * _S
	body.add_child(cs)
