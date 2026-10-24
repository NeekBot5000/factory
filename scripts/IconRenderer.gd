class_name IconRenderer
extends SubViewport
## Renders a thumbnail of every part's real 3D model in an isolated world (used for hotbar cards).

signal icon_ready(id: String, tex: Texture2D)

const SIZE := 128

var _queue: Array[String] = []
var _current: Part = null
var _current_id := ""
var _wait := 0
var _holder: Node3D
var _cam: Camera3D
var icons := {}


func _ready() -> void:
	size = Vector2i(SIZE, SIZE)
	transparent_bg = true
	own_world_3d = true
	msaa_3d = Viewport.MSAA_4X
	render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.75, 0.8, 0.95)
	env.ambient_light_energy = 0.7
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -30, 0)
	sun.light_energy = 1.3
	add_child(sun)
	_cam = Camera3D.new()
	_cam.fov = 28.0
	add_child(_cam)
	_cam.current = true
	_holder = Node3D.new()
	add_child(_holder)


func request_all() -> void:
	for id in Defs.PARTS:
		if not icons.has(id) and not _queue.has(id):
			_queue.append(id)


func _process(_delta: float) -> void:
	if _current != null:
		_wait -= 1
		if _wait <= 0:
			var img := get_texture().get_image()
			var tex := ImageTexture.create_from_image(img)
			icons[_current_id] = tex
			icon_ready.emit(_current_id, tex)
			_current.queue_free()
			_current = null
		return
	if _queue.is_empty():
		return
	_current_id = _queue.pop_front()
	_current = Part.create(_current_id)
	_holder.add_child(_current)
	_current.setup(null, _current_id, Vector3i.ZERO, 0, true)
	_current.position = Vector3.ZERO
	_frame(_current)
	_wait = 3


func _frame(p: Part) -> void:
	var aabb := AABB()
	var first := true
	for c in p.find_children("*", "VisualInstance3D", true, false):
		var vi := c as VisualInstance3D
		if vi is Label3D:
			continue
		var a: AABB = vi.global_transform * vi.get_aabb()
		if first:
			aabb = a
			first = false
		else:
			aabb = aabb.merge(a)
	var center := aabb.get_center()
	var radius := maxf(0.6, aabb.size.length() * 0.5)
	var dir := Vector3(1.0, 0.85, 1.25).normalized()
	var dist := radius / sin(deg_to_rad(_cam.fov * 0.5)) * 0.95
	_cam.global_transform = Transform3D(Basis(), center + dir * dist).looking_at(center, Vector3.UP)
