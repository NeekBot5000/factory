extends Node
## Headless test of the second wave of items: throwing hatchet, spiral axe, bark spud, thunder axe, pole saw,
## two-man crosscut (and the giant trees), planer, pressure washer, rake, leaf blower, sledgehammer, ore detector
## (and hidden ore), dynamite, watering can, log scale, wheelbarrow.
var main: Node3D
var player: Player
var fails := 0
var trees: Array = []
var used := {}


func check(c: bool, msg: String) -> void:
	print(("PASS " if c else "FAIL ") + msg)
	if not c:
		fails += 1


func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func look_at_point(at: Vector3) -> void:
	var eye := player.global_position + Vector3(0, 1.58, 0)
	var to := at - eye
	player.set("_yaw", atan2(-to.x, -to.z))
	player.set("_pitch", atan2(to.y, Vector2(to.x, to.z).length()))
	player.rotation.y = atan2(-to.x, -to.z)
	player.head.rotation.x = atan2(to.y, Vector2(to.x, to.z).length())


func stand(at: Vector3) -> void:
	at.y = main.terrain.height_at(at.x, at.z) + 0.05
	player.global_position = at
	player.velocity = Vector3.ZERO
	await frames(2)


## Stands `dist` from the trunk (on the side toward the cabin) looking at height `h` on it.
func face(tree: Node3D, h: float, dist: float) -> void:
	var away := Vector3(0, 0, 14) - tree.global_position
	away.y = 0
	away = away.normalized()
	await stand(tree.global_position + away * dist)
	look_at_point(tree.global_position + Vector3(0, h, 0))
	await frames(1)


func count(tree: ForestTree, l: int) -> int:
	var n := 0
	for b in tree.layers[l]:
		n += b
	return n


func bark(tree: ForestTree) -> int:
	return count(tree, 0) + count(tree, 1)


## A fresh, ordinary standing tree we can see clearly from `dist` away at height `h`.
func fresh_tree(h: float, dist: float, reach: float) -> ForestTree:
	for t in trees:
		var tr := t as ForestTree
		if used.has(tr) or tr.felled or tr.giant or not is_instance_valid(tr) or tr.trunk_h < h + 1.0:
			continue
		await face(tr, h, dist)
		var hit := player.look_ray(reach, 1)
		if hit.get("collider") == tr:
			used[tr] = true
			return tr
	return null


func equip(id: String) -> void:
	Game.owned[id] = true
	player.equip(id)
	await frames(20)


func hold(n: int) -> void:
	player.force_trigger = true
	await frames(n)
	player.force_trigger = false
	await frames(2)


func _ready() -> void:
	Game.save_enabled = false
	Game.reset()
	for id in Tools.SHOP_ORDER:
		if id != "phone":
			Game.owned[id] = true
	main = load("res://scenes/Main.tscn").instantiate()
	add_child(main)
	await frames(3)
	player = main.player
	trees = main.trees.duplicate()
	trees.sort_custom(func(a, b): return a.global_position.distance_to(Vector3(0, 0, 14)) < b.global_position.distance_to(Vector3(0, 0, 14)))

	catalogue_test()
	await throwing_test()
	await spiral_test()
	await spud_test()
	await thunder_test()
	await pole_saw_test()
	await giant_test()
	await planer_test()
	await washer_test()
	await rake_test()
	await blower_test()
	await sledge_test()
	await detector_test()
	await dynamite_test()
	await water_test()
	await scale_test()
	await barrow_test()
	print("ITEM RESULT: ", "PASS" if fails == 0 else "FAIL (%d)" % fails)
	get_tree().quit()


func catalogue_test() -> void:
	var missing: Array = []
	for id in Tools.TOOLS:
		if id == "hands":
			continue
		if not Tools.SHOP.has(id) or not Tools.SHOP_ORDER.has(id) or not Tools.TOOL_ORDER.has(id):
			missing.append(id)
	check(missing.is_empty(), "every tool is in the shop and the tool bar order %s" % str(missing))
	var empty: Array = []
	for id in ["throwing", "spiral", "spud", "thunder", "pole_saw", "crosscut", "planer", "washer", "rake", "blower", "sledge", "detector", "dynamite", "can", "scale"]:
		var holder := Node3D.new()
		add_child(holder)
		var m := Tools.build_model(id, holder)
		if m.find_children("*", "MeshInstance3D", true, false).size() < 3:
			empty.append(id)
		holder.queue_free()
	check(empty.is_empty(), "every new tool has a proper model %s" % str(empty))
	var n := 0
	for g in main.trees:
		if (g as ForestTree).giant:
			n += 1
	check(n >= 4, "there are giant trees deep in the woods (%d)" % n)


