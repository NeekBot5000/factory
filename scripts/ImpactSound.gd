class_name ImpactSound
extends Node
## Gives a rigid body a sound when it hits something hard: a clunk for ore, a wooden thud for logs. Uses the
## speed from the frame before the hit (the contact itself already slows it), and won't repeat faster than
## every quarter second, so a pile settling doesn't rattle like a drum roll.

var sound := "thud"
var pitch := 1.0
var volume := 0.0
var min_speed := 2.5
var _body: RigidBody3D
var _speed := 0.0
var _cool := 0.0


static func attach(body: RigidBody3D, p_sound: String, p_pitch := 1.0, p_volume := 0.0, p_min_speed := 2.5) -> ImpactSound:
	var s := ImpactSound.new()
	s.sound = p_sound
	s.pitch = p_pitch
	s.volume = p_volume
	s.min_speed = p_min_speed
	body.add_child(s)
	return s


func _ready() -> void:
	_body = get_parent() as RigidBody3D
	_body.contact_monitor = true
	_body.max_contacts_reported = maxi(_body.max_contacts_reported, 2)
	_body.body_entered.connect(_hit)


func _physics_process(delta: float) -> void:
	_cool -= delta
	_speed = _body.linear_velocity.length()


func _hit(_other: Node) -> void:
	if _cool > 0.0 or _speed < min_speed or _body.freeze:
		return
	_cool = 0.25
	var loud := clampf((_speed - min_speed) / 6.0, 0.0, 1.0)
	Sfx.play_at(sound, _body.global_position, pitch * randf_range(0.9, 1.1), volume - 8.0 + loud * 10.0)
