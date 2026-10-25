class_name ForestTree
extends StaticBody3D
## A tree whose trunk is made of real layers: a grid of outer-bark panels over a grid of inner-bark panels
## over the pale wood core. Chopping removes the outermost remaining layer exactly at the spot you hit,
## and that piece is spawned as a physical chip you can pick up.

const SECTORS := 16          # panels around the trunk
const BAND_H := 0.18         # height of one panel
const OUTER_T := 0.045       # outer bark thickness
const INNER_T := 0.035       # inner bark thickness

const OUTER := 0
const INNER := 1

var radius := 0.4
var trunk_h := 6.0
var bands := 24
var r_core := 0.32
var r_mid := 0.355
var layers := [PackedByteArray(), PackedByteArray()]   # 1 = panel present
var kind := "oak"
var bark_color := Color("5b4030")
var inner_color := Color("b5653a")
var wood_color := Color("e2c08d")

var _layer_mi: Array[MeshInstance3D] = [null, null]
var _seed := 0
var _crown: Node3D
var _shake_tw: Tween
var _core_mi: MeshInstance3D
var _col: CollisionShape3D
var is_section := false     # a piece of trunk inside a Log: closed at both ends, no crown, no collision of its own
var felled := false         # sawn down: just a stump now


func setup(rng: RandomNumberGenerator, p_kind: String) -> void:
	kind = p_kind
	_seed = rng.randi()
	radius = rng.randf_range(0.3, 0.46)
	bands = rng.randi_range(26, 40)
	trunk_h = bands * BAND_H
	r_mid = radius - OUTER_T
	r_core = r_mid - INNER_T
	match kind:
		"pine":
			bark_color = Color("4d3a2e")
			inner_color = Color("b7703f")
			wood_color = Color("ead1a0")
		"birch":
			bark_color = Color("e8e4da")
			inner_color = Color("c9875a")
			wood_color = Color("f0dcb4")
		_:
			bark_color = Color("5b4030")
			inner_color = Color("b5653a")
			wood_color = Color("e2c08d")
	for l in 2:
		var a := PackedByteArray()
		a.resize(SECTORS * bands)
		a.fill(1)
		layers[l] = a
	collision_layer = 1
	collision_mask = 0
	add_to_group("trees")
	_build_static()
	for l in 2:
		var mi := MeshInstance3D.new()
		mi.material_override = LowPoly.vcol_mat(0.95)
		add_child(mi)
		_layer_mi[l] = mi
		_rebuild(l)


## Makes this node a piece of `src`'s trunk covering bands j0..j1-1 (used inside a Log).
func setup_section(src: ForestTree, j0: int, j1: int) -> void:
	is_section = true
	kind = src.kind
	_seed = src._seed
	radius = src.radius
	r_mid = src.r_mid
	r_core = src.r_core
	bark_color = src.bark_color
	inner_color = src.inner_color
	wood_color = src.wood_color
	bands = j1 - j0
	trunk_h = bands * BAND_H
	for l in 2:
		var a := PackedByteArray()
		a.resize(SECTORS * bands)
		for j in bands:
			for i in SECTORS:
				a[j * SECTORS + i] = src.layers[l][(j + j0) * SECTORS + i]
		layers[l] = a
	collision_layer = 0
	collision_mask = 0
	_build_static()
	for l in 2:
		var mi := MeshInstance3D.new()
		mi.material_override = LowPoly.vcol_mat(0.95)
		add_child(mi)
		_layer_mi[l] = mi
		_rebuild(l)


## Saws through the trunk at band `cut_j`: everything above becomes a falling Log (crown and all) and this
## tree is left as a stump.
func fell(cut_j: int, push_dir: Vector3) -> Log:
	cut_j = clampi(cut_j, 1, bands - 2)
	var lg := Log.new()
	get_parent().add_child(lg)
	lg.setup_from(self, cut_j, bands, global_transform * Transform3D(Basis(), Vector3(0, cut_j * BAND_H + 0.03, 0)))
	if _crown != null:
		lg.attach_crown(_crown)
		_crown = null
	# what's left is a stump
	bands = cut_j
	trunk_h = bands * BAND_H
	felled = true
	remove_from_group("trees")
	_core_mi.mesh = LowPoly.cyl(r_core * 0.985, r_core * 0.985, trunk_h, SECTORS)
	_core_mi.position.y = trunk_h * 0.5
	var sh := CylinderShape3D.new()
	sh.radius = radius
	sh.height = trunk_h
	_col.shape = sh
	_col.position.y = trunk_h * 0.5
	for l in 2:
		_rebuild(l)
	lg.topple(push_dir)
	return lg


