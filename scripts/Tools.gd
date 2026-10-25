class_name Tools
extends RefCounted
## Tool + shop catalogue, and the procedural models for every tool.
## Model frame: origin = where the hand grips, handle runs along +Y, the cutting end faces -Z.

# radius: stripping circle in metres.  cooldown: seconds per swing.  impact: fraction of the swing where it hits.
# hurt: damage to yourself per hit.  anim: animation style.  hold: keep the button down for continuous use.
const TOOLS := {
	"hands": {"name": "Bare Hands", "radius": 0.05, "cooldown": 0.34, "impact": 0.42, "hurt": 6.0, "anim": "karate", "reach": 2.1},
	"hatchet": {"name": "Trusty Hatchet", "radius": 0.18, "cooldown": 0.5, "impact": 0.45, "hurt": 0.0, "anim": "chop", "reach": 2.3},
	"double_bit": {"name": "Double-Bit Axe", "radius": 0.25, "cooldown": 0.9, "impact": 0.35, "hurt": 0.0, "anim": "double", "impacts": [0.32, 0.74], "reach": 2.5},
	"labrys": {"name": "Crescent Labrys", "radius": 0.34, "cooldown": 0.85, "impact": 0.55, "hurt": 0.0, "anim": "slam", "reach": 2.6},
	"scraper": {"name": "Bark Scraper", "radius": 0.3, "cooldown": 0.42, "impact": 0.45, "hurt": 0.0, "anim": "chop", "reach": 2.3, "layer": "outer"},
	"gouge": {"name": "Inner Gouge", "radius": 0.13, "cooldown": 0.34, "impact": 0.45, "hurt": 0.0, "anim": "chop", "reach": 2.2, "layer": "inner", "value": 1.35},
	"ringer": {"name": "Ringing Axe", "radius": 0.0, "cooldown": 0.95, "impact": 0.55, "hurt": 0.0, "anim": "sweep", "reach": 2.4, "ring": true},
	"twins": {"name": "Twin Hatchets", "radius": 0.12, "cooldown": 0.24, "impact": 0.45, "hurt": 0.0, "anim": "twin", "reach": 2.2},
	"greataxe": {"name": "Greataxe", "radius": 0.5, "cooldown": 1.35, "impact": 0.62, "hurt": 0.0, "anim": "slam", "reach": 2.7, "move": 0.55},
	"combo": {"name": "Combo Axe", "radius": 0.1, "cooldown": 0.4, "impact": 0.45, "hurt": 0.0, "anim": "chop", "reach": 2.3},
	"drill": {"name": "Timber Auger", "radius": 0.3, "cooldown": 0.16, "impact": 0.0, "hurt": 0.0, "anim": "drill", "reach": 2.2, "hold": true, "kind": "drill"},
	"saw": {"name": "Bow Saw", "radius": 0.0, "cooldown": 0.3, "impact": 0.0, "hurt": 0.0, "anim": "saw", "reach": 2.2, "hold": true, "kind": "saw"},
	"shears": {"name": "Pruning Shears", "radius": 0.0, "cooldown": 0.32, "impact": 0.45, "hurt": 0.0, "anim": "snip", "reach": 4.2},
	"vacuum": {"name": "Leaf Vacuum", "radius": 0.0, "cooldown": 0.1, "impact": 0.0, "hurt": 0.0, "anim": "vacuum", "reach": 7.0, "hold": true, "kind": "vacuum"},
	"robo": {"name": "Robo-Axe X9", "radius": 0.0, "cooldown": 0.16, "impact": 0.5, "hurt": 0.0, "anim": "chop", "reach": 2.4, "through": true, "grid": 3, "auto": true},
	"chainsaw": {"name": "Chainsaw", "radius": 0.0, "cooldown": 0.3, "impact": 0.0, "hurt": 0.0, "anim": "saw", "reach": 2.0, "hold": true, "kind": "saw", "speed": 3.2},
	"bucksaw": {"name": "Buck Saw", "radius": 0.0, "cooldown": 0.3, "impact": 0.0, "hurt": 0.0, "anim": "saw", "reach": 2.4, "hold": true, "kind": "saw", "fell": false, "buck": true, "speed": 0.8},
	"twin_auger": {"name": "Twin Auger", "radius": 0.17, "cooldown": 0.2, "impact": 0.0, "hurt": 0.0, "anim": "drill", "reach": 2.2, "hold": true, "kind": "drill", "bits": 2},
	"holesaw": {"name": "Hole Saw", "radius": 0.12, "cooldown": 0.22, "impact": 0.0, "hurt": 0.0, "anim": "drill", "reach": 2.2, "hold": true, "kind": "drill", "through": true},
	"twinvac": {"name": "Twin-Nozzle Vac", "radius": 0.0, "cooldown": 0.1, "impact": 0.0, "hurt": 0.0, "anim": "vacuum", "reach": 9.0, "hold": true, "kind": "vacuum", "nozzles": [Vector3(-0.32, 0, 0), Vector3(0.32, 0, 0)], "cone": 0.62, "cap": 70, "range": 9.0},
	"cyclone": {"name": "Cyclone Vac", "radius": 0.0, "cooldown": 0.1, "impact": 0.0, "hurt": 0.0, "anim": "vacuum", "reach": 12.0, "hold": true, "kind": "vacuum", "range": 12.0, "cone": 0.93, "cap": 25, "launch": true},
	"hammer": {"name": "Builder's Hammer", "radius": 0.0, "cooldown": 0.45, "impact": 0.5, "hurt": 0.0, "anim": "hammer", "reach": 2.2},
}
const TOOL_ORDER := ["hands", "hatchet", "double_bit", "twins", "combo", "scraper", "gouge", "ringer", "labrys", "greataxe", "robo", "saw", "bucksaw", "chainsaw", "shears", "drill", "twin_auger", "holesaw", "vacuum", "twinvac", "cyclone", "hammer"]

const CATEGORIES := [
	{"id": "all", "name": "Everything"},
	{"id": "axes", "name": "Axes"},
	{"id": "saws", "name": "Saws"},
	{"id": "specialty", "name": "Specialty Tools"},
	{"id": "other", "name": "Other"},
]

