class_name Hammock
extends StaticBody3D
## A leaf hammock strung between two log posts. E to climb in and sway; E again to get out.

var bed_point := Vector3(0, 0.8, 0)


func hint_text() -> String:
	return "[E] lie down"


func on_use(player: Node) -> void:
	player.call("lie_in", self)
