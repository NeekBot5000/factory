class_name Hud
extends CanvasLayer
## All UI, built in code: wallet + quest cards, orders tracker, inspector, build hotbar with rendered
## part icons, modal panels (upgrades, land, orders, market, quests, blueprints, ascension, menu, help).

const C_BG := Color(0.07, 0.09, 0.16, 0.9)
const C_BG2 := Color(0.11, 0.14, 0.24, 0.97)
const C_CARD := Color(1, 1, 1, 0.05)
const C_ACCENT := Color("ffcf4a")
const C_GOOD := Color("7aff9a")
const C_BAD := Color("ff7a7a")
const C_INFO := Color("8fd0ff")
const C_MUTED := Color(1, 1, 1, 0.6)

var world: Node
var builder: Builder
var root: Control
var theme_res: Theme
var font_body: FontVariation
var font_bold: FontVariation
var font_title: FontVariation
var icons: IconRenderer

var money_lbl: Label
var income_lbl: Label
var level_lbl: Label
var xp_bar: ProgressBar
var stars_lbl: Label
var items_lbl: Label
var quest_lbl: Label
var quest_reward: Label
var quest_bar: ProgressBar
var fps_lbl: Label

var orders_box: VBoxContainer
var inspector: PanelContainer
var insp_title: Label
var insp_icon: TextureRect
var insp_info: Label
var insp_opts: VBoxContainer
var insp_actions: HFlowContainer
var inspected: Part = null

var cat_row: HBoxContainer
var tool_row: HBoxContainer
var card_row: HBoxContainer
var info_lbl: Label
var tip: Label
var toast_box: VBoxContainer

var modal: PanelContainer
var modal_title: Label
var modal_body: VBoxContainer
var modal_scroll: ScrollContainer
var panel_name := ""

var cur_cat := "production"
var buy_qty := 1
var _tick := 0.0
var _confirm_reset := false
var _speed_btns: Array[Button] = []
var _slot_cache: Array = []
var _cards := {}


func setup(p_world: Node, p_builder: Builder) -> void:
	world = p_world
	builder = p_builder
	builder.hud = self
	layer = 10
	_make_theme()
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = theme_res
	add_child(root)
	_build_top_left()
	_build_top_right()
	_build_inspector()
	_build_bottom()
	_build_modal()
	_build_toasts()
	tip = Label.new()
	tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tip.add_theme_stylebox_override("normal", _flat(Color(0.04, 0.05, 0.1, 0.94), 8, 10, Color(1, 1, 1, 0.1), 1))
	tip.add_theme_font_size_override("font_size", 14)
	tip.visible = false
	root.add_child(tip)
	if DisplayServer.get_name() != "headless":
		icons = IconRenderer.new()
		add_child(icons)
		icons.icon_ready.connect(_on_icon)
		icons.request_all()
	Game.toast.connect(show_toast)
	Game.quests_changed.connect(_update_quest)
	Game.unlocks_changed.connect(refresh_hotbar)
	Game.upgrades_changed.connect(_on_data_changed)
	Game.plots_changed.connect(_on_data_changed)
	Game.stars_changed.connect(_on_data_changed)
	Game.orders_changed.connect(_refresh_orders)
	builder.mode_changed.connect(_on_mode_changed)
	refresh_hotbar()
	_update_quest()
	_update_top()
	_refresh_orders()
	if not Game.offline_report.is_empty():
		var rep: Dictionary = Game.offline_report
		show_toast("Welcome back! Your factory earned %s while you were away (%s)." % [Util.money(rep.earned), _fmt_time(rep.seconds)], C_GOOD, 7.0)
	if not bool(Game.settings.seen_help):
		Game.set_setting("seen_help", true)
		open_panel("help")


# ------------------------------------------------------------ styling

func _flat(c: Color, radius: int = 10, pad: int = 8, border: Color = Color(0, 0, 0, 0), bw: int = 0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = c
	s.set_corner_radius_all(radius)
	s.content_margin_left = pad
	s.content_margin_right = pad
	s.content_margin_top = pad * 0.6
	s.content_margin_bottom = pad * 0.6
	if bw > 0:
		s.border_color = border
		s.set_border_width_all(bw)
	s.anti_aliasing = true
	return s


func _font(path: String, weight: int) -> FontVariation:
	var f := FontVariation.new()
	var base := load(path) as FontFile
	if base == null:
		base = FontFile.new()
	f.base_font = base
	f.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): weight}
	return f


func _make_theme() -> void:
	font_body = _font("res://assets/fonts/Nunito.ttf", 650)
	font_bold = _font("res://assets/fonts/Nunito.ttf", 850)
	font_title = _font("res://assets/fonts/Fredoka.ttf", 600)
	theme_res = Theme.new()
	theme_res.default_font = font_body
	theme_res.default_font_size = 15
	theme_res.set_color("font_color", "Label", Color.WHITE)
	theme_res.set_color("font_outline_color", "Label", Color(0, 0, 0, 0.5))
	theme_res.set_stylebox("panel", "PanelContainer", _flat(C_BG, 14, 12, Color(1, 1, 1, 0.08), 1))
	theme_res.set_stylebox("normal", "Button", _flat(Color("26345c"), 9, 10, Color(1, 1, 1, 0.06), 1))
	theme_res.set_stylebox("hover", "Button", _flat(Color("34477d"), 9, 10, Color(1, 1, 1, 0.15), 1))
	theme_res.set_stylebox("pressed", "Button", _flat(Color("4c63a8"), 9, 10, Color(1, 1, 1, 0.2), 1))
	theme_res.set_stylebox("disabled", "Button", _flat(Color("1b2238"), 9, 10))
	theme_res.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	theme_res.set_font("font", "Button", font_bold)
	theme_res.set_color("font_color", "Button", Color.WHITE)
	theme_res.set_color("font_disabled_color", "Button", Color(1, 1, 1, 0.35))
	theme_res.set_stylebox("background", "ProgressBar", _flat(Color(0, 0, 0, 0.45), 6, 0))
	theme_res.set_stylebox("fill", "ProgressBar", _flat(C_ACCENT, 6, 0))
	theme_res.set_stylebox("normal", "Label", StyleBoxEmpty.new())
	theme_res.set_stylebox("panel", "TooltipPanel", _flat(Color(0.04, 0.05, 0.1, 0.95), 8, 10, Color(1, 1, 1, 0.12), 1))
	theme_res.set_color("font_color", "TooltipLabel", Color.WHITE)
	theme_res.set_font_size("font_size", "TooltipLabel", 14)
	var sep := StyleBoxLine.new()
	sep.color = Color(1, 1, 1, 0.1)
	sep.thickness = 1
	theme_res.set_stylebox("separator", "HSeparator", sep)


