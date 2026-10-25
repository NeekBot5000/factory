class_name Quality
extends Node
## Keeps the game smooth on weak computers (school laptops, Chromebooks): if the frame rate stays low for a few
## seconds, it drops one graphics level - softer shadows, then no shadows and less grass, then a shorter view.
## The level is remembered in the save, so a slow machine starts at the right level next time.

const LOW_FPS := 40.0
const WAIT := 10.0          # let the world load and settle before judging
const SLOW_FOR := 4.0       # seconds below LOW_FPS before stepping down
const MAX_LEVEL := 3

var main: Node
var sun: DirectionalLight3D
var grass: MultiMeshInstance3D
var _t := 0.0
var _slow := 0.0


func setup(p_main: Node, p_sun: DirectionalLight3D, p_grass: MultiMeshInstance3D) -> void:
	main = p_main
	sun = p_sun
	grass = p_grass
	apply(Game.quality)


## 0 = full, 1 = lighter shadows + no MSAA, 2 = no shadows + a third of the grass, 3 = also a shorter view.
func apply(level: int) -> void:
	Game.quality = clampi(level, 0, MAX_LEVEL)
	var q := Game.quality
	if sun != null:
		sun.shadow_enabled = q < 2
		sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS if q == 0 else DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
		sun.directional_shadow_max_distance = 60.0 if q == 0 else 35.0
	get_viewport().msaa_3d = Viewport.MSAA_2X if q == 0 else Viewport.MSAA_DISABLED
	if grass != null and grass.multimesh != null:
		grass.multimesh.visible_instance_count = -1 if q < 2 else int(grass.multimesh.instance_count / 3.0)
	var player: Node = main.get("player")
	if player != null and player.get("cam") != null:
		(player.cam as Camera3D).far = 400.0 if q < 3 else 140.0


func _process(delta: float) -> void:
	_t += delta
	# only real builds (the web page, the downloads) adapt; editor runs, tests and screenshots stay at full
	if not OS.has_feature("template") or _t < WAIT or Game.quality >= MAX_LEVEL:
		return
	# a background tab or a minimised window is throttled by the browser / OS - that's not a slow computer;
	# nor is the burst of work while the shop icons are still being drawn at startup
	var icons: Node = main.get("icons")
	if not get_window().has_focus() or (icons != null and icons.call("busy")):
		_slow = 0.0
		return
	if Engine.get_frames_per_second() < LOW_FPS:
		_slow += delta
		if _slow >= SLOW_FOR:
			_slow = 0.0
			_t = WAIT - 3.0      # give the new level a few seconds before judging again
			apply(Game.quality + 1)
			Game.save_game()
	else:
		_slow = 0.0
