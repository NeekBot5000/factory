# Overnight session 2, 3 Nov 2026

GOAL: "Check and make sure it looks exactly the same, once you are confident it is, then add the rest of the things.
Do an overnight session until it is completely done" (the Roblox version of Timber vs the Godot game).
STARTED: 14:22 UTC   ENDS: 22:22 UTC (8 hours)

## Queue
[x] 1. Visual check: render the Godot game and a reconstruction of the Roblox scene (what the Roblox scripts build,
       plus the Godot meshes coloured the way WorldMeshes colours them) from the same cameras, side by side; list
       every difference
[x] 2. Fix the differences found in 1, re-render until they match
[ ] 3. Saving the world: stumps, felled logs, cut crowns and grown trees survive a restart (Godot's WorldSave)
[ ] 4. Small tools: leaf rake, leaf blower, watering can (saplings grow 2x), scale
[ ] 5. Bushes you can snip (Godot's Bush), trophies (Godot's Trophies)
[ ] 6. Mining: rocks/ore, pickaxe, sledge, steel pick, rock drill, core drill, detector, dynamite
[ ] 7. Building: hammer, build menu, hologram placement, blueprints filled by dropping resources (Godot's Builder,
       Blueprint, Builds) with the simple builds first (basket, bench, wheelbarrow...)
[ ] 8. Machines on top of building: crank, lever, button, conveyor, ramp, piston, rotator, windmill, generator,
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

## Parked
