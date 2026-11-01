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


static var _vc_mats := {}


static func _vcount(m: Mesh, s: int) -> int:
	var a = m.surface_get_arrays(s)
	return (a[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() if a.size() > 0 and a[Mesh.ARRAY_VERTEX] != null else 0


## A shared material that takes its colour from the vertices (for baked machines), one per roughness/metalness.
static func _vc_mat(rough: float, metal: float) -> StandardMaterial3D:
	var k := "%.2f_%.2f" % [rough, metal]
	if not _vc_mats.has(k):
		var m := StandardMaterial3D.new()
		m.vertex_color_use_as_albedo = true
		m.roughness = rough
		m.metallic = metal
		_vc_mats[k] = m
	return _vc_mats[k]


## Plain colour-only materials can be merged into vertex colours; glowing, see-through or textured ones can't.
static func _plain(m: Material) -> bool:
	var sm := m as StandardMaterial3D
	return sm != null and sm.albedo_texture == null and not sm.emission_enabled \
		and sm.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED and sm.shading_mode == BaseMaterial3D.SHADING_MODE_PER_PIXEL \
		and not sm.vertex_color_use_as_albedo and sm.cull_mode == BaseMaterial3D.CULL_BACK and sm.next_pass == null


## Merges the plain mesh children of `node` (not the named ones: code moves or recolours those) into as few meshes
## as possible: plain-coloured parts become one surface with the colours in the vertices, the rest one surface per
## material. A machine made of twenty boxes then costs the graphics card a draw call or two instead of twenty (times
## every shadow pass). Returns how many meshes it merged.
static func bake(node: Node3D, shadows := true) -> int:
	var plain := {}          # "rough_metal" -> {v, n, c, i, mat}
	var groups := {}         # other materials: key -> {mat, st}
	var merged: Array[MeshInstance3D] = []
	for c in node.get_children():
		var mi := c as MeshInstance3D
		if mi == null or not String(mi.name).begins_with("@") or mi.get_child_count() > 0 or not mi.visible or mi.mesh == null:
			continue
		var mat: Material = mi.material_override if mi.material_override != null else mi.mesh.surface_get_material(0)
		if _plain(mat):
			var sm := mat as StandardMaterial3D
			# two finishes are plenty on low-poly parts: matte (wood, stone, paint) and shiny (metal)
			var rough := 0.9 if sm.roughness >= 0.6 else 0.4
			var metal := 0.6 if sm.metallic >= 0.3 else 0.0
			var key := "%.2f_%.2f" % [rough, metal]
			if not plain.has(key):
				plain[key] = {"v": PackedVector3Array(), "n": PackedVector3Array(), "c": PackedColorArray(), "i": PackedInt32Array(), "mat": _vc_mat(rough, metal)}
			var g: Dictionary = plain[key]
			# (packed arrays are copied when read out of a dictionary: work on locals and put them back)
			var gv: PackedVector3Array = g.v
			var gn: PackedVector3Array = g.n
			var gc: PackedColorArray = g.c
			var gi: PackedInt32Array = g.i
			var nb := mi.transform.basis.inverse().transposed()
			for s in mi.mesh.get_surface_count():
				if _vcount(mi.mesh, s) == 0:
					continue
				var arrs := mi.mesh.surface_get_arrays(s)
				var verts: PackedVector3Array = arrs[Mesh.ARRAY_VERTEX]
				var norms: PackedVector3Array = arrs[Mesh.ARRAY_NORMAL] if arrs[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
				var base := gv.size()
				for k in verts.size():
					gv.append(mi.transform * verts[k])
					gn.append((nb * norms[k]).normalized() if k < norms.size() else Vector3.UP)
					gc.append(sm.albedo_color)
				if arrs[Mesh.ARRAY_INDEX] != null:
					for ix in (arrs[Mesh.ARRAY_INDEX] as PackedInt32Array):
						gi.append(base + ix)
				else:
					for k in verts.size():
						gi.append(base + k)
			g.v = gv
			g.n = gn
			g.c = gc
			g.i = gi
		else:
			var fmt := 0             # which vertex data it has (normals, colours, UVs...): only like merges with like
			var arrs0 := mi.mesh.surface_get_arrays(0)
			for a in 6:
				if arrs0[a] != null:
					fmt |= 1 << a
			var key := "%d_%d" % [mat.get_instance_id() if mat != null else 0, fmt]
			if not groups.has(key):
				var st := SurfaceTool.new()
				st.begin(Mesh.PRIMITIVE_TRIANGLES)
				groups[key] = {"mat": mat, "st": st, "n": 0}
			for s in mi.mesh.get_surface_count():
				if _vcount(mi.mesh, s) > 0:
					(groups[key].st as SurfaceTool).append_from(mi.mesh, s, mi.transform)
					groups[key].n += 1
		merged.append(mi)
	if merged.size() < 2:
		return 0
	var am := ArrayMesh.new()
	for key in plain:
		var g: Dictionary = plain[key]
		if (g.v as PackedVector3Array).is_empty():
			continue
		var arrs := []
		arrs.resize(Mesh.ARRAY_MAX)
		arrs[Mesh.ARRAY_VERTEX] = g.v
		arrs[Mesh.ARRAY_NORMAL] = g.n
		arrs[Mesh.ARRAY_COLOR] = g.c
		arrs[Mesh.ARRAY_INDEX] = g.i
		am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrs)
		am.surface_set_material(am.get_surface_count() - 1, g.mat)
	for key in groups:
		var g: Dictionary = groups[key]
		if int(g.n) == 0:
			continue
		(g.st as SurfaceTool).commit(am)
		am.surface_set_material(am.get_surface_count() - 1, g.mat)
	var out := MeshInstance3D.new()
	out.name = "Baked"
	out.mesh = am
	out.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_child(out)
	for mi in merged:
		node.remove_child(mi)
		mi.queue_free()
	return merged.size()
