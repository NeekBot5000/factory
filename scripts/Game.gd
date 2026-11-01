extends Node
## Global state: money, owned tools, orders waiting for delivery, phone. Autosaves.

signal money_changed(money: float)
signal tools_changed
signal orders_changed
signal toast(text: String, color: Color)
signal saved
signal vehicle_bought

var save_path := "user://timber_save.json"   # tests point this elsewhere

var money := 0.0
var owned := {"hands": true}
var has_phone := false
var orders: Array = []          # {id, item, status: "processing"|"shipping"|"delivered", t}
var next_order := 1
var total_earned := 0.0
var save_enabled := true
var skip_title := false         # New Game reloads the scene: go straight into the game this once (not saved)
var land: Array = ["-1,-1", "-1,0", "0,-1", "0,0"]     # plots of land you own (Land.gd)
var tutorial := 0               # starting tutorial step (-1 = finished, or an old save from before it existed)
var trophies := {}              # milestones on the cabin's trophy wall
var charges := {}               # consumables left: dynamite sticks
var dropped := {}               # tools lying on the ground (owned, but not in your hands); not saved
var world_builds: Array = []    # things built with the hammer (and plans in progress), as saved data
var world_saver := Callable()   # set by the scene: returns the current world_builds
var world_state := {}           # trees stripped/felled/grown, bushes, loose bark, leaves, logs, saplings, dropped tools
var world_state_saver := Callable()
var quality := 0                # graphics level picked by Quality.gd (0 = full); remembered between sessions
var settings := {"sens": 1.0, "fov": 75.0, "volume": 0.8, "auto_quality": true, "invert": false, "bob": true, "fps": false, "music": 0.5, "fullscreen": false}   # the Esc menu


func _ready() -> void:
	load_game()


func add_money(v: float) -> void:
	money += v
	total_earned += maxf(v, 0.0)
	if total_earned >= 1000.0:
		Trophies.award("thousand")
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
	if it.has("vehicle"):
		# trucks don't come in a box: the old one drives off and the new one drives in
		money -= float(it.price)
		money_changed.emit(money)
		owned[id] = true
		toast.emit("Bought the %s" % it.name, Color("8fd0ff"))
		tools_changed.emit()
		vehicle_bought.emit()
		save_game()
		return true
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


## Which truck you have: 0 the starting log truck, 1 the big truck, 2 the log hauler.
func truck_level() -> int:
	return 2 if owned.has("truck_hauler") else (1 if owned.has("truck_big") else 0)


## Nothing done yet: no money ever earned, nothing bought, nothing changed in the world.
func is_fresh() -> bool:
	return total_earned <= 0.0 and owned.size() <= 1 and orders.is_empty() and world_builds.is_empty() and world_state.is_empty()


func pending_orders() -> Array:
	return orders.filter(func(o): return o.status == "processing")


func save_game() -> void:
	if not save_enabled:
		return
	if world_saver.is_valid():
		world_builds = world_saver.call()
	if world_state_saver.is_valid():
		world_state = world_state_saver.call()
	# orders still in transit are refunded into "processing" so they get re-delivered next session
	var text := JSON.stringify({"money": money, "owned": owned.keys(), "phone": has_phone, "orders": orders, "next_order": next_order, "earned": total_earned, "builds": world_builds, "world": world_state, "quality": quality, "settings": settings, "charges": charges, "land": land, "trophies": trophies, "tutorial": tutorial})
	# write the new save beside the old one, keep the old one as a backup, then swap: a save cut off half way
	# (the tab closed, the power went) can never cost you your world
	var tmp := save_path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(text)
	f.close()
	var abs := ProjectSettings.globalize_path(save_path)
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(abs + ".bak")
		DirAccess.rename_absolute(abs, abs + ".bak")
	if DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp), abs) != OK:
		# a file system that can't rename: just write it in place
		var f2 := FileAccess.open(save_path, FileAccess.WRITE)
		if f2 != null:
			f2.store_string(text)
	saved.emit()


## Reads a save file: the dictionary in it, or null if it's missing or broken.
static func _read_save(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var j := JSON.new()
	if j.parse(FileAccess.get_file_as_string(path)) != OK:
		return null
	return j.data if typeof(j.data) == TYPE_DICTIONARY else null


## A value from the save if it's the right kind of thing, else the default (old or damaged saves still load).
static func _val(d: Dictionary, k: String, def: Variant) -> Variant:
	var v: Variant = d.get(k, def)
	if typeof(v) == typeof(def):
		return v
	if typeof(def) == TYPE_FLOAT and typeof(v) == TYPE_INT:
		return float(v)
	if typeof(def) == TYPE_INT and typeof(v) == TYPE_FLOAT:
		return int(v)
	return def


func load_game() -> void:
	if not save_enabled:
		return
	var d: Variant = _read_save(save_path)
	if d == null:
		# the save is broken (or gone): fall back to the one before it
		d = _read_save(save_path + ".bak")
		if d == null:
			return
	money = _val(d, "money", 0.0)
	owned = {"hands": true}
	for k in _val(d, "owned", []):
		if typeof(k) == TYPE_STRING and (Tools.TOOLS.has(k) or String(k).begins_with("bp_") or Tools.SHOP.has(k)):
			owned[k] = true
	has_phone = _val(d, "phone", false)
	orders = []
	for o in _val(d, "orders", []):
		if typeof(o) != TYPE_DICTIONARY or not o.has("item") or not Tools.SHOP.has(String(o.item)):
			continue
		if o.get("status", "") != "delivered":
			o.status = "processing"
		orders.append(o)
	next_order = _val(d, "next_order", 1)
	total_earned = _val(d, "earned", 0.0)
	world_builds = _val(d, "builds", [])
	world_state = _val(d, "world", {})
	quality = clampi(_val(d, "quality", 0), 0, 3)
	land = ["-1,-1", "-1,0", "0,-1", "0,0"]
	for k in _val(d, "land", []):
		if not land.has(String(k)):
			land.append(String(k))
	trophies = _val(d, "trophies", {})
	tutorial = _val(d, "tutorial", -1)
	charges = {}
	var ch: Dictionary = _val(d, "charges", {})
	for k in ch:
		charges[k] = int(ch[k]) if typeof(ch[k]) in [TYPE_INT, TYPE_FLOAT] else 0
	var st: Dictionary = _val(d, "settings", {})
	for k in settings:
		if st.has(k) and typeof(st[k]) in [TYPE_INT, TYPE_FLOAT, TYPE_BOOL]:
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
	land = ["-1,-1", "-1,0", "0,-1", "0,0"]
	trophies = {}
	tutorial = 0
	has_phone = false
	orders = []
	total_earned = 0.0
	# forget the scene's savers first, or saving would read the old world straight back in
	world_saver = Callable()
	world_state_saver = Callable()
	save_game()
