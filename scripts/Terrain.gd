class_name Terrain
extends StaticBody3D
## Low-poly rolling forest floor with a flat clearing around the cabin and a dirt path.

const SIZE := 220.0
const GRID := 72
const CLEARING := 13.0

var noise := FastNoiseLite.new()
var detail := FastNoiseLite.new()


func build() -> void:
	noise.seed = 7
	noise.frequency = 0.018
	detail.seed = 11
	detail.frequency = 0.09
	collision_layer = 1
	collision_mask = 0
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var step := SIZE / GRID
	var h0 := -SIZE * 0.5
	for gz in GRID:
		for gx in GRID:
			var x0 := h0 + gx * step
			var z0 := h0 + gz * step
			var a := _v(x0, z0)
			var b := _v(x0 + step, z0)
			var c := _v(x0 + step, z0 + step)
			var d := _v(x0, z0 + step)
			if (gx + gz) % 2 == 0:
				_tri(st, a, b, c)
				_tri(st, a, c, d)
			else:
				_tri(st, a, b, d)
				_tri(st, b, c, d)
	var mesh := st.commit()
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = LowPoly.vcol_mat(1.0)
	add_child(mi)
	var cs := CollisionShape3D.new()
	cs.shape = mesh.create_trimesh_shape()
	add_child(cs)


func height_at(x: float, z: float) -> float:
	var d := Vector2(x, z).length()
	var fall := smoothstep(CLEARING, CLEARING + 14.0, d)
	var edge := smoothstep(70.0, 105.0, d) * 6.0
	return (noise.get_noise_2d(x, z) * 3.2 + detail.get_noise_2d(x, z) * 0.35) * fall + edge


func _v(x: float, z: float) -> Vector3:
	return Vector3(x, height_at(x, z), z)


func _color(p: Vector3, n: Vector3) -> Color:
	var g := Color("5c9c3e").lerp(Color("4a8a35"), clampf(detail.get_noise_2d(p.x * 2.0, p.z * 2.0) * 0.5 + 0.5, 0.0, 1.0))
	if n.y < 0.85:
		g = g.lerp(Color("7a6a4a"), 0.5)
	# dirt path from the cabin porch towards the forest
	if p.z > 3.0 and absf(p.x + sin(p.z * 0.15) * 1.5) < 1.3 and p.z < 40.0:
		g = Color("8a6a45")
	# worn ground around the cabin
	var d := Vector2(p.x, p.z).length()
	if d < 6.5:
		g = g.lerp(Color("7d7040"), 0.35)
	return g


func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	var n := (b - a).cross(c - a).normalized()
	if n.y < 0.0:
		n = -n
	var col := _color((a + b + c) / 3.0, n)
	LowPoly.tri(st, a, b, c, n, col)
