extends Node
## Physics stress test: many droppers + belts + sellers; reports wall-clock per simulated second.
var world: Node
var frames := 0
var t0 := 0
var N_LINES := 30


func _ready() -> void:
	Game.save_enabled = false
	world = load("res://scripts/World.gd").new()
	add_child(world)
	await get_tree().process_frame
	Game.money = 1e12
	Game.upgrades["item_cap"] = 20
	Game.upgrades["drop_speed"] = 20
	for i in range(-2, 3):
		for j in range(-2, 3):
			Game.plots[Vector2i(i, j)] = true
	var n := 0
	for k in N_LINES:
		var z := -19 + (k % 20) * 2
		var x0 := -19 if k < 20 else -19
		if k >= 20:
			continue
		for x in range(x0, 18):
			world.place("conveyor3", Vector3i(x, 0, z), 1)
		for x in range(x0, x0 + 12):
			world.place("dropper_copper", Vector3i(x, 1, z), 1)
		world.place("seller", Vector3i(18, 0, z), 1)
	print("BENCH parts=", world.parts.size())
	t0 = Time.get_ticks_msec()


func _physics_process(_d: float) -> void:
	frames += 1
	if frames % 300 == 0:
		var el := (Time.get_ticks_msec() - t0) / 1000.0
		print("BENCH sim_s=%.0f wall_s=%.1f items=%d sold=%d" % [frames / 60.0, el, world.active_items.size(), Game.stats.sold])
	if frames >= 1500:
		get_tree().quit()