const SHOP := {
	"hatchet": {"name": "Trusty Hatchet", "price": 30.0, "cat": "axes", "tag": "Light",
		"desc": "A light forged hatchet with a hickory handle. No more bruised hands, and it lifts a palm-sized sheet of bark per swing."},
	"double_bit": {"name": "Double-Bit Axe", "price": 160.0, "cat": "axes", "tag": "Balanced",
		"desc": "Two balanced heads on a straight handle. Swing it sideways in a wide arc to peel off big strips of bark."},
	"labrys": {"name": "Crescent Labrys", "price": 650.0, "cat": "axes", "tag": "Heavy",
		"desc": "A two-handed axe with mirrored crescent blades. A spinning overhead slam strips a huge patch in one blow."},
	"twins": {"name": "Twin Hatchets", "price": 300.0, "cat": "axes", "tag": "Fast",
		"desc": "One in each hand. Lightning-quick left and right chops, small strips each - keep up the rhythm."},
	"combo": {"name": "Combo Axe", "price": 750.0, "cat": "axes", "tag": "Rhythmic",
		"desc": "Every hit in quick succession makes the next one bigger, up to huge patches. Stop swinging and it resets."},
	"scraper": {"name": "Bark Scraper", "price": 220.0, "cat": "axes", "tag": "Wide",
		"desc": "A flat spud blade that lifts big clean sheets of outer bark only - it never digs into the inner layer."},
	"gouge": {"name": "Inner Gouge", "price": 380.0, "cat": "axes", "tag": "Precise",
		"desc": "A curved gouge for the prized orange inner bark only. Small strips, but each sells for 35% more."},
	"ringer": {"name": "Ringing Axe", "price": 520.0, "cat": "axes", "tag": "Sweeping",
		"desc": "A long curved blade: every swing takes a whole ring of bark off all the way round the trunk. Slow."},
	"greataxe": {"name": "Greataxe", "price": 900.0, "cat": "axes", "tag": "Massive",
		"desc": "The biggest bite in the forest. A long windup, and you walk slowly while you lug it around."},
	"drill": {"name": "Timber Auger", "price": 2400.0, "cat": "specialty", "tag": "Heavy",
		"desc": "A cordless rotary debarker. Hold the trigger and sweep it across the trunk to strip bark continuously."},
	"saw": {"name": "Bow Saw", "price": 450.0, "cat": "saws", "tag": "Long reach",
		"desc": "A steel bow saw. Hold it against a trunk to fell the whole tree, then saw the log into pieces. Logs sell by the metre."},
	"shears": {"name": "Pruning Shears", "price": 90.0, "cat": "specialty", "tag": "Light",
		"desc": "Long-reach shears. Snip big clumps of leaves off bushes and tree crowns. Leaves don't sell for much, but there are tons of them."},
	"robo": {"name": "Robo-Axe X9", "price": 6500.0, "cat": "axes", "tag": "Automatic",
		"desc": "Servo-driven and relentless. Hold the trigger: it chops on its own several times a second, punching a 3x3 patch through BOTH layers of bark every hit."},
	"chainsaw": {"name": "Chainsaw", "price": 1800.0, "cat": "saws", "tag": "Loud",
		"desc": "A two-stroke chainsaw. Fells trees and cuts logs about three times faster than a bow saw. Ear defenders not included."},
	"bucksaw": {"name": "Buck Saw", "price": 280.0, "cat": "saws", "tag": "Long",
		"desc": "A long framed saw for lying logs only - it can't fell a tree. One cut splits the whole log into neat carryable rounds."},
	"twin_auger": {"name": "Twin Auger", "price": 3200.0, "cat": "specialty", "tag": "Wide",
		"desc": "Two counter-rotating bits side by side. Sweep it along a trunk to bore two tracks of bark off at once."},
	"holesaw": {"name": "Hole Saw", "price": 2100.0, "cat": "specialty", "tag": "Deep",
		"desc": "A toothed cup that bites straight in: every spot it touches loses its outer AND inner bark together."},
	"twinvac": {"name": "Twin-Nozzle Vac", "price": 2600.0, "cat": "specialty", "tag": "Wide",
		"desc": "Two intakes on a forked tube. A much wider pull, and it holds twice as much in two swirling clumps."},
	"cyclone": {"name": "Cyclone Vac", "price": 3400.0, "cat": "specialty", "tag": "Powerful",
		"desc": "A long-range cyclone with a narrow, strong pull. Let go of the trigger and it fires everything it caught straight ahead."},
	"hammer": {"name": "Builder's Hammer", "price": 120.0, "cat": "other", "tag": "Compact",
		"desc": "Build things out of what you gather: pick a plan, set it down, then drop the materials into it."},
	"vacuum": {"name": "Leaf Vacuum", "price": 1200.0, "cat": "specialty", "tag": "Bulky",
		"desc": "Hold the trigger to suck up loose bark and boxes. They float in front of the nozzle until you let go."},
	"phone": {"name": "TimberPhone", "price": 350.0, "cat": "other", "tag": "Pocket-size",
		"desc": "Shop TimberMart and send the log truck off from anywhere in the forest. Press Tab to use it."},
}
const SHOP_ORDER := ["hatchet", "double_bit", "twins", "combo", "scraper", "gouge", "ringer", "labrys", "greataxe", "robo", "saw", "bucksaw", "chainsaw", "drill", "twin_auger", "holesaw", "shears", "vacuum", "twinvac", "cyclone", "hammer", "phone"]

const WOOD := Color("a0703c")
const STEEL := Color("c9ced6")
const DARK_STEEL := Color("6d7480")


static func stat_reach(id: String) -> float:
	return float(TOOLS[id].radius) if TOOLS.has(id) else 0.0


static func steel(c: Color = STEEL, rough: float = 0.3) -> StandardMaterial3D:
	var m := LowPoly.mat(c, rough)
	m.metallic = 0.7
	return m


