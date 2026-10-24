extends Node3D
## Prototype scene: a log cabin in a clearing surrounded by forest, and a first-person lumberjack.

const MAX_CHIPS := 600

var terrain: Terrain
var cabin: Cabin
var player: Player
var hud: Hud
var trees: Array[ForestTree] = []
var chips: Array[Chip] = []
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	rng.seed = 2024
	_environment()
	terrain = Terrain.new()
	add_child(terrain)
	terrain.build()
	cabin = Cabin.new()
	add_child(cabin)
	cabin.build()
	_forest()
	_decor()
	player = Player.new()
	add_child(player)
	# start on the porch, looking out at the forest
	player.global_transform = Transform3D(Basis.IDENTITY.rotated(Vector3.UP, PI), Vector3(0.0, Cabin.FLOOR_Y + 0.05, Cabin.D * 0.5 + 1.0))
	player.spawn_xform = player.global_transform
	player.set("_yaw", PI)
	hud = Hud.new()
	add_child(hud)
	hud.setup(player)


func _environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color("4a8fe0")
	sm.sky_horizon_color = Color("cfe6f5")
	sm.ground_horizon_color = Color("cfe6f5")
	sm.ground_bottom_color = Color("6d8f5a")
	sky.sky_material = sm
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.42
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.fog_enabled = true
	env.fog_light_color = Color("a9c4b8")
	env.fog_light_energy = 0.8
	env.fog_density = 0.006
	env.fog_sky_affect = 0.2
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -35, 0)
	sun.light_energy = 1.05
	sun.light_color = Color("fff2dc")
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_max_distance = 60.0
	sun.shadow_bias = 0.04
	add_child(sun)


func _forest() -> void:
	var points: Array[Vector2] = []
	# a ring of trees close to the cabin so you can start chopping right away, then the deep forest
	var targets := [[9.5, 16.0, 14], [16.0, 90.0, 220]]
	for t in targets:
		var rmin: float = t[0]
		var rmax: float = t[1]
		var want: int = t[2]
		var tries := 0
		var placed := 0
		while placed < want and tries < want * 40:
			tries += 1
			var a := rng.randf() * TAU
			var r := sqrt(rng.randf_range(rmin * rmin, rmax * rmax))
			var p := Vector2(cos(a), sin(a)) * r
			# keep the porch path open
			if p.y > 2.0 and absf(p.x) < 2.5 and p.y < 40.0:
				continue
			var ok := true
			for q in points:
				if q.distance_squared_to(p) < 3.4 * 3.4:
					ok = false
					break
			if not ok:
				continue
			points.append(p)
			placed += 1
			var kinds := ["oak", "oak", "pine", "pine", "birch"]
			var tree := ForestTree.new()
			add_child(tree)
			tree.position = Vector3(p.x, terrain.height_at(p.x, p.y) - 0.05, p.y)
			tree.rotation.y = rng.randf() * TAU
			tree.setup(rng, kinds[rng.randi() % kinds.size()])
			trees.append(tree)


func _decor() -> void:
	# rocks, bushes, stumps, flowers and grass tufts
	var rock_m := LowPoly.mat(Color("8a8780"), 1.0)
	var bush_m := LowPoly.mat(Color("3f7f33"), 1.0)
	for i in 70:
		var a := rng.randf() * TAU
		var r := rng.randf_range(7.0, 80.0)
		var p := Vector2(cos(a), sin(a)) * r
		var y := terrain.height_at(p.x, p.y)
		if i % 2 == 0:
			var s := rng.randf_range(0.3, 0.9)
			LowPoly.mesh_instance(self, LowPoly.blob(1.0, 0.3, rng.randi() % 40), rock_m, Vector3(p.x, y + s * 0.25, p.y), Vector3(0, rng.randf() * 360.0, 0), Vector3(s * 1.3, s * 0.7, s))
			var sb := LowPoly.static_box(self, Vector3(s * 2.0, s * 0.9, s * 1.6), Vector3(p.x, y + s * 0.25, p.y))
			sb.collision_layer = 1
		else:
			LowPoly.mesh_instance(self, LowPoly.blob(0.6, 0.3, rng.randi() % 40), bush_m, Vector3(p.x, y + 0.3, p.y), Vector3.ZERO, Vector3(1.2, 0.8, 1.2) * rng.randf_range(0.7, 1.4))
	# grass tufts + flowers via MultiMesh
	var grass := MultiMeshInstance3D.new()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = LowPoly.cyl(0.0, 0.06, 0.32, 3)
	mm.instance_count = 2500
	for i in mm.instance_count:
		var a := rng.randf() * TAU
		var r := rng.randf_range(4.5, 60.0)
		var p := Vector2(cos(a), sin(a)) * r
		var xf := Transform3D(Basis.from_euler(Vector3(rng.randf_range(-0.2, 0.2), rng.randf() * TAU, rng.randf_range(-0.2, 0.2))).scaled(Vector3.ONE * rng.randf_range(0.7, 1.5)), Vector3(p.x, terrain.height_at(p.x, p.y) + 0.12, p.y))
		mm.set_instance_transform(i, xf)
		var c := Color("4f9a37").lerp(Color("7cb84a"), rng.randf())
		if rng.randf() < 0.04:
			c = [Color("f5e05a"), Color("f2f2f2"), Color("d06ad6")][rng.randi() % 3]
		mm.set_instance_color(i, c)
	grass.multimesh = mm
	var gm := StandardMaterial3D.new()
	gm.vertex_color_use_as_albedo = true
	gm.roughness = 1.0
	grass.material_override = gm
	grass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(grass)
	# distant hills ring for a sense of a valley
	for i in 18:
		var a := i / 18.0 * TAU + rng.randf() * 0.2
		var d := rng.randf_range(115.0, 140.0)
		var h := rng.randf_range(14.0, 28.0)
		LowPoly.mesh_instance(self, LowPoly.cyl(0.0, h * 1.6, h, 6), LowPoly.mat(Color("5d7d5a").lerp(Color("8fa6a8"), 0.4)), Vector3(cos(a) * d, h * 0.5 - 2.0, sin(a) * d), Vector3(0, rng.randf() * 60.0, 0))


## Called by the player when a piece of bark comes off a tree.
func spawn_chip(data: Dictionary, kind: String, push_dir: Vector3) -> Chip:
	var c := Chip.new()
	add_child(c)
	c.global_transform = data.xform
	c.setup(data, kind)
	var out: Vector3 = data.outward
	c.linear_velocity = out * randf_range(0.8, 1.6) + Vector3.UP * randf_range(0.6, 1.4) + push_dir * 0.3
	c.angular_velocity = Vector3(randf_range(-5, 5), randf_range(-5, 5), randf_range(-5, 5))
	chips.append(c)
	while chips.size() > MAX_CHIPS:
		var old: Chip = chips.pop_front()
		if is_instance_valid(old) and old != player.held:
			old.queue_free()
	return c
