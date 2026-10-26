class_name SettingsMenu
extends Control
## Esc during play: mouse sensitivity, field of view, volume and graphics. Changes apply as you drag and are
## saved with the game. Esc or Resume goes back to the game.

signal closed

const BG := Color(0.08, 0.09, 0.12, 0.94)
const ACCENT := Color("ffcf6a")
const QUALITY_NAMES := ["Auto", "High", "Medium", "Low", "Lowest"]

var main: Node
var font_body: FontVariation
var font_bold: FontVariation
var font_title: FontVariation


func setup(p_main: Node) -> void:
	main = p_main
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	font_body = _font("res://assets/fonts/Nunito.ttf", 650)
	font_bold = _font("res://assets/fonts/Nunito.ttf", 850)
	font_title = _font("res://assets/fonts/Fredoka.ttf", 600)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.45)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var panel := PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -270
	panel.offset_right = 270
	panel.offset_top = -230
	panel.offset_bottom = 230
	var sb := StyleBoxFlat.new()
	sb.bg_color = BG
	sb.set_corner_radius_all(18)
	for side in ["left", "right", "top", "bottom"]:
		sb.set("content_margin_" + side, 26)
	panel.add_theme_stylebox_override("panel", sb)
	add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 16)
	panel.add_child(v)
	var head := HBoxContainer.new()
	v.add_child(head)
	var t := _label("Paused", 34, ACCENT, font_title)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	head.add_child(_label("[Esc] resume", 14, Color(1, 1, 1, 0.55)))
	var s: Dictionary = Game.settings
	v.add_child(_slider("Mouse sensitivity", 0.2, 3.0, float(s.sens), func(x): _change("sens", x), "%.1fx"))
	v.add_child(_slider("Field of view", 60.0, 100.0, float(s.fov), func(x): _change("fov", x), "%d°"))
	v.add_child(_slider("Volume", 0.0, 1.0, float(s.volume), func(x): _change("volume", x), "%d%%", 100.0))
	var row := HBoxContainer.new()
	row.add_child(_label("Graphics", 17, Color.WHITE, font_bold))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(sp)
	var opt := OptionButton.new()
	opt.focus_mode = Control.FOCUS_NONE
	opt.add_theme_font_override("font", font_bold)
	for n in QUALITY_NAMES:
		opt.add_item(n)
	opt.selected = 0 if bool(s.auto_quality) else Game.quality + 1
	opt.custom_minimum_size.x = 170
	opt.item_selected.connect(func(i):
		Game.settings.auto_quality = i == 0
		if i > 0:
			_quality(i - 1)
		Game.save_game())
	row.add_child(opt)
	v.add_child(row)
	v.add_child(_label("Auto turns graphics down by itself if the game runs slowly.", 13, Color(1, 1, 1, 0.5)))
	var resume := Button.new()
	resume.text = "Resume"
	resume.focus_mode = Control.FOCUS_NONE
	resume.add_theme_font_override("font", font_bold)
	resume.add_theme_font_size_override("font_size", 20)
	resume.custom_minimum_size.y = 46
	for st in ["normal", "hover", "pressed"]:
		var bs := StyleBoxFlat.new()
		bs.bg_color = ACCENT if st == "normal" else (ACCENT.lightened(0.15) if st == "hover" else ACCENT.darkened(0.1))
		bs.set_corner_radius_all(12)
		resume.add_theme_stylebox_override(st, bs)
	resume.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	for c in ["font_color", "font_hover_color", "font_pressed_color"]:
		resume.add_theme_color_override(c, Color("2b2118"))
	resume.pressed.connect(func():
		Sfx.play("click")
		closed.emit())
	v.add_child(resume)


## Applies the saved settings to the game (on start and whenever one changes).
static func apply_all(p_main: Node) -> void:
	var s: Dictionary = Game.settings
	var player: Player = p_main.get("player")
	if player != null:
		player.mouse_sens = 0.0025 * float(s.sens)
		player.cam.fov = float(s.fov)
	Sfx.set_volume(float(s.volume))


func _change(k: String, x: float) -> void:
	Game.settings[k] = x
	apply_all(main)


func _quality(level: int) -> void:
	var q := main.get_node_or_null("Quality") as Quality
	if q != null:
		q.apply(level)


func _slider(title: String, lo: float, hi: float, val: float, cb: Callable, fmt: String, show_scale := 1.0) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	var row := HBoxContainer.new()
	row.add_child(_label(title, 17, Color.WHITE, font_bold))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(sp)
	var value := _label(fmt % (val * show_scale), 15, ACCENT, font_bold)
	row.add_child(value)
	box.add_child(row)
	var sl := HSlider.new()
	sl.min_value = lo
	sl.max_value = hi
	sl.step = (hi - lo) / 100.0
	sl.value = val
	sl.focus_mode = Control.FOCUS_NONE
	sl.value_changed.connect(func(x):
		value.text = fmt % (x * show_scale)
		cb.call(x))
	sl.drag_ended.connect(func(_c): Game.save_game())
	box.add_child(sl)
	return box


func _font(path: String, weight: int) -> FontVariation:
	var f := FontVariation.new()
	f.base_font = load(path)
	f.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): weight}
	return f


func _label(t: String, size: int, c: Color, f: Font = null) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_override("font", f if f else font_body)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", c)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		closed.emit()