func _label(text: String, size: int = 15, color: Color = Color.WHITE, f: Font = null) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if f != null:
		l.add_theme_font_override("font", f)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _button(text: String, cb: Callable, min_w: float = 0.0, tint: Color = Color(0, 0, 0, 0)) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	if min_w > 0.0:
		b.custom_minimum_size.x = min_w
	if tint.a > 0.0:
		b.add_theme_stylebox_override("normal", _flat(tint.darkened(0.45), 9, 10, tint.darkened(0.1), 1))
		b.add_theme_stylebox_override("hover", _flat(tint.darkened(0.3), 9, 10, tint, 1))
	b.pressed.connect(func():
		FX.play("click")
		cb.call())
	return b


func _bar(w: float, h: float, color: Color) -> ProgressBar:
	var p := ProgressBar.new()
	p.custom_minimum_size = Vector2(w, h)
	p.max_value = 1.0
	p.show_percentage = false
	p.add_theme_stylebox_override("fill", _flat(color, 6, 0))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


# ------------------------------------------------------------ layout

func _build_top_left() -> void:
	var col := VBoxContainer.new()
	col.position = Vector2(14, 14)
	col.add_theme_constant_override("separation", 8)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(col)
	var p := PanelContainer.new()
	col.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	p.add_child(v)
	money_lbl = _label("$0", 34, C_ACCENT, font_title)
	v.add_child(money_lbl)
	income_lbl = _label("+$0/s", 15, C_GOOD, font_bold)
	v.add_child(income_lbl)
	var lr := HBoxContainer.new()
	lr.add_theme_constant_override("separation", 10)
	level_lbl = _label("Level 0", 15, Color.WHITE, font_bold)
	lr.add_child(level_lbl)
	stars_lbl = _label("", 14, Color("ffb3ff"), font_bold)
	lr.add_child(stars_lbl)
	v.add_child(lr)
	xp_bar = _bar(240, 9, C_ACCENT)
	v.add_child(xp_bar)
	items_lbl = _label("", 12, C_MUTED)
	v.add_child(items_lbl)
	var q := PanelContainer.new()
	q.custom_minimum_size.x = 264
	col.add_child(q)
	var qv := VBoxContainer.new()
	qv.add_theme_constant_override("separation", 3)
	q.add_child(qv)
	qv.add_child(_label("QUEST", 11, C_INFO, font_bold))
	quest_lbl = _label("", 14, Color("e6ecff"))
	quest_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	quest_lbl.custom_minimum_size.x = 240
	qv.add_child(quest_lbl)
	quest_bar = _bar(240, 7, C_INFO)
	qv.add_child(quest_bar)
	quest_reward = _label("", 12, C_GOOD)
	qv.add_child(quest_reward)
	fps_lbl = _label("", 12, C_MUTED)
	col.add_child(fps_lbl)


func _build_top_right() -> void:
	var col := VBoxContainer.new()
	col.anchor_left = 1.0
	col.anchor_right = 1.0
	col.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	col.offset_right = -14
	col.offset_top = 14
	col.alignment = BoxContainer.ALIGNMENT_BEGIN
	col.add_theme_constant_override("separation", 8)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(col)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 5)
	h.alignment = BoxContainer.ALIGNMENT_END
	col.add_child(h)
	for e in [["Orders", "orders", C_INFO], ["Market", "market", Color("57e08a")], ["Upgrades", "upgrades", C_ACCENT], ["Land", "land", Color("6fc24a")], ["Quests", "quests", Color("c9d6ff")], ["Blueprints", "blueprints", Color("c07bff")], ["Ascend", "ascend", Color("ff7ad9")]]:
		var pname: String = e[1]
		h.add_child(_button(String(e[0]), func(): toggle_panel(pname), 0, e[2]))
	h.add_child(_button("Menu", func(): toggle_menu()))
	var sh := HBoxContainer.new()
	sh.alignment = BoxContainer.ALIGNMENT_END
	sh.add_theme_constant_override("separation", 4)
	col.add_child(sh)
	sh.add_child(_label("Speed ", 13, C_MUTED))
	for s in [1, 2, 3]:
		var b := _button("%dx" % s, func(): _set_speed(s), 40)
		_speed_btns.append(b)
		sh.add_child(b)
	_set_speed(1)
	var op := PanelContainer.new()
	op.custom_minimum_size.x = 290
	col.add_child(op)
	var ov := VBoxContainer.new()
	ov.add_theme_constant_override("separation", 4)
	op.add_child(ov)
	ov.add_child(_label("ORDERS", 11, C_INFO, font_bold))
	orders_box = VBoxContainer.new()
	orders_box.add_theme_constant_override("separation", 6)
	ov.add_child(orders_box)


func _set_speed(s: int) -> void:
	Engine.time_scale = float(s)
	for i in _speed_btns.size():
		_speed_btns[i].modulate = C_ACCENT if i == s - 1 else Color.WHITE


func _build_inspector() -> void:
	inspector = PanelContainer.new()
	inspector.anchor_left = 1.0
	inspector.anchor_right = 1.0
	inspector.anchor_top = 0.5
	inspector.anchor_bottom = 0.5
	inspector.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	inspector.grow_vertical = Control.GROW_DIRECTION_BOTH
	inspector.offset_right = -14
	inspector.offset_top = -40
	inspector.custom_minimum_size = Vector2(300, 0)
	inspector.add_theme_stylebox_override("panel", _flat(C_BG2, 14, 12, C_ACCENT.darkened(0.3), 1))
	inspector.visible = false
	root.add_child(inspector)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	inspector.add_child(v)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	insp_icon = TextureRect.new()
	insp_icon.custom_minimum_size = Vector2(56, 56)
	insp_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	insp_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	head.add_child(insp_icon)
	insp_title = _label("", 20, C_ACCENT, font_title)
	insp_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	insp_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	head.add_child(insp_title)
	head.add_child(_button("x", func(): inspect(null), 32))
	v.add_child(head)
	insp_info = _label("", 13, Color("dfe6ff"))
	insp_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	insp_info.custom_minimum_size.x = 276
	v.add_child(insp_info)
	insp_opts = VBoxContainer.new()
	insp_opts.add_theme_constant_override("separation", 4)
	v.add_child(insp_opts)
	insp_actions = HFlowContainer.new()
	insp_actions.add_theme_constant_override("h_separation", 5)
	insp_actions.add_theme_constant_override("v_separation", 5)
	v.add_child(insp_actions)


