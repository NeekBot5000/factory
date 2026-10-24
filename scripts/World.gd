extends Node3D
## Main scene: environment, grid occupancy, item physics pool, item geometry operations (cut / crush / press),
## the wiring network and save glue.

const ITEM_LIFETIME := 300.0
const STILL_LIMIT := 20.0

var cells := {}
var parts: Array[Part] = []
var tickers: Array[Part] = []
var animators: Array[Part] = []
var signal_parts: Array[Part] = []
var links: Array = []          # [{a: Vector3i (output), b: Vector3i (input)}]
var in_links := {}             # Vector3i -> Array[Vector3i]
var teleporters: Array[Part] = []

var terrain: Terrain
var batcher: Batcher
var rig: CameraRig
var builder: Builder
var hud: Hud
var wires: Wires
var parts_root: Node3D
var items_root: Node3D

var active_items: Array[Item] = []
var _free_items: Array[Item] = []
var _retire_queue: Array[Item] = []
var _jobs: Array[Callable] = []
var _clouds: Array[Node3D] = []
var _ui_timer := 0.0
var _sun: DirectionalLight3D
var _links_dirty := true


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
	wires = Wires.new()
	add_child(wires)
	wires.setup(self)
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
	for p in animators:
		p.animate(delta)
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


func place(type_id: String, c: Vector3i, rot: int, charge: bool = true, paid: float = -1.0, cfg: Dictionary = {}) -> Part:
	if not can_place(c):
		return null
	var cost := Game.part_cost(type_id)
	if charge:
		if not Game.spend(cost):
			return null
	else:
		cost = paid if paid >= 0.0 else cost
	var p := Part.create(type_id)
	parts_root.add_child(p)
	if not cfg.is_empty():
		p.set_meta("pending_config", cfg)
	p.setup(self, type_id, c, rot)
	if not cfg.is_empty():
		for k in cfg:
			if p.config.has(k):
				p.config[k] = cfg[k]
		p.on_config_changed()
	p.paid = cost
	cells[c] = p
	parts.append(p)
	if p.needs_tick():
		tickers.append(p)
	if p.needs_anim():
		animators.append(p)
	if Defs.has_input(type_id) or Defs.has_output(type_id):
		signal_parts.append(p)
	Game.on_part_added(type_id)
	p.on_placed()
	_notify_neighbors(c)
	return p


func remove(p: Part, refund: bool = true) -> void:
	if not is_instance_valid(p):
		return
	cells.erase(p.cell)
	parts.erase(p)
	tickers.erase(p)
	animators.erase(p)
	signal_parts.erase(p)
	_remove_links_of(p.cell)
	p.on_removed()
	p.release_visuals()
	if refund:
		Game.add_bonus(p.paid)
	Game.on_part_removed(p.type_id)
	var c := p.cell
	p.queue_free()
	_notify_neighbors(c)


func _notify_neighbors(c: Vector3i) -> void:
	for d in Defs.DIRS:
		for dy in [-1, 0, 1]:
			var n: Part = cells.get(c + d + Vector3i(0, dy, 0))
			if n != null:
				n.on_neighbor_changed()


func upgrade_part(p: Part) -> bool:
	if not p.can_upgrade():
		return false
	var c := p.upgrade_cost()
	if not Game.spend(c):
		return false
	p.paid += c
	p.set_level(p.level + 1)
	Game.stats.part_upgrades += 1
	return true


func clear_all(refund: bool) -> void:
	for p in parts.duplicate():
		remove(p, refund)
	for it in active_items.duplicate():
		_retire_now(it)
	cells.clear()
	links.clear()
	in_links.clear()
	_links_dirty = true


func serialize() -> Array:
	var out := []
	for p in parts:
		var e := {"t": p.type_id, "x": p.cell.x, "y": p.cell.y, "z": p.cell.z, "r": p.rot, "p": p.paid, "l": p.level}
		if not p.config.is_empty():
			e["c"] = p.config
		out.append(e)
	return out


func serialize_links() -> Array:
	var out := []
	for l in links:
		var a: Vector3i = l.a
		var b: Vector3i = l.b
		out.append([a.x, a.y, a.z, b.x, b.y, b.z])
	return out