## Flat prism from a 2D outline in the YZ plane, extruded along X (thickness centred on 0).
static func prism(points: PackedVector2Array, thickness: float, col: Color) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tris := Geometry2D.triangulate_polygon(points)
	var h := thickness * 0.5
	for k in range(0, tris.size(), 3):
		var a: Vector2 = points[tris[k]]
		var b: Vector2 = points[tris[k + 1]]
		var c: Vector2 = points[tris[k + 2]]
		LowPoly.tri(st, Vector3(h, a.x, a.y), Vector3(h, b.x, b.y), Vector3(h, c.x, c.y), Vector3.RIGHT, col)
		LowPoly.tri(st, Vector3(-h, a.x, a.y), Vector3(-h, b.x, b.y), Vector3(-h, c.x, c.y), Vector3.LEFT, col)
	var n := points.size()
	var center := Vector2.ZERO
	for p in points:
		center += p
	center /= n
	for k in n:
		var p0: Vector2 = points[k]
		var p1: Vector2 = points[(k + 1) % n]
		var mid := (p0 + p1) * 0.5
		var edge := p1 - p0
		var nrm := Vector2(edge.y, -edge.x).normalized()
		if nrm.dot(mid - center) < 0.0:
			nrm = -nrm
		LowPoly.quad(st, Vector3(-h, p0.x, p0.y), Vector3(h, p0.x, p0.y), Vector3(h, p1.x, p1.y), Vector3(-h, p1.x, p1.y), Vector3(0, nrm.x, nrm.y), col.darkened(0.08))
	return st.commit()


