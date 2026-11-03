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
var rocks: Array = []             # each rock: {at (studs), s (Godot's size), ore, hidden, hp}
var bushes: Array = []            # each bush: {at, r (studs), color}


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
	await _bake_ground(main, ProjectSettings.globalize_path("res://roblox/images/ground"))
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
	for id in ["hatchet", "double_bit", "twins", "combo", "scraper", "gouge", "ringer", "labrys", "greataxe", "spud", "spiral", "robo", "thunder", "saw", "bucksaw", "pole_saw", "chainsaw", "throwing", "crosscut", "drill", "twin_auger", "holesaw", "planer", "washer", "shears", "vacuum", "twinvac", "cyclone", "wires", "hammer", "rake", "blower", "can", "scale", "pickaxe", "steel_pick", "sledge", "rock_drill", "core_drill", "detector", "dynamite", "phone", "bp_crank", "bp_lever", "bp_button", "bp_conveyor", "bp_ramp", "bp_piston", "bp_rotator", "bp_truck_caller", "bp_windmill", "bp_generator", "bp_battery", "bp_logic", "bp_sensors", "bp_lamp", "bp_sawmill", "bp_chipper", "bp_planter", "bp_sprinkler", "bp_smelter", "bp_kiln", "bp_assembler", "bp_grabber", "bp_sorter", "bp_crate", "bp_wireless", "bp_drill_rig", "bp_charger", "bp_carts", "bp_rail_tools", "bp_rail_extras", "bp_oil", "bp_drones", "bp_feller", "bp_wheelbarrow"]:
		var root := Node3D.new()
		holder.add_child(root)
		Tools.build_model(id, root)
		for mi in root.find_children("*", "MeshInstance3D", true, false):
			_add_mesh("tools", "tool_" + id, mi, root.global_transform.affine_inverse() * (mi as MeshInstance3D).global_transform)
		root.free()
	_marker("tools")
	var nl := _write("tools", out + "/tools.glb")

	# ---------------------------------------------------------------- props: things the game shows and changes
	# (each around its own origin: the company sign's six tiers, ...)
	groups.clear()
	for tier in 6:
		var sign := CompanySign.new()
		holder.add_child(sign)
		sign.tier = tier
		sign.call("_build")
		for mi in sign.find_children("*", "MeshInstance3D", true, false):
			if not (mi as Node).is_queued_for_deletion():
				_add_mesh("props", "sign_%d" % tier, mi, sign.global_transform.affine_inverse() * (mi as MeshInstance3D).global_transform)
		sign.free()
	# every build the hammer makes (Builds.make at 1x), one mesh a part, named b__<id>__<part>__<resource or fin>,
	# so a blueprint can turn each part solid as it's filled; what each part needs goes in GodotBuilds.luau
	var builds_info := {}
	for id in Builds.ORDER:
		var root := Node3D.new()
		holder.add_child(root)
		var parts: Array = Builds.make(id, root, Builds.HOOP_DEFAULT, 1.0)
		var inv := root.global_transform.affine_inverse()
		var info: Array = []
		var groups_at := {}
		var top := 0.3
		for k in parts.size():
			var mi: MeshInstance3D = parts[k].mi
			var res: String = parts[k].res
			_add_mesh("props", "b__%s__%d__%s" % [id, k, res if res != "" else "fin"], mi, inv * mi.global_transform)
			var real: Material = parts[k].real
			var col := (real as StandardMaterial3D).albedo_color if real is StandardMaterial3D else Color(0.6, 0.6, 0.6)
			var a: AABB = (inv * mi.global_transform) * mi.get_aabb()
			var pn := String(mi.get_parent().name)
			info.append({"res": res, "color": col.to_html(false), "arrow": mi.has_meta("arrow"), "at": a.get_center() * S, "size": a.size * S,
				"group": pn if pn != "Model" else ""})
			if pn != "Model" and not groups_at.has(pn):
				groups_at[pn] = (inv * (mi.get_parent() as Node3D).global_transform).origin * S
			top = maxf(top, a.end.y)
		builds_info[id] = {"parts": info, "top": top, "groups": groups_at}
		root.free()
	_write_builds(builds_info)
	# the trophy wall's plaques: empty, and with each trophy's keepsake on it (Trophies._build)
	var tw := Trophies.new()
	holder.add_child(tw)
	for c in tw.get_children():
		c.free()
	var empty := Node3D.new()
	tw.add_child(empty)
	LowPoly.mesh_instance(empty, LowPoly.box(Vector3(0.03, 0.4, 0.4)), LowPoly.mat(Color("6b4a32"), 0.9), Vector3.ZERO)
	LowPoly.mesh_instance(empty, LowPoly.box(Vector3(0.02, 0.1, 0.1)), LowPoly.mat(Color("3b2a22"), 0.9), Vector3(0.02, 0, 0))
	for mi in empty.find_children("*", "MeshInstance3D", true, false):
		_add_mesh("props", "plaque", mi, (mi as MeshInstance3D).transform)
	for e in Trophies.LIST:
		var pl := Node3D.new()
		tw.add_child(pl)
		LowPoly.mesh_instance(pl, LowPoly.box(Vector3(0.03, 0.4, 0.4)), LowPoly.mat(Color("6b4a32"), 0.9), Vector3.ZERO)
		tw.call("_item", pl, e[0])
		for mi in pl.find_children("*", "MeshInstance3D", true, false):
			_add_mesh("props", "trophy_" + String(e[0]), mi, pl.global_transform.affine_inverse() * (mi as MeshInstance3D).global_transform)
	tw.free()
	# what the machines make (Product.setup), in Godot's plank colour: the game tints the wood to the log's
	for kind in ["plank", "dry_plank", "mulch", "copper_bar", "iron_bar", "chair", "table", "lantern", "cabinet", "toy_truck", "battery_cell", "rail", "curved_rail", "oil_barrel", "fuel_can", "plastic", "lawn_chair", "bucket"]:
		var pr := Product.new()
		holder.add_child(pr)
		pr.setup(kind, 1.0, Color("e2c08d") if kind != "copper_bar" else Machines.COPPER)
		for mi in pr.find_children("*", "MeshInstance3D", true, false):
			_add_mesh("props", "product_" + kind, mi, pr.global_transform.affine_inverse() * (mi as MeshInstance3D).global_transform)
		pr.free()
	# an ore chunk of each kind (Ore.setup at its usual size, 0.14 m) and a mine shaft's rim and pit
	for kind in ["stone", "copper", "iron"]:
		var o := Ore.new()
		holder.add_child(o)
		o.setup(kind, 0.14)
		for mi in o.find_children("*", "MeshInstance3D", true, false):
			_add_mesh("props", "ore_" + kind, mi, o.global_transform.affine_inverse() * (mi as MeshInstance3D).global_transform)
		o.free()
	var sh := Shaft.new()
	holder.add_child(sh)
	sh.setup(Vector3.ZERO)
	for mi in sh.find_children("*", "MeshInstance3D", true, false):
		_add_mesh("props", "shaft", mi, sh.global_transform.affine_inverse() * (mi as MeshInstance3D).global_transform)
	sh.free()
	# the land's for-sale sign and a corner stake (Land.rebuild), around their own origins
	var fs := ForSale.new()
	holder.add_child(fs)
	fs.setup(null, "")
	for mi in fs.find_children("*", "MeshInstance3D", true, false):
		_add_mesh("props", "forsale", mi, fs.global_transform.affine_inverse() * (mi as MeshInstance3D).global_transform)
	fs.free()
	var stake := Node3D.new()
	holder.add_child(stake)
	LowPoly.mesh_instance(stake, LowPoly.box(Vector3(0.1, 0.8, 0.1)), LowPoly.mat(Color("a0703c"), 0.9), Vector3(0, 0.4, 0))
	LowPoly.mesh_instance(stake, LowPoly.box(Vector3(0.12, 0.12, 0.12)), LowPoly.mat(Color("d64034"), 0.6), Vector3(0, 0.82, 0))
	for mi in stake.find_children("*", "MeshInstance3D", true, false):
		_add_mesh("props", "stake", mi, (mi as MeshInstance3D).transform)
	stake.free()
	# one smoke puff (Nature.Smoke's blob), for the client's chimney smoke
	var smoke := Nature.Smoke.new()
	holder.add_child(smoke)
	var puff: MeshInstance3D = smoke.get_child(0)
	_add_mesh("props", "puff", puff, Transform3D.IDENTITY)
	smoke.free()
	_marker("props")
	var np := _write("props", out + "/props.glb")

	# ---------------------------------------------------------------- where everything is
	_write_luau(main)
	print("EXPORT world %d, crowns %d, trucks %d, tools %d, props %d mesh groups" % [nw, nc, nt, nl, np])
	get_tree().quit()


