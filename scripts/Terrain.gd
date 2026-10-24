class_name Terrain
extends Node3D
## Floating island made of 5x5 buyable plots, with trees on locked land and a low-poly underside.

var _plots := {}
var _grid_nodes: Array[MeshInstance3D] = []


func build() -> void:
	var r := Defs.PLOT_RADIUS
	for i in range(-r, r + 1):
		for j in range(-r, r + 1):
			_make_plot(Vector2i(i, j))
	_make_underside()
	refresh()


func _make_plot(p: Vector2i) -> void:
	var biome: String = Defs.plot_biome(p)
	var bd: Dictionary = Defs.BIOMES[biome]
	var root := Node3D.new()
	root.position = Vector3(p.x * Defs.PLOT_SIZE, 0, p.y * Defs.PLOT_SIZE)
	add_child(root)
	var shade := 0.0 if (p.x + p.y) % 2 == 0 else 0.05
	var top_c: Color = (bd.top as Color).lightened(shade)
	var top := MeshInstance3D.new()
	top.mesh = Meshes.box_mesh(Vector3(Defs.PLOT_SIZE, 0.5, Defs.PLOT_SIZE))
	top.material_override = Meshes.mat(top_c, 0.0, 1.0)
	top.position.y = -0.25
	root.add_child(top)
	var dirt := MeshInstance3D.new()
	dirt.mesh = Meshes.box_mesh(Vector3(Defs.PLOT_SIZE, 1.1, Defs.PLOT_SIZE))
	dirt.material_override = Meshes.mat(bd.side, 0.0, 1.0)
	dirt.position.y = -1.05
	root.add_child(dirt)
	var sb := StaticBody3D.new()
	sb.collision_layer = 1
	sb.collision_mask = 0
	sb.set_meta("plot", p)
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(Defs.PLOT_SIZE, 1.0, Defs.PLOT_SIZE)
	cs.shape = sh
	cs.position.y = -0.5
	sb.add_child(cs)
	var pm := PhysicsMaterial.new()
	pm.friction = 1.0
	sb.physics_material_override = pm
	root.add_child(sb)
	# grid overlay
	var g := MeshInstance3D.new()
	var pl := PlaneMesh.new()
	pl.size = Vector2(Defs.PLOT_SIZE, Defs.PLOT_SIZE)
	g.mesh = pl
	g.material_override = Meshes.grid_mat()
	g.position.y = 0.015
	g.visible = false
	g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(g)
	_grid_nodes.append(g)
	# decorations while locked
	var specs: Array = []
	_scatter(specs, biome, p)
	var lbl := Label3D.new()
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.no_depth_test = true
	lbl.fixed_size = true
	lbl.pixel_size = 0.0007
	lbl.font_size = 36
	lbl.outline_size = 12
	lbl.position = Vector3(0, 2.6, 0)
	lbl.render_priority = 3
	root.add_child(lbl)
	_plots[p] = {"root": root, "top": top, "dirt": dirt, "specs": specs, "deco_handles": [], "label": lbl, "grid": g, "top_c": top_c, "side_c": bd.side}


func _scatter(deco: Array, biome: String, p: Vector2i) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(p)
	var n := 9
	for i in n:
		var x := rng.randf_range(-3.4, 3.4)
		var z := rng.randf_range(-3.4, 3.4)
		var pos := Vector3(x, 0, z)
		match biome:
			"meadow", "jungle":
				var h := rng.randf_range(0.9, 1.5) * (1.4 if biome == "jungle" else 1.0)
				_add(deco, Meshes.cyl_mesh(0.1, 0.13, h * 0.5, 5), Meshes.mat(Color("7a5230")), pos + Vector3(0, h * 0.25, 0))
				var leaf: Color = Color("3f9e3b") if biome == "meadow" else Color("1f7a3a")
				_add(deco, Meshes.cyl_mesh(0.0, 0.6, h, 6), Meshes.mat(leaf.lightened(rng.randi_range(0, 2) * 0.05)), pos + Vector3(0, h * 0.5 + h * 0.4, 0))
			"snow":
				var h2 := rng.randf_range(1.0, 1.7)
				_add(deco, Meshes.cyl_mesh(0.08, 0.1, 0.4, 5), Meshes.mat(Color("6b5640")), pos + Vector3(0, 0.2, 0))
				_add(deco, Meshes.cyl_mesh(0.0, 0.55, h2, 6), Meshes.mat(Color("dfeeff")), pos + Vector3(0, 0.4 + h2 * 0.5, 0))
			"desert":
				var h3 := rng.randf_range(0.6, 1.3)
				_add(deco, Meshes.box_mesh(Vector3(0.22, h3, 0.22)), Meshes.mat(Color("3f9a52")), pos + Vector3(0, h3 * 0.5, 0))
				_add(deco, Meshes.box_mesh(Vector3(0.4, 0.14, 0.14)), Meshes.mat(Color("3f9a52")), pos + Vector3(0.2, h3 * 0.6, 0))
			"volcano":
				var h4 := rng.randf_range(0.5, 1.4)
				_add(deco, Meshes.cyl_mesh(0.0, 0.45, h4, 5), Meshes.mat(Color("2a2330").lightened(rng.randi_range(0, 2) * 0.04)), pos + Vector3(0, h4 * 0.5, 0))
				if rng.randf() < 0.4:
					_add(deco, Meshes.cyl_mesh(0.12, 0.12, 0.05, 6), Meshes.mat(Color("ff6a2a"), 2.0), pos + Vector3(0.5, 0.03, 0.2))


