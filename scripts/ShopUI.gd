class_name ShopUI
extends Control
## TimberMart storefront. Full-screen on the cabin computer (the whole computer IS the shop), or a compact
## phone version with an extra Truck tab.

signal closed

const BG := Color("f4efe6")
const INK := Color("2b2118")
const MUTED := Color("7a6a58")
const ACCENT := Color("e8792b")
const GREEN := Color("2f7d4a")
const CARD := Color("ffffff")

var main: Node
var compact := false
var page := "store"      # store | product | orders | truck
var cat := "all"
var selected := ""
var font_body: FontVariation
var font_bold: FontVariation
var font_title: FontVariation

var _screen: PanelContainer
var _content: VBoxContainer
var _scroll: ScrollContainer
var _wallet: Label
var _side: VBoxContainer
var _nav: HBoxContainer


func setup(p_main: Node, p_compact: bool) -> void:
	main = p_main
	compact = p_compact
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	font_body = _font("res://assets/fonts/Nunito.ttf", 650)
	font_bold = _font("res://assets/fonts/Nunito.ttf", 850)
	font_title = _font("res://assets/fonts/Fredoka.ttf", 600)
	if compact:
		_build_phone()
	else:
		_build_computer()
	Game.money_changed.connect(func(_m): _refresh_wallet())
	Game.orders_changed.connect(func(): if page == "orders": _render())
	if main.icons != null:
		main.icons.icon_ready.connect(func(_id): _render())
	_render()


func _font(path: String, weight: int) -> FontVariation:
	var f := FontVariation.new()
	f.base_font = load(path)
	f.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): weight}
	return f


func _flat(c: Color, r: int, pad: int, border: Color = Color(0, 0, 0, 0), bw: int = 0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = c
	s.set_corner_radius_all(r)
	s.content_margin_left = pad
	s.content_margin_right = pad
	s.content_margin_top = pad
	s.content_margin_bottom = pad
	if bw > 0:
		s.border_color = border
		s.set_border_width_all(bw)
	return s


func _label(t: String, size: int, c: Color = INK, f: Font = null) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_override("font", f if f else font_body)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", c)
	return l


func _button(t: String, cb: Callable, bg: Color = ACCENT, fg: Color = Color.WHITE, size: int = 15) -> Button:
	var b := Button.new()
	b.text = t
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_override("font", font_bold)
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_color_override("font_color", fg)
	b.add_theme_color_override("font_hover_color", fg)
	b.add_theme_color_override("font_pressed_color", fg)
	b.add_theme_color_override("font_disabled_color", Color(fg.r, fg.g, fg.b, 0.5))
	b.add_theme_stylebox_override("normal", _flat(bg, 8, 8))
	b.add_theme_stylebox_override("hover", _flat(bg.lightened(0.12), 8, 8))
	b.add_theme_stylebox_override("pressed", _flat(bg.darkened(0.1), 8, 8))
	b.add_theme_stylebox_override("disabled", _flat(bg.lerp(Color(0.8, 0.8, 0.8), 0.6), 8, 8))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.pressed.connect(func():
		Sfx.play("click")
		cb.call())
	return b


# ------------------------------------------------------------------ frames

func _build_computer() -> void:
	# monitor bezel filling the screen, with the store inside
	var bezel := PanelContainer.new()
	bezel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bezel.add_theme_stylebox_override("panel", _flat(Color("d9d2bf"), 0, 26))
	add_child(bezel)
	_screen = PanelContainer.new()
	_screen.add_theme_stylebox_override("panel", _flat(BG, 10, 0, Color("8a8270"), 3))
	bezel.add_child(_screen)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	_screen.add_child(v)
	# header
	var head := PanelContainer.new()
	head.add_theme_stylebox_override("panel", _flat(Color("2b2118"), 0, 14))
	v.add_child(head)
	var hh := HBoxContainer.new()
	hh.add_theme_constant_override("separation", 16)
	head.add_child(hh)
	var logo := _label("TimberMart", 30, Color("ffb070"), font_title)
	hh.add_child(logo)
	var tag := _label("Tools & gear for the working lumberjack  -  free delivery to Pinewood Cabin", 14, Color(1, 1, 1, 0.65))
	tag.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tag.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hh.add_child(tag)
	_nav = HBoxContainer.new()
	_nav.add_theme_constant_override("separation", 8)
	hh.add_child(_nav)
	_wallet = _label("", 20, Color("7aff9a"), font_title)
	_wallet.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hh.add_child(_wallet)
	hh.add_child(_button("Power off  [Esc]", func(): close(), Color("8a3b1c")))
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 0)
	v.add_child(body)
	var sidep := PanelContainer.new()
	sidep.custom_minimum_size.x = 230
	sidep.add_theme_stylebox_override("panel", _flat(Color("ebe3d5"), 0, 16))
	body.add_child(sidep)
	_side = VBoxContainer.new()
	_side.add_theme_constant_override("separation", 6)
	sidep.add_child(_side)
	_scroll = ScrollContainer.new()
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(_scroll)
	var pad := MarginContainer.new()
	pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for k in ["left", "right", "top", "bottom"]:
		pad.add_theme_constant_override("margin_" + k, 22)
	_scroll.add_child(pad)
	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 14)
	pad.add_child(_content)
	var foot := PanelContainer.new()
	foot.add_theme_stylebox_override("panel", _flat(Color("ebe3d5"), 0, 8))
	v.add_child(foot)
	foot.add_child(_label("Orders ship immediately. The orange delivery van drops your boxes at the loading dock by the cabin.", 13, MUTED))


