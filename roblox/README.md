# Timber for Roblox (in progress)

The Roblox version of Timber, written in Luau and synced into Roblox Studio with [Rojo](https://rojo.space/).
The plan (what to do first, and the decisions and optimizations behind this code) is in
[`../docs/roblox-port.md`](../docs/roblox-port.md).

- `src/shared/` - game logic with no Roblox calls (tested from the command line)
- `src/server/` - server scripts: saves, money, trees, machines, oil
- `src/client/` - client scripts: input for keyboard/gamepad/touch, swinging, drawing bark
- `models/` - every machine, decoration and tool from the Godot game as .glb (import with File > Import 3D);
  re-export with `godot --headless --path . res://tools/ExportModels.tscn` from the repo root

**Setting up for the first time: follow [SETUP.md](SETUP.md).**
Run it: `rojo serve` here, then connect from the Rojo plugin in Studio.
Test the logic: `luau tests/run.luau` (Luau tools: https://github.com/luau-lang/luau/releases).
