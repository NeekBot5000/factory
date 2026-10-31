class_name Feller
extends Machine
## An automatic tree feller. Put a saw into it (E while holding a bow saw, chainsaw or crosscut; E again with empty
## hands to take it back) and power it: it saws down the tree standing in front of it.

const SAWS := ["saw", "chainsaw", "crosscut"]

var saw_id := ""
var progress := 0.0
var _arm: Node3D
var _model: Node3D
var _fx := 0.0


func activate(p_size: float) -> void:
	super(p_size)
	_arm = get_node_or_null("Model/Arm")
	add_lamp(Vector3(0.38, 0.3, 0.38))


func terminal() -> Vector3:
	return Vector3(0.38, 0.45, 0.38) * size


func hint_text() -> String:
	var p := get_tree().get_first_node_in_group("player")
	var t := String(p.get("tool")) if p != null else ""
	if saw_id == "":
		return "[E] put your saw in" if t in SAWS else "Tree Feller  ·  needs a saw (bow saw, chainsaw or crosscut)"
	var target := _target()
	return "Tree Feller  ·  %s%s" % [Tools.TOOLS[saw_id].name, ("    [E] take the saw out" if t == "hands" else "") + ("  ·  %d%%" % int(progress * 100.0) if target != null and powered else "")]


func on_use(player: Node) -> void:
	var t := String(player.get("tool"))
	if saw_id == "" and t in SAWS:
		saw_id = player.call("hand_over_tool")
		_show_saw()
		Sfx.play("clink", 0.8, -2.0)
	elif saw_id != "" and t == "hands":
		Game.set_dropped(saw_id, false)
		player.call("equip", saw_id)
		saw_id = ""
		_show_saw()
		Sfx.play("pickup", 1.0, -2.0)


func _show_saw() -> void:
	if _model != null:
		_model.queue_free()
		_model = null
	if saw_id != "" and _arm != null:
		_model = Tools.build_model(saw_id, _arm)
		_model.position = Vector3(0, 0, 0)


## The standing tree right in front of it (within reach of the arm), if any.
func _target() -> ForestTree:
	var best: ForestTree = null
	var bd := 9.0
	for t in get_tree().get_nodes_in_group("trees"):
		var tr := t as ForestTree
		if tr.felled or tr.bands < 4:
			continue
		var lp := to_local(tr.global_position)
		if lp.z < -2.6 or lp.z > -0.3 or absf(lp.x) > 0.9:
			continue
		if -lp.z < bd:
			bd = -lp.z
			best = tr
	return best


func _physics_process(delta: float) -> void:
	if saw_id == "" or not powered:
		progress = maxf(0.0, progress - delta)
		return
	var tr := _target()
	if tr == null:
		progress = 0.0
		return
	var d: Dictionary = Tools.TOOLS[saw_id]
	if tr.giant and not bool(d.get("big", false)) and saw_id != "chainsaw":
		return
	if _arm != null:
		_arm.position.x = sin(Time.get_ticks_msec() * 0.012) * 0.08
	progress += delta / (Player.SAW_TREE_TIME * 1.5 * (tr.radius / 0.38)) * float(d.get("speed", 1.0))
	_fx -= delta
	if _fx <= 0.0:
		_fx = 0.08
		var at := tr.global_position + Vector3(0, 0.5, 0) + (global_position - tr.global_position).normalized() * tr.radius
		Nature.burst(get_parent(), at, Vector3.UP, tr.wood_color.lightened(0.1), 6, 1.6, 0.018, 6.0, 0.5, 60.0)
		Sfx.play_at("saw", at, 1.1, -4.0)
	if progress >= 1.0:
		progress = 0.0
		var lg := tr.fell(2, -global_basis.z)
		if d.has("clean"):
			lg.set_meta("clean", true)
		Sfx.play_at("timber", tr.global_position, 1.0, 2.0)


func on_take_down() -> void:
	if saw_id == "":
		return
	var item := ToolItem.new()
	get_parent().add_child(item)
	item.setup(saw_id)
	item.global_position = global_position + Vector3.UP * 0.8
	saw_id = ""


func save_state() -> Dictionary:
	return {"saw": saw_id}


func load_state(d: Dictionary) -> void:
	saw_id = String(d.get("saw", ""))
	if saw_id != "" and Tools.TOOLS.has(saw_id):
		Game.set_dropped(saw_id, true)
		_show_saw()
	else:
		saw_id = ""
