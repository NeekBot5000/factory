class_name Circuit
extends Node
## Works out which machines have power, many times a second: power starts at every active source and flows along
## wires to connected machines, passing through any machine that conducts (a switch that's off stops it there).

const TICK := 0.05

var _t := 0.0
var _belt_links := {}       # Conveyor -> touching conveyors (worked out again only when machines change)
var _belt_sig := -1


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
	# belts that touch pass power along to each other as if wired
	var bl := _belt_neighbours(machines)
	for m in bl:
		for n in bl[m]:
			links[m].append(n)
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


func _belt_neighbours(machines: Array) -> Dictionary:
	var sig := machines.size()
	for m in machines:
		sig = sig * 31 + (m as Object).get_instance_id()
	if sig == _belt_sig:
		return _belt_links
	_belt_sig = sig
	_belt_links = {}
	var belts: Array = machines.filter(func(m): return m is Conveyor and (m as Node).is_inside_tree())
	for b in belts:
		_belt_links[b] = []
	for i in belts.size():
		for j in range(i + 1, belts.size()):
			var a: Conveyor = belts[i]
			var c: Conveyor = belts[j]
			if a.global_position.distance_to(c.global_position) < 3.2 and a.touches(c):
				_belt_links[a].append(c)
				_belt_links[c].append(a)
	for b in belts:
		var fed: Array = (b as Conveyor).fed_sides(_belt_links[b])
		(b as Conveyor).set_sides_open(fed[0], fed[1])
	return _belt_links


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