func _build_bottom() -> void:
	var v := VBoxContainer.new()
	v.anchor_left = 0.5
	v.anchor_right = 0.5
	v.anchor_top = 1.0
	v.anchor_bottom = 1.0
	v.grow_horizontal = Control.GROW_DIRECTION_BOTH
	v.grow_vertical = Control.GROW_DIRECTION_BEGIN
	v.offset_bottom = -12
	v.add_theme_constant_override("separation", 6)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(v)
	var ic := CenterContainer.new()
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(ic)
	info_lbl = _label("", 14, Color("dfe8ff"))
	info_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info_lbl.add_theme_stylebox_override("normal", _flat(Color(0.04, 0.05, 0.1, 0.82), 10, 12))
	ic.add_child(info_lbl)
	var p := PanelContainer.new()
	v.add_child(p)
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 8)
	p.add_child(inner)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 16)
	inner.add_child(top)
	cat_row = HBoxContainer.new()
	cat_row.add_theme_constant_override("separation", 4)
	top.add_child(cat_row)
	tool_row = HBoxContainer.new()
	tool_row.add_theme_constant_override("separation", 4)
	tool_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tool_row.alignment = BoxContainer.ALIGNMENT_END
	top.add_child(tool_row)
	for t in [["Wire [N]", "wire", Color("ff4f4f")], ["Upgrade [G]", "upgrade", Color("57e08a")], ["Select [B]", "select", Color("4fa8ff")], ["Demolish [T]", "demolish", Color("ff7a7a")]]:
		var m: String = t[1]
		var b := _button(String(t[0]), func(): builder.set_mode(m), 0, t[2])
		b.set_meta("mode", m)
		tool_row.add_child(b)
	tool_row.add_child(_button("Copy [C]", func(): builder.copy_selection()))
	tool_row.add_child(_button("Paste [V]", func(): builder.paste_mode()))
	card_row = HBoxContainer.new()
	card_row.add_theme_constant_override("separation", 6)
	card_row.custom_minimum_size.y = 104
	inner.add_child(card_row)


func _build_modal() -> void:
	modal = PanelContainer.new()
	modal.anchor_left = 0.5
	modal.anchor_right = 0.5
	modal.anchor_top = 0.44
	modal.anchor_bottom = 0.44
	modal.grow_horizontal = Control.GROW_DIRECTION_BOTH
	modal.grow_vertical = Control.GROW_DIRECTION_BOTH
	modal.custom_minimum_size = Vector2(740, 460)
	modal.add_theme_stylebox_override("panel", _flat(C_BG2, 16, 16, Color(1, 1, 1, 0.12), 1))
	modal.visible = false
	root.add_child(modal)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	modal.add_child(v)
	var head := HBoxContainer.new()
	modal_title = _label("", 26, C_ACCENT, font_title)
	modal_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(modal_title)
	head.add_child(_button("Close  [Esc]", func(): close_panel()))
	v.add_child(head)
	modal_scroll = ScrollContainer.new()
	modal_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	modal_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(modal_scroll)
	modal_body = VBoxContainer.new()
	modal_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	modal_body.add_theme_constant_override("separation", 6)
	modal_scroll.add_child(modal_body)


func _build_toasts() -> void:
	toast_box = VBoxContainer.new()
	toast_box.anchor_left = 0.5
	toast_box.anchor_right = 0.5
	toast_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	toast_box.offset_top = 16
	toast_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_box.add_theme_constant_override("separation", 4)
	root.add_child(toast_box)


# ------------------------------------------------------------ toasts / tips

func show_toast(text: String, color: Color = Color.WHITE, life: float = 3.4) -> void:
	var l := _label(text, 15, color, font_bold)
	l.add_theme_stylebox_override("normal", _flat(Color(0.04, 0.05, 0.1, 0.9), 10, 14, color.darkened(0.4), 1))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_box.add_child(l)
	while toast_box.get_child_count() > 4:
		var old := toast_box.get_child(0)
		toast_box.remove_child(old)
		old.queue_free()
	var tw := l.create_tween()
	tw.tween_interval(life)
	tw.tween_property(l, "modulate:a", 0.0, 0.5)
	tw.tween_callback(l.queue_free)


func pointer_over_ui() -> bool:
	var c: Control = get_viewport().gui_get_hovered_control()
	return c != null and c != root


func update_hover_info(b: Builder) -> void:
	var text := ""
	if b.mode == "build" or b.mode == "paste":
		text = b.plan_text()
		if b.layer_off > 0:
			text += "   Layer +%d" % b.layer_off
	elif b.hover_part != null and b.hover_part != inspected:
		text = b.hover_part.info_text()
		if b.mode == "none":
			text += "\n[click to %s]" % ("use" if b.hover_part.kind() == "logic" and String(b.hover_part.def.logic) in ["lever", "button"] or b.hover_part.kind() == "teleporter" else "inspect")
	if text == "" or pointer_over_ui():
		tip.visible = false
	else:
		tip.visible = true
		tip.text = text
		tip.reset_size()
		var mp := root.get_local_mouse_position()
		var vs := root.get_viewport_rect().size
		var pos := mp + Vector2(20, 20)
		if pos.x + tip.size.x > vs.x - 8:
			pos.x = mp.x - tip.size.x - 12
		if pos.y + tip.size.y > vs.y - 8:
			pos.y = mp.y - tip.size.y - 12
		tip.position = pos


