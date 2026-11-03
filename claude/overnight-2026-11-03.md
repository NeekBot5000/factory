# Overnight session, 3 Nov 2026

GOAL: "keep working until it is the EXACT SAME GAME" (the Roblox version of Timber vs the Godot game), after fixing:
key presses don't work (only clicking and moving), trees turn into lines when touched, graphics aren't the same.
STARTED: 04:06 UTC   ENDS: 12:06 UTC (8 hours)

## Queue
[ ] 1. Keys: find why E/Q/1-9/Shift do nothing; make input robust (UserInputService, controllers can't take each other down)
[ ] 2. Client harness in Lune: run the real client scripts with key presses, so client bugs show up without Studio
[ ] 3. Trees: port Godot's tree look and bark (ForestTree.gd) so peeling looks the same, and fix the "lines"
[ ] 4. World look: Godot's sky, fog, sun, ground colours, grass tufts, hills
[ ] 5. Tool models: the Godot tool meshes (Tools.gd) instead of the made-up ones
[ ] 6. Godot bark sheets (Chip.gd): shape, colours, how they fly off
[ ] 7. The cabin, porch and chopping block from Godot (Cabin.gd, Main.gd)
[ ] 8. The Godot truck model (Truck.gd)
[ ] 9. Re-check every number and rule against the Godot scripts (swing poses, hints, sounds)
[ ] 10. Docs, playtest, CI; morning report

## Done

## Parked