func _load_buildings() -> void:
	for b in Game.saved_buildings:
		var id := String(b.get("t", ""))
		if not Defs.PARTS.has(id):
			continue
		var cfg: Dictionary = b.get("c", {})
		var np := place(id, Vector3i(int(b.x), int(b.y), int(b.z)), int(b.r), false, float(b.get("p", 0.0)), cfg)
		if np != null and int(b.get("l", 0)) > 0:
			np.set_level(int(b.l))
	for l in Game.saved_links:
		add_link(Vector3i(int(l[0]), int(l[1]), int(l[2])), Vector3i(int(l[3]), int(l[4]), int(l[5])))
	Game.saved_buildings = []
	Game.saved_links = []


# ------------------------------------------------------------ wiring

func has_link(a: Vector3i, b: Vector3i) -> bool:
	for l in links:
		if l.a == a and l.b == b:
			return true
	return false


func add_link(a: Vector3i, b: Vector3i) -> bool:
	if a == b or has_link(a, b):
		return false
	var pa: Part = cells.get(a)
	var pb: Part = cells.get(b)
	if pa == null or pb == null or not Defs.has_output(pa.type_id) or not Defs.has_input(pb.type_id):
		return false
	links.append({"a": a, "b": b})
	if not in_links.has(b):
		in_links[b] = []
	(in_links[b] as Array).append(a)
	_links_dirty = true
	return true


func remove_link(a: Vector3i, b: Vector3i) -> void:
	for i in range(links.size() - 1, -1, -1):
		if links[i].a == a and links[i].b == b:
			links.remove_at(i)
	if in_links.has(b):
		(in_links[b] as Array).erase(a)
		if (in_links[b] as Array).is_empty():
			in_links.erase(b)
	_links_dirty = true


func _remove_links_of(c: Vector3i) -> void:
	for i in range(links.size() - 1, -1, -1):
		var l: Dictionary = links[i]
		if l.a == c or l.b == c:
			remove_link(l.a, l.b)
	in_links.erase(c)


func _signal_step(delta: float) -> void:
	var changed: Array[Part] = []
	for p in signal_parts:
		if not Defs.has_input(p.type_id):
			continue
		var srcs: Array = in_links.get(p.cell, [])
		var on := 0
		for s in srcs:
			var sp: Part = cells.get(s)
			if sp != null and sp.sig_out:
				on += 1
		var was_wired := p.wired_in
		var was_in := p.sig_in
		p.wired_in = srcs.size() > 0
		p.in_total = srcs.size()
		p.in_on = on
		p.sig_in = on > 0
		if was_wired != p.wired_in or was_in != p.sig_in:
			changed.append(p)
	for p in signal_parts:
		if Defs.has_output(p.type_id):
			p.update_output(delta)
	for p in changed:
		p.on_signal()


# ------------------------------------------------------------ teleporters

func register_teleporter(p: Part) -> void:
	teleporters.append(p)


func unregister_teleporter(p: Part) -> void:
	teleporters.erase(p)


func receivers(channel: int) -> Array:
	var out := []
	for t in teleporters:
		if String(t.def.role) == "recv" and int(t.config.channel) == channel:
			out.append(t)
	return out


# ------------------------------------------------------------ items

func can_spawn() -> bool:
	return active_items.size() < Game.item_cap()


func spawn_item(props: Dictionary, xf: Transform3D, vel: Vector3 = Vector3.ZERO, force: bool = false) -> Item:
	if not force and not can_spawn():
		return null
	if active_items.size() >= Game.item_cap() + 200:
		return null
	var it: Item
	if _free_items.size() > 0:
		it = _free_items.pop_back()
	else:
		it = Item.new()
		items_root.add_child(it)
	it.activate(props, xf, vel)
	active_items.append(it)
	return it


func queue_job(c: Callable) -> void:
	_jobs.append(c)


func consume_item(it: Item) -> void:
	if not it.active:
		return
	it.active = false
	it.visible = false
	_retire_queue.append(it)


