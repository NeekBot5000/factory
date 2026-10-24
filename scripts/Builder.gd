class_name Builder
extends Node
## Placement, demolish, blueprint copy/paste. Drag to paint, Shift+drag to fill rectangles.

signal mode_changed
signal selection_changed

const MAX_GHOSTS := 300
const MAX_FILL := 900

var world: Node
var rig: CameraRig
var cam: Camera3D
var hud: Node

var mode := "none"   # none | build | demolish | select | paste
var part_id := ""
var rot := 0
var layer_off := 0

var hover_cell := Vector3i.ZERO
var hover_ok := false
var hover_part: Part = null

var clipboard: Array = []   # {id, rel: Vector3i, rot}
var selection: Array[Part] = []

var _dragging := false
var _drag_start := Vector3i.ZERO
var _last_cell := Vector3i(99999, 0, 0)
var _last_placed: Part = null
var _ghosts: Array[Part] = []
var _markers: Array[MeshInstance3D] = []
var _sig := ""
var _ghost_ok := Color(0.25, 1.0, 0.45, 0.45)
var _ghost_bad := Color(1.0, 0.25, 0.25, 0.5)
var _ghost_poor := Color(1.0, 0.85, 0.2, 0.5)
var _ov_ok: StandardMaterial3D
var _ov_bad: StandardMaterial3D
var _ov_poor: StandardMaterial3D
var _marker_red: StandardMaterial3D
var _marker_blue: StandardMaterial3D
var _marker_green: StandardMaterial3D
var _last_upgraded: Part = null
var _plan_cost := 0.0
var _plan_count := 0
var _plan_invalid := 0


func setup(p_world: Node, p_rig: CameraRig) -> void:
	world = p_world
	rig = p_rig
	cam = p_rig.camera
	rig.right_clicked.connect(cancel)
	_ov_ok = _overlay(_ghost_ok)
	_ov_bad = _overlay(_ghost_bad)
	_ov_poor = _overlay(_ghost_poor)
	_marker_red = _overlay(Color(1, 0.2, 0.2, 0.45))
	_marker_blue = _overlay(Color(0.3, 0.6, 1.0, 0.4))
	_marker_green = _overlay(Color(0.4, 1.0, 0.4, 0.4))


