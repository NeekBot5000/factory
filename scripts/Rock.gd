class_name Rock
extends StaticBody3D
## A boulder. Plain stone, or with a vein of copper or iron showing through. Pickaxes knock chunks off it until it
## crumbles away; iron needs a steel pickaxe (or the steel core drill). Other tools just kick up dust and sparks.

var _color := Color("8a8780")
var ore := "stone"
var hp := 6
var max_hp := 6
var size := 0.6
var hidden := ""          # some plain-looking stone has copper or iron inside (the ore detector finds it)
var revealed := false
var _mesh: Node3D
static var _last_told := -100000


func build(rng: RandomNumberGenerator, s: float, p_ore := "stone", p_hidden := "") -> void:
	collision_layer = 1
	collision_mask = 0
	size = s
	ore = p_ore
	hidden = p_hidden if ore == "stone" else ""
	max_hp = int(clampf(s * 10.0, 3.0, 12.0))
	hp = max_hp
	_color = Color("8a8780").lerp(Color("a39f95"), rng.randf())
	_mesh = Node3D.new()
	add_child(_mesh)
	LowPoly.mesh_instance(_mesh, LowPoly.blob(1.0, 0.3, rng.randi() % 40), Ground.stone_mat(Color(snappedf(_color.r, 0.02), snappedf(_color.g, 0.02), snappedf(_color.b, 0.02))), Vector3.ZERO, Vector3(0, rng.randf() * 360.0, 0), Vector3(s * 1.3, s * 0.7, s))
	if ore != "stone":
		# a vein of glinting ore lumps poking out of the rock
		var fm := LowPoly.mat(Ore.KINDS[ore].fleck, 0.35, 0.35)
		# its own dice, so veins don't shift the rest of the world's layout
		var vr := RandomNumberGenerator.new()
		vr.seed = hash(s) ^ hash(ore)
		for k in 7:
			var a := vr.randf() * TAU
			var e := vr.randf_range(-0.2, 0.5)
			var dir := Vector3(cos(a) * 1.25, e, sin(a)).normalized()
			LowPoly.mesh_instance(_mesh, LowPoly.box(Vector3.ONE * s * 0.22), fm, Vector3(dir.x * s * 1.15, dir.y * s * 0.62, dir.z * s * 0.9), Vector3(vr.randf() * 90.0, vr.randf() * 90.0, 0))
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(s * 2.0, s * 0.9, s * 1.6)
	cs.shape = sh
	add_child(cs)
	add_to_group("rocks")


## The ore you'd get out of it: its vein, or what's hidden inside.
func inner_ore() -> String:
	return hidden if hidden != "" else ore


func hint_text() -> String:
	if revealed:
		return "Stone with %s inside  ·  %s" % ["copper" if hidden == "copper" else "iron", "any pickaxe" if hidden == "copper" else "needs a steel pickaxe or core drill"]
	match ore:
		"copper": return "Copper vein  ·  any pickaxe"
		"iron": return "Iron vein  ·  needs a steel pickaxe or core drill"
	return "Stone  ·  any pickaxe"


