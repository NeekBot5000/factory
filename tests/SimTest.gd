extends Node
## Headless sim test: builds factories programmatically and checks the physics economy works.
## Run: godot --headless --path . res://tests/SimTest.tscn --fixed-fps 60

var world: Node
var frames := 0
var phase := 0
var money0 := 0.0
var results: Array[String] = []
var failed := false


func _ready() -> void:
	Game.save_enabled = false
	world = load("res://scripts/World.gd").new()
	add_child(world)
	await get_tree().process_frame
	Game.money = 1e6
	for i in range(-2, 3):
		for j in range(-2, 3):
			Game.plots[Vector2i(i, j)] = true
	Game.unlocked["ramp"] = true
	Game.unlocked["polisher"] = true
	_build_line(0, "north")
	_build_line(1, "east")
	_build_line(2, "south")
	_build_line(3, "west")
	_build_ramp_line()
	_build_splitter_line()
	money0 = Game.money
	print("TEST: built %d parts" % world.parts.size())


func _build_line(rot: int, label: String) -> void:
	# a straight line of 6 belts in direction rot, dropper above the first, polisher mid, seller at end
	var d: Vector3i = Defs.DIRS[rot]
	var origin := Vector3i(-3, 0, 3)
	var off := {0: Vector3i(0, 0, 0), 1: Vector3i(-3, 0, -3), 2: Vector3i(3, 0, 0), 3: Vector3i(3, 0, 3)}
	origin = Vector3i(0, 0, 0) + off[rot] + Vector3i(rot * 0, 0, 0)
	if rot == 0:
		origin = Vector3i(-3, 0, 3)
	elif rot == 1:
		origin = Vector3i(-3, 0, -3)
	elif rot == 2:
		origin = Vector3i(6, 0, -6)
	else:
		origin = Vector3i(3, 0, 6)
	world.place("dropper_copper", origin + Vector3i(0, 1, 0) + d, rot)
	for i in 6:
		var id := "polisher" if i == 3 else "conveyor"
		world.place(id, origin + d * i, rot)
	var s: Part = world.place("seller", origin + d * 6, rot)
	if s == null:
		print("TEST: seller placement failed at ", origin + d * 6)
	print("TEST: line %s seller=%s" % [label, str(s != null)])


func _build_ramp_line() -> void:
	# along z=-1, going east: belts, ramp up, belts at layer 1, seller
	var z := 10
	world.place("dropper_iron", Vector3i(-3, 1, z), 1)
	world.place("conveyor", Vector3i(-3, 0, z), 1)
	world.place("conveyor", Vector3i(-2, 0, z), 1)
	world.place("ramp", Vector3i(-1, 0, z), 1)
	world.place("conveyor", Vector3i(0, 1, z), 1)
	world.place("conveyor", Vector3i(1, 1, z), 1)
	world.place("seller", Vector3i(2, 1, z), 1)


func _build_splitter_line() -> void:
	Game.unlocked["splitter"] = true
	var z := -14
	world.place("dropper_copper", Vector3i(-8, 1, z), 1)
	world.place("dropper_copper", Vector3i(-7, 1, z), 1)
	for x in [-8, -7, -6]:
		world.place("conveyor", Vector3i(x, 0, z), 1)
	var sp: Part = world.place("splitter", Vector3i(-5, 0, z), 1)
	world.place("conveyor", Vector3i(-4, 0, z), 1)
	world.place("seller", Vector3i(-3, 0, z), 1)
	world.place("conveyor", Vector3i(-5, 0, z - 1), 0)
	world.place("seller", Vector3i(-5, 0, z - 2), 0)
	world.place("conveyor", Vector3i(-5, 0, z + 1), 2)
	world.place("seller", Vector3i(-5, 0, z + 2), 2)
	print("TEST: splitter placed=%s" % str(sp != null))
	# upgrade a dropper to level 3 and check refund bookkeeping
	var dp: Part = world.cells[Vector3i(-8, 1, z)]
	Game.money = 1e6
	for i in 3:
		world.upgrade_part(dp)
	print("TEST: dropper level=%d paid=%.1f" % [dp.level, dp.paid])
	if dp.level != 3:
		failed = true


func _physics_process(_delta: float) -> void:
	frames += 1
	if frames == 60 * 16 and OS.get_environment("DBG2") != "":
		for it in world.active_items:
			if it.global_position.z < -10.0:
				print("ITEM ", it.global_position, " v=", it.linear_velocity, " still=", it.still_time)
	if frames % 45 == 0 and frames < 60 * 12 and OS.get_environment("DBG") != "":
		var line := "t=%.1f " % (frames / 60.0)
		for it in world.active_items:
			if it.kind == "iron":
				line += "(%.1f,%.2f,%.1f v=%.1f) " % [it.global_position.x, it.global_position.y, it.global_position.z, it.linear_velocity.length()]
		print(line)
	if frames == 60 * 20:
		var sold: int = Game.stats.sold
		var gained: float = Game.money - money0
		print("TEST: after 20s sold=%d gained=%.1f active_items=%d" % [sold, gained, world.active_items.size()])
		# every line should have produced sales; 5 droppers at ~1/s
		if sold < 40:
			print("TEST FAIL: too few sales")
			failed = true
		print("TEST: income_rate=%.2f" % Game.income_rate)
		for p in world.parts:
			if String(p.def.kind) == "splitter":
				print("TEST: splitter routes ", p.route_counts)
			if String(p.def.kind) == "seller":
				print("TEST: seller at %s sold %d" % [str(p.cell), p.sold])
				if p.sold < 4:
					failed = true
		print("TEST RESULT: %s" % ("FAIL" if failed else "PASS"))
		get_tree().quit(1 if failed else 0)
