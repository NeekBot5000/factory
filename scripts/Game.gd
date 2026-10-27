extends Node
## Global state: money, owned tools, orders waiting for delivery, phone. Autosaves.

signal money_changed(money: float)
signal tools_changed
signal orders_changed
signal toast(text: String, color: Color)
signal saved

var save_path := "user://timber_save.json"   # tests point this elsewhere

var money := 0.0
var owned := {"hands": true}
var has_phone := false
var orders: Array = []          # {id, item, status: "processing"|"shipping"|"delivered", t}
var next_order := 1
var total_earned := 0.0
var save_enabled := true
var charges := {}               # consumables left: dynamite sticks
var dropped := {}               # tools lying on the ground (owned, but not in your hands); not saved
var world_builds: Array = []    # things built with the hammer (and plans in progress), as saved data
var world_saver := Callable()   # set by the scene: returns the current world_builds
var world_state := {}           # trees stripped/felled/grown, bushes, loose bark, leaves, logs, saplings, dropped tools
var world_state_saver := Callable()
var quality := 0                # graphics level picked by Quality.gd (0 = full); remembered between sessions
var settings := {"sens": 1.0, "fov": 75.0, "volume": 0.8, "auto_quality": true, "invert": false, "bob": true, "fps": false}   # the Esc menu


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


## In the tool bar: owned and not lying on the ground somewhere.
func in_toolbar(id: String) -> bool:
	return is_owned(id) and not dropped.has(id)


func set_dropped(id: String, on: bool) -> void:
	if on:
		dropped[id] = true
	else:
		dropped.erase(id)
	tools_changed.emit()


func is_ordered(id: String) -> bool:
	for o in orders:
		if o.item == id and o.status != "delivered":
			return true
	return false


func buy(id: String) -> bool:
	var it: Dictionary = Tools.SHOP[id]
	var restock := int(it.get("consumable", 0)) > 0      # boxes of dynamite: buy as many as you like
	if (is_owned(id) and not restock) or is_ordered(id):
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
	var n := int(Tools.SHOP.get(id, {}).get("consumable", 0))
	if n > 0:
		charges[id] = int(charges.get(id, 0)) + n
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
	var f := FileAccess.open(save_path, FileAccess.WRITE)
	if f == null:
		return
	if world_saver.is_valid():
		world_builds = world_saver.call()
	if world_state_saver.is_valid():
		world_state = world_state_saver.call()
	# orders still in transit are refunded into "processing" so they get re-delivered next session
	f.store_string(JSON.stringify({"money": money, "owned": owned.keys(), "phone": has_phone, "orders": orders, "next_order": next_order, "earned": total_earned, "builds": world_builds, "world": world_state, "quality": quality, "settings": settings, "charges": charges}))
	saved.emit()


func load_game() -> void:
	if not save_enabled or not FileAccess.file_exists(save_path):
		return
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	if typeof(d) != TYPE_DICTIONARY:
		return
	money = float(d.get("money", 0.0))
	owned = {"hands": true}
	for k in d.get("owned", []):
		if Tools.TOOLS.has(k) or String(k).begins_with("bp_"):
			owned[k] = true
	has_phone = bool(d.get("phone", false))
	orders = []
	for o in d.get("orders", []):
		if o.status != "delivered":
			o.status = "processing"
		orders.append(o)
	next_order = int(d.get("next_order", 1))
	total_earned = float(d.get("earned", 0.0))
	world_builds = d.get("builds", [])
	world_state = d.get("world", {})
	quality = int(d.get("quality", 0))
	charges = {}
	var ch: Dictionary = d.get("charges", {})
	for k in ch:
		charges[k] = int(ch[k])
	var st: Dictionary = d.get("settings", {})
	for k in settings:
		if st.has(k):
			settings[k] = st[k]


## Clears the in-memory state without touching the save file (tests use this to simulate a restart).
func reset_memory_only() -> void:
	var keep := save_enabled
	save_enabled = false
	reset()
	save_enabled = keep


func reset() -> void:
	dropped = {}
	world_builds = []
	world_state = {}
	money = 0.0
	owned = {"hands": true}
	charges = {}
	has_phone = false
	orders = []
	total_earned = 0.0
	save_game()
