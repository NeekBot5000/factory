class_name Hud
extends CanvasLayer
## Minimal first-person HUD: crosshair, health, context hint, damage flash, faint fade, start screen.

var player: Player
var root: Control
var health_bar: ProgressBar
var health_lbl: Label
var hint: Label
var crosshair: Control
var flash: ColorRect
var fade: ColorRect
var start_panel: PanelContainer
var font_body: FontVariation
var font_title: FontVariation
var _flash_a := 0.0
var hide_start := false


func setup(p: Player) -> void:
	player = p
	layer = 5
	font_body = _font("res://assets/fonts/Nunito.ttf", 700)
	font_title = _font("res://assets/fonts/Fredoka.ttf", 600)
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	flash = ColorRect.new()
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = """
shader_type canvas_item;
uniform float strength = 0.0;
void fragment() {
	float d = distance(UV, vec2(0.5));
	COLOR = vec4(0.75, 0.0, 0.0, smoothstep(0.25, 0.75, d) * strength);
}
"""
	var sm := ShaderMaterial.new()
	sm.shader = sh
	flash.material = sm
	root.add_child(flash)
	crosshair = Control.new()
	crosshair.set_anchors_preset(Control.PRESET_CENTER)
	crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	crosshair.draw.connect(_draw_crosshair)
	root.add_child(crosshair)
	# health
	var hp := PanelContainer.new()
	hp.add_theme_stylebox_override("panel", _flat(Color(0.05, 0.06, 0.1, 0.65), 12, 12))
	hp.anchor_top = 1.0
	hp.anchor_bottom = 1.0
	hp.offset_left = 20
	hp.offset_top = -74
	hp.grow_vertical = Control.GROW_DIRECTION_BEGIN
	root.add_child(hp)
	var hv := VBoxContainer.new()
	hp.add_child(hv)
	health_lbl = _label("Health 100", 15, Color.WHITE)
	hv.add_child(health_lbl)
	health_bar = ProgressBar.new()
	health_bar.custom_minimum_size = Vector2(240, 14)
	health_bar.max_value = 100.0
	health_bar.value = 100.0
	health_bar.show_percentage = false
	health_bar.add_theme_stylebox_override("background", _flat(Color(0, 0, 0, 0.5), 7, 0))
	health_bar.add_theme_stylebox_override("fill", _flat(Color("e04848"), 7, 0))
	hv.add_child(health_bar)
	# hint
	hint = _label("", 17, Color.WHITE)
	hint.anchor_left = 0.5
	hint.anchor_right = 0.5
	hint.anchor_top = 1.0
	hint.anchor_bottom = 1.0
	hint.offset_top = -120
	hint.grow_horizontal = Control.GROW_DIRECTION_BOTH
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_constant_override("outline_size", 6)
	hint.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	root.add_child(hint)
	fade = ColorRect.new()
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade.color = Color(0, 0, 0, 0)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(fade)
	_build_start()
	player.health_changed.connect(_on_health)
	player.hurt.connect(func(_a): _flash_a = 0.85)
	player.fainted.connect(_on_faint)
	player.revived.connect(_on_revive)


func _font(path: String, weight: int) -> FontVariation:
	var f := FontVariation.new()
	f.base_font = load(path)
	f.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): weight}
	return f


func _flat(c: Color, radius: int, pad: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = c
	s.set_corner_radius_all(radius)
	s.content_margin_left = pad
	s.content_margin_right = pad
	s.content_margin_top = pad * 0.6
	s.content_margin_bottom = pad * 0.6
	return s


func _label(t: String, size: int, c: Color, f: Font = null) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_override("font", f if f else font_body)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", c)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _build_start() -> void:
	start_panel = PanelContainer.new()
	start_panel.set_anchors_preset(Control.PRESET_CENTER)
	start_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	start_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	start_panel.add_theme_stylebox_override("panel", _flat(Color(0.05, 0.06, 0.1, 0.85), 18, 28))
	start_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(start_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	start_panel.add_child(v)
	var t := _label("TIMBER", 52, Color("ffcf6a"), font_title)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var s := _label("You're a lumberjack with no tools. Karate-chop the bark off the trees.\nEvery chop hurts. No inventory: carry what you strip with your own hands.", 16, Color(1, 1, 1, 0.85))
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(s)
	var c := _label("WASD move    Mouse look    Shift sprint    Space jump\nLeft click  karate chop    E / Right click  pick up / drop    Left click while holding  throw\nEsc  release mouse", 15, Color("8fd0ff"))
	c.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(c)
	var go := _label("Click to play", 22, Color.WHITE, font_title)
	go.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(go)


func _draw_crosshair() -> void:
	var col := Color(1, 1, 1, 0.85)
	crosshair.draw_circle(Vector2.ZERO, 2.5, col)
	crosshair.draw_arc(Vector2.ZERO, 9.0, 0, TAU, 24, Color(1, 1, 1, 0.35), 1.5)


func _on_health(h: float, m: float) -> void:
	health_bar.max_value = m
	health_bar.value = h
	health_lbl.text = "Health %d" % int(ceil(h))


func _on_faint() -> void:
	var tw := create_tween()
	tw.tween_property(fade, "color:a", 1.0, 1.0)
	hint.text = ""


func _on_revive() -> void:
	var tw := create_tween()
	tw.tween_property(fade, "color:a", 0.0, 1.2)


func _process(delta: float) -> void:
	_flash_a = maxf(0.0, _flash_a - delta * 2.5)
	var low := clampf(1.0 - player.health / 40.0, 0.0, 1.0) * 0.45
	(flash.material as ShaderMaterial).set_shader_parameter("strength", maxf(_flash_a, low))
	start_panel.visible = Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and player.controls_enabled and not hide_start
	crosshair.visible = not start_panel.visible
	if player.controls_enabled:
		hint.text = player.look_target_text() if not start_panel.visible else ""
