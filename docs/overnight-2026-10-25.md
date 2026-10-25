# Overnight session, 25 Oct 2026 (16:35-20:35 UTC)

**Goal (your words):** bug fixing and playtesting, ideas for good additions, removing things too buggy to keep,
balancing things so they're comparable, and a founder-style look at the game's potential: what you need to do
and what I need to do.

*Checkpoint, updated as work lands. Final summary at the bottom.*

## Done

### Balance
* **Tool benchmark** (`tests/Bench.tscn`): every stripping tool clears 75% of the same fresh tree with an
  efficient sweep, giving $/minute. Before: the $160 double-bit beat tools costing up to 13x more, and the
  $2,400 auger beat the $6,500 robo-axe. Retuned stats and prices so speed rises with price:

  | Tool | Price before -> after | $/min before -> after |
  |---|---|---|
  | Hatchet | $30 | 326 -> 331 |
  | Double-Bit Axe | $160 | 773 -> 417 (radius .25->.20, swing .9->1.0 s) |
  | Combo Axe | $750 -> **$250** | 382 -> 466 (radius .10->.12) |
  | Twin Hatchets | $300 | 313 -> 509 (radius .12->.15, .24->.22 s) |
  | Bark Scraper | $220 -> **$400** | 988 (outer bark only, half a tree) |
  | Crescent Labrys | $650 -> **$600** | 713 |
  | Ringing Axe | $520 -> **$750** | 966 -> 798 (.95->1.15 s) |
  | Greataxe | $900 | 1045 (you walk at half speed) |
  | Hole Saw | $2,100 | 656 -> 1302 (radius .12->.17) |
  | Timber Auger | $2,400 | 2963 -> 1505 (radius .30->.24, .16->.20 s) |
  | Twin Auger | $3,200 | 1253 -> 2118 (radius .17->.20, .20->.18 s) |
  | Robo-Axe X9 | $6,500 | 2421 (unchanged, now clearly the best) |

* **Inner Gouge** earns $0 on a fresh tree (inner bark only): its shop text now says so, and you get a
  one-time hint when it hits outer bark.
* **Crank** stores 15 s per wind (was 10), up to 2 minutes (was 1).
* **Rocks regrow** one at a time every 75 s (never within 8 m of you, never inside something you built), so
  stone, copper and iron can't run out for good.

### Bugs fixed
* **No way to remove a build.** A misplaced conveyor was permanent. Now: hammer + **X** on a build takes it down
  and refunds what it would sell for.
* **Crash risk:** snipping every leaf off a standing tree, then chopping or sawing it, touched a freed node.
* **Crowns weren't saved:** reloading refilled snipped crowns, which also handed out fresh saplings every reload.
  Snipped and bare crowns now persist.
* **Ramp misaligned with the grid:** it overhung half a cell at each end, leaving gaps to the next belt. It now
  fills its own cell and the one in front. Added a **Stone Pillar** (4 stone, no blueprint) so a belt can carry
  on from the top of a ramp; tested end to end (belt -> ramp -> belt on pillar).
* **Toolbar ran off the screen** once you owned lots of tools; it now shows 9 around the one in hand, with
  "+N" counts either side.
* **Wire spool** clicked at 3 m while its hint looked 4 m, so a click could cancel instead of connecting.
  The wire preview also recoloured a shared material.
* Iron veins looked like snow (now steel blue); live wires glowed like lightning (toned down).
* Machine lamps and wire glow rewrote their materials 20 times a second; now only on change.

* **Machines could stack on machines** when you aimed at a belt to extend it; now only pillars take a machine on top.
* **Blueprints all had the same icon** in the shop; each now shows the machine it unlocks.
* **Values on hover:** looking at a log, a bark piece or an ore chunk shows what it's worth, and rocks say
  what's in them and which pickaxe they need.

### Playtesting and test hardening
* Screenshot playtest of the machine line (`tests/MachineShot.tscn`).
* **Soak test** (`tests/SoakTest.tscn`, now in CI): one of every build, wired machines, 2 minutes of random
  inputs, then save + reload must bring back the same builds and wires. Clean on 6 seeds.
* CI now fails if any test prints a script error (a test could previously print PASS after crashing part-way).
* Fixed two flaky build tests, both caused by the felled log from earlier in the test: the hammer click
  sometimes hit it, and bark released from the vacuum sometimes landed on it. Found by running every suite
  6 times; the vacuum case looked like pieces hanging in mid-air until frame-by-frame diagnostics showed them
  resting on the log, so the game code was left alone.
* `SaveTest` covers snipped crowns, mined and chipped rocks, ore chunks, machines with settings, and wires.
* **Performance:** game logic costs under 1.1 ms per frame even with 600 loose bark pieces and 20 running
  belts, so on weak machines graphics will be the limit. Added an **automatic graphics fallback** for exported
  builds: after 4 s under 40 fps it softens shadows, then drops shadows and two-thirds of the grass, then
  shortens the view, and remembers the level.

* **Web build check:** exported the web build locally and loaded it in headless Chromium. It boots with no
  errors. (github.io itself is blocked from this sandbox, and the software-rendered browser runs at ~1 fps, so
  it can't judge real frame rates.)
* CI test steps now time out after 15 minutes. A test with a parse error used to leave Godot idle forever.

### Documents
* `docs/founder-assessment.md`: potential, riskiest assumption, a free 10-strangers test, who does what.
* `docs/ideas.md`: prioritised additions, what to cut or park, balance notes.

## Parked (needs you)
* **Onboarding / goals checklist.** You had me remove the intro panel. A new player spawns with $0 and no hint.
  Recommendation: a small goals checklist in a HUD corner that hides itself when done.
* **Posting the game publicly** (itch.io etc.) for the strangers test needs your accounts and your OK.
* **Jolt physics warning** ("job system exceeded the maximum number of jobs") appeared once in a soak run. It's
  an engine-level warning that waits rather than crashes; worth watching, nothing to fix in our code.