func on_hit(pos: Vector3, normal: Vector3, tool: String) -> void:
	var parent := get_parent()
	Nature.burst(parent, pos, normal, _color.darkened(0.15), 14, 2.8, 0.05, 9.0, 0.8, 55.0)
	Nature.burst(parent, pos, normal + Vector3.UP, Color("d8d2c4"), 18, 1.0, 0.07, -0.5, 1.2, 80.0)   # dust drifting up
	var d: Dictionary = Tools.TOOLS.get(tool, {})
	var power := int(d.get("mine", 0))
	if power <= 0:
		if tool == "hands":
			Sfx.play("thud", 1.3, -2.0)
		else:
			Nature.burst(parent, pos, normal, Color("ffd36a"), 12, 4.5, 0.015, 6.0, 0.35, 40.0, 3.0)  # sparks
			Sfx.play("clink", randf_range(0.9, 1.15))
		return
	Sfx.play("crack", randf_range(0.85, 1.1))
	var tier := int(d.get("tier", 1))
	if ore == "iron" and tier < 2:
		# too hard for a basic pick: sparks fly but nothing comes off
		Nature.burst(parent, pos, normal, Color("ffd36a"), 18, 4.5, 0.015, 6.0, 0.35, 40.0, 3.0)
		# (once in a while: a drill held on it would say it several times a second)
		if Time.get_ticks_msec() - _last_told > 4000:
			_last_told = Time.get_ticks_msec()
			Game.toast.emit("Too hard - needs a steel pickaxe or core drill", Color("ffd27a"))
		return
	# a sledgehammer bursts a small rock in one blow
	if float(d.get("smash", 0.0)) >= size:
		shatter(tier)
		return
	hp -= power
	# a chunk breaks off: mostly the vein's ore, sometimes plain stone
	_spawn_chunk(_chunk_kind(tier), pos, normal)
	var k := clampf(float(hp) / float(max_hp), 0.0, 1.0)
	_mesh.scale = Vector3.ONE * lerpf(0.45, 1.0, k)
	if hp <= 0:
		for i in 2:
			_spawn_chunk(_chunk_kind(tier) if i == 0 else "stone", global_position + Vector3(0, size * 0.3, 0), Vector3.UP)
		Nature.burst(parent, global_position, Vector3.UP, _color, 30, 3.0, 0.09, 9.0, 1.0, 120.0)
		Sfx.play("crumble", 1.0, 2.0)
		queue_free()


func _chunk_kind(tier: int) -> String:
	if hidden != "":
		if hidden == "iron" and tier < 2:
			return "stone"      # the iron inside is too hard for this tool
		if randf() < 0.5:
			if not revealed:
				revealed = true
				Game.toast.emit("There was %s hiding in that rock!" % ("copper" if hidden == "copper" else "iron"), Color("ffd27a"))
			return hidden
		return "stone"
	return ore if ore == "stone" or randf() < 0.7 else "stone"


## The whole rock bursts at once (sledgehammer, dynamite): every chunk left in it flies out.
func shatter(tier: int = 2, from := Vector3.ZERO) -> void:
	if is_queued_for_deletion():
		return
	var parent := get_parent()
	var n := clampi(hp + 1, 2, 10)
	for i in n:
		var a := TAU * i / n + randf() * 0.5
		var dir := Vector3(cos(a), randf_range(0.4, 1.0), sin(a)).normalized()
		if from != Vector3.ZERO:
			dir = (dir + (global_position - from).normalized() * 0.8).normalized()
		_spawn_chunk(_chunk_kind(tier), global_position + dir * size * 0.5 + Vector3.UP * size * 0.2, dir)
	Nature.burst(parent, global_position, Vector3.UP, _color, 40, 4.0, 0.09, 9.0, 1.1, 160.0)
	Nature.burst(parent, global_position, Vector3.UP, Color("d8d2c4"), 30, 1.4, 0.12, -0.5, 1.6, 120.0)
	Sfx.play_at("crumble", global_position, 0.9, 4.0)
	hp = 0
	queue_free()


func _spawn_chunk(kind: String, pos: Vector3, normal: Vector3) -> void:
	var o := Ore.new()
	get_parent().add_child(o)
	o.setup(kind, randf_range(0.11, 0.17))
	o.global_position = pos + normal * 0.2
	o.linear_velocity = normal * randf_range(1.5, 2.5) + Vector3.UP * 1.5 + Vector3(randf_range(-0.6, 0.6), 0, randf_range(-0.6, 0.6))
	o.angular_velocity = Vector3(randf_range(-6, 6), randf_range(-6, 6), randf_range(-6, 6))


## For the save file.
func set_hp(v: int) -> void:
	hp = v
	_mesh.scale = Vector3.ONE * lerpf(0.45, 1.0, clampf(float(hp) / float(max_hp), 0.0, 1.0))