func throwing_test() -> void:
	await equip("throwing")
	var t := await fresh_tree(3.6, 7.0, 12.0)
	check(t != null, "found a tree to throw at")
	if t == null:
		return
	var b0 := bark(t)
	player.primary()
	await frames(22)
	var th: ThrownHatchet = player.get("_thrown")
	check(th != null and is_instance_valid(th), "the hatchet leaves the hand")
	check(player.hand_flat.visible and not player.tool_model.visible, "the hand is open and empty while it's out")
	player.primary()            # can't throw what you don't have
	await frames(80)
	check(bark(t) < b0, "the throw took bark off high up the trunk, 7 m away (%d panels)" % (b0 - bark(t)))
	check(not is_instance_valid(th) and player.get("_thrown") == null, "it came back and was caught")
	await frames(20)
	check(player.tool_model.visible and player.hand_fist.visible, "back in the hand after the catch")
	# a second throw works once it's back
	player.primary()
	await frames(22)
	check(is_instance_valid(player.get("_thrown")), "it can be thrown again")
	await frames(90)


func spiral_test() -> void:
	await equip("spiral")
	var t := await fresh_tree(1.2, t_dist(), 2.4)
	if t == null:
		check(false, "found a tree for the spiral axe")
		return
	var bands: Array = []
	for k in 3:
		var before: Array = [t.layers[0].duplicate(), t.layers[1].duplicate()]
		player.call("_do_impact")
		var lo := 9999
		var got := 0
		for l in 2:
			for idx in before[l].size():
				if before[l][idx] == 1 and t.layers[l][idx] == 0:
					got += 1
					lo = mini(lo, idx / ForestTree.SECTORS)
		bands.append(lo)
		check(got >= 4, "spiral hit %d takes a slanted stripe (%d panels)" % [k + 1, got])
		await frames(10)
	check(bands[1] > bands[0] and bands[2] > bands[1], "each stripe carries on above the last one: bands %s" % str(bands))


func t_dist() -> float:
	return 1.3


func spud_test() -> void:
	await equip("spud")
	var t := await fresh_tree(1.3, 1.3, 2.4)
	if t == null:
		check(false, "found a tree for the spud")
		return
	var n0 := (main.chips as Array).size()
	player.call("_do_impact")
	var newest: Chip = main.chips.back() if (main.chips as Array).size() > n0 else null
	check(newest != null and is_equal_approx(newest.value_mult, 1.5), "bark spud sheets sell for 50% more")


func thunder_test() -> void:
	await equip("thunder")
	var t := await fresh_tree(1.3, 1.4, 2.5)
	if t == null:
		check(false, "found a tree for the thunder axe")
		return
	var full := bark(t)
	await hold(20)
	await frames(30)
	check(bark(t) < full and bark(t) > full - 30, "a short press is an ordinary hit, no lightning (%d panels)" % (full - bark(t)))
	await frames(30)
	var b0 := bark(t)
	Sfx.played.erase("thunder")
	await hold(90)
	await frames(10)
	check(bark(t) == 0 and b0 > 100, "a full charge cracks every last sheet off the trunk (%d -> %d)" % [b0, bark(t)])
	check(int(Sfx.played.get("thunder", 0)) > 0, "with a thunderclap")
	var t2 := await fresh_tree(1.3, 1.4, 2.5)
	if t2 != null:
		var b2 := bark(t2)
		await hold(90)
		await frames(10)
		check(bark(t2) > b2 - 30, "it has to recharge before the next strike")