func _add(specs: Array, mesh: Mesh, m: Material, pos: Vector3) -> void:
	specs.append([mesh, m, pos])


func _set_deco(e: Dictionary, on: bool) -> void:
	var handles: Array = e.deco_handles
	var batcher: Batcher = Game.world.batcher
	if on and handles.is_empty():
		var root: Node3D = e.root
		for sp in e.specs:
			handles.append(batcher.add(sp[0], sp[1], Transform3D(Basis.IDENTITY, root.position + (sp[2] as Vector3))))
	elif not on and not handles.is_empty():
		for h in handles:
			batcher.remove(h)
		handles.clear()


func _make_underside() -> void:
	var half := Defs.PLOT_SIZE * (Defs.PLOT_RADIUS * 2 + 1) * 0.5
	var pyr := MeshInstance3D.new()
	pyr.mesh = Meshes.cyl_mesh(half * sqrt(2.0), 3.5, 18.0, 4)
	pyr.material_override = Meshes.mat(Color("6f5440"), 0.0, 1.0)
	pyr.position = Vector3(0, -1.6 - 9.0, 0)
	pyr.rotation_degrees.y = 45.0
	add_child(pyr)
	var rock := MeshInstance3D.new()
	rock.mesh = Meshes.cyl_mesh(half * 0.78, 1.2, 24.0, 7)
	rock.material_override = Meshes.mat(Color("57443a"), 0.0, 1.0)
	rock.position = Vector3(0, -1.6 - 12.0, 0)
	add_child(rock)
	for i in 7:
		var a := i / 7.0 * TAU
		var m := MeshInstance3D.new()
		m.mesh = Meshes.cyl_mesh(2.0, 0.0, 7.0 + (i % 3) * 3.0, 5)
		m.material_override = Meshes.mat(Color("4e3c33"), 0.0, 1.0)
		m.position = Vector3(cos(a) * half * 0.55, -9.0 - (i % 3) * 2.0, sin(a) * half * 0.55)
		add_child(m)


func refresh() -> void:
	var cost := Game.plot_cost()
	for p in _plots:
		var e: Dictionary = _plots[p]
		var owned := Game.plots.has(p)
		_set_deco(e, not owned)
		var top_m: MeshInstance3D = e.top
		var dirt_m: MeshInstance3D = e.dirt
		var lbl: Label3D = e.label
		if owned:
			top_m.material_override = Meshes.mat(e.top_c, 0.0, 1.0)
			dirt_m.material_override = Meshes.mat(e.side_c, 0.0, 1.0)
			lbl.visible = false
		else:
			var dim := 0.55
			top_m.material_override = Meshes.mat((e.top_c as Color).darkened(1.0 - dim), 0.0, 1.0)
			dirt_m.material_override = Meshes.mat((e.side_c as Color).darkened(1.0 - dim), 0.0, 1.0)
			lbl.visible = true
			var bname: String = Defs.BIOMES[Defs.plot_biome(p)].name
			if Game.can_buy_plot(p):
				lbl.text = "%s\nLAND %s" % [bname, Util.money(cost)]
				lbl.modulate = Color("7aff9a") if Game.can_afford(cost) else Color("ffd27a")
			else:
				lbl.text = "%s\n(locked)" % bname
				lbl.modulate = Color(1, 1, 1, 0.45)


func set_grid_visible(v: bool) -> void:
	for p in _plots:
		var e: Dictionary = _plots[p]
		(e.grid as MeshInstance3D).visible = v and Game.plots.has(p)
