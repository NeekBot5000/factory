class_name Guide
extends Control
## The field guide: how each part of the game works, one topic at a time. Opens from the pause menu (Esc).
## It explains what things do; working out what to build with them is still up to you.

signal closed

const BG := Color(0.08, 0.09, 0.12, 1.0)
const ACCENT := Color("ffcf6a")

const TOPICS := [
	["Getting started", """You start with bare hands, a cabin and a forest.

[b]Bark[/b] - swing at a tree (left click) to peel off a sheet of bark. The dark outer bark comes first, then the orange inner bark, then the pale wood. Better tools peel bigger sheets.

[b]Carrying[/b] - there's no inventory: look at something and press [b]E[/b] to pick it up, [b]E[/b] again to drop it. Hold [b]R[/b] to tip out what you're holding.

[b]Selling[/b] - drop things into the back of the green truck, look at the truck and press [b]E[/b] to send it to the mill. You're paid when it gets there.

[b]Buying[/b] - use the computer in the cabin. A van delivers your order to the dock in a box: click the box to open it."""],
	["Controls", """[b]Mouse[/b] - look around. Click the game to capture the mouse.
[b]W A S D[/b] - walk. [b]Shift[/b] runs, [b]Space[/b] jumps.
[b]Left click[/b] - use your tool: chop, saw, mine, build, connect wires. Hold it for saws, drills and vacuums.
[b]E[/b] or [b]right click[/b] - pick up, drop, or use what you're looking at.
[b]R[/b] - turn the build you're placing or a laid rail; hold it to tip out what you're holding.
[b]X[/b] with the hammer - take a build down (you get its value back).
[b]Q[/b] - put your tool down.
[b]1-9[/b] or the [b]mouse wheel[/b] - switch tools (Shift + 1-9 for tools 10-18).
[b]Tab[/b] - the phone, once you've bought one.
[b]F11[/b] - fullscreen.  [b]Esc[/b] - pause, settings and this guide.

Keys go by where they are on the keyboard, so on AZERTY or QWERTZ keyboards it's the same keys in the same place."""],
	["Tools", """Switch tools with [b]1-9[/b] (Shift for 10-18) or the mouse wheel. [b]Q[/b] puts the tool in your hand down.

[b]Axes[/b] peel bark. Each one is different: some hit twice, some take a whole ring, some only take one layer.
[b]Saws[/b] fell standing trees (hold on the trunk) and cut logs into shorter pieces.
[b]Pickaxes and drills[/b] break rocks and dig down into the ground.
[b]The vacuum and blower[/b] move piles of loose bits.
[b]The hammer[/b] builds things (see Building).
[b]The wire spool[/b] connects machines (see Power).

The [b]scale[/b] tells you what something weighs and is worth. The [b]ore detector[/b] shows how rich the ground under you is."""],
	["Building", """Click with the [b]hammer[/b] to open the build menu and pick something. A hologram follows your aim: [b]R[/b] turns it, the mouse wheel resizes it (anything but machines), click to place it.

The placed plan shows what it needs. Drop the materials into it - bark, logs, leaves, stone, ore, planks or bars - and it builds itself.

[b]Hammer + X[/b] takes a build down and pays you what it's worth.

[b]Decorations[/b] sell for far more than their materials, so they're a good way to turn raw stuff into money.

Machines need a [b]blueprint[/b] from the shop first, and they sit on a 1 m grid so belts line up. You can only build on [b]land you own[/b]."""],
	["Power and wires", """Machines need power. It starts at a [b]source[/b] and flows along [b]wires[/b] to everything connected.

[b]Sources[/b]: the hand crank (wind it with E), the windmill (when there's wind), the generator (burns bark, leaves and wood) and the battery (charges while there's power, takes over when it goes).

[b]Wires[/b]: hold the wire spool, click one machine, then another. Click the same pair again to take the wire down. Every machine has a [b]power socket[/b] where the plug goes.

[b]Battery cells[/b] fit the same socket: drop a charged cell on it and it clicks in. It powers that machine and everything wired to it, and recharges when other power is about. Grab it to take it out.

[b]Switches[/b] (lever, button, sensors) only let power through while they're on. Conveyor belts that touch pass power along to each other."""],
	["Logic blocks", """Logic blocks have a direction: the arrow on top points to the [b]front[/b]. Which side a wire counts as depends on where the other machine stands.

[b]One-Way[/b] - power in the back, out the front, never the other way.
[b]Relay[/b] - back to front, but only while a side is powered.
[b]Inverting Relay[/b] - back to front only while no side is powered.
[b]Timer[/b] - pulses out the front while the back is powered (E: how often).
[b]Delay[/b] - lets power out once the back has been on for a while (E: how long).
[b]Toggle Latch[/b] - each pulse at the back flips it on or off; while on, side power goes out the front.
[b]Counter[/b] - every N pulses at the back, side power goes out the front for a moment (E: N).

[b]Sensors[/b]: the pressure plate (something standing on it), the item sensor (something in front of it), the level sensor (the crate in front holds enough; E sets how many) and the cart sensor (a cart is on the rail in front)."""],
	["Making things", """Raw stuff is worth more once you've worked it.

[b]Sawmill[/b] - a log on its table becomes planks.
[b]Kiln[/b] - dries planks: worth more.
[b]Chipper[/b] - bark and leaves become bags of mulch.
[b]Smelter[/b] - copper and iron ore become metal bars.
[b]Assembler[/b] - planks and bars become furniture that sells for much more, plus battery cells and rails. E picks what it makes.

Most machines take things in through a hopper on top and push the result out of their front, so belts and grabber arms can feed them."""],
	["Moving things", """[b]Conveyor belts[/b] carry anything along; ramps go up a level. The arrows show which way they run.
[b]Sorter belts[/b] send one kind of thing off to the side (hold it and press E to choose). [b]Splitter belts[/b] send every other thing to the side.
[b]Grabber arms[/b] pick up what's in front of them and put it behind.
[b]Pistons[/b] push; [b]rotators[/b] spin what's stuck to them (hammer it on).
[b]Storage crates[/b] hold a pile of things; power one and it empties out of its door.
[b]Transmitters and receivers[/b] send power without wires: a powered transmitter turns on every receiver on the same channel (E changes channel), however far away.
The [b]truck caller[/b] sends the truck off when it gets power."""],
	["Trees and farming", """Felled trees leave a stump; saplings grow into new trees.

Drop saplings into a [b]planter[/b] and power it: it plants them in a row.
A powered [b]sprinkler[/b] makes saplings nearby grow twice as fast (so does the watering can).
A [b]tree feller[/b] with your saw in it cuts down the tree in front of it.

Bigger farms need more room: buy the plots of land next to yours at their for-sale signs."""],
	["Mining", """Copper and iron are underground. The deeper you dig, the more there is: copper from about 1.5 m down, iron from about 5 m (and you need a steel pick or core drill to get it out).

Hit the ground with a pickaxe or drill to dig a shaft. The [b]ore detector[/b] shows where the ground is rich.

A [b]drill rig[/b] with your drill in it drills straight down by itself and drops what it digs out of its chute - onto a belt or into a crate. Each spot only goes so deep, then it's [b]drilled out[/b]: while drilled out, the rig lets power through to whatever is wired to it, so you can use it as a signal."""],
	["Rails and carts", """[b]Rails[/b] and [b]curved rails[/b] are made in the assembler. Click a loose rail with the hammer to lay it, click a laid rail to pick it up, [b]R[/b] to turn it.

A [b]minecart[/b] (1 to 4 squares long) is built on rails. Drop a charged battery cell into the cradle at its back. Machines built on its deck share the cell's power with no wires - except the ones you have to switch yourself: [b]Go[/b], [b]Reverse[/b], logic blocks, transmitters and crates.

While Go is powered the cart rolls forward one square at a time; Reverse rolls it back. It stops where the track ends, at another cart, or at a [b]rail buffer[/b] that's down.

A [b]rail layer[/b] lays a rail from a crate on the cart when the track runs out; a [b]rail lifter[/b] picks up the rail behind. A [b]rail switch[/b] beside the track branches it while powered. A [b]cart unloader[/b] empties a crate on a cart beside it onto a belt."""],
	["Drones", """Drones fly at a fixed height and carry [b]one thing[/b] - only as heavy as their size can lift. Too heavy and they can't get off the ground.

A drone runs on a battery cell in the cradle on its back. It has no wires: its five [b]dials[/b] are wireless receivers. Look at a dial and press E to change its channel.

The front, right, back and left dials fly it that way while their channel is on (two at once flies diagonally). The top dial works its [b]pad[/b]: on, it goes down and picks up what's under it; off, it lets go.

A powered [b]drone pad[/b] charges a drone above it."""],
	["Growing the business", """[b]Land[/b] - for-sale signs stand on the plots next to yours. Press E at one to buy it; each plot costs more than the last.
[b]Bigger trucks[/b] - buy a bigger truck at the computer: your old one drives off and the new one comes back in its place.
[b]Company sign[/b] - grows as you earn more.
[b]Trophy wall[/b] - your milestones, in the cabin.

The game saves by itself. Continue on the title screen picks up where you left off."""],
]

