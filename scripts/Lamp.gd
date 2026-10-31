class_name Lamp
extends Machine
## Outputs you can see and hear: a lamp that lights up while powered, a bell that rings when power arrives.

var kind := "lamp"
var _light: OmniLight3D
var _bulb: MeshInstance3D


func activate(p_size: float) -> void:
	super(p_size)
	kind = String(get_meta("build").id) if has_meta("build") else kind
	if kind == "lamp":
		_light = OmniLight3D.new()
		_light.light_color = Color("ffcf8a")
		_light.omni_range = 7.0
		_light.light_energy = 0.0
		_light.position = Vector3(0, 1.25, 0)
		add_child(_light)
		_bulb = get_node_or_null("Model/Bulb") as MeshInstance3D
		if _bulb != null:
			var m := StandardMaterial3D.new()
			m.albedo_color = Color("6b6458")
			m.emission_enabled = true
			m.emission = Color("ffcf8a")
			m.emission_energy_multiplier = 0.0
			_bulb.material_override = m


func terminal() -> Vector3:
	return Vector3(0, 0.35, 0.12) * size


func hint_text() -> String:
	return "%s  ·  %s" % ["Lamp" if kind == "lamp" else "Bell", "powered" if powered else "no power"]


func _power_on() -> void:
	if kind == "bell":
		Sfx.play_at("clink", global_position, 0.7, 4.0)
		Sfx.play_at("clink", global_position, 0.52, 2.0)
		var b := get_node_or_null("Model/Bell") as Node3D
		if b != null:
			var tw := create_tween()
			for k in 4:
				tw.tween_property(b, "rotation:x", 0.35 * (1.0 if k % 2 == 0 else -1.0) * pow(0.6, k), 0.1)
			tw.tween_property(b, "rotation:x", 0.0, 0.1)
	_show(true)


func _power_off() -> void:
	_show(false)


func _show(on: bool) -> void:
	if _light != null:
		_light.light_energy = 2.5 if on else 0.0
	if _bulb != null:
		(_bulb.material_override as StandardMaterial3D).emission_energy_multiplier = 3.0 if on else 0.0
		(_bulb.material_override as StandardMaterial3D).albedo_color = Color("ffe2a8") if on else Color("6b6458")
