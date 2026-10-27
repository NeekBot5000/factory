class_name Hud
extends CanvasLayer
## First-person HUD: crosshair ring sized to the tool's stripping circle, health, money, tool bar, hints,
## toasts, damage flash, faint fade and the start screen.

var player: Player
var main: Node
var root: Control
var health_bar: ProgressBar
var health_lbl: Label
var money_lbl: Label
var fps_lbl: Label
var hint: Label
var crosshair: Control
var flash: ColorRect
var fade: ColorRect
var toast_box: VBoxContainer
var toolbar: HBoxContainer
var font_body: FontVariation
var font_bold: FontVariation
var font_title: FontVariation
var hide_start := false
var save_icon: SaveIcon
var _flash_a := 0.0
var white: ColorRect          # lightning flash
var _white_a := 0.0
var _ring_px := 10.0


func setup(p: Player, p_main: Node) -> void:
	player = p
	main = p_main
	layer = 5
	font_body = _font("res://assets/fonts/Nunito.ttf", 700)
	font_bold = _font("res://assets/fonts/Nunito.ttf", 850)
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
	white = ColorRect.new()
	white.set_anchors_preset(Control.PRESET_FULL_RECT)
	white.mouse_filter = Control.MOUSE_FILTER_IGNORE
	white.color = Color(0.9, 0.95, 1.0, 0.0)
	root.add_child(white)
	crosshair = Control.new()
	crosshair.set_anchors_preset(Control.PRESET_CENTER)
	crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	crosshair.draw.connect(_draw_crosshair)
	root.add_child(crosshair)
	# health (bottom left)
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
	# money (top right)
	var mp := PanelContainer.new()
	mp.add_theme_stylebox_override("panel", _flat(Color(0.05, 0.06, 0.1, 0.65), 12, 14))
	mp.anchor_left = 1.0
	mp.anchor_right = 1.0
	mp.offset_right = -20
	mp.offset_top = 18
	mp.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	root.add_child(mp)
	fps_lbl = _label("", 13, Color(1, 1, 1, 0.75), font_bold)
	fps_lbl.position = Vector2(14, 10)
	fps_lbl.visible = false
	root.add_child(fps_lbl)
	money_lbl = _label("$0.00", 28, Color("7aff9a"), font_title)
	mp.add_child(money_lbl)
	# tool bar (bottom centre)
	toolbar = HBoxContainer.new()
	toolbar.anchor_left = 0.5
	toolbar.anchor_right = 0.5
	toolbar.anchor_top = 1.0
	toolbar.anchor_bottom = 1.0
	toolbar.offset_top = -86
	toolbar.offset_bottom = -16
	toolbar.grow_horizontal = Control.GROW_DIRECTION_BOTH
	toolbar.add_theme_constant_override("separation", 6)
	toolbar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(toolbar)
	# hint
	hint = _label("", 17, Color.WHITE)
	hint.anchor_left = 0.5
	hint.anchor_right = 0.5
	hint.anchor_top = 1.0
	hint.anchor_bottom = 1.0
	hint.offset_top = -130
	hint.grow_horizontal = Control.GROW_DIRECTION_BOTH
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_constant_override("outline_size", 6)
	hint.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	root.add_child(hint)
	# toasts
	toast_box = VBoxContainer.new()
	toast_box.anchor_left = 0.5
	toast_box.anchor_right = 0.5
	toast_box.offset_top = 18
	toast_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	toast_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_box.add_theme_constant_override("separation", 6)
	root.add_child(toast_box)
	fade = ColorRect.new()
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade.color = Color(0, 0, 0, 0)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(fade)
	player.health_changed.connect(_on_health)
	player.hurt.connect(func(_a): _flash_a = 0.85)
	player.fainted.connect(_on_faint)
	player.revived.connect(_on_revive)
	player.tool_changed.connect(func(_t): _rebuild_toolbar())
	Game.money_changed.connect(_on_money)
	Game.tools_changed.connect(_rebuild_toolbar)
	Game.toast.connect(show_toast)
	# autosave indicator: a little white hammer in the corner that taps while the game saves
	save_icon = SaveIcon.new()
	save_icon.anchor_left = 1.0
	save_icon.anchor_right = 1.0
	save_icon.anchor_top = 1.0
	save_icon.anchor_bottom = 1.0
	save_icon.offset_left = -64
	save_icon.offset_top = -64
	save_icon.offset_right = -20
	save_icon.offset_bottom = -20
	save_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	save_icon.modulate.a = 0.0
	root.add_child(save_icon)
	Game.saved.connect(save_icon.flash)
	if main.icons != null:
		main.icons.icon_ready.connect(func(_id): _rebuild_toolbar())
	money_lbl.text = "$%.2f" % Game.money
	_shown_money = Game.money
	_rebuild_toolbar()


func _font(path: String, weight: int) -> FontVariation:
	var f := FontVariation.new()
	f.base_font = load(path)
	f.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): weight}
	return f


