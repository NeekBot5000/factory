extends Node
## Exports the Godot game's world for the Roblox version, so both look the same:
##   roblox/models/godot/world.glb   every static mesh (terrain, grass, cabin, rocks, bushes, hills, clouds, the
##                                   chopping block, each tree's crown and roots), in studs (1 m = 3 studs)
##   roblox/models/godot/crowns.glb  every tree's crown on its own, named after the tree ("crown_17"): it falls with
##                                   the log when the tree is felled
##   roblox/models/godot/trucks.glb  the log truck and the delivery van, each around its own origin
##   roblox/models/godot/tools.glb   the tools, each with the hand's grip at its origin
##   roblox/src/shared/GodotWorld.luau  where everything is: trees (kind, size, seed), the spawn, the truck's spot and
##                                   route, solid boxes for collisions, the ground heights, the sky and the sun
## Roblox imports a glb as a Model of MeshParts but drops colours, so the triangles are grouped by colour and each
## group's name ends in its colour: "terrain_3_4_c4f8a35". The game colours each MeshPart from its name.
## Two small cubes ("marker_origin" at 0,0,0 and "marker_x" at x = 30 studs) let the game check the import's scale.
## Run: godot --headless --path . res://tools/ExportRobloxWorld.tscn

const S := 3.0                    # studs per metre
const CHUNK := 55.0               # terrain / grass / crown chunk size, metres (fewer, bigger meshes)
const QUANT := 16.0               # colour steps per channel (fewer colours, fewer MeshParts)

var groups := {}                  # "glb/name" -> {"verts": PackedVector3Array, "norms": PackedVector3Array}
var collide: Array = []           # solid boxes: {p, b, size}
var computer: Array = []          # the computer's boxes (E on it opens TimberMart)


func _ready() -> void:
	Game.save_enabled = false
	Game.reset()
	Game.skip_title = true
	var main: Node3D = load("res://scenes/Main.tscn").instantiate()
	add_child(main)
	for i in 4:
		await get_tree().physics_frame
	var out := ProjectSettings.globalize_path("res://roblox/models/godot")
	DirAccess.make_dir_recursive_absolute(out)

	# ---------------------------------------------------------------- the static world
	var tree_index := {}
	for i in main.trees.size():
		tree_index[main.trees[i]] = i
	for child in main.get_children():
		_walk(child, main, tree_index)
	_marker("world")
	var nw := _write("world", out + "/world.glb")
	_marker("crowns")
	var nc := _write("crowns", out + "/crowns.glb")

	# ---------------------------------------------------------------- trucks, around their own origins
	groups.clear()
	for t in [main.ship_truck, main.van]:
		var role := "ship" if t == main.ship_truck else "van"
		var inv: Transform3D = (t as Node3D).global_transform.affine_inverse()
		for mi in (t as Node3D).find_children("*", "MeshInstance3D", true, false):
			if (mi as MeshInstance3D).visible:
				_add_mesh("trucks", role, mi, inv * (mi as MeshInstance3D).global_transform)
	_marker("trucks")
	var nt := _write("trucks", out + "/trucks.glb")

	# ---------------------------------------------------------------- tools, grip at the origin
	groups.clear()
	var holder := Node3D.new()
	add_child(holder)
	for id in ["hatchet", "double_bit", "twins", "combo", "scraper", "gouge", "ringer", "labrys", "greataxe", "spud", "spiral", "robo", "thunder", "saw", "bucksaw", "pole_saw", "chainsaw", "throwing", "crosscut", "drill", "twin_auger", "holesaw", "shears", "phone"]:
		var root := Node3D.new()
		holder.add_child(root)
		Tools.build_model(id, root)
		for mi in root.find_children("*", "MeshInstance3D", true, false):
			_add_mesh("tools", "tool_" + id, mi, root.global_transform.affine_inverse() * (mi as MeshInstance3D).global_transform)
		root.free()
	_marker("tools")
	var nl := _write("tools", out + "/tools.glb")

	# ---------------------------------------------------------------- where everything is
	_write_luau(main)
	print("EXPORT world %d, crowns %d, trucks %d, tools %d mesh groups" % [nw, nc, nt, nl])
	get_tree().quit()


