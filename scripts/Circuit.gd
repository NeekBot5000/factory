class_name Circuit
extends Node
## Works out which machines have power, many times a second: power starts at every active source and flows along
## wires to connected machines, passing through any machine that conducts (a switch that's off stops it there).

const TICK := 0.05

var _t := 0.0


func _physics_process(delta: float) -> void:
	_t += delta
	if _t < TICK:
		return
	_t = 0.0
	refresh()


func refresh() -> void:
	var machines := get_tree().get_nodes_in_group("machines")
	var wires := get_tree().get_nodes_in_group("wires")
	var links := {}
	for m in machines:
		links[m] = []
	for w in wires:
		var wire := w as Wire
		if wire == null or not is_instance_valid(wire.a) or not is_instance_valid(wire.b):
			continue
		if links.has(wire.a) and links.has(wire.b):
			links[wire.a].append(wire.b)
			links[wire.b].append(wire.a)
	var live := {}
	var queue: Array = []
	for m in machines:
		if (m as Machine).is_source():
			live[m] = true
			queue.append(m)
	while not queue.is_empty():
		var m: Machine = queue.pop_back()
		if not m.conducts() and not m.is_source():
			continue      # it gets power itself, but doesn't pass it on
		for n in links[m]:
			if not live.has(n):
				live[n] = true
				queue.append(n)
	for m in machines:
		(m as Machine).set_powered(live.has(m))
		(m as Machine)._update_lamp()
	for w in wires:
		var wire := w as Wire
		if wire != null and is_instance_valid(wire.a) and is_instance_valid(wire.b):
			# a wire glows when power actually flows through it
			var flows := live.has(wire.a) and live.has(wire.b) and (wire.a.conducts() or wire.a.is_source() or wire.b.conducts() or wire.b.is_source())
			wire.set_live(flows)


## Connects two machines, or takes the wire down if they're already connected. Returns "added", "removed" or "".
static func toggle_wire(world: Node, m1: Machine, m2: Machine) -> String:
	if m1 == m2:
		return ""
	for w in world.get_tree().get_nodes_in_group("wires"):
		var wire := w as Wire
		if wire.connects(m1) and wire.connects(m2):
			wire.queue_free()
			wire.remove_from_group("wires")
			return "removed"
	if m1.terminal_world().distance_to(m2.terminal_world()) > Wire.MAX_LEN:
		return ""
	var nw := Wire.new()
	world.add_child(nw)
	nw.setup(m1, m2)
	return "added"
