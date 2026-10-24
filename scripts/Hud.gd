class_name Hud
extends CanvasLayer
## All UI is built in code: top bars, build hotbar, modal panels, toasts, tooltips.

const C_BG := Color(0.09, 0.12, 0.2, 0.93)
const C_BG2 := Color(0.14, 0.18, 0.3, 0.97)
const C_ACCENT := Color("ffcf4a")
const C_GOOD := Color("7aff9a")
const C_BAD := Color("ff7a7a")

var world: Node
var builder: Builder
var root: Control
var theme_res: Theme

var money_lbl: Label
var income_lbl: Label
var items_lbl: Label
var level_lbl: Label
var xp_bar: ProgressBar
var stars_lbl: Label
var quest_lbl: Label
var quest_bar: ProgressBar
var fps_lbl: Label

var cat_row: HBoxContainer
var card_row: HBoxContainer
var info_lbl: Label
var tip: Label
var toast_box: VBoxContainer

var modal: PanelContainer
var modal_title: Label
var modal_body: VBoxContainer
var modal_scroll: ScrollContainer
var panel_name := ""

var cur_cat := "droppers"
var buy_qty := 1
var _tick := 0.0
var _confirm_reset := false
var _speed_btns: Array[Button] = []
var _qty_btns: Array[Button] = []
var _slot_cache: Array = []


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
	_build_bottom()
	_build_modal()
	_build_toasts()
	tip = Label.new()
	tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tip.add_theme_stylebox_override("normal", _flat(Color(0.05, 0.07, 0.12, 0.92), 6, 8))
	tip.visible = false
	root.add_child(tip)
	Game.toast.connect(show_toast)
	Game.quests_changed.connect(_update_quest)
	Game.unlocks_changed.connect(refresh_hotbar)
	Game.upgrades_changed.connect(_on_data_changed)
	Game.plots_changed.connect(_on_data_changed)
	Game.stars_changed.connect(_on_data_changed)
	builder.mode_changed.connect(_on_mode_changed)
	refresh_hotbar()
	_update_quest()
	_update_top()
	if not Game.offline_report.is_empty():
		var rep: Dictionary = Game.offline_report
		show_toast("Welcome back! Your factory earned %s while you were away (%s)." % [Util.money(rep.earned), _fmt_time(rep.seconds)], C_GOOD, 6.0)
	if not bool(Game.settings.seen_help):
		Game.set_setting("seen_help", true)
		open_panel("help")


# ------------------------------------------------------------ styling

func _flat(c: Color, radius: int = 8, pad: int = 8, border: Color = Color(0, 0, 0, 0), bw: int = 0) -> StyleBoxFlat:
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
	return s


func _make_theme() -> void:
	theme_res = Theme.new()
	theme_res.default_font_size = 15
	theme_res.set_color("font_color", "Label", Color.WHITE)
	theme_res.set_stylebox("panel", "PanelContainer", _flat(C_BG, 10, 10, Color(1, 1, 1, 0.08), 1))
	theme_res.set_stylebox("normal", "Button", _flat(Color("2b3a63"), 8, 10))
	theme_res.set_stylebox("hover", "Button", _flat(Color("3a4d85"), 8, 10))
	theme_res.set_stylebox("pressed", "Button", _flat(Color("4c63a8"), 8, 10))
	theme_res.set_stylebox("disabled", "Button", _flat(Color("20263a"), 8, 10))
	theme_res.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	theme_res.set_color("font_color", "Button", Color.WHITE)
	theme_res.set_color("font_disabled_color", "Button", Color(1, 1, 1, 0.4))
	theme_res.set_stylebox("background", "ProgressBar", _flat(Color(0, 0, 0, 0.45), 6, 2))
	theme_res.set_stylebox("fill", "ProgressBar", _flat(C_ACCENT, 6, 2))


func _label(text: String, size: int = 15, color: Color = Color.WHITE) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _button(text: String, cb: Callable, min_w: float = 0.0) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	if min_w > 0.0:
		b.custom_minimum_size.x = min_w
	b.pressed.connect(func():
		FX.play("click")
		cb.call())
	return b


