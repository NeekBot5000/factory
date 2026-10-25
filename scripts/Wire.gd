class_name Wire
extends Node3D
## A sagging copper cable between two machines. It glows faintly while power runs through it.

const SEGMENTS := 10
const MAX_LEN := 14.0

var a: Machine
var b: Machine
var _segs: Array[MeshInstance3D] = []
var _mat: StandardMaterial3D
var _last := [Vector3.INF, Vector3.INF]
var _live := false


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
	for i in SEGMENTS:
		var mi := MeshInstance3D.new()
		mi.mesh = LowPoly.box(Vector3(0.035, 0.035, 1.0))
		mi.material_override = _mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
		_segs.append(mi)
	add_to_group("wires")
	_redraw()


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
	var sag := clampf(pa.distance_to(pb) * 0.12, 0.05, 1.2)
	var pts: Array[Vector3] = []
	for i in SEGMENTS + 1:
		var t := float(i) / SEGMENTS
		pts.append(pa.lerp(pb, t) + Vector3.DOWN * sag * 4.0 * t * (1.0 - t))
	for i in SEGMENTS:
		var p0 := pts[i]
		var p1 := pts[i + 1]
		var d := p1 - p0
		var mi := _segs[i]
		if d.length() < 0.001:
			mi.visible = false
			continue
		mi.visible = true
		# stretch along the segment's own length (Basis.scaled would stretch along the world's axes instead)
		var b := Basis.looking_at(d.normalized(), Vector3.UP if absf(d.normalized().y) < 0.99 else Vector3.RIGHT)
		mi.global_transform = Transform3D(b * Basis.from_scale(Vector3(1, 1, d.length() + 0.02)), (p0 + p1) * 0.5)
