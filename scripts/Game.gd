extends Node
## Global state: money, owned tools, orders waiting for delivery, phone. Autosaves.

signal money_changed(money: float)
signal tools_changed
signal orders_changed
signal toast(text: String, color: Color)

const SAVE_PATH := "user://timber_save.json"

var money := 0.0
var owned := {"hands": true}
var has_phone := false
var orders: Array = []          # {id, item, status: "processing"|"shipping"|"delivered", t}
var next_order := 1
var total_earned := 0.0
var save_enabled := true


func _ready() -> void:
	load_game()


func add_money(v: float) -> void:
	money += v
	total_earned += maxf(v, 0.0)
	money_changed.emit(money)
	save_game()


func can_afford(v: float) -> bool:
	return money + 0.001 >= v


func is_owned(id: String) -> bool:
	if id == "phone":
		return has_phone
	return owned.has(id)


func is_ordered(id: String) -> bool:
	for o in orders:
		if o.item == id and o.status != "delivered":
			return true
	return false


func buy(id: String) -> bool:
	var it: Dictionary = Tools.SHOP[id]
	if is_owned(id) or is_ordered(id):
		return false
	if not can_afford(float(it.price)):
		toast.emit("Not enough money", Color("ff7a7a"))
		return false
	money -= float(it.price)
	money_changed.emit(money)
	orders.append({"id": next_order, "item": id, "status": "processing", "t": 0.0})
	next_order += 1
	orders_changed.emit()
	toast.emit("Ordered %s" % it.name, Color("8fd0ff"))
	save_game()
	return true


func receive(id: String) -> void:
	if id == "phone":
		has_phone = true
	else:
		owned[id] = true
	for o in orders:
		if o.item == id and o.status != "delivered":
			o.status = "delivered"
	orders_changed.emit()
	tools_changed.emit()
	save_game()


func pending_orders() -> Array:
	return orders.filter(func(o): return o.status == "processing")


func save_game() -> void:
	if not save_enabled:
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		return
	# orders still in transit are refunded into "processing" so they get re-delivered next session
	f.store_string(JSON.stringify({"money": money, "owned": owned.keys(), "phone": has_phone, "orders": orders, "next_order": next_order, "earned": total_earned}))


func load_game() -> void:
	if not save_enabled or not FileAccess.file_exists(SAVE_PATH):
		return
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if typeof(d) != TYPE_DICTIONARY:
		return
	money = float(d.get("money", 0.0))
	owned = {"hands": true}
	for k in d.get("owned", []):
		if Tools.TOOLS.has(k):
			owned[k] = true
	has_phone = bool(d.get("phone", false))
	orders = []
	for o in d.get("orders", []):
		if o.status != "delivered":
			o.status = "processing"
		orders.append(o)
	next_order = int(d.get("next_order", 1))
	total_earned = float(d.get("earned", 0.0))


func reset() -> void:
	money = 0.0
	owned = {"hands": true}
	has_phone = false
	orders = []
	total_earned = 0.0
	save_game()