# ------------------------------------------------------------ layout

func _build_top_left() -> void:
	var p := PanelContainer.new()
	p.position = Vector2(12, 12)
	root.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 3)
	p.add_child(v)
	money_lbl = _label("$0", 30, C_ACCENT)
	v.add_child(money_lbl)
	income_lbl = _label("+$0/s", 15, C_GOOD)
	v.add_child(income_lbl)
	var lr := HBoxContainer.new()
	level_lbl = _label("Lv 0", 15)
	lr.add_child(level_lbl)
	stars_lbl = _label("", 15, Color("ffb3ff"))
	lr.add_child(stars_lbl)
	lr.add_theme_constant_override("separation", 12)
	v.add_child(lr)
	xp_bar = ProgressBar.new()
	xp_bar.custom_minimum_size = Vector2(230, 10)
	xp_bar.max_value = 1.0
	xp_bar.show_percentage = false
	v.add_child(xp_bar)
	items_lbl = _label("Items 0/0", 13, Color(1, 1, 1, 0.65))
	v.add_child(items_lbl)
	var sep := HSeparator.new()
	v.add_child(sep)
	quest_lbl = _label("", 14, Color("c9d6ff"))
	quest_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	quest_lbl.custom_minimum_size.x = 230
	v.add_child(quest_lbl)
	quest_bar = ProgressBar.new()
	quest_bar.custom_minimum_size = Vector2(230, 8)
	quest_bar.max_value = 1.0
	quest_bar.show_percentage = false
	v.add_child(quest_bar)
	fps_lbl = _label("", 12, Color(1, 1, 1, 0.5))
	v.add_child(fps_lbl)


func _build_top_right() -> void:
	var h := HBoxContainer.new()
	h.anchor_left = 1.0
	h.anchor_right = 1.0
	h.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	h.offset_right = -12
	h.offset_top = 12
	h.add_theme_constant_override("separation", 6)
	root.add_child(h)
	h.add_child(_button("Upgrades [U]", func(): toggle_panel("upgrades")))
	h.add_child(_button("Land [L]", func(): toggle_panel("land")))
	h.add_child(_button("Quests [J]", func(): toggle_panel("quests")))
	h.add_child(_button("Blueprints [F]", func(): toggle_panel("blueprints")))
	h.add_child(_button("Ascend [P]", func(): toggle_panel("ascend")))
	h.add_child(_button("Menu", func(): toggle_menu()))
	for s in [1, 2, 3]:
		var b := _button("%dx" % s, func(): _set_speed(s), 38)
		_speed_btns.append(b)
		h.add_child(b)
	_set_speed(1)


func _set_speed(s: int) -> void:
	Engine.time_scale = float(s)
	for i in _speed_btns.size():
		_speed_btns[i].modulate = C_ACCENT if i == s - 1 else Color.WHITE


func _build_bottom() -> void:
	var v := VBoxContainer.new()
	v.anchor_left = 0.5
	v.anchor_right = 0.5
	v.anchor_top = 1.0
	v.anchor_bottom = 1.0
	v.grow_horizontal = Control.GROW_DIRECTION_BOTH
	v.grow_vertical = Control.GROW_DIRECTION_BEGIN
	v.offset_bottom = -10
	v.add_theme_constant_override("separation", 4)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(v)
	info_lbl = _label("", 14, Color("dfe8ff"))
	info_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info_lbl.add_theme_stylebox_override("normal", _flat(Color(0.05, 0.07, 0.12, 0.8), 8, 10))
	v.add_child(info_lbl)
	var p := PanelContainer.new()
	v.add_child(p)
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 6)
	p.add_child(inner)
	cat_row = HBoxContainer.new()
	cat_row.add_theme_constant_override("separation", 6)
	inner.add_child(cat_row)
	card_row = HBoxContainer.new()
	card_row.add_theme_constant_override("separation", 6)
	card_row.custom_minimum_size.y = 74
	inner.add_child(card_row)