static func build_model(id: String, parent: Node3D) -> Node3D:
	var root := Node3D.new()
	parent.add_child(root)
	match id:
		"hatchet": _hatchet(root)
		"double_bit": _double_bit(root)
		"labrys": _labrys(root)
		"drill": _drill(root)
		"phone": _phone(root)
		"saw": _saw(root)
		"vacuum": _vacuum(root)
		"hammer": _hammer(root)
		"shears": _shears(root)
		"scraper": _scraper(root)
		"gouge": _gouge(root)
		"ringer": _ringer(root)
		"twins": _twin(root)
		"greataxe": _greataxe(root)
		"combo": _combo(root)
		"robo": _robo(root)
		"chainsaw": _chainsaw(root)
		"bucksaw": _bucksaw(root)
		"twin_auger": _twin_auger(root)
		"holesaw": _holesaw(root)
		"twinvac": _twinvac(root)
		"cyclone": _cyclone(root)
	for m in root.find_children("*", "MeshInstance3D", true, false):
		(m as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return root


static func _handle(root: Node3D, length: float, r: float, col: Color, from_y: float = -0.06) -> void:
	LowPoly.mesh_instance(root, LowPoly.cyl(r * 0.9, r, length, 7), LowPoly.mat(col, 0.7), Vector3(0, from_y + length * 0.5, 0))
	LowPoly.mesh_instance(root, LowPoly.cyl(r * 1.25, r * 1.25, 0.03, 7), LowPoly.mat(col.darkened(0.3)), Vector3(0, from_y + 0.015, 0))


static func _hatchet(root: Node3D) -> void:
	_handle(root, 0.42, 0.016, WOOD)
	var y := 0.33
	# head: eye block + flaring bit towards -Z
	LowPoly.mesh_instance(root, LowPoly.box(Vector3(0.034, 0.06, 0.055)), steel(DARK_STEEL), Vector3(0, y, 0.0))
	var blade := PackedVector2Array([Vector2(y - 0.03, -0.025), Vector2(y + 0.03, -0.025), Vector2(y + 0.055, -0.115), Vector2(y - 0.05, -0.115)])
	LowPoly.mesh_instance(root, prism(blade, 0.022, STEEL), steel(), Vector3.ZERO)
	LowPoly.mesh_instance(root, LowPoly.box(Vector3(0.036, 0.04, 0.03)), LowPoly.mat(Color("c0392b"), 0.5), Vector3(0, y, 0.015))
	# edge highlight
	LowPoly.mesh_instance(root, LowPoly.box(Vector3(0.008, 0.104, 0.006)), steel(Color("f2f5f8"), 0.1), Vector3(0, y + 0.002, -0.116))


static func _double_bit(root: Node3D) -> void:
	_handle(root, 0.62, 0.017, Color("b98a52"))
	var y := 0.53
	LowPoly.mesh_instance(root, LowPoly.box(Vector3(0.036, 0.07, 0.05)), steel(DARK_STEEL), Vector3(0, y, 0))
	for s in [-1.0, 1.0]:
		var blade := PackedVector2Array([Vector2(y - 0.032, 0.02 * s), Vector2(y + 0.032, 0.02 * s), Vector2(y + 0.075, 0.13 * s), Vector2(y - 0.075, 0.13 * s)])
		LowPoly.mesh_instance(root, prism(blade, 0.02, STEEL), steel(), Vector3.ZERO)
		LowPoly.mesh_instance(root, LowPoly.box(Vector3(0.007, 0.15, 0.006)), steel(Color("f2f5f8"), 0.1), Vector3(0, y, 0.131 * s))
	LowPoly.mesh_instance(root, LowPoly.box(Vector3(0.038, 0.072, 0.014)), LowPoly.mat(Color("2e86de"), 0.4), Vector3(0, y, 0))


static func _labrys(root: Node3D) -> void:
	_handle(root, 0.78, 0.02, Color("3b2a22"), -0.12)
	for k in 3:
		LowPoly.mesh_instance(root, LowPoly.cyl(0.023, 0.023, 0.05, 7), LowPoly.mat(Color("7a4a2a"), 1.0), Vector3(0, -0.05 + k * 0.07, 0))
	var y := 0.6
	LowPoly.mesh_instance(root, LowPoly.cyl(0.03, 0.03, 0.12, 8), steel(Color("d4a52a"), 0.25), Vector3(0, y, 0))
	for s in [-1.0, 1.0]:
		# crescent blade: outer arc + inner arc
		var pts := PackedVector2Array()
		var n := 9
		for i in n + 1:
			var a := lerpf(-1.05, 1.05, float(i) / n)
			pts.append(Vector2(y + sin(a) * 0.14, s * (0.03 + cos(a) * 0.15)))
		for i in range(n, -1, -1):
			var a2 := lerpf(-0.8, 0.8, float(i) / n)
			pts.append(Vector2(y + sin(a2) * 0.08, s * (0.03 + cos(a2) * 0.07)))
		LowPoly.mesh_instance(root, prism(pts, 0.018, STEEL), steel(Color("dfe4ea"), 0.2), Vector3.ZERO)
	LowPoly.mesh_instance(root, LowPoly.blob(0.025, 0.0, 1), LowPoly.mat(Color("d4a52a"), 0.25), Vector3(0, y + 0.09, 0))


## Timber auger: forest-green body with a wooden grip and a wide wood-boring auger bit (lead screw + spiral flights).
static func _drill(root: Node3D) -> void:
	var green := LowPoly.mat(Color("2f7d4a"), 0.5)
	var black := LowPoly.mat(Color("222428"), 0.6)
	var wood := LowPoly.mat(Color("a0703c"), 0.7)
	# wooden pistol grip, body, battery
	LowPoly.mesh_instance(root, LowPoly.box(Vector3(0.045, 0.12, 0.05)), wood, Vector3(0, 0.02, 0), Vector3(-12, 0, 0))
	LowPoly.mesh_instance(root, LowPoly.box(Vector3(0.07, 0.035, 0.09)), black, Vector3(0, -0.055, 0.01))
	LowPoly.mesh_instance(root, LowPoly.box(Vector3(0.062, 0.078, 0.18)), green, Vector3(0, 0.11, -0.03))
	LowPoly.mesh_instance(root, LowPoly.box(Vector3(0.064, 0.02, 0.18)), LowPoly.mat(Color("d4a52a"), 0.4), Vector3(0, 0.152, -0.03))
	LowPoly.mesh_instance(root, LowPoly.box(Vector3(0.02, 0.03, 0.012)), LowPoly.mat(Color("c0392b")), Vector3(0, 0.05, -0.03))
	LowPoly.mesh_instance(root, LowPoly.cyl(0.026, 0.03, 0.05, 8), black, Vector3(0, 0.11, -0.145), Vector3(90, 0, 0))
	# auger bit (spins while drilling): shaft, wide spiral flights, threaded lead screw
	var bit := Node3D.new()
	bit.name = "Bit"
	bit.position = Vector3(0, 0.11, -0.17)
	root.add_child(bit)
	LowPoly.mesh_instance(bit, LowPoly.cyl(0.008, 0.008, 0.2, 6), steel(STEEL, 0.2), Vector3(0, 0, -0.1), Vector3(90, 0, 0))
	for k in 12:
		LowPoly.mesh_instance(bit, LowPoly.box(Vector3(0.07, 0.006, 0.012)), steel(Color("d9a441"), 0.25), Vector3(0, 0, -0.03 - k * 0.013), Vector3(0, 0, k * 30.0))
	LowPoly.mesh_instance(bit, LowPoly.cyl(0.0, 0.01, 0.04, 6), steel(STEEL, 0.2), Vector3(0, 0, -0.21), Vector3(-90, 0, 0))


static func _phone(root: Node3D) -> void:
	LowPoly.mesh_instance(root, LowPoly.box(Vector3(0.075, 0.15, 0.012)), LowPoly.mat(Color("1c1f26"), 0.4), Vector3(0, 0.075, 0))
	LowPoly.mesh_instance(root, LowPoly.box(Vector3(0.066, 0.13, 0.002)), LowPoly.mat(Color("3fa66b"), 0.3, 0.8), Vector3(0, 0.075, -0.007))
	LowPoly.mesh_instance(root, LowPoly.box(Vector3(0.03, 0.006, 0.003)), LowPoly.mat(Color("eeeeee")), Vector3(0, 0.14, -0.008))


## Bow saw: grip at the origin, a tubular steel bow arching over a thin toothed blade that runs forward (-Z).
static func _saw(root: Node3D) -> void:
	var orange := LowPoly.mat(Color("e8642b"), 0.45)
	LowPoly.mesh_instance(root, LowPoly.box(Vector3(0.036, 0.11, 0.045)), LowPoly.mat(Color("2b2d33"), 0.7), Vector3(0, 0.0, 0.0))
	# blade along -Z at grip height + teeth on the underside
	var len := 0.62
	LowPoly.mesh_instance(root, LowPoly.box(Vector3(0.004, 0.035, len)), steel(Color("dfe3e8"), 0.25), Vector3(0, 0.05, -len * 0.5 - 0.02))
	var teeth := PackedVector2Array()
	var n := 22
	for i in n + 1:
		var z := -0.02 - len * float(i) / n
		teeth.append(Vector2(0.034 if i % 2 == 0 else 0.018, z))
	teeth.append(Vector2(0.034, -0.02 - len))
	teeth.append(Vector2(0.04, -0.02 - len))
	teeth.append(Vector2(0.04, -0.02))
	LowPoly.mesh_instance(root, prism(teeth, 0.005, STEEL), steel(Color("bfc5cc"), 0.3), Vector3.ZERO)
	# the bow: segments of a tube arching from the grip end to the tip
	var pts: Array[Vector3] = []
	for i in 9:
		var t := float(i) / 8.0
		pts.append(Vector3(0, 0.06 + sin(t * PI) * 0.2 + t * 0.0, -0.01 - t * (len + 0.02)))
	for i in 8:
		var a := pts[i]
		var b := pts[i + 1]
		var mid := (a + b) * 0.5
		var d := b - a
		var mi := LowPoly.mesh_instance(root, LowPoly.cyl(0.011, 0.011, d.length() + 0.012, 6), orange, mid)
		mi.basis = Basis(Vector3.UP.cross(d.normalized()).normalized(), Vector3.UP.angle_to(d.normalized())) if Vector3.UP.cross(d.normalized()).length() > 0.001 else Basis()


## Stick leaf vacuum: pistol grip with a motor pod on top and a long tube to a wide nozzle (-Z).
static func _vacuum(root: Node3D) -> void:
	var green := LowPoly.mat(Color("3aa66b"), 0.45)
	var black := LowPoly.mat(Color("222428"), 0.6)
	LowPoly.mesh_instance(root, LowPoly.box(Vector3(0.04, 0.11, 0.045)), black, Vector3(0, 0.0, 0), Vector3(-10, 0, 0))
	LowPoly.mesh_instance(root, LowPoly.cyl(0.07, 0.07, 0.2, 10), green, Vector3(0, 0.1, 0.03), Vector3(90, 0, 0))
	LowPoly.mesh_instance(root, LowPoly.cyl(0.072, 0.072, 0.03, 10), black, Vector3(0, 0.1, 0.13), Vector3(90, 0, 0))
	for k in 4:
		LowPoly.mesh_instance(root, LowPoly.box(Vector3(0.1, 0.008, 0.02)), black, Vector3(0, 0.1, 0.07 - k * 0.03), Vector3(0, 0, 45.0 * k))
	LowPoly.mesh_instance(root, LowPoly.cyl(0.03, 0.035, 0.5, 8), LowPoly.mat(Color("c9ced6"), 0.35), Vector3(0, 0.1, -0.32), Vector3(90, 0, 0))
	LowPoly.mesh_instance(root, LowPoly.cyl(0.075, 0.035, 0.12, 8), green, Vector3(0, 0.1, -0.62), Vector3(90, 0, 0))
	LowPoly.mesh_instance(root, LowPoly.cyl(0.062, 0.062, 0.01, 8), black, Vector3(0, 0.1, -0.68), Vector3(90, 0, 0))


## Claw hammer: handle along +Y, striking face toward -Z, claw curling back toward +Z.
static func _hammer(root: Node3D) -> void:
	_handle(root, 0.34, 0.015, Color("c08a4e"))
	LowPoly.mesh_instance(root, LowPoly.cyl(0.019, 0.019, 0.12, 7), LowPoly.mat(Color("2b2d33"), 0.8), Vector3(0, 0.0, 0))
	var y := 0.3
	LowPoly.mesh_instance(root, LowPoly.box(Vector3(0.036, 0.045, 0.06)), steel(DARK_STEEL), Vector3(0, y, 0))
	LowPoly.mesh_instance(root, LowPoly.cyl(0.024, 0.02, 0.06, 8), steel(), Vector3(0, y, -0.06), Vector3(90, 0, 0))
	LowPoly.mesh_instance(root, LowPoly.cyl(0.026, 0.026, 0.008, 8), steel(Color("f2f5f8"), 0.1), Vector3(0, y, -0.092), Vector3(90, 0, 0))
	for s in [-1.0, 1.0]:
		var claw := PackedVector2Array([Vector2(y + 0.02, 0.025), Vector2(y + 0.012, 0.06), Vector2(y - 0.01, 0.1), Vector2(y - 0.03, 0.115), Vector2(y - 0.015, 0.09), Vector2(y - 0.005, 0.055), Vector2(y - 0.012, 0.025)])
		LowPoly.mesh_instance(root, prism(claw, 0.012, STEEL), steel(), Vector3(s * 0.009, 0, 0))


## Pruning shears: two halves pivoting about a bolt; nodes "BladeA"/"BladeB" rotate about X to open/shut.
## Blades point forward (-Z) from the pivot, red handles run back to the grip at the origin.
static func _shears(root: Node3D) -> void:
	var red := LowPoly.mat(Color("c0392b"), 0.5)
	var pivot := Vector3(0, 0.05, -0.16)
	for s in [-1.0, 1.0]:
		var half := Node3D.new()
		half.name = "BladeA" if s < 0 else "BladeB"
		half.position = pivot
		root.add_child(half)
		# blade: a long tapering prism, flat side facing the other blade
		# blades are side-by-side plates turning about the bolt (X axis): jaws open up/down
		var blade := PackedVector2Array([Vector2(0.0, 0.0), Vector2(-s * 0.02, -0.02), Vector2(-s * 0.01, -0.2), Vector2(s * 0.004, -0.2), Vector2(s * 0.01, -0.02)])
		LowPoly.mesh_instance(half, prism(blade, 0.006, STEEL), steel(), Vector3(s * 0.004, 0, 0))
		# handle back toward the grip
		LowPoly.mesh_instance(half, LowPoly.box(Vector3(0.016, 0.02, 0.17)), red, Vector3(s * 0.012, -0.03, 0.09), Vector3(18, 0, 0))
		LowPoly.mesh_instance(half, LowPoly.box(Vector3(0.02, 0.026, 0.05)), LowPoly.mat(Color("2b2d33"), 0.7), Vector3(s * 0.014, -0.058, 0.17), Vector3(18, 0, 0))
	LowPoly.mesh_instance(root, LowPoly.cyl(0.01, 0.01, 0.03, 6), steel(Color("d4a52a"), 0.3), pivot, Vector3(0, 0, 90))


## Bark spud: a flat, wide spade-like blade on a long handle; the straight edge faces -Z.
static func _scraper(root: Node3D) -> void:
	_handle(root, 0.5, 0.017, Color("8a6a45"))
	var y := 0.48
	LowPoly.mesh_instance(root, LowPoly.cyl(0.02, 0.024, 0.06, 7), steel(DARK_STEEL), Vector3(0, y, 0))
	var blade := PackedVector2Array([Vector2(y - 0.05, 0.0), Vector2(y + 0.05, 0.0), Vector2(y + 0.075, -0.13), Vector2(y - 0.075, -0.13)])
	LowPoly.mesh_instance(root, prism(blade, 0.012, STEEL), steel(), Vector3.ZERO)
	LowPoly.mesh_instance(root, LowPoly.box(Vector3(0.014, 0.15, 0.006)), steel(Color("f2f5f8"), 0.1), Vector3(0, y, -0.131))


## Gouge: a short handle with a brass ferrule and a curved U-channel blade.
static func _gouge(root: Node3D) -> void:
	_handle(root, 0.32, 0.018, Color("6b4428"))
	var y := 0.3
	LowPoly.mesh_instance(root, LowPoly.cyl(0.022, 0.022, 0.03, 8), steel(Color("d4a52a"), 0.3), Vector3(0, y, 0))
	for k in 7:
		var a := lerpf(-1.3, 1.3, k / 6.0)
		LowPoly.mesh_instance(root, LowPoly.box(Vector3(0.012, 0.02, 0.1)), steel(Color("e8b45a"), 0.25), Vector3(sin(a) * 0.028, y + 0.01 + cos(a) * 0.028 - 0.028, -0.05))
	LowPoly.mesh_instance(root, LowPoly.box(Vector3(0.06, 0.006, 0.006)), steel(Color("fff4d8"), 0.1), Vector3(0, y + 0.002, -0.1))


## Ringing axe: a long red handle and one big sweeping crescent with a hole punched through it.
static func _ringer(root: Node3D) -> void:
	_handle(root, 0.68, 0.019, Color("a8322c"))
	var y := 0.58
	var pts := PackedVector2Array()
	for i in 13:
		var a := lerpf(-1.25, 1.25, i / 12.0)
		pts.append(Vector2(y + sin(a) * 0.17, -0.02 - cos(a) * 0.17))
	pts.append(Vector2(y + 0.08, -0.02))
	pts.append(Vector2(y - 0.08, -0.02))
	LowPoly.mesh_instance(root, prism(pts, 0.016, STEEL), steel(Color("dfe4ea"), 0.2), Vector3.ZERO)
	LowPoly.mesh_instance(root, LowPoly.cyl(0.035, 0.035, 0.02, 10), LowPoly.mat(Color("2b2d33")), Vector3(0, y, -0.1), Vector3(0, 0, 90))
	LowPoly.mesh_instance(root, LowPoly.box(Vector3(0.04, 0.08, 0.05)), steel(DARK_STEEL), Vector3(0, y, 0))


## One of the twin hatchets: small, green-handled.
static func _twin(root: Node3D) -> void:
	_handle(root, 0.34, 0.015, Color("3f7f4a"))
	var y := 0.27
	LowPoly.mesh_instance(root, LowPoly.box(Vector3(0.03, 0.05, 0.045)), steel(DARK_STEEL), Vector3(0, y, 0.0))
	var blade := PackedVector2Array([Vector2(y - 0.025, -0.02), Vector2(y + 0.025, -0.02), Vector2(y + 0.045, -0.09), Vector2(y - 0.04, -0.09)])
	LowPoly.mesh_instance(root, prism(blade, 0.018, STEEL), steel(), Vector3.ZERO)
	LowPoly.mesh_instance(root, LowPoly.box(Vector3(0.007, 0.085, 0.005)), steel(Color("f2f5f8"), 0.1), Vector3(0, y + 0.002, -0.091))


## Greataxe: long dark handle, one enormous bearded blade, gold rivets.
static func _greataxe(root: Node3D) -> void:
	_handle(root, 0.95, 0.024, Color("3b2a22"), -0.2)
	for k in 2:
		LowPoly.mesh_instance(root, LowPoly.cyl(0.028, 0.028, 0.06, 7), LowPoly.mat(Color("7a4a2a"), 1.0), Vector3(0, -0.1 + k * 0.12, 0))
	var y := 0.66
	LowPoly.mesh_instance(root, LowPoly.box(Vector3(0.05, 0.12, 0.08)), steel(DARK_STEEL), Vector3(0, y, 0))
	var blade := PackedVector2Array([Vector2(y - 0.05, -0.03), Vector2(y + 0.06, -0.03), Vector2(y + 0.16, -0.22), Vector2(y + 0.05, -0.27), Vector2(y - 0.14, -0.25), Vector2(y - 0.2, -0.16)])
	LowPoly.mesh_instance(root, prism(blade, 0.026, Color("8d949e")), steel(Color("8d949e"), 0.35), Vector3.ZERO)
	LowPoly.mesh_instance(root, LowPoly.box(Vector3(0.01, 0.36, 0.008)), steel(Color("f2f5f8"), 0.1), Vector3(0, y - 0.02, -0.255), Vector3(-15, 0, 0))
	for k in 2:
		LowPoly.mesh_instance(root, LowPoly.cyl(0.012, 0.012, 0.03, 6), steel(Color("d4a52a"), 0.3), Vector3(0, y - 0.03 + k * 0.06, -0.06), Vector3(0, 0, 90))


## Combo axe: a sleek hatchet with a glowing rune stripe ("Glow") that brightens as the combo builds.
static func _combo(root: Node3D) -> void:
	_handle(root, 0.44, 0.016, Color("2b2d33"))
	var y := 0.35
	LowPoly.mesh_instance(root, LowPoly.box(Vector3(0.034, 0.06, 0.055)), steel(DARK_STEEL), Vector3(0, y, 0.0))
	var blade := PackedVector2Array([Vector2(y - 0.03, -0.025), Vector2(y + 0.035, -0.025), Vector2(y + 0.07, -0.12), Vector2(y - 0.06, -0.125)])
	LowPoly.mesh_instance(root, prism(blade, 0.02, Color("b8c4d6")), steel(Color("b8c4d6"), 0.2), Vector3.ZERO)
	var glow_mat := StandardMaterial3D.new()
	glow_mat.albedo_color = Color("4fc3ff")
	glow_mat.emission_enabled = true
	glow_mat.emission = Color("4fc3ff")
	glow_mat.emission_energy_multiplier = 0.4
	var g := LowPoly.mesh_instance(root, LowPoly.box(Vector3(0.024, 0.012, 0.08)), glow_mat, Vector3(0, y + 0.005, -0.06))
	g.name = "Glow"


static func _glow(c: Color, e: float = 1.5) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = e
	return m


## Robo-axe: a gunmetal handle with a servo housing, a piston arm and a wide carbide blade, cyan lights.
static func _robo(root: Node3D) -> void:
	var gun := steel(Color("4a505a"), 0.35)
	var dark := LowPoly.mat(Color("1c1f26"), 0.5)
	var cyan := _glow(Color("4fe3ff"), 2.0)
	LowPoly.mesh_instance(root, LowPoly.box(Vector3(0.045, 0.14, 0.05)), dark, Vector3(0, 0.0, 0))
	LowPoly.mesh_instance(root, LowPoly.cyl(0.02, 0.02, 0.42, 8), gun, Vector3(0, 0.28, 0))
	for k in 3:
		LowPoly.mesh_instance(root, LowPoly.box(Vector3(0.05, 0.012, 0.05)), cyan, Vector3(0, 0.1 + k * 0.1, 0))
	var y := 0.5
	LowPoly.mesh_instance(root, LowPoly.box(Vector3(0.08, 0.1, 0.12)), dark, Vector3(0, y, 0.02))
	LowPoly.mesh_instance(root, LowPoly.cyl(0.035, 0.035, 0.09, 10), gun, Vector3(0, y, 0.02), Vector3(0, 0, 90))
	LowPoly.mesh_instance(root, LowPoly.cyl(0.018, 0.018, 0.1, 8), steel(Color("c9ced6"), 0.2), Vector3(0, y, -0.06), Vector3(90, 0, 0))
	var blade := PackedVector2Array([Vector2(y - 0.06, -0.09), Vector2(y + 0.06, -0.09), Vector2(y + 0.1, -0.2), Vector2(y - 0.1, -0.2)])
	LowPoly.mesh_instance(root, prism(blade, 0.02, Color("8d949e")), steel(Color("8d949e"), 0.25), Vector3.ZERO)
	LowPoly.mesh_instance(root, LowPoly.box(Vector3(0.012, 0.2, 0.008)), cyan, Vector3(0, y, -0.202))
	LowPoly.mesh_instance(root, LowPoly.box(Vector3(0.082, 0.02, 0.06)), cyan, Vector3(0, y + 0.052, 0.04))


## Chainsaw: an orange engine body with a rear handle, a top handle and a long guide bar with a chain.
static func _chainsaw(root: Node3D) -> void:
	var orange := LowPoly.mat(Color("e8642b"), 0.45)
	var dark := LowPoly.mat(Color("222428"), 0.6)
	LowPoly.mesh_instance(root, LowPoly.box(Vector3(0.04, 0.1, 0.04)), dark, Vector3(0, 0.0, 0))
	LowPoly.mesh_instance(root, LowPoly.box(Vector3(0.11, 0.13, 0.2)), orange, Vector3(0, 0.08, -0.12))
	LowPoly.mesh_instance(root, LowPoly.box(Vector3(0.112, 0.04, 0.08)), dark, Vector3(0, 0.12, -0.06))
	LowPoly.mesh_instance(root, LowPoly.cyl(0.012, 0.012, 0.13, 6), dark, Vector3(0, 0.18, -0.12), Vector3(0, 0, 90))
	for sx in [-1.0, 1.0]:
		LowPoly.mesh_instance(root, LowPoly.box(Vector3(0.012, 0.06, 0.012)), dark, Vector3(sx * 0.06, 0.15, -0.12))
	LowPoly.mesh_instance(root, LowPoly.box(Vector3(0.012, 0.07, 0.5)), steel(Color("bfc5cc"), 0.3), Vector3(0, 0.07, -0.47))
	var chain := Node3D.new()
	chain.name = "Bit"
	chain.position = Vector3(0, 0.07, -0.47)
	root.add_child(chain)
	for k in 18:
		var z := -0.24 + k * 0.028
		LowPoly.mesh_instance(chain, LowPoly.box(Vector3(0.016, 0.012, 0.016)), dark, Vector3(0, 0.04, z))
		LowPoly.mesh_instance(chain, LowPoly.box(Vector3(0.016, 0.012, 0.016)), dark, Vector3(0, -0.04, z))


## Buck saw: an H-shaped wooden frame tensioned by a twisted cord, the blade across the bottom.
static func _bucksaw(root: Node3D) -> void:
	var wood := LowPoly.mat(Color("b98a52"), 0.8)
	var cord := LowPoly.mat(Color("c9b48a"), 0.9)
	var len := 0.7
	for z in [0.0, -len]:
		LowPoly.mesh_instance(root, LowPoly.box(Vector3(0.03, 0.34, 0.035)), wood, Vector3(0, 0.12, z))
	LowPoly.mesh_instance(root, LowPoly.box(Vector3(0.025, 0.03, len)), wood, Vector3(0, 0.14, -len * 0.5))
	LowPoly.mesh_instance(root, LowPoly.box(Vector3(0.006, 0.006, len)), cord, Vector3(0.01, 0.27, -len * 0.5))
	LowPoly.mesh_instance(root, LowPoly.box(Vector3(0.006, 0.006, len)), cord, Vector3(-0.01, 0.275, -len * 0.5))
	LowPoly.mesh_instance(root, LowPoly.box(Vector3(0.004, 0.03, len)), steel(Color("dfe3e8"), 0.25), Vector3(0, -0.03, -len * 0.5))
	var teeth := PackedVector2Array()
	for i in 29:
		teeth.append(Vector2(-0.045 if i % 2 == 0 else -0.06, -len * float(i) / 28.0))
	teeth.append(Vector2(-0.04, -len))
	teeth.append(Vector2(-0.04, 0.0))
	LowPoly.mesh_instance(root, prism(teeth, 0.004, STEEL), steel(Color("bfc5cc"), 0.3), Vector3.ZERO)


## Twin auger: a wide gearbox carrying two spinning bits side by side ("Bit" spins both).
static func _twin_auger(root: Node3D) -> void:
	var blue := LowPoly.mat(Color("2e6fb3"), 0.5)
	var dark := LowPoly.mat(Color("222428"), 0.6)
	LowPoly.mesh_instance(root, LowPoly.box(Vector3(0.045, 0.12, 0.05)), dark, Vector3(0, 0.02, 0), Vector3(-12, 0, 0))
	LowPoly.mesh_instance(root, LowPoly.box(Vector3(0.07, 0.08, 0.17)), blue, Vector3(0, 0.11, -0.03))
	LowPoly.mesh_instance(root, LowPoly.box(Vector3(0.24, 0.06, 0.06)), dark, Vector3(0, 0.11, -0.13))
	var bit := Node3D.new()
	bit.name = "Bit"
	bit.position = Vector3(0, 0.11, -0.16)
	root.add_child(bit)
	for sx in [-0.09, 0.09]:
		LowPoly.mesh_instance(bit, LowPoly.cyl(0.007, 0.007, 0.18, 6), steel(STEEL, 0.2), Vector3(sx, 0, -0.09), Vector3(90, 0, 0))
		for k in 9:
			LowPoly.mesh_instance(bit, LowPoly.box(Vector3(0.05, 0.005, 0.01)), steel(Color("d9a441"), 0.25), Vector3(sx, 0, -0.02 - k * 0.016), Vector3(0, 0, k * 40.0 * (1.0 if sx > 0 else -1.0)))


## Hole saw: a stubby drill driving a wide toothed steel cup.
static func _holesaw(root: Node3D) -> void:
	var red := LowPoly.mat(Color("b3262e"), 0.5)
	var dark := LowPoly.mat(Color("222428"), 0.6)
	LowPoly.mesh_instance(root, LowPoly.box(Vector3(0.045, 0.12, 0.05)), dark, Vector3(0, 0.02, 0), Vector3(-12, 0, 0))
	LowPoly.mesh_instance(root, LowPoly.box(Vector3(0.065, 0.075, 0.14)), red, Vector3(0, 0.11, -0.02))
	var bit := Node3D.new()
	bit.name = "Bit"
	bit.position = Vector3(0, 0.11, -0.1)
	root.add_child(bit)
	LowPoly.mesh_instance(bit, LowPoly.cyl(0.01, 0.01, 0.06, 6), steel(STEEL, 0.2), Vector3(0, 0, -0.03), Vector3(90, 0, 0))
	LowPoly.mesh_instance(bit, LowPoly.cyl(0.07, 0.07, 0.07, 14), steel(Color("c9ced6"), 0.25), Vector3(0, 0, -0.09), Vector3(90, 0, 0))
	for k in 12:
		var a := TAU * k / 12.0
		LowPoly.mesh_instance(bit, LowPoly.cyl(0.0, 0.01, 0.02, 4), steel(Color("f2f5f8"), 0.1), Vector3(cos(a) * 0.066, sin(a) * 0.066, -0.135), Vector3(-90, 0, 0))


## Twin-nozzle vac: a motor pod feeding a forked tube with two intakes, left and right.
static func _twinvac(root: Node3D) -> void:
	var teal := LowPoly.mat(Color("1f8a8a"), 0.45)
	var black := LowPoly.mat(Color("222428"), 0.6)
	LowPoly.mesh_instance(root, LowPoly.box(Vector3(0.04, 0.11, 0.045)), black, Vector3(0, 0.0, 0), Vector3(-10, 0, 0))
	LowPoly.mesh_instance(root, LowPoly.cyl(0.075, 0.075, 0.22, 10), teal, Vector3(0, 0.1, 0.03), Vector3(90, 0, 0))
	LowPoly.mesh_instance(root, LowPoly.cyl(0.035, 0.035, 0.22, 8), LowPoly.mat(Color("c9ced6"), 0.35), Vector3(0, 0.1, -0.19), Vector3(90, 0, 0))
	LowPoly.mesh_instance(root, LowPoly.box(Vector3(0.12, 0.06, 0.06)), teal, Vector3(0, 0.1, -0.32))
	for sx in [-1.0, 1.0]:
		LowPoly.mesh_instance(root, LowPoly.cyl(0.03, 0.03, 0.28, 8), LowPoly.mat(Color("c9ced6"), 0.35), Vector3(sx * 0.11, 0.1, -0.45), Vector3(90, sx * 18.0, 0))
		LowPoly.mesh_instance(root, LowPoly.cyl(0.06, 0.03, 0.09, 8), teal, Vector3(sx * 0.16, 0.1, -0.61), Vector3(90, sx * 18.0, 0))
		LowPoly.mesh_instance(root, LowPoly.cyl(0.05, 0.05, 0.01, 8), black, Vector3(sx * 0.17, 0.1, -0.66), Vector3(90, sx * 18.0, 0))


## Cyclone vac: a clear dust bin with a swirling vortex inside ("Bit" spins) and a long narrow snout.
static func _cyclone(root: Node3D) -> void:
	var purple := LowPoly.mat(Color("6b3fa0"), 0.45)
	var black := LowPoly.mat(Color("222428"), 0.6)
	var clear := StandardMaterial3D.new()
	clear.albedo_color = Color(0.8, 0.9, 1.0, 0.3)
	clear.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	LowPoly.mesh_instance(root, LowPoly.box(Vector3(0.04, 0.11, 0.045)), black, Vector3(0, 0.0, 0), Vector3(-10, 0, 0))
	LowPoly.mesh_instance(root, LowPoly.cyl(0.06, 0.06, 0.08, 10), purple, Vector3(0, 0.1, 0.1), Vector3(90, 0, 0))
	LowPoly.mesh_instance(root, LowPoly.cyl(0.07, 0.05, 0.16, 12), clear, Vector3(0, 0.1, -0.02), Vector3(90, 0, 0))
	var swirl := Node3D.new()
	swirl.name = "Bit"
	swirl.position = Vector3(0, 0.1, -0.02)
	root.add_child(swirl)
	for k in 6:
		var a := TAU * k / 6.0
		LowPoly.mesh_instance(swirl, LowPoly.box(Vector3(0.012, 0.012, 0.12)), _glow(Color("c79bff"), 1.2), Vector3(cos(a) * 0.035, sin(a) * 0.035, 0), Vector3(0, 0, rad_to_deg(a)))
	LowPoly.mesh_instance(root, LowPoly.cyl(0.022, 0.03, 0.6, 8), LowPoly.mat(Color("c9ced6"), 0.35), Vector3(0, 0.1, -0.4), Vector3(90, 0, 0))
	LowPoly.mesh_instance(root, LowPoly.cyl(0.04, 0.022, 0.06, 8), purple, Vector3(0, 0.1, -0.72), Vector3(90, 0, 0))
