class_name DrillRig
extends Machine
## A drilling rig. Put a rock drill or a steel core drill into it (E while holding it; E with empty hands takes it
## back) and power it: it drills straight down by itself, and every chunk it brings up drops out of the chute at the
## front - onto a belt, or into a storage crate. It can only go so deep (deeper, and into iron, with the core drill),
## and then that spot is drilled out: move the rig.

const DRILLS := {"rock_drill": {"max": 12.0, "tier": 1, "rate": 0.12}, "core_drill": {"max": 30.0, "tier": 2, "rate": 0.2}}
const PER_CHUNK := 0.25

var tool_id := ""
var depth := 0.0
var _next := PER_CHUNK
var _bit: Node3D
var _model: Node3D
var _fx := 0.0


func activate(p_size: float) -> void:
	super(p_size)
	_bit = get_node_or_null("Model/Bit")
	add_lamp(Vector3(0.45, 0.2, 0.45))


func terminal() -> Vector3:
	return Vector3(0.45, 0.35, 0.45) * size


func max_depth() -> float:
	return float(DRILLS[tool_id].max) if tool_id != "" else 0.0


func drilled_out() -> bool:
	return tool_id != "" and depth >= max_depth()


func hint_text() -> String:
	var p := get_tree().get_first_node_in_group("player")
	var t := String(p.get("tool")) if p != null else ""
	if tool_id == "":
		return "[E] put your drill in" if DRILLS.has(t) else "Drill Rig  ·  needs a rock drill or steel core drill"
	var take := "    [E] take the drill out" if t == "hands" else ""
	if drilled_out():
		return "Drill Rig  ·  drilled out at %d m - move it somewhere new%s" % [int(depth), take]
	return "Drill Rig  ·  %.1f of %d m  ·  %s%s" % [depth, int(max_depth()), Mining.layer_name(depth), take]


func on_use(player: Node) -> void:
	var t := String(player.get("tool"))
	if tool_id == "" and DRILLS.has(t):
		tool_id = player.call("hand_over_tool")
		_show_tool()
		Sfx.play("clink", 0.8, -2.0)
	elif tool_id != "" and t == "hands":
		Game.set_dropped(tool_id, false)
		player.call("equip", tool_id)
		tool_id = ""
		_show_tool()
		Sfx.play("pickup", 1.0, -2.0)


func _show_tool() -> void:
	if _model != null:
		_model.queue_free()
		_model = null
	if tool_id != "":
		_model = Tools.build_model(tool_id, self)
		_model.position = Vector3(0, 1.5, 0)
		_model.rotation_degrees = Vector3(90, 0, 0)


func _physics_process(delta: float) -> void:
	if tool_id == "" or not powered or drilled_out():
		return
	var d: Dictionary = DRILLS[tool_id]
	depth = minf(max_depth(), depth + float(d.rate) * delta)
	if _bit != null:
		_bit.rotation.y += delta * 18.0
		_bit.position.y = 0.4 + sin(Time.get_ticks_msec() * 0.03) * 0.03
	_fx -= delta
	if _fx <= 0.0:
		_fx = 0.15
		Nature.burst(get_parent(), global_position + Vector3.UP * 0.1, Vector3.UP, Color("6b5a44"), 4, 1.2, 0.03, 9.0, 0.5)
		Sfx.play_at("grind", global_position, 0.8, -12.0)
	while depth >= _next:
		_next += PER_CHUNK
		_chunk(int(d.tier))
	if drilled_out():
		Sfx.play_at("thunk", global_position, 0.7, 0.0)


func _chunk(tier: int) -> void:
	var kind := Mining.roll(global_position.x, global_position.z, depth, tier)
	var o := Ore.new()
	get_parent().add_child(o)
	o.setup(kind, randf_range(0.11, 0.15))
	o.global_transform = global_transform * Transform3D(Basis(), Vector3(randf_range(-0.1, 0.1), 0.75, -0.75))
	o.linear_velocity = -global_basis.z * 1.4 + Vector3.UP * 0.6


func on_take_down() -> void:
	if tool_id == "":
		return
	var item := ToolItem.new()
	get_parent().add_child(item)
	item.setup(tool_id)
	item.global_position = global_position + Vector3.UP * 1.0
	tool_id = ""


func save_state() -> Dictionary:
	return {"tool": tool_id, "depth": snappedf(depth, 0.01)}


func load_state(d: Dictionary) -> void:
	tool_id = String(d.get("tool", ""))
	depth = float(d.get("depth", 0.0))
	_next = (floor(depth / PER_CHUNK) + 1.0) * PER_CHUNK
	if DRILLS.has(tool_id):
		Game.set_dropped(tool_id, true)
		_show_tool()
	else:
		tool_id = ""
