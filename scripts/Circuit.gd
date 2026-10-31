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
	# batteries charge from a network that has other power; if it has none, they power it themselves
	var batteries: Array = machines.filter(func(m): return m is Battery)
	for bt in batteries:
		(bt as Battery).feeding = false
	var res := _solve(machines, links)
	if not batteries.is_empty():
		var any := false
		for bt in batteries:
			if not res.live.has(bt) and (bt as Battery).charge > 0.0:
				(bt as Battery).feeding = true
				any = true
		if any:
			res = _solve(machines, links)
	var live: Dictionary = res.live
	var fed: Dictionary = res.fed
	for m in machines:
		(m as Machine).set_powered(live.has(m))
		(m as Machine)._update_lamp()
		if m is Gate:
			(m as Gate).step(fed.get(m, {}), TICK)
		elif m is Battery:
			(m as Battery).step(TICK)
	for w in wires:
		var wire := w as Wire
		if wire != null and is_instance_valid(wire.a) and is_instance_valid(wire.b):
			# a wire glows when power actually flows through it
			var flows := live.has(wire.a) and live.has(wire.b) and (_feeds(wire.a) or _feeds(wire.b))
			if not flows and (wire.a is Gate or wire.b is Gate):
				var g: Gate = wire.a if wire.a is Gate else wire.b
				var o: Machine = wire.b if g == wire.a else wire.a
				flows = (live.has(o) and _feeds(o) and g.side_of(o) != "front") or (g.passing and g.side_of(o) == "front")
			wire.set_live(flows)


static func _feeds(m: Machine) -> bool:
	return m.is_source() or m.conducts() or (m is Gate and (m as Gate).passing)


## Spreads power from every source. Logic blocks only let it out of their front, and only when their logic says so;
## since that depends on what reaches their inputs, it settles over a few rounds (feedback loops just stop there).
func _solve(machines: Array, links: Dictionary) -> Dictionary:
	var gates: Array = machines.filter(func(m): return m is Gate)
	var live := {}
	var fed := {}
	for round_i in 8:
		live = {}
		fed = {}
		for g in gates:
			fed[g] = {"back": false, "side": false}
		var queue: Array = []
		for m in machines:
			var mm := m as Machine
			if mm.is_source() or (mm is Gate and (mm as Gate).passing):
				live[m] = true
				queue.append(m)
		while not queue.is_empty():
			var m: Machine = queue.pop_back()
			if not _feeds(m):
				continue      # it gets power itself, but doesn't pass it on
			for n in links[m]:
				if m is Gate and (m as Gate).side_of(n) != "front":
					continue
				if n is Gate:
					var side := (n as Gate).side_of(m)
					if side != "front":
						fed[n][side] = true
					continue
				if not live.has(n):
					live[n] = true
					queue.append(n)
		var changed := false
		for g in gates:
			var want := (g as Gate).would_pass(fed[g])
			if want != (g as Gate).passing:
				(g as Gate).passing = want
				changed = true
		if not changed:
			break
	for g in gates:
		if (g as Gate).passing:
			live[g] = true
	return {"live": live, "fed": fed}


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
