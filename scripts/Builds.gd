class_name Builds
extends RefCounted
## Things the hammer can build, and their models. Every model is built from parts; a part either needs a
## resource ("bark" = one panel of any bark, "log" = any log) and takes that material's colour when it is
## filled in, or is a finishing part that appears when the build completes.

const BUILDS := {
	"basket": {"name": "Bark Basket", "needs": {"bark": 16}, "desc": "Carry loads of bark around"},
	"hoop": {"name": "Basketball Hoop", "needs": {"bark": 12, "log": 1}, "desc": "Look up or down to set the height"},
}
const ORDER := ["basket", "hoop"]
const RES_NAME := {"bark": "bark", "log": "log"}

const HOOP_MIN := 1.8
const HOOP_MAX := 4.5
const HOOP_DEFAULT := 3.05


static func needs_text(id: String) -> String:
	var parts: Array[String] = []
	var n: Dictionary = BUILDS[id].needs
	for r in n:
		parts.append("%d %s" % [n[r], RES_NAME[r]])
	return "  +  ".join(parts)


## What a dropped body is worth to a build: {res, amount} or {} if it's no use.
static func resource_of(body: Node) -> Dictionary:
	if body is Chip:
		return {"res": "bark", "amount": (body as Chip).panels, "color": (body as Chip).color}
	if body is Log:
		return {"res": "log", "amount": 1, "color": (body as Log).trunk.bark_color}
	return {}


## Builds the model's parts under `parent`. Returns [{mi, res, real}] - res "" for finishing parts.
static func make(id: String, parent: Node3D, height: float = HOOP_DEFAULT) -> Array:
	var parts: Array = []
	match id:
		"basket": _basket(parent, parts)
		"hoop": _hoop(parent, parts, height)
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


## The finished object, coloured with the materials that went into it.
static func finish(id: String, world: Node, xform: Transform3D, height: float, colors: Array) -> Node3D:
	var body: Node3D
	if id == "basket":
		var rb := RigidBody3D.new()
		rb.collision_layer = 2
		rb.collision_mask = 1 | 2
		rb.mass = 1.5
		rb.angular_damp = 1.0
		body = rb
	else:
		var sb := StaticBody3D.new()
		sb.collision_layer = 1
		body = sb
	world.add_child(body)
	body.global_transform = xform
	var parts := make(id, body, height)
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
		"hoop":
			var top := height + 0.6
			_box_col(body, Vector3(0.22, top, 0.22), Vector3(0, top * 0.5, -0.45))
			_box_col(body, Vector3(1.2, 0.84, 0.05), Vector3(0, height + 0.3, -0.2))
			body.add_to_group("hoops")
	body.add_to_group("builds")
	return body


static func _box_col(body: Node3D, size: Vector3, pos: Vector3) -> void:
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	cs.position = pos
	body.add_child(cs)
