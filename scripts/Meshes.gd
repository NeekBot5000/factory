class_name Meshes
extends RefCounted
## Procedural low-poly meshes and shared materials. Everything is generated in code.

static var _mat_cache := {}
static var _mesh_cache := {}
static var _belt_mats := {}

const BELT_SHADER := """
shader_type spatial;
uniform vec3 base_col : source_color = vec3(0.16, 0.17, 0.21);
uniform vec3 stripe_col : source_color = vec3(1.0, 0.8, 0.25);
uniform float speed = 4.0;
varying vec3 lp;
void vertex() { lp = VERTEX; }
void fragment() {
	float ph = lp.z * 2.0 - abs(lp.x) * 1.4 + TIME * speed;
	float f = fract(ph);
	float s = smoothstep(0.50, 0.58, f) * (1.0 - smoothstep(0.86, 0.94, f));
	ALBEDO = mix(base_col, stripe_col, s * 0.9);
	ROUGHNESS = 0.85;
}
"""

const GRID_SHADER := """
shader_type spatial;
render_mode unshaded, depth_draw_never, cull_disabled;
varying vec3 wp;
void vertex() { wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec2 f = fract(wp.xz);
	vec2 d = min(f, 1.0 - f);
	float line = 1.0 - smoothstep(0.0, 0.035, min(d.x, d.y));
	ALBEDO = vec3(1.0);
	ALPHA = line * 0.4;
}
"""


static func mat(color: Color, emit: float = 0.0, rough: float = 0.85, alpha: float = 1.0) -> StandardMaterial3D:
	var key := "%s_%.2f_%.2f_%.2f" % [color.to_html(true), emit, rough, alpha]
	if _mat_cache.has(key):
		return _mat_cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	if emit > 0.0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = emit
	if alpha < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mat_cache[key] = m
	return m


static func glass(color: Color, alpha: float) -> StandardMaterial3D:
	var key := "glass_%s_%.2f" % [color.to_html(true), alpha]
	if _mat_cache.has(key):
		return _mat_cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(color.r, color.g, color.b, alpha)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mat_cache[key] = m
	return m


static func box_mesh(size: Vector3) -> BoxMesh:
	var key := "box_%s" % str(size)
	if _mesh_cache.has(key):
		return _mesh_cache[key]
	var m := BoxMesh.new()
	m.size = size
	_mesh_cache[key] = m
	return m


static func cyl_mesh(top: float, bottom: float, h: float, segs: int = 8) -> CylinderMesh:
	var key := "cyl_%f_%f_%f_%d" % [top, bottom, h, segs]
	if _mesh_cache.has(key):
		return _mesh_cache[key]
	var m := CylinderMesh.new()
	m.top_radius = top
	m.bottom_radius = bottom
	m.height = h
	m.radial_segments = segs
	m.rings = 1
	_mesh_cache[key] = m
	return m


static func belt_mat(key: String, stripe: Color, base_speed: float) -> ShaderMaterial:
	if _belt_mats.has(key):
		return _belt_mats[key].mat
	var sh := Shader.new()
	sh.code = BELT_SHADER
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("stripe_col", stripe)
	m.set_shader_parameter("speed", 2.0 * base_speed)
	_belt_mats[key] = {"mat": m, "speed": base_speed}
	return m


static func refresh_belt_speeds(mult: float) -> void:
	for k in _belt_mats:
		var e: Dictionary = _belt_mats[k]
		(e.mat as ShaderMaterial).set_shader_parameter("speed", 2.0 * float(e.speed) * mult)


static func grid_mat() -> ShaderMaterial:
	if _mat_cache.has("grid"):
		return _mat_cache["grid"]
	var sh := Shader.new()
	sh.code = GRID_SHADER
	var m := ShaderMaterial.new()
	m.shader = sh
	_mat_cache["grid"] = m
	return m


# ---------------------------------------------------------------- polyhedra

