# Timber

A low-poly, first-person lumberjack game (prototype), built in **Godot 4.4**.

You start with nothing but your bare hands: a log cabin in a clearing, surrounded by forest.
**Karate-chop trees to strip their bark**, and every chop hurts. You can see the layers come away: the dark
**outer bark** first, then the orange **inner bark**, then the pale **wood** underneath. Everything inside your
aim circle comes off in one sheet, but only one layer at a time. There is no inventory: every piece is a
physics object you pick up and carry.

Carry bark to the green **log truck** by the cabin and ship it to town for money. Then use the **computer in the
cabin** to order better tools from TimberMart. An orange delivery van backs up to your cabin and drops off a
box with a drawing of what's inside. Click the box to unpack it, then pick up your new tool.

| Tool | Price | What it does |
|---|---|---|
| Bare hands | free | small chips, hurts you |
| Trusty Hatchet | $30 | no more damage, bigger circle |
| Double-Bit Axe | $160 | every swing hits twice: forehand, then straight back with the other bit |
| Crescent Labrys | $600 | big spinning diagonal slam, huge patch |
| Twin Hatchets | $300 | one in each hand: very fast alternating small chops |
| Combo Axe | $250 | each hit in quick succession grows the next one; pause and it resets |
| Bark Scraper | $400 | big sheets of outer bark only - never touches the inner layer |
| Inner Gouge | $380 | inner bark only, small strips that sell for 35% more |
| Ringing Axe | $750 | slow; every hit takes a full ring of bark all the way round |
| Greataxe | $900 | the biggest patch of all, but a long windup and you walk slowly |
| Robo-Axe X9 | $6500 | automatic: hold the trigger, it chops ~7 times a second, each hit a 3x3 patch through both layers |
| Buck Saw | $280 | logs only (can't fell): one cut splits the whole log into carryable rounds |
| Chainsaw | $1800 | fells and cuts about 3x faster than the bow saw |
| Twin Auger | $3200 | two bits side by side: bores two strips at once |
| Hole Saw | $2100 | small, but takes outer and inner bark together |
| Twin-Nozzle Vac | $2600 | two intakes: wider pull, twice the capacity, two clumps |
| Cyclone Vac | $3400 | long narrow pull; let go and it fires its load forward |
| Bow Saw | $450 | hold on a trunk to fell the tree; hold on a log to cut it in two |
| Pruning Shears | $90 | snip clumps of leaves off bushes and crowns (felled trees keep theirs) |
| Timber Auger | $2400 | hold the mouse button and it bores bark off continuously |
| Builder's Hammer | $120 | build things from what you gather |
| Leaf Vacuum | $1200 | sucks loose bark/leaves/boxes into a floating clump; let go to drop |
| TimberPhone | $350 | the store and the truck, from anywhere (Tab) |
| Pickaxe | $80 | knocks chunks of stone and copper ore off rocks |
| Steel Pickaxe | $900 | hits twice as hard and gets through iron veins |
| Wire Spool | $200 | click one machine, then another, to wire them together (again to unwire) |

Logs keep their bark, so you can still strip them. The mill pays well for clean timber, but bark left on drags
the price down: a log in full bark fetches only 15% of what it would stripped bare.

**Building:** take out the hammer and click to open the build menu (categories, previews). Pick a plan and its
hologram follows your aim; R turns it, scroll makes it bigger (bigger costs more), click to set it down, E to
cancel. Drop materials into the hologram - it shows what it still needs - and each
piece fills in; any kind of bark or wood counts, leaves too. E on a plan cancels it and gives everything back.
Movable builds (baskets, balls) sell in the log truck for a bit less than their materials.

| Build | Needs | What it does |
|---|---|---|
| Bark Basket | 50 bark | carry it around, fill it up |
| Log Bench | 1 log + 6 bark | somewhere to sit |
| Campfire | 6 bark + 10 leaves | burns anything dropped on it (logs too - their value goes up in smoke) |
| Leaf Hammock | 2 logs + 30 leaves | E to lie down and sway |
| Bark Chute | 3 logs + 12 bark | slippery slide: drop bark in the top |
| Log Rack | 4 logs | V-cradles that hold logs |
| Compost Pile | 40 leaves | feed it leaves and it sprouts saplings; plant one and it grows into a tree |
| Basketball | 8 leaves | bouncy; drop it through the hoop to score |
| Basketball Hoop | 12 bark + 1 log | a real rim; baskets set off a celebration and count streaks |
| Catapult | 3 logs + 10 bark + 6 leaves | click it to launch whatever's in the cup |

## Mining and machines

Rocks around the forest are stone; some show orange **copper** veins, and the **quarry** in the woods
(south-west of the cabin) is full of copper and silvery **iron**. Every pickaxe hit knocks off a chunk you can
carry, sell, or drop into a machine's hologram.

Machines need their **blueprint** from TimberMart first (the build menu shows them greyed out until then). They
always build on a 1 m grid facing one of four ways, so belts line up end to end; their front points away from
you as you place them. Power comes from a **hand crank** (E winds it: 10 s per wind, up to a minute) and runs
along wires; a switch that's off stops it there. Each machine has a small lamp that lights while it's powered.

| Machine | Needs | What it does |
|---|---|---|
| Hand Crank | 4 stone + 1 log + 1 copper | power source: E to wind |
| Lever | 2 stone + 1 copper | E flips it; passes power while on |
| Push Button | 1 log + 2 stone + 1 copper | E presses it; passes power for 1.5 s |
| Conveyor | 5 bark + 2 stone | powered belt that carries things forward |
| Ramp Conveyor | 8 bark + 2 stone | carries things up a metre over two cells |
| Piston | 8 stone + 2 copper + 1 log | shoves its plate out a metre while powered |
| Rotator | 4 stone + 1 copper + 1 log | turntable: hammer it to stick what's on it, then it spins it round |
| Truck Caller | 3 stone + 1 log + 3 copper | sends the log truck to the mill when it gets power |

The last clump of leaves on any crown always drops one or two saplings, so every tree can be replaced; they take
five minutes to grow.

## Play

* **Download a build:** open the latest successful run under the repo's *Actions* tab, scroll to *Artifacts*
  and grab **Timber-windows** (or -linux / -web).
* **Or open it in Godot 4.4:** *Import* `project.godot`, then press **F5**.

| Control | Action |
|---|---|
| WASD / arrows | move |
| Mouse | look (click the window to capture the mouse, Esc to release) |
| Shift / Space | sprint / jump |
| Left click | swing / hold for saw, auger, vacuum / open a box / use the computer / build |
| E or right click | pick up / drop, ship the truck, take an item, cancel a build |
| Q | drop your tool on the ground |
| Spin and drop | things keep their momentum, so you can fling them |
| Hold R while holding something | tip it over (pour a basket out) |
| R while placing a build | turn it |
| Hammer click on a log | lock it in place (iron bands); click again to unlock |
| Hammer click on a rotator | stick what's on it to the table / let go |
| Hammer + X on a build | take it down (you get back what it would sell for) |
| 1-9 / mouse wheel | the 1st-9th tool you own (while placing a build, the wheel resizes it) |
| Tab | phone (once you own it) |

Progress autosaves every 15 seconds (a little white hammer taps in the corner): money, tools, everything you've
built (machines, their settings and wires too), plans in progress, bark you've stripped, felled and grown trees,
trimmed bushes, mined rocks, and every log, bark sheet, leaf, ore chunk, sapling and dropped tool lying around.

## Roadmap

Saws that strip whole logs, chainsaws, a long axe that slices straight through, and drones that haul bark back
to base.

## Code

```
scripts/Main.gd        scene setup, chip spawning, order dispatch, UI
scripts/Game.gd        money, owned tools, orders, save/load (autoload)
scripts/Tools.gd       tool stats, shop catalogue, procedural tool models
scripts/Player.gd      first-person controller, tools + swing animations, health, carrying
scripts/ForestTree.gd  trunk built from outer-bark / inner-bark panel grids, circle stripping
scripts/Chip.gd        a physical sheet of bark
scripts/Truck.gd       log truck (ship for cash) and delivery van
scripts/DeliveryBox.gd box with printed art and an unboxing animation
scripts/ItemPickup.gd  the revealed item          scripts/Computer.gd  cabin PC
scripts/ShopUI.gd      TimberMart store (computer and phone)
scripts/Icons.gd       renders item thumbnails and the box line art
scripts/Cabin.gd       procedural log cabin       scripts/Terrain.gd  forest floor and road
scripts/Hud.gd         crosshair, health, money, toolbar   scripts/Sfx.gd  procedural sounds
scripts/Machine.gd     base for powered machines; Circuit.gd works out power, Wire.gd draws cables
scripts/Machines.gd    machine models and finishing (Crank, Lever, PushButton, Piston, Rotator, Conveyor, TruckCaller)
scripts/Rock.gd, Ore.gd  mineable rocks and the chunks they drop
tests/*Test.tscn       headless gameplay tests (MachineTest covers mining, wires and machines)
tests/Shot.tscn        screenshots (xvfb)
```
All models and sounds are generated in code. The only external assets are two SIL OFL fonts.
