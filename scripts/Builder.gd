class_name Builder
extends Node
## Placement, demolish, upgrade, wiring, blueprint copy/paste and click-to-interact.
## Drag to paint lines (belts auto-turn), Shift+drag to fill rectangles.

signal mode_changed
signal selection_changed

const MAX_GHOSTS := 300
const MAX_FILL := 900

var world: Node
var rig: CameraRig
var cam: Camera3D
var hud: Node

var mode := "none"   # none | build | demolish | select | paste | upgrade | wire
var part_id := ""
var rot := 0
var layer_off := 0

var hover_cell := Vector3i.ZERO
var hover_ok := false
var hover_part: Part = null
var hover_point := Vector3.ZERO

var clipboard: Array = []        # {id, rel: Vector3i, rot, cfg}
var clip_links: Array = []       # {a: Vector3i rel, b: Vector3i rel}
var selection: Array[Part] = []
var wire_src: Vector3i = Vector3i(99999, 0, 0)

var _dragging := false
var _drag_start := Vector3i.ZERO
var _last_cell := Vector3i(99999, 0, 0)
var _last_placed: Part = null
var _last_upgraded: Part = null
var _ghosts: Array[Part] = []
var _markers: Array[MeshInstance3D] = []
var _sig := ""
var _ov_ok: StandardMaterial3D
var _ov_bad: StandardMaterial3D
var _ov_poor: StandardMaterial3D
var _marker_red: StandardMaterial3D
var _marker_blue: StandardMaterial3D
var _marker_green: StandardMaterial3D
var _marker_yellow: StandardMaterial3D
var _plan_cost := 0.0
var _plan_count := 0
var _plan_invalid := 0


func setup(p_world: Node, p_rig: CameraRig) -> void:
	world = p_world
	rig = p_rig
	cam = p_rig.camera
	rig.right_clicked.connect(cancel)
	_ov_ok = _overlay(Color(0.25, 1.0, 0.45, 0.45))
	_ov_bad = _overlay(Color(1.0, 0.25, 0.25, 0.5))
	_ov_poor = _overlay(Color(1.0, 0.85, 0.2, 0.5))
	_marker_red = _overlay(Color(1, 0.2, 0.2, 0.45))
	_marker_blue = _overlay(Color(0.3, 0.6, 1.0, 0.4))
	_marker_green = _overlay(Color(0.4, 1.0, 0.4, 0.4))
	_marker_yellow = _overlay(Color(1.0, 0.85, 0.2, 0.4))