## Builds a flat-shaded mesh from convex vertices (centred on the origin) and faces
## (index lists, any winding; fixed so normals point outward).
static func poly(verts: PackedVector3Array, faces: Array) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	var center := Vector3.ZERO
	for v in verts:
		center += v
	center /= float(verts.size())
	for f in faces:
		# fan-triangulate
		for i in range(1, f.size() - 1):
			var a: Vector3 = verts[f[0]]
			var b: Vector3 = verts[f[i]]
			var c: Vector3 = verts[f[i + 1]]
			var n := (b - a).cross(c - a)
			var cen := (a + b + c) / 3.0 - center
			if n.dot(cen) > 0.0:
				var t := b
				b = c
				c = t
			st.add_vertex(a)
			st.add_vertex(b)
			st.add_vertex(c)
	st.generate_normals()
	return st.commit()


static func icosa(r: float, jitter: float, seed_value: int) -> ArrayMesh:
	var t := (1.0 + sqrt(5.0)) / 2.0
	var raw := [
		Vector3(-1, t, 0), Vector3(1, t, 0), Vector3(-1, -t, 0), Vector3(1, -t, 0),
		Vector3(0, -1, t), Vector3(0, 1, t), Vector3(0, -1, -t), Vector3(0, 1, -t),
		Vector3(t, 0, -1), Vector3(t, 0, 1), Vector3(-t, 0, -1), Vector3(-t, 0, 1),
	]
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var verts := PackedVector3Array()
	for v in raw:
		verts.append((v as Vector3).normalized() * r * (1.0 + rng.randf_range(-jitter, jitter)))
	var faces := [
		[0, 11, 5], [0, 5, 1], [0, 1, 7], [0, 7, 10], [0, 10, 11],
		[1, 5, 9], [5, 11, 4], [11, 10, 2], [10, 7, 6], [7, 1, 8],
		[3, 9, 4], [3, 4, 2], [3, 2, 6], [3, 6, 8], [3, 8, 9],
		[4, 9, 5], [2, 4, 11], [6, 2, 10], [8, 6, 7], [9, 8, 1],
	]
	return poly(verts, faces)


static func octa(r: float, h: float) -> ArrayMesh:
	var verts := PackedVector3Array([
		Vector3(r, 0, 0), Vector3(-r, 0, 0), Vector3(0, h, 0),
		Vector3(0, -h, 0), Vector3(0, 0, r), Vector3(0, 0, -r),
	])
	var faces := [[2, 4, 0], [2, 0, 5], [2, 5, 1], [2, 1, 4], [3, 0, 4], [3, 5, 0], [3, 1, 5], [3, 4, 1]]
	return poly(verts, faces)


static func ingot() -> ArrayMesh:
	var bx := 0.17
	var bz := 0.09
	var tx := 0.12
	var tz := 0.05
	var h := 0.06
	var verts := PackedVector3Array([
		Vector3(-bx, -h, -bz), Vector3(bx, -h, -bz), Vector3(bx, -h, bz), Vector3(-bx, -h, bz),
		Vector3(-tx, h, -tz), Vector3(tx, h, -tz), Vector3(tx, h, tz), Vector3(-tx, h, tz),
	])
	var faces := [[0, 1, 2, 3], [4, 5, 6, 7], [0, 1, 5, 4], [1, 2, 6, 5], [2, 3, 7, 6], [3, 0, 4, 7]]
	return poly(verts, faces)


static func wedge(w: float, depth: float, height: float) -> ArrayMesh:
	# Triangular ramp body: back edge at z=+depth/2 (y=0), front edge at z=-depth/2 (y=height).
	var hw := w * 0.5
	var hd := depth * 0.5
	var verts := PackedVector3Array([
		Vector3(-hw, 0, hd), Vector3(hw, 0, hd),
		Vector3(-hw, 0, -hd), Vector3(hw, 0, -hd),
		Vector3(-hw, height, -hd), Vector3(hw, height, -hd),
	])
	var faces := [[0, 1, 3, 2], [2, 3, 5, 4], [0, 1, 5, 4], [0, 2, 4], [1, 3, 5]]
	# Centre differs from the true centroid but all faces are planar & convex enough for the winding fix.
	return poly(verts, faces)


