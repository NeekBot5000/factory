class_name Cabin
extends Node3D
## A low-poly log cabin built from stacked round logs, with a porch, door, windows, gable roof and chimney.

const W := 6.0          # along X
const D := 5.0          # along Z (door wall faces +Z)
const LOG_R := 0.16
const ROWS := 8
const FLOOR_Y := 0.35

var log_mat: Material
var log_end_mat: Material
var _body: StaticBody3D


func build() -> void:
	log_mat = LowPoly.mat(Color("8a5a36"), 0.95)
	log_end_mat = LowPoly.mat(Color("d8b07a"), 0.9)
	_body = StaticBody3D.new()
	_body.collision_layer = 1
	add_child(_body)
	_foundation()
	var top := FLOOR_Y + ROWS * LOG_R * 2.0
	var door := Rect2(-0.55, FLOOR_Y, 1.1, 2.05)        # x, y, w, h on the front wall
	var win_front := Rect2(1.2, FLOOR_Y + 0.9, 1.1, 0.85)
	var win_side := Rect2(-0.6, FLOOR_Y + 0.9, 1.2, 0.85)
	for r in ROWS:
		var y := FLOOR_Y + LOG_R + r * LOG_R * 2.0
		var off := LOG_R if r % 2 == 0 else 0.0
		# front (+Z) and back (-Z) walls run along X
		_wall_row(Vector3(0, y, D * 0.5), true, W + 0.5, [door, win_front], off)
		_wall_row(Vector3(0, y, -D * 0.5), true, W + 0.5, [Rect2(-1.6, FLOOR_Y + 0.9, 1.1, 0.85)], off)
		# side walls run along Z
		_wall_row(Vector3(W * 0.5, y, 0), false, D + 0.5, [win_side], LOG_R - off)
		_wall_row(Vector3(-W * 0.5, y, 0), false, D + 0.5, [], LOG_R - off)
	_gables(top)
	_roof(top)
	_chimney(top)
	_porch()
	_interior()


func _box_col(size: Vector3, pos: Vector3, rot_deg: Vector3 = Vector3.ZERO) -> void:
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	cs.position = pos
	cs.rotation_degrees = rot_deg
	_body.add_child(cs)


func _log(center: Vector3, along_x: bool, length: float, radius: float = LOG_R) -> void:
	var rot := Vector3(0, 0, 90) if along_x else Vector3(90, 0, 0)
	LowPoly.mesh_instance(self, LowPoly.cyl(radius, radius, length, 7), log_mat, center, rot)
	var axis := Vector3(1, 0, 0) if along_x else Vector3(0, 0, 1)
	for s in [-1, 1]:
		LowPoly.mesh_instance(self, LowPoly.cyl(radius * 0.92, radius * 0.92, 0.012, 7), log_end_mat, center + axis * (length * 0.5 + 0.002) * s, rot)
	var size := Vector3(length, radius * 2.0, radius * 2.0) if along_x else Vector3(radius * 2.0, radius * 2.0, length)
	# chinking: the mortar packed between logs, so no daylight leaks through the walls
	var chink := Vector3(length - 0.02, radius * 2.05, radius * 1.15) if along_x else Vector3(radius * 1.15, radius * 2.05, length - 0.02)
	LowPoly.mesh_instance(self, LowPoly.box(chink), LowPoly.mat(Color("c9b48a"), 1.0), center)
	_box_col(size, center)


func _wall_row(center: Vector3, along_x: bool, length: float, openings: Array, extra: float) -> void:
	var y := center.y
	var a := -length * 0.5 - extra
	var b := length * 0.5 + extra
	var cuts: Array = []
	for o in openings:
		var rr: Rect2 = o
		if y + LOG_R * 0.5 > rr.position.y and y - LOG_R * 0.5 < rr.position.y + rr.size.y:
			cuts.append(Vector2(rr.position.x, rr.position.x + rr.size.x))
	cuts.sort_custom(func(p, q): return p.x < q.x)
	var segs: Array = []
	var cur := a
	for c in cuts:
		if c.x > cur:
			segs.append(Vector2(cur, c.x))
		cur = maxf(cur, c.y)
	if cur < b:
		segs.append(Vector2(cur, b))
	for s in segs:
		var l: float = s.y - s.x
		if l < 0.05:
			continue
		var mid: float = (s.x + s.y) * 0.5
		var c3 := center + (Vector3(mid, 0, 0) if along_x else Vector3(0, 0, mid))
		_log(c3, along_x, l)


