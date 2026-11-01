class_name Credits
extends Control
## Who made the game and what it's built with, including the licences the engine and fonts ask to be shown.
## Opens over the title screen or the pause menu; Esc or Back closes it.

signal closed

const BG := Color(0.08, 0.09, 0.12, 1.0)
const ACCENT := Color("ffcf6a")
const MADE_BY := "NeekBot5000"     # the name shown as the game's maker

var _font_body: FontVariation
var _font_bold: FontVariation
var _font_title: FontVariation


static func version() -> String:
	return String(ProjectSettings.get_setting("application/config/version", "1.0.0"))


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_font_body = _font("res://assets/fonts/Nunito.ttf", 600)
	_font_bold = _font("res://assets/fonts/Nunito.ttf", 850)
	_font_title = _font("res://assets/fonts/Fredoka.ttf", 600)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.5)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var panel := PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -330
	panel.offset_right = 330
	panel.offset_top = -320
	panel.offset_bottom = 320
	var sb := StyleBoxFlat.new()
	sb.bg_color = BG
	sb.set_corner_radius_all(18)
	for side in ["left", "right", "top", "bottom"]:
		sb.set("content_margin_" + side, 26)
	panel.add_theme_stylebox_override("panel", sb)
	add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)
	var head := HBoxContainer.new()
	v.add_child(head)
	var t := _label("Credits", 34, ACCENT, _font_title)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	head.add_child(_label("Timber  v%s" % version(), 15, Color(1, 1, 1, 0.55), _font_bold))
	v.add_child(_label("Made by %s, with Claude." % MADE_BY, 17, Color.WHITE, _font_bold))
	v.add_child(_label("Every model, sound and song in the game is made from code inside the game itself.", 15, Color(1, 1, 1, 0.75)))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 8)
	scroll.add_child(body)
	body.add_child(_label("Built with the Godot Engine (godotengine.org)", 16, ACCENT, _font_bold))
	body.add_child(_small(Engine.get_license_text()))
	body.add_child(_label("Fonts", 16, ACCENT, _font_bold))
	body.add_child(_small("Nunito - Copyright 2014 The Nunito Project Authors. Fredoka - Copyright 2016 The Fredoka Project Authors.\nBoth are licensed under the SIL Open Font License, Version 1.1 (scripts.sil.org/OFL); the full text ships with the game's source."))
	body.add_child(_label("Engine components", 16, ACCENT, _font_bold))
	var parts: Array[String] = []
	for info in Engine.get_copyright_info():
		parts.append(String(info.get("name", "")))
	body.add_child(_small("Godot includes third-party code, each under its own licence: " + ", ".join(parts) + "."))
	var back := Button.new()
	back.text = "Back"
	back.focus_mode = Control.FOCUS_NONE
	back.add_theme_font_override("font", _font_bold)
	back.add_theme_font_size_override("font_size", 20)
	back.custom_minimum_size.y = 44
	for st in ["normal", "hover", "pressed"]:
		var bs := StyleBoxFlat.new()
		bs.bg_color = ACCENT if st == "normal" else (ACCENT.lightened(0.15) if st == "hover" else ACCENT.darkened(0.1))
		bs.set_corner_radius_all(12)
		back.add_theme_stylebox_override(st, bs)
	back.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	for c in ["font_color", "font_hover_color", "font_pressed_color"]:
		back.add_theme_color_override(c, Color("2b2118"))
	back.pressed.connect(_close)
	v.add_child(back)


func _close() -> void:
	Sfx.play("click")
	closed.emit()
	queue_free()


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		_close()


func _small(text: String) -> Label:
	var l := _label(text, 13, Color(1, 1, 1, 0.65))
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 590
	return l


func _label(text: String, size: int, c: Color, f: Font = null) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", f if f else _font_body)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", c)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _font(path: String, weight: int) -> FontVariation:
	var f := FontVariation.new()
	f.base_font = load(path)
	f.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): weight}
	return f
