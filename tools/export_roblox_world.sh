#!/bin/sh
# Exports the Godot game's world, trucks and tools for the Roblox version (roblox/models/godot/*.glb and
# roblox/src/shared/GodotWorld.luau). Commit and push: GitHub uploads the meshes and the game loads them.
set -e
cd "$(dirname "$0")/.."
godot --headless --path . res://tools/ExportRobloxWorld.tscn
python3 tools/name_glb_meshes.py roblox/models/godot/*.glb
