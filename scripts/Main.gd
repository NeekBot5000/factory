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
var icons: Icons
var ship_truck: Truck
var van: Truck
var computer: Computer
var ui_layer: CanvasLayer
var shop_ui: Control          # whichever full-screen UI is open: the store (computer / phone) or the build menu
var _dispatch_timer := -1.0
var grass_mat: ShaderMaterial
var n_wild_trees := 0            # trees from world generation (saved by index); grown ones come after
var _grass_hits: Array[Vector4] = []    # xyz = where something hit the ground, w = strength (decays)


func _ready() -> void:
	rng.seed = 2024
	_environment()
	terrain = Terrain.new()
	add_child(terrain)
	terrain.build()
	cabin = Cabin.new()
	add_child(cabin)
	cabin.build()
	icons = Icons.new()
	add_child(icons)
	computer = Computer.new()
	add_child(computer)
	computer.build(self)
	computer.position = Vector3(0.4, Cabin.FLOOR_Y, -1.98)
	_trucks()
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
	hud.setup(player, self)
	ui_layer = CanvasLayer.new()
	ui_layer.layer = 20
	add_child(ui_layer)
	if not Game.pending_orders().is_empty():
		_dispatch_timer = 4.0
	n_wild_trees = trees.size()
	# the world as you left it, and what you built
	WorldSave.load(self, Game.world_state)
	Builds.load_world(self, Game.world_builds)
	Game.world_saver = func(): return Builds.save_world(self)
	Game.world_state_saver = func(): return WorldSave.save(self)
	var autosave := Timer.new()
	autosave.wait_time = 15.0
	autosave.autostart = true
	autosave.timeout.connect(Game.save_game)
	add_child(autosave)


func _notification(what: int) -> void:
	# keep what you built: save when the window closes or the tab loses focus (web builds never get a close event)
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		Game.save_game()
	elif what == NOTIFICATION_PREDELETE or what == NOTIFICATION_EXIT_TREE:
		Game.world_saver = Callable()
		Game.world_state_saver = Callable()


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
			# keep the road and the truck parking spot clear
			if p.y > 1.0 and p.y < 118.0 and absf(p.x - Terrain.road_x(p.y)) < 4.6:
				continue
			if _in_lot(p):
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


## The truck parking spot and its turning loop.
func _in_lot(p: Vector2) -> bool:
	return p.x > 2.5 and p.x < 13.0 and p.y > 2.0 and p.y < 20.0


func _decor() -> void:
	# rocks, bushes, stumps, flowers and grass tufts
	for i in 70:
		var a := rng.randf() * TAU
		var r := rng.randf_range(7.0, 80.0)
		var p := Vector2(cos(a), sin(a)) * r
		if _in_lot(p) or (p.y > 1.0 and p.y < 118.0 and absf(p.x - Terrain.road_x(p.y)) < 4.6):
			continue
		var y := terrain.height_at(p.x, p.y)
		if i % 2 == 0:
			var s := rng.randf_range(0.3, 0.9)
			var rock := Rock.new()
			add_child(rock)
			rock.position = Vector3(p.x, y + s * 0.25, p.y)
			rock.build(rng, s)
		else:
			var bush := Bush.new()
			bush.set_meta("bush_id", i)
			add_child(bush)
			bush.position = Vector3(p.x, y, p.y)
			bush.build(rng, rng.randf_range(0.7, 1.4))
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
		var c := Color("438530").lerp(Color("6aa23f"), rng.randf())
		if rng.randf() < 0.04:
			c = [Color("f5e05a"), Color("f2f2f2"), Color("d06ad6")][rng.randi() % 3]
		mm.set_instance_color(i, c)
	grass.multimesh = mm
	grass_mat = Nature.grass_mat()
	grass.material_override = grass_mat
	grass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(grass)
	# distant hills ring for a sense of a valley
	for i in 18:
		var a := i / 18.0 * TAU + rng.randf() * 0.2
		var d := rng.randf_range(115.0, 140.0)
		var h := rng.randf_range(14.0, 28.0)
		LowPoly.mesh_instance(self, LowPoly.cyl(0.0, h * 1.6, h, 6), LowPoly.mat(Color("5d7d5a").lerp(Color("8fa6a8"), 0.4)), Vector3(cos(a) * d, h * 0.5 - 2.0, sin(a) * d), Vector3(0, rng.randf() * 60.0, 0))


