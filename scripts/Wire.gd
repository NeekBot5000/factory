class_name Wire
extends Node3D
## A sagging copper cable between two machines. It glows faintly while power runs through it.

const SEGMENTS := 10
const MAX_LEN := 14.0

var a: Machine
var b: Machine
var _cable: MeshInstance3D       # the whole sagging cable as one mesh (rebuilt only when an end moves)
var _mat: StandardMaterial3D
var _last := [Vector3.INF, Vector3.INF]
var _live := false
var _plugs: Array[Node3D] = []


func setup(p_a: Machine, p_b: Machine) -> void:
	a = p_a
	b = p_b
	top_level = true
	_mat = StandardMaterial3D.new()
	_mat.albedo_color = Color("b8622c")
	_mat.roughness = 0.4
	_mat.emission_enabled = true
	_mat.emission = Color("ffb347")
	_mat.emission_energy_multiplier = 0.0
	_cable = MeshInstance3D.new()
	_cable.material_override = _mat
	_cable.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_cable)
	for k in 2:
		_plugs.append(_make_plug())
	add_to_group("wires")
	_redraw()


## The plug on each end: a dark block that fits the machine's socket exactly, a copper band and a rubber boot.
func _make_plug() -> Node3D:
	var n := Node3D.new()
	add_child(n)
	var dark := LowPoly.mat(Color("2e3036"), 0.5)
	var w := Machine.SOCKET - 0.008
	LowPoly.mesh_instance(n, LowPoly.box(Vector3(w, 0.1, w)), dark, Vector3(0, -0.01, 0))
	LowPoly.mesh_instance(n, LowPoly.box(Vector3(w + 0.006, 0.018, w + 0.006)), LowPoly.mat(Color("d8893f"), 0.3), Vector3(0, 0.028, 0))
	LowPoly.mesh_instance(n, LowPoly.cyl(0.03, 0.05, 0.06, 8), LowPoly.mat(Color("1d1e22"), 0.8), Vector3(0, 0.07, 0))
	LowPoly.bake(n, false)
	return n


## Plugs sit in the socket (or on top of the cell in it), turned to match the machine.
func _place_plugs(pa: Vector3, pb: Vector3) -> void:
	var ends := [[a, pa], [b, pb]]
	for k in 2:
		var m: Machine = ends[k][0]
		var yaw := m.global_basis.get_euler().y
		_plugs[k].global_transform = Transform3D(Basis(Vector3.UP, yaw), ends[k][1])


func connects(m: Machine) -> bool:
	return m == a or m == b


func other(m: Machine) -> Machine:
	return b if m == a else a


func set_live(on: bool) -> void:
	if on == _live:
		return
	_live = on
	_mat.emission_energy_multiplier = 0.45 if on else 0.0


func _process(_delta: float) -> void:
	if not is_instance_valid(a) or not is_instance_valid(b):
		queue_free()
		return
	var pa := a.terminal_world()
	var pb := b.terminal_world()
	if pa.distance_squared_to(_last[0]) > 0.0001 or pb.distance_squared_to(_last[1]) > 0.0001:
		_redraw()


func _redraw() -> void:
	var pa := a.terminal_world()
	var pb := b.terminal_world()
	_last = [pa, pb]
	_place_plugs(pa, pb)
	# the cable comes out of the top of each plug
	pa += Vector3.UP * 0.09
	pb += Vector3.UP * 0.09
	var sag := clampf(pa.distance_to(pb) * 0.12, 0.05, 1.2)
	var pts: Array[Vector3] = []
	for i in SEGMENTS + 1:
		var t := float(i) / SEGMENTS
		pts.append(pa.lerp(pb, t) + Vector3.DOWN * sag * 4.0 * t * (1.0 - t))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var seg := LowPoly.box(Vector3(0.035, 0.035, 1.0))
	for i in SEGMENTS:
		var p0 := pts[i]
		var p1 := pts[i + 1]
		var d := p1 - p0
		if d.length() < 0.001:
			continue
		# stretch along the segment's own length (Basis.scaled would stretch along the world's axes instead)
		var b := Basis.looking_at(d.normalized(), Vector3.UP if absf(d.normalized().y) < 0.99 else Vector3.RIGHT)
		st.append_from(seg, 0, Transform3D(b * Basis.from_scale(Vector3(1, 1, d.length() + 0.02)), (p0 + p1) * 0.5))
	_cable.mesh = st.commit()