func _overlay(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.no_depth_test = false
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
	if m == "demolish" or m == "select" or m == "upgrade":
		part_id = ""
	_reset_drag()
	if m != "select":
		selection.clear()
	_after_mode()


func cancel() -> void:
	if _dragging:
		_reset_drag()
		return
	if mode != "none":
		set_mode("none")


func _after_mode() -> void:
	_sig = ""
	world.terrain.set_grid_visible(mode != "none")
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


func _rotate_clipboard() -> void:
	var out: Array = []
	var minx := 99999
	var minz := 99999
	for e in clipboard:
		var r: Vector3i = e.rel
		var nr := Vector3i(-r.z, r.y, r.x)
		out.append({"id": e.id, "rel": nr, "rot": posmod(int(e.rot) + 1, 4) if Defs.is_directional(e.id) else int(e.rot)})
		minx = mini(minx, nr.x)
		minz = mini(minz, nr.z)
	for e in out:
		e.rel = Vector3i(e.rel.x - minx, e.rel.y, e.rel.z - minz)
	clipboard = out


func copy_selection() -> void:
	if selection.is_empty():
		Game.toast.emit("Select parts first (B, then drag)", Color("ffd27a"))
		return
	var mn := Vector3i(99999, 99999, 99999)
	for p in selection:
		mn = Vector3i(mini(mn.x, p.cell.x), mini(mn.y, p.cell.y), mini(mn.z, p.cell.z))
	clipboard = []
	for p in selection:
		clipboard.append({"id": p.type_id, "rel": p.cell - mn, "rot": p.rot})
	Game.toast.emit("Copied %d parts. Click to paste, R to rotate." % clipboard.size(), Color("7aff9a"))
	set_mode("paste")


func export_clipboard() -> Array:
	var out := []
	for e in clipboard:
		var r: Vector3i = e.rel
		out.append({"id": e.id, "x": r.x, "y": r.y, "z": r.z, "rot": e.rot})
	return out


func import_clipboard(data: Array) -> void:
	clipboard = []
	for e in data:
		var id := String(e.get("id", ""))
		if Defs.PARTS.has(id):
			clipboard.append({"id": id, "rel": Vector3i(int(e.x), int(e.y), int(e.z)), "rot": int(e.rot)})
	if clipboard.is_empty():
		return
	set_mode("paste")


func paste_mode() -> void:
	if clipboard.is_empty():
		Game.toast.emit("Clipboard empty. Use Select (B) and Copy (C).", Color("ffd27a"))
		return
	set_mode("paste")


# ------------------------------------------------------------ picking

func _pointer_blocked() -> bool:
	return hud != null and hud.pointer_over_ui()


func _update_hover() -> void:
	hover_ok = false
	hover_part = null
	if _pointer_blocked():
		return
	var vp := cam.get_viewport()
	var mp := vp.get_mouse_position()
	var from := cam.project_ray_origin(mp)
	var to := from + cam.project_ray_normal(mp) * 400.0
	var q := PhysicsRayQueryParameters3D.create(from, to, 1)
	var space := cam.get_world_3d().direct_space_state
	var hit := space.intersect_ray(q)
	if hit.is_empty():
		return
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
	var x0 := mini(a.x, b.x)
	var x1 := maxi(a.x, b.x)
	var z0 := mini(a.z, b.z)
	var z1 := maxi(a.z, b.z)
	for x in range(x0, x1 + 1):
		for z in range(z0, z1 + 1):
			out.append(Vector3i(x, a.y, z))
			if out.size() >= MAX_FILL:
				return out
	return out


func _plan() -> Array:
	# returns list of {id, cell, rot, ok}
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
				plan.append({"id": part_id, "cell": c, "rot": rot, "ok": world.can_place(c)})
		"paste":
			for e in clipboard:
				var c: Vector3i = hover_cell + (e.rel as Vector3i)
				plan.append({"id": e.id, "cell": c, "rot": e.rot, "ok": world.can_place(c)})
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
			if is_instance_valid(_last_placed) and String(_last_placed.def.kind) == "belt":
				_last_placed.set_rot(d)
	_last_cell = c
	var p := _try_place(c)
	if p != null:
		_last_placed = p


func _try_place(c: Vector3i, id: String = "", r: int = -1) -> Part:
	var pid := part_id if id == "" else id
	var rr := rot if r < 0 else r
	if not world.can_place(c):
		return null
	var p: Part = world.place(pid, c, rr, true)
	if p == null:
		Game.toast.emit("Not enough money (%s)" % Util.money(Game.part_cost(pid)), Color("ff7a7a"))
		FX.play("error", 1.0, 0.25)
		return null
	FX.play("place", randf_range(0.95, 1.1), 0.03)
	return p


func _refresh_visuals() -> void:
	var sig := "%s|%s|%d|%s|%s|%s|%s|%d" % [mode, part_id, rot, str(hover_cell), hover_ok, _dragging, Input.is_key_pressed(KEY_SHIFT), clipboard.size()]
	var poor_sig := "%d" % int(Game.money)
	if sig + poor_sig == _sig and mode not in ["demolish", "select", "upgrade"]:
		return
	_sig = sig + poor_sig
	_clear_ghosts()
	_plan_cost = 0.0
	_plan_count = 0
	_plan_invalid = 0
	var marks: Array = []
	match mode:
		"build", "paste":
			var plan := _plan()
			var running := Game.money
			var counts := {}
			var n := 0
			for e in plan:
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
					var g := Part.new()
					add_child(g)
					g.setup(world, e.id, e.cell, e.rot, true)
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
	if not hover_ok and mode != "demolish" and mode != "upgrade":
		return
	match mode:
		"build":
			if not hover_ok:
				return
			_dragging = true
			_drag_start = hover_cell
			_last_cell = Vector3i(99999, 0, 0)
			if not Input.is_key_pressed(KEY_SHIFT):
				_paint_step()
		"paste":
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
				Game.toast.emit("%d parts selected. Press C to copy, Delete to remove." % selection.size(), Color("7ab8ff"))
	_reset_drag()
	_sig = ""


func _commit_fill() -> void:
	var plan := _plan()
	var placed := 0
	var broke := false
	for e in plan:
		if not e.ok:
			continue
		var p := _try_place(e.cell, e.id, e.rot)
		if p == null:
			broke = true
			break
		placed += 1
	if placed > 0:
		FX.play("buy")
	if broke:
		Game.toast.emit("Ran out of money after %d parts" % placed, Color("ffd27a"))


func _do_paste() -> void:
	var plan := _plan()
	var placed := 0
	for e in plan:
		if not e.ok:
			continue
		var p := _try_place(e.cell, e.id, e.rot)
		if p == null:
			Game.toast.emit("Ran out of money after %d parts" % placed, Color("ffd27a"))
			break
		placed += 1
	if placed > 0:
		FX.play("buy")


func _upgrade_one(p: Part) -> void:
	_last_upgraded = p
	if not p.can_upgrade():
		Game.toast.emit("%s is already max level" % p.def.name if p.level >= Defs.LEVEL_MAX else "This part can't be upgraded", Color("ffd27a"))
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
	world.remove(p, true)
	FX.play("remove", randf_range(0.95, 1.1), 0.03)


func _on_key(e: InputEventKey) -> void:
	var k := e.keycode
	if k == KEY_ESCAPE:
		if mode != "none":
			cancel()
		else:
			hud.toggle_menu()
		return
	if k >= KEY_1 and k <= KEY_9 and not e.ctrl_pressed:
		hud.pick_slot(k - KEY_1)
		return
	match k:
		KEY_R:
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
		KEY_H:
			hud.toggle_panel("help")
		KEY_P:
			hud.toggle_panel("ascend")
		KEY_F:
			hud.toggle_panel("blueprints")
