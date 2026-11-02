class_name Trophies
extends Node3D
## The trophy wall inside the cabin: a plaque for each milestone, with something on it to remember it by.

const LIST := [
	["first_tree", "your first tree felled"], ["first_machine", "your first machine"], ["thousand", "$1,000 earned"],
	["first_plank", "your first planks"], ["first_iron", "your first iron bar"], ["first_furniture", "your first furniture"],
	["giant", "an ancient giant felled"], ["legend", "the Legendary Tree felled"], ["first_oil", "your first barrel of oil"],
]

static var _wall: Trophies = null


func _ready() -> void:
	_wall = self
	_build()


## Awards a trophy (once). Call from anywhere.
static func award(id: String) -> void:
	if Game.trophies.has(id):
		return
	Game.trophies[id] = true
	for e in LIST:
		if e[0] == id:
			Game.toast.emit("Trophy: %s" % e[1], Color("ffd27a"))
	Sfx.play("reveal", 1.2, -2.0)
	if _wall != null and is_instance_valid(_wall):
		_wall._build()


func _build() -> void:
	for c in get_children():
		c.queue_free()
	for i in LIST.size():
		var id: String = LIST[i][0]
		var at := Vector3(0, 1.75 - (i / 4) * 0.55, -1.2 + (i % 4) * 0.6)
		var plaque := Node3D.new()
		add_child(plaque)
		plaque.position = at
		LowPoly.mesh_instance(plaque, LowPoly.box(Vector3(0.03, 0.4, 0.4)), LowPoly.mat(Color("6b4a32"), 0.9), Vector3.ZERO)
		if not Game.trophies.has(id):
			LowPoly.mesh_instance(plaque, LowPoly.box(Vector3(0.02, 0.1, 0.1)), LowPoly.mat(Color("3b2a22"), 0.9), Vector3(0.02, 0, 0))
			continue
		_item(plaque, id)


func _item(p: Node3D, id: String) -> void:
	var r := Vector3(90, 0, 90)
	match id:
		"first_tree":
			LowPoly.mesh_instance(p, LowPoly.cyl(0.14, 0.14, 0.04, 10), LowPoly.mat(Color("e2c08d"), 0.8), Vector3(0.04, 0, 0), r)
		"first_machine":
			LowPoly.mesh_instance(p, LowPoly.cyl(0.12, 0.12, 0.04, 8), Tools.steel(Machines.COPPER, 0.3), Vector3(0.04, 0, 0), r)
			LowPoly.mesh_instance(p, LowPoly.cyl(0.04, 0.04, 0.05, 6), LowPoly.mat(Color("2b2d33")), Vector3(0.05, 0, 0), r)
		"thousand":
			for k in 3:
				LowPoly.mesh_instance(p, LowPoly.cyl(0.06, 0.06, 0.02, 10), LowPoly.mat(Color("e8b923"), 0.3), Vector3(0.03 + k * 0.022, -0.08 + k * 0.05, 0), r)
		"first_plank":
			LowPoly.mesh_instance(p, LowPoly.box(Vector3(0.03, 0.06, 0.32)), LowPoly.mat(Color("e2c08d"), 0.8), Vector3(0.04, 0, 0))
		"first_iron":
			LowPoly.mesh_instance(p, LowPoly.box(Vector3(0.05, 0.07, 0.24)), Tools.steel(Color("9aa1ab"), 0.3), Vector3(0.05, 0, 0))
		"first_furniture":
			LowPoly.mesh_instance(p, LowPoly.box(Vector3(0.12, 0.02, 0.12)), LowPoly.mat(Color("c69a62")), Vector3(0.08, -0.02, 0))
			LowPoly.mesh_instance(p, LowPoly.box(Vector3(0.02, 0.14, 0.12)), LowPoly.mat(Color("c69a62")), Vector3(0.03, 0.05, 0))
		"giant":
			LowPoly.mesh_instance(p, LowPoly.cyl(0.17, 0.17, 0.05, 12), LowPoly.mat(Color("b5653a"), 0.8), Vector3(0.04, 0, 0), r)
			LowPoly.mesh_instance(p, LowPoly.cyl(0.1, 0.1, 0.052, 12), LowPoly.mat(Color("e2c08d"), 0.8), Vector3(0.04, 0, 0), r)
		"first_oil":
			LowPoly.mesh_instance(p, LowPoly.cyl(0.08, 0.08, 0.2, 10), LowPoly.mat(Color("2f3a48"), 0.5), Vector3(0.1, 0, 0))
		"legend":
			LowPoly.mesh_instance(p, LowPoly.blob(0.14, 0.2, 7), LowPoly.mat(Color("e0a43a"), 0.4, 0.8), Vector3(0.08, 0, 0))
