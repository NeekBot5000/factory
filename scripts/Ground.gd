class_name Ground
extends RefCounted
## Surface detail for the forest floor and the rocks, drawn by the shader itself (no texture files): soft
## patches of lighter and darker grass, drier yellow-green areas, fine grain up close, pebbles on dirt, and a
## grainy, speckled face on stone. The low-poly shapes and their colours stay exactly as they were.

const NOISE := """
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}
float fbm(vec2 p) { return vnoise(p) * 0.6 + vnoise(p * 2.03 + 17.0) * 0.3 + vnoise(p * 4.1 + 41.0) * 0.1; }
"""

const TERRAIN := """
shader_type spatial;
render_mode diffuse_lambert;
varying vec3 wpos;
%s
void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	vec3 base = COLOR.rgb;
	float dist = length(wpos - INV_VIEW_MATRIX[3].xyz);
	float near = 1.0 - smoothstep(18.0, 55.0, dist);      // fine detail fades out with distance (no shimmer)
	float grass = clamp((base.g - base.r) * 5.0, 0.0, 1.0); // green ground vs dirt
	float big = fbm(wpos.xz * 0.045);
	float mid = fbm(wpos.xz * 0.35);
	float fine = vnoise(wpos.xz * 2.6);
	vec3 c = base * (0.84 + 0.32 * big);
	// drier, yellower patches in the grass, and darker lush ones
	c = mix(c, c * vec3(1.16, 1.1, 0.7), grass * smoothstep(0.5, 0.7, big) * 0.75);
	c = mix(c, c * vec3(0.78, 0.9, 0.76), grass * smoothstep(0.48, 0.28, mid) * 0.6);
	c *= 0.86 + 0.28 * mid;
	c *= mix(1.0, 0.88 + 0.24 * fine, near);
	// tiny pebbles and darker ruts on dirt: small and subtle, a shade lighter than the dirt itself
	float peb = smoothstep(0.88, 0.93, vnoise(wpos.xz * 11.0)) * (1.0 - grass) * near;
	c = mix(c, c * vec3(1.22, 1.2, 1.15), peb * 0.6);
	c = mix(c, c * 0.8, (1.0 - grass) * smoothstep(0.55, 0.78, mid) * 0.55);
	ALBEDO = c;
	ROUGHNESS = 0.96;
}
"""

const STONE := """
shader_type spatial;
render_mode diffuse_lambert;
uniform vec4 albedo : source_color = vec4(0.54, 0.53, 0.5, 1.0);
varying vec3 wpos;
varying vec3 wnrm;
%s
void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}
void fragment() {
	// project the grain from whichever side the face points (so it never stretches)
	vec3 an = abs(wnrm);
	vec2 uv = an.y > max(an.x, an.z) ? wpos.xz : (an.x > an.z ? wpos.zy : wpos.xy);
	float g = fbm(uv * 2.5);
	float pits = smoothstep(0.86, 0.92, vnoise(uv * 18.0));
	vec3 c = albedo.rgb * (0.86 + 0.24 * g);
	c = mix(c, c * 0.72, pits * 0.55);      // small dark pits and flecks, like weathered granite
	ALBEDO = c;
	ROUGHNESS = 0.92;
}
"""

static var _terrain_shader: Shader
static var _stone_shader: Shader
static var _stone_mats := {}


static func terrain_mat() -> ShaderMaterial:
	if _terrain_shader == null:
		_terrain_shader = Shader.new()
		_terrain_shader.code = TERRAIN % NOISE
	var m := ShaderMaterial.new()
	m.shader = _terrain_shader
	return m


## Grainy stone in the given colour (shared per colour).
static func stone_mat(color: Color) -> ShaderMaterial:
	var key := color.to_html()
	if _stone_mats.has(key):
		return _stone_mats[key]
	if _stone_shader == null:
		_stone_shader = Shader.new()
		_stone_shader.code = STONE % NOISE
	var m := ShaderMaterial.new()
	m.shader = _stone_shader
	m.set_shader_parameter("albedo", color)
	_stone_mats[key] = m
	return m
