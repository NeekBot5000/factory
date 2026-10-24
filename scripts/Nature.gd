class_name Nature
## Living-world helpers: wind-swayed foliage materials, grass that bends around the player and hits
## (purely visual, done in the vertex shader), and one-shot particle bursts.

const MAX_BENDERS := 8

const WIND_SHADER := """
shader_type spatial;
render_mode cull_back;
uniform vec4 albedo : source_color = vec4(0.3, 0.6, 0.25, 1.0);
uniform float sway = 0.08;        // metres of movement at the top of the mesh
uniform float height = 2.0;       // local height over which sway ramps from 0 to full
uniform float base = -1.0;        // local y where sway starts
void vertex() {
	vec3 wp = NODE_POSITION_WORLD;
	float k = clamp((VERTEX.y - base) / height, 0.0, 1.0);
	float t = TIME * 1.3 + wp.x * 0.21 + wp.z * 0.17;
	vec3 off = vec3(sin(t) + 0.35 * sin(t * 2.7 + 1.3), 0.0, 0.6 * cos(t * 0.8 + 0.5)) * sway * k;
	VERTEX += (inverse(MODEL_MATRIX) * vec4(off, 0.0)).xyz;
}
void fragment() {
	ALBEDO = albedo.rgb;
	ROUGHNESS = 1.0;
}
"""

const GRASS_SHADER := """
shader_type spatial;
render_mode cull_disabled;
uniform vec4 benders[8];          // xyz = world position, w = strength (0 = unused)
void vertex() {
	// blade mesh spans local y -0.16..0.16; only the tip moves
	float k = clamp((VERTEX.y + 0.16) / 0.32, 0.0, 1.0);
	k *= k;
	vec3 root = (MODEL_MATRIX * vec4(0.0, -0.16, 0.0, 1.0)).xyz;
	float t = TIME * 2.1 + root.x * 0.35 + root.z * 0.27;
	vec3 off = vec3(sin(t) * 0.05 + sin(t * 2.3) * 0.02, 0.0, cos(t * 0.7) * 0.03);
	for (int i = 0; i < 8; i++) {
		vec4 b = benders[i];
		if (b.w <= 0.0) continue;
		vec3 d = root - b.xyz;
		d.y = 0.0;
		float dist = length(d);
		float r = 0.55 + b.w * 0.35;
		if (dist < r) {
			float push = (1.0 - dist / r) * min(b.w, 1.5);
			vec3 dir = dist > 0.001 ? d / dist : vec3(1.0, 0.0, 0.0);
			off += dir * push * 0.22;
			off.y -= push * 0.12;
		}
	}
	VERTEX += (inverse(MODEL_MATRIX) * vec4(off * k, 0.0)).xyz;
}
void fragment() {
	ALBEDO = COLOR.rgb;
	ROUGHNESS = 1.0;
}
"""

static var _wind_shader: Shader
static var _grass_shader: Shader
static var _wind_mats := {}


## A flat-colour material whose vertices sway in the wind; top of the mesh moves most.
static func wind_mat(color: Color, sway: float, height: float = 2.0, base: float = -1.0) -> ShaderMaterial:
	var key := "%s_%.3f_%.2f_%.2f" % [color.to_html(), sway, height, base]
	if _wind_mats.has(key):
		return _wind_mats[key]
	if _wind_shader == null:
		_wind_shader = Shader.new()
		_wind_shader.code = WIND_SHADER
	var m := ShaderMaterial.new()
	m.shader = _wind_shader
	m.set_shader_parameter("albedo", color)
	m.set_shader_parameter("sway", sway)
	m.set_shader_parameter("height", height)
	m.set_shader_parameter("base", base)
	_wind_mats[key] = m
	return m


static func grass_mat() -> ShaderMaterial:
	if _grass_shader == null:
		_grass_shader = Shader.new()
		_grass_shader.code = GRASS_SHADER
	var m := ShaderMaterial.new()
	m.shader = _grass_shader
	var empty: Array[Vector4] = []
	for i in MAX_BENDERS:
		empty.append(Vector4.ZERO)
	m.set_shader_parameter("benders", empty)
	return m


## One-shot burst of little tumbling cubes. `dir` is the main direction they fly.
## (Own tiny simulation instead of CPUParticles3D so the debris shows up on the very frame of the hit.)
static func burst(parent: Node, pos: Vector3, dir: Vector3, color: Color, amount: int, speed: float = 2.0,
		size: float = 0.025, gravity: float = 9.0, lifetime: float = 0.7, spread: float = 55.0, glow: float = 0.0) -> void:
	var b := Debris.new()
	parent.add_child(b)
	b.start(pos, dir, color, maxi(1, amount), speed, size, gravity, lifetime, spread, glow)


class Debris extends MultiMeshInstance3D:
	var _pos := PackedVector3Array()
	var _vel := PackedVector3Array()
	var _rot := PackedVector3Array()
	var _spin := PackedVector3Array()
	var _life := PackedFloat32Array()
	var _gravity := 9.0
	var _lifetime := 0.7
	var _size := 0.025
	var _t := 0.0

	func start(pos: Vector3, dir: Vector3, color: Color, amount: int, speed: float, size: float,
			gravity: float, lifetime: float, spread: float, glow: float) -> void:
		_gravity = gravity
		_lifetime = lifetime
		_size = size
		cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = LowPoly.box(Vector3.ONE)
		mm.instance_count = amount
		multimesh = mm
		material_override = LowPoly.mat(color, 0.9, glow)
		top_level = true
		global_transform = Transform3D.IDENTITY
		var d := dir.normalized() if dir.length() > 0.01 else Vector3.UP
		var side := d.cross(Vector3.UP if absf(d.y) < 0.9 else Vector3.RIGHT).normalized()
		var up := side.cross(d)
		for i in amount:
			var a := deg_to_rad(randf() * spread)
			var r := randf() * TAU
			var v := (d * cos(a) + (side * cos(r) + up * sin(r)) * sin(a)) * randf_range(speed * 0.4, speed)
			_pos.append(pos + Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * size)
			_vel.append(v)
			_rot.append(Vector3(randf(), randf(), randf()) * TAU)
			_spin.append(Vector3(randf_range(-12, 12), randf_range(-12, 12), randf_range(-12, 12)))
			_life.append(lifetime * randf_range(0.6, 1.0))
		_update(0.0)

	func _process(delta: float) -> void:
		_t += delta
		if _t > _lifetime:
			queue_free()
			return
		_update(delta)

	func _update(delta: float) -> void:
		for i in _pos.size():
			_vel[i] += Vector3(0, -_gravity, 0) * delta
			_vel[i] *= 1.0 - minf(1.0, delta * 1.5)
			_pos[i] += _vel[i] * delta
			_rot[i] += _spin[i] * delta
			var k := clampf(1.0 - (_t / _life[i] - 0.6) / 0.4, 0.0, 1.0) if _t < _life[i] else 0.0
			var s := _size * randf_range(0.95, 1.05) * k
			multimesh.set_instance_transform(i, Transform3D(Basis.from_euler(_rot[i]).scaled(Vector3.ONE * maxf(s, 0.0001)), _pos[i]))
