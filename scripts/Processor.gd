class_name Processor
extends Machine
## Machines that turn one thing into another: drop inputs into the hopper (by hand, off a belt, from a grabber arm),
## power it, and the product comes out of the front.
##   smelter   - copper ore -> copper bar, iron ore -> iron bar
##   kiln      - plank -> dried plank (worth more)
##   assembler - planks and bars -> furniture (E picks what it makes); furniture sells for 2.5x what went in

const RECIPES := {
	"chair": {"plank": 2},
	"table": {"plank": 4, "iron_bar": 1},
	"lantern": {"copper_bar": 1, "plank": 1},
	"cabinet": {"plank": 6, "copper_bar": 1},
	"toy_truck": {"plank": 2, "iron_bar": 1},
	"battery_cell": {"copper_bar": 1, "iron_bar": 1},
	"rail": {"iron_bar": 1},
	"curved_rail": {"iron_bar": 1},
	"lawn_chair": {"plastic": 2},
	"bucket": {"plastic": 1, "iron_bar": 1},
}
const RECIPE_ORDER := ["chair", "table", "lantern", "cabinet", "toy_truck", "lawn_chair", "bucket", "battery_cell", "rail", "curved_rail"]
## Parts rather than furniture: they're for using, so they sell for little more than what went in.
const PART_VALUE := {"battery_cell": 1.2, "rail": 0.7, "curved_rail": 0.7}
const MAKES := {"rail": 2}
const WORK_TIME := {"smelter": 3.0, "kiln": 4.0, "assembler": 3.0, "refinery": 4.0}

var kind := "smelter"
var recipe := 0
var queue: Array = []           # [{out, value, color}] waiting to come out
var have := {}                  # assembler: inputs collected so far (res -> count)
var have_value := 0.0
var _color := Color("a0703c")
var _work := 0.0
var _fx := 0.0


func activate(p_size: float) -> void:
	super(p_size)
	kind = String(get_meta("build").id) if has_meta("build") else kind
	add_lamp(Vector3(0.4, 0.3, 0.4))


func terminal() -> Vector3:
	return Vector3(0.4, 0.45, 0.4) * size


static func res_of(b: Node) -> String:
	if b is Product and (b as Product).kind == "plastic":
		return "plastic"
	if b is Product:
		return String(Product.KINDS[(b as Product).kind].res)
	if b is Ore:
		return (b as Ore).kind
	return ""


func hint_text() -> String:
	match kind:
		"smelter":
			return "Smelter  ·  copper or iron ore in, bars out%s" % ("  ·  %d waiting" % queue.size() if not queue.is_empty() else "")
		"kiln":
			return "Kiln  ·  planks in, dried planks out%s" % ("  ·  %d drying" % queue.size() if not queue.is_empty() else "")
		"refinery":
			return "Refinery  ·  a barrel of oil in, a fuel can and a plastic sheet out%s" % ("  ·  %d waiting" % queue.size() if not queue.is_empty() else "")
	var r: String = RECIPE_ORDER[recipe]
	var parts: Array[String] = []
	for res in RECIPES[r]:
		parts.append("%d/%d %s" % [int(have.get(res, 0)), int(RECIPES[r][res]), Builds.RES_NAME.get(res, res)])
	var what := "2 rails" if r == "rail" else "a " + String(Product.KINDS[r].name).to_lower()
	return "Assembler  ·  making %s  ·  %s    [E] change" % [what, ", ".join(parts)]


func on_use(_player: Node) -> void:
	if kind != "assembler":
		return
	# switching drops back out what was collected for the old recipe (as value: it's already been used up)
	recipe = (recipe + 1) % RECIPE_ORDER.size()
	have = {}
	have_value = 0.0
	Sfx.play("click", 0.9 + recipe * 0.08, -4.0)


func _accepts(b: Node) -> bool:
	var r := res_of(b)
	match kind:
		"smelter":
			return r == "copper" or r == "iron"
		"kiln":
			return b is Product and (b as Product).kind == "plank"
		"refinery":
			return b is Product and (b as Product).kind == "oil_barrel"
		"assembler":
			var need: Dictionary = RECIPES[RECIPE_ORDER[recipe]]
			return need.has(r) and int(have.get(r, 0)) < int(need[r])
	return false


func _physics_process(delta: float) -> void:
	if not powered:
		return
	if queue.size() < 6:
		for b in bodies_in(Vector3(0, 1.0, 0), Vector3(0.75, 0.5, 0.75)):
			if _accepts(b):
				_take(b)
	if queue.is_empty():
		_work = 0.0
		return
	_work += delta
	_fx -= delta
	if _fx <= 0.0:
		_fx = 0.3
		var c := Color("ff9a3d") if kind != "assembler" else Color("d9b98a")
		Nature.burst(get_parent(), global_transform * Vector3(0, 0.9, 0), Vector3.UP, c, 4, 1.0, 0.025, -0.5, 0.6, 60.0, 1.5 if kind != "assembler" else 0.0)
	if _work >= float(WORK_TIME[kind]):
		_work = 0.0
		var o: Dictionary = queue.pop_front()
		var p := Product.new()
		get_parent().add_child(p)
		p.setup(String(o.out), snappedf(float(o.value), 0.01), o.color)
		p.global_transform = global_transform * Transform3D(Basis(), Vector3(0, 0.5, -0.8))
		p.linear_velocity = -global_basis.z * 1.2
		Sfx.play_at("clink" if kind == "smelter" else "thud", global_position, 1.1, -4.0)
		if o.out == "iron_bar":
			Trophies.award("first_iron")
		elif kind == "assembler":
			Trophies.award("first_furniture")


func _take(b: Node) -> void:
	var v := Truck.sale_value(b)
	var r := res_of(b)
	match kind:
		"smelter":
			queue.append({"out": r + "_bar", "value": v * 2.2, "color": Machines.COPPER})
		"kiln":
			queue.append({"out": "dry_plank", "value": v * 1.4, "color": (b as Product).color})
		"refinery":
			# the oil's worth splits over what comes out, and gains on the way
			queue.append({"out": "fuel_can", "value": v * 0.8, "color": Color.WHITE})
			queue.append({"out": "plastic", "value": v * 0.6, "color": Color.WHITE})
		"assembler":
			have[r] = int(have.get(r, 0)) + 1
			have_value += v
			if b is Product and (b as Product).kind.contains("plank"):
				_color = (b as Product).color
			var need: Dictionary = RECIPES[RECIPE_ORDER[recipe]]
			var done := true
			for res in need:
				if int(have.get(res, 0)) < int(need[res]):
					done = false
			if done:
				queue.append({"out": RECIPE_ORDER[recipe], "value": have_value * 2.5, "color": _color})
				have = {}
				have_value = 0.0
	Nature.burst(get_parent(), (b as Node3D).global_position, Vector3.UP, Color("d8d2c4"), 6, 1.0, 0.03, 4.0, 0.4)
	b.queue_free()


func save_state() -> Dictionary:
	var q: Array = []
	for o in queue:
		q.append({"out": o.out, "value": o.value, "c": (o.color as Color).to_html()})
	return {"recipe": recipe, "queue": q, "have": have, "hv": have_value}


func load_state(d: Dictionary) -> void:
	recipe = clampi(int(d.get("recipe", 0)), 0, RECIPE_ORDER.size() - 1)
	queue = []
	for o in d.get("queue", []):
		queue.append({"out": String(o.out), "value": float(o.value), "color": Color.html(String(o.c))})
	have = {}
	var h: Dictionary = d.get("have", {})
	for k in h:
		have[k] = int(h[k])
	have_value = float(d.get("hv", 0.0))
