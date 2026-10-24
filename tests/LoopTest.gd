extends Node
## Headless test of the money loop: circle stripping with tools, shipping bark, buying, delivery, unboxing.
var main: Node3D
var player: Player
var tree: ForestTree
var fails := 0
var step := 0
var t := 0.0
var money0 := 0.0
var box: DeliveryBox


func check(c: bool, msg: String) -> void:
	print(("PASS " if c else "FAIL ") + msg)
	if not c:
		fails += 1


func _ready() -> void:
	Game.save_enabled = false
	Game.reset()
	main = load("res://scenes/Main.tscn").instantiate()
	add_child(main)
	await get_tree().physics_frame
	player = main.player
	var best := 1e9
	for tr in main.trees:
		var d: float = tr.global_position.distance_to(player.global_position)
		if d < best:
			best = d
			tree = tr
	_face_tree(0.0)


func _face_tree(pitch_deg: float) -> void:
	var tp := tree.global_position
	var away := player.global_position - tp
	away.y = 0
	away = away.normalized()
	var stand := tp + away * (tree.radius + 0.9)
	stand.y = main.terrain.height_at(stand.x, stand.z) + 0.1
	player.global_position = stand
	player.velocity = Vector3.ZERO
	var to := tp - stand
	player.set("_yaw", atan2(-to.x, -to.z))
	player.rotation.y = atan2(-to.x, -to.z)
	player.set("_pitch", deg_to_rad(pitch_deg))
	player.head.rotation.x = deg_to_rad(pitch_deg)


func _physics_process(delta: float) -> void:
	t += delta
	match step:
		0:
			if t > 0.3:
				Game.owned["hatchet"] = true
				player.equip("hatchet")
				step = 1
				t = 0.0
		1:
			if t > 0.4:
				var hp := player.health
				player.call("_do_impact")
				var c: Chip = main.chips[-1] if main.chips.size() > 0 else null
				check(c != null and c.panels > 1, "hatchet strips a whole circle in one piece (%d panels)" % (c.panels if c else 0))
				check(player.health == hp, "axes don't hurt you")
				player.call("_do_impact")
				var c2: Chip = main.chips[-1]
				check(c2.layer == ForestTree.INNER, "second hit at the same spot takes the inner layer")
				var pj := tree.panel_at(player.look_ray(3.0, 1).position)
				check(not tree.has_panel(ForestTree.INNER, pj.x, pj.y), "inner bark gone at the centre")
				step = 2
				t = 0.0
		2:
			# no digging through layers: aim at an untouched band, strip outer with the big labrys, check inner untouched
			Game.owned["labrys"] = true
			player.equip("labrys")
			_face_tree(-30.0)
			step = 3
			t = 0.0
		3:
			if t > 0.4:
				var hit := player.look_ray(3.0, 1)
				var res := tree.strip_circle(hit.position, Tools.TOOLS.labrys.radius)
				check(int(res.layer) == ForestTree.OUTER and (res.panels as Array).size() >= 6, "labrys strips a big patch (%d panels)" % (res.panels as Array).size())
				var inner_left := 0
				for p in res.panels:
					if tree.has_panel(ForestTree.INNER, p.x, p.y):
						inner_left += 1
				check(inner_left == (res.panels as Array).size(), "the hit did not dig into the inner layer")
				Game.owned["drill"] = true
				player.equip("drill")
				step = 4
				t = 0.0
		4:
			if t > 0.4:
				var n0: int = main.chips.size()
				_face_tree(10.0)
				player.drill_once()
				player.drill_once()
				check(main.chips.size() > n0, "the drill strips bark")
				step = 5
				t = 0.0
		5:
			# load chips into the truck bed and ship
			var truck: Truck = main.ship_truck
			var k := 0
			for c in main.chips:
				c.global_position = truck.global_transform * Vector3(randf_range(-0.6, 0.6), 1.6 + k * 0.05, randf_range(0.0, 2.0))
				c.linear_velocity = Vector3.ZERO
				k += 1
			step = 6
			t = 0.0
		6:
			if t > 1.5:
				var v: float = main.ship_truck.load_value()
				check(v > 0.0, "truck bed counts the loaded bark ($%.2f)" % v)
				money0 = Game.money
				check(main.ship_truck.ship(), "truck ships the load")
				step = 7
				t = 0.0
		7:
			if Game.money > money0 + 0.001:
				check(true, "shipping paid out ($%.2f, after %.0fs)" % [Game.money - money0, t])
				check(main.ship_truck.state == "returning" and main.ship_truck.route_out.size() > 2, "truck heads back home along its route")
				step = 8
				t = 0.0
			elif t > 60.0:
				check(false, "shipping never paid out")
				step = 8
		8:
			# buy the double-bit axe through the shop and the phone
			Game.money = 2000.0
			main.open_computer()
			check(main.shop_ui != null, "computer opens the TimberMart store")
			check(Game.buy("double_bit"), "bought the double-bit axe")
			check(Game.buy("phone"), "bought the TimberPhone")
			main.on_order_placed()
			main.close_ui()
			step = 9
			t = 0.0
		9:
			var boxes := main.get_children().filter(func(n): return n is DeliveryBox)
			if boxes.size() >= 2:
				check(true, "the van delivered %d boxes after %.0fs" % [boxes.size(), t])
				box = boxes[0]
				step = 10
				t = 0.0
			elif t > 60.0:
				check(false, "no delivery boxes arrived (van state %s)" % main.van.state)
				step = 13
		10:
			if t > 1.5:
				box.open()
				step = 11
				t = 0.0
		11:
			if t > 2.0:
				var picks := main.get_children().filter(func(n): return n is ItemPickup)
				check(picks.size() >= 1, "opening the box reveals the item")
				var item := ""
				if picks.size() > 0:
					item = picks[0].item
					picks[0].take(player)
				check(item != "" and Game.is_owned(item), "taking the item gives it to you (%s)" % item)
				for b in main.get_children().filter(func(n): return n is DeliveryBox and not n.opened):
					b.open()
				step = 12
				t = 0.0
		12:
			if t > 2.5:
				for p in main.get_children().filter(func(n): return n is ItemPickup):
					p.take(player)
				check(Game.is_owned("double_bit") and Game.has_phone, "both orders received")
				check(player.tool == "double_bit" or Game.is_owned("double_bit"), "double-bit axe available")
				main.open_phone()
				check(main.shop_ui != null and main.shop_ui.compact, "Tab-phone opens the compact store")
				main.close_ui()
				step = 13
		13:
			print("LOOP RESULT: ", "PASS" if fails == 0 else "FAIL (%d)" % fails)
			get_tree().quit(0 if fails == 0 else 1)
