extends Node3D
## The visual check of the Roblox version against this game. Renders the same camera views twice:
##   godot  - this game itself (Main.tscn), and writes the views' camera poses to <out>/views.json
##   roblox - what the Roblox scripts build (a dump from roblox/tests/lune/dump.luau: every part, in studs) plus the
##            uploaded meshes (roblox/models/godot/*.glb) coloured the way Roblox's WorldMeshes colours them (Roblox
##            drops a glb's materials; each mesh is named after its colour, one flat colour per mesh)
## Both use this game's sky, sun and fog, so what differs is what's built, where, and in what colours.
## Run (see tools/roblox_view.sh):
##   xvfb-run -a godot --path . res://tools/RobloxView.tscn --rendering-driver opengl3 -- godot <out>
##   xvfb-run -a godot --path . res://tools/RobloxView.tscn --rendering-driver opengl3 -- roblox <out> <dump.json>

const STUD := 1.0 / 3.0
var mode := "godot"
var out := "/tmp/roblox_view"
var dump := ""
var cam: Camera3D
var views: Array = []


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		mode = args[0]
	if args.size() > 1:
		out = args[1]
	if args.size() > 2:
		dump = args[2]
	DirAccess.make_dir_recursive_absolute(out)
	get_window().size = Vector2i(1280, 720)
	cam = Camera3D.new()
	cam.fov = 75.0
	cam.near = 0.05
	cam.far = 900.0
	add_child(cam)
	if mode == "godot":
		await _godot()
	else:
		await _roblox()
	get_tree().quit()


func _shoot(name: String) -> void:
	for k in 6:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s_%s.png" % [out, mode, name])


# ------------------------------------------------------------------ this game
func _godot() -> void:
	Game.save_enabled = false
	Game.reset()
	var main: Node3D = load("res://scenes/Main.tscn").instantiate()
	add_child(main)
	for k in 10:
		await get_tree().physics_frame
	main.hud.visible = false
	for c in main.hud.get_children():
		if c is CanvasItem:
			(c as CanvasItem).visible = false
	var p: Node3D = main.player
	var pc: Camera3D = p.get("cam")
	var eye := pc.global_transform
	# the views: the porch at the start, the clearing, a tree up close, the cabin from outside, the truck
	var near_tree: Node3D = null
	var best := 1e9
	for t in main.trees:
		var d: float = (t as Node3D).global_position.distance_to(eye.origin)
		if d < best:
			best = d
			near_tree = t
	var tp: Vector3 = near_tree.global_position
	views = [
		["porch", eye],
		["clearing", Transform3D(Basis(), eye.origin + Vector3(0, 6, -4)).looking_at(eye.origin + Vector3(0, 0, 20), Vector3.UP)],
		["tree", Transform3D(Basis(), tp + Vector3(1.6, 1.7, 1.6)).looking_at(tp + Vector3(0, 1.4, 0), Vector3.UP)],
		["cabin", Transform3D(Basis(), Vector3(7, 3.5, 14)).looking_at(Vector3(0, 1.5, 0), Vector3.UP)],
		["sign", Transform3D(Basis(), eye.origin + Vector3(-2.5, 0.5, 5)).looking_at(eye.origin + Vector3(-4.5, -0.5, 9), Vector3.UP)],
		["truck", Transform3D(Basis(), main.ship_truck.global_position + Vector3(5, 3, 6)).looking_at(main.ship_truck.global_position + Vector3(0, 1, 0), Vector3.UP)],
	]
	p.set_process(false)
	p.set_physics_process(false)
	cam.make_current()
	var saved := []
	for v in views:
		cam.global_transform = v[1]
		await _shoot(v[0])
		var t: Transform3D = v[1]
		saved.append({"name": v[0], "origin": [t.origin.x, t.origin.y, t.origin.z],
			"basis": [t.basis.x.x, t.basis.x.y, t.basis.x.z, t.basis.y.x, t.basis.y.y, t.basis.y.z, t.basis.z.x, t.basis.z.y, t.basis.z.z]})
	var f := FileAccess.open(out + "/views.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(saved))


# ------------------------------------------------------------------ the Roblox build
func _environment() -> void:
	# (the same as Main._environment)
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color("4a8fe0")
	sm.sky_horizon_color = Color("cfe6f5")
	sm.ground_horizon_color = Color("cfe6f5")
	sm.ground_bottom_color = Color("6d8f5a")
	sky.sky_material = sm
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.42
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.fog_enabled = true
	env.fog_light_color = Color("a9c4b8")
	env.fog_light_energy = 0.8
	env.fog_density = 0.006
	env.fog_sky_affect = 0.2
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -35, 0)
	sun.light_energy = 1.05
	sun.light_color = Color("fff2dc")
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_max_distance = 60.0
	sun.shadow_bias = 0.04
	add_child(sun)


var _mats := {}
func _mat(c: Color, neon := false) -> StandardMaterial3D:
	var key := c.to_html() + ("n" if neon else "")
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 1.0
	if neon:
		m.emission_enabled = true
		m.emission = c
	_mats[key] = m
	return m