func sell(it: Item, seller: Part) -> void:
	if not it.active:
		return
	var base: float = it.value() * float(seller.call("sell_mult")) * Game.sell_mult()
	var key := it.product_key()
	var demand := Game.demand(key)
	var amount: float = base * demand
	Game.add_money(amount)
	Game.on_sold(it, amount)
	it.active = false
	it.visible = false
	_retire_queue.append(it)
	var col := Color("7aff9a") if demand > 0.8 else (Color("ffe07a") if demand > 0.5 else Color("ff9a7a"))
	FX.popup(seller.global_position + Vector3(0, 1.0, 0), "+" + Util.money(amount), col)
	FX.play("sell", 0.9 + minf(it.quality, 4.0) * 0.08, 0.06)
	if randf() < 0.35:
		FX.burst("coins", seller.global_position + Vector3(0, 0.5, 0))


func _retire_now(it: Item) -> void:
	active_items.erase(it)
	it.deactivate()
	if not _free_items.has(it):
		_free_items.append(it)


## Cuts an item with a plane (world space). Returns the resulting pieces ([item] if the blade only grazed it).
func cut_item(it: Item, point: Vector3, normal: Vector3, min_piece: float = 0.03) -> Array:
	if not it.active or it.form == "crate":
		return [it]
	var xf := it.global_transform.orthonormalized()
	var n_local := (xf.basis.inverse() * normal).normalized()
	var k := 0
	if absf(n_local.y) > absf(n_local[k]):
		k = 1
	if absf(n_local.z) > absf(n_local[k]):
		k = 2
	var size := it.size
	var c: float = (xf.affine_inverse() * point)[k]
	var new_shape := it.shape
	if it.shape == "cyl" and k != 2:
		var f := sqrt(PI / 4.0)
		size = Vector3(size.x * f, size.y * f, size.z)
		c *= f
		new_shape = "box"
	var h: float = size[k] * 0.5
	if absf(c) > h - min_piece:
		return [it]
	var la := c + h
	var lb := h - c
	var sa := size
	var sb := size
	sa[k] = la
	sb[k] = lb
	var axis: Vector3 = xf.basis[k].normalized()
	var vel := it.linear_velocity
	var props := it.props()
	props.size = sb
	props.shape = new_shape
	var sep := 0.35
	var b := spawn_item(props, Transform3D(xf.basis, xf.origin + axis * (c + lb * 0.5)), vel + axis * sep, true)
	it.global_transform = Transform3D(xf.basis, xf.origin + axis * (-h + la * 0.5))
	it.set_geometry(new_shape, sa)
	it.linear_velocity = vel - axis * sep
	if b == null:
		return [it]
	return [it, b]


## Breaks an item into fragments no bigger than max_piece and ejects them at out_pos.
func crush_item(it: Item, max_piece: float, out_pos: Vector3, out_vel: Vector3) -> void:
	var sizes: Array[Vector3] = [it.size if it.shape != "cyl" else Vector3(it.size.x * 0.886, it.size.y * 0.886, it.size.z)]
	var guard := 0
	while guard < 40 and sizes.size() < 12:
		guard += 1
		var idx := -1
		var best := max_piece
		for i in sizes.size():
			var m: float = maxf(sizes[i].x, maxf(sizes[i].y, sizes[i].z))
			if m > best:
				best = m
				idx = i
		if idx < 0:
			break
		var s: Vector3 = sizes[idx]
		var k := 0
		if s.y > s[k]:
			k = 1
		if s.z > s[k]:
			k = 2
		var f := randf_range(0.38, 0.62)
		var a := s
		var b := s
		a[k] = s[k] * f
		b[k] = s[k] * (1.0 - f)
		sizes[idx] = a
		sizes.append(b)
	var props := it.props()
	props.shape = "chunk"
	var cat := Defs.mat_cat(it.mat)
	if cat == "gem" and not it.refined:
		var scale := pow(clampf(it.purity, 0.05, 1.0), 1.0 / 3.0)
		props.refined = true
		props.purity = 1.0
		for i in sizes.size():
			sizes[i] = sizes[i] * scale
	var basis := Basis.from_euler(Vector3(randf() * TAU, randf() * TAU, randf() * TAU))
	for i in sizes.size():
		var off := Vector3(randf_range(-0.18, 0.18), 0.08 * (i % 4), randf_range(-0.08, 0.08))
		var xf := Transform3D(basis.rotated(Vector3.UP, randf() * TAU), out_pos + off)
		var v := out_vel + Vector3(randf_range(-0.3, 0.3), randf_range(0.0, 0.6), randf_range(-0.3, 0.3))
		props.size = sizes[i]
		props.variant = randi() % 4
		if i == 0:
			it.global_transform = xf
			it.shape = "chunk"
			it.refined = bool(props.refined)
			it.purity = float(props.purity)
			it.variant = int(props.variant)
			it.set_geometry("chunk", sizes[i])
			it.linear_velocity = v
		else:
			spawn_item(props, xf, v, true)


