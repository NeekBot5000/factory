class_name Wires
extends MeshInstance3D
## Draws every wire link as a sagging cable (crossed ribbons) that glows when its source is powered.

const SEGMENTS := 10
const WIDTH := 0.035

var world: Node
var _im := ImmediateMesh.new()
var _mat := StandardMaterial3D.new()
var _sig := PackedByteArray()
var _preview_on := false
var _preview_a := Vector3.ZERO
var _preview_b := Vector3.ZERO
var _preview_dirty := false
var visible_wires := true


func setup(p_world: Node) -> void:
	world = p_world
	mesh = _im
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.vertex_color_use_as_albedo = true
	_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func set_preview(on: bool, a: Vector3 = Vector3.ZERO, b: Vector3 = Vector3.ZERO) -> void:
	if on != _preview_on or (on and (a.distance_to(_preview_a) > 0.01 or b.distance_to(_preview_b) > 0.01)):
		_preview_on = on
		_preview_a = a
		_preview_b = b
		_preview_dirty = true


func update_states(force: bool) -> void:
	var links: Array = world.links
	var sig := PackedByteArray()
	sig.resize(links.size())
	for i in links.size():
		var p: Part = world.cells.get(links[i].a)
		sig[i] = 1 if (p != null and p.sig_out) else 0
	if force or sig != _sig or _preview_dirty:
		_sig = sig
		_preview_dirty = false
		_redraw()


func _process(_delta: float) -> void:
	if _preview_dirty:
		_preview_dirty = false
		_redraw()


func _redraw() -> void:
	_im.clear_surfaces()
	var links: Array = world.links
	if links.is_empty() and not _preview_on:
		return
	_im.surface_begin(Mesh.PRIMITIVE_TRIANGLES, _mat)
	for i in links.size():
		var a: Part = world.cells.get(links[i].a)
		var b: Part = world.cells.get(links[i].b)
		if a == null or b == null:
			continue
		var on := _sig.size() > i and _sig[i] == 1
		_cable(a.port_out_pos(), b.port_in_pos(), Color(1.0, 0.25, 0.15) if on else Color(0.35, 0.08, 0.08))
		_plug(a.port_out_pos(), Color(1.0, 0.8, 0.2))
		_plug(b.port_in_pos(), Color(0.3, 0.7, 1.0))
	if _preview_on:
		_cable(_preview_a, _preview_b, Color(1.0, 0.9, 0.3))
	_im.surface_end()


func _cable(a: Vector3, b: Vector3, c: Color) -> void:
	var dist := a.distance_to(b)
	var sag := minf(0.6, 0.12 + dist * 0.08)
	var prev := a
	for s in range(1, SEGMENTS + 1):
		var t := s / float(SEGMENTS)
		var p := a.lerp(b, t) + Vector3(0, -sag * 4.0 * t * (1.0 - t), 0)
		_ribbon(prev, p, c)
		prev = p


func _ribbon(p0: Vector3, p1: Vector3, c: Color) -> void:
	var d := (p1 - p0)
	if d.length_squared() < 0.000001:
		return
	d = d.normalized()
	var side := d.cross(Vector3.UP)
	if side.length_squared() < 0.001:
		side = Vector3.RIGHT
	side = side.normalized() * WIDTH * 0.5
	var up := side.cross(d).normalized() * WIDTH * 0.5
	for off in [side, up]:
		_im.surface_set_color(c)
		_im.surface_add_vertex(p0 - off)
		_im.surface_add_vertex(p0 + off)
		_im.surface_add_vertex(p1 + off)
		_im.surface_add_vertex(p0 - off)
		_im.surface_add_vertex(p1 + off)
		_im.surface_add_vertex(p1 - off)


func _plug(p: Vector3, c: Color) -> void:
	var s := 0.04
	_ribbon(p - Vector3(s, 0, 0), p + Vector3(s, 0, 0), c)
	_ribbon(p - Vector3(0, s, 0), p + Vector3(0, s, 0), c)
