class_name CartPart
extends Machine
## Parts that only make sense on a minecart's deck:
##   cart_go     - while powered, the cart rolls forward
##   cart_back   - while powered, the cart rolls backward
##   rail_layer  - (front) when the track runs out ahead, lays a rail from a crate on the cart
##   rail_lifter - (back) picks up the rail the cart just left and puts it in a crate on the cart
## Go and Back don't share the cart's power automatically: wire something that switches into them (a lever, a sensor,
## a drill rig that's drilled out, a receiver, logic...), or the cart would never stop.

var kind := "cart_go"


func activate(p_size: float) -> void:
	super(p_size)
	kind = String(get_meta("build").id) if has_meta("build") else kind
	add_lamp(Vector3(0.25, 0.2, 0.25))


func terminal() -> Vector3:
	return Vector3(0, 0.35, 0) * size


func hint_text() -> String:
	var what := ""
	match kind:
		"cart_go": what = "Go  ·  the cart rolls forward while this is powered (wire a switch into it)"
		"cart_back": what = "Reverse  ·  the cart rolls backward while this is powered (wire a switch into it)"
		"rail_layer": what = "Rail Layer  ·  lays a rail ahead from a crate on the cart when the track runs out"
		"rail_lifter": what = "Rail Lifter  ·  picks up the rail behind the cart into a crate on the cart"
	return "%s  ·  %s" % [what, "powered" if powered else "off"]
