extends Node
## Headless gameplay test: walk up to a tree, karate-chop it, check layers/chips/damage, grab and carry a chip, faint.
var main: Node3D
var player: Player
var tree: ForestTree
var fails := 0
var step := 0
var t := 0.0
var chip: Chip
var hp_before := 0.0


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
	check(main.trees.size() > 150, "forest planted (%d trees)" % main.trees.size())
	# nearest tree
	var best := 1e9
	for tr in main.trees:
		var d: float = tr.global_position.distance_to(player.global_position)
		if d < best:
			best = d
			tree = tr
	_face_tree()


func _face_tree() -> void:
	var tp := tree.global_position
	var away := (player.global_position - tp)
	away.y = 0
	away = away.normalized()
	var stand := tp + away * (tree.radius + 0.9)
	stand.y = main.terrain.height_at(stand.x, stand.z) + 0.1
	player.global_position = stand
	player.velocity = Vector3.ZERO
	var to := tp - stand
	player.set("_yaw", atan2(-to.x, -to.z))
	player.set("_pitch", deg_to_rad(-12.0))


func _physics_process(delta: float) -> void:
	t += delta
	match step:
		0:
			if t > 0.5:
				hp_before = player.health
				player.primary()
				step = 1
				t = 0.0
		1:
			if t > 0.5:
				check(main.chips.size() == 1, "one karate chop knocks off one bark chip (%d)" % main.chips.size())
				check(main.chips.size() > 0 and main.chips[0].layer == ForestTree.OUTER, "first chip is outer bark")
				check(player.health < hp_before, "chopping hurt the player (%.0f -> %.0f)" % [hp_before, player.health])
				player.primary()
				step = 2
				t = 0.0
		2:
			if t > 0.5:
				check(main.chips.size() == 2 and main.chips[1].layer == ForestTree.INNER, "second chop at the same spot strips the inner bark")
				player.primary()
				step = 3
				t = 0.0
		3:
			if t > 0.5:
				check(main.chips.size() == 2, "third chop hits bare wood: no more chips (%d)" % main.chips.size())
				# chop a ring of spots
				for k in 6:
					player.set("_pitch", deg_to_rad(-30.0 + k * 9.0))
					player.head.rotation.x = deg_to_rad(-30.0 + k * 9.0)
					player.call("_do_impact")
				check(main.chips.size() >= 6, "chopping other spots strips more bark (%d chips)" % main.chips.size())
				check(tree.bare_fraction() > 0.0, "tree shows bare wood where both layers are gone")
				step = 4
				t = 0.0
		4:
			if t > 1.5:
				chip = main.chips[0]
				# place the chip in front of the camera and grab it
				chip.global_position = player.cam.global_position - player.cam.global_transform.basis.z * 1.0
				chip.linear_velocity = Vector3.ZERO
				step = 5
				t = 0.0
		5:
			if t > 0.05:
				player.interact()
				check(player.held == chip, "E picks up the chip")
				step = 55
				t = 0.0
		55:
			player.set("_yaw", player.get("_yaw") + delta * 3.0)
			if t > 1.0:
				step = 6
				t = 0.0
		6:
			if t > 1.0:
				var target: Vector3 = player.cam.global_transform * Player.HOLD_OFFSET
				check(chip.global_position.distance_to(target) < 0.4, "held chip follows the hands (%.2f)" % chip.global_position.distance_to(target))
				player.primary()
				check(player.held == null, "left click throws it")
				step = 7
				t = 0.0
		7:
			if t > 0.8:
				check(chip.global_position.distance_to(player.global_position) > 2.0, "thrown chip flew away")
				player.health = 3.0
				_face_tree()
				player.set("_pitch", deg_to_rad(0.0))
				player.primary()
				step = 8
				t = 0.0
		8:
			if t > 0.6:
				check(not player.controls_enabled, "running out of health makes you faint")
				step = 9
				t = 0.0
		9:
			if t > 2.6:
				check(player.controls_enabled and player.health == player.max_health, "you wake up healed at the cabin")
				check(player.global_position.distance_to(player.spawn_xform.origin) < 0.5, "respawned on the porch")
				print("CHOP RESULT: ", "PASS" if fails == 0 else "FAIL (%d)" % fails)
				get_tree().quit(0 if fails == 0 else 1)
