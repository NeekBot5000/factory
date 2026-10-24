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


func _build_static() -> void:
	# wood core (only visible where bark has been stripped)
	LowPoly.mesh_instance(self, LowPoly.cyl(r_core * 0.985, r_core * 0.985, trunk_h, SECTORS), LowPoly.mat(wood_color, 0.8), Vector3(0, trunk_h * 0.5, 0))
	# root flare
	LowPoly.mesh_instance(self, LowPoly.cyl(radius * 1.02, radius * 1.45, 0.35, SECTORS), LowPoly.mat(bark_color.darkened(0.15)), Vector3(0, 0.1, 0))
	# canopy
	var rng := RandomNumberGenerator.new()
	rng.seed = _seed
	match kind:
		"pine":
			var base_y := trunk_h - 1.2
			for k in 4:
				var r := 2.0 - k * 0.42
				LowPoly.mesh_instance(self, LowPoly.cyl(0.0, r, 1.9, 7), LowPoly.mat(Color("2f6b3a").lightened(k * 0.04)), Vector3(0, base_y + k * 1.05 + 0.9, 0), Vector3(0, rng.randf() * 60.0, 0))
		"birch":
			for k in 4:
				var off := Vector3(rng.randf_range(-0.8, 0.8), trunk_h + rng.randf_range(-0.6, 1.2), rng.randf_range(-0.8, 0.8))
				LowPoly.mesh_instance(self, LowPoly.blob(1.0, 0.25, rng.randi() % 50), LowPoly.mat(Color("7fb34a").lightened(rng.randf() * 0.1)), off, Vector3.ZERO, Vector3.ONE * rng.randf_range(0.9, 1.4))
		_:
			LowPoly.mesh_instance(self, LowPoly.blob(1.9, 0.22, rng.randi() % 50), LowPoly.mat(Color("4f9a3c")), Vector3(0, trunk_h + 0.9, 0))
			for k in 3:
				var off2 := Vector3(rng.randf_range(-1.3, 1.3), trunk_h + rng.randf_range(0.2, 1.6), rng.randf_range(-1.3, 1.3))
				LowPoly.mesh_instance(self, LowPoly.blob(1.2, 0.25, rng.randi() % 50), LowPoly.mat(Color("5aab44").lightened(rng.randf() * 0.08)), off2)
	# collision: the trunk
	var cs := CollisionShape3D.new()
	var sh := CylinderShape3D.new()
	sh.radius = radius
	sh.height = trunk_h
	cs.shape = sh
	cs.position.y = trunk_h * 0.5
	add_child(cs)


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
			if j > 0 and not has_panel(l, i, j - 1):
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


## Removes the outermost remaining layer at the hit point.
## Returns {layer, i, j} for the piece that came off, or {} if the spot was already bare wood.
func strip_at(world_point: Vector3) -> Dictionary:
	var pj := panel_at(world_point)
	if pj.x < 0:
		return {}
	for l in [OUTER, INNER]:
		if has_panel(l, pj.x, pj.y):
			layers[l][_idx(pj.x, pj.y)] = 0
			_rebuild(l)
			if l == OUTER:
				_rebuild(INNER)   # the inner bark under it is now exposed
			return {"layer": l, "i": pj.x, "j": pj.y}
	return {}


func bare_fraction() -> float:
	var total := SECTORS * bands
	var bare := 0
	for k in total:
		if layers[OUTER][k] == 0 and layers[INNER][k] == 0:
			bare += 1
	return float(bare) / float(total)


## Mesh + local transform for the piece (layer l, panel i, j) as a free-standing chip.
## The chip's local frame: +Z = outward (radial), +Y = up, X = along the bark.
func chip_data(l: int, i: int, j: int) -> Dictionary:
	var rr := layer_radii(l)
	var ri := rr.x
	var ro := rr.y
	var y0 := j * BAND_H
	var y1 := y0 + BAND_H
	var mid_a := TAU * (i + 0.5) / SECTORS
	var center := Vector3(cos(mid_a) * (ri + ro) * 0.5, (y0 + y1) * 0.5, sin(mid_a) * (ri + ro) * 0.5)
	var basis := Basis(Vector3.UP, PI * 0.5 - mid_a)
	var inv := basis.inverse()
	var pts := [
		_corner(ri, i, y0), _corner(ri, i + 1, y0), _corner(ro, i + 1, y0), _corner(ro, i, y0),
		_corner(ri, i, y1), _corner(ri, i + 1, y1), _corner(ro, i + 1, y1), _corner(ro, i, y1),
	]
	var lp: Array[Vector3] = []
	for p in pts:
		lp.append(inv * ((p as Vector3) - center))
	var col := _panel_color(l, i, j)
	var under := inner_color if l == OUTER else wood_color.darkened(0.05)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	LowPoly.quad(st, lp[3], lp[2], lp[6], lp[7], Vector3(0, 0, 1), col)            # outer face
	LowPoly.quad(st, lp[0], lp[1], lp[5], lp[4], Vector3(0, 0, -1), under)          # inner face (fibres)
	LowPoly.quad(st, lp[4], lp[5], lp[6], lp[7], Vector3.UP, col.darkened(0.2))
	LowPoly.quad(st, lp[0], lp[1], lp[2], lp[3], Vector3.DOWN, col.darkened(0.2))
	var nl := (lp[0] + lp[3] + lp[4] + lp[7]) * 0.25
	var nr := (lp[1] + lp[2] + lp[5] + lp[6]) * 0.25
	LowPoly.quad(st, lp[0], lp[3], lp[7], lp[4], nl - nr, col.darkened(0.2))
	LowPoly.quad(st, lp[1], lp[2], lp[6], lp[5], nr - nl, col.darkened(0.2))
	var width := lp[2].distance_to(lp[3])
	return {
		"mesh": st.commit(),
		"xform": global_transform * Transform3D(basis, center),
		"size": Vector3(width, BAND_H, ro - ri),
		"layer": l,
		"outward": (global_transform.basis * Vector3(cos(mid_a), 0, sin(mid_a))).normalized(),
	}
