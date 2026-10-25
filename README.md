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
| Crescent Labrys | $650 | big spinning diagonal slam, huge patch |
| Twin Hatchets | $300 | one in each hand: very fast alternating small chops |
| Combo Axe | $750 | each hit in quick succession grows the next one; pause and it resets |
| Bark Scraper | $220 | big sheets of outer bark only - never touches the inner layer |
| Inner Gouge | $380 | inner bark only, small strips that sell for 35% more |
| Ringing Axe | $520 | slow; every hit takes a full ring of bark all the way round |
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

Logs keep their bark, so you can still strip them; the mill pays for timber plus a little for bark left on.

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
| 1-9 / mouse wheel | the 1st-9th tool you own (while placing a build, the wheel resizes it) |
| Tab | phone (once you own it) |

Progress saves automatically, including everything you've built and plans still waiting for materials.

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
tests/ChopTest.tscn, tests/LoopTest.tscn  headless gameplay tests
tests/Shot.tscn        screenshots (xvfb)
```
All models and sounds are generated in code. The only external assets are two SIL OFL fonts.
