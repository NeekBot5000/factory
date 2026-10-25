class_name Hammock
extends StaticBody3D
## A leaf hammock strung between two log posts. E to climb in and sway; E again to get out.

var bed_h := 0.55     # where you lie, above the base (scaled with the build)


func hint_text() -> String:
	return "[E] lie down"


func on_use(player: Node) -> void:
	player.call("lie_in", self)
