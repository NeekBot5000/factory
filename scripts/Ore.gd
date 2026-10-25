class_name Ore
extends RigidBody3D
## A chunk knocked off a rock with a pickaxe: plain stone, or stone flecked with copper or iron ore.
## Carry it, sell it in the log truck, or use it to build machines.

const KINDS := {
	"stone": {"name": "Stone", "color": Color("8a8780"), "fleck": Color("a39f95"), "value": 0.4},
	"copper": {"name": "Copper ore", "color": Color("7a746c"), "fleck": Color("d9783a"), "value": 3.0},
	"iron": {"name": "Iron ore", "color": Color("6e6a66"), "fleck": Color("6f80a8"), "value": 6.0},
}

var kind := "stone"
var value := 0.4
var size := 0.14


func setup(p_kind: String, p_size: float = 0.14) -> void:
	kind = p_kind
	size = p_size
	var d: Dictionary = KINDS[kind]
	value = float(d.value) * (size / 0.14)
	collision_layer = 2
	collision_mask = 1 | 2
	mass = clampf(size * 8.0, 0.4, 3.0)
	angular_damp = 0.6
	var pm := PhysicsMaterial.new()
	pm.friction = 0.9
	pm.bounce = 0.05
	physics_material_override = pm
	LowPoly.mesh_instance(self, LowPoly.blob(size, 0.35, randi() % 40), LowPoly.mat(d.color, 1.0), Vector3.ZERO,
		Vector3(randf() * 360.0, randf() * 360.0, 0), Vector3(1.0, randf_range(0.65, 0.9), randf_range(0.8, 1.1)))
	if kind != "stone":
		var fm := LowPoly.mat(d.fleck, 0.4, 0.3)
		for k in 5:
			var dir := Vector3(randf_range(-1, 1), randf_range(-0.6, 0.6), randf_range(-1, 1)).normalized()
			LowPoly.mesh_instance(self, LowPoly.box(Vector3.ONE * size * 0.32), fm, dir * size * 0.78, Vector3(randf() * 90.0, randf() * 90.0, 0))
	var cs := CollisionShape3D.new()
	# boxy, so chunks sit still on a belt instead of rolling
	var sh := BoxShape3D.new()
	sh.size = Vector3(size * 1.9, size * 1.4, size * 1.7)
	cs.shape = sh
	add_child(cs)
	add_to_group("grabbable")
	add_to_group("ores")


func hint_text() -> String:
	return "[E] grab    %s  $%.2f" % [KINDS[kind].name, value]
