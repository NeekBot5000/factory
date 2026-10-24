extends Node3D
## Main scene: environment, grid occupancy, item physics pool, dropper simulation, save glue.

const ITEM_LIFETIME := 150.0

var cells := {}
var parts: Array[Part] = []
var droppers: Array[Part] = []

var terrain: Terrain
var batcher: Batcher
var rig: CameraRig
var builder: Builder
var hud: Hud
var parts_root: Node3D
var items_root: Node3D

var active_items: Array[Item] = []
var _free_items: Array[Item] = []
var _retire_queue: Array[Item] = []
var _clouds: Array[Node3D] = []
var _ui_timer := 0.0
var _sun: DirectionalLight3D


func _ready() -> void:
	Game.world = self
	_setup_env()
	batcher = Batcher.new()
	batcher.name = "Batcher"
	add_child(batcher)
	terrain = Terrain.new()
	add_child(terrain)
	terrain.build()
	parts_root = Node3D.new()
	parts_root.name = "Parts"
	add_child(parts_root)
	items_root = Node3D.new()
	items_root.name = "Items"
	add_child(items_root)
	rig = CameraRig.new()
	add_child(rig)
	builder = Builder.new()
	add_child(builder)
	builder.setup(self, rig)
	hud = Hud.new()
	add_child(hud)
	hud.setup(self, builder)
	Game.plots_changed.connect(terrain.refresh)
	Game.upgrades_changed.connect(_on_upgrades_changed)
	Game.settings_changed.connect(_on_settings_changed)
	_load_buildings()
	_on_upgrades_changed()
	get_tree().auto_accept_quit = false


func _setup_env() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color("3d86e0")
	sm.sky_horizon_color = Color("bfe3ff")
	sm.ground_horizon_color = Color("bfe3ff")
	sm.ground_bottom_color = Color("86b6e6")
	sm.sun_angle_max = 25.0
	sky.sky_material = sm
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.5
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.fog_enabled = true
	env.fog_light_color = Color("cfe6ff")
	env.fog_density = 0.0012
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	_sun = DirectionalLight3D.new()
	_sun.rotation_degrees = Vector3(-50, -38, 0)
	_sun.light_energy = 1.25
	_sun.shadow_enabled = bool(Game.settings.shadows)
	_sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	_sun.directional_shadow_max_distance = 70.0
	_sun.shadow_bias = 0.05
	_sun.shadow_normal_bias = 1.0
	add_child(_sun)
	var ocean := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(1400, 1400)
	ocean.mesh = pm
	ocean.material_override = Meshes.mat(Color("3a8fd8"), 0.0, 0.25)
	ocean.position.y = -26.0
	ocean.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ocean)
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for i in 14:
		var c := Node3D.new()
		var n := rng.randi_range(3, 5)
		for k in n:
			var s := MeshInstance3D.new()
			var sp := SphereMesh.new()
			sp.radius = rng.randf_range(3.0, 5.5)
			sp.height = sp.radius * 1.2
			sp.radial_segments = 7
			sp.rings = 3
			s.mesh = sp
			s.material_override = Meshes.mat(Color(1, 1, 1), 0.15, 1.0)
			s.position = Vector3(k * 4.0 - n * 2.0, rng.randf_range(-0.6, 0.6), rng.randf_range(-1.5, 1.5))
			s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			c.add_child(s)
		var a := rng.randf() * TAU
		var d := rng.randf_range(55.0, 140.0)
		c.position = Vector3(cos(a) * d, rng.randf_range(16.0, 38.0), sin(a) * d)
		add_child(c)
		_clouds.append(c)


func _on_settings_changed() -> void:
	_sun.shadow_enabled = bool(Game.settings.shadows)


func _on_upgrades_changed() -> void:
	Meshes.refresh_belt_speeds(Game.belt_mult())
	for p in parts:
		p.apply_speed()


func _process(delta: float) -> void:
	for c in _clouds:
		c.position.x += delta * 0.6
		if c.position.x > 160.0:
			c.position.x = -160.0
	_ui_timer += delta
	if _ui_timer > 1.0:
		_ui_timer = 0.0
		terrain.refresh()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		Game.save_game()
		get_tree().quit()
	elif what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		Game.save_game()


# ------------------------------------------------------------ grid

func owns_cell(c: Vector3i) -> bool:
	if c.y < 0 or c.y > Defs.MAX_LAYER:
		return false
	return Game.plots.has(Defs.plot_of_cell(c))