func _flatten(it: Item) -> bool:
	var xf := it.global_transform.orthonormalized()
	var up_l := xf.basis.inverse() * Vector3.UP
	var k := 0
	if absf(up_l.y) > absf(up_l[k]):
		k = 1
	if absf(up_l.z) > absf(up_l[k]):
		k = 2
	var s := it.size
	if s[k] <= 0.012:
		return false
	for j in 3:
		if j == k:
			s[j] *= 0.5
		else:
			s[j] = minf(s[j] * sqrt(2.0), 0.95)
	it.set_geometry("box", s)
	return true


## Hammer impact. Returns true if the item changed.
func press_item(it: Item) -> bool:
	if not it.active:
		return false
	match it.cat():
		"glass":
			if it.heat < 0.4:
				# cold glass shatters into cullet
				it.broken = true
				var shards := cut_item(it, it.global_position, Vector3(1, 0, 0).rotated(Vector3.UP, randf() * TAU), 0.01)
				for sh in shards:
					var more := cut_item(sh, sh.global_position, Vector3(0, 0, 1).rotated(Vector3.UP, randf() * TAU), 0.01)
					for m in more:
						(m as Item).set_geometry("chunk", (m as Item).size)
				FX.burst("shine", it.global_position)
				return true
			return _flatten(it)
		"metal":
			return _flatten(it)
		"gem":
			if it.refined:
				it.quality *= 0.6
				var pieces := cut_item(it, it.global_position + Vector3(randf_range(-0.02, 0.02), 0, 0), Vector3(1, 0, 0).rotated(Vector3.UP, randf() * TAU), 0.01)
				for p in pieces:
					cut_item(p, p.global_position, Vector3(0, 0, 1).rotated(Vector3.UP, randf() * TAU), 0.01)
				return true
		"ore":
			cut_item(it, it.global_position, Vector3(1, 0, 0).rotated(Vector3.UP, randf() * TAU))
			return true
	return false


func cool_rate(it: Item) -> float:
	return 0.2 if it.mat == "sand" else 0.06


func _item_resting_on_part(it: Item) -> bool:
	var p := it.global_position
	var c := Vector3i(floori(p.x), floori(p.y - 0.15), floori(p.z))
	return cells.has(c) or cells.has(c + Vector3i(0, -1, 0))


func _physics_process(delta: float) -> void:
	if not _retire_queue.is_empty():
		for it in _retire_queue:
			_retire_now(it)
		_retire_queue.clear()
	if not _jobs.is_empty():
		var jobs := _jobs
		_jobs = []
		for j in jobs:
			j.call()
	_signal_step(delta)
	for p in tickers:
		p.tick(delta)
	for p in signal_parts:
		p.end_signal_tick()
	wires.update_states(_links_dirty)
	_links_dirty = false
	# item housekeeping
	var i := active_items.size() - 1
	while i >= 0:
		var it: Item = active_items[i]
		it.age += delta
		if it.heat > 0.0:
			it.set_heat(it.heat - delta * cool_rate(it))
		if it.linear_velocity.length_squared() < 0.01 and not _item_resting_on_part(it):
			it.still_time += delta
		else:
			it.still_time = 0.0
		if it.global_position.y < -20.0 or it.age > ITEM_LIFETIME or it.still_time > STILL_LIMIT:
			active_items.remove_at(i)
			it.deactivate()
			_free_items.append(it)
		i -= 1