# what each top-level node of the world is, and what to call its meshes
func _walk(n: Node, main: Node3D, tree_index: Dictionary) -> void:
	if n is Player or n is CanvasLayer or n is Truck or n is WorldEnvironment or n is DirectionalLight3D or n is CompanySign or n is Land or n is Trophies:
		# (the company sign grows as you earn: it's in props.glb, tier by tier, and the game puts up the right one;
		# the land's for-sale signs and corner stakes depend on what each player owns: props too, drawn by the client)
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
	if n is Cabin or n is Computer:
		kind = "cabin"
	elif n is Rock:
		# each rock on its own (you mine it: it shrinks and crumbles away), and what's in it
		kind = "rock_%d" % rocks.size()
		var rk := n as Rock
		rocks.append({"at": rk.global_position * S, "s": rk.size, "ore": rk.ore, "hidden": rk.hidden, "hp": rk.max_hp})
	elif n is Bush:
		# each bush on its own (shears trim it away), and its look
		kind = "bush_%d" % bushes.size()
		bushes.append({"at": (n as Node3D).global_position * S, "r": float(n.get("_radius")) * S, "color": (n.get("_color") as Color).to_html(false)})
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
		# (the chimney's smoke moves: the Roblox client animates it, so it's not part of the still world)
		if (mi as Node).get_parent() is Nature.Smoke:
			continue
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
	# (a rock's box says which rock it is: mining it away takes its box with it)


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
		# (things that glow - the lamp, lamps on signs - in their own group: the Roblox version makes them Neon)
		var gname := name
		if glb == "world" and _emissive(mi, s):
			gname = "glow"
		_add_tris(glb, gname, mi.mesh, s, xf, mc[0], mc[1])