func can_place(c: Vector3i) -> bool:
	return owns_cell(c) and not cells.has(c)


func place(type_id: String, c: Vector3i, rot: int, charge: bool = true, paid: float = -1.0) -> Part:
	if not can_place(c):
		return null
	var cost := Game.part_cost(type_id)
	if charge:
		if not Game.spend(cost):
			return null
	else:
		cost = paid if paid >= 0.0 else cost
	var p := Part.new()
	parts_root.add_child(p)
	p.setup(self, type_id, c, rot)
	p.paid = cost
	cells[c] = p
	parts.append(p)
	match String(p.def.kind):
		"dropper": droppers.append(p)
	Game.on_part_added(type_id)
	return p


func remove(p: Part, refund: bool = true) -> void:
	if not is_instance_valid(p):
		return
	cells.erase(p.cell)
	parts.erase(p)
	droppers.erase(p)
	p.release_visuals()
	if refund:
		Game.add_bonus(p.paid)
	Game.on_part_removed(p.type_id)
	p.queue_free()


func clear_all(refund: bool) -> void:
	for p in parts.duplicate():
		remove(p, refund)
	for it in active_items.duplicate():
		_retire_now(it)
	cells.clear()


func serialize() -> Array:
	var out := []
	for p in parts:
		out.append({"t": p.type_id, "x": p.cell.x, "y": p.cell.y, "z": p.cell.z, "r": p.rot, "p": p.paid})
	return out


func _load_buildings() -> void:
	for b in Game.saved_buildings:
		var id := String(b.get("t", ""))
		if not Defs.PARTS.has(id):
			continue
		place(id, Vector3i(int(b.x), int(b.y), int(b.z)), int(b.r), false, float(b.get("p", 0.0)))
	Game.saved_buildings = []


# ------------------------------------------------------------ items

func spawn_item(kind: String, pos: Vector3, value: float) -> Item:
	if active_items.size() >= Game.item_cap():
		return null
	var it: Item
	if _free_items.size() > 0:
		it = _free_items.pop_back()
	else:
		it = Item.new()
		items_root.add_child(it)
	it.activate(kind, value, pos)
	active_items.append(it)
	return it


func sell(it: Item, seller: Part) -> void:
	if not it.active:
		return
	var amount := it.value * float(seller.def.mult) * Game.sell_mult()
	Game.add_money(amount)
	Game.stats.sold += 1
	seller.sold += 1
	it.active = false
	it.visible = false
	_retire_queue.append(it)
	FX.popup(seller.global_position + Vector3(0, 0.9, 0), "+" + Util.money(amount), Color("7aff9a"))
	FX.play("sell", 0.9 + minf(it.passes, 4) * 0.12, 0.06)


func _retire_now(it: Item) -> void:
	active_items.erase(it)
	it.deactivate()
	if not _free_items.has(it):
		_free_items.append(it)


func _physics_process(delta: float) -> void:
	if not _retire_queue.is_empty():
		for it in _retire_queue:
			_retire_now(it)
		_retire_queue.clear()
	# droppers
	var rate_mult := Game.drop_rate_mult()
	var lucky := Game.lucky_chance()
	for d in droppers:
		var r: Dictionary = Defs.RESOURCES[d.def.res]
		d.drop_accum += delta * float(r.rate) * rate_mult
		while d.drop_accum >= 1.0:
			d.drop_accum -= 1.0
			var v: float = r.value
			if lucky > 0.0 and randf() < lucky:
				v *= 5.0
			var jitter := Vector3(randf_range(-0.08, 0.08), 0, randf_range(-0.08, 0.08))
			var it := spawn_item(d.def.res, d.global_position + Vector3(0, 0.26, 0) + jitter, v)
			if it == null:
				d.drop_accum = minf(d.drop_accum, 1.0)
				break
			if v > float(r.value) * 1.5:
				it.passes = 3
				it.apply_pass(-1, 1.0)
	# cleanup
	var i := active_items.size() - 1
	while i >= 0:
		var it: Item = active_items[i]
		it.age += delta
		if it.linear_velocity.length_squared() < 0.01:
			it.still_time += delta
		else:
			it.still_time = 0.0
		if it.global_position.y < -20.0 or it.age > ITEM_LIFETIME or it.still_time > 8.0:
			active_items.remove_at(i)
			it.deactivate()
			_free_items.append(it)
		i -= 1