## Each chop makes the crown shudder away from the hit and spring back.
func shake_crown(dir: Vector3, amount: float) -> void:
	dir.y = 0.0
	if dir.length() < 0.01 or _crown == null:
		return
	var axis := Vector3.UP.cross(dir.normalized())
	var a := deg_to_rad(2.5) * amount
	if _shake_tw != null:
		_shake_tw.kill()
	_crown.basis = Basis()
	_shake_tw = create_tween()
	for k in 4:
		var amp := a * pow(0.45, k) * (1.0 if k % 2 == 0 else -1.0)
		_shake_tw.tween_property(_crown, "basis", Basis(axis, amp), 0.07 + k * 0.03).set_trans(Tween.TRANS_SINE)
	_shake_tw.tween_property(_crown, "basis", Basis(), 0.15).set_trans(Tween.TRANS_SINE)
	# a few leaves drift down
	if kind != "pine":
		var top := global_position + Vector3(0, trunk_h + 0.5, 0)
		Nature.burst(get_parent(), top, Vector3.DOWN, Color("6aa846"), int(3 + amount * 4), 0.6, 0.06, 1.2, 2.2, 120.0)


func _build_static() -> void:
	# wood core (only visible where bark has been stripped)
	_core_mi = LowPoly.mesh_instance(self, LowPoly.cyl(r_core * 0.985, r_core * 0.985, trunk_h, SECTORS), LowPoly.mat(wood_color, 0.8), Vector3(0, trunk_h * 0.5, 0))
	if is_section:
		return
	# root flare
	LowPoly.mesh_instance(self, LowPoly.cyl(radius * 1.02, radius * 1.45, 0.35, SECTORS), LowPoly.mat(bark_color.darkened(0.15)), Vector3(0, 0.1, 0))
	# canopy: hangs off a pivot at the base of the trunk so the whole crown can sway / shake
	_crown = Node3D.new()
	_crown.name = "Crown"
	add_child(_crown)
	var rng := RandomNumberGenerator.new()
	rng.seed = _seed
	match kind:
		"pine":
			var base_y := trunk_h - 1.2
			for k in 4:
				var r := 2.0 - k * 0.42
				LowPoly.mesh_instance(_crown, LowPoly.cyl(0.0, r, 1.9, 7), Nature.wind_mat(Color("2f6b3a").lightened(k * 0.04), 0.03 + k * 0.025, 1.9, -0.95), Vector3(0, base_y + k * 1.05 + 0.9, 0), Vector3(0, rng.randf() * 60.0, 0))
		"birch":
			for k in 4:
				var off := Vector3(rng.randf_range(-0.8, 0.8), trunk_h + rng.randf_range(-0.6, 1.2), rng.randf_range(-0.8, 0.8))
				LowPoly.mesh_instance(_crown, LowPoly.blob(1.0, 0.25, rng.randi() % 50), Nature.wind_mat(Color("7fb34a").lightened(snappedf(rng.randf() * 0.1, 0.02)), 0.07), off, Vector3.ZERO, Vector3.ONE * rng.randf_range(0.9, 1.4))
		_:
			LowPoly.mesh_instance(_crown, LowPoly.blob(1.9, 0.22, rng.randi() % 50), Nature.wind_mat(Color("4f9a3c"), 0.08, 3.8, -1.9), Vector3(0, trunk_h + 0.9, 0))
			for k in 3:
				var off2 := Vector3(rng.randf_range(-1.3, 1.3), trunk_h + rng.randf_range(0.2, 1.6), rng.randf_range(-1.3, 1.3))
				LowPoly.mesh_instance(_crown, LowPoly.blob(1.2, 0.25, rng.randi() % 50), Nature.wind_mat(Color("5aab44").lightened(snappedf(rng.randf() * 0.08, 0.02)), 0.09, 2.4, -1.2), off2)
	var fol := Foliage.new()
	_crown.add_child(fol)
	fol.setup(_crown)
	# collision: the trunk
	_col = CollisionShape3D.new()
	var sh := CylinderShape3D.new()
	sh.radius = radius
	sh.height = trunk_h
	_col.shape = sh
	_col.position.y = trunk_h * 0.5
	add_child(_col)