func _flat(c: Color, radius: int, pad: int, border: Color = Color(0, 0, 0, 0), bw: int = 0) -> StyleBoxFlat:
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


func _label(t: String, size: int, c: Color, f: Font = null) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_override("font", f if f else font_body)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", c)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _rebuild_toolbar() -> void:
	for c in toolbar.get_children():
		toolbar.remove_child(c)
		c.queue_free()
	var owned: Array = Tools.TOOL_ORDER.filter(func(t): return Game.in_toolbar(t))
	# with lots of tools the bar shows a window of them around the one in hand, so it never runs off screen
	var first := 0
	var last := owned.size()
	if owned.size() > MAX_SLOTS:
		first = clampi(owned.find(player.tool) - 4, 0, owned.size() - MAX_SLOTS)
		last = first + MAX_SLOTS
		if first > 0:
			toolbar.add_child(_more_label("+%d" % first))
	for n in range(first + 1, last + 1):
		var id: String = owned[n - 1]
		var sel := player.tool == id
		var pc := PanelContainer.new()
		pc.add_theme_stylebox_override("panel", _flat(Color(0.05, 0.06, 0.1, 0.75 if sel else 0.5), 10, 6, Color("ffcf6a") if sel else Color(1, 1, 1, 0.15), 2 if sel else 1))
		pc.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var v := VBoxContainer.new()
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pc.add_child(v)
		var tex: Texture2D = main.icons.get_icon(id) if main.icons != null and id != "hands" else null
		if tex != null:
			var tr := TextureRect.new()
			tr.texture = tex
			tr.custom_minimum_size = Vector2(44, 44)
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
			v.add_child(tr)
		else:
			var hand := HandIcon.new()
			hand.custom_minimum_size = Vector2(44, 44)
			hand.mouse_filter = Control.MOUSE_FILTER_IGNORE
			v.add_child(hand)
		# number keys pick the n-th tool you own; only the one in hand shows its name (keeps the bar short)
		var key := str(n) if n <= 9 else ("S+%d" % (n - 9) if n <= 18 else "")
		var l := _label(("%s  %s" % [key, Tools.TOOLS[id].name]).strip_edges() if sel else key, 11, Color("ffcf6a") if sel else Color(1, 1, 1, 0.8), font_bold)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(l)
		toolbar.add_child(pc)
	if last < owned.size():
		toolbar.add_child(_more_label("+%d" % (owned.size() - last)))


const MAX_SLOTS := 9      # odd, so the tool in hand sits in the middle (4 either side)


func _more_label(t: String) -> Label:
	var l := _label(t, 14, Color(1, 1, 1, 0.6), font_bold)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return l


func show_toast(text: String, color: Color = Color.WHITE) -> void:
	var l := _label(text, 16, color, font_bold)
	l.add_theme_stylebox_override("normal", _flat(Color(0.05, 0.06, 0.1, 0.85), 10, 14))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_box.add_child(l)
	while toast_box.get_child_count() > 4:
		var old := toast_box.get_child(0)
		toast_box.remove_child(old)
		old.queue_free()
	var tw := l.create_tween()
	tw.tween_interval(3.5)
	tw.tween_property(l, "modulate:a", 0.0, 0.5)
	tw.tween_callback(l.queue_free)


func _draw_crosshair() -> void:
	crosshair.draw_circle(Vector2.ZERO, 2.5, Color(1, 1, 1, 0.9))
	if player.saw_progress > 0.0:
		crosshair.draw_arc(Vector2.ZERO, 16.0, -PI * 0.5, -PI * 0.5 + TAU * player.saw_progress, 40, Color("ffcf6a"), 3.0, true)
		return
	var on_tree := player.aiming_at_tree()
	var col := Color(1, 0.85, 0.4, 0.8) if on_tree else Color(1, 1, 1, 0.35)
	crosshair.draw_arc(Vector2.ZERO, _ring_px, 0, TAU, 40, col, 1.6, true)


## Money counts up to the new total (a quick roll, so a big sale feels big) and the counter gives a little pop.
var _shown_money := -1.0
var _money_tw: Tween


func _on_money(m: float) -> void:
	if _shown_money < 0.0:
		_shown_money = m
	var gain := m - _shown_money
	if _money_tw != null:
		_money_tw.kill()
	if gain <= 0.0:
		_shown_money = m
		money_lbl.text = "$%.2f" % m
		return
	_money_tw = create_tween()
	_money_tw.tween_method(func(v: float):
		_shown_money = v
		money_lbl.text = "$%.2f" % v, _shown_money, m, clampf(0.25 + gain / 400.0, 0.25, 1.4)).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	var box := money_lbl.get_parent() as Control
	box.pivot_offset = box.size * 0.5
	var pop := create_tween()
	pop.tween_property(box, "scale", Vector2.ONE * (1.06 + minf(gain / 1500.0, 0.14)), 0.08)
	pop.tween_property(box, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK)


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


