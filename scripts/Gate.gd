class_name Gate
extends Machine
## A logic block. Unlike other machines it has a direction (the arrow on top points to its front):
##   back  - main input: the power it passes on
##   sides - control input (relays), or the power supply (latch, counter)
##   front - output: the only side power leaves through
## Which side a wire is on is decided by where the other machine stands. Modes:
##   diode   - one-way: back -> front
##   and     - relay: back -> front while a side is powered
##   not     - inverting relay: back -> front while no side is powered
##   timer   - back -> front in short pulses (E: how often)
##   delay   - back -> front once the back has been powered for a while (E: how long)
##   latch   - a pulse at the back flips it; while on, side power goes out the front
##   counter - counts pulses at the back; every N it lets side power out the front for a moment (E: N)

const PULSE := 0.5
const TIMER_STEPS := [1.0, 2.0, 4.0, 8.0]
const DELAY_STEPS := [0.5, 1.0, 2.0, 4.0]
const COUNT_STEPS := [2, 3, 5, 10]

var mode := "diode"
var passing := false
var setting := 0                 # index into the mode's steps
var _clock := 0.0
var _held := 0.0
var _released := 99.0
var _on := false                  # latch
var _count := 0
var _pulse := 0.0
var _back_was := false


func activate(p_size: float) -> void:
	super(p_size)
	mode = String(get_meta("build").id).trim_prefix("gate_") if has_meta("build") else mode
	add_lamp(Vector3(0, 0.2, -0.22))


func conducts() -> bool:
	return false


func terminal() -> Vector3:
	return Vector3(0, 0.22, 0) * size


## Which side of this block another machine is wired from: "front", "back" or "side".
func side_of(other: Machine) -> String:
	var lp := to_local(other.terminal_world())
	if lp.z < -0.3 and absf(lp.z) >= absf(lp.x) * 0.7:
		return "front"
	if absf(lp.x) > absf(lp.z):
		return "side"
	return "back" if lp.z >= 0.0 else "front"


## Would it pass power, given which of its inputs are fed right now?
func would_pass(fed: Dictionary) -> bool:
	var back: bool = fed.get("back", false)
	var side: bool = fed.get("side", false)
	match mode:
		"diode": return back
		"and": return back and side
		"not": return back and not side
		"timer": return back and _clock < PULSE
		"delay": return (back and _held >= _delay()) or (not back and _held >= _delay() and _released < _delay())
		"latch": return side and _on
		"counter": return side and _pulse > 0.0
	return false


## Once a tick, after power has been worked out: clocks run, edges are counted.
func step(fed: Dictionary, dt: float) -> void:
	var back: bool = fed.get("back", false)
	match mode:
		"timer":
			_clock = fmod(_clock + dt, float(TIMER_STEPS[setting]))
		"delay":
			if back:
				_held += dt
				_released = 0.0
			else:
				_released += dt
				if _released >= _delay():
					_held = 0.0
		"latch":
			if back and not _back_was:
				_on = not _on
				Sfx.play_at("click", global_position, 1.3 if _on else 0.9, -6.0)
		"counter":
			_pulse = maxf(0.0, _pulse - dt)
			if back and not _back_was:
				_count += 1
				if _count >= int(COUNT_STEPS[setting]):
					_count = 0
					_pulse = 1.0
	_back_was = back


func _delay() -> float:
	return float(DELAY_STEPS[setting])


func on_use(_player: Node) -> void:
	match mode:
		"timer", "delay", "counter":
			setting = (setting + 1) % 4
			_count = 0
			Sfx.play("click", 0.8 + setting * 0.15, -4.0)
		"latch":
			_on = not _on
			Sfx.play("click", 1.3 if _on else 0.9, -4.0)


func hint_text() -> String:
	var what := ""
	match mode:
		"diode": what = "One-Way  ·  power in the back, out the front"
		"and": what = "Relay  ·  passes back -> front while a side is powered"
		"not": what = "Inverting Relay  ·  passes back -> front while no side is powered"
		"timer": what = "Timer  ·  pulses every %ds    [E] change" % int(TIMER_STEPS[setting])
		"delay": what = "Delay  ·  %.1fs    [E] change" % _delay()
		"latch": what = "Toggle Latch  ·  %s  ·  a pulse at the back flips it    [E] flip" % ("on" if _on else "off")
		"counter": what = "Counter  ·  %d of %d pulses    [E] change" % [_count, int(COUNT_STEPS[setting])]
	return what


func save_state() -> Dictionary:
	return {"setting": setting, "on": _on, "count": _count}


func load_state(d: Dictionary) -> void:
	setting = clampi(int(d.get("setting", 0)), 0, 3)
	_on = bool(d.get("on", false))
	_count = int(d.get("count", 0))
