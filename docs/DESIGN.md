# Factory Islands: Design (v2)

A low-poly 3D factory tycoon on floating islands, inspired by the factory side of Roblox *Islands*.
Every resource is a **real physics object** with a material, a shape and real dimensions. Machines act
on that geometry: a saw cuts a log **where the blade actually meets it**, a press really flattens an
ingot (volume conserved), a crusher breaks a boulder into actual fragments, and a sieve lets small
fragments physically fall through its bars.

## 1. Items

| field | meaning |
|---|---|
| `mat` | material id (oak, copper, ruby, ...) |
| `shape` | `box`, `cyl` (logs; length on local Z) or `chunk` (irregular rock, box collider) |
| `size` | full extents in world units (cylinder: x = y = diameter, z = length) |
| `purity` | ore/gem content 0..1 (wood/metal = 1) |
| `refined` | metal/gem that has been smelted or extracted |
| `quality` | multiplier from finishing (washing, polishing) |
| `heat` | 0..1, rises in furnaces; hot items glow |

**Value** = `price(mat) × volume × form_mult × quality × purity_factor × market_demand × seller bonus × global multipliers`.
Value depends only on geometry and processing, so cutting conserves value. Cutting only pays when the
cut produces a better *form*.

### Forms (derived from geometry every time it changes)

| category | forms (mult) |
|---|---|
| wood | log 1.0 (cylinder), timber 1.4 (box), plank 2.6 (thinnest side <= 0.09), offcut 0.5 (longest side < 0.3), chips 0.3 |
| ore | boulder 1.0 (> 0.3), chunk 1.05 |
| metal | ingot 3.0, plate 4.2 (<= 0.07 thick), sheet 5.5 (<= 0.035), scrap 1.0 (longest side < 0.12) |
| gem | geode 1.0, shard 1.8 (pure gem), polished 4.5 |
| crate | sum of contents × 1.3 (a crate counts as one sale for market demand) |

### Cutting algorithm

`World.cut_item(item, plane_point, plane_normal)`:
1. Transform the plane into the item's local frame and pick the local axis most aligned with the normal.
2. Get the cut coordinate along that axis. Within 0.03 of an edge the blade just grazes (no cut).
3. Two pieces: `[-h, c]` and `[c, h]`, each keeping orientation and velocity, pushed apart slightly.
4. A cylinder cut along its radius (a rip cut) becomes boxes whose radial dimensions are scaled by
   sqrt(pi/4), so volume is conserved.

## 2. Machines

* **Tree Farm**: a sapling grows (visible) and topples a real log onto the cell in front.
* **Ore Drill**: drills and drops boulders (random size and purity) from its hopper.
* **Chop Saw**: the blade drops every N seconds (or on a wire pulse) and cross-cuts whatever lies under it.
* **Rip Saw**: a spinning blade parallel to the belt splits items lengthwise. The blade offset is
  configurable, so timber turns into planks only with the right sequence of offsets.
* **Gang Saw**: several blades 0.08 apart; turns timber into planks in one pass (late game).
* **Crusher**: rollers break any item bigger than 0.25 into real fragments by repeated random plane cuts.
* **Sieve Grate**: a belt made of bars with gaps. Small fragments fall through to the layer below, big ones ride on.
* **Washer**: water spray raises ore purity once per item.
* **Furnace**: items inside heat up. Ore melts into a metal pool (volume × purity) and an ingot is
  cast each time a pool holds enough. Wood burns as fuel (faster heating). Gems crack. Boulders
  don't fit the intake and have to be crushed first.
* **Press**: the hammer flattens items under it (height ×0.5, width and length ×sqrt 2). Ingot -> plate -> sheet. Gems shatter.
* **Polisher**: polishes gem shards (quality up, some volume lost) and metal plates.
* **Packer**: puts N items into a physical crate worth more and counted once by the market.
* **Sellers**: trade pads of increasing bonus.
* **Belts** have low side guards that open automatically where another belt feeds in from the side.

## 3. Wiring (logic)

Wires link an **output** port of one part to an **input** port of another, at any distance, drawn as
sagging cables that light up when powered.

* Outputs: Lever, Button, Timer, Item Sensor (filter by material or form), AND, OR, NOT, XOR, Counter.
* Inputs: gates, counter, lamp, and almost every machine.
* An input with no wires means the machine is always on. If wired, a machine runs only while the
  signal is on. Pulse machines (chop saw, press, piston) fire on the rising edge.
* Gates compute from the previous tick's outputs (1-tick delay), so clocks, latches and memory
  cells all work.
* Actuators: **Piston** (physical paddle that pushes items off a belt), **Door** (physical barrier),
  **Diverter** (routes items to the side when powered), **Teleporter** sender/receiver pairs by
  colour channel, **Lamp**.

## 4. Economy and long-term loop

* Levels from lifetime earnings gate blueprint unlocks. Land plots unlock biomes, and each biome adds materials.
* **Market demand**: every product (material + form) loses price as you sell it and recovers over
  time, which rewards running several product lines and packing crates.
* **Orders board**: rotating contracts ("deliver 30 Oak Planks in 8 min") with big rewards.
* Global upgrades, per-part levels, quests, prestige (Ascension stars), offline earnings.