func _build_phone() -> void:
	var frame := PanelContainer.new()
	frame.anchor_left = 1.0
	frame.anchor_right = 1.0
	frame.anchor_top = 0.5
	frame.anchor_bottom = 0.5
	frame.offset_left = -430
	frame.offset_right = -40
	frame.offset_top = -330
	frame.offset_bottom = 330
	frame.add_theme_stylebox_override("panel", _flat(Color("1c1f26"), 36, 14))
	add_child(frame)
	_screen = PanelContainer.new()
	_screen.add_theme_stylebox_override("panel", _flat(BG, 24, 0))
	frame.add_child(_screen)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	_screen.add_child(v)
	var status := PanelContainer.new()
	status.add_theme_stylebox_override("panel", _flat(Color("2b2118"), 0, 10))
	v.add_child(status)
	var sh := HBoxContainer.new()
	status.add_child(sh)
	var app := _label("TimberMart", 20, Color("ffb070"), font_title)
	app.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sh.add_child(app)
	_wallet = _label("", 16, Color("7aff9a"), font_title)
	sh.add_child(_wallet)
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(_scroll)
	var pad := MarginContainer.new()
	pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for k in ["left", "right", "top", "bottom"]:
		pad.add_theme_constant_override("margin_" + k, 12)
	_scroll.add_child(pad)
	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 10)
	pad.add_child(_content)
	_nav = HBoxContainer.new()
	_nav.alignment = BoxContainer.ALIGNMENT_CENTER
	_nav.add_theme_constant_override("separation", 6)
	var navp := PanelContainer.new()
	navp.add_theme_stylebox_override("panel", _flat(Color("ebe3d5"), 0, 8))
	navp.add_child(_nav)
	v.add_child(navp)


func close() -> void:
	closed.emit()


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var k := (event as InputEventKey).keycode
		if k == KEY_ESCAPE or (compact and k == KEY_TAB):
			get_viewport().set_input_as_handled()
			close()


# ------------------------------------------------------------------ render

func _refresh_wallet() -> void:
	if _wallet:
		_wallet.text = "$%.2f" % Game.money
	if page in ["product", "store"]:
		_render()


func _render() -> void:
	_refresh_wallet_label()
	for c in _content.get_children():
		_content.remove_child(c)
		c.queue_free()
	_render_nav()
	if not compact:
		_render_side()
	match page:
		"store": _p_store()
		"product": _p_product()
		"orders": _p_orders()
		"truck": _p_truck()


func _refresh_wallet_label() -> void:
	if _wallet:
		_wallet.text = "$%.2f" % Game.money


func _render_nav() -> void:
	for c in _nav.get_children():
		_nav.remove_child(c)
		c.queue_free()
	var tabs := [["store", "Store"], ["orders", "My orders"]]
	if compact:
		tabs.append(["truck", "Log truck"])
	tabs.append(["close", "Close"] if compact else ["", ""])
	for t in tabs:
		if String(t[0]) == "":
			continue
		var id: String = t[0]
		var active := page == id or (id == "store" and page == "product")
		var b := _button(String(t[1]), func():
			if id == "close":
				close()
				return
			page = id
			_render(), Color("ffb070") if active else Color("3a2e24"), Color("2b2118") if active else Color.WHITE, 14)
		_nav.add_child(b)