static func coin_mesh() -> ArrayMesh:
	if _mesh_cache.has("coin"):
		return _mesh_cache["coin"]
	var verts := PackedVector3Array()
	var r := 0.2
	var t := 0.03
	for i in 8:
		var a := i / 8.0 * TAU + TAU / 16.0
		verts.append(Vector3(cos(a) * r, sin(a) * r, t))
	for i in 8:
		var a := i / 8.0 * TAU + TAU / 16.0
		verts.append(Vector3(cos(a) * r, sin(a) * r, -t))
	var faces := [[0, 1, 2, 3, 4, 5, 6, 7], [8, 9, 10, 11, 12, 13, 14, 15]]
	for i in 8:
		var j := (i + 1) % 8
		faces.append([i, j, j + 8, i + 8])
	var m := poly(verts, faces)
	_mesh_cache["coin"] = m
	return m


static func wedge_mesh() -> ArrayMesh:
	if _mesh_cache.has("wedge"):
		return _mesh_cache["wedge"]
	var m := wedge(0.96, 1.0, 0.917)
	_mesh_cache["wedge"] = m
	return m


const SPIN_SHADER := """
shader_type spatial;
uniform vec3 col : source_color = vec3(1.0, 0.8, 0.2);
varying float ang;
void vertex() {
	float a = TIME * 2.2;
	float c = cos(a);
	float s = sin(a);
	// spin around the world-up axis of the part (model Y), regardless of the mesh's own rotation
	vec3 v = VERTEX;
	VERTEX = vec3(c * v.x + s * v.z, v.y, -s * v.x + c * v.z);
	NORMAL = vec3(c * NORMAL.x + s * NORMAL.z, NORMAL.y, -s * NORMAL.x + c * NORMAL.z);
}
void fragment() {
	ALBEDO = col;
	EMISSION = col * 0.45;
	ROUGHNESS = 0.35;
}
"""


static func spin_mat(color: Color) -> ShaderMaterial:
	var key := "spin_" + color.to_html(false)
	if _mat_cache.has(key):
		return _mat_cache[key]
	var sh := Shader.new()
	sh.code = SPIN_SHADER
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("col", color)
	_mat_cache[key] = m
	return m


static func unit_box() -> BoxMesh:
	return box_mesh(Vector3.ONE)


static func _flat_tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, outward: Vector3) -> void:
	var n := (b - a).cross(c - a)
	if n.dot(outward) > 0.0:
		var t := b
		b = c
		c = t
	st.add_vertex(a)
	st.add_vertex(b)
	st.add_vertex(c)


## Unit log: diameter 1, length 1 along Z. Surface 0 = bark, surface 1 = end grain.
static func log_mesh() -> ArrayMesh:
	if _mesh_cache.has("log"):
		return _mesh_cache["log"]
	var segs := 8
	var ring: Array[Vector2] = []
	for i in segs:
		var a := i / float(segs) * TAU
		ring.append(Vector2(cos(a), sin(a)) * 0.5)
	var mesh := ArrayMesh.new()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	for i in segs:
		var p0 := ring[i]
		var p1 := ring[(i + 1) % segs]
		var a0 := Vector3(p0.x, p0.y, -0.5)
		var a1 := Vector3(p1.x, p1.y, -0.5)
		var b0 := Vector3(p0.x, p0.y, 0.5)
		var b1 := Vector3(p1.x, p1.y, 0.5)
		var out := Vector3((p0.x + p1.x) * 0.5, (p0.y + p1.y) * 0.5, 0.0)
		_flat_tri(st, a0, a1, b1, out)
		_flat_tri(st, a0, b1, b0, out)
	st.generate_normals()
	st.commit(mesh)
	st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	for zs in [-0.5, 0.5]:
		for i in segs:
			var p0 := ring[i]
			var p1 := ring[(i + 1) % segs]
			_flat_tri(st, Vector3(0, 0, zs), Vector3(p0.x, p0.y, zs), Vector3(p1.x, p1.y, zs), Vector3(0, 0, zs))
	st.generate_normals()
	st.commit(mesh)
	_mesh_cache["log"] = mesh
	return mesh