func _overlay(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


# ------------------------------------------------------------ mode api

func select_part(id: String) -> void:
	if not Game.part_unlocked(id):
		if Game.try_unlock(id):
			hud.refresh_hotbar()
		else:
			return
	mode = "build"
	part_id = id
	_reset_drag()
	_after_mode()


func set_mode(m: String) -> void:
	mode = m
	if m != "build":
		part_id = ""
	_reset_drag()
	if m != "select":
		selection.clear()
	wire_src = Vector3i(99999, 0, 0)
	world.wires.set_preview(false)
	_after_mode()


func cancel() -> void:
	if _dragging:
		_reset_drag()
		return
	if mode == "wire" and wire_src.x != 99999:
		wire_src = Vector3i(99999, 0, 0)
		world.wires.set_preview(false)
		mode_changed.emit()
		return
	if mode != "none":
		set_mode("none")
	elif hud.inspected != null:
		hud.inspect(null)


func _after_mode() -> void:
	_sig = ""
	world.terrain.set_grid_visible(mode in ["build", "paste"])
	mode_changed.emit()


func _reset_drag() -> void:
	_dragging = false
	_last_cell = Vector3i(99999, 0, 0)
	_last_placed = null


func rotate_selection(step: int) -> void:
	if mode == "paste":
		for _i in (step if step > 0 else 3):
			_rotate_clipboard()
	else:
		rot = posmod(rot + step, 4)
	_sig = ""


func _rot_rel(r: Vector3i) -> Vector3i:
	return Vector3i(-r.z, r.y, r.x)


func _rotate_clipboard() -> void:
	var out: Array = []
	var minx := 99999
	var minz := 99999
	for e in clipboard:
		var nr := _rot_rel(e.rel)
		out.append({"id": e.id, "rel": nr, "rot": posmod(int(e.rot) + 1, 4) if Defs.is_directional(e.id) else int(e.rot), "cfg": e.cfg})
		minx = mini(minx, nr.x)
		minz = mini(minz, nr.z)
	var shift := Vector3i(-minx, 0, -minz)
	for e in out:
		e.rel = (e.rel as Vector3i) + shift
	var nl: Array = []
	for l in clip_links:
		nl.append({"a": _rot_rel(l.a) + shift, "b": _rot_rel(l.b) + shift})
	clipboard = out
	clip_links = nl


func copy_selection() -> void:
	if selection.is_empty():
		Game.toast.emit("Select parts first (B, then drag)", Color("ffd27a"))
		return
	var mn := Vector3i(99999, 99999, 99999)
	var cellset := {}
	for p in selection:
		mn = Vector3i(mini(mn.x, p.cell.x), mini(mn.y, p.cell.y), mini(mn.z, p.cell.z))
		cellset[p.cell] = true
	clipboard = []
	for p in selection:
		clipboard.append({"id": p.type_id, "rel": p.cell - mn, "rot": p.rot, "cfg": p.config.duplicate()})
	clip_links = []
	for l in world.links:
		if cellset.has(l.a) and cellset.has(l.b):
			clip_links.append({"a": (l.a as Vector3i) - mn, "b": (l.b as Vector3i) - mn})
	Game.toast.emit("Copied %d parts and %d wires. Click to paste, R to rotate." % [clipboard.size(), clip_links.size()], Color("7aff9a"))
	set_mode("paste")


func export_clipboard() -> Dictionary:
	var parts_out := []
	for e in clipboard:
		var r: Vector3i = e.rel
		parts_out.append({"id": e.id, "x": r.x, "y": r.y, "z": r.z, "rot": e.rot, "cfg": e.cfg})
	var links_out := []
	for l in clip_links:
		links_out.append([l.a.x, l.a.y, l.a.z, l.b.x, l.b.y, l.b.z])
	return {"parts": parts_out, "links": links_out}


func import_clipboard(data: Variant) -> void:
	clipboard = []
	clip_links = []
	var plist: Array = data.get("parts", []) if data is Dictionary else data
	for e in plist:
		var id := String(e.get("id", ""))
		if Defs.PARTS.has(id):
			clipboard.append({"id": id, "rel": Vector3i(int(e.x), int(e.y), int(e.z)), "rot": int(e.rot), "cfg": e.get("cfg", {})})
	if data is Dictionary:
		for l in data.get("links", []):
			clip_links.append({"a": Vector3i(int(l[0]), int(l[1]), int(l[2])), "b": Vector3i(int(l[3]), int(l[4]), int(l[5]))})
	if not clipboard.is_empty():
		set_mode("paste")


func paste_mode() -> void:
	if clipboard.is_empty():
		Game.toast.emit("Clipboard empty. Use Select (B) and Copy (C).", Color("ffd27a"))
		return
	set_mode("paste")


func start_wire_from(p: Part) -> void:
	set_mode("wire")
	if Defs.has_output(p.type_id):
		wire_src = p.cell
	mode_changed.emit()


# ------------------------------------------------------------ picking

func _pointer_blocked() -> bool:
	return hud != null and hud.pointer_over_ui()


func _update_hover() -> void:
	hover_ok = false
	hover_part = null
	if _pointer_blocked():
		return
	var mp := cam.get_viewport().get_mouse_position()
	var from := cam.project_ray_origin(mp)
	var to := from + cam.project_ray_normal(mp) * 400.0
	var q := PhysicsRayQueryParameters3D.create(from, to, 1)
	var hit := cam.get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return
	hover_point = hit.position
	var col: Object = hit.collider
	if col.has_meta("part"):
		hover_part = col.get_meta("part")
		var n: Vector3 = hit.normal
		var an := n.abs()
		var off := Vector3i.ZERO
		if an.y >= an.x and an.y >= an.z:
			off = Vector3i(0, 1 if n.y > 0 else -1, 0)
		elif an.x >= an.z:
			off = Vector3i(1 if n.x > 0 else -1, 0, 0)
		else:
			off = Vector3i(0, 0, 1 if n.z > 0 else -1)
		hover_cell = hover_part.cell + off + Vector3i(0, layer_off, 0)
		hover_ok = true
	elif col.has_meta("plot"):
		var p: Vector3 = hit.position
		if hit.normal.y > 0.5:
			hover_cell = Vector3i(floori(p.x), layer_off, floori(p.z))
			hover_ok = true


# ------------------------------------------------------------ plan computation

func _fill_cells(a: Vector3i, b: Vector3i) -> Array[Vector3i]:
	var out: Array[Vector3i] = []
	for x in range(mini(a.x, b.x), maxi(a.x, b.x) + 1):
		for z in range(mini(a.z, b.z), maxi(a.z, b.z) + 1):
			out.append(Vector3i(x, a.y, z))
			if out.size() >= MAX_FILL:
				return out
	return out


func _plan() -> Array:
	var plan: Array = []
	if not hover_ok:
		return plan
	match mode:
		"build":
			var cells_list: Array[Vector3i] = []
			if _dragging and Input.is_key_pressed(KEY_SHIFT):
				cells_list = _fill_cells(_drag_start, Vector3i(hover_cell.x, _drag_start.y, hover_cell.z))
			else:
				cells_list.append(hover_cell)
			for c in cells_list:
				plan.append({"id": part_id, "cell": c, "rot": rot, "ok": world.can_place(c), "cfg": {}})
		"paste":
			for e in clipboard:
				var c: Vector3i = hover_cell + (e.rel as Vector3i)
				plan.append({"id": e.id, "cell": c, "rot": e.rot, "ok": world.can_place(c), "cfg": e.cfg})
	return plan


func _rect_parts() -> Array[Part]:
	var out: Array[Part] = []
	var a := _drag_start
	var b := hover_cell
	var x0 := mini(a.x, b.x)
	var x1 := maxi(a.x, b.x)
	var z0 := mini(a.z, b.z)
	var z1 := maxi(a.z, b.z)
	for p in world.parts:
		if p.cell.x >= x0 and p.cell.x <= x1 and p.cell.z >= z0 and p.cell.z <= z1:
			out.append(p)
	return out


# ------------------------------------------------------------ frame

func _process(_delta: float) -> void:
	_update_hover()
	if _dragging and mode == "demolish" and not Input.is_key_pressed(KEY_SHIFT) and hover_part != null:
		_demolish(hover_part)
	if _dragging and mode == "upgrade" and not Input.is_key_pressed(KEY_SHIFT) and hover_part != null and hover_part != _last_upgraded:
		_upgrade_one(hover_part)
	if _dragging and mode == "build" and not Input.is_key_pressed(KEY_SHIFT) and hover_ok:
		_paint_step()
	if mode == "wire" and wire_src.x != 99999:
		var sp: Part = world.cells.get(wire_src)
		if sp == null:
			wire_src = Vector3i(99999, 0, 0)
			world.wires.set_preview(false)
		else:
			var tgt := hover_point if hover_ok else sp.port_out_pos()
			if hover_part != null and Defs.has_input(hover_part.type_id):
				tgt = hover_part.port_in_pos()
			world.wires.set_preview(true, sp.port_out_pos(), tgt)
	_refresh_visuals()
	if hud != null:
		hud.update_hover_info(self)


func _paint_step() -> void:
	var c := hover_cell
	if c == _last_cell:
		return
	var is_dir := Defs.is_directional(part_id)
	var delta := c - _last_cell
	if _last_cell.x != 99999 and is_dir and delta.y == 0 and absi(delta.x) + absi(delta.z) == 1:
		var d := Defs.dir_index(delta)
		if d >= 0:
			rot = d
			if is_instance_valid(_last_placed) and _last_placed.kind() == "belt":
				_last_placed.set_rot(d)
				world._notify_neighbors(_last_placed.cell)
				_last_placed.on_neighbor_changed()
	_last_cell = c
	var p := _try_place(c)
	if p != null:
		_last_placed = p


func _try_place(c: Vector3i, id: String = "", r: int = -1, cfg: Dictionary = {}) -> Part:
	var pid := part_id if id == "" else id
	var rr := rot if r < 0 else r
	if not world.can_place(c):
		return null
	if not Game.can_afford(Game.part_cost(pid)):
		Game.toast.emit("Not enough money (%s)" % Util.money(Game.part_cost(pid)), Color("ff7a7a"))
		FX.play("error", 1.0, 0.25)
		return null
	var p: Part = world.place(pid, c, rr, true, -1.0, cfg)
	if p == null:
		return null
	FX.play("place", randf_range(0.95, 1.1), 0.03)
	return p


func _refresh_visuals() -> void:
	var sig := "%s|%s|%d|%s|%s|%s|%s|%d|%d" % [mode, part_id, rot, str(hover_cell), hover_ok, _dragging, Input.is_key_pressed(KEY_SHIFT), clipboard.size(), int(Game.money)]
	if sig == _sig and mode not in ["demolish", "select", "upgrade", "wire"]:
		return
	_sig = sig
	_clear_ghosts()
	_plan_cost = 0.0
	_plan_count = 0
	_plan_invalid = 0
	var marks: Array = []
	match mode:
		"build", "paste":
			var running := Game.money
			var counts := {}
			var n := 0
			for e in _plan():
				var ok: bool = e.ok
				var affordable := true
				if ok:
					var id: String = e.id
					var k := int(counts.get(id, 0))
					var cost := float(Defs.PARTS[id].cost) * pow(Game.COST_GROWTH, int(Game.part_counts.get(id, 0)) + k)
					counts[id] = k + 1
					if running + 0.0001 < cost:
						affordable = false
					else:
						running -= cost
						_plan_cost += cost
					_plan_count += 1
				else:
					_plan_invalid += 1
				if n < MAX_GHOSTS:
					var g := Part.create(e.id)
					add_child(g)
					g.setup(null, e.id, e.cell, e.rot, true)
					g.set_overlay(_ov_ok if (ok and affordable) else (_ov_poor if ok else _ov_bad))
					_ghosts.append(g)
				n += 1
		"demolish":
			if hover_ok and _dragging and Input.is_key_pressed(KEY_SHIFT):
				for p in _rect_parts():
					marks.append([p.cell, _marker_red])
			elif hover_part != null:
				marks.append([hover_part.cell, _marker_red])
		"upgrade":
			if hover_ok and _dragging and Input.is_key_pressed(KEY_SHIFT):
				for p in _rect_parts():
					marks.append([p.cell, _marker_green])
			elif hover_part != null:
				marks.append([hover_part.cell, _marker_green])
		"select":
			if hover_ok and _dragging:
				for p in _rect_parts():
					marks.append([p.cell, _marker_blue])
			else:
				for p in selection:
					if is_instance_valid(p):
						marks.append([p.cell, _marker_blue])
		"wire":
			var choosing_src := wire_src.x == 99999
			for p in world.signal_parts:
				if choosing_src and Defs.has_output(p.type_id):
					marks.append([p.cell, _marker_yellow])
				elif not choosing_src and Defs.has_input(p.type_id) and p.cell != wire_src:
					marks.append([p.cell, _marker_blue])
			if not choosing_src:
				marks.append([wire_src, _marker_green])
	_set_markers(marks)


func _clear_ghosts() -> void:
	for g in _ghosts:
		g.queue_free()
	_ghosts.clear()


func _set_markers(marks: Array) -> void:
	while _markers.size() < marks.size():
		var m := MeshInstance3D.new()
		m.mesh = Meshes.box_mesh(Vector3(1.04, 1.04, 1.04))
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		world.add_child(m)
		_markers.append(m)
	for i in _markers.size():
		var m := _markers[i]
		if i < marks.size():
			var c: Vector3i = marks[i][0]
			m.visible = true
			m.position = Vector3(c.x + 0.5, c.y + 0.5, c.z + 0.5)
			m.material_override = marks[i][1]
		else:
			m.visible = false


func plan_text() -> String:
	if mode == "build" or mode == "paste":
		var t := ""
		if _plan_count > 0:
			t = "%d part%s  %s" % [_plan_count, "" if _plan_count == 1 else "s", Util.money(_plan_cost)]
		if _plan_invalid > 0:
			t += "   (%d blocked)" % _plan_invalid
		return t
	return ""


# ------------------------------------------------------------ input

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var e := event as InputEventMouseButton
		if e.button_index == MOUSE_BUTTON_LEFT:
			if e.pressed:
				_on_left_down()
			else:
				_on_left_up()
		elif e.ctrl_pressed and e.pressed and (e.button_index == MOUSE_BUTTON_WHEEL_UP or e.button_index == MOUSE_BUTTON_WHEEL_DOWN):
			layer_off = clampi(layer_off + (1 if e.button_index == MOUSE_BUTTON_WHEEL_UP else -1), 0, Defs.MAX_LAYER)
			_sig = ""
	elif event is InputEventKey and event.pressed and not event.echo:
		_on_key(event as InputEventKey)


func _on_left_down() -> void:
	match mode:
		"none":
			if hover_part != null:
				if not hover_part.interact():
					hud.inspect(hover_part)
				else:
					hud.refresh_inspector()
			else:
				hud.inspect(null)
		"build":
			if not hover_ok:
				return
			_dragging = true
			_drag_start = hover_cell
			_last_cell = Vector3i(99999, 0, 0)
			if not Input.is_key_pressed(KEY_SHIFT):
				_paint_step()
		"paste":
			if hover_ok:
				_do_paste()
		"demolish":
			_dragging = true
			_drag_start = hover_cell
			if not Input.is_key_pressed(KEY_SHIFT) and hover_part != null:
				_demolish(hover_part)
		"upgrade":
			if not hover_ok:
				return
			_dragging = true
			_drag_start = hover_cell
			_last_upgraded = null
			if not Input.is_key_pressed(KEY_SHIFT) and hover_part != null:
				_upgrade_one(hover_part)
		"select":
			if not hover_ok:
				return
			_dragging = true
			_drag_start = hover_cell
			selection.clear()
		"wire":
			_wire_click()


func _on_left_up() -> void:
	if not _dragging:
		return
	match mode:
		"build":
			if Input.is_key_pressed(KEY_SHIFT):
				_commit_fill()
		"demolish":
			if Input.is_key_pressed(KEY_SHIFT) and hover_ok:
				var list := _rect_parts()
				for p in list:
					world.remove(p, true)
				if list.size() > 0:
					FX.play("remove")
					Game.toast.emit("Demolished %d parts (refunded)" % list.size(), Color("ffd27a"))
		"upgrade":
			if Input.is_key_pressed(KEY_SHIFT) and hover_ok:
				_upgrade_many(_rect_parts())
		"select":
			if hover_ok:
				selection = _rect_parts()
				selection_changed.emit()
				Game.toast.emit("%d parts selected. C copy, G upgrade, Delete remove." % selection.size(), Color("7ab8ff"))
	_reset_drag()
	_sig = ""


func _wire_click() -> void:
	if hover_part == null:
		return
	if wire_src.x == 99999:
		if not Defs.has_output(hover_part.type_id):
			Game.toast.emit("%s has no output. Start from a lever, button, timer, sensor, gate, counter or seller." % hover_part.def.name, Color("ffd27a"))
			FX.play("error", 1.0, 0.2)
			return
		wire_src = hover_part.cell
		FX.play("click", 1.2)
		mode_changed.emit()
		return
	if hover_part.cell == wire_src:
		wire_src = Vector3i(99999, 0, 0)
		world.wires.set_preview(false)
		mode_changed.emit()
		return
	if not Defs.has_input(hover_part.type_id):
		Game.toast.emit("%s has no input." % hover_part.def.name, Color("ffd27a"))
		FX.play("error", 1.0, 0.2)
		return
	if world.has_link(wire_src, hover_part.cell):
		world.remove_link(wire_src, hover_part.cell)
		Game.toast.emit("Wire removed", Color("ffd27a"))
		FX.play("remove")
	else:
		world.add_link(wire_src, hover_part.cell)
		FX.play("place", 1.3)
	if not Input.is_key_pressed(KEY_SHIFT):
		wire_src = Vector3i(99999, 0, 0)
		world.wires.set_preview(false)
	mode_changed.emit()


func _commit_fill() -> void:
	var placed := 0
	var broke := false
	for e in _plan():
		if not e.ok:
			continue
		if _try_place(e.cell, e.id, e.rot) == null:
			broke = true
			break
		placed += 1
	if placed > 0:
		FX.play("buy")
	if broke:
		Game.toast.emit("Ran out of money after %d parts" % placed, Color("ffd27a"))


func _do_paste() -> void:
	var placed := 0
	for e in _plan():
		if not e.ok:
			continue
		if _try_place(e.cell, e.id, e.rot, e.cfg) == null:
			Game.toast.emit("Ran out of money after %d parts" % placed, Color("ffd27a"))
			break
		placed += 1
	var wired := 0
	for l in clip_links:
		if world.add_link(hover_cell + (l.a as Vector3i), hover_cell + (l.b as Vector3i)):
			wired += 1
	if placed > 0:
		FX.play("buy")


func _upgrade_one(p: Part) -> void:
	_last_upgraded = p
	if not p.can_upgrade():
		Game.toast.emit(("%s is already max level" % p.def.name) if p.level >= Defs.LEVEL_MAX else "This part can't be upgraded", Color("ffd27a"))
		return
	var n := 0
	var repeat := Input.is_key_pressed(KEY_CTRL)
	while world.upgrade_part(p):
		n += 1
		if not repeat:
			break
	if n > 0:
		FX.play("buy", 1.0 + 0.04 * p.level, 0.05)
		FX.popup(p.global_position + Vector3(0, 1.3, 0), "Lv %d" % p.level, Color("ffd23f"))
		hud.refresh_inspector()
	else:
		Game.toast.emit("Need %s to upgrade" % Util.money(p.upgrade_cost()), Color("ff7a7a"))
		FX.play("error", 1.0, 0.25)


func _upgrade_many(list: Array[Part]) -> void:
	var total := 0
	var broke := false
	var repeat := Input.is_key_pressed(KEY_CTRL)
	for p in list:
		if not p.can_upgrade():
			continue
		while world.upgrade_part(p):
			total += 1
			if not repeat:
				break
		if p.can_upgrade() and not Game.can_afford(p.upgrade_cost()):
			broke = true
	if total > 0:
		FX.play("buy")
		Game.toast.emit("Upgraded %d levels across %d parts%s" % [total, list.size(), " (out of money)" if broke else ""], Color("7aff9a"))
	elif list.size() > 0:
		Game.toast.emit("Nothing upgraded (max level or not enough money)", Color("ffd27a"))
		FX.play("error", 1.0, 0.25)


func upgrade_selection() -> void:
	var list: Array[Part] = []
	for p in selection:
		if is_instance_valid(p):
			list.append(p)
	if list.is_empty():
		set_mode("upgrade")
		return
	_upgrade_many(list)


func _demolish(p: Part) -> void:
	if hud.inspected == p:
		hud.inspect(null)
	world.remove(p, true)
	FX.play("remove", randf_range(0.95, 1.1), 0.03)


func _on_key(e: InputEventKey) -> void:
	var k := e.keycode
	if k == KEY_ESCAPE:
		if mode != "none" or hud.inspected != null:
			cancel()
		else:
			hud.toggle_menu()
		return
	if k >= KEY_1 and k <= KEY_9 and not e.ctrl_pressed:
		hud.pick_slot(k - KEY_1)
		return
	match k:
		KEY_R:
			if mode == "none" and hud.inspected != null and Defs.is_directional(hud.inspected.type_id):
				hud.inspected.set_rot(hud.inspected.rot + (-1 if e.shift_pressed else 1))
				world._notify_neighbors(hud.inspected.cell)
				hud.inspected.on_neighbor_changed()
			else:
				rotate_selection(-1 if e.shift_pressed else 1)
		KEY_Z, KEY_PAGEDOWN:
			layer_off = maxi(0, layer_off - 1)
			_sig = ""
		KEY_X, KEY_PAGEUP:
			layer_off = mini(Defs.MAX_LAYER, layer_off + 1)
			_sig = ""
		KEY_TAB:
			hud.cycle_category()
		KEY_B:
			set_mode("select")
		KEY_C:
			copy_selection()
		KEY_V:
			paste_mode()
		KEY_N:
			set_mode("wire")
		KEY_T, KEY_DELETE, KEY_BACKSPACE:
			if mode == "select" and not selection.is_empty():
				var n := 0
				for p in selection:
					if is_instance_valid(p):
						world.remove(p, true)
						n += 1
				selection.clear()
				FX.play("remove")
				Game.toast.emit("Removed %d parts (refunded)" % n, Color("ffd27a"))
			else:
				set_mode("demolish")
		KEY_G:
			if mode == "select" and not selection.is_empty():
				upgrade_selection()
			else:
				set_mode("upgrade")
		KEY_U:
			hud.toggle_panel("upgrades")
		KEY_L:
			hud.toggle_panel("land")
		KEY_J:
			hud.toggle_panel("quests")
		KEY_O:
			hud.toggle_panel("orders")
		KEY_M:
			hud.toggle_panel("market")
		KEY_H, KEY_F1:
			hud.toggle_panel("help")
		KEY_P:
			hud.toggle_panel("ascend")
		KEY_F:
			hud.toggle_panel("blueprints")
