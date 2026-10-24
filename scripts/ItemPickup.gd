class_name ItemPickup
extends StaticBody3D
## A delivered item floating out of its box. Look at it and press E to take it.

var item := ""
var _model: Node3D
var _t := 0.0
var _base_y := 0.0
var _ready_to_take := false


func setup(p_item: String) -> void:
	item = p_item
	collision_layer = 2
	collision_mask = 0
	var cs := CollisionShape3D.new()
	var sh := SphereShape3D.new()
	sh.radius = 0.35
	cs.shape = sh
	add_child(cs)
	var pivot := Node3D.new()
	add_child(pivot)
	_model = Tools.build_model(item, pivot)
	_model.position = Vector3(0, -0.25, 0)
	pivot.scale = Vector3.ONE * (2.2 if item == "phone" else 1.4)
	var glow := OmniLight3D.new()
	glow.light_color = Color("ffe08a")
	glow.light_energy = 0.8
	glow.omni_range = 1.6
	add_child(glow)


func rise_from_box(to: Vector3) -> void:
	var tw := create_tween()
	tw.tween_property(self, "global_position", to, 0.8).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func():
		_base_y = global_position.y
		_ready_to_take = true)


func hint_text() -> String:
	return "[E] take"


func on_use(player: Node) -> void:
	take(player)


func take(player: Node) -> void:
	Game.receive(item)
	Sfx.play("equip")
	if Tools.TOOLS.has(item):
		player.call("equip", item)
		Game.toast.emit("%s  [%d]" % [Tools.SHOP[item].name, Tools.TOOL_ORDER.find(item) + 1], Color("7aff9a"))
	else:
		Game.toast.emit("TimberPhone  [Tab]", Color("7aff9a"))
	queue_free()


func _process(delta: float) -> void:
	_t += delta
	_model.get_parent().rotation.y += delta * 1.4
	if _ready_to_take:
		global_position.y = _base_y + sin(_t * 2.0) * 0.05