## A glb the way Roblox shows it: every mesh one flat colour, taken from its name ("terrain_3_4_c4f8a35").
func _glb(path: String) -> int:
	var doc := GLTFDocument.new()
	var st := GLTFState.new()
	if doc.append_from_file(ProjectSettings.globalize_path(path), st) != OK:
		push_warning("couldn't read " + path)
		return 0
	var root: Node3D = doc.generate_scene(st)
	var n := 0
	var stack: Array = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		stack.append_array(node.get_children())
		if node is MeshInstance3D:
			var mi := node as MeshInstance3D
			var nm := String(mi.name)       # (the node's name: Godot prefixes mesh names with the file's)
			if nm.begins_with("marker"):
				mi.visible = false
				continue
			var at := nm.find("_c")
			var col := Color("ff00ff")
			while at >= 0:
				var hexs := nm.substr(at + 2, 6)
				if hexs.is_valid_hex_number() and hexs.length() == 6:
					col = Color("#" + hexs)
					break
				at = nm.find("_c", at + 1)
			mi.material_override = _mat(col)
			if nm.begins_with("ground_"):
				# (Roblox: TextureID from the uploaded image, see WorldMeshes)
				var ck := nm.substr(7).get_slice("_c", 0)
				var img := Image.load_from_file(ProjectSettings.globalize_path("res://roblox/images/ground/ground_%s.png" % ck))
				var tm := StandardMaterial3D.new()
				tm.albedo_texture = ImageTexture.create_from_image(img)
				tm.roughness = 1.0
				tm.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
				mi.material_override = tm
			if nm.begins_with("grass") or nm.begins_with("cloud") or nm.begins_with("hills"):
				mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			n += 1
	root.scale = Vector3.ONE * STUD
	add_child(root)
	return n


func _cf(c: Array) -> Transform3D:
	return Transform3D(Basis(Vector3(c[3], c[6], c[9]), Vector3(c[4], c[7], c[10]), Vector3(c[5], c[8], c[11])), Vector3(c[0], c[1], c[2]))


## The trucks the way WorldMeshes puts them on: each "ship" mesh at the Truck model's pivot, "van" at the Van's.
func _trucks(pivots: Dictionary) -> void:
	var doc := GLTFDocument.new()
	var st := GLTFState.new()
	if doc.append_from_file(ProjectSettings.globalize_path("res://roblox/models/godot/trucks.glb"), st) != OK:
		return
	var src: Node3D = doc.generate_scene(st)
	var studs := Node3D.new()
	studs.scale = Vector3.ONE * STUD
	add_child(studs)
	for mi in src.find_children("*", "MeshInstance3D", true, false):
		var nm := String(mi.name)
		var key := "Truck" if nm.begins_with("ship") else ("Van" if nm.begins_with("van") else "")
		if key == "" or not pivots.has(key):
			continue
		var at := nm.find("_c")
		var col := Color("#" + nm.substr(at + 2, 6)) if at >= 0 else Color.MAGENTA
		var m := MeshInstance3D.new()
		m.mesh = (mi as MeshInstance3D).mesh
		m.transform = _cf(pivots[key]) * (mi as MeshInstance3D).global_transform
		m.material_override = _mat(col)
		studs.add_child(m)
	src.free()


func _roblox() -> void:
	_environment()
	var nm := 0
	for g in ["world", "crowns"]:
		nm += _glb("res://roblox/models/godot/%s.glb" % g)
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(dump))
	_trucks(data.get("pivots", {}))
	var box := BoxMesh.new()
	box.size = Vector3.ONE
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.5
	cyl.bottom_radius = 0.5
	cyl.height = 1.0
	cyl.radial_segments = 24
	var ball := SphereMesh.new()
	ball.radius = 0.5
	ball.height = 1.0
	var made := 0
	for p in data.parts:
		if float(p.transparency) >= 0.99 or p.shape == "MeshPart":
			continue
		var s := Vector3(p.size[0], p.size[1], p.size[2]) * STUD
		var c: Array = p.cf
		var basis := Basis(Vector3(c[3], c[6], c[9]), Vector3(c[4], c[7], c[10]), Vector3(c[5], c[8], c[11]))
		var xf := Transform3D(basis, Vector3(c[0], c[1], c[2]) * STUD)
		var mi := MeshInstance3D.new()
		match String(p.shape):
			"Cylinder":
				# Roblox cylinders lie along X: length Size.X, diameter Size.Y
				mi.mesh = cyl
				xf = xf * Transform3D(Basis(Vector3(0, 0, 1), PI / 2), Vector3.ZERO)
				mi.scale = Vector3(s.y, s.x, s.z)
			"Ball":
				mi.mesh = ball
				mi.scale = s
			_:
				mi.mesh = box
				mi.scale = s
		var sc := mi.scale
		mi.transform = xf
		mi.scale = sc
		mi.material_override = _mat(Color(p.color[0], p.color[1], p.color[2]), p.material == "Neon")
		if float(p.transparency) > 0.01:
			var m: StandardMaterial3D = (mi.material_override as StandardMaterial3D).duplicate()
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.albedo_color.a = 1.0 - float(p.transparency)
			mi.material_override = m
		add_child(mi)
		made += 1
	print("ROBLOXVIEW meshes %d, parts %d" % [nm, made])
	views = JSON.parse_string(FileAccess.get_file_as_string(out + "/views.json"))
	cam.make_current()
	for v in views:
		var b: Array = v.basis
		var o: Array = v.origin
		cam.global_transform = Transform3D(Basis(Vector3(b[0], b[1], b[2]), Vector3(b[3], b[4], b[5]), Vector3(b[6], b[7], b[8])), Vector3(o[0], o[1], o[2]))
		await _shoot(v.name)
