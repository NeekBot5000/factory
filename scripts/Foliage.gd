class_name Foliage
extends StaticBody3D
## Makes a tree crown snippable: one sphere per leaf blob, on its own layer that only tool rays look at.
## Every snip with the shears tears a clump of leaves off; the blob shrinks and is gone after enough snips.

const LAYER := 32

var _blob_of := {}      # CollisionShape3D -> MeshInstance3D
var _hp := {}           # MeshInstance3D -> snips left
var _cs_list: Array[CollisionShape3D] = []   # every blob in build order, for the save file
var _left: Array[int] = []                   # snips left per blob (0 = gone), same order
var _full: Array[int] = []


func setup(crown: Node3D) -> void:
	collision_layer = LAYER
	collision_mask = 0
	for c in crown.get_children():
		var mi := c as MeshInstance3D
		if mi == null:
			continue
		var aabb := mi.get_aabb()
		var r := aabb.size.length() * 0.35 * mi.scale.x
		var cs := CollisionShape3D.new()
		var sh := SphereShape3D.new()
		sh.radius = maxf(r, 0.4)
		cs.shape = sh
		cs.position = mi.position + mi.basis * aabb.get_center()
		add_child(cs)
		_blob_of[cs] = mi
		_hp[mi] = int(clampf(r * 7.0, 4.0, 16.0))
		_cs_list.append(cs)
		_left.append(int(_hp[mi]))
		_full.append(int(_hp[mi]))


static func blob_color(mi: MeshInstance3D) -> Color:
	var m := mi.material_override
	if m is ShaderMaterial:
		return (m as ShaderMaterial).get_shader_parameter("albedo")
	if m is StandardMaterial3D:
		return (m as StandardMaterial3D).albedo_color
	return Color("4f9a3c")


## Snips the blob owning `shape_idx` (from a ray hit). Spawns the leaf clump(s) into `world`.
func snip(shape_idx: int, at: Vector3, out_dir: Vector3, world: Node) -> bool:
	var owner_id := shape_find_owner(shape_idx)
	var cs := shape_owner_get_owner(owner_id) as CollisionShape3D
	if cs == null or not _blob_of.has(cs):
		return false
	var mi: MeshInstance3D = _blob_of[cs]
	var col := blob_color(mi)
	for k in randi_range(2, 3):
		var lf := Leaf.new()
		world.add_child(lf)
		lf.setup(col, randf_range(0.12, 0.2))
		lf.global_position = at + Vector3(randf_range(-0.15, 0.15), randf_range(-0.1, 0.1), randf_range(-0.15, 0.15))
		lf.linear_velocity = out_dir * randf_range(0.5, 1.5) + Vector3(randf_range(-0.5, 0.5), 0.3, randf_range(-0.5, 0.5))
		lf.angular_velocity = Vector3(randf_range(-3, 3), randf_range(-3, 3), randf_range(-3, 3))
	Nature.burst(world, at, out_dir, col, 8, 1.2, 0.04, 3.0, 0.9, 80.0)
	_hp[mi] = int(_hp[mi]) - 1
	_left[_cs_list.find(cs)] = maxi(0, int(_hp[mi]))
	mi.scale *= 0.9
	(cs.shape as SphereShape3D).radius *= 0.9
	if int(_hp[mi]) <= 0:
		Nature.burst(world, mi.global_position, Vector3.UP, col, 20, 1.6, 0.1, 3.0, 1.4, 140.0)
		_blob_of.erase(cs)
		_hp.erase(mi)
		mi.queue_free()
		cs.queue_free()
		if _blob_of.is_empty():
			# the very last clump always holds a sapling or two, so a tree can always be replaced
			var tree_kind := "oak"
			var crown_owner := get_parent().get_parent()
			if crown_owner is ForestTree:
				tree_kind = (crown_owner as ForestTree).kind
			elif crown_owner is Log:
				tree_kind = (crown_owner as Log).kind
			for k in randi_range(1, 2):
				var sp := Sapling.new()
				world.add_child(sp)
				sp.setup(tree_kind)
				sp.global_position = at + Vector3(randf_range(-0.2, 0.2), 0.1, randf_range(-0.2, 0.2))
				sp.linear_velocity = out_dir * 1.0 + Vector3.UP * 1.5
			Sfx.play("reveal", 1.3, -6.0)
			get_parent().queue_free()      # the crown is bare
	return true


func untouched() -> bool:
	return _left == _full


## Snips left on each blob, for the save file.
func state() -> Array:
	return _left.duplicate()


## Puts a saved crown back: shrinks the snipped blobs and removes the gone ones (no saplings this time).
func apply_state(st: Array) -> void:
	for i in mini(st.size(), _cs_list.size()):
		var v := int(st[i])
		if v >= _left[i]:
			continue
		var cs := _cs_list[i]
		var mi: MeshInstance3D = _blob_of[cs]
		if v <= 0:
			_blob_of.erase(cs)
			_hp.erase(mi)
			mi.queue_free()
			cs.queue_free()
		else:
			var k := pow(0.9, _left[i] - v)
			mi.scale *= k
			(cs.shape as SphereShape3D).radius *= k
			_hp[mi] = v
		_left[i] = maxi(0, v)
	if _blob_of.is_empty():
		get_parent().queue_free()
