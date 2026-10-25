class_name WorldSave
extends RefCounted
## Everything you've done to the world, as plain data for the save file: bark stripped off trees, trees felled,
## trees grown, bushes trimmed, and every loose thing lying around (bark, leaves, logs, saplings, dropped tools).
## Builds and plans are saved separately by Builds.save_world.

static func _xf(t: Transform3D) -> Array:
	return Builds.xf_to_array(t)


static func _unxf(a: Array) -> Transform3D:
	return Builds.xf_from_array(a)


## Whether a body is really lying in the world (not riding in the truck, swallowed by a plan, etc.).
static func _loose(b: Node3D, world: Node) -> bool:
	if not is_instance_valid(b) or not b.visible:
		return false
	var p := b.get_parent()
	if p == world:
		return not ((b is RigidBody3D) and (b as RigidBody3D).freeze and not (b is Log and (b as Log).locked))
	# things riding in a carried basket count as being in the world
	return p is RigidBody3D and p.is_in_group("baskets")


static func save(world: Node) -> Dictionary:
	var out := {"trees": [], "grown": [], "bushes": [], "chips": [], "leaves": [], "logs": [], "saplings": [], "tools": []}
	var n_wild: int = world.get("n_wild_trees")
	var trees: Array = world.get("trees")
	for i in trees.size():
		var t := trees[i] as ForestTree
		if not is_instance_valid(t):
			continue
		if t.has_meta("grown"):
			var g: Dictionary = t.get_meta("grown")
			out.grown.append({"xf": _xf(t.global_transform), "seed": g.seed, "kind": g.kind, "state": t.layer_state()})
		elif i < n_wild and not t.is_untouched():
			out.trees.append({"i": i, "state": t.layer_state()})
	for b in world.get_tree().get_nodes_in_group("bushes"):
		if b.has_meta("bush_id"):
			out.bushes.append({"id": b.get_meta("bush_id"), "snips": b.get("_snips_left"), "trim": b.get("_trim")})
	out["bush_ids_known"] = true
	for c in world.get_tree().get_nodes_in_group("chips"):
		var chip := c as Chip
		if _loose(chip, world) and not chip.src.is_empty():
			out.chips.append({"xf": _xf(chip.global_transform), "layer": chip.layer, "kind": chip.kind, "src": chip.src,
				"panels": chip.panel_list, "mult": chip.value_mult})
	for l in world.get_tree().get_nodes_in_group("leaves"):
		var lf := l as Leaf
		if _loose(lf, world):
			out.leaves.append({"xf": _xf(lf.global_transform), "c": lf.color.to_html(), "s": lf.size})
	for l in world.get_tree().get_nodes_in_group("logs"):
		var lg := l as Log
		if _loose(lg, world):
			out.logs.append({"xf": _xf(lg.global_transform), "src": lg.trunk.src_info(), "state": lg.trunk.layer_state(), "locked": lg.locked})
	for s in world.get_tree().get_nodes_in_group("saplings"):
		var sp := s as Sapling
		if _loose(sp, world) or (sp.get("_rooted") and is_instance_valid(sp)):
			out.saplings.append({"xf": _xf(sp.global_transform), "kind": sp.kind, "rooted": sp.get("_rooted"), "grow": sp.get("_grow")})
	for t in world.get_tree().get_nodes_in_group("tool_items"):
		var ti := t as ToolItem
		if _loose(ti, world):
			out.tools.append({"xf": _xf(ti.global_transform), "tool": ti.tool})
	return out


static func load(world: Node, d: Dictionary) -> void:
	if d.is_empty():
		return
	var trees: Array = world.get("trees")
	for e in d.get("trees", []):
		var i := int(e.i)
		if i >= 0 and i < trees.size():
			(trees[i] as ForestTree).apply_layer_state(e.state)
	for e in d.get("grown", []):
		var rng := RandomNumberGenerator.new()
		rng.seed = int(e.seed)
		var tree := ForestTree.new()
		tree.set_meta("grown", {"seed": int(e.seed), "kind": String(e.kind)})
		world.add_child(tree)
		var xf := _unxf(e.xf)
		tree.position = xf.origin
		tree.rotation.y = rng.randf() * TAU
		tree.setup(rng, String(e.kind))
		tree.apply_layer_state(e.state)
		trees.append(tree)
	if d.has("bush_ids_known"):
		var keep := {}
		for e in d.get("bushes", []):
			keep[int(e.id)] = e
		for b in world.get_tree().get_nodes_in_group("bushes"):
			if not b.has_meta("bush_id"):
				continue
			var id := int(b.get_meta("bush_id"))
			if not keep.has(id):
				b.queue_free()            # trimmed away
			else:
				b.set("_snips_left", int(keep[id].snips))
				b.set("_trim", float(keep[id].trim))
				(b.get("_leaves") as Node3D).scale = Vector3.ONE * float(keep[id].trim)
	for e in d.get("chips", []):
		var src: Dictionary = e.src
		var panels: Array = []
		for p in e.panels:
			panels.append(Vector2i(int(p[0]), int(p[1])))
		if panels.is_empty():
			continue
		var top := 0
		for p in panels:
			top = maxi(top, p.y + 1)
		var g := ForestTree.ghost(src, top, PackedByteArray(), PackedByteArray())
		world.add_child(g)
		var data := g.piece_data(int(e.layer), panels)
		g.free()
		data["value_mult"] = float(e.get("mult", 1.0))
		var c := Chip.new()
		world.add_child(c)
		c.setup(data, String(e.kind))
		c.global_transform = _unxf(e.xf)
		if "chips" in world:
			world.chips.append(c)
	for e in d.get("leaves", []):
		var lf := Leaf.new()
		world.add_child(lf)
		lf.setup(Color.html(String(e.c)), float(e.s), true)
		lf.global_transform = _unxf(e.xf)
	for e in d.get("logs", []):
		var st: Dictionary = e.state
		var n := int(st.bands)
		var g2 := ForestTree.ghost(e.src, n, Marshalls.base64_to_raw(String(st.outer)), Marshalls.base64_to_raw(String(st.inner)))
		var lg := Log.new()
		world.add_child(lg)
		var xf2 := _unxf(e.xf)
		lg.setup_from(g2, 0, n, xf2 * Transform3D(Basis(), Vector3(0, -n * ForestTree.BAND_H * 0.5, 0)))
		g2.free()
		lg.global_transform = xf2
		if bool(e.get("locked", false)):
			lg.set_locked(true)
	for e in d.get("saplings", []):
		var sp := Sapling.new()
		world.add_child(sp)
		sp.setup(String(e.kind))
		sp.global_transform = _unxf(e.xf)
		if bool(e.get("rooted", false)):
			sp.call("_root")
			sp.set("_grow", float(e.get("grow", 0.0)))
	for e in d.get("tools", []):
		var ti := ToolItem.new()
		world.add_child(ti)
		ti.setup(String(e.tool))
		ti.global_transform = _unxf(e.xf)
		Game.dropped[String(e.tool)] = true
	Game.tools_changed.emit()