static func chunk_mesh(variant: int) -> ArrayMesh:
	var key := "chunk_%d" % (variant % 4)
	if _mesh_cache.has(key):
		return _mesh_cache[key]
	var m := icosa(0.5, 0.18, 1000 + variant % 4)
	_mesh_cache[key] = m
	return m


static func crate_mesh() -> ArrayMesh:
	if _mesh_cache.has("crate"):
		return _mesh_cache["crate"]
	# unit crate: inner box + frame bars on the edges, single surface (material tints it)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	_append_box(st, Vector3.ZERO, Vector3(0.92, 0.92, 0.92))
	var e := 0.5 - 0.06
	for a in [-1, 1]:
		for b in [-1, 1]:
			_append_box(st, Vector3(a * e, b * e, 0), Vector3(0.12, 0.12, 1.0))
			_append_box(st, Vector3(a * e, 0, b * e), Vector3(0.12, 1.0, 0.12))
			_append_box(st, Vector3(0, a * e, b * e), Vector3(1.0, 0.12, 0.12))
	st.generate_normals()
	var m := st.commit()
	_mesh_cache["crate"] = m
	return m


static func _append_box(st: SurfaceTool, c: Vector3, s: Vector3) -> void:
	var h := s * 0.5
	var v := [
		c + Vector3(-h.x, -h.y, -h.z), c + Vector3(h.x, -h.y, -h.z), c + Vector3(h.x, h.y, -h.z), c + Vector3(-h.x, h.y, -h.z),
		c + Vector3(-h.x, -h.y, h.z), c + Vector3(h.x, -h.y, h.z), c + Vector3(h.x, h.y, h.z), c + Vector3(-h.x, h.y, h.z),
	]
	var faces := [[0, 1, 2, 3], [5, 4, 7, 6], [4, 0, 3, 7], [1, 5, 6, 2], [3, 2, 6, 7], [4, 5, 1, 0]]
	for f in faces:
		var a: Vector3 = v[f[0]]
		var b: Vector3 = v[f[1]]
		var cc: Vector3 = v[f[2]]
		var d: Vector3 = v[f[3]]
		var out := (a + b + cc + d) * 0.25 - c
		_flat_tri(st, a, b, cc, out)
		_flat_tri(st, a, cc, d, out)


static func item_mat(it: Item) -> StandardMaterial3D:
	var m: Dictionary = Defs.MATERIALS[it.mat]
	var col: Color = m.color
	match it.cat():
		"sand":
			return mat(col.darkened(0.05), 0.0, 1.0)
		"glass":
			var gk := "glass_item_%s" % it.polished
			if _mat_cache.has(gk):
				return _mat_cache[gk]
			var gm := StandardMaterial3D.new()
			gm.albedo_color = Color(0.75, 0.92, 1.0, 0.55)
			gm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			gm.roughness = 0.02 if it.polished else 0.12
			gm.metallic_specular = 1.0
			gm.rim_enabled = true
			gm.rim = 0.6
			_mat_cache[gk] = gm
			return gm
		"crate":
			return mat(Color("b07a45"), 0.0, 0.9)
		"wood":
			if it.form == "chips":
				return mat(col.darkened(0.15), 0.0, 1.0)
			return mat(col, 0.0, 0.85)
		"metal":
			var key := "metal_%s_%s" % [it.mat, it.polished]
			if _mat_cache.has(key):
				return _mat_cache[key]
			var mm := StandardMaterial3D.new()
			mm.albedo_color = col.lightened(0.1)
			mm.metallic = 0.75
			mm.roughness = 0.12 if it.polished else 0.38
			mm.metallic_specular = 0.8
			_mat_cache[key] = mm
			return mm
		"gem":
			if not it.refined:
				var rock: Color = m.rock
				return mat(rock.lerp(col, 0.25), 0.0, 0.95)
			if it.polished:
				return mat(col.lightened(0.25), 0.9, 0.05)
			return mat(col, 0.35, 0.3)
	# ore (unrefined): rock tinted by purity
	var rk: Color = m.rock
	var p := snappedf(clampf(it.purity, 0.0, 1.0), 0.1)
	var c2 := rk.lerp(col, p * 0.85)
	if it.washed:
		c2 = c2.lightened(0.12)
	return mat(c2, 0.0, 0.9)


