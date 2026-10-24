class_name Icons
extends SubViewport
## Renders every shop item's 3D model into a thumbnail, and derives a "printed outline drawing with a border"
## for the delivery boxes from each thumbnail.

signal icon_ready(id: String)

const SIZE := 192

var icons := {}
var box_art := {}
var _queue: Array[String] = []
var _current: Node3D = null
var _current_id := ""
var _wait := 0
var _holder: Node3D
var _cam: Camera3D
var headless := false


func _ready() -> void:
	headless = DisplayServer.get_name() == "headless"
	size = Vector2i(SIZE, SIZE)
	transparent_bg = true
	own_world_3d = true
	msaa_3d = Viewport.MSAA_4X
	render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.85, 0.85, 0.95)
	env.ambient_light_energy = 0.7
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, -30, 0)
	sun.light_energy = 1.4
	add_child(sun)
	_cam = Camera3D.new()
	_cam.fov = 26.0
	add_child(_cam)
	_cam.current = true
	_holder = Node3D.new()
	add_child(_holder)
	for id in Tools.SHOP_ORDER:
		_queue.append(id)


func get_icon(id: String) -> Texture2D:
	return icons.get(id)


func get_box_art(id: String) -> Texture2D:
	return box_art.get(id)


func _process(_delta: float) -> void:
	if headless:
		return
	if _current != null:
		_wait -= 1
		if _wait <= 0:
			var img := get_texture().get_image()
			icons[_current_id] = ImageTexture.create_from_image(img)
			box_art[_current_id] = ImageTexture.create_from_image(_outline_art(img))
			_current.queue_free()
			_current = null
			icon_ready.emit(_current_id)
		return
	if _queue.is_empty():
		return
	_current_id = _queue.pop_front()
	_current = Node3D.new()
	_holder.add_child(_current)
	var m := Tools.build_model(_current_id, _current)
	# show axes diagonally like a product shot
	_current.rotation_degrees = Vector3(0, 90, -35) if _current_id != "drill" and _current_id != "phone" else Vector3(0, 120, 0)
	_frame()
	_wait = 3


func _frame() -> void:
	var aabb := AABB()
	var first := true
	for c in _current.find_children("*", "MeshInstance3D", true, false):
		var vi := c as MeshInstance3D
		var a: AABB = vi.global_transform * vi.get_aabb()
		aabb = a if first else aabb.merge(a)
		first = false
	var center := aabb.get_center()
	var radius := maxf(0.05, aabb.size.length() * 0.5)
	var dist := radius / sin(deg_to_rad(_cam.fov * 0.5)) * 1.0
	_cam.global_transform = Transform3D(Basis(), center + Vector3(0.15, 0.1, 1.0).normalized() * dist).looking_at(center, Vector3.UP)


## Turns a rendered icon into a brown "printed" line drawing (silhouette outline + inner edges) with a border.
func _outline_art(src: Image) -> Image:
	var n := 128
	var img := src.duplicate() as Image
	img.resize(n, n, Image.INTERPOLATE_BILINEAR)
	var out := Image.create(n, n, false, Image.FORMAT_RGBA8)
	out.fill(Color(0, 0, 0, 0))
	var ink := Color("5a2f15")
	var lum := PackedFloat32Array()
	lum.resize(n * n)
	for y in n:
		for x in n:
			var c := img.get_pixel(x, y)
			lum[y * n + x] = (c.r + c.g + c.b) / 3.0 if c.a > 0.4 else -1.0
	for y in range(1, n - 1):
		for x in range(1, n - 1):
			var v := lum[y * n + x]
			var edge := false
			for o in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var w := lum[(y + o.y) * n + (x + o.x)]
				if (v < 0.0) != (w < 0.0):
					edge = v >= 0.0
				elif v >= 0.0 and absf(v - w) > 0.22:
					edge = true
			if edge:
				out.set_pixel(x, y, ink)
	# thicken the silhouette lines slightly
	var thick := out.duplicate() as Image
	for y in range(1, n - 1):
		for x in range(1, n - 1):
			if out.get_pixel(x, y).a > 0.5:
				thick.set_pixel(x + 1, y, ink)
				thick.set_pixel(x, y + 1, ink)
	# double border frame like a shipping label
	for k in [2, 3, 7]:
		for i in range(k, n - k):
			thick.set_pixel(i, k, ink)
			thick.set_pixel(i, n - 1 - k, ink)
			thick.set_pixel(k, i, ink)
			thick.set_pixel(n - 1 - k, i, ink)
	return thick