var _body: RichTextLabel
var _buttons: Array[Button] = []
var _font_body: FontVariation
var _font_bold: FontVariation


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_font_body = _font("res://assets/fonts/Nunito.ttf", 600)
	_font_bold = _font("res://assets/fonts/Nunito.ttf", 850)
	var font_title := _font("res://assets/fonts/Fredoka.ttf", 600)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.5)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var panel := PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -470
	panel.offset_right = 470
	panel.offset_top = -315
	panel.offset_bottom = 315
	var sb := StyleBoxFlat.new()
	sb.bg_color = BG
	sb.set_corner_radius_all(18)
	for side in ["left", "right", "top", "bottom"]:
		sb.set("content_margin_" + side, 24)
	panel.add_theme_stylebox_override("panel", sb)
	add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	panel.add_child(v)
	var head := HBoxContainer.new()
	v.add_child(head)
	var t := Label.new()
	t.text = "Field Guide"
	t.add_theme_font_override("font", font_title)
	t.add_theme_font_size_override("font_size", 32)
	t.add_theme_color_override("font_color", ACCENT)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	var back := _flat("Back  [Esc]", 15)
	back.pressed.connect(_close)
	head.add_child(back)
	var row := HBoxContainer.new()
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 18)
	v.add_child(row)
	var list := VBoxContainer.new()
	list.custom_minimum_size.x = 210
	list.add_theme_constant_override("separation", 2)
	row.add_child(list)
	for i in TOPICS.size():
		var b := _flat(String(TOPICS[i][0]), 16)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.toggle_mode = true
		var idx := i
		b.pressed.connect(func(): _show(idx))
		list.add_child(b)
		_buttons.append(b)
	_body = RichTextLabel.new()
	_body.bbcode_enabled = true
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_font_override("normal_font", _font_body)
	_body.add_theme_font_override("bold_font", _font_bold)
	_body.add_theme_font_size_override("normal_font_size", 16)
	_body.add_theme_font_size_override("bold_font_size", 16)
	_body.add_theme_color_override("default_color", Color(1, 1, 1, 0.85))
	_body.add_theme_constant_override("line_separation", 3)
	row.add_child(_body)
	_show(0)


func _show(i: int) -> void:
	for k in _buttons.size():
		_buttons[k].button_pressed = k == i
	_body.text = "[font_size=22][color=#ffcf6a][b]%s[/b][/color][/font_size]\n\n%s" % [TOPICS[i][0], TOPICS[i][1]]
	_body.scroll_to_line(0)
	Sfx.play("click", 1.1, -6.0)


func _close() -> void:
	Sfx.play("click")
	closed.emit()
	queue_free()


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		_close()


func _flat(text: String, size: int) -> Button:
	var b := Button.new()
	b.text = text
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_override("font", _font_bold)
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_color_override("font_color", Color(1, 1, 1, 0.7))
	b.add_theme_color_override("font_hover_color", ACCENT)
	b.add_theme_color_override("font_pressed_color", ACCENT)
	b.add_theme_color_override("font_hover_pressed_color", ACCENT)
	return b


func _font(path: String, weight: int) -> FontVariation:
	var f := FontVariation.new()
	f.base_font = load(path)
	f.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): weight}
	return f