func _foundation() -> void:
	var stone := LowPoly.mat(Color("8d8a85"), 1.0)
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			LowPoly.mesh_instance(self, LowPoly.box(Vector3(0.6, 0.5, 0.6)), stone, Vector3(sx * W * 0.45, 0.05, sz * D * 0.45))
	var planks := LowPoly.mat(Color("a8784c"), 0.9)
	LowPoly.mesh_instance(self, LowPoly.box(Vector3(W, 0.12, D)), planks, Vector3(0, FLOOR_Y - 0.06, 0))
	for i in 10:
		LowPoly.mesh_instance(self, LowPoly.box(Vector3(W - 0.05, 0.005, 0.02)), LowPoly.mat(Color("7a5534")), Vector3(0, FLOOR_Y + 0.001, -D * 0.5 + 0.45 * (i + 1)))
	_box_col(Vector3(W, 0.12, D), Vector3(0, FLOOR_Y - 0.06, 0))
	_box_col(Vector3(W, FLOOR_Y, D), Vector3(0, FLOOR_Y * 0.5 - 0.1, 0))


func _gables(top: float) -> void:
	# stacked, shortening logs closing the triangles under the roof on both side walls
	var rows := 5
	for r in rows:
		var y := top + LOG_R + r * LOG_R * 2.0
		var length := (D + 0.4) * (1.0 - float(r + 0.5) / rows)
		for sx in [-1, 1]:
			_log(Vector3(sx * W * 0.5, y, 0), false, length)


func _gable_board(top: float, rise: float) -> void:
	# a solid triangular board behind the gable logs so no sky shows at the roof peak
	var half := D * 0.5 + 0.2
	for sx in [-1, 1]:
		var x: float = sx * (W * 0.5 - 0.12)
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var a := Vector3(x, top - 0.05, -half)
		var b := Vector3(x, top - 0.05, half)
		var c := Vector3(x, top + rise + 0.1, 0)
		for n in [Vector3(1, 0, 0), Vector3(-1, 0, 0)]:
			LowPoly.tri(st, a, b, c, n, Color("7a5234"))
		var mi := MeshInstance3D.new()
		mi.mesh = st.commit()
		mi.material_override = LowPoly.vcol_mat(0.95)
		add_child(mi)


func _roof(top: float) -> void:
	var rise := 1.7
	var half := D * 0.5 + 0.7
	var slope_len := sqrt(half * half + rise * rise)
	var ang := rad_to_deg(atan2(rise, half))
	_gable_board(top, rise)
	var shingle := LowPoly.mat(Color("6e3b2c"), 0.95)
	var shingle2 := LowPoly.mat(Color("5a2f24"), 0.95)
	for sz in [-1, 1]:
		var c := Vector3(0, top + rise * 0.5 + 0.1, sz * half * 0.5)
		var rot := Vector3(ang * sz, 0, 0)
		LowPoly.mesh_instance(self, LowPoly.box(Vector3(W + 1.2, 0.12, slope_len)), shingle, c, rot)
		for k in 6:
			var t := (k + 0.5) / 6.0 - 0.5
			var p := c + Basis.from_euler(Vector3(deg_to_rad(ang * sz), 0, 0)) * Vector3(0, 0.07, t * slope_len)
			LowPoly.mesh_instance(self, LowPoly.box(Vector3(W + 1.22, 0.03, 0.08)), shingle2, p, rot)
		_box_col(Vector3(W + 1.2, 0.12, slope_len), c, rot)
	_log(Vector3(0, top + rise + 0.12, 0), true, W + 1.3, 0.13)


func _chimney(top: float) -> void:
	var stone := LowPoly.mat(Color("7f7b76"), 1.0)
	var stone2 := LowPoly.mat(Color("6c6864"), 1.0)
	var x := -W * 0.5 - 0.45
	var h := top + 2.4
	for k in int(h / 0.4):
		LowPoly.mesh_instance(self, LowPoly.box(Vector3(0.8, 0.4, 1.0)), stone if k % 2 == 0 else stone2, Vector3(x, 0.2 + k * 0.4, -0.8), Vector3(0, (k % 3) * 2.0, 0))
	_box_col(Vector3(0.8, h, 1.0), Vector3(x, h * 0.5, -0.8))
	var smoke := Nature.Smoke.new()
	smoke.position = Vector3(x, h + 0.2, -0.8)
	add_child(smoke)


