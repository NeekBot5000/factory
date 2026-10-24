class_name Batcher
extends Node3D
## Groups static visuals by (mesh, material) into MultiMeshes so thousands of parts cost a few draw calls.
## Handles are Dictionaries {batch, idx, local} that stay valid across swap-removes.

class Batch:
	var mmi: MultiMeshInstance3D
	var mm: MultiMesh
	var xforms: Array[Transform3D] = []
	var handles: Array = []

	func _init(mesh: Mesh, mat: Material, parent: Node3D) -> void:
		mm = MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = mesh
		mm.instance_count = 0
		mmi = MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = mat
		mmi.custom_aabb = AABB(Vector3(-60, -30, -60), Vector3(120, 80, 120))
		parent.add_child(mmi)

	func add(xf: Transform3D, local: Transform3D) -> Dictionary:
		var h := {"batch": self, "idx": xforms.size(), "local": local}
		xforms.append(xf)
		handles.append(h)
		_sync_added()
		return h

	func _sync_added() -> void:
		var n := xforms.size()
		if n > mm.instance_count:
			var cap := maxi(32, mm.instance_count * 2)
			mm.instance_count = cap
			# buffer was reset by resize: re-upload everything
			for i in n:
				mm.set_instance_transform(i, xforms[i])
		else:
			mm.set_instance_transform(n - 1, xforms[n - 1])
		mm.visible_instance_count = n

	func remove(h: Dictionary) -> void:
		var i: int = h.idx
		var last := xforms.size() - 1
		if i != last:
			xforms[i] = xforms[last]
			var moved: Dictionary = handles[last]
			handles[i] = moved
			moved.idx = i
			mm.set_instance_transform(i, xforms[i])
		xforms.pop_back()
		handles.pop_back()
		mm.visible_instance_count = xforms.size()

	func set_xf(h: Dictionary, xf: Transform3D) -> void:
		xforms[h.idx] = xf
		mm.set_instance_transform(h.idx, xf)


var _batches := {}


func add(mesh: Mesh, mat: Material, xf: Transform3D, local: Transform3D = Transform3D.IDENTITY) -> Dictionary:
	var key := "%d_%d" % [mesh.get_instance_id(), mat.get_instance_id()]
	var b: Batch = _batches.get(key)
	if b == null:
		b = Batch.new(mesh, mat, self)
		_batches[key] = b
	return b.add(xf, local)


func remove(h: Dictionary) -> void:
	(h.batch as Batch).remove(h)


func move(h: Dictionary, parent_xf: Transform3D) -> void:
	(h.batch as Batch).set_xf(h, parent_xf * (h.local as Transform3D))
