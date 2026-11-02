extends Node
## Writes every build (machines, furniture, decorations) and every tool out as a .glb file in roblox/models/, so the
## Roblox version can import the exact same low-poly models (Studio: File > Import 3D).
## Run: godot --headless --path . res://tools/ExportModels.tscn
## Scale: 1 Godot metre should become 3 studs - set the scale in Studio's 3D importer.

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://roblox/models"))
	var n := 0
	for id in Builds.ORDER:
		var root := Node3D.new()
		root.name = id
		add_child(root)
		Builds.make(id, root, Builds.HOOP_DEFAULT, 1.0)
		LowPoly.bake(root.get_node("Model") as Node3D)
		n += _save(root, "build_" + id)
		root.free()
	for id in Tools.TOOL_ORDER:
		var troot := Node3D.new()
		troot.name = id
		add_child(troot)
		Tools.build_model(id, troot)
		n += _save(troot, "tool_" + id)
		troot.free()
	print("EXPORT wrote %d models to roblox/models/" % n)
	get_tree().quit()


func _save(root: Node3D, file: String) -> int:
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	if doc.append_from_scene(root, state) != OK:
		push_warning("could not export " + file)
		return 0
	return 1 if doc.write_to_filesystem(state, ProjectSettings.globalize_path("res://roblox/models/%s.glb" % file)) == OK else 0
