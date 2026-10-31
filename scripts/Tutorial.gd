class_name Tutorial
extends PanelContainer
## The starting tutorial (new games only): a small panel in the corner, one step at a time, from taking the
## hatchet to selling your first decoration. After that you're on your own.

const STEPS := [
	"Take the hatchet from the chopping block in front of the cabin: look at it and press E.",
	"Swing at a tree (left click) to peel off its bark. Peel off a few pieces.",
	"Pick the bark up (E), carry it to the green truck and drop it in the back (E again).",
	"Look at the truck and press E to send it to the mill. You're paid when it gets there.",
	"Keep at it until you have $120 for a Builder's Hammer.",
	"Go into the cabin, use the computer (E) and buy the Builder's Hammer from TimberMart.",
	"The delivery van brings it to the dock. Open the box with E to get your hammer.",
	"Click with the hammer to open the build menu, pick the Bark Wreath, place it, then drop 12 bark into the hologram.",
	"Decorations sell for much more than they cost. Look at your wreath with the hammer and press X to sell it.",
]

var main: Node
var player: Player
var _label: Label
var _count: Label
var _t := 0.0
static var sold_decoration := false


func setup(p_main: Node, p_player: Player, body: Font, bold: Font) -> void:
	main = p_main
	player = p_player
	anchor_left = 0.0
	anchor_top = 0.0
	offset_left = 20
	offset_top = 20
	offset_right = 400
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.09, 0.12, 0.78)
	sb.set_corner_radius_all(12)
	for side in ["left", "right", "top", "bottom"]:
		sb.set("content_margin_" + side, 14)
	add_theme_stylebox_override("panel", sb)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	add_child(v)
	_count = Label.new()
	_count.add_theme_font_override("font", bold)
	_count.add_theme_font_size_override("font_size", 13)
	_count.add_theme_color_override("font_color", Color("ffcf6a"))
	v.add_child(_count)
	_label = Label.new()
	_label.add_theme_font_override("font", body)
	_label.add_theme_font_size_override("font_size", 16)
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.custom_minimum_size.x = 360
	v.add_child(_label)
	_show()


func _show() -> void:
	var i := Game.tutorial
	_count.text = "Getting started  ·  %d of %d" % [i + 1, STEPS.size()]
	var t: String = STEPS[i]
	if i == 4:
		t += "  ($%d / $120)" % int(Game.money)
	_label.text = t


## Is step `i` done?
func _done(i: int) -> bool:
	match i:
		0: return Game.in_toolbar("hatchet")
		1: return player.pieces_stripped >= 6
		2: return main.ship_truck.load_value() > 0.0 or Game.total_earned > 0.0
		3: return Game.total_earned > 0.0
		4: return Game.money >= 120.0 or Game.is_owned("hammer") or Game.is_ordered("hammer")
		5: return Game.is_ordered("hammer") or Game.is_owned("hammer")
		6: return Game.is_owned("hammer")
		7:
			for b in get_tree().get_nodes_in_group("builds"):
				if (b as Node).has_meta("build") and String((b as Node).get_meta("build").id) == "bark_wreath":
					return true
			return sold_decoration
		8: return sold_decoration
	return true


func _process(delta: float) -> void:
	visible = main.shop_ui == null
	_t -= delta
	if _t > 0.0:
		return
	_t = 0.3
	if Game.tutorial < 0:
		queue_free()
		return
	var moved := false
	while Game.tutorial >= 0 and Game.tutorial < STEPS.size() and _done(Game.tutorial):
		Game.tutorial += 1
		moved = true
	if Game.tutorial >= STEPS.size():
		Game.tutorial = -1
		Game.toast.emit("That's the basics. The rest is yours to find out!", Color("7aff9a"))
		Sfx.play("reveal")
		Game.save_game()
		queue_free()
		return
	if moved:
		Sfx.play("pickup", 1.4, -6.0)
		Game.save_game()
	_show()