# what each top-level node of the world is, and what to call its meshes
func _walk(n: Node, main: Node3D, tree_index: Dictionary) -> void:
	if n is Player or n is CanvasLayer or n is Truck or n is WorldEnvironment or n is DirectionalLight3D:
		return
	if n is ToolItem:
		# the old hatchet stuck in the chopping block (each player's client hides it once they own a hatchet)
		for mi in n.find_children("*", "MeshInstance3D", true, false):
			_add_mesh("world", "blockhatchet", mi, (mi as MeshInstance3D).global_transform)
		return
	if n is ForestTree:
		var t := n as ForestTree
		var idx: int = tree_index.get(t, -1)
		for c in t.get_children():
			if c.name == "Crown":
				# each tree's crown on its own (it falls with the log when the tree is felled)
				for mi in (c as Node3D).find_children("*", "MeshInstance3D", true, false):
					_add_mesh("crowns", "crown_%d" % idx, mi, (mi as MeshInstance3D).global_transform)
		# the root flare (the trunk and its bark are drawn by the Roblox client, panel by panel)
		for c in t.get_children():
			if c is MeshInstance3D and c != t.get("_core_mi") and not (t.get("_layer_mi") as Array).has(c):
				_add_mesh("world", "roots_" + _chunk_of(t.global_position), c, (c as MeshInstance3D).global_transform)
		return
	if n is Terrain:
		for c in n.get_children():
			if c is MeshInstance3D:
				_add_terrain(c as MeshInstance3D)
		return
	if n is MultiMeshInstance3D:
		_add_multimesh(n as MultiMeshInstance3D)
		return
	var kind := "decor"
	if n is Cabin or n is Computer or n is CompanySign or n is Trophies:
		kind = "cabin"
	elif n is Rock:
		kind = "rock"
	elif n is Bush:
		kind = "bush"
	elif n.name == "Clouds":
		kind = "cloud"
	elif n is StaticBody3D and n.get_child_count() > 0 and (n as Node3D).global_position.distance_to(main.get("BLOCK_AT") + Vector3(0, (n as Node3D).global_position.y, 0)) < 0.5:
		kind = "block"
	elif n is MeshInstance3D and (n as Node3D).global_position.length() > 100.0:
		kind = "hills"
	if kind == "cloud":
		# each cloud on its own, so the game can drift them across the sky like Godot does
		var ci := 0
		for c in n.get_children():
			for mi in (c as Node).find_children("*", "MeshInstance3D", true, false):
				_add_mesh("world", "cloud_%d" % ci, mi, (mi as MeshInstance3D).global_transform)
			ci += 1
		return
	var meshes: Array = []
	if n is MeshInstance3D:
		meshes.append(n)
	meshes.append_array(n.find_children("*", "MeshInstance3D", true, false))
	for mi in meshes:
		if (mi as MeshInstance3D).is_visible_in_tree():
			_add_mesh("world", kind, mi, (mi as MeshInstance3D).global_transform)
	# solid boxes (walls, the porch, the chopping block, rocks)
	if n is Computer:
		for cs in n.find_children("*", "CollisionShape3D", true, false):
			var before := collide.size()
			_add_collider(cs as CollisionShape3D)
			if collide.size() > before:
				computer.append(collide[collide.size() - 1])
	if kind != "cloud" and kind != "hills":
		var bodies: Array = []
		if n is StaticBody3D:
			bodies.append(n)
		bodies.append_array(n.find_children("*", "StaticBody3D", true, false))
		for b in bodies:
			if (b as CollisionObject3D).collision_layer & 1 == 0:
				continue
			for cs in (b as Node).find_children("*", "CollisionShape3D", true, false):
				_add_collider(cs as CollisionShape3D, kind)
		if n is CollisionObject3D and not n is StaticBody3D and (n as CollisionObject3D).collision_layer & 1 != 0:
			for cs in n.find_children("*", "CollisionShape3D", true, false):
				_add_collider(cs as CollisionShape3D, kind)


