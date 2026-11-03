# Overnight session, 3 Nov 2026

GOAL: "keep working until it is the EXACT SAME GAME" (the Roblox version of Timber vs the Godot game), after fixing:
key presses don't work (only clicking and moving), trees turn into lines when touched, graphics aren't the same.
STARTED: 04:06 UTC   ENDS: 12:06 UTC (8 hours)

## Queue
[x] 9. Throwing hatchet, thunder axe, two-man crosscut, pole saw, the phone (see Done)
[ ] 11. Next from Godot: the shears (snip leaves off crowns and bushes), then whatever else the Godot shop sells
    that fits (drill, planer, washer...) as time allows
[ ] 10. Docs, playtest, CI; morning report

## Done
[x] Keys: input now comes straight from UserInputService; E on the hatchet itself takes it (it only worked on the
    stump); found and fixed the ground being 8 studs too high (Rojo ignored the Baseplate's Position, so everything
    was buried). Files: InputController, InteractService, default.project.json, plugin/TimberSync.lua. Commit 581c40a
[x] Client playtest: tests/lune/clientharness.luau + client.luau run the real client scripts against the real server
    scripts in Lune, with key presses, clicks and a camera (17 checks), in CI. Commit 581c40a

[x] Trees drawn panel by panel like Godot's ForestTree (sizes, colours, jitter, birch flecks, inner layer, wood):
    fixes the "lines". Commit e640798
[x] The Godot world exported and rebuilt: tools/ExportRobloxWorld.gd -> world/trucks/tools glb + GodotWorld.luau;
    WorldService builds Godot's ground (voxels from its heights), ~240 trees in place, cabin walls, porch spawn,
    computer = TimberMart, chopping block, truck spot and Godot's truck route; WorldMeshes loads the uploaded meshes.
    Uploaded by the workflow: GodotWorld 74577339810456, GodotTrucks 128707536945262, GodotTools 122305679607294.
    Commits b872efb, ff03b6a
[x] Godot's sky rendered into a skybox (tools/make_sky.py), uploaded; fog colour. Commit ff03b6a
[x] Bark sheets are the exact panels torn off (Godot's Chip), '[E] grab    $0.60' hint. Commit a10d230
[x] Godot's tree hints, Getting started wording with the cabin and computer. Commit 1dabeca
[x] TimberMart delivery: order, van drives in and backs onto the dock beeping, box, click to open, tool rises, E
    takes it. Commit 11d6313
[x] The first-person arm ported from Godot's ARCS and poses. Commit 5addf03
[x] CI fixes: analyze only pure-logic modules; InputTest waits for the dropped tool to settle. Commit 03d33c6
[x] Drifting clouds, wood/stone footsteps, sturdier client start. Commit d5aeb17
[x] Godot's strip_circle ported exactly (circle in metres). Commit b94b7fa
[x] Six more axes: twins, gouge, ringer, spud, spiral, robo (+ combo growth). Commit f5850a3
[x] Godot's title screen, settings, credits. Commit e391fa8
[x] Felling and logs: bow saw, buck saw, chainsaw; stumps, logs with bark, cutting, bucking, carrying, selling;
    per-tree crowns (crowns.glb). Commit bfa6f25

[x] Throwing hatchet (flies 20 m/s, sticks, returns), two-man crosscut (giants, the Legendary Tree, clean cut +20%),
    TimberPhone (shop item, toast with [Tab], sends the truck), shop departments. Commit 8ff0195
[x] Thunder Axe: hold to charge 1.2 s, lightning strips the whole tree, 6 s recharge, bolt/flash/glow. Commit 26b44e1
[x] Pole saw: cuts the crown off; leaves ($0.05 clumps) and 1-2 saplings fall; saplings root and grow into trees in
    5 min. Harness: server warnings shown, default velocity, seedless Random. Commit 9d2fe43
    Checkpoint 07:40 UTC: playtests 109 server + 33 client checks pass locally.

## Parked
- Checking the imports from CI: downloading an uploaded asset needs the API key to have the asset-delivery
  ("legacy-asset") permission, which it doesn't. Optional; the game measures the import itself with marker cubes.