func _road_point(z: float) -> Vector3:
	var x := Terrain.road_x(z)
	return Vector3(x, terrain.height_at(x, z), z)


## Points along the road from z0 to the end of the map, then over the crest and down out of sight.
func _road_out(z0: float) -> Array[Vector3]:
	var pts: Array[Vector3] = []
	var z := z0
	while z <= 108.0:
		pts.append(_road_point(z))
		z += 4.0
	var rim := _road_point(110.0)
	pts.append(rim)
	pts.append(rim + Vector3(0, -1.5, 6.0))
	pts.append(rim + Vector3(0, -7.0, 14.0))
	pts.append(rim + Vector3(0, -14.0, 22.0))
	return pts


func _ground(x: float, z: float) -> Vector3:
	return Vector3(x, terrain.height_at(x, z), z)


func _trucks() -> void:
	# green log truck parked beside the cabin, bed facing the porch, cab facing the road
	var park := _ground(6.0, 8.5)
	var out: Array[Vector3] = [park, _ground(6.0, 11.5), _ground(4.8, 14.5), _ground(2.0, 17.0)]
	out.append_array(_road_out(21.0))
	# comes back forwards and loops round the clearing into the same spot
	var back := _road_out(20.0)
	back.reverse()
	back.append_array([_ground(1.5, 16.5), _ground(5.5, 15.0), _ground(9.0, 13.0), _ground(10.6, 10.2),
		_ground(10.6, 7.4), _ground(9.6, 5.6), _ground(8.0, 5.0), _ground(6.6, 5.8), _ground(6.05, 7.2), park])
	ship_truck = Truck.new()
	add_child(ship_truck)
	ship_truck.build("ship", self, Transform3D(Basis.looking_at(Vector3(0, 0, 1), Vector3.UP), park), out, back)
	# orange TimberMart van: drives in, U-turns past the cabin, then backs onto the loading dock
	var vin := _road_out(24.0)
	vin.reverse()
	vin.append_array([_ground(1.6, 19.5), _ground(1.7, 17.4), _ground(1.0, 15.7), _ground(-0.8, 15.0),
		_ground(-2.6, 15.6), _ground(-3.2, 17.3), _ground(-3.2, 19.0)])
	var vdock: Array[Vector3] = [_ground(-3.2, 19.0), _ground(-3.2, 17.2), _ground(-3.2, 15.4)]
	var vout: Array[Vector3] = [_ground(-3.2, 15.4), _ground(-3.0, 19.0), _ground(-2.0, 21.5)]
	vout.append_array(_road_out(25.0))
	van = Truck.new()
	add_child(van)
	van.build("deliver", self, Transform3D.IDENTITY, vout, vin)
	van.route_dock = vdock
	_loading_dock(_ground(-3.2, 10.9))


## Wooden loading dock where the van drops off your orders.
func _loading_dock(at: Vector3) -> void:
	var dock := StaticBody3D.new()
	dock.collision_layer = 1
	add_child(dock)
	dock.position = at
	var h := 0.45
	var w := 2.8
	var d := 2.6
	var plank := LowPoly.mat(Color("9c6d43"), 0.9)
	var plank2 := LowPoly.mat(Color("8a5e38"), 0.9)
	var beam := LowPoly.mat(Color("5b4030"), 0.95)
	for k in 9:
		var z := -d * 0.5 + d / 18.0 + k * d / 9.0
		LowPoly.mesh_instance(dock, LowPoly.box(Vector3(w, 0.06, d / 9.0 - 0.015)), plank if k % 2 == 0 else plank2, Vector3(0, h - 0.03, z))
	LowPoly.mesh_instance(dock, LowPoly.box(Vector3(w - 0.1, h - 0.06, d - 0.1)), beam, Vector3(0, (h - 0.06) * 0.5, 0))
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			LowPoly.mesh_instance(dock, LowPoly.box(Vector3(0.16, h + 0.02, 0.16)), beam, Vector3(sx * (w * 0.5 - 0.08), (h + 0.02) * 0.5, sz * (d * 0.5 - 0.08)))
	# hazard stripes along the edge the van backs up to, and two rubber bumpers
	var yellow := LowPoly.mat(Color("f5c02e"), 0.6)
	var black := LowPoly.mat(Color("23252a"), 0.8)
	for k in 10:
		LowPoly.mesh_instance(dock, LowPoly.box(Vector3(w / 10.0, 0.07, 0.12)), yellow if k % 2 == 0 else black, Vector3(-w * 0.5 + w / 20.0 + k * w / 10.0, h + 0.005, d * 0.5 - 0.06))
	for sx in [-1.0, 1.0]:
		LowPoly.mesh_instance(dock, LowPoly.box(Vector3(0.3, 0.26, 0.14)), black, Vector3(sx * 0.85, h * 0.5, d * 0.5 + 0.06))
	# a step up on the cabin side
	LowPoly.mesh_instance(dock, LowPoly.box(Vector3(1.2, 0.22, 0.4)), plank, Vector3(0, 0.11, -d * 0.5 - 0.2))
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(w, h, d)
	cs.shape = sh
	cs.position = Vector3(0, h * 0.5, 0)
	dock.add_child(cs)
	var cs2 := CollisionShape3D.new()
	var sh2 := BoxShape3D.new()
	sh2.size = Vector3(1.2, 0.22, 0.4)
	cs2.shape = sh2
	cs2.position = Vector3(0, 0.11, -d * 0.5 - 0.2)
	dock.add_child(cs2)


