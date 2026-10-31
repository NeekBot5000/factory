class_name Sorter
extends Conveyor
## A belt that sends some things off to its left side:
##   sorter   - things that match its sample (hold something and press E to set it; E with empty hands clears it)
##   splitter - every other thing, so one line becomes two

var mode := "sorter"
var filter := ""
var _seen := {}            # body -> whether it goes left
var _flip := false


func activate(p_size: float) -> void:
	super(p_size)
	mode = String(get_meta("build").id) if has_meta("build") else mode
	set_sides_open(false, false)


## Its left side is always open (that's where things leave); the right one opens for turns like any belt.
func set_sides_open(_left: bool, right: bool) -> void:
	super(true, right)


## What sort of thing a body is, for matching against the sample.
static func kind_of(b: Node) -> String:
	if b is Chip:
		return "bark"
	if b is Log:
		return "log"
	if b is Leaf:
		return "leaf"
	if b is Ore:
		return (b as Ore).kind
	if b is Product:
		return (b as Product).kind
	if b is Sapling:
		return "sapling"
	return "?"


func hint_text() -> String:
	if mode == "splitter":
		return "Splitter Belt  ·  every other thing goes off to the left"
	if filter == "":
		return "Sorter Belt  ·  hold something and press [E] to sort that out to the left"
	return "Sorter Belt  ·  sends %s left    [E] with empty hands to clear" % filter.replace("_", " ")


func on_use(player: Node) -> void:
	if mode != "sorter":
		return
	var held: Node = player.get("held")
	if held != null:
		filter = kind_of(held)
		Sfx.play("clink", 1.3, -4.0)
	elif filter != "":
		filter = ""
		Sfx.play("click", 0.7, -4.0)


func _physics_process(delta: float) -> void:
	super(delta)
	if not powered:
		return
	var left := -global_basis.x
	var now := {}
	for b in bodies_in(_center + Vector3(0, 0.25, 0), Vector3(0.9, 0.5, 0.9)):
		var rb := b as RigidBody3D
		if rb == null:
			continue
		var go: bool
		if _seen.has(rb):
			go = _seen[rb]
		elif mode == "splitter":
			go = _flip
			_flip = not _flip
		else:
			go = filter != "" and kind_of(rb) == filter
		now[rb] = go
		if go:
			rb.sleeping = false
			rb.linear_velocity = Vector3(left.x * 1.8, rb.linear_velocity.y, left.z * 1.8)
	_seen = now


func save_state() -> Dictionary:
	return {"filter": filter}


func load_state(d: Dictionary) -> void:
	filter = String(d.get("filter", ""))