func _build_modal() -> void:
	modal = PanelContainer.new()
	modal.anchor_left = 0.5
	modal.anchor_right = 0.5
	modal.anchor_top = 0.5
	modal.anchor_bottom = 0.5
	modal.grow_horizontal = Control.GROW_DIRECTION_BOTH
	modal.grow_vertical = Control.GROW_DIRECTION_BOTH
	modal.custom_minimum_size = Vector2(700, 440)
	modal.anchor_top = 0.44
	modal.anchor_bottom = 0.44
	modal.add_theme_stylebox_override("panel", _flat(C_BG2, 14, 14, Color(1, 1, 1, 0.12), 1))
	modal.visible = false
	root.add_child(modal)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	modal.add_child(v)
	var head := HBoxContainer.new()
	modal_title = _label("", 22, C_ACCENT)
	modal_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(modal_title)
	head.add_child(_button("Close [Esc]", func(): close_panel()))
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
	toast_box.offset_top = 14
	toast_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_box.alignment = BoxContainer.ALIGNMENT_BEGIN
	root.add_child(toast_box)


# ------------------------------------------------------------ toasts / tips

func show_toast(text: String, color: Color = Color.WHITE, life: float = 3.2) -> void:
	var l := _label(text, 16, color)
	l.add_theme_stylebox_override("normal", _flat(Color(0.05, 0.07, 0.12, 0.9), 8, 10))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_box.add_child(l)
	while toast_box.get_child_count() > 4:
		toast_box.get_child(0).queue_free()
		toast_box.remove_child(toast_box.get_child(0))
	var tw := l.create_tween()
	tw.tween_interval(life)
	tw.tween_property(l, "modulate:a", 0.0, 0.5)
	tw.tween_callback(l.queue_free)


func pointer_over_ui() -> bool:
	var vp := get_viewport()
	var c: Control = vp.gui_get_hovered_control()
	return c != null and c != root


func update_hover_info(b: Builder) -> void:
	var text := ""
	if b.mode == "build" or b.mode == "paste":
		text = b.plan_text()
		if b.layer_off > 0:
			text += "   Layer +%d" % b.layer_off
	elif b.hover_part != null:
		text = b.hover_part.info_text()
	if text == "" or pointer_over_ui():
		tip.visible = false
	else:
		tip.visible = true
		tip.text = text
		tip.reset_size()
		var mp := root.get_local_mouse_position()
		tip.position = mp + Vector2(18, 18)


func _on_mode_changed() -> void:
	_update_info_line()
	_refresh_cards_state()


func _update_info_line() -> void:
	match builder.mode:
		"build":
			var d: Dictionary = Defs.PARTS[builder.part_id]
			info_lbl.text = "%s  -  %s   |  R rotate, drag to paint, Shift+drag to fill, Z/X layer, RMB cancel" % [d.name, _part_blurb(builder.part_id)]
		"demolish":
			info_lbl.text = "DEMOLISH  -  click/drag to remove (full refund), Shift+drag for an area, RMB cancel"
		"upgrade":
			info_lbl.text = "UPGRADE  -  click a part (Ctrl = max out), Shift+drag to upgrade an area, RMB cancel"
		"select":
			info_lbl.text = "SELECT  -  drag a rectangle (all layers), then C to copy / G to upgrade / Delete to remove"
		"paste":
			info_lbl.text = "PASTE  -  click to place the blueprint, R rotates, RMB cancel"
		_:
			info_lbl.text = "Pick a part below (keys 1-9, Tab for category). Drag mouse to paint lines, Shift+drag to fill."


func _part_blurb(id: String) -> String:
	var d: Dictionary = Defs.PARTS[id]
	match String(d.kind):
		"dropper":
			var r: Dictionary = Defs.RESOURCES[d.res]
			return "drops %s worth %s" % [r.name, Util.money(float(r.value))]
		"belt": return "moves items at %.1f u/s" % float(d.speed)
		"splitter": return "alternates items between left, forward and right outputs"
		"ramp": return "lifts items up one layer"
		"processor": return "multiplies item value x%.1f" % float(d.mult)
		"seller": return "sells items at x%.1f" % float(d.mult)
		"block": return "solid support block"
	return ""


# ------------------------------------------------------------ hotbar