func on_order_placed() -> void:
	if _dispatch_timer < 0.0:
		_dispatch_timer = 3.0


func unload_boxes(truck: Truck) -> void:
	var k := 0
	for o in Game.orders:
		if o.status != "shipping":
			continue
		var b := DeliveryBox.new()
		add_child(b)
		b.setup(String(o.item), self, icons.get_box_art(String(o.item)))
		var back := truck.global_transform.basis.z
		var side := truck.global_transform.basis.x
		b.global_position = truck.rear_point() + side * (k - 0.5) * 0.6 + Vector3(0, k * 0.1, 0)
		b.rotation.y = randf() * TAU
		b.linear_velocity = back * 2.2 + Vector3.UP * 1.0
		k += 1


## Something hit the ground here: flattens the grass for a moment (visual only).
func bend_grass(pos: Vector3, strength: float = 1.4) -> void:
	_grass_hits.append(Vector4(pos.x, pos.y, pos.z, strength))
	while _grass_hits.size() > Nature.MAX_BENDERS - 1:
		_grass_hits.pop_front()


func _update_grass(delta: float) -> void:
	if grass_mat == null:
		return
	var b: Array[Vector4] = []
	var pp := player.global_position
	b.append(Vector4(pp.x, pp.y, pp.z, 1.0))
	for i in range(_grass_hits.size() - 1, -1, -1):
		var h := _grass_hits[i]
		h.w -= delta * 0.9
		if h.w <= 0.0:
			_grass_hits.remove_at(i)
		else:
			_grass_hits[i] = h
	b.append_array(_grass_hits)
	while b.size() < Nature.MAX_BENDERS:
		b.append(Vector4.ZERO)
	grass_mat.set_shader_parameter("benders", b)


func _process(delta: float) -> void:
	_update_grass(delta)
	if _dispatch_timer >= 0.0:
		_dispatch_timer -= delta
		if _dispatch_timer < 0.0:
			if van.state == "away" and not Game.pending_orders().is_empty():
				for o in Game.orders:
					if o.status == "processing":
						o.status = "shipping"
				Game.orders_changed.emit()
				van.deliver()
			elif not Game.pending_orders().is_empty():
				_dispatch_timer = 2.0


func open_computer() -> void:
	_open_ui(false)


func open_phone() -> void:
	_open_ui(true)


## Hammer click: the build menu.
func open_build_menu() -> void:
	if shop_ui != null:
		return
	player.drop_held()
	player.controls_enabled = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var bm := BuildMenu.new()
	shop_ui = bm
	ui_layer.add_child(bm)
	bm.setup(self)
	bm.closed.connect(close_ui)
	Sfx.play("click")


func _open_ui(compact: bool) -> void:
	if shop_ui != null:
		return
	player.drop_held()
	player.controls_enabled = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	shop_ui = ShopUI.new()
	ui_layer.add_child(shop_ui)
	shop_ui.setup(self, compact)
	shop_ui.closed.connect(close_ui)
	if not compact:
		computer.set_on(true)
	Sfx.play("boot" if not compact else "click")


func close_ui() -> void:
	if shop_ui == null:
		return
	shop_ui.queue_free()
	shop_ui = null
	computer.set_on(false)
	player.controls_enabled = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


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
