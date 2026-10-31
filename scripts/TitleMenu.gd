class_name TitleMenu
extends Control
## The first thing you see: the game's name over the forest, and Continue / New Game / Settings.

signal chosen(what: String)

const ACCENT := Color("ffcf6a")

var _confirm: Button
var _font_title: FontVariation
var _font_bold: FontVariation


func setup(has_save: bool) -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_font_title = _font("res://assets/fonts/Fredoka.ttf", 650)
	_font_bold = _font("res://assets/fonts/Nunito.ttf", 850)
	# a soft dark band on the left, the forest visible on the right
	var shade := ColorRect.new()
	shade.color = Color(0.05, 0.06, 0.05, 0.55)
	shade.anchor_bottom = 1.0
	shade.offset_right = 470
	add_child(shade)
	var v := VBoxContainer.new()
	v.anchor_top = 0.5
	v.anchor_bottom = 0.5
	v.offset_left = 64
	v.offset_right = 420
	v.offset_top = -190
	v.offset_bottom = 230
	v.add_theme_constant_override("separation", 14)
	add_child(v)
	var title := Label.new()
	title.text = "Timber"
	title.add_theme_font_override("font", _font_title)
	title.add_theme_font_size_override("font_size", 86)
	title.add_theme_color_override("font_color", ACCENT)
	title.add_theme_constant_override("outline_size", 10)
	title.add_theme_color_override("font_outline_color", Color(0.12, 0.08, 0.04, 0.8))
	v.add_child(title)
	var sub := Label.new()
	sub.text = "Peel it. Fell it. Build something bigger."
	sub.add_theme_font_override("font", _font_bold)
	sub.add_theme_font_size_override("font_size", 18)
	sub.add_theme_color_override("font_color", Color(1, 1, 1, 0.8))
	v.add_child(sub)
	var gap := Control.new()
	gap.custom_minimum_size.y = 24
	v.add_child(gap)
	if has_save:
		v.add_child(_button("Continue", true, func(): chosen.emit("continue")))
	_confirm = _button("New Game", not has_save, func():
		if has_save and _confirm.text == "New Game":
			_confirm.text = "Start over? Your saved world will be lost"
			return
		chosen.emit("new"))
	v.add_child(_confirm)
	v.add_child(_button("Settings", false, func(): chosen.emit("settings")))


func _button(text: String, primary: bool, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_font_override("font", _font_bold)
	b.add_theme_font_size_override("font_size", 22)
	b.custom_minimum_size.y = 54
	for st in ["normal", "hover", "pressed"]:
		var bs := StyleBoxFlat.new()
		var base := ACCENT if primary else Color(1, 1, 1, 0.1)
		bs.bg_color = base if st == "normal" else (base.lightened(0.15) if st == "hover" else base.darkened(0.1))
		if not primary and st == "hover":
			bs.bg_color = Color(1, 1, 1, 0.2)
		bs.set_corner_radius_all(14)
		bs.content_margin_left = 22
		b.add_theme_stylebox_override(st, bs)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var fc := Color("2b2118") if primary else Color.WHITE
	for c in ["font_color", "font_hover_color", "font_pressed_color"]:
		b.add_theme_color_override(c, fc)
	b.pressed.connect(func():
		Sfx.play("click")
		cb.call())
	return b


func _font(path: String, weight: int) -> FontVariation:
	var f := FontVariation.new()
	f.base_font = load(path)
	f.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): weight}
	return f