func _render_side() -> void:
	for c in _side.get_children():
		_side.remove_child(c)
		c.queue_free()
	_side.add_child(_label("DEPARTMENTS", 12, MUTED, font_bold))
	for cdef in Tools.CATEGORIES:
		var cid: String = cdef.id
		var n := _items_in(cid).size()
		var active := cat == cid and page in ["store", "product"]
		var b := _button("%s  (%d)" % [cdef.name, n], func():
			cat = cid
			page = "store"
			_render(), ACCENT if active else Color("f8f3ea"), Color.WHITE if active else INK, 15)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		_side.add_child(b)
	_side.add_child(HSeparator.new())
	_side.add_child(_label("YOUR CABIN", 12, MUTED, font_bold))
	var owned := Tools.SHOP_ORDER.filter(func(i): return Game.is_owned(i)).size()
	_side.add_child(_label("Owned: %d of %d items" % [owned, Tools.SHOP_ORDER.size()], 14, INK))
	_side.add_child(_label("On the way: %d" % Game.orders.filter(func(o): return o.status != "delivered").size(), 14, INK))
	_side.add_child(_label("Lifetime sales: $%.2f" % Game.total_earned, 14, INK))


func _items_in(cid: String) -> Array:
	return Tools.SHOP_ORDER.filter(func(i): return cid == "all" or Tools.SHOP[i].cat == cid)


func _status_of(id: String) -> String:
	if Game.is_owned(id):
		return "owned"
	if Game.is_ordered(id):
		return "ordered"
	return "buy"


func _icon(id: String, px: int) -> Control:
	var tr := TextureRect.new()
	tr.custom_minimum_size = Vector2(px, px)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if main.icons != null:
		tr.texture = main.icons.get_icon(id)
	var bg := PanelContainer.new()
	bg.add_theme_stylebox_override("panel", _flat(Color("efe7da"), 10, 6))
	bg.add_child(tr)
	return bg


func _stat_bar(label: String, value: float, maxv: float) -> Control:
	var h := HBoxContainer.new()
	var l := _label(label, 12, MUTED)
	l.custom_minimum_size.x = 90
	h.add_child(l)
	var pb := ProgressBar.new()
	pb.custom_minimum_size = Vector2(110, 8)
	pb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pb.max_value = maxv
	pb.value = value
	pb.show_percentage = false
	pb.add_theme_stylebox_override("background", _flat(Color("e3d9c8"), 4, 0))
	pb.add_theme_stylebox_override("fill", _flat(GREEN, 4, 0))
	h.add_child(pb)
	return h


func _tool_stats(id: String, box: Container) -> void:
	if not Tools.TOOLS.has(id):
		return
	var d: Dictionary = Tools.TOOLS[id]
	if float(d.radius) <= 0.0:
		return     # saws, shears, vacuum, hammer: no stripping circle to compare
	box.add_child(_stat_bar("Strip size", float(d.radius), 0.36))
	var rate := 1.0 / float(d.cooldown)
	box.add_child(_stat_bar("Speed", rate, 6.5))


func _p_store() -> void:
	var title := "All products" if cat == "all" else String(Tools.CATEGORIES.filter(func(c): return c.id == cat)[0].name)
	_content.add_child(_label(title, 26 if not compact else 20, INK, font_title))
	if not compact and cat == "all":
		var banner := PanelContainer.new()
		banner.add_theme_stylebox_override("panel", _flat(Color("2f7d4a"), 12, 18))
		var bl := _label("Tired of bruised knuckles?  The Trusty Hatchet is only $30 - no more pain, bigger bark sheets.", 16, Color.WHITE, font_bold)
		bl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		banner.add_child(bl)
		_content.add_child(banner)
	var grid := GridContainer.new()
	grid.columns = 1 if compact else 3
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 16)
	_content.add_child(grid)
	for id in _items_in(cat):
		grid.add_child(_card(id))


func _card(id: String) -> Control:
	var it: Dictionary = Tools.SHOP[id]
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", _flat(CARD, 14, 14, Color("e3d9c8"), 1))
	pc.custom_minimum_size = Vector2(0 if compact else 260, 0)
	pc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v: VBoxContainer = VBoxContainer.new() if not compact else null
	var row: HBoxContainer = HBoxContainer.new() if compact else null
	if compact:
		row.add_theme_constant_override("separation", 10)
		pc.add_child(row)
		row.add_child(_icon(id, 84))
		v = VBoxContainer.new()
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(v)
	else:
		v.add_theme_constant_override("separation", 6)
		pc.add_child(v)
		var top := HBoxContainer.new()
		var pill := PanelContainer.new()
		pill.add_theme_stylebox_override("panel", _flat(Color("fde4cf"), 10, 4))
		pill.add_child(_label(String(it.tag).to_upper(), 11, ACCENT, font_bold))
		top.add_child(pill)
		v.add_child(top)
		var ic := _icon(id, 170)
		v.add_child(ic)
	v.add_child(_label(String(it.name), 18, INK, font_bold))
	var pr := _label("$%s" % _price(float(it.price)), 20, GREEN, font_title)
	v.add_child(pr)
	if not compact:
		_tool_stats(id, v)
	var st := _status_of(id)
	var b: Button
	match st:
		"owned": b = _button("Owned", func(): _open(id), Color("cfc6b5"), INK)
		"ordered": b = _button("On the way", func(): _open(id), Color("8fb8d8"), INK)
		_: b = _button("View", func(): _open(id))
	v.add_child(b)
	return pc


