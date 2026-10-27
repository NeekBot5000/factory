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
| Rock Drill | $650 | hold it on a rock: chunks come off about twice as fast as a pickaxe (stone and copper) |
| Steel Core Drill | $2600 | faster, hits twice as hard, and bores through iron |
| Leaf Rake | $40 | every pull drags loose bark, leaves and bits in front of you a step closer |
| Watering Can | $70 | a rooted sapling grows twice as fast for a minute |
| Log Scale | $90 | point it at a log, a sheet or a full basket: weight and value |
| Sledgehammer | $220 | slow; one blow bursts a small rock into all its chunks |
| Pole Saw | $380 | 5.5 m reach; hold it in a standing tree's crown to cut the whole crown off |
| Throwing Hatchet | $450 | click to throw: it spins out up to 12 m, bites off bark, sticks for a moment and flies back to your hand |
| Wheelbarrow Blueprint | $600 | build a wheelbarrow (hammer, Storage): grab it and push a big load along the ground |
| Ore Detector | $750 | beeps faster near ore, including copper and iron hidden inside plain-looking rocks |
| Leaf Blower | $900 | hold to blow everything in front of you away |
| Bark Spud | $1100 | slow push tool; its sheets sell for 50% more |
| Dynamite (box of 5) | $1200 | stick a charge on a rock, wire it to a powered switch, and set it off |
| Electric Planer | $1300 | logs lying down only: one full-length strip per pass, as one long sheet |
| Spiral Axe | $1400 | each hit carries a slanted stripe on from the last, winding a spiral up the trunk |
| Two-Man Crosscut | $1600 | slow saw that fells the giant trees deep in the woods; its logs are worth 20% more |
| Pressure Washer | $2200 | hold to strip bark with a jet of water from up to 6 m away |
| Thunder Axe | $18000 | hold to charge, let go on a trunk: lightning cracks off every last sheet of bark (6 s recharge) |
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

The simple machines take stone and copper; the advanced ones (piston, rotator, truck caller) need iron ore,
which only the Steel Pickaxe or Steel Core Drill can get out of a vein.

Machines need their **blueprint** from TimberMart first (the build menu shows them greyed out until then). They
always build on a 1 m grid facing one of four ways, so belts line up end to end; their front points away from
you as you place them. Power comes from a **hand crank** (E winds it: 15 s per wind, up to two minutes) and runs
along wires; a switch that's off stops it there. Each machine has a small lamp that lights while it's powered, and looking at one tells you whether it has power.
Mined-out rocks slowly grow back (one every minute or so, never right next to you).

| Machine | Needs | What it does |
|---|---|---|
| Hand Crank | 4 stone + 1 log + 1 copper | power source: E to wind |
| Lever | 2 stone + 1 copper | E flips it; passes power while on |
| Push Button | 1 log + 2 stone + 1 copper | E presses it; passes power for 1.5 s |
| Conveyor | 5 bark + 2 stone | powered belt that carries things forward |
| Ramp Conveyor | 8 bark + 2 stone | carries things up a metre; it fills its own cell and the one in front |
| Stone Pillar | 4 stone | a 1 m block (no blueprint needed); a belt on top carries on from the top of a ramp |
| Piston | 6 stone + 3 iron + 2 copper | shoves its iron plate out a metre while powered |
| Rotator | 4 stone + 2 iron + 1 copper + 1 log | turntable: hammer it to stick what's on it, then it spins it round |
| Truck Caller | 3 stone + 3 copper + 2 iron + 1 log | sends the log truck to the mill when it gets power |

The last clump of leaves on any crown always drops one or two saplings, so every tree can be replaced; they take
five minutes to grow.

## Play

* **Download a build:** open the latest successful run under the repo's *Actions* tab, scroll to *Artifacts*
  and grab **Timber-windows** (or -linux / -web).
* **Or open it in Godot 4.4:** *Import* `project.godot`, then press **F5**.

| Control | Action |
|---|---|
| WASD / arrows | move |
| Mouse | look (click the window to capture the mouse) |
| Esc | pause: mouse sensitivity, field of view, volume, graphics, invert mouse, head bob, FPS counter (saved) |
| Shift / Space | sprint / jump |
| Left click | swing / hold for saw, auger, vacuum / open a box / use the computer / build |
| E or right click | pick up / drop, ship the truck, take an item, cancel a build |
| Q | drop your tool on the ground |
| Spin and drop | things keep their momentum, so you can fling them |
| Hold R while holding something | tip it over (pour a basket out) |
| R while placing a build | turn it |
| Hammer click on a log | lock it in place (iron bands); click again to unlock |
| Hammer click on a rotator | stick what's on it to the table / let go |
| Hammer + X on a build | take it down (you get back what it would sell for); on a plan, knocks it down and drops the materials |
| 1-9 / mouse wheel | the 1st-9th tool you own; Shift + 1-9 for the 10th-18th (while placing a build, the wheel resizes it) |
| Tab | phone (once you own it) |

On a slow computer the game turns down its own graphics after a few seconds of low frame rate (softer shadows,
then no shadows and less grass, then a shorter view distance), and remembers that for next time.

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
scripts/Hud.gd         crosshair, health, money, toolbar   scripts/Sfx.gd  procedural sounds, wind, positional sounds
scripts/Machine.gd     base for powered machines; Circuit.gd works out power, Wire.gd draws cables
scripts/Machines.gd    machine models and finishing (Crank, Lever, PushButton, Piston, Rotator, Conveyor, TruckCaller)
scripts/Rock.gd, Ore.gd  mineable rocks and the chunks they drop (mined rocks regrow, see Main.regrow_rock)
scripts/Quality.gd     steps graphics down on slow computers (exported builds only)
scripts/Ground.gd      surface detail shaders for the forest floor and stone (no texture files)
scripts/SettingsMenu.gd  the Esc pause / settings menu
scripts/ImpactSound.gd clunks and thuds when ore and logs hit something hard
scripts/Builds.gd, Builder.gd, Blueprint.gd, BuildMenu.gd  hammer builds: catalogue + models, placement, plans, menu
scripts/WorldSave.gd   everything you've done to the world, for the save file
tests/*Test.tscn       headless gameplay tests (MachineTest: mining, wires, machines; InputTest: every control through
                       real input events; SoakTest: random inputs, then save + reload)
tests/Bench.tscn       balance bench: $/minute for every stripping tool
tests/Shot.tscn        screenshots (xvfb)
```
All models and sounds are generated in code. The only external assets are two SIL OFL fonts.
