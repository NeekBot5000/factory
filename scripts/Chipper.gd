class_name Chipper
extends Machine
## Feed bark and leaves into the hopper while it's powered: it shreds them and drops out bags of mulch, worth more
## than the loose bits that went in.

const BAG_AT := 4.0

var stock := 0.0
var _color := Color("6b4a32")
var _drum: Node3D


func activate(p_size: float) -> void:
	super(p_size)
	_drum = get_node_or_null("Model/Drum")
	add_lamp(Vector3(0.4, 0.3, 0.4))


func terminal() -> Vector3:
	return Vector3(0.4, 0.45, 0.4) * size


func hint_text() -> String:
	return "Chipper  ·  %d%% of a bag    drop bark or leaves in the hopper" % int(stock / BAG_AT * 100.0)


func _physics_process(delta: float) -> void:
	if not powered:
		return
	if _drum != null:
		_drum.rotation.x += delta * 14.0
	for b in bodies_in(Vector3(0, 1.0, 0), Vector3(0.75, 0.5, 0.75)):
		if not (b is Chip or b is Leaf):
			continue
		stock += Truck.sale_value(b) * 1.6
		_color = (b as Chip).color if b is Chip else Color("5f8a3a")
		Nature.burst(get_parent(), b.global_position, Vector3.UP, _color, 8, 1.5, 0.02, 6.0, 0.4)
		Sfx.play_at("grind", global_position, 1.4, -10.0)
		b.queue_free()
	if stock >= BAG_AT:
		var bag := Product.new()
		get_parent().add_child(bag)
		bag.setup("mulch", snappedf(stock, 0.01), _color)
		bag.global_transform = global_transform * Transform3D(Basis(), Vector3(0, 0.45, -0.75))
		bag.linear_velocity = -global_basis.z * 1.2
		stock = 0.0
		Sfx.play_at("drop", global_position, 0.8, 0.0)


func save_state() -> Dictionary:
	return {"stock": snappedf(stock, 0.01)}


func load_state(d: Dictionary) -> void:
	stock = float(d.get("stock", 0.0))