func pole_saw_test() -> void:
	await equip("pole_saw")
	var t: ForestTree = null
	for tr in trees:
		var tt := tr as ForestTree
		if used.has(tt) or tt.giant or tt.felled or tt.get_node_or_null("Crown") == null:
			continue
		await face(tt, tt.trunk_h - 0.8, 2.5)
		var hit := player.look_ray(5.5, 1 | Foliage.LAYER)
		var c: Object = hit.get("collider")
		if c == tt or (c is Foliage and (c as Node).get_parent().get_parent() == tt):
			t = tt
			break
	check(t != null, "found a crown in reach of the pole saw")
	if t == null:
		return
	used[t] = true
	var leaves0 := get_tree().get_nodes_in_group("leaves").size()
	var saps0 := get_tree().get_nodes_in_group("saplings").size()
	await hold(130)
	await frames(5)
	check(t.get_node_or_null("Crown") == null and not t.felled, "holding the pole saw in it cuts the crown off a standing tree")
	check(get_tree().get_nodes_in_group("leaves").size() > leaves0 + 5, "its leaves rain down")
	check(get_tree().get_nodes_in_group("saplings").size() > saps0, "with a sapling in them")


func giant_test() -> void:
	var g: ForestTree = null
	for tr in trees:
		if (tr as ForestTree).giant and not (tr as ForestTree).felled:
			g = tr
			break
	if g == null:
		check(false, "found a giant tree")
		return
	await equip("saw")
	await face(g, 0.9, g.radius + 0.9)
	await hold(300)
	check(not g.felled, "an ordinary bow saw can't fell a giant tree")
	await equip("crosscut")
	await face(g, 0.9, g.radius + 0.9)
	var logs0 := get_tree().get_nodes_in_group("logs")
	await hold(480)
	check(g.felled, "the two-man crosscut fells it")
	var fresh: Array = get_tree().get_nodes_in_group("logs").filter(func(l): return not logs0.has(l))
	check(fresh.size() == 1 and (fresh[0] as Node).has_meta("clean"), "its clean cut marks the log (worth 20% more)")


func planer_test() -> void:
	var t := await fresh_tree(1.0, 1.4, 2.4)
	if t == null:
		check(false, "found a tree for the planer")
		return
	var lg := t.fell(3, Vector3(1, 0, 0.3).normalized())
	await frames(240)
	await equip("planer")
	await stand(lg.global_position + Vector3(0, 0, 1.6))
	look_at_point(lg.global_position + Vector3(0, 0.1, 0))
	await frames(2)
	var hit := player.look_ray(2.3, 1)
	check(hit.get("collider") == lg, "aiming at the felled log")
	var n0 := (main.chips as Array).size()
	await hold(60)
	var biggest := 0
	for k in range(n0, (main.chips as Array).size()):
		biggest = maxi(biggest, (main.chips[k] as Chip).panels)
	check(biggest >= 8, "the planer takes a full-length strip off the log in one sheet (%d panels)" % biggest)


func washer_test() -> void:
	await equip("washer")
	var t := await fresh_tree(1.6, 4.5, 6.0)
	if t == null:
		check(false, "found a tree for the pressure washer")
		return
	var b0 := bark(t)
	await hold(70)
	check(b0 - bark(t) >= 10, "the pressure washer strips bark from 4.5 m away (%d panels in a second)" % (b0 - bark(t)))


func _clear_spot() -> Vector3:
	# open ground near the cabin, away from the trees
	return Vector3(-4.0, 0, 9.0)


func _scatter(n: int, around: Vector3) -> Array:
	var out: Array = []
	for k in n:
		var o := Ore.new()
		main.add_child(o)
		o.setup("stone", 0.12)
		var p := around + Vector3(randf_range(-0.4, 0.4), 0, randf_range(-0.4, 0.4))
		o.global_position = Vector3(p.x, main.terrain.height_at(p.x, p.z) + 0.15, p.z)
		out.append(o)
	return out


func _mean_dist(bodies: Array, to: Vector3) -> float:
	var d := 0.0
	for b in bodies:
		d += Vector2((b as Node3D).global_position.x - to.x, (b as Node3D).global_position.z - to.z).length()
	return d / maxf(bodies.size(), 1)