## A white flash over the whole screen (lightning).
func lightning(a: float) -> void:
	_white_a = maxf(_white_a, a)


func _process(delta: float) -> void:
	_flash_a = maxf(0.0, _flash_a - delta * 2.5)
	_white_a = maxf(0.0, _white_a - delta * 3.0)
	white.color.a = _white_a
	fps_lbl.visible = bool(Game.settings.get("fps", false))
	if fps_lbl.visible:
		fps_lbl.text = "%d FPS" % Engine.get_frames_per_second()
	var low := clampf(1.0 - player.health / 40.0, 0.0, 1.0) * 0.45
	(flash.material as ShaderMaterial).set_shader_parameter("strength", maxf(_flash_a, low))
	var ui_open: bool = main.shop_ui != null
	crosshair.visible = not ui_open
	toolbar.visible = not ui_open
	money_lbl.get_parent().visible = not ui_open
	if crosshair.visible:
		crosshair.queue_redraw()
		_ring_px = lerpf(_ring_px, player.aim_ring_px(root.get_viewport_rect().size.y), 0.35)
		crosshair.queue_redraw()
	if player.controls_enabled and not ui_open:
		hint.text = player.look_target_text()
	else:
		hint.text = ""


## A flat karate-chop hand drawn with polygons (fonts don't all have a hand glyph).
class HandIcon extends Control:
	func _draw() -> void:
		var c := size * 0.5
		var k := minf(size.x, size.y) / 44.0
		var skin := Color("f2c9a0")
		var line := Color("6b4428")
		var sleeve := Color("d94a3d")
		# palm + four fingers held together, tilted like a chop
		var pts := PackedVector2Array([Vector2(-7, 14), Vector2(-9, -4), Vector2(-8, -16), Vector2(-4, -19),
			Vector2(5, -19), Vector2(8, -16), Vector2(9, -2), Vector2(14, -6), Vector2(17, -4), Vector2(9, 10), Vector2(7, 14)])
		var xf := Transform2D(deg_to_rad(-15.0), c)
		var poly := PackedVector2Array()
		for p in pts:
			poly.append(xf * (p * k))
		draw_colored_polygon(poly, skin)
		poly.append(poly[0])
		draw_polyline(poly, line, 1.5 * k, true)
		for f in [-3.5, 0.0, 3.5]:
			draw_line(xf * (Vector2(f, -19) * k), xf * (Vector2(f, -9) * k), line, 1.0 * k, true)
		var cuff := PackedVector2Array()
		for p in [Vector2(-8, 13), Vector2(8, 13), Vector2(8, 20), Vector2(-8, 20)]:
			cuff.append(xf * (p * k))
		draw_colored_polygon(cuff, sleeve)


## A small white hammer that knocks a couple of times and fades when the game autosaves.
class SaveIcon extends Control:
	var _t := 99.0

	func flash() -> void:
		_t = 0.0
		queue_redraw()

	func _process(delta: float) -> void:
		if _t > 2.0:
			return
		_t += delta
		modulate.a = clampf(minf(_t / 0.15, (2.0 - _t) / 0.5), 0.0, 0.9)
		queue_redraw()

	func _draw() -> void:
		var c := size * 0.5
		var k := minf(size.x, size.y) / 44.0
		var white := Color(1, 1, 1, 1)
		var shadow := Color(0, 0, 0, 0.35)
		# taps: swings down twice in the first second
		var swing := 0.0
		if _t < 1.0:
			swing = absf(sin(_t * TAU * 2.0)) * 0.6
		var xf := Transform2D(-0.6 + swing, c + Vector2(4, 6) * k)
		var handle := [Vector2(-2.2, 0), Vector2(2.2, 0), Vector2(2.2, -26), Vector2(-2.2, -26)]
		var head := [Vector2(-11, -32), Vector2(9, -32), Vector2(11, -29), Vector2(9, -24), Vector2(-11, -24)]
		var claw := [Vector2(-11, -32), Vector2(-17, -36), Vector2(-15, -31), Vector2(-11, -26)]
		for poly in [handle, head, claw]:
			var sh := PackedVector2Array()
			var pts := PackedVector2Array()
			for p in poly:
				pts.append(xf * ((p as Vector2) * k))
				sh.append(xf * ((p as Vector2) * k) + Vector2(1.5, 1.5))
			draw_colored_polygon(sh, shadow)
			draw_colored_polygon(pts, white)
		# a little spark when it lands
		if _t < 1.0 and swing < 0.15:
			var tip := xf * (Vector2(10, -28) * k)
			for i in 4:
				var a := TAU * i / 4.0 + 0.4
				draw_line(tip + Vector2(cos(a), sin(a)) * 3.0 * k, tip + Vector2(cos(a), sin(a)) * 7.0 * k, white, 1.5 * k)