func _on_mode_changed() -> void:
	_update_info_line()
	_refresh_cards_state()
	for b in tool_row.get_children():
		if b.has_meta("mode"):
			b.modulate = C_ACCENT if builder.mode == String(b.get_meta("mode")) else Color.WHITE


func _update_info_line() -> void:
	match builder.mode:
		"build":
			var d: Dictionary = Defs.PARTS[builder.part_id]
			info_lbl.text = "%s  -  %s\nR rotate  |  drag to paint (belts auto-turn)  |  Shift+drag fill  |  Z/X layer  |  RMB cancel" % [d.name, String(d.get("desc", ""))]
		"demolish":
			info_lbl.text = "DEMOLISH  -  click or drag to remove (100% refund), Shift+drag for an area"
		"select":
			info_lbl.text = "SELECT  -  drag a rectangle (all layers), then C copy (with wires) / G upgrade / Delete remove"
		"paste":
			info_lbl.text = "PASTE  -  click to place the blueprint (parts + wires), R rotates, RMB cancel"
		"upgrade":
			info_lbl.text = "UPGRADE  -  click a part (Ctrl = max out), Shift+drag to upgrade an area"
		"wire":
			if builder.wire_src.x == 99999:
				info_lbl.text = "WIRE  -  click a part with an OUTPUT (yellow): lever, button, timer, sensor, gate, counter, seller"
			else:
				info_lbl.text = "WIRE  -  now click a part with an INPUT (blue). Click an existing wire's target to remove it. Shift keeps the source."
		_:
			info_lbl.text = "Pick a part (1-9, Tab = category). Click parts to inspect / use them. Wheel zoom, right-drag orbit, WASD pan."


# ------------------------------------------------------------ hotbar

func _on_icon(id: String, tex: Texture2D) -> void:
	if _cards.has(id) and is_instance_valid(_cards[id]):
		(_cards[id] as Button).icon = tex
	if inspected != null and inspected.type_id == id:
		insp_icon.texture = tex


func refresh_hotbar() -> void:
	for c in cat_row.get_children():
		cat_row.remove_child(c)
		c.queue_free()
	for cat in Defs.CATEGORIES:
		var cid: String = cat.id
		var b := _button(String(cat.name), func(): _set_cat(cid))
		if cid == cur_cat:
			b.add_theme_stylebox_override("normal", _flat(Color("4c63a8"), 9, 10, C_ACCENT, 1))
			b.add_theme_color_override("font_color", C_ACCENT)
		cat_row.add_child(b)
	_rebuild_cards()
	_update_info_line()


func _set_cat(cid: String) -> void:
	cur_cat = cid
	refresh_hotbar()


func cycle_category() -> void:
	var idx := 0
	for i in Defs.CATEGORIES.size():
		if Defs.CATEGORIES[i].id == cur_cat:
			idx = i
	cur_cat = Defs.CATEGORIES[(idx + 1) % Defs.CATEGORIES.size()].id
	refresh_hotbar()


func _cat_parts() -> Array:
	var out := []
	for id in Defs.PARTS:
		if Defs.PARTS[id].cat == cur_cat:
			out.append(id)
	return out


func pick_slot(i: int) -> void:
	var list := _cat_parts()
	if i < list.size():
		builder.select_part(list[i])


func _rebuild_cards() -> void:
	for c in card_row.get_children():
		card_row.remove_child(c)
		c.queue_free()
	_cards.clear()
	_slot_cache = _cat_parts()
	for id in _slot_cache:
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(108, 104)
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		b.expand_icon = true
		b.clip_text = true
		b.set_meta("part_id", id)
		var pid: String = id
		b.pressed.connect(func():
			FX.play("click")
			builder.select_part(pid))
		if icons != null and icons.icons.has(id):
			b.icon = icons.icons[id]
		_style_card(b)
		card_row.add_child(b)
		_cards[id] = b


func _card_color(id: String) -> Color:
	var d: Dictionary = Defs.PARTS[id]
	if d.has("tint"):
		return d.tint
	if d.has("mat"):
		return Defs.MATERIALS[d.mat].color
	match String(d.cat):
		"machines": return Color("ff8a3d")
		"logic": return Color("ff5f5f")
	return Color("8a93a8")


func _style_card(b: Button) -> void:
	var id: String = b.get_meta("part_id")
	var d: Dictionary = Defs.PARTS[id]
	var c := _card_color(id)
	var unlocked := Game.part_unlocked(id)
	var cost := Game.part_cost(id)
	var slot := _slot_cache.find(id) + 1
	var line2 := ""
	if unlocked:
		line2 = Util.money(cost)
	else:
		var reason := Game.unlock_block_reason(id)
		line2 = ("Lv %d" % int(d.level)) if reason.begins_with("Reach") else ("Need land" if reason != "" else "Unlock " + Util.money(float(d.unlock)))
	b.text = "%s\n%s" % [d.name, line2]
	b.tooltip_text = "[%d] %s\n%s%s" % [slot, d.name, String(d.get("desc", "")), "" if unlocked else "\n\nLocked: " + (Game.unlock_block_reason(id) if Game.unlock_block_reason(id) != "" else "click to unlock for " + Util.money(float(d.unlock)))]
	b.add_theme_font_size_override("font_size", 12)
	var selected := builder.mode == "build" and builder.part_id == id
	var bg := c.darkened(0.7) if unlocked else Color(0.1, 0.11, 0.16)
	var border := C_ACCENT if selected else (c.darkened(0.15) if unlocked else Color(1, 1, 1, 0.12))
	var bw := 3 if selected else 1
	b.add_theme_stylebox_override("normal", _flat(bg, 10, 6, border, bw))
	b.add_theme_stylebox_override("hover", _flat(bg.lightened(0.12), 10, 6, border.lightened(0.3), maxi(bw, 2)))
	b.add_theme_stylebox_override("pressed", _flat(bg.lightened(0.2), 10, 6, border, bw))
	var afford := (unlocked and Game.can_afford(cost)) or (not unlocked and Game.unlock_block_reason(id) == "" and Game.can_afford(float(d.unlock)))
	b.add_theme_color_override("font_color", Color.WHITE if afford else Color(1, 1, 1, 0.45))
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.modulate = Color.WHITE if unlocked else Color(0.75, 0.75, 0.8)


