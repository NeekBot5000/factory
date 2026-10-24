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


static func item_mesh(kind: String) -> Mesh:
	var key := "item_" + kind
	if _mesh_cache.has(key):
		return _mesh_cache[key]
	var shape: String = Defs.RESOURCES[kind].shape
	var m: Mesh
	match shape:
		"chunk": m = icosa(0.16, 0.22, hash(kind))
		"ingot": m = ingot()
		"gem": m = octa(0.15, 0.19)
		"crystal": m = octa(0.1, 0.27)
		_: m = icosa(0.16, 0.04, 7)
	_mesh_cache[key] = m
	return m


static func item_mat(kind: String, tier: int) -> StandardMaterial3D:
	var c: Color = Defs.RESOURCES[kind].color
	match clampi(tier, 0, 3):
		0: return mat(c, 0.0, 0.75)
		1: return mat(c.lightened(0.15), 0.35, 0.45)
		2: return mat(c.lightened(0.3), 0.8, 0.3)
		_: return mat(c.lightened(0.5), 1.6, 0.2)
