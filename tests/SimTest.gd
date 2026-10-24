extends Node
## Headless simulation test of the physical production chains.
## Run: godot --headless --path . res://tests/SimTest.tscn --fixed-fps 60

var world: Node
var frames := 0
var failed := false
var sellers := {}
var probes := {}
var SIM_SECONDS := 60


func _ready() -> void:
	Game.save_enabled = false
	world = load("res://scripts/World.gd").new()
	add_child(world)
	await get_tree().process_frame
	world.hud.close_panel()
	Game.money = 1e9
	Game.level = 20
	for i in range(-2, 3):
		for j in range(-2, 3):
			Game.plots[Vector2i(i, j)] = true
	for id in Defs.PARTS:
		Game.unlocked[id] = true
	_row_logs(-18)
	_row_rip(-15)
	_row_planks(-12)
	_row_chop(-9)
	_row_smelt(-6)
	_row_press(-2)
	_row_grate(2)
	_row_wired(6)
	_row_teleport(10)
	_row_sorter(13)
	_row_packer(17)
	print("TEST: built %d parts, %d links" % [world.parts.size(), world.links.size()])


func P(id: String, x: int, y: int, z: int, r: int = 1, cfg: Dictionary = {}) -> Part:
	var p: Part = world.place(id, Vector3i(x, y, z), r, false, 0.0, cfg)
	if p == null:
		print("TEST WARN: could not place %s at %d,%d,%d" % [id, x, y, z])
	return p


func belt(x0: int, x1: int, z: int, y: int = 0, id: String = "conveyor") -> void:
	for x in range(x0, x1 + 1):
		P(id, x, y, z)


func seller(name: String, x: int, z: int, y: int = 0) -> void:
	sellers[name] = P("seller", x, y, z)


func _row_logs(z: int) -> void:
	P("treefarm_oak", -19, 0, z, 1)
	belt(-18, -10, z)
	seller("logs", -9, z)


func _row_rip(z: int) -> void:
	P("treefarm_oak", -19, 0, z, 1)
	belt(-18, -16, z)
	P("rip_saw", -15, 0, z, 1)
	belt(-14, -10, z)
	seller("rip", -9, z)


func _row_planks(z: int) -> void:
	P("treefarm_oak", -19, 0, z, 1)
	belt(-18, -17, z)
	P("gang_saw", -16, 0, z, 1)
	belt(-15, -10, z)
	seller("planks", -9, z)


func _row_chop(z: int) -> void:
	P("treefarm_oak", -19, 0, z, 1)
	belt(-18, -17, z)
	P("chop_saw", -16, 0, z, 1)
	belt(-15, -10, z)
	seller("chop", -9, z)


func _row_smelt(z: int) -> void:
	P("drill_copper", -19, 1, z)
	belt(-19, -18, z)
	P("crusher", -17, 0, z, 1)
	belt(-16, -15, z)
	P("furnace", -14, 0, z, 1)
	belt(-13, -10, z)
	seller("ingots", -9, z)


func _row_press(z: int) -> void:
	P("drill_iron", -19, 1, z)
	belt(-19, -18, z)
	P("crusher", -17, 0, z, 1)
	belt(-16, -15, z)
	P("furnace", -14, 0, z, 1)
	belt(-13, -12, z)
	P("press", -11, 0, z, 1)
	belt(-10, -8, z)
	P("press", -7, 0, z, 1)
	belt(-6, -4, z)
	seller("plates", -3, z)


func _row_grate(z: int) -> void:
	# crushed ore on a grate at layer 1; fines fall onto a lower belt to their own seller
	P("drill_copper", -19, 2, z)
	P("crusher", -19, 1, z, 1)
	P("grate", -18, 1, z, 1)
	P("grate", -17, 1, z, 1)
	belt(-16, -14, z, 1)
	seller("coarse", -13, z, 1)
	P("conveyor", -18, 0, z, 1)
	P("conveyor", -17, 0, z, 1)
	belt(-16, -15, z, 0)
	seller("fines", -14, z)


func _row_wired(z: int) -> void:
	# lever off -> belt stopped (no sales); timer -> chop saw
	P("treefarm_oak", -19, 0, z, 1)
	belt(-18, -12, z)
	seller("lever_off", -11, z)
	P("lever", -19, 0, z - 1, 0, {"on": false})
	world.add_link(Vector3i(-19, 0, z - 1), Vector3i(-19, 0, z))