func _add_collider(cs: CollisionShape3D, kind: String = "decor") -> void:
	if cs.disabled or cs.shape == null:
		return
	var xf := cs.global_transform
	var size := Vector3.ZERO
	if cs.shape is BoxShape3D:
		size = (cs.shape as BoxShape3D).size
	elif cs.shape is CylinderShape3D:
		var c := cs.shape as CylinderShape3D
		size = Vector3(c.radius * 2.0, c.height, c.radius * 2.0)
	elif cs.shape is SphereShape3D:
		var r := (cs.shape as SphereShape3D).radius
		size = Vector3.ONE * r * 2.0
	elif cs.shape is CapsuleShape3D:
		var cp := cs.shape as CapsuleShape3D
		size = Vector3(cp.radius * 2.0, cp.height, cp.radius * 2.0)
	else:
		return
	var sc := xf.basis.get_scale()
	var b := xf.basis.orthonormalized()
	collide.append({"p": xf.origin * S, "b": b, "size": size * sc * S, "kind": kind})


# the colour of a triangle's material (albedo, or a shader's "albedo"), times its vertex colour if it uses one
func _material_color(mi: MeshInstance3D, surface: int) -> Array:
	var mat: Material = mi.material_override
	if mat == null:
		mat = mi.get_surface_override_material(surface)
	if mat == null and mi.mesh != null:
		mat = mi.mesh.surface_get_material(surface)
	var col := Color(0.8, 0.8, 0.8)
	var vcol := false
	if mat is StandardMaterial3D:
		col = (mat as StandardMaterial3D).albedo_color
		vcol = (mat as StandardMaterial3D).vertex_color_use_as_albedo
	elif mat is ShaderMaterial:
		var a = (mat as ShaderMaterial).get_shader_parameter("albedo")
		if a is Color:
			col = a
		else:
			vcol = true
			col = Color.WHITE
	return [col, vcol]


func _q(c: Color, steps: float = QUANT) -> String:
	var r := roundf(clampf(c.r, 0, 1) * steps) / steps
	var g := roundf(clampf(c.g, 0, 1) * steps) / steps
	var b := roundf(clampf(c.b, 0, 1) * steps) / steps
	return Color(r, g, b).to_html(false)


func _group(glb: String, name: String, hex: String) -> Dictionary:
	var key := "%s/%s_c%s" % [glb, name, hex]
	if not groups.has(key):
		groups[key] = {"verts": [], "norms": []}      # (plain Arrays: a packed array read out of a Dictionary is a copy)
	return groups[key]


func _add_tris(glb: String, name: String, mesh: Mesh, surface: int, xf: Transform3D, col: Color, vcol: bool, tint: Color = Color.WHITE) -> void:
	var arr := mesh.surface_get_arrays(surface)
	var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var nrm = arr[Mesh.ARRAY_NORMAL]
	var cols = arr[Mesh.ARRAY_COLOR]
	var idx = arr[Mesh.ARRAY_INDEX]
	var tri: PackedInt32Array = idx if idx != null and (idx as PackedInt32Array).size() > 0 else PackedInt32Array(range(v.size()))
	var nb := xf.basis.inverse().transposed()
	for k in range(0, tri.size() - 2, 3):
		var ids := [tri[k], tri[k + 1], tri[k + 2]]
		var c := col * tint
		if vcol and cols != null and (cols as PackedColorArray).size() > ids[0]:
			var vc: Color = (cols as PackedColorArray)[ids[0]]
			c = Color(col.r * vc.r, col.g * vc.g, col.b * vc.b) * tint
		# (crowns: coarser colour steps, one or two greens a tree, so ~240 crowns stay a few hundred meshes)
		var g := _group(glb, name, _q(c, 5.0 if name.begins_with("crown_") else QUANT))
		for id in ids:
			(g.verts as Array).append(xf * v[id] * S)
			var nn := Vector3.UP
			if nrm != null and (nrm as PackedVector3Array).size() > id:
				nn = (nb * (nrm as PackedVector3Array)[id]).normalized()
			(g.norms as Array).append(nn)