func refresh_hotbar() -> void:
	for c in cat_row.get_children():
		cat_row.remove_child(c)
		c.queue_free()
	for cat in Defs.CATEGORIES:
		var cid: String = cat.id
		var b := _button(String(cat.name), func(): _set_cat(cid))
		b.modulate = C_ACCENT if cid == cur_cat else Color.WHITE
		cat_row.add_child(b)
	cat_row.add_child(_spacer(16))
	var tools := [
		["Demolish [T]", func(): builder.set_mode("demolish")],
		["Upgrade [G]", func(): builder.set_mode("upgrade")],
		["Select [B]", func(): builder.set_mode("select")],
		["Copy [C]", func(): builder.copy_selection()],
		["Paste [V]", func(): builder.paste_mode()],
	]
	for t in tools:
		cat_row.add_child(_button(t[0], t[1]))
	_rebuild_cards()
	_update_info_line()


func _spacer(w: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size.x = w
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


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
	_slot_cache = _cat_parts()
	var n := 0
	for id in _slot_cache:
		n += 1
		card_row.add_child(_make_card(id, n))


func _make_card(id: String, slot: int) -> Button:
	var d: Dictionary = Defs.PARTS[id]
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(104, 70)
	b.set_meta("part_id", id)
	b.pressed.connect(func():
		FX.play("click")
		builder.select_part(id))
	_style_card(b)
	return b


func _card_color(id: String) -> Color:
	var d: Dictionary = Defs.PARTS[id]
	match String(d.kind):
		"dropper": return (Defs.RESOURCES[d.res].color as Color)
		"belt", "ramp", "processor", "seller", "splitter": return d.tint
	return Color("8a93a8")


func _style_card(b: Button) -> void:
	var id: String = b.get_meta("part_id")
	var d: Dictionary = Defs.PARTS[id]
	var c := _card_color(id)
	var unlocked := Game.part_unlocked(id)
	var cost := Game.part_cost(id)
	var slot := _slot_cache.find(id) + 1
	var txt := "[%d] %s\n" % [slot, d.name]
	if unlocked:
		txt += Util.money(cost)
	else:
		var reason := Game.unlock_block_reason(id)
		if reason != "":
			txt += reason
		else:
			txt += "Unlock " + Util.money(float(d.unlock))
	b.text = txt
	b.add_theme_font_size_override("font_size", 13)
	var selected := builder.mode == "build" and builder.part_id == id
	var bg := c.darkened(0.62) if unlocked else Color(0.14, 0.15, 0.2)
	var border := C_ACCENT if selected else c.darkened(0.2)
	var bw := 3 if selected else 2
	b.add_theme_stylebox_override("normal", _flat(bg, 8, 6, border, bw))
	b.add_theme_stylebox_override("hover", _flat(bg.lightened(0.15), 8, 6, border.lightened(0.2), bw))
	b.add_theme_stylebox_override("pressed", _flat(bg.lightened(0.25), 8, 6, border, bw))
	var afford := unlocked and Game.can_afford(cost) or (not unlocked and Game.unlock_block_reason(id) == "" and Game.can_afford(float(d.unlock)))
	b.add_theme_color_override("font_color", Color.WHITE if afford else Color(1, 1, 1, 0.5))
	b.add_theme_color_override("font_hover_color", Color.WHITE)


func _refresh_cards_state() -> void:
	for b in card_row.get_children():
		if b is Button and b.has_meta("part_id"):
			_style_card(b)


# ------------------------------------------------------------ top bar updates

func _fmt_time(sec: float) -> String:
	var s := int(sec)
	if s >= 3600:
		return "%dh %dm" % [s / 3600, (s % 3600) / 60]
	return "%dm" % maxi(1, s / 60)


func _update_top() -> void:
	money_lbl.text = Util.money(Game.money)
	income_lbl.text = "+%s/s" % Util.money(Game.income_rate)
	level_lbl.text = "Level %d" % Game.level
	xp_bar.value = Game.level_progress()
	stars_lbl.text = ("%d stars  x%.2f" % [Game.stars, Game.star_mult()]) if Game.stars > 0 else ""
	items_lbl.text = "Items %d / %d    Parts %d" % [world.active_items.size(), Game.item_cap(), world.parts.size()]
	if bool(Game.settings.show_fps):
		fps_lbl.text = "%d FPS" % Engine.get_frames_per_second()
	else:
		fps_lbl.text = ""
	_update_quest_progress()


func _update_quest() -> void:
	_update_quest_progress()
	if panel_name == "quests":
		_rebuild_panel()


func _update_quest_progress() -> void:
	var q := Game.current_quest()
	if q.is_empty():
		quest_lbl.text = "All quests complete!"
		quest_bar.value = 1.0
		return
	var v := Game.stat_value(q.stat)
	quest_lbl.text = "Quest: %s\n%s / %s" % [q.desc, Util.fmt(minf(v, float(q.target))), Util.fmt(float(q.target))]
	quest_bar.value = clampf(v / float(q.target), 0.0, 1.0)


func _on_data_changed() -> void:
	_refresh_cards_state()
	if panel_name in ["upgrades", "land", "ascend"]:
		_rebuild_panel()


func _process(delta: float) -> void:
	_tick += delta
	if _tick >= 0.1:
		_tick = 0.0
		_update_top()
		if Engine.get_process_frames() % 5 == 0:
			_refresh_cards_state()
	if modal.visible and panel_name in ["upgrades", "land", "ascend"] and Engine.get_process_frames() % 20 == 0:
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
		"ascend": _p_ascend()
		"menu": _p_menu()
		"help": _p_help()
		"blueprints": _p_blueprints()
	modal_scroll.set_deferred("scroll_vertical", keep)


func _row_panel() -> HBoxContainer:
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", _flat(Color(1, 1, 1, 0.05), 8, 8))
	modal_body.add_child(pc)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	pc.add_child(h)
	return h


func _p_upgrades() -> void:
	modal_title.text = "Upgrades  -  %s" % Util.money(Game.money)
	var qr := HBoxContainer.new()
	qr.add_child(_label("Buy amount:", 14, Color(1, 1, 1, 0.7)))
	for q in [[1, "x1"], [10, "x10"], [-1, "Max"]]:
		var qty: int = q[0]
		var b := _button(String(q[1]), func():
			buy_qty = qty
			_rebuild_panel(), 56)
		b.modulate = C_ACCENT if buy_qty == qty else Color.WHITE
		qr.add_child(b)
	modal_body.add_child(qr)
	for id in Defs.UPGRADE_ORDER:
		var d: Dictionary = Defs.UPGRADES[id]
		var lvl := Game.upg(id)
		var maxed := lvl >= int(d.max)
		var h := _row_panel()
		var v := VBoxContainer.new()
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_child(_label("%s   Lv %d / %d" % [d.name, lvl, d.max], 16))
		v.add_child(_label(String(d.desc) + "   " + _upgrade_now(id), 13, Color(1, 1, 1, 0.65)))
		h.add_child(v)
		var n := 1 if buy_qty == 1 else (10 if buy_qty == 10 else maxi(1, Game.upgrade_max_affordable(id)))
		n = mini(n, int(d.max) - lvl)
		var cost := Game.upgrade_cost_n(id, n) if n > 0 else 0.0
		var btn := _button("MAXED" if maxed else "Buy %s  %s" % [("x%d" % n) if n > 1 else "", Util.money(cost)], func(): Game.buy_upgrade(id, buy_qty), 150)
		btn.disabled = maxed or not Game.can_afford(cost)
		h.add_child(btn)


func _upgrade_now(id: String) -> String:
	match id:
		"drop_speed": return "Now x%.2f" % Game.drop_rate_mult()
		"belt_speed": return "Now x%.2f" % Game.belt_mult()
		"sell_value": return "Now x%.2f" % Game.sell_mult()
		"proc_power": return "Now +%d%%" % int(round((Game.proc_mult(1.0) - 1.0) * 100.0))
		"item_cap": return "Now %d" % Game.item_cap()
		"lucky": return "Now %d%%" % int(round(Game.lucky_chance() * 100.0))
		"night_shift": return "Now %d%%" % int(round(Game.offline_eff() * 100.0))
	return ""


func _p_land() -> void:
	modal_title.text = "Land  -  next plot %s" % Util.money(Game.plot_cost())
	modal_body.add_child(_label("Buy land adjacent to your island. Each biome unlocks its resource droppers.", 14, Color(1, 1, 1, 0.7)))
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
			b.custom_minimum_size = Vector2(96, 52)
			var owned := Game.plots.has(p)
			var buyable := Game.can_buy_plot(p)
			var c: Color = bd.top
			if owned:
				b.text = "%s\nOWNED" % bd.name
				b.add_theme_stylebox_override("normal", _flat(c.darkened(0.35), 6, 4, C_ACCENT, 2))
				b.disabled = false
			elif buyable:
				b.text = "%s\n%s" % [bd.name, Util.money(Game.plot_cost())]
				b.add_theme_stylebox_override("normal", _flat(c.darkened(0.55), 6, 4, c, 2))
				b.add_theme_stylebox_override("hover", _flat(c.darkened(0.4), 6, 4, c, 2))
			else:
				b.text = "%s\nlocked" % bd.name
				b.add_theme_stylebox_override("normal", _flat(Color(0.12, 0.13, 0.18), 6, 4))
				b.modulate = Color(1, 1, 1, 0.5)
			b.add_theme_font_size_override("font_size", 12)
			if buyable:
				b.pressed.connect(func():
					Game.buy_plot(p))
				if not Game.can_afford(Game.plot_cost()):
					b.modulate = Color(1, 1, 1, 0.7)
			grid.add_child(b)
	var legend := "Biomes -> droppers:  "
	for rid in Defs.RESOURCES:
		var r: Dictionary = Defs.RESOURCES[rid]
		legend += "%s (%s)   " % [r.name, Defs.BIOMES[r.biome].name]
	var l := _label(legend, 13, Color(1, 1, 1, 0.75))
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	modal_body.add_child(l)


func _p_quests() -> void:
	modal_title.text = "Quests  (%d / %d)" % [Game.quest_index, Defs.QUESTS.size()]
	for i in Defs.QUESTS.size():
		var q: Dictionary = Defs.QUESTS[i]
		var h := _row_panel()
		var done := i < Game.quest_index
		var cur := i == Game.quest_index
		var mark := "[x]" if done else ("[>]" if cur else "[ ]")
		var col := Color(1, 1, 1, 0.4) if done else (C_ACCENT if cur else Color(1, 1, 1, 0.8))
		var l := _label("%s  %s" % [mark, q.desc], 15, col)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(l)
		h.add_child(_label("Reward " + Util.money(float(q.reward)), 14, C_GOOD if not done else Color(1, 1, 1, 0.35)))


func _p_ascend() -> void:
	modal_title.text = "Ascension"
	var gain := Game.ascend_gain()
	var next_total := Game.stars + gain + 1
	var need := float(next_total * next_total) * 2000000.0
	var t := "Ascending resets your money, buildings, land and upgrades, but you keep unlocked blueprints, factory level and quest progress.\n\n"
	t += "Each Ascension Star permanently adds +25%% sell value and +$250 starting cash.\n\n"
	t += "Stars: %d  (income x%.2f)\nStars gained by ascending now: %d\nLifetime earnings: %s\nNext star at lifetime earnings of %s" % [Game.stars, Game.star_mult(), gain, Util.money(Game.lifetime), Util.money(need)]
	var l := _label(t, 16)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	modal_body.add_child(l)
	var b := _button("ASCEND  (+%d stars)" % gain, func():
		Game.ascend()
		close_panel(), 260)
	b.disabled = gain <= 0
	modal_body.add_child(b)


func _p_menu() -> void:
	modal_title.text = "Menu"
	modal_body.add_child(_button("Save game now", func():
		Game.save_game()
		show_toast("Game saved", C_GOOD), 240))
	var sh := CheckButton.new()
	sh.text = "Shadows"
	sh.button_pressed = bool(Game.settings.shadows)
	sh.focus_mode = Control.FOCUS_NONE
	sh.toggled.connect(func(v): Game.set_setting("shadows", v))
	modal_body.add_child(sh)
	var fp := CheckButton.new()
	fp.text = "Show FPS"
	fp.button_pressed = bool(Game.settings.show_fps)
	fp.focus_mode = Control.FOCUS_NONE
	fp.toggled.connect(func(v): Game.set_setting("show_fps", v))
	modal_body.add_child(fp)
	var vr := HBoxContainer.new()
	vr.add_child(_label("Volume  ", 15))
	var sl := HSlider.new()
	sl.min_value = 0.0
	sl.max_value = 1.0
	sl.step = 0.05
	sl.value = float(Game.settings.volume)
	sl.custom_minimum_size.x = 220
	sl.value_changed.connect(func(v): Game.set_setting("volume", v))
	vr.add_child(sl)
	modal_body.add_child(vr)
	modal_body.add_child(_button("Controls / help [H]", func(): open_panel("help"), 240))
	modal_body.add_child(HSeparator.new())
	var rb := _button("Really delete save? Click again" if _confirm_reset else "New game (delete save)", func():
		if _confirm_reset:
			Game.new_game()
			close_panel()
			show_toast("Fresh start!", C_GOOD)
		else:
			_confirm_reset = true
			_rebuild_panel(), 240)
	modal_body.add_child(rb)
	modal_body.add_child(HSeparator.new())
	modal_body.add_child(_button("Clear all parts (refund)", func():
		world.clear_all(true)
		show_toast("Factory cleared, parts refunded", C_GOOD), 240))


func _p_help() -> void:
	modal_title.text = "How to play"
	var t := """[b]Goal[/b]  Build a factory: droppers spawn physical items that fall onto conveyors, run through processors that multiply their value, and end at sellers that pay you.

[b]Build[/b]
  - Pick a part from the bar (keys 1-9, Tab = next category). Left-click to place, drag to paint lines (belts auto-turn), Shift+drag to fill an area.
  - Droppers drop items straight down. Put them one layer above a conveyor: aim at the top of a belt, or raise the layer with Z / X (Ctrl+wheel).
  - R rotates. Ramps lift items one layer so you can stack factories vertically.
  - Processors are belts with a gate: items get a value multiplier once per processor.
  - Right-click or Esc cancels the current tool.

[b]Scale up[/b]
  - Select (B) + drag a rectangle, Copy (C), Paste (V). R rotates the blueprint. Save up to 5 blueprints in the Blueprints panel [F].
  - Demolish (T) refunds 100%. Shift+drag demolishes an area.
  - Upgrades [U] boost every dropper, belt and seller at once. Land [L] adds plots; each biome unlocks new resource droppers.
  - Ascend [P] for permanent star bonuses once you have earned enough.

[b]Camera[/b]  WASD pan, Q/E rotate, mouse wheel zoom, right-drag orbit, middle-drag pan, Shift = faster.

Your factory earns while you are away (offline earnings). The game autosaves every 20 seconds."""
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.text = t
	r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.custom_minimum_size.x = 640
	modal_body.add_child(r)


func _p_blueprints() -> void:
	modal_title.text = "Blueprints"
	var l := _label("Copy a design with Select (B) + C, then save it to a slot. Load a slot to paste it anywhere, any time.", 14, Color(1, 1, 1, 0.7))
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	modal_body.add_child(l)
	modal_body.add_child(_label("Clipboard: %d parts" % builder.clipboard.size(), 15, C_ACCENT))
	for s in range(1, 6):
		var key := str(s)
		var h := _row_panel()
		var data: Array = Game.blueprints.get(key, [])
		var name_l := _label("Slot %d  -  %s" % [s, ("%d parts" % data.size()) if data.size() > 0 else "empty"], 16)
		name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(name_l)
		var sv := _button("Save clipboard", func():
			if builder.clipboard.is_empty():
				show_toast("Clipboard is empty", C_BAD)
				return
			Game.blueprints[key] = builder.export_clipboard()
			_rebuild_panel(), 140)
		h.add_child(sv)
		var ld := _button("Load & paste", func():
			builder.import_clipboard(Game.blueprints.get(key, []))
			close_panel(), 140)
		ld.disabled = data.size() == 0
		h.add_child(ld)
