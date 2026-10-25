extends Node
## Balance bench: how much bark money each stripping tool makes per minute of swinging, on fresh trees.
var main: Node3D
var player: Player


func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _ready() -> void:
	Game.save_enabled = false
	Game.reset()
	for id in Tools.SHOP_ORDER:
		Game.owned[id] = true
	main = load("res://scenes/Main.tscn").instantiate()
	add_child(main)
	await frames(3)
	player = main.player
	player.max_health = 1e9
	player.health = 1e9
	var trees: Array = main.trees.duplicate()
	trees.sort_custom(func(a, b): return a.global_position.distance_to(Vector3(0, 0, 14)) < b.global_position.distance_to(Vector3(0, 0, 14)))
	var t: ForestTree = trees[0]
	var fresh := t.layer_state()
	var results := []
	for id in ["hands", "hatchet", "twins", "double_bit", "combo", "scraper", "ringer", "labrys", "greataxe", "drill", "holesaw", "twin_auger", "robo"]:
		t.apply_layer_state(fresh)
		player.equip(id)
		await frames(20)
		var d: Dictionary = Tools.TOOLS[id]
		var per_swing := (d.get("impacts", [0]) as Array).size()
		var money := 0.0
		var secs := 0.0
		var log: Array = []      # [secs, money]
		# an efficient player: work round the trunk in rows, each hit just past the last one
		var r := maxf(float(d.radius), 0.05)
		var step_h := ForestTree.BAND_H if bool(d.get("ring", false)) else (0.3 if id == "robo" else maxf(r * 1.6, ForestTree.BAND_H))
		var hits := 0
		for pass_i in 3:
			var h := 0.4
			while h < 2.7:
				var step_a := TAU if bool(d.get("ring", false)) else (0.3 if id == "robo" else maxf(r * 1.6, 0.12)) / t.radius
				var bits := int(d.get("bits", 1))
				if bits == 2:
					step_a *= 2.0
				var a := pass_i * 0.37
				while a < TAU + pass_i * 0.37:
					var dir := Vector3(cos(a), 0, sin(a))
					var at := t.global_position + Vector3(0, h, 0) + dir * t.radius
					player.global_position = t.global_position + dir * (t.radius + 0.9) + Vector3(0, h - 1.75, 0)
					var eye := player.global_position + Vector3(0, 1.58, 0)
					var to := at - eye
					player.rotation.y = atan2(-to.x, -to.z)
					player.head.rotation.x = atan2(to.y, Vector2(to.x, to.z).length())
					player.set("_yaw", player.rotation.y)
					player.set("_pitch", player.head.rotation.x)
					player.set("_combo_t", 0.0)
					var before := _chip_value()
					player.call("_do_impact")
					var got := _chip_value() - before
					if got > 0.0 or pass_i == 0:
						secs += float(d.cooldown) / float(per_swing)
						money += got
						log.append([secs, money])
					hits += 1
					if hits % 40 == 0:
						await frames(1)
					a += step_a
				h += step_h
		var t75 := -1.0
		for e in log:
			if e[1] >= money * 0.75:
				t75 = e[0]
				break
		results.append([id, money, t75])
		print("BENCH %-10s price %6s  tree $%7.2f   75%% of it in %5.1fs   -> $%6.1f/min" % [id, str(Tools.SHOP.get(id, {}).get("price", 0)), money, t75, money * 0.75 / maxf(t75, 0.01) * 60.0])
		for c in main.chips.duplicate():
			c.queue_free()
		main.chips.clear()
		await frames(2)
	get_tree().quit()


func _chip_value() -> float:
	var v := 0.0
	for c in main.chips:
		if is_instance_valid(c) and not c.is_queued_for_deletion():
			v += (c as Chip).value
	return v
