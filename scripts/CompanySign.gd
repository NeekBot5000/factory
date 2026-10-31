class_name CompanySign
extends Node3D
## Your company's sign by the road. It starts as a scrap of board on a stake and gets bigger and grander as your
## business earns more - no words, just your axe-and-tree emblem.

const TIERS := [0.0, 500.0, 2500.0, 10000.0, 50000.0, 200000.0]

var tier := -1
var _t := 0.0


func _process(delta: float) -> void:
	_t -= delta
	if _t > 0.0:
		return
	_t = 2.0
	var want := 0
	for i in TIERS.size():
		if Game.total_earned >= float(TIERS[i]):
			want = i
	if want != tier:
		var grew := tier >= 0
		tier = want
		_build()
		if grew:
			Game.toast.emit("Your company sign got an upgrade", Color("ffd27a"))
			Sfx.play_at("reveal", global_position, 1.0, 0.0)


func _build() -> void:
	for c in get_children():
		c.queue_free()
	var wood := LowPoly.mat(Color("a0703c"), 0.9)
	var dark := LowPoly.mat(Color("6b4a32"), 0.9)
	var w := [0.6, 1.0, 1.4, 1.6, 1.9, 2.2][tier] as float
	var h := [0.4, 0.6, 0.8, 0.9, 1.0, 1.1][tier] as float
	var y := 1.0 + h * 0.5
	if tier >= 4:
		LowPoly.mesh_instance(self, LowPoly.box(Vector3(w + 0.4, 0.5, 0.5)), LowPoly.mat(Color("8a8780"), 1.0), Vector3(0, 0.25, 0))
	for sx in ([0.0] if tier == 0 else [-w * 0.45, w * 0.45]):
		LowPoly.mesh_instance(self, LowPoly.box(Vector3(0.12, y + h * 0.5, 0.12)), dark, Vector3(sx, (y + h * 0.5) * 0.5, 0))
	LowPoly.mesh_instance(self, LowPoly.box(Vector3(w, h, 0.08)), wood if tier < 3 else LowPoly.mat(Color("c69a62"), 0.8), Vector3(0, y, 0))
	if tier >= 1:
		# the emblem: a little tree and a crossed axe
		var green := LowPoly.mat(Color("3f7d4a"), 0.8)
		LowPoly.mesh_instance(self, LowPoly.box(Vector3(0.06, h * 0.5, 0.02)), dark, Vector3(-w * 0.15, y - h * 0.1, 0.05))
		LowPoly.mesh_instance(self, LowPoly.cyl(0.0, h * 0.3, h * 0.45, 6), green, Vector3(-w * 0.15, y + h * 0.15, 0.05), Vector3(0, 0, 0))
		LowPoly.mesh_instance(self, LowPoly.box(Vector3(0.04, h * 0.6, 0.02)), dark, Vector3(w * 0.15, y, 0.05), Vector3(0, 0, 35))
		LowPoly.mesh_instance(self, LowPoly.box(Vector3(0.12, 0.1, 0.02)), LowPoly.mat(Color("c9ced6"), 0.3), Vector3(w * 0.15 + h * 0.15, y + h * 0.22, 0.06), Vector3(0, 0, 35))
	if tier >= 2:
		var trim := LowPoly.mat(Color("d4a52a") if tier >= 5 else (Machines.COPPER if tier >= 4 else Color("6b4a32")), 0.4)
		LowPoly.mesh_instance(self, LowPoly.box(Vector3(w + 0.1, 0.06, 0.1)), trim, Vector3(0, y + h * 0.5, 0))
		LowPoly.mesh_instance(self, LowPoly.box(Vector3(w + 0.1, 0.06, 0.1)), trim, Vector3(0, y - h * 0.5, 0))
	if tier >= 3:
		for sx in [-w * 0.45, w * 0.45]:
			var lamp := StandardMaterial3D.new()
			lamp.albedo_color = Color("ffe2a8")
			lamp.emission_enabled = true
			lamp.emission = Color("ffcf8a")
			lamp.emission_energy_multiplier = 2.0
			LowPoly.mesh_instance(self, LowPoly.box(Vector3(0.14, 0.14, 0.14)), lamp, Vector3(sx, y + h * 0.5 + 0.15, 0))
	if tier >= 5:
		LowPoly.mesh_instance(self, LowPoly.cyl(0.03, 0.03, 1.2, 6), dark, Vector3(w * 0.45, y + h + 0.4, 0))
		LowPoly.mesh_instance(self, LowPoly.box(Vector3(0.02, 0.3, 0.5)), LowPoly.mat(Color("d64034"), 0.6), Vector3(w * 0.45, y + h + 0.85, -0.25))