func _add_mesh(glb: String, name: String, mi: MeshInstance3D, xf: Transform3D) -> void:
	if mi.mesh == null:
		return
	for s in mi.mesh.get_surface_count():
		var mc := _material_color(mi, s)
		_add_tris(glb, name, mi.mesh, s, xf, mc[0], mc[1])


func _chunk_of(p: Vector3) -> String:
	return "%d_%d" % [int(floor(p.x / CHUNK)) + 3, int(floor(p.z / CHUNK)) + 3]


func _add_terrain(mi: MeshInstance3D) -> void:
	var arr := mi.mesh.surface_get_arrays(0)
	var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var nrm: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
	var cols: PackedColorArray = arr[Mesh.ARRAY_COLOR]
	var xf := mi.global_transform
	for k in range(0, v.size() - 2, 3):
		var center := xf * ((v[k] + v[k + 1] + v[k + 2]) / 3.0)
		var g := _group("world", "terrain_" + _chunk_of(center), _q(cols[k]))
		for i in 3:
			(g.verts as Array).append(xf * v[k + i] * S)
			(g.norms as Array).append(nrm[k + i])


func _add_multimesh(mmi: MultiMeshInstance3D) -> void:
	var mm := mmi.multimesh
	for i in mm.instance_count:
		var xf := mmi.global_transform * mm.get_instance_transform(i)
		var c := mm.get_instance_color(i) if mm.use_colors else Color.WHITE
		_add_tris("world", "grass_" + _chunk_of(xf.origin), mm.mesh, 0, xf, Color.WHITE, false, c)


func _marker(glb: String) -> void:
	var box := BoxMesh.new()
	box.size = Vector3.ONE * 0.1      # 0.3 studs
	var mi := MeshInstance3D.new()
	mi.mesh = box
	_add_tris(glb, "marker_origin", box, 0, Transform3D.IDENTITY, Color.WHITE, false)
	_add_tris(glb, "marker_x", box, 0, Transform3D(Basis.IDENTITY, Vector3(10.0, 0, 0)), Color.WHITE, false)
	mi.free()


func _write(glb: String, path: String) -> int:
	var root := Node3D.new()
	root.name = glb
	add_child(root)
	var n := 0
	var tris := 0
	for key in groups.keys():
		if not (key as String).begins_with(glb + "/"):
			continue
		var g: Dictionary = groups[key]
		var verts := PackedVector3Array(g.verts)
		var norms := PackedVector3Array(g.norms)
		# Roblox takes up to 20,000 triangles a mesh: split bigger groups
		var per := 60000
		var start := 0
		var part := 0
		while start < verts.size():
			var count := mini(per, verts.size() - start)
			var arrays := []
			arrays.resize(Mesh.ARRAY_MAX)
			arrays[Mesh.ARRAY_VERTEX] = verts.slice(start, start + count)
			arrays[Mesh.ARRAY_NORMAL] = norms.slice(start, start + count)
			var am := ArrayMesh.new()
			am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			var mi := MeshInstance3D.new()
			mi.mesh = am
			mi.name = (key as String).substr(glb.length() + 1) + ("" if part == 0 else "_p%d" % part)
			am.resource_name = mi.name          # (the import may name its MeshParts after the mesh, not the node)
			root.add_child(mi)
			n += 1
			tris += count / 3
			start += count
			part += 1
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	doc.append_from_scene(root, state)
	doc.write_to_filesystem(state, path)
	print("  %s: %d meshes, %d triangles" % [glb, n, tris])
	root.free()
	return n


func _v3(v: Vector3) -> String:
	return "{ %.3f, %.3f, %.3f }" % [v.x, v.y, v.z]