func _refresh_cards_state() -> void:
	for b in card_row.get_children():
		if b is Button and b.has_meta("part_id"):
			_style_card(b)


# ------------------------------------------------------------ inspector

func inspect(p: Part) -> void:
	inspected = p
	inspector.visible = p != null
	if p == null:
		return
	insp_title.text = String(p.def.name)
	insp_icon.texture = icons.icons.get(p.type_id) if icons != null else null
	_build_inspector_controls()
	refresh_inspector()


func _build_inspector_controls() -> void:
	for c in insp_opts.get_children():
		insp_opts.remove_child(c)
		c.queue_free()
	for c in insp_actions.get_children():
		insp_actions.remove_child(c)
		c.queue_free()
	var p := inspected
	for opt in p.config_options():
		var o: Dictionary = opt
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		var l := _label(String(o.label), 13, C_MUTED)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(l)
		var val := _label(_opt_value_text(o, p.config.get(o.key)), 14, C_ACCENT, font_bold)
		val.custom_minimum_size.x = 80
		val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		row.add_child(_button("<", func(): _cycle_opt(o, -1), 30))
		row.add_child(val)
		row.add_child(_button(">", func(): _cycle_opt(o, 1), 30))
		insp_opts.add_child(row)
	if p.kind() == "logic" and String(p.def.logic) in ["lever", "button"]:
		insp_actions.add_child(_button("Use", func():
			if is_instance_valid(inspected):
				inspected.interact()
				refresh_inspector(), 0, Color("ff4f4f")))
	if p.can_upgrade():
		insp_actions.add_child(_button("Upgrade", func():
			if is_instance_valid(inspected) and world.upgrade_part(inspected):
				FX.play("buy")
				refresh_inspector(), 0, Color("57e08a")))
	if Defs.is_directional(p.type_id):
		insp_actions.add_child(_button("Rotate [R]", func():
			if is_instance_valid(inspected):
				inspected.set_rot(inspected.rot + 1)
				world._notify_neighbors(inspected.cell)
				inspected.on_neighbor_changed()))
	if Defs.has_output(p.type_id):
		insp_actions.add_child(_button("Wire from here", func():
			if is_instance_valid(inspected):
				builder.start_wire_from(inspected), 0, Color("ff4f4f")))
	insp_actions.add_child(_button("Build more", func():
		if is_instance_valid(inspected):
			builder.select_part(inspected.type_id)))
	insp_actions.add_child(_button("Demolish", func():
		if is_instance_valid(inspected):
			var q := inspected
			inspect(null)
			world.remove(q, true)
			FX.play("remove"), 0, Color("ff7a7a")))


func _opt_value_text(o: Dictionary, v: Variant) -> String:
	var values: Array = o["values"]
	var i := values.find(v)
	if o.has("names") and i >= 0:
		return String(o.names[i])
	if typeof(v) == TYPE_FLOAT:
		return ("%+.3f" % v) if String(o.key) == "offset" else str(v)
	return str(v)


func _cycle_opt(o: Dictionary, step: int) -> void:
	if not is_instance_valid(inspected):
		return
	var values: Array = o["values"]
	var cur: Variant = inspected.config.get(o.key)
	var i := values.find(cur)
	i = posmod((i if i >= 0 else 0) + step, values.size())
	inspected.config[o.key] = values[i]
	inspected.on_config_changed()
	_build_inspector_controls()
	refresh_inspector()


func refresh_inspector() -> void:
	if inspected == null:
		return
	if not is_instance_valid(inspected):
		inspect(null)
		return
	insp_info.text = inspected.info_text()


# ------------------------------------------------------------ orders tracker

func _refresh_orders() -> void:
	for c in orders_box.get_children():
		orders_box.remove_child(c)
		c.queue_free()
	if Game.orders.is_empty():
		orders_box.add_child(_label("No orders yet - new ones arrive every 40s once you produce something.", 12, C_MUTED))
		(orders_box.get_child(0) as Label).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		(orders_box.get_child(0) as Label).custom_minimum_size.x = 266
		return
	for o in Game.orders:
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 1)
		var h := HBoxContainer.new()
		var n := _label("%s" % o.name, 13, Color.WHITE, font_bold)
		n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(n)
		h.add_child(_label(Util.money(float(o.reward)), 13, C_GOOD, font_bold))
		v.add_child(h)
		var pb := _bar(266, 6, C_INFO)
		pb.value = float(o.done) / float(o.qty)
		pb.set_meta("order", o)
		v.add_child(pb)
		var t := _label("%d / %d   -   %s left" % [int(o.done), int(o.qty), _fmt_clock(float(o.time))], 11, C_MUTED)
		t.set_meta("order", o)
		v.add_child(t)
		orders_box.add_child(v)


func _tick_orders() -> void:
	for v in orders_box.get_children():
		for c in v.get_children():
			if c.has_meta("order"):
				var o: Dictionary = c.get_meta("order")
				if c is ProgressBar:
					(c as ProgressBar).value = float(o.done) / float(o.qty)
				elif c is Label:
					(c as Label).text = "%d / %d   -   %s left" % [int(o.done), int(o.qty), _fmt_clock(float(o.time))]


# ------------------------------------------------------------ top bar updates

func _fmt_time(sec: float) -> String:
	var s := int(sec)
	if s >= 3600:
		return "%dh %dm" % [s / 3600, (s % 3600) / 60]
	return "%dm" % maxi(1, s / 60)


func _fmt_clock(sec: float) -> String:
	var s := maxi(0, int(sec))
	return "%d:%02d" % [s / 60, s % 60]


func _update_top() -> void:
	money_lbl.text = Util.money(Game.money)
	income_lbl.text = "+%s / sec" % Util.money(Game.income_rate)
	level_lbl.text = "Factory level %d" % Game.level
	xp_bar.value = Game.level_progress()
	stars_lbl.text = ("%d stars  x%.2f" % [Game.stars, Game.star_mult()]) if Game.stars > 0 else ""
	items_lbl.text = "Items %d / %d    Parts %d    Wires %d" % [world.active_items.size(), Game.item_cap(), world.parts.size(), world.links.size()]
	fps_lbl.text = ("%d FPS" % Engine.get_frames_per_second()) if bool(Game.settings.show_fps) else ""
	_update_quest_progress()


