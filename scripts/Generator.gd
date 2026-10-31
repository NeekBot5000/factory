class_name Generator
extends Machine
## Burns whatever you drop into its hopper - bark, leaves, logs, planks, mulch - and gives power while it has fuel.

const MAX_FUEL := 600.0

var fuel := 0.0
var _smoke := 0.0


func activate(p_size: float) -> void:
	super(p_size)
	add_lamp(Vector3(0.36, 0.3, 0.3))


func is_source() -> bool:
	return fuel > 0.0


func terminal() -> Vector3:
	return Vector3(0.36, 0.45, 0.3) * size


## Seconds of power something is worth as fuel.
static func burn_time(b: Node) -> float:
	if b is Chip:
		return 2.0 * (b as Chip).panels
	if b is Leaf:
		return 1.0
	if b is Log:
		return 25.0 * (b as Log).length
	if b is Product:
		return (b as Product).fuel()
	if b is Sapling:
		return 3.0
	return 0.0


func hint_text() -> String:
	return "Generator  ·  %s    drop bark, leaves or wood in the hopper" % ("%ds of fuel" % int(fuel) if fuel > 0.0 else "no fuel")


func _physics_process(delta: float) -> void:
	if fuel > 0.0:
		fuel = maxf(0.0, fuel - delta)
		_smoke -= delta
		if _smoke <= 0.0:
			_smoke = 0.25
			Nature.burst(get_parent(), global_transform * Vector3(-0.25, 1.55, 0.25), Vector3.UP, Color(0.35, 0.33, 0.32), 2, 0.6, 0.12, -0.6, 2.0, 25.0)
	# feed it: anything resting in the hopper burns
	if fuel >= MAX_FUEL:
		return
	for b in bodies_in(Vector3(0.1, 1.05, -0.05), Vector3(0.6, 0.5, 0.6)):
		var t := burn_time(b)
		if t <= 0.0:
			continue
		fuel = minf(MAX_FUEL, fuel + t)
		Nature.burst(get_parent(), b.global_position, Vector3.UP, Color("ff9a3d"), 10, 1.5, 0.03, -1.0, 0.5, 60.0, 2.5)
		Sfx.play_at("crumble", global_position, 1.6, -8.0)
		b.queue_free()


func save_state() -> Dictionary:
	return {"fuel": snappedf(fuel, 0.1)}


func load_state(d: Dictionary) -> void:
	fuel = float(d.get("fuel", 0.0))
