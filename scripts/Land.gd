class_name Land
extends Node3D
## Land you own. The world is cut into 20 m plots; you start with the four around the cabin and can only build on
## land you own. A "for sale" sign stands just past your border on every plot next to yours: look at it and press E
## to buy that plot. Each plot costs more than the last. (Trees and rocks can be harvested anywhere.)

const PLOT := 20.0
const LIMIT := 5          # plots go out to +-5 (the edge of the map)
const START := ["-1,-1", "-1,0", "0,-1", "0,0"]

var main: Node


static func key_at(p: Vector3) -> String:
	return "%d,%d" % [int(floor(p.x / PLOT)), int(floor(p.z / PLOT))]


static func owns(p: Vector3) -> bool:
	return Game.land.has(key_at(p))


static func next_price() -> float:
	return snappedf(400.0 * pow(1.7, maxi(0, Game.land.size() - START.size())), 10.0)


func setup(p_main: Node) -> void:
	main = p_main
	rebuild()


func buy(k: String) -> bool:
	var price := next_price()
	if Game.land.has(k) or not Game.can_afford(price):
		if not Game.can_afford(price):
			Game.toast.emit("Not enough money", Color("ff7a7a"))
		return false
	Game.add_money(-price)
	Game.land.append(k)
	Sfx.play("buy")
	Game.toast.emit("Bought a new plot of land", Color("7aff9a"))
	rebuild()
	Game.save_game()
	return true


## Corner stakes around everything you own, and a sign on each plot you could buy next.
func rebuild() -> void:
	for c in get_children():
		c.queue_free()
	var corners := {}
	for k in Game.land:
		var xz: PackedStringArray = String(k).split(",")
		var px := int(xz[0])
		var pz := int(xz[1])
		for dx in [0, 1]:
			for dz in [0, 1]:
				corners[Vector2i(px + dx, pz + dz)] = true
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nx: int = px + d.x
			var nz: int = pz + d.y
			var nk := "%d,%d" % [nx, nz]
			if Game.land.has(nk) or absi(nx) > LIMIT or absi(nz) > LIMIT or absi(nx + 1) > LIMIT + 1 or absi(nz + 1) > LIMIT + 1:
				continue
			# on the shared edge, a couple of metres into the plot for sale
			var mid := Vector2((px + 0.5) * PLOT, (pz + 0.5) * PLOT) + Vector2(d.x, d.y) * (PLOT * 0.5 + 2.0)
			if get_node_or_null("Sign_" + nk.replace(",", "_").replace("-", "m")) == null:
				_sign(nk, Vector3(mid.x, 0, mid.y))
	for c in corners:
		var cp := Vector3(c.x * PLOT, 0, c.y * PLOT)
		cp.y = main.terrain.height_at(cp.x, cp.z)
		var stake := Node3D.new()
		add_child(stake)
		stake.position = cp
		LowPoly.mesh_instance(stake, LowPoly.box(Vector3(0.1, 0.8, 0.1)), LowPoly.mat(Color("a0703c"), 0.9), Vector3(0, 0.4, 0))
		LowPoly.mesh_instance(stake, LowPoly.box(Vector3(0.12, 0.12, 0.12)), LowPoly.mat(Color("d64034"), 0.6), Vector3(0, 0.82, 0))


func _sign(k: String, at: Vector3) -> void:
	at.y = main.terrain.height_at(at.x, at.z)
	var s := ForSale.new()
	s.name = "Sign_" + k.replace(",", "_").replace("-", "m")
	add_child(s)
	s.position = at
	s.setup(self, k)