# ------------------------------------------------------------------ layer geometry

func _idx(i: int, j: int) -> int:
	return j * SECTORS + posmod(i, SECTORS)


func has_panel(l: int, i: int, j: int) -> bool:
	if j < 0 or j >= bands:
		return false
	return layers[l][_idx(i, j)] == 1


func layer_radii(l: int) -> Vector2:
	return Vector2(r_mid, radius) if l == OUTER else Vector2(r_core, r_mid)


func _panel_color(l: int, i: int, j: int) -> Color:
	var h := hash(Vector3i(i, j, _seed + l * 7)) % 1000 / 1000.0
	if l == OUTER:
		if kind == "birch":
			return bark_color.darkened(0.35) if h < 0.12 else bark_color.darkened(h * 0.08)
		return bark_color.lightened((h - 0.5) * 0.18)
	return inner_color.lightened((h - 0.5) * 0.12)


func _corner(r: float, i: int, y: float) -> Vector3:
	var a := TAU * float(i) / SECTORS
	return Vector3(cos(a) * r, y, sin(a) * r)


func _rebuild(l: int) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rr := layer_radii(l)
	var ri := rr.x
	var ro := rr.y
	var any := false
	for j in bands:
		var y0 := j * BAND_H
		var y1 := y0 + BAND_H
		for i in SECTORS:
			if not has_panel(l, i, j):
				continue
			any = true
			var col := _panel_color(l, i, j)
			var mid_a := TAU * (i + 0.5) / SECTORS
			var radial := Vector3(cos(mid_a), 0, sin(mid_a))
			# outer face: always for bark, for inner bark only where the bark above it is gone
			if l == OUTER or not has_panel(OUTER, i, j):
				LowPoly.quad(st, _corner(ro, i, y0), _corner(ro, i + 1, y0), _corner(ro, i + 1, y1), _corner(ro, i, y1), radial, col)
			var edge := col.darkened(0.25)
			# side faces where the neighbour in this layer is missing
			if not has_panel(l, i - 1, j):
				var n0 := Vector3(sin(TAU * i / SECTORS), 0, -cos(TAU * i / SECTORS))
				LowPoly.quad(st, _corner(ri, i, y0), _corner(ro, i, y0), _corner(ro, i, y1), _corner(ri, i, y1), n0, edge)
			if not has_panel(l, i + 1, j):
				var n1 := Vector3(-sin(TAU * (i + 1) / SECTORS), 0, cos(TAU * (i + 1) / SECTORS))
				LowPoly.quad(st, _corner(ri, i + 1, y0), _corner(ro, i + 1, y0), _corner(ro, i + 1, y1), _corner(ri, i + 1, y1), n1, edge)
			if not has_panel(l, i, j + 1):
				LowPoly.quad(st, _corner(ri, i, y1), _corner(ro, i, y1), _corner(ro, i + 1, y1), _corner(ri, i + 1, y1), Vector3.UP, edge)
			if (j > 0 or is_section) and not has_panel(l, i, j - 1):
				LowPoly.quad(st, _corner(ri, i, y0), _corner(ro, i, y0), _corner(ro, i + 1, y0), _corner(ri, i + 1, y0), Vector3.DOWN, edge)
	_layer_mi[l].mesh = st.commit() if any else null


# ------------------------------------------------------------------ chopping

## Which panel a world-space point on the trunk belongs to: Vector2i(sector, band), or (-1,-1).
func panel_at(world_point: Vector3) -> Vector2i:
	var p := to_local(world_point)
	var j := int(floor(p.y / BAND_H))
	if j < 0 or j >= bands:
		return Vector2i(-1, -1)
	var a := fposmod(atan2(p.z, p.x), TAU)
	var i := int(floor(a / TAU * SECTORS)) % SECTORS
	return Vector2i(i, j)


