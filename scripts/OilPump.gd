class_name OilPump
extends Machine
## A pumpjack. Build it over an oil pocket (the ore detector hums low over oil) and power it: its beam nods up and
## down and it fills barrels of oil, faster the richer the ground, pushing each full barrel out of its front.
## Oil burns in a generator, or goes to a refinery to become fuel cans and plastic.

const FULL_RATE := 1.0 / 25.0     # barrels a second over the richest oil
const MIN_RICH := 0.12            # below this there's nothing to pump

var fill := 0.0
var _beam: Node3D
var _phase := 0.0


func activate(p_size: float) -> void:
	super(p_size)
	_beam = get_node_or_null("Model/Beam")
	add_lamp(Vector3(0.42, 0.22, 0.42))


func richness() -> float:
	return Mining.richness("oil", global_position.x, global_position.z)


func terminal() -> Vector3:
	return Vector3(0.42, 0.3, 0.42) * size


func hint_text() -> String:
	var r := richness()
	if r < MIN_RICH:
		return "Oil Pump  ·  no oil under here - look for it with the ore detector"
	return "Oil Pump  ·  %s oil  ·  barrel %d%% full  ·  %s" % ["rich" if r > 0.6 else ("some" if r > 0.3 else "a little"), int(fill * 100.0), "pumping" if powered else "power it to pump"]


func _physics_process(delta: float) -> void:
	var r := richness()
	if not powered or r < MIN_RICH:
		return
	_phase += delta * 2.4
	if _beam != null:
		_beam.rotation.x = sin(_phase) * 0.32
	fill += FULL_RATE * r * delta
	if fill >= 1.0:
		fill = 0.0
		var b := Product.new()
		get_parent().add_child(b)
		b.setup("oil_barrel", 8.0, Color.WHITE)
		b.global_transform = global_transform * Transform3D(Basis(), Vector3(0, 0.4, -0.85))
		b.linear_velocity = -global_basis.z * 1.0
		Sfx.play_at("thud", global_position, 0.7, -4.0)
		Trophies.award("first_oil")


func save_state() -> Dictionary:
	return {"fill": snappedf(fill, 0.01)}


func load_state(d: Dictionary) -> void:
	fill = float(d.get("fill", 0.0))