func _write_luau(main: Node3D) -> void:
	var L := PackedStringArray()
	L.append("--!strict")
	L.append("-- Made by tools/ExportRobloxWorld.gd from the Godot game's world. Don't edit by hand: run tools/export_roblox_world.sh.")
	L.append("-- Positions are in studs (Godot metres x 3), in the same place as in the Godot game.")
	L.append("return {")
	# trees
	L.append("\ttrees = {")
	for i in main.trees.size():
		var t: ForestTree = main.trees[i]
		L.append("\t\t{ kind = \"%s\", at = %s, yaw = %.3f, radius = %.3f, bands = %d, seed = %d, giant = %s }," % [t.kind, _v3(t.global_position * S), t.global_rotation.y, t.radius, t.bands, t.get("_seed") % 1000000, str(t.giant)])
	L.append("\t},")
	# the player's start: on the porch, looking out
	var p: Player = main.player
	L.append("\tspawn = { at = %s, yaw = %.3f }," % [_v3(p.spawn_xform.origin * S), p.spawn_xform.basis.get_euler().y])
	var block: Vector3 = main.get("BLOCK_AT")
	block.y = main.terrain.height_at(block.x, block.z)
	L.append("\tblock = %s," % _v3(block * S))
	# the truck: where it parks and the roads out and back
	var tr: Truck = main.ship_truck
	var park: Transform3D = main.get("_truck_park")
	L.append("\ttruck = { at = %s, yaw = %.3f, out = {" % [_v3(park.origin * S), park.basis.get_euler().y])
	for q in main.get("_truck_out"):
		L.append("\t\t%s," % _v3((q as Vector3) * S))
	L.append("\t}, back = {")
	for q in main.get("_truck_back"):
		L.append("\t\t%s," % _v3((q as Vector3) * S))
	L.append("\t}, bed = { center = %s, size = %s } }," % [_v3(tr.to_local(tr.rear_point()) * S), _v3(Vector3(1.9, 1.0, 2.6) * S)])
	# the TimberMart van: in over the crest, U-turn, back onto the loading dock, then out again
	var van: Truck = main.van
	for route in [["inn", van.route_in], ["dock", van.route_dock], ["out", van.route_out]]:
		L.append("\tvan_%s = {" % route[0])
		for q in route[1]:
			L.append("\t\t%s," % _v3((q as Vector3) * S))
		L.append("\t},")
	# solid boxes
	L.append("\tsolid = {")
	for c in collide:
		var b: Basis = c.b
		L.append("\t\t{ p = %s, x = %s, y = %s, z = %s, size = %s, kind = \"%s\" }," % [_v3(c.p), _v3(b.x), _v3(b.y), _v3(b.z), _v3(c.size), c.kind])
	L.append("\t},")
	# the ground: heights every 3 m (9 studs), for the Roblox ground you walk on
	var step := 3.0
	var half := 105.0
	var n := int(half * 2.0 / step) + 1
	L.append("\tground = { origin = %.1f, step = %.1f, n = %d, heights = {" % [-half * S, step * S, n])
	for gz in n:
		var row := PackedStringArray()
		for gx in n:
			row.append("%.2f" % (main.terrain.height_at(-half + gx * step, -half + gz * step) * S))
		L.append("\t\t" + ", ".join(row) + ",")
	L.append("\t} },")
	L.append("\tcabin = { floorY = %.3f }," % (Cabin.FLOOR_Y * S))
	L.append("\tcomputer = {")
	for c in computer:
		var b2: Basis = c.b
		L.append("\t\t{ p = %s, x = %s, y = %s, z = %s, size = %s }," % [_v3(c.p), _v3(b2.x), _v3(b2.y), _v3(b2.z), _v3(c.size)])
	L.append("\t},")
	L.append("}")
	var f := FileAccess.open("res://roblox/src/shared/GodotWorld.luau", FileAccess.WRITE)
	f.store_string("\n".join(L) + "\n")
	f.close()