func _row_teleport(z: int) -> void:
	P("treefarm_oak", -19, 0, z, 1)
	belt(-18, -16, z)
	P("tele_in", -15, 0, z, 0, {"channel": 2})
	P("tele_out", 5, 0, z, 1, {"channel": 2})
	belt(6, 8, z)
	seller("teleport", 9, z)


func _row_sorter(z: int) -> void:
	# copper ore boulders: a sensor detects them and a piston shoves them off sideways onto a side belt
	P("drill_copper", -19, 1, z)
	belt(-19, -17, z)
	P("sensor", -16, 0, z, 1, {"filter": "boulder"})
	belt(-15, -12, z)
	seller("unsorted", -11, z)
	P("piston", -16, 0, z - 1, 2)
	world.add_link(Vector3i(-16, 0, z), Vector3i(-16, 0, z - 1))
	P("conveyor", -16, 0, z + 1, 2)
	seller("sorted", -16, z + 2)


func _row_packer(z: int) -> void:
	P("treefarm_oak", -19, 0, z, 1, {})
	P("treefarm_oak", -19, 0, z + 1, 1, {})
	P("conveyor", -18, 0, z + 1, 0)
	belt(-18, -16, z)
	P("packer", -15, 0, z, 1, {"count": 4})
	belt(-14, -12, z)
	seller("crates", -11, z)


func _physics_process(_delta: float) -> void:
	frames += 1
	if OS.get_environment("DBG") != "" and frames % 60 == 0 and frames < 60 * 30:
		var tl := "TP t=%d " % (frames / 60)
		for it in world.active_items:
			if it.shape == "cyl" and absf(it.global_position.z - 10.5) < 1.5:
				tl += "(%.1f,%.2f,%.1f) " % [it.global_position.x, it.global_position.y, it.global_position.z]
		print(tl)
	if false:
		var line := "t=%d " % (frames / 60)
		for it in world.active_items:
			if it.shape == "cyl" and absf(it.global_position.z - (-17.5)) < 1.5:
				line += "(%.1f,%.2f,%.1f v%.1f) " % [it.global_position.x, it.global_position.y, it.global_position.z, it.linear_velocity.length()]
		print(line)
	if frames == 60 * SIM_SECONDS:
		_report()


func _check(cond: bool, msg: String) -> void:
	print(("PASS " if cond else "FAIL ") + msg)
	if not cond:
		failed = true


func _report() -> void:
	for k in sellers:
		var s: Part = sellers[k]
		print("TEST: seller %-10s sold %d" % [k, s.sold if s else -1])
	print("TEST: forms sold ", Game.forms_sold)
	print("TEST: ingots cast %d" % int(Game.stats.ingots))
	var f: Dictionary = Game.forms_sold
	_check(sellers.logs.sold >= 4, "logs line sells logs")
	_check(int(f.get("timber", 0)) >= 4, "rip saw makes timber")
	_check(int(f.get("plank", 0)) >= 4, "gang saw makes planks")
	_check(sellers.chop.sold > sellers.logs.sold, "chop saw multiplies log pieces (%d vs %d)" % [sellers.chop.sold, sellers.logs.sold])
	_check(int(Game.stats.ingots) >= 2, "furnaces cast ingots")
	_check(int(f.get("ingot", 0)) >= 1, "ingots sold")
	_check(int(f.get("plate", 0)) + int(f.get("sheet", 0)) >= 1, "press makes plates/sheets")
	_check(sellers.fines.sold >= 1, "fines fall through the grate (%d)" % sellers.fines.sold)
	_check(sellers.lever_off.sold == 0, "lever-off belt is stopped")
	_check(sellers.teleport.sold >= 3, "teleporter delivers")
	_check(sellers.sorted.sold >= 2, "sensor+piston sorts (%d)" % sellers.sorted.sold)
	_check(int(f.get("crate", 0)) >= 1, "packer makes crates")
	print("TEST RESULT: %s" % ("FAIL" if failed else "PASS"))
	get_tree().quit(1 if failed else 0)