func _emissive(mi: MeshInstance3D, surface: int) -> bool:
	var mat: Material = mi.material_override
	if mat == null:
		mat = mi.get_surface_override_material(surface)
	if mat == null and mi.mesh != null:
		mat = mi.mesh.surface_get_material(surface)
	return mat is StandardMaterial3D and (mat as StandardMaterial3D).emission_enabled


func _chunk_of(p: Vector3) -> String:
	return "%d_%d" % [int(floor(p.x / CHUNK)) + 3, int(floor(p.z / CHUNK)) + 3]


# The ground: one mesh a chunk, textured. Roblox can't run Godot's terrain shader (soft lighter and darker patches,
# drier areas, grain, pebbles on the dirt), so the shader's colours are baked into a texture per chunk (_bake_ground)
# and the mesh carries UVs onto it: u, v = x, z across the chunk plus a margin.
const GROUND_MARGIN := 2.0
const GROUND_PX := 1024
var ground_chunks := {}           # "X_Z" -> Vector2 (the chunk's corner, metres)


func _ground_uv(p: Vector3, corner: Vector2) -> Vector2:
	var span := CHUNK + GROUND_MARGIN * 2.0
	return Vector2((p.x - corner.x + GROUND_MARGIN) / span, (p.z - corner.y + GROUND_MARGIN) / span)


