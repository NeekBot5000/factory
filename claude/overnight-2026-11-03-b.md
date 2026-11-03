# Overnight session 2, 3 Nov 2026

GOAL: "Check and make sure it looks exactly the same, once you are confident it is, then add the rest of the things.
Do an overnight session until it is completely done" (the Roblox version of Timber vs the Godot game).
STARTED: 14:22 UTC   ENDS: 22:22 UTC (8 hours)

## Queue
[x] 1. Visual check: render the Godot game and a reconstruction of the Roblox scene (what the Roblox scripts build,
       plus the Godot meshes coloured the way WorldMeshes colours them) from the same cameras, side by side; list
       every difference
[x] 2. Fix the differences found in 1, re-render until they match
[x] 3. Saving the world: stumps, felled logs, cut crowns and grown trees survive a restart (Godot's WorldSave)
[x] 4. Small tools: leaf rake, leaf blower, watering can (saplings grow 2x), scale
[x] 5. Bushes you can snip (Godot's Bush), trophies (Godot's Trophies)
[x] 6. Mining: rocks/ore, pickaxe, sledge, steel pick, rock drill, core drill, detector, dynamite
[x] 7. Building: hammer, build menu, hologram placement, blueprints filled by dropping resources (Godot's Builder,
       Blueprint, Builds) with the simple builds first (basket, bench, wheelbarrow...)
[x] 8. Machines on top of building: crank, lever, button, conveyor, ramp, piston, rotator, windmill, generator,
       battery, logic, sensors, lamp, sawmill, chipper, planter, sprinkler, feller, smelter, kiln, assembler,
       grabber, sorter, crate, wireless, drill rig, charger
[ ] 9. Rails and carts, drones, oil, truck upgrades, truck caller
[ ] 10. Docs, ledger, morning report

## Done
[x] Visual check: tools/roblox_view.sh (RobloxView.gd + roblox/tests/lune/dump.luau) renders Godot and the Roblox
    build (real scripts dumped from Lune + the uploaded meshes coloured like WorldMeshes) from 9 cameras side by side.
    Found and fixed: grass tufts/flowers lost (headless export, now xvfb); flat ground (Godot's terrain shader baked
    to 16 textures, TextureID); company sign missing (now SignService with Godot's 6 tiers from props.glb); cabin lamp
    unlit (lights exported, PointLight) and not glowing (emissive -> Neon); chimney smoke frozen (client animates
    Godot's puffs). Matches now: ground, grass, trees and bark panels, crowns, cabin inside and out, truck, dock,
    rocks, bushes, sky. Commits c8642ec + next. Not checkable here: Roblox's own lighting/renderer (render uses
    Godot's sun and fog for both), and the glTF UV orientation of the ground textures in Roblox's importer.

[x] Lamp light + glow, chimney smoke (client animates Godot's puffs), props in ReplicatedStorage. Commit 2e645c4
[x] Building: hammer, Godot's build menu, hologram placement (R/wheel/click/E), plans filled part by part with
    dropped bark/logs/leaves, completion toast, E cancel, X take-down; all 76 builds' models exported part by part
    (props.glb + GodotBuilds.luau); land: 4 start plots, per-player for-sale signs and stakes, buying plots.
    Commits 448b10d, client test.
[x] Finished builds: campfire, compost, catapult, hoop + ball, hammock, basket/wheelbarrow (carry), truck sells
    builds. Commit 41e3527. Checkpoint 16:08 UTC: 141 server + 38 client checks.

[x] Saving: builds, plans, machine state and wires saved with each player (commit a77d111 + later)
[x] Mining: pickaxes, rock/core drills, sledge, shafts with Godot's richness grid, rocks, ore chunks (4ea82c7)
[x] Small tools: rake, blower, watering can, scale, ore detector (e5f68c6)
[x] Bushes (snip, trim away) and the trophy wall (bfee6ec)
[x] Machines: 34 blueprints, Wire Spool, Godot's circuit (crank, windmill, generator, battery, lever, button,
    lamp, bell, belts, truck caller) (d3ad062); production: sawmill, smelter, kiln, chipper, assembler (4d3e63b);
    logic gates + pressure plate + item sensor (04b4bdf); crate, sprinkler, planter, grabber, piston, sorter,
    splitter, wireless (d0a9948); oil pump, refinery, Big Truck, Log Hauler (d726557).
    Checkpoint 17:51 UTC: 179 server + 38 client checks.
[x] Tree feller and drill rig (hand them a saw / drill with E) (540ff43); level sensor and charger, battery cell
    charge hints (46ad2ac); rotator: hammer sticks/lets go, spins powered, saved (latest). The playtest now clears
    up the drill rig, which kept adding chunks and broke the anti-cheat counts in CI run 156.
    Checkpoint 18:53 UTC: 187 server + 38 client checks.

## Parked