## Strips every panel inside a circle (radius in metres) around the hit point - but only from the layer that
## is outermost at the hit point, never digging through to the layer below in the same hit.
## Returns {layer, panels: Array[Vector2i]} or {} if the spot is bare wood.
## `only` (OUTER / INNER) restricts a specialist tool to one layer: it takes only that layer's exposed panels in
## the circle, wherever the hit lands.
func strip_circle(world_point: Vector3, circle_r: float, only := -1) -> Dictionary:
	var c := panel_at(world_point)
	if c.x < 0:
		return {}
	var l := -1
	if only >= 0:
		l = only
	elif has_panel(OUTER, c.x, c.y):
		l = OUTER
	elif has_panel(INNER, c.x, c.y):
		l = INNER
	if l < 0:
		return {}
	var hit_local := to_local(world_point)
	var ro := layer_radii(l).y
	var panels: Array[Vector2i] = []
	if _strippable(l, c.x, c.y):
		panels.append(c)
	var reach_j := int(ceil(circle_r / BAND_H)) + 1
	var reach_i := int(ceil(circle_r / (TAU * ro / SECTORS))) + 1
	for dj in range(-reach_j, reach_j + 1):
		for di in range(-reach_i, reach_i + 1):
			if di == 0 and dj == 0:
				continue
			var i := posmod(c.x + di, SECTORS)
			var j := c.y + dj
			if j < 0 or j >= bands:
				continue
			if not _strippable(l, i, j):
				continue
			if _panel_center(l, i, j).distance_to(hit_local) <= circle_r:
				panels.append(Vector2i(i, j))
	if panels.is_empty():
		return {}
	for p in panels:
		layers[l][_idx(p.x, p.y)] = 0
	_rebuild(l)
	if l == OUTER:
		_rebuild(INNER)
	return {"layer": l, "panels": panels}


## Goes through both layers: every panel in the area loses its outer bark AND the inner bark under it in one go.
## The area is a circle of `circle_r` metres, or (grid > 0) a square of grid x grid panels centred on the hit.
## Returns [{layer, panels}] for each layer that lost something.
func strip_through(world_point: Vector3, circle_r: float, grid := 0) -> Array:
	var c := panel_at(world_point)
	if c.x < 0:
		return []
	var hit_local := to_local(world_point)
	var area: Array[Vector2i] = []
	if grid > 0:
		var h := grid / 2
		for dj in range(-h, grid - h):
			for di in range(-h, grid - h):
				var j := c.y + dj
				if j >= 0 and j < bands:
					area.append(Vector2i(posmod(c.x + di, SECTORS), j))
	else:
		var ro := layer_radii(OUTER).y
		var reach_j := int(ceil(circle_r / BAND_H)) + 1
		var reach_i := int(ceil(circle_r / (TAU * ro / SECTORS))) + 1
		for dj in range(-reach_j, reach_j + 1):
			for di in range(-reach_i, reach_i + 1):
				var i := posmod(c.x + di, SECTORS)
				var j := c.y + dj
				if j < 0 or j >= bands:
					continue
				if (di == 0 and dj == 0) or _panel_center(OUTER, i, j).distance_to(hit_local) <= circle_r:
					area.append(Vector2i(i, j))
	var out: Array = []
	for l in [OUTER, INNER]:
		var got: Array[Vector2i] = []
		for p in area:
			if has_panel(l, p.x, p.y):
				got.append(p)
		if got.is_empty():
			continue
		for p in got:
			layers[l][_idx(p.x, p.y)] = 0
		out.append({"layer": l, "panels": got})
	if not out.is_empty():
		_rebuild(OUTER)
		_rebuild(INNER)
	return out


## Ringing axe: the whole band at the hit height comes off all the way round (the outermost layer at the hit).
func strip_ring(world_point: Vector3) -> Dictionary:
	var c := panel_at(world_point)
	if c.x < 0:
		return {}
	var l := OUTER if has_panel(OUTER, c.x, c.y) else (INNER if has_panel(INNER, c.x, c.y) else -1)
	if l < 0:
		return {}
	var panels: Array[Vector2i] = []
	for k in SECTORS:
		var i := posmod(c.x + k, SECTORS)
		if _strippable(l, i, c.y):
			panels.append(Vector2i(i, c.y))
	for p in panels:
		layers[l][_idx(p.x, p.y)] = 0
	_rebuild(l)
	if l == OUTER:
		_rebuild(INNER)
	return {"layer": l, "panels": panels}


func _strippable(l: int, i: int, j: int) -> bool:
	if l == OUTER:
		return has_panel(OUTER, i, j)
	return has_panel(INNER, i, j) and not has_panel(OUTER, i, j)


