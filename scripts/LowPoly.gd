class_name LowPoly
extends RefCounted
## Procedural low-poly mesh helpers and cached materials.

static var _mats := {}
static var _meshes := {}


static func mat(color: Color, rough: float = 0.9, emit: float = 0.0) -> StandardMaterial3D:
	var key := "%s_%.2f_%.2f" % [color.to_html(true), rough, emit]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	if emit > 0.0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = emit
	_mats[key] = m
	return m


## Material that takes its colour from vertex colours (used for bark, terrain, ...).
static func vcol_mat(rough: float = 0.95) -> StandardMaterial3D:
	var key := "vcol_%.2f" % rough
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = rough
	_mats[key] = m
	return m


static func box(size: Vector3) -> BoxMesh:
	var key := "box_%s" % str(size)
	if not _meshes.has(key):
		var m := BoxMesh.new()
		m.size = size
		_meshes[key] = m
	return _meshes[key]


static func cyl(top: float, bottom: float, h: float, segs: int = 8) -> CylinderMesh:
	var key := "cyl_%.3f_%.3f_%.3f_%d" % [top, bottom, h, segs]
	if not _meshes.has(key):
		var m := CylinderMesh.new()
		m.top_radius = top
		m.bottom_radius = bottom
		m.height = h
		m.radial_segments = segs
		m.rings = 1
		_meshes[key] = m
	return _meshes[key]


## Adds a flat-shaded quad (a,b,c,d in order around the face) facing `outward`.
static func quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, outward: Vector3, col: Color) -> void:
	tri(st, a, b, c, outward, col)
	tri(st, a, c, d, outward, col)


static func tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, outward: Vector3, col: Color) -> void:
	var n := (b - a).cross(c - a)
	if n.dot(outward) > 0.0:
		var t := b
		b = c
		c = t
		n = -n
	# Godot front faces are clockwise -> the cross product above points inward; normal = outward
	var nn := outward.normalized()
	st.set_color(col)
	st.set_normal(nn)
	st.add_vertex(a)
	st.set_color(col)
	st.set_normal(nn)
	st.add_vertex(b)
	st.set_color(col)
	st.set_normal(nn)
	st.add_vertex(c)


## Jittered icosahedron (rocks, bushes, round canopies).
static func blob(r: float, jitter: float, seed_value: int) -> ArrayMesh:
	var key := "blob_%.3f_%.3f_%d" % [r, jitter, seed_value]
	if _meshes.has(key):
		return _meshes[key]
	var t := (1.0 + sqrt(5.0)) / 2.0
	var raw := [
		Vector3(-1, t, 0), Vector3(1, t, 0), Vector3(-1, -t, 0), Vector3(1, -t, 0),
		Vector3(0, -1, t), Vector3(0, 1, t), Vector3(0, -1, -t), Vector3(0, 1, -t),
		Vector3(t, 0, -1), Vector3(t, 0, 1), Vector3(-t, 0, -1), Vector3(-t, 0, 1),
	]
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var v: Array[Vector3] = []
	for p in raw:
		v.append((p as Vector3).normalized() * r * (1.0 + rng.randf_range(-jitter, jitter)))
	var faces := [
		[0, 11, 5], [0, 5, 1], [0, 1, 7], [0, 7, 10], [0, 10, 11], [1, 5, 9], [5, 11, 4], [11, 10, 2], [10, 7, 6], [7, 1, 8],
		[3, 9, 4], [3, 4, 2], [3, 2, 6], [3, 6, 8], [3, 8, 9], [4, 9, 5], [2, 4, 11], [6, 2, 10], [8, 6, 7], [9, 8, 1],
	]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for f in faces:
		var a: Vector3 = v[f[0]]
		var b: Vector3 = v[f[1]]
		var c: Vector3 = v[f[2]]
		tri(st, a, b, c, (a + b + c) / 3.0, Color.WHITE)
	var m := st.commit()
	_meshes[key] = m
	return m


static func mesh_instance(parent: Node3D, mesh: Mesh, m: Material, pos: Vector3, rot_deg: Vector3 = Vector3.ZERO, scl: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	mi.position = pos
	mi.rotation_degrees = rot_deg
	mi.scale = scl
	parent.add_child(mi)
	return mi


static func static_box(parent: Node3D, size: Vector3, pos: Vector3, rot_deg: Vector3 = Vector3.ZERO) -> StaticBody3D:
	var sb := StaticBody3D.new()
	sb.position = pos
	sb.rotation_degrees = rot_deg
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	sb.add_child(cs)
	parent.add_child(sb)
	return sb
