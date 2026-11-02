class_name Mining
extends RefCounted
## What's under the ground. Copper and iron lie in patches (rich in some places, poor in others); the deeper you go
## the more there is: topsoil and stone near the surface, copper from about 1.5 m down, iron from about 5 m.

const COPPER_FROM := 1.5
const IRON_FROM := 5.0
const MAX_DEPTH := 40.0

static var drilled := {}       # "x,z" grid square -> how deep drill rigs have got there (it stays drilled out)
static var _oil: FastNoiseLite
static var _copper: FastNoiseLite
static var _iron: FastNoiseLite


static func _noise(seed: int) -> FastNoiseLite:
	var n := FastNoiseLite.new()
	n.seed = seed
	n.frequency = 0.035
	return n


## How rich the ground is in copper or iron at a spot, 0..1 (the ore detector reads this).
static func richness(kind: String, x: float, z: float) -> float:
	if _copper == null:
		_copper = _noise(4141)
		_iron = _noise(9393)
		_oil = _noise(7171)
		_oil.frequency = 0.018
	if kind == "oil":
		# oil sits in a few big pockets: most ground has none at all
		return clampf(_oil.get_noise_2d(x, z) * 2.2 - 0.25, 0.0, 1.0)
	var n := (_copper if kind == "copper" else _iron).get_noise_2d(x, z)
	return clampf(n * 1.3 + 0.45, 0.0, 1.0)


## What one chunk dug out at this depth is. `tier` 2 is needed to get iron out (with less, it comes out as stone).
static func roll(x: float, z: float, depth: float, tier: int) -> String:
	if depth >= IRON_FROM and randf() < richness("iron", x, z) * clampf((depth - IRON_FROM) / 6.0 + 0.35, 0.0, 0.8):
		return "iron" if tier >= 2 else "stone"
	if depth >= COPPER_FROM and randf() < richness("copper", x, z) * clampf((depth - COPPER_FROM) / 4.0 + 0.3, 0.0, 0.7):
		return "copper"
	return "stone"


## A layer's name for hints.
static func layer_name(depth: float) -> String:
	if depth < COPPER_FROM:
		return "topsoil"
	if depth < IRON_FROM:
		return "copper layer"
	return "iron layer"


## Digs at a spot on the ground with a mining tool: finds (or starts) the shaft there and takes it deeper.
## Returns the shaft, or null if the ground can't be dug there.
static func dig(world: Node, at: Vector3, tool: String) -> Shaft:
	var d: Dictionary = Tools.TOOLS.get(tool, {})
	var power := int(d.get("mine", 0))
	if power <= 0:
		return null
	var cell := Vector3(snappedf(at.x, 1.0), 0.0, snappedf(at.z, 1.0))
	var shaft: Shaft = null
	for s in world.get_tree().get_nodes_in_group("shafts"):
		var sh := s as Shaft
		if Vector2(sh.global_position.x - cell.x, sh.global_position.z - cell.z).length() < 0.5:
			shaft = sh
			break
	if shaft == null:
		shaft = Shaft.new()
		world.add_child(shaft)
		var t: Terrain = world.get("terrain")
		cell.y = t.height_at(cell.x, cell.z) if t != null else at.y
		shaft.setup(cell)
	shaft.dig(power, int(d.get("tier", 1)))
	return shaft
