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
| Double-Bit Axe | $160 | alternating diagonal chops from both sides |
| Crescent Labrys | $650 | big spinning diagonal slam, huge patch |
| Bow Saw | $450 | hold on a trunk to fell the tree; hold on a log to cut it in two |
| Pruning Shears | $90 | snip clumps of leaves off bushes and crowns (felled trees keep theirs) |
| Timber Auger | $2400 | hold the mouse button and it bores bark off continuously |
| Builder's Hammer | $120 | build things from what you gather |
| Leaf Vacuum | $1200 | sucks loose bark/leaves/boxes into a floating clump; let go to drop |
| TimberPhone | $350 | the store and the truck, from anywhere (Tab) |

Logs keep their bark, so you can still strip them; the mill pays for timber plus a little for bark left on.

**Building:** take out the hammer, scroll to pick a plan, click for a hologram, click to set it down (the hoop
then takes its height from where you look). Drop materials into the hologram and each piece fills in; any
kind of bark or wood counts, leaves too. E on a plan cancels it and gives everything back.

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
| Basketball Hoop | 12 bark + 1 log | height set by where you look |
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
| 1-9 / mouse wheel | switch tools (with the hammer, the wheel picks a build) |
| Tab | phone (once you own it) |

Progress saves automatically.

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