func rake_test() -> void:
	await equip("rake")
	var spot := _clear_spot()
	await stand(spot)
	look_at_point(spot + Vector3(0, 0, -2.0))
	await frames(2)
	var pile := _scatter(6, spot + Vector3(0, 0, -2.0))
	await frames(40)
	var d0 := _mean_dist(pile, player.global_position)
	for k in 3:
		player.call("rake")
		await frames(40)
	var d1 := _mean_dist(pile, player.global_position)
	check(d1 < d0 - 0.5, "the rake drags loose things toward you (%.1f m -> %.1f m)" % [d0, d1])
	for b in pile:
		b.queue_free()


func blower_test() -> void:
	await equip("blower")
	var spot := _clear_spot()
	await stand(spot)
	look_at_point(spot + Vector3(0, 0.3, -3.0))
	await frames(2)
	var pile: Array = []
	for k in 8:
		var lf := Leaf.new()
		main.add_child(lf)
		lf.setup(Color("6aa846"), 0.16)
		var p := spot + Vector3(randf_range(-0.5, 0.5), 0, -2.5 + randf_range(-0.4, 0.4))
		lf.global_position = Vector3(p.x, main.terrain.height_at(p.x, p.z) + 0.1, p.z)
		pile.append(lf)
	await frames(60)
	var d0 := _mean_dist(pile, player.global_position)
	await hold(80)
	var d1 := _mean_dist(pile, player.global_position)
	check(d1 > d0 + 1.0, "the leaf blower blows loose things away (%.1f m -> %.1f m)" % [d0, d1])
	for b in pile:
		b.queue_free()


func _rock(pred: Callable) -> Rock:
	var best: Rock = null
	for r in get_tree().get_nodes_in_group("rocks"):
		var rk := r as Rock
		if rk.is_queued_for_deletion() or not pred.call(rk):
			continue
		if best == null or rk.global_position.length() < best.global_position.length():
			best = rk
	return best


func _face_rock(rk: Rock) -> void:
	var away := Vector3(0, 0, 14) - rk.global_position
	away.y = 0
	await stand(rk.global_position + away.normalized() * (rk.size * 1.3 + 0.9))
	look_at_point(rk.global_position)
	await frames(1)


func sledge_test() -> void:
	await equip("sledge")
	var rk := _rock(func(r): return r.size < 0.75 and r.ore != "iron")
	if rk == null:
		check(false, "found a small rock")
		return
	await _face_rock(rk)
	var ores0 := get_tree().get_nodes_in_group("ores").size()
	player.call("_do_impact")
	await frames(3)
	check(not is_instance_valid(rk) or rk.is_queued_for_deletion(), "one sledgehammer blow bursts a small rock")
	check(get_tree().get_nodes_in_group("ores").size() >= ores0 + 2, "into all its chunks (%d)" % (get_tree().get_nodes_in_group("ores").size() - ores0))


func detector_test() -> void:
	var hid := _rock(func(r): return r.hidden != "")
	check(hid != null and hid.hint_text().begins_with("Stone"), "some plain-looking rocks hide ore inside")
	await equip("detector")
	var vein := _rock(func(r): return r.inner_ore() != "stone")
	await stand(vein.global_position + Vector3(2.5, 0, 2.5))
	var b0 := int(Sfx.played.get("beep", 0))
	await frames(120)
	var near := int(Sfx.played.get("beep", 0)) - b0
	await stand(Vector3(0, 0, 6))
	b0 = int(Sfx.played.get("beep", 0))
	await frames(120)
	var far := int(Sfx.played.get("beep", 0)) - b0
	check(near >= 4 and near > far, "the ore detector beeps faster close to ore (%d beeps near, %d away)" % [near, far])


