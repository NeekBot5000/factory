extends Part
## Conveyor belt with low side guards. A guard opens automatically where something feeds in from that side
## (another belt pointing at us, a splitter, a piston pushing across, a teleporter, ...).

var _rails := [true, true]   # left, right
var _rail_shapes: Array[CollisionShape3D] = [null, null]
var _rail_handles: Array = [[], []]


func build() -> void:
	_deck(def.tint, float(def.speed))
	# under-frame legs
	_box(Vector3(0.08, 0.1, 0.08), Vector3(0.42, 0.0, 0.0), Meshes.mat(FRAME_COLOR))
	_box(Vector3(0.08, 0.1, 0.08), Vector3(-0.42, 0.0, 0.0), Meshes.mat(FRAME_COLOR))
	if not ghost:
		for side in 2:
			var sx := -0.465 if side == 0 else 0.465
			_rail_shapes[side] = _add_shape(body, Vector3(0.07, 0.16, 1.0), Vector3(sx, 0.27, 0))
	_update_rail_visuals()


func on_placed() -> void:
	refresh_rails()


func on_neighbor_changed() -> void:
	refresh_rails()


func apply_speed() -> void:
	_deck_speed(belt_speed() if enabled() else 0.0)


func info_lines() -> Array:
	return ["Speed %.1f u/s%s" % [belt_speed(), "" if enabled() else "  (STOPPED)"]]


func refresh_rails() -> void:
	if ghost:
		return
	var piston_near := false
	for side in 2:
		var d: Vector3i = Defs.DIRS[posmod(rot + (-1 if side == 0 else 1), 4)]
		var n: Part = world.cells.get(cell + d)
		if n != null and (n.kind() == "piston" or (n.kind() == "source" and Defs.is_directional(n.type_id))) and n.cell + Defs.DIRS[n.rot] == cell:
			piston_near = true
	for side in 2:
		var d: Vector3i = Defs.DIRS[posmod(rot + (-1 if side == 0 else 1), 4)]
		var n: Part = world.cells.get(cell + d)
		var open := piston_near or Belt_feeds(n, cell)
		_rails[side] = not open
		if _rail_shapes[side] != null:
			_rail_shapes[side].disabled = open
	_update_rail_visuals()


static func Belt_feeds(n: Part, target: Vector3i) -> bool:
	if n == null:
		return false
	var k := n.kind()
	if k in ["splitter", "teleporter", "source", "crusher", "furnace", "packer"]:
		return true
	if Defs.is_directional(n.type_id) and n.cell + Defs.DIRS[n.rot] == target:
		return true
	if k == "ramp" and n.cell + Defs.DIRS[n.rot] + Vector3i(0, 1, 0) == target:
		return true
	return false


func _update_rail_visuals() -> void:
	for side in 2:
		var sx := -0.465 if side == 0 else 0.465
		if ghost:
			if side == 0:
				_box(Vector3(0.06, 0.12, 1.0), Vector3(sx, 0.26, 0), Meshes.mat(Color("c9a13a")))
				_box(Vector3(0.06, 0.12, 1.0), Vector3(-sx, 0.26, 0), Meshes.mat(Color("c9a13a")))
			continue
		var want: bool = _rails[side]
		var have: bool = not (_rail_handles[side] as Array).is_empty()
		if want and not have:
			var m := Meshes.mat(Color("c9a13a"), 0.0, 0.6)
			var mesh := Meshes.box_mesh(Vector3(0.06, 0.12, 1.0))
			var local := Transform3D(Basis.IDENTITY, Vector3(sx, 0.26, 0))
			var h: Dictionary = world.batcher.add(mesh, m, _xf() * local, local)
			_rail_handles[side] = [h]
			_handles.append(h)
		elif not want and have:
			for h in _rail_handles[side]:
				world.batcher.remove(h)
				_handles.erase(h)
			_rail_handles[side] = []
