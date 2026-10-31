class_name Wireless
extends Machine
## A transmitter and receiver pair with no wire between them, at any distance. Set both to the same channel (E):
## while any transmitter on a channel has power, every receiver on that channel gives power out.

const CHANNELS := [Color("e8503a"), Color("3fa66b"), Color("3f8ee8"), Color("f2c12e"), Color("9b6ad6"), Color("f08a2e"),
	Color("eeeeee"), Color("f06fb0")]
const NAMES := ["red", "green", "blue", "yellow", "purple", "orange", "white", "pink"]

var kind := "transmitter"
var channel := 0


func activate(p_size: float) -> void:
	super(p_size)
	kind = String(get_meta("build").id) if has_meta("build") else kind
	add_to_group("transmitters" if kind == "transmitter" else "receivers")
	add_lamp(Vector3(0.18, 0.15, 0.18))
	_paint()


func is_source() -> bool:
	return kind == "receiver" and channel_on(get_tree(), channel)


## Whether any transmitter on a channel has power right now (receivers and drones listen for this).
static func channel_on(tree: SceneTree, ch: int) -> bool:
	for t in tree.get_nodes_in_group("transmitters"):
		var tx := t as Wireless
		if is_instance_valid(tx) and tx.channel == ch and tx.powered:
			return true
	return false


## Neither passes power through from a wire: a receiver is a source of its own (so on a cart it can't be fed by the
## cart's battery and switch the cart by accident), and a transmitter is where a signal ends.
func conducts() -> bool:
	return false


func terminal() -> Vector3:
	return Vector3(0.18, 0.25, 0.18) * size


func hint_text() -> String:
	return "%s  ·  %s channel  ·  %s    [E] change channel" % ["Transmitter" if kind == "transmitter" else "Receiver", NAMES[channel],
		("sending" if powered else "no power") if kind == "transmitter" else ("receiving" if is_source() else "nothing on this channel")]


func on_use(_player: Node) -> void:
	channel = (channel + 1) % CHANNELS.size()
	_paint()
	Sfx.play("click", 0.9 + channel * 0.1, -4.0)


func _paint() -> void:
	var gem := get_node_or_null("Model/Gem") as MeshInstance3D
	if gem != null:
		var m := StandardMaterial3D.new()
		m.albedo_color = CHANNELS[channel]
		m.emission_enabled = true
		m.emission = CHANNELS[channel]
		m.emission_energy_multiplier = 1.2
		gem.material_override = m


func save_state() -> Dictionary:
	return {"ch": channel}


func load_state(d: Dictionary) -> void:
	channel = clampi(int(d.get("ch", 0)), 0, CHANNELS.size() - 1)
	_paint()