func _add_terrain(mi: MeshInstance3D) -> void:
	var arr := mi.mesh.surface_get_arrays(0)
	var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var nrm: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
	var xf := mi.global_transform
	for k in range(0, v.size() - 2, 3):
		var center := xf * ((v[k] + v[k + 1] + v[k + 2]) / 3.0)
		var ck := _chunk_of(center)
		var corner := Vector2((floor(center.x / CHUNK)) * CHUNK, (floor(center.z / CHUNK)) * CHUNK)
		ground_chunks[ck] = corner
		var g := _group("world", "ground_" + ck, "ffffff")
		if not g.has("uvs"):
			g["uvs"] = []
		for i in 3:
			var wp := xf * v[k + i]
			(g.verts as Array).append(wp * S)
			(g.norms as Array).append(nrm[k + i])
			(g.uvs as Array).append(_ground_uv(wp, corner))


## Renders each ground chunk from straight above with the terrain's own shader, unlit and at full detail, into
## roblox/images/ground/ground_X_Z.png: exactly the colours Godot paints on the ground.
func _bake_ground(main: Node3D, dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	var code: String = Ground.TERRAIN % Ground.NOISE
	code = code.replace("render_mode diffuse_lambert;", "render_mode unshaded, cull_disabled;")
	code = code.replace("float near = 1.0 - smoothstep(18.0, 55.0, dist);", "float near = 1.0;")
	var sh := Shader.new()
	sh.code = code
	var mat := ShaderMaterial.new()
	mat.shader = sh
	mat.set_shader_parameter("detail", 1.0)
	var terrain: Node = main.get("terrain")
	for c in terrain.get_children():
		if c is MeshInstance3D:
			(c as MeshInstance3D).material_override = mat
			(c as MeshInstance3D).layers = 1 << 19
	var vp := SubViewport.new()
	vp.size = Vector2i(GROUND_PX, GROUND_PX)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.transparent_bg = false
	add_child(vp)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = CHUNK + GROUND_MARGIN * 2.0
	cam.cull_mask = 1 << 19
	cam.near = 1.0
	cam.far = 600.0
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("4f8a35")
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	cam.environment = env
	vp.add_child(cam)
	cam.make_current()
	for ck in ground_chunks.keys():
		var corner: Vector2 = ground_chunks[ck]
		var mid := corner + Vector2(CHUNK, CHUNK) * 0.5
		# image right = +x, image down = +z
		cam.transform = Transform3D(Basis(Vector3(1, 0, 0), Vector3(0, 0, -1), Vector3(0, 1, 0)), Vector3(mid.x, 300.0, mid.y))
		for k in 3:
			await RenderingServer.frame_post_draw
		vp.get_texture().get_image().save_png("%s/ground_%s.png" % [dir, ck])
	print("  ground: %d textures" % ground_chunks.size())
	vp.queue_free()


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
			if g.has("uvs"):
				arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array(g.uvs).slice(start, start + count)
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


## roblox/src/shared/GodotBuilds.luau: Godot's builds (Builds.gd) for the hammer, and their parts in props.glb.
func _write_builds(info: Dictionary) -> void:
	var L := PackedStringArray()
	L.append("--!strict")
	L.append("-- Made by tools/ExportRobloxWorld.gd from Builds.gd. Don't edit by hand: run tools/export_roblox_world.sh.")
	L.append("-- Each build's parts are meshes in props.glb named b__<id>__<part>__<resource or fin>; top, at (a part's box")
	L.append("-- centre) and size are in studs, around the build's origin (at and size give stand-ins until the meshes load).")
	L.append("return {")
	L.append("\torder = { \"%s\" }," % "\", \"".join(Builds.ORDER))
	L.append("\tsizes = { %s }," % ", ".join(Builds.SIZES.map(func(x): return str(x))))
	L.append("\tresName = {")
	for r in Builds.RES_NAME:
		L.append("\t\t%s = \"%s\"," % [r, Builds.RES_NAME[r]])
	L.append("\t},")
	L.append("\tcategories = {")
	for c in Builds.CATEGORIES:
		L.append("\t\t{ name = \"%s\", items = { \"%s\" } }," % [c.name, "\", \"".join(c.items)])
	L.append("\t},")
	L.append("\tbuilds = {")
	for id in Builds.ORDER:
		var b: Dictionary = Builds.BUILDS[id]
		var needs := PackedStringArray()
		for r in b.needs:
			needs.append("%s = %d" % [r, int(b.needs[r])])
		L.append("\t\t%s = { name = \"%s\", needs = { %s }, needsOrder = { \"%s\" }, bp = %s, sell = %s, fixed = %s, machine = %s, top = %.3f, parts = {" % [
			id, b.name, ", ".join(needs), "\", \"".join(b.needs.keys()), ("\"%s\"" % b.bp) if b.has("bp") else "nil", str(b.get("sell", 0.85)),
			str(Builds.fixed(id)), str(Machines.is_machine(id)), float(info[id].top) * S])
		for p in info[id].parts:
			L.append("\t\t\t{ res = \"%s\", color = \"%s\", at = %s, size = %s%s%s }," % [p.res, p.color, _v3(p.at), _v3(p.size), ", arrow = true" if p.arrow else "",
				(", group = \"%s\"" % p.group) if p.group != "" else ""])
		var gs := PackedStringArray()
		for g in info[id].groups:
			gs.append("%s = %s" % [g, _v3(info[id].groups[g])])
		L.append("\t\t}, groups = { %s } }," % ", ".join(gs))
	L.append("\t},")
	L.append("}")
	var f := FileAccess.open(ProjectSettings.globalize_path("res://roblox/src/shared/GodotBuilds.luau"), FileAccess.WRITE)
	f.store_string("\n".join(L) + "\n")


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
	# the bushes (shears snip leaves off them)
	L.append("\tbushes = {")
	for b in bushes:
		L.append("\t\t{ at = %s, r = %.3f, color = \"%s\" }," % [_v3(b.at), b.r, b.color])
	L.append("\t},")
	# the trophy wall in the cabin (each player's own: the client puts up their plaques)
	for c in main.get_children():
		if c is Trophies:
			L.append("\ttrophies = { at = %s }," % _v3((c as Node3D).global_position * S))
	# the rocks you can mine
	L.append("\trocks = {")
	for r in rocks:
		L.append("\t\t{ at = %s, s = %.3f, ore = \"%s\", hidden = \"%s\", hp = %d }," % [_v3(r.at), r.s, r.ore, r.hidden, r.hp])
	L.append("\t},")
	# how rich the ground is in copper, iron and oil (Mining.richness), every 3 m like the heights
	var ostep := 3.0
	var ohalf := 105.0
	var on := int(ohalf * 2.0 / ostep) + 1
	L.append("\tore = { origin = %.1f, step = %.1f, n = %d," % [-ohalf * S, ostep * S, on])
	for kind in ["copper", "iron", "oil"]:
		var row := PackedStringArray()
		for gz in on:
			for gx in on:
				row.append("%.2f" % Mining.richness(kind, -ohalf + gx * ostep, -ohalf + gz * ostep))
		L.append("\t\t%s = { %s }," % [kind, ", ".join(row)])
	L.append("\t},")
	# lights that are part of the world (the lamp in the cabin) and the chimney's smoke
	L.append("\tlights = {")
	for l in main.find_children("*", "OmniLight3D", true, false):
		var ol := l as OmniLight3D
		if ol.is_visible_in_tree() and not ol.get_parent() is Player:
			L.append("\t\t{ at = %s, color = \"%s\", energy = %.2f, range = %.2f }," % [_v3(ol.global_position * S), ol.light_color.to_html(false), ol.light_energy, ol.omni_range * S])
	L.append("\t},")
	for sm in main.find_children("*", "Node3D", true, false):
		if sm is Nature.Smoke:
			L.append("\tsmoke = { at = %s }," % _v3((sm as Node3D).global_position * S))
	for c in main.get_children():
		if c is CompanySign:
			L.append("\tsign = { at = %s, yaw = %.3f }," % [_v3((c as Node3D).global_position * S), (c as Node3D).global_rotation.y])
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