static func heat_overlay(lvl: int) -> StandardMaterial3D:
	var key := "heat_%d" % lvl
	if _mat_cache.has(key):
		return _mat_cache[key]
	var m := StandardMaterial3D.new()
	var c := Color(1.0, 0.45, 0.1)
	m.albedo_color = Color(c.r, c.g, c.b, 0.25 * lvl)
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = 0.8 * lvl
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat_cache[key] = m
	return m


## Circular saw blade in the XY plane (axis Z), radius r, with teeth.
static func blade_mesh(r: float) -> ArrayMesh:
	var key := "blade_%f" % r
	if _mesh_cache.has(key):
		return _mesh_cache[key]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	var teeth := 16
	var t := 0.012
	var pts: Array[Vector2] = []
	for i in teeth * 2:
		var a := i / float(teeth * 2) * TAU
		var rr := r if i % 2 == 0 else r * 0.86
		pts.append(Vector2(cos(a), sin(a)) * rr)
	for zs in [-t, t]:
		for i in pts.size():
			var p0 := pts[i]
			var p1 := pts[(i + 1) % pts.size()]
			_flat_tri(st, Vector3(0, 0, zs), Vector3(p0.x, p0.y, zs), Vector3(p1.x, p1.y, zs), Vector3(0, 0, zs))
	for i in pts.size():
		var p0 := pts[i]
		var p1 := pts[(i + 1) % pts.size()]
		var out := Vector3(p0.x + p1.x, p0.y + p1.y, 0)
		_flat_tri(st, Vector3(p0.x, p0.y, -t), Vector3(p1.x, p1.y, -t), Vector3(p1.x, p1.y, t), out)
		_flat_tri(st, Vector3(p0.x, p0.y, -t), Vector3(p1.x, p1.y, t), Vector3(p0.x, p0.y, t), out)
	st.generate_normals()
	var m := st.commit()
	_mesh_cache[key] = m
	return m


## Gear / roller with ridges along Z, radius r, length l (axis Z).
static func roller_mesh(r: float, l: float, ridges: int = 10) -> ArrayMesh:
	var key := "roller_%f_%f_%d" % [r, l, ridges]
	if _mesh_cache.has(key):
		return _mesh_cache[key]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	var pts: Array[Vector2] = []
	for i in ridges * 2:
		var a := i / float(ridges * 2) * TAU
		var rr := r if i % 2 == 0 else r * 0.78
		pts.append(Vector2(cos(a), sin(a)) * rr)
	var h := l * 0.5
	for zs in [-h, h]:
		for i in pts.size():
			var p0 := pts[i]
			var p1 := pts[(i + 1) % pts.size()]
			_flat_tri(st, Vector3(0, 0, zs), Vector3(p0.x, p0.y, zs), Vector3(p1.x, p1.y, zs), Vector3(0, 0, zs))
	for i in pts.size():
		var p0 := pts[i]
		var p1 := pts[(i + 1) % pts.size()]
		var out := Vector3(p0.x + p1.x, p0.y + p1.y, 0)
		_flat_tri(st, Vector3(p0.x, p0.y, -h), Vector3(p1.x, p1.y, -h), Vector3(p1.x, p1.y, h), out)
		_flat_tri(st, Vector3(p0.x, p0.y, -h), Vector3(p1.x, p1.y, h), Vector3(p0.x, p0.y, h), out)
	st.generate_normals()
	var m := st.commit()
	_mesh_cache[key] = m
	return m


static func metal_mat(color: Color, rough: float = 0.35) -> StandardMaterial3D:
	var key := "metalm_%s_%.2f" % [color.to_html(false), rough]
	if _mat_cache.has(key):
		return _mat_cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = 0.7
	m.roughness = rough
	m.metallic_specular = 0.7
	_mat_cache[key] = m
	return m
