# Timber

A low-poly, first-person lumberjack game (prototype), built in **Godot 4.4**.

You start with nothing but your bare hands: a log cabin in a clearing, surrounded by forest.
**Karate-chop trees to strip their bark**, and every chop hurts. Each hit knocks off a small piece exactly
where your hand lands, and you can see the layers come away: the dark **outer bark** first, then the
orange **inner bark**, then the pale **wood** underneath. There is no inventory: every piece is a physics
object you pick up and carry in your hands.

## Play

* **Download a build:** open the latest successful run under the repo's *Actions* tab, scroll to *Artifacts*
  and grab **Timber-windows** (or -linux / -web).
* **Or open it in Godot 4.4:** *Import* `project.godot`, then press **F5**.

| Control | Action |
|---|---|
| WASD / arrows | move |
| Mouse | look (click the window to capture the mouse, Esc to release) |
| Shift / Space | sprint / jump |
| Left click | karate chop (costs health) |
| E or right click | pick up / drop the piece you're looking at |
| Left click while holding | throw it |

Health regenerates slowly when you stop hurting yourself. Hit zero and you black out and wake up at the cabin.

## Prototype scope / roadmap

Done: first-person movement, cabin + forest, layered bark trees that strip where you hit, damage and fainting,
physically carrying pieces.

Next, per the plan: axes (no more damage, bigger pieces), selling bark, saws that strip whole logs (sell the
bark and the log separately, or the whole log), better axes, chainsaws, a long axe that slices straight through,
and realistic robots and drones that start slow and help haul bark and logs back to base.

## Code

```
scripts/Main.gd        scene: sky, terrain, cabin, forest, spawning chips
scripts/Player.gd      first-person controller, karate chop, health, carrying
scripts/ForestTree.gd  trunk built from outer-bark / inner-bark panel grids over a wood core
scripts/Chip.gd        a physical piece of bark
scripts/Cabin.gd       procedural log cabin       scripts/Terrain.gd  rolling forest floor
scripts/Hud.gd         crosshair, health, hints   scripts/Sfx.gd      procedural sounds
tests/ChopTest.tscn    headless gameplay test     tests/Shot.tscn     screenshots (xvfb)
```
All models and sounds are generated in code. The only external assets are two SIL OFL fonts.