func _update_quest() -> void:
	_update_quest_progress()
	if panel_name == "quests":
		_rebuild_panel()


func _update_quest_progress() -> void:
	var q := Game.current_quest()
	if q.is_empty():
		quest_lbl.text = "All quests complete! Keep growing your empire."
		quest_bar.value = 1.0
		quest_reward.text = ""
		return
	var v := Game.stat_value(q.stat)
	quest_lbl.text = String(q.desc)
	quest_bar.value = clampf(v / float(q.target), 0.0, 1.0)
	quest_reward.text = "%s / %s     reward %s" % [Util.fmt(minf(v, float(q.target))), Util.fmt(float(q.target)), Util.money(float(q.reward))]


func _on_data_changed() -> void:
	_refresh_cards_state()
	if panel_name in ["upgrades", "land", "ascend"]:
		_rebuild_panel()


func _process(delta: float) -> void:
	_tick += delta
	if _tick >= 0.1:
		_tick = 0.0
		_update_top()
		var f := Engine.get_process_frames()
		if f % 5 == 0:
			_refresh_cards_state()
			_tick_orders()
			refresh_inspector()
	if modal.visible and panel_name in ["upgrades", "land", "ascend", "market", "orders"] and Engine.get_process_frames() % 30 == 0:
		_rebuild_panel()


# ------------------------------------------------------------ modal panels

func toggle_panel(name: String) -> void:
	if modal.visible and panel_name == name:
		close_panel()
	else:
		open_panel(name)


func toggle_menu() -> void:
	if modal.visible:
		close_panel()
	else:
		open_panel("menu")


func open_panel(name: String) -> void:
	panel_name = name
	modal.visible = true
	_confirm_reset = false
	modal_scroll.scroll_vertical = 0
	_rebuild_panel()


func close_panel() -> void:
	modal.visible = false
	panel_name = ""


func _rebuild_panel() -> void:
	var keep := modal_scroll.scroll_vertical
	for c in modal_body.get_children():
		modal_body.remove_child(c)
		c.queue_free()
	match panel_name:
		"upgrades": _p_upgrades()
		"land": _p_land()
		"quests": _p_quests()
		"orders": _p_orders()
		"market": _p_market()
		"ascend": _p_ascend()
		"menu": _p_menu()
		"help": _p_help()
		"blueprints": _p_blueprints()
	modal_scroll.set_deferred("scroll_vertical", keep)


func _row_panel() -> HBoxContainer:
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", _flat(C_CARD, 10, 10))
	modal_body.add_child(pc)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	pc.add_child(h)
	return h