func _panel_center(l: int, i: int, j: int) -> Vector3:
	var ro := layer_radii(l).y
	var a := TAU * (i + 0.5) / SECTORS
	return Vector3(cos(a) * ro, (j + 0.5) * BAND_H, sin(a) * ro)


## Old single-panel API (kept for tests): strips one panel at the hit point.
func strip_at(world_point: Vector3) -> Dictionary:
	var r := strip_circle(world_point, 0.0)
	if r.is_empty():
		return {}
	var p: Vector2i = r.panels[0]
	return {"layer": r.layer, "i": p.x, "j": p.y}


func bare_fraction() -> float:
	var total := SECTORS * bands
	var bare := 0
	for k in total:
		if layers[OUTER][k] == 0 and layers[INNER][k] == 0:
			bare += 1
	return float(bare) / float(total)


func chip_data(l: int, i: int, j: int) -> Dictionary:
	return piece_data(l, [Vector2i(i, j)])


## Mesh + transform for a bark piece made of several panels of one layer (one curved sheet).
## The piece frame is centred on the first panel: +Z = outward, +Y = up.
func piece_data(l: int, panels: Array) -> Dictionary:
	var rr := layer_radii(l)
	var ri := rr.x
	var ro := rr.y
	var c0: Vector2i = panels[0]
	var mid_a := TAU * (c0.x + 0.5) / SECTORS
	var center := Vector3(cos(mid_a) * (ri + ro) * 0.5, (c0.y + 0.5) * BAND_H, sin(mid_a) * (ri + ro) * 0.5)
	var basis := Basis(Vector3.UP, PI * 0.5 - mid_a)
	var inv := basis.inverse()
	var set := {}
	for p in panels:
		set[p] = true
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var lo := Vector3(1e9, 1e9, 1e9)
	var hi := -lo
	for p in panels:
		var i: int = p.x
		var j: int = p.y
		var y0 := j * BAND_H
		var y1 := y0 + BAND_H
		var pts := [
			_corner(ri, i, y0), _corner(ri, i + 1, y0), _corner(ro, i + 1, y0), _corner(ro, i, y0),
			_corner(ri, i, y1), _corner(ri, i + 1, y1), _corner(ro, i + 1, y1), _corner(ro, i, y1),
		]
		var lp: Array[Vector3] = []
		for q in pts:
			var v := inv * ((q as Vector3) - center)
			lp.append(v)
			lo = lo.min(v)
			hi = hi.max(v)
		var col := _panel_color(l, i, j)
		var under := inner_color if l == OUTER else wood_color.darkened(0.05)
		var pa := TAU * (i + 0.5) / SECTORS
		var out := inv * Vector3(cos(pa), 0, sin(pa))
		LowPoly.quad(st, lp[3], lp[2], lp[6], lp[7], out, col)
		LowPoly.quad(st, lp[0], lp[1], lp[5], lp[4], -out, under)
		var edge := col.darkened(0.2)
		if not set.has(Vector2i(i, j + 1)):
			LowPoly.quad(st, lp[4], lp[5], lp[6], lp[7], Vector3.UP, edge)
		if not set.has(Vector2i(i, j - 1)):
			LowPoly.quad(st, lp[0], lp[1], lp[2], lp[3], Vector3.DOWN, edge)
		var nl := (lp[0] + lp[3] + lp[4] + lp[7]) * 0.25
		var nr := (lp[1] + lp[2] + lp[5] + lp[6]) * 0.25
		if not set.has(Vector2i(posmod(i - 1, SECTORS), j)):
			LowPoly.quad(st, lp[0], lp[3], lp[7], lp[4], nl - nr, edge)
		if not set.has(Vector2i(posmod(i + 1, SECTORS), j)):
			LowPoly.quad(st, lp[1], lp[2], lp[6], lp[5], nr - nl, edge)
	var size := (hi - lo).max(Vector3(0.03, 0.03, 0.03))
	return {
		"mesh": st.commit(),
		"xform": global_transform * Transform3D(basis, center),
		"size": size,
		"box_center": (hi + lo) * 0.5,
		"layer": l,
		"panels": panels.size(),
		"color": bark_color if l == OUTER else inner_color,
		"outward": (global_transform.basis * Vector3(cos(mid_a), 0, sin(mid_a))).normalized(),
	}