func _porch() -> void:
	var planks := LowPoly.mat(Color("9c6d43"), 0.9)
	var pz := D * 0.5 + 0.8
	LowPoly.mesh_instance(self, LowPoly.box(Vector3(W, 0.12, 1.5)), planks, Vector3(0, FLOOR_Y - 0.06, pz))
	_box_col(Vector3(W, FLOOR_Y + 0.05, 1.5), Vector3(0, FLOOR_Y * 0.5 - 0.06, pz))
	for k in 2:
		var sy := FLOOR_Y - 0.12 - k * 0.12
		var sz := pz + 0.95 + k * 0.32
		LowPoly.mesh_instance(self, LowPoly.box(Vector3(1.4, 0.12, 0.32)), planks, Vector3(0, sy, sz))
		_box_col(Vector3(1.4, 0.12, 0.32), Vector3(0, sy, sz))
	for sx in [-1, 1]:
		LowPoly.mesh_instance(self, LowPoly.cyl(0.09, 0.09, 2.3, 6), log_mat, Vector3(sx * (W * 0.5 - 0.2), FLOOR_Y + 1.15, pz + 0.6))
		_box_col(Vector3(0.18, 2.3, 0.18), Vector3(sx * (W * 0.5 - 0.2), FLOOR_Y + 1.15, pz + 0.6))
	# open door on its hinge
	var door := Node3D.new()
	door.position = Vector3(-0.55, FLOOR_Y, D * 0.5)
	door.rotation_degrees.y = -100.0
	add_child(door)
	LowPoly.mesh_instance(door, LowPoly.box(Vector3(1.08, 2.02, 0.07)), LowPoly.mat(Color("6b4428")), Vector3(0.54, 1.01, 0))
	LowPoly.mesh_instance(door, LowPoly.box(Vector3(0.06, 0.06, 0.1)), LowPoly.mat(Color("2a2a2a"), 0.4), Vector3(0.95, 1.0, 0.04))


func _interior() -> void:
	var wood := LowPoly.mat(Color("8f6440"), 0.9)
	# table + lantern
	LowPoly.mesh_instance(self, LowPoly.box(Vector3(1.2, 0.08, 0.8)), wood, Vector3(1.5, FLOOR_Y + 0.75, -1.2))
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			LowPoly.mesh_instance(self, LowPoly.box(Vector3(0.07, 0.75, 0.07)), wood, Vector3(1.5 + sx * 0.52, FLOOR_Y + 0.375, -1.2 + sz * 0.32))
	_box_col(Vector3(1.2, 0.8, 0.8), Vector3(1.5, FLOOR_Y + 0.4, -1.2))
	LowPoly.mesh_instance(self, LowPoly.cyl(0.07, 0.09, 0.22, 6), LowPoly.mat(Color("ffcf6a"), 0.5, 2.0), Vector3(1.6, FLOOR_Y + 0.9, -1.2))
	var light := OmniLight3D.new()
	light.light_color = Color("ffbf70")
	light.light_energy = 1.4
	light.omni_range = 6.0
	light.position = Vector3(1.6, FLOOR_Y + 1.2, -1.2)
	add_child(light)
	# bed with a red wool blanket
	LowPoly.mesh_instance(self, LowPoly.box(Vector3(1.0, 0.35, 2.0)), wood, Vector3(-2.2, FLOOR_Y + 0.17, -1.3))
	LowPoly.mesh_instance(self, LowPoly.box(Vector3(0.95, 0.12, 1.5)), LowPoly.mat(Color("a8322c")), Vector3(-2.2, FLOOR_Y + 0.4, -1.05))
	LowPoly.mesh_instance(self, LowPoly.box(Vector3(0.7, 0.12, 0.35)), LowPoly.mat(Color("eeeeee")), Vector3(-2.2, FLOOR_Y + 0.42, -2.05))
	_box_col(Vector3(1.0, 0.45, 2.0), Vector3(-2.2, FLOOR_Y + 0.22, -1.3))
	# stump stool
	LowPoly.mesh_instance(self, LowPoly.cyl(0.2, 0.22, 0.45, 7), log_mat, Vector3(1.4, FLOOR_Y + 0.22, -0.4))
	LowPoly.mesh_instance(self, LowPoly.cyl(0.19, 0.19, 0.01, 7), log_end_mat, Vector3(1.4, FLOOR_Y + 0.455, -0.4))
	_box_col(Vector3(0.4, 0.45, 0.4), Vector3(1.4, FLOOR_Y + 0.22, -0.4))