func _wrap(text: String, size: int = 14, color: Color = C_MUTED) -> Label:
	var l := _label(text, size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 690
	return l


func _p_upgrades() -> void:
	modal_title.text = "Upgrades"
	var qr := HBoxContainer.new()
	qr.add_theme_constant_override("separation", 6)
	qr.add_child(_label("Buy amount ", 14, C_MUTED))
	for q in [[1, "x1"], [10, "x10"], [-1, "Max"]]:
		var qty: int = q[0]
		var b := _button(String(q[1]), func():
			buy_qty = qty
			_rebuild_panel(), 56)
		b.modulate = C_ACCENT if buy_qty == qty else Color.WHITE
		qr.add_child(b)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	qr.add_child(spacer)
	qr.add_child(_label(Util.money(Game.money), 18, C_ACCENT, font_title))
	modal_body.add_child(qr)
	for id in Defs.UPGRADE_ORDER:
		var d: Dictionary = Defs.UPGRADES[id]
		var lvl := Game.upg(id)
		var maxed := lvl >= int(d.max)
		var h := _row_panel()
		var v := VBoxContainer.new()
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var t := HBoxContainer.new()
		t.add_child(_label(String(d.name), 17, Color.WHITE, font_bold))
		t.add_child(_label("   Lv %d / %d" % [lvl, d.max], 13, C_ACCENT))
		v.add_child(t)
		v.add_child(_label(String(d.desc) + "    " + _upgrade_now(id), 13, C_MUTED))
		var pb := _bar(380, 5, C_ACCENT)
		pb.value = float(lvl) / float(d.max)
		v.add_child(pb)
		h.add_child(v)
		var n := 1 if buy_qty == 1 else (10 if buy_qty == 10 else maxi(1, Game.upgrade_max_affordable(id)))
		n = mini(n, int(d.max) - lvl)
		var cost := Game.upgrade_cost_n(id, n) if n > 0 else 0.0
		var btn := _button("MAXED" if maxed else "Buy %s %s" % [("x%d" % n) if n > 1 else "", Util.money(cost)], func(): Game.buy_upgrade(id, buy_qty), 170, C_GOOD)
		btn.disabled = maxed or not Game.can_afford(cost)
		h.add_child(btn)


func _upgrade_now(id: String) -> String:
	match id:
		"src_speed": return "Now x%.2f" % Game.src_mult()
		"belt_speed": return "Now x%.2f" % Game.belt_mult()
		"machine_speed": return "Now x%.2f" % Game.machine_mult()
		"sell_value": return "Now x%.2f" % Game.sell_mult()
		"item_cap": return "Now %d items" % Game.item_cap()
		"rich_veins": return "Now +%d%%" % (2 * Game.upg("rich_veins"))
		"marketing": return "Now level %d" % Game.upg("marketing")
		"night_shift": return "Now %d%%" % int(round(Game.offline_eff() * 100.0))
	return ""


func _p_land() -> void:
	modal_title.text = "Land  -  next plot %s" % Util.money(Game.plot_cost())
	modal_body.add_child(_wrap("Buy land next to your island. Each biome unlocks its own trees and ores."))
	var grid := GridContainer.new()
	grid.columns = Defs.PLOT_RADIUS * 2 + 1
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	var cc := CenterContainer.new()
	cc.add_child(grid)
	modal_body.add_child(cc)
	for j in range(-Defs.PLOT_RADIUS, Defs.PLOT_RADIUS + 1):
		for i in range(-Defs.PLOT_RADIUS, Defs.PLOT_RADIUS + 1):
			var p := Vector2i(i, j)
			var biome: String = Defs.plot_biome(p)
			var bd: Dictionary = Defs.BIOMES[biome]
			var b := Button.new()
			b.focus_mode = Control.FOCUS_NONE
			b.custom_minimum_size = Vector2(110, 56)
			var owned := Game.plots.has(p)
			var buyable := Game.can_buy_plot(p)
			var c: Color = bd.top
			if owned:
				b.text = "%s\nOWNED" % bd.name
				b.add_theme_stylebox_override("normal", _flat(c.darkened(0.35), 8, 4, C_ACCENT, 2))
			elif buyable:
				b.text = "%s\n%s" % [bd.name, Util.money(Game.plot_cost())]
				b.add_theme_stylebox_override("normal", _flat(c.darkened(0.6), 8, 4, c, 2))
				b.add_theme_stylebox_override("hover", _flat(c.darkened(0.4), 8, 4, c, 2))
				b.pressed.connect(func(): Game.buy_plot(p))
				if not Game.can_afford(Game.plot_cost()):
					b.modulate = Color(1, 1, 1, 0.7)
			else:
				b.text = "%s\nlocked" % bd.name
				b.add_theme_stylebox_override("normal", _flat(Color(0.1, 0.11, 0.16), 8, 4))
				b.modulate = Color(1, 1, 1, 0.5)
			b.add_theme_font_size_override("font_size", 12)
			grid.add_child(b)
	var legend := "Biomes:  "
	for b in Defs.BIOMES:
		var mats := []
		for m in Defs.MATERIALS:
			if Defs.MATERIALS[m].biome == b:
				mats.append(Defs.MATERIALS[m].name)
		legend += "%s (%s)    " % [Defs.BIOMES[b].name, ", ".join(mats)]
	modal_body.add_child(_wrap(legend, 13))


func _p_quests() -> void:
	modal_title.text = "Quests  (%d / %d)" % [Game.quest_index, Defs.QUESTS.size()]
	for i in Defs.QUESTS.size():
		var q: Dictionary = Defs.QUESTS[i]
		var h := _row_panel()
		var done := i < Game.quest_index
		var cur := i == Game.quest_index
		var mark := "DONE" if done else ("NOW" if cur else "")
		var col := Color(1, 1, 1, 0.4) if done else (C_ACCENT if cur else Color(1, 1, 1, 0.85))
		var m := _label(mark, 11, C_GOOD if done else C_ACCENT, font_bold)
		m.custom_minimum_size.x = 40
		h.add_child(m)
		var l := _label(String(q.desc), 15, col)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(l)
		h.add_child(_label(Util.money(float(q.reward)), 14, C_GOOD if not done else Color(1, 1, 1, 0.35), font_bold))


func _p_orders() -> void:
	modal_title.text = "Orders board"
	modal_body.add_child(_wrap("Merchants post orders for specific products. Sell matching items at any seller before the timer runs out for a big bonus. A new order arrives every 40 seconds (up to 3)."))
	if Game.orders.is_empty():
		modal_body.add_child(_label("No open orders right now.", 15, C_MUTED))
	for o in Game.orders:
		var h := _row_panel()
		var v := VBoxContainer.new()
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_child(_label("%d x %s" % [int(o.qty), o.name], 17, Color.WHITE, font_bold))
		var pb := _bar(420, 8, C_INFO)
		pb.value = float(o.done) / float(o.qty)
		v.add_child(pb)
		v.add_child(_label("%d delivered   -   %s left" % [int(o.done), _fmt_clock(float(o.time))], 13, C_MUTED))
		h.add_child(v)
		h.add_child(_label(Util.money(float(o.reward)), 20, C_GOOD, font_title))
	modal_body.add_child(HSeparator.new())
	modal_body.add_child(_label("Orders completed: %d" % int(Game.stats.get("orders", 0)), 14, C_MUTED))


func _p_market() -> void:
	modal_title.text = "Market"
	modal_body.add_child(_wrap("Each product's price drops a little every time you sell it and recovers over time. Spread production over different products, pack items into crates (a crate counts as one sale) and buy Marketing upgrades to keep prices high."))
	var keys: Array = Game.demand_map.keys()
	keys.sort_custom(func(a, b): return float(Game.demand_map[a]) < float(Game.demand_map[b]))
	if keys.is_empty():
		modal_body.add_child(_label("All products are selling at full price.", 15, C_GOOD))
	for k in keys:
		var d: float = Game.demand_map[k]
		var h := _row_panel()
		var name := "Crate"
		if String(k) != "crate":
			var parts := String(k).split(":")
			name = Defs.product_name(parts[0], parts[1])
		var l := _label(name, 15, Color.WHITE, font_bold)
		l.custom_minimum_size.x = 240
		h.add_child(l)
		var col := C_GOOD if d > 0.8 else (C_ACCENT if d > 0.5 else C_BAD)
		var pb := _bar(300, 10, col)
		pb.value = d
		pb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(pb)
		h.add_child(_label("%d%% price" % int(d * 100.0), 14, col, font_bold))
	modal_body.add_child(HSeparator.new())
	var fs := "Sold so far:  "
	for f in Game.forms_sold:
		fs += "%s %s   " % [Util.fmt(float(Game.forms_sold[f])), Defs.FORM_NAMES.get(f, f)]
	modal_body.add_child(_wrap(fs, 13))


func _p_ascend() -> void:
	modal_title.text = "Ascension"
	var gain := Game.ascend_gain()
	var next_total := Game.stars + gain + 1
	var need := float(next_total * next_total) * 2000000.0
	var t := "Ascending resets your money, buildings, land and upgrades. You keep unlocked blueprints, factory level, quests and saved blueprints.\n\nEach Ascension Star permanently adds +25% sell value and +$250 starting cash.\n\n"
	t += "Stars: %d  (income x%.2f)\nStars gained by ascending now: %d\nLifetime earnings: %s\nNext star at lifetime earnings of %s" % [Game.stars, Game.star_mult(), gain, Util.money(Game.lifetime), Util.money(need)]
	modal_body.add_child(_wrap(t, 16, Color.WHITE))
	var b := _button("ASCEND  (+%d stars)" % gain, func():
		Game.ascend()
		close_panel(), 260, Color("ff7ad9"))
	b.disabled = gain <= 0
	modal_body.add_child(b)


func _p_menu() -> void:
	modal_title.text = "Menu"
	modal_body.add_child(_button("Save game now", func():
		Game.save_game()
		show_toast("Game saved", C_GOOD), 260))
	for e in [["shadows", "Shadows"], ["show_fps", "Show FPS"]]:
		var key: String = e[0]
		var cb := CheckButton.new()
		cb.text = String(e[1])
		cb.button_pressed = bool(Game.settings[key])
		cb.focus_mode = Control.FOCUS_NONE
		cb.toggled.connect(func(v): Game.set_setting(key, v))
		modal_body.add_child(cb)
	for e in [["volume", "Sound volume"], ["music", "Music volume"]]:
		var key: String = e[0]
		var vr := HBoxContainer.new()
		var lab := _label(String(e[1]), 15)
		lab.custom_minimum_size.x = 130
		vr.add_child(lab)
		var sl := HSlider.new()
		sl.min_value = 0.0
		sl.max_value = 1.0
		sl.step = 0.05
		sl.value = float(Game.settings.get(key, 0.5))
		sl.custom_minimum_size.x = 240
		sl.value_changed.connect(func(v): Game.set_setting(key, v))
		vr.add_child(sl)
		modal_body.add_child(vr)
	modal_body.add_child(_button("How to play [H]", func(): open_panel("help"), 260))
	modal_body.add_child(HSeparator.new())
	modal_body.add_child(_button("Clear all parts (refund)", func():
		world.clear_all(true)
		show_toast("Factory cleared, parts refunded", C_GOOD), 260))
	modal_body.add_child(_button("Really delete save? Click again" if _confirm_reset else "New game (delete save)", func():
		if _confirm_reset:
			Game.new_game()
			close_panel()
			show_toast("Fresh start!", C_GOOD)
		else:
			_confirm_reset = true
			_rebuild_panel(), 260, C_BAD))


func _p_help() -> void:
	modal_title.text = "How to play"
	var t := """[font_size=17][color=#ffcf4a]Everything is physical.[/color][/font_size] Trees topple real logs, drills drop real boulders, and machines work on the actual shape of each piece: a saw cuts exactly where its blade meets the item, a press flattens metal (same volume, new shape), a crusher really breaks rocks into fragments, a sieve lets small pieces fall through its bars.

[color=#8fd0ff]Value[/color] = material price x volume x form bonus x quality x market demand. Turn raw resources into better forms:
  [b]Wood[/b]: Log (x1) -> Rip Saw -> Timber (x1.4) -> rip again with offset blades / Gang Saw -> Plank (x2.6, thinnest side <= 0.09)
  [b]Ore[/b]: Boulder -> Crusher -> Chunks -> (Washer: +purity) -> Furnace -> Ingot (x3) -> Press -> Plate (x4.2) -> Press -> Sheet (x5.5)
  [b]Gems[/b]: Geode -> Crusher frees pure Shards (x1.8) -> Polisher -> Polished Gem (x4.5)
  [b]Crate Packer[/b]: N items -> 1 crate worth +30%, counted once by the market.

[color=#8fd0ff]Building[/color]
  - Pick parts on the bar (1-9, Tab next category). Click to place, drag to paint lines (belts auto-turn), Shift+drag to fill.
  - R rotates, Z / X (or Ctrl+wheel) change the build layer. Drills drop straight down, so put them above a belt.
  - Belt side guards open automatically where another belt feeds in from the side.
  - Click any placed part to inspect it: change settings (saw offset, timer, filters, channels), upgrade, rotate or wire it.

[color=#8fd0ff]Wiring[/color] (Wire tool, N): click a part with an OUTPUT, then a part with an INPUT.
  Levers, buttons, timers, item sensors, logic gates, counters and sellers (one pulse per sale) send signals. Machines with a wired input only run while powered; saws, presses and pistons fire on each pulse. Sensor + Piston = sorter. Timer + Counter + gates = anything you can imagine.

[color=#8fd0ff]Scaling[/color]  Select (B) + Copy (C) + Paste (V) copies parts, settings and wires. Upgrade (G) levels parts, Shift+drag for whole areas. Teleporters move items across the island. Buy land [L], global upgrades [U], fill orders [O], watch the market [M], and Ascend [P] for permanent stars.

[color=#8fd0ff]Camera[/color]  WASD pan, Q/E rotate, wheel zoom, right-drag orbit, middle-drag pan, Shift = faster. Right-click or Esc cancels."""
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.text = t
	r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.custom_minimum_size.x = 690
	r.add_theme_font_override("normal_font", font_body)
	r.add_theme_font_override("bold_font", font_bold)
	r.add_theme_font_size_override("normal_font_size", 15)
	r.add_theme_font_size_override("bold_font_size", 15)
	modal_body.add_child(r)


func _p_blueprints() -> void:
	modal_title.text = "Blueprints"
	modal_body.add_child(_wrap("Copy a design with Select (B) + C (parts, their settings and wires), then save it to a slot. Load a slot to paste it anywhere, even after ascending."))
	modal_body.add_child(_label("Clipboard: %d parts, %d wires" % [builder.clipboard.size(), builder.clip_links.size()], 15, C_ACCENT, font_bold))
	for s in range(1, 9):
		var key := str(s)
		var h := _row_panel()
		var data: Variant = Game.blueprints.get(key, {})
		var count := 0
		if data is Dictionary:
			count = (data.get("parts", []) as Array).size()
		elif data is Array:
			count = (data as Array).size()
		var name_l := _label("Slot %d  -  %s" % [s, ("%d parts" % count) if count > 0 else "empty"], 16, Color.WHITE, font_bold)
		name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(name_l)
		h.add_child(_button("Save clipboard", func():
			if builder.clipboard.is_empty():
				show_toast("Clipboard is empty", C_BAD)
				return
			Game.blueprints[key] = builder.export_clipboard()
			Game.save_game()
			_rebuild_panel(), 150))
		var ld := _button("Load & paste", func():
			builder.import_clipboard(Game.blueprints.get(key, {}))
			close_panel(), 150, C_INFO)
		ld.disabled = count == 0
		h.add_child(ld)
