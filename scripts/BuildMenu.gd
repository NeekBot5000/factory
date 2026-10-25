class_name BuildMenu
extends Control
## The hammer's build menu: categories down the side, big preview cards on the right. Click a card to start
## placing it. Esc / E closes.

signal closed

const BG := Color(0.08, 0.09, 0.12, 0.94)
const CARD := Color(1, 1, 1, 0.06)
const CARD_HOVER := Color(1, 0.81, 0.42, 0.22)
const ACCENT := Color("ffcf6a")
const RES_COLOR := {"bark": Color("a0703c"), "log": Color("6b4a32"), "leaf": Color("4f9a3c")}

var main: Node
var cat := -1         # index into Builds.CATEGORIES, -1 = all
var font_body: FontVariation
var font_bold: FontVariation
var font_title: FontVariation
var _grid: GridContainer
var _side: VBoxContainer


func setup(p_main: Node) -> void:
	main = p_main
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	font_body = _font("res://assets/fonts/Nunito.ttf", 650)
	font_bold = _font("res://assets/fonts/Nunito.ttf", 850)
	font_title = _font("res://assets/fonts/Fredoka.ttf", 600)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.35)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var panel := PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -560
	panel.offset_right = 560
	panel.offset_top = -320
	panel.offset_bottom = 320
	panel.add_theme_stylebox_override("panel", _flat(BG, 18, 22))
	add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	panel.add_child(v)
	var head := HBoxContainer.new()
	v.add_child(head)
	var t := _label("Build", 34, ACCENT, font_title)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	head.add_child(_label("Pick a plan, then drop the materials into its hologram.   [Esc] close", 14, Color(1, 1, 1, 0.55)))
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 18)
	v.add_child(body)
	_side = VBoxContainer.new()
	_side.custom_minimum_size.x = 190
	_side.add_theme_constant_override("separation", 8)
	body.add_child(_side)
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	_grid = GridContainer.new()
	_grid.columns = 3
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.add_theme_constant_override("h_separation", 14)
	_grid.add_theme_constant_override("v_separation", 14)
	scroll.add_child(_grid)
	if main.icons != null:
		main.icons.icon_ready.connect(func(_id): _render())
	_render()


func _font(path: String, weight: int) -> FontVariation:
	var f := FontVariation.new()
	f.base_font = load(path)
	f.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): weight}
	return f


func _flat(c: Color, r: int, pad: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = c
	s.set_corner_radius_all(r)
	s.content_margin_left = pad
	s.content_margin_right = pad
	s.content_margin_top = pad
	s.content_margin_bottom = pad
	return s


func _label(t: String, size: int, c: Color, f: Font = null) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_override("font", f if f else font_body)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", c)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _button(t: String, on: bool, cb: Callable) -> Button:
	var b := Button.new()
	b.text = t
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_override("font", font_bold)
	b.add_theme_font_size_override("font_size", 17)
	var fg := Color("2b2118") if on else Color.WHITE
	for st in ["font_color", "font_hover_color", "font_pressed_color"]:
		b.add_theme_color_override(st, fg)
	b.add_theme_stylebox_override("normal", _flat(ACCENT if on else CARD, 10, 12))
	b.add_theme_stylebox_override("hover", _flat(ACCENT if on else CARD_HOVER, 10, 12))
	b.add_theme_stylebox_override("pressed", _flat(ACCENT.darkened(0.1), 10, 12))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.pressed.connect(func():
		Sfx.play("click")
		cb.call())
	return b


func _items() -> Array:
	if cat < 0:
		return Builds.ORDER
	return Builds.CATEGORIES[cat].items


func _render() -> void:
	for c in _side.get_children():
		c.queue_free()
	for c in _grid.get_children():
		c.queue_free()
	_side.add_child(_button("All  (%d)" % Builds.ORDER.size(), cat < 0, func():
		cat = -1
		_render()))
	for i in Builds.CATEGORIES.size():
		var ci := i
		var c: Dictionary = Builds.CATEGORIES[i]
		_side.add_child(_button("%s  (%d)" % [c.name, (c.items as Array).size()], cat == i, func():
			cat = ci
			_render()))
	for id in _items():
		_grid.add_child(_card(id))


func _card(id: String) -> Control:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(275, 250)
	b.add_theme_stylebox_override("normal", _flat(CARD, 14, 12))
	b.add_theme_stylebox_override("hover", _flat(CARD_HOVER, 14, 12))
	b.add_theme_stylebox_override("pressed", _flat(CARD_HOVER.lightened(0.2), 14, 12))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.pressed.connect(func(): _pick(id))
	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 12)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_theme_constant_override("separation", 6)
	b.add_child(v)
	var pv := PanelContainer.new()
	pv.add_theme_stylebox_override("panel", _flat(Color(1, 1, 1, 0.05), 10, 4))
	pv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pv.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(pv)
	var tex: Texture2D = main.icons.get_icon("build:" + id) if main.icons != null else null
	if tex != null:
		var tr := TextureRect.new()
		tr.texture = tex
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pv.add_child(tr)
	v.add_child(_label(Builds.BUILDS[id].name, 19, Color.WHITE, font_bold))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var needs: Dictionary = Builds.BUILDS[id].needs
	for r in needs:
		var pill := PanelContainer.new()
		pill.add_theme_stylebox_override("panel", _flat(RES_COLOR[r], 8, 6))
		pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pill.add_child(_label("%d %s" % [needs[r], Builds.RES_NAME[r]], 13, Color.WHITE, font_bold))
		row.add_child(pill)
	v.add_child(row)
	return b


func _pick(id: String) -> void:
	Sfx.play("click")
	closed.emit()
	main.player.builder.start(id)


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var k := (event as InputEventKey).keycode
		if k == KEY_ESCAPE or k == KEY_E or k == KEY_Q:
			get_viewport().set_input_as_handled()
			closed.emit()