func _price(p: float) -> String:
	return ("%d" % int(p)) if absf(p - round(p)) < 0.001 else ("%.2f" % p)


func _open(id: String) -> void:
	selected = id
	page = "product"
	_render()


func _p_product() -> void:
	var id := selected
	var it: Dictionary = Tools.SHOP[id]
	_content.add_child(_button("< Back to %s" % ("store" if cat == "all" else "department"), func():
		page = "store"
		_render(), Color("3a2e24")))
	var row: BoxContainer = HBoxContainer.new() if not compact else VBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	_content.add_child(row)
	row.add_child(_icon(id, 300 if not compact else 220))
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 10)
	row.add_child(v)
	v.add_child(_label(String(it.name), 32 if not compact else 22, INK, font_title))
	var d := _label(String(it.desc), 16, MUTED)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.custom_minimum_size.x = 260
	v.add_child(d)
	_tool_stats(id, v)
	if Tools.TOOLS.has(id) and float(Tools.TOOLS[id].radius) > 0.0:
		var td: Dictionary = Tools.TOOLS[id]
		v.add_child(_label("Strips a %d cm circle per hit, %.1f hits per second%s." % [int(float(td.radius) * 200.0), 1.0 / float(td.cooldown), " (hold to drill)" if td.get("hold", false) else ""], 14, INK))
	v.add_child(_label("$%s" % _price(float(it.price)), 30, GREEN, font_title))
	var st := _status_of(id)
	match st:
		"owned":
			v.add_child(_label("You own this.", 16, GREEN, font_bold))
		"ordered":
			v.add_child(_label("Ordered - the delivery van is bringing it.", 16, Color("2e6da4"), font_bold))
		_:
			var can: bool = Game.can_afford(float(it.price))
			var b := _button("Buy now - $%s" % _price(float(it.price)) if can else "Need $%.2f more" % (float(it.price) - Game.money), func():
				if Game.buy(id):
					Sfx.play("buy")
					main.call("on_order_placed")
					_render(), GREEN if can else Color("b9ae9a"), Color.WHITE, 18)
			b.disabled = not can
			v.add_child(b)


func _p_orders() -> void:
	_content.add_child(_label("My orders", 26 if not compact else 20, INK, font_title))
	if Game.orders.is_empty():
		_content.add_child(_label("No orders yet. Everything you buy arrives by delivery van in a box.", 15, MUTED))
		return
	var list: Array = Game.orders.duplicate()
	list.reverse()
	for o in list:
		var pc := PanelContainer.new()
		pc.add_theme_stylebox_override("panel", _flat(CARD, 12, 12, Color("e3d9c8"), 1))
		_content.add_child(pc)
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 14)
		pc.add_child(h)
		h.add_child(_icon(String(o.item), 64))
		var v := VBoxContainer.new()
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(v)
		v.add_child(_label(String(Tools.SHOP[o.item].name), 17, INK, font_bold))
		v.add_child(_label("Order #%d" % int(o.id), 13, MUTED))
		var txt := "Processing"
		var col := Color("b9822b")
		match String(o.status):
			"shipping":
				txt = "Out for delivery"
				col = Color("2e6da4")
			"delivered":
				txt = "Delivered"
				col = GREEN
		var pill := PanelContainer.new()
		pill.add_theme_stylebox_override("panel", _flat(col, 10, 6))
		pill.add_child(_label(txt, 13, Color.WHITE, font_bold))
		pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(pill)


func _p_truck() -> void:
	_content.add_child(_label("Log truck", 20, INK, font_title))
	var t: Truck = main.ship_truck
	var v: float = t.load_value()
	var state := "Parked by the cabin" if t.state == "parked" else ("Driving to town" if t.state in ["leaving", "away"] else "Coming back")
	_content.add_child(_label(state, 16, INK, font_bold))
	_content.add_child(_label("Current load: $%.2f" % v, 16, GREEN, font_bold))
	var b := _button("Send the truck to town", func():
		if t.ship():
			_render(), GREEN)
	b.disabled = t.state != "parked" or v <= 0.0
	_content.add_child(b)
	_content.add_child(_label("Lifetime sales: $%.2f" % Game.total_earned, 14, MUTED))