func dynamite_test() -> void:
	Game.money = 5000.0
	check(Game.buy("dynamite"), "buy a box of dynamite")
	Game.receive("dynamite")
	check(int(Game.charges.get("dynamite", 0)) == 5, "a box holds five sticks")
	check(Game.buy("dynamite"), "and you can buy another box once that one's arrived")
	Game.receive("dynamite")
	check(int(Game.charges.get("dynamite", 0)) == 10, "boxes add up (%d)" % int(Game.charges.get("dynamite", 0)))
	await equip("dynamite")
	var rk := _rock(func(r): return r.size > 0.6)
	await _face_rock(rk)
	var ch: Charge = player.plant_charge()
	check(ch != null and int(Game.charges.dynamite) == 9, "stick a charge on a rock")
	await frames(2)
	check(Machine.of(player.look_ray(3.0, 1 | 2).get("collider")) == ch or ch.is_in_group("machines"), "the charge is a machine you can wire up")
	# step back to a safe distance, then power reaches it (as through a wire from a switch)
	await stand(rk.global_position + (player.global_position - rk.global_position).normalized() * 6.0)
	var h0 := player.health
	var ores0 := get_tree().get_nodes_in_group("ores").size()
	ch.set_powered(true)
	await frames(40)
	check(not is_instance_valid(rk), "boom: the rock bursts")
	check(get_tree().get_nodes_in_group("ores").size() >= ores0 + 4, "into all its chunks")
	check(player.health == h0, "from 6 m away you're safe")


func water_test() -> void:
	await equip("can")
	var spot := _clear_spot() + Vector3(2.0, 0, 0)
	await stand(spot)
	var sp := Sapling.new()
	main.add_child(sp)
	sp.setup("oak")
	var at := spot + Vector3(0, 0, -1.4)
	sp.global_position = Vector3(at.x, main.terrain.height_at(at.x, at.z) + 0.2, at.z)
	look_at_point(sp.global_position + Vector3(0, 0.15, 0))
	await frames(150)
	check(sp.is_rooted(), "the sapling takes root")
	look_at_point(sp.global_position + Vector3(0, 0.15, 0))
	await frames(1)
	check(player.call("water"), "water it with the can")
	var g0 := float(sp.get("_grow"))
	await frames(60)
	var g1 := float(sp.get("_grow"))
	check(g1 - g0 > 1.8, "a watered sapling grows twice as fast (%.2f s of growth in 1 s)" % (g1 - g0))


func scale_test() -> void:
	await equip("scale")
	var lg: Log = null
	for l in get_tree().get_nodes_in_group("logs"):
		lg = l
		break
	var r := player.scale_reading(lg)
	check(float(r.get("kg", 0.0)) > 20.0 and String(r.get("text", "")).contains("$"), "the scale weighs a log and says what it's worth: %s" % r.get("text", ""))


func barrow_test() -> void:
	Game.owned["bp_wheelbarrow"] = true
	check(Builds.unlocked("wheelbarrow"), "the blueprint unlocks the wheelbarrow")
	var spot := _clear_spot() + Vector3(-2.0, 0, -1.0)
	var y: float = main.terrain.height_at(spot.x, spot.z)
	var wb := Builds.finish("wheelbarrow", main, Transform3D(Basis(), Vector3(spot.x, y + 0.02, spot.z)), 0.0, [], 1.0) as RigidBody3D
	await frames(60)
	var load: Array = []
	for k in 6:
		var o := Ore.new()
		main.add_child(o)
		o.setup("copper", 0.12)
		o.global_position = wb.global_transform * Vector3(randf_range(-0.2, 0.2), Builds.BARROW_Y + 0.15 + k * 0.08, randf_range(-0.25, 0.25))
		load.append(o)
	await frames(90)
	# grab it from behind (the handle end)
	await stand(wb.global_position + wb.global_basis.z * 1.6)
	look_at_point(wb.global_position + Vector3(0, 0.4, 0))
	await frames(2)
	check(player.try_grab() and player.held == wb, "grab the wheelbarrow")
	await frames(30)
	var start := wb.global_position
	# push it along for two seconds
	for k in 120:
		player.global_position += -player.global_transform.basis.z * 0.025
		await get_tree().physics_frame
	await frames(20)
	var moved := Vector2(wb.global_position.x - start.x, wb.global_position.z - start.z).length()
	check(moved > 2.0, "it rolls along in front of you (%.1f m)" % moved)
	var gy: float = main.terrain.height_at(wb.global_position.x, wb.global_position.z)
	check(wb.global_position.y < gy + 0.5, "on the ground, not floating")
	var inside := 0
	for o in load:
		if is_instance_valid(o) and (o as Node3D).global_position.distance_to(wb.global_position + wb.global_basis.y * Builds.BARROW_Y) < 0.8:
			inside += 1
	check(inside >= 5, "the load rides along in it (%d of 6)" % inside)
	player.drop_held()
	await frames(30)
