#!/bin/sh
# Exports the Godot game's world, trucks and tools for the Roblox version (roblox/models/godot/*.glb and
# roblox/src/shared/GodotWorld.luau). Commit and push: GitHub uploads the meshes and the game loads them.
set -e
cd "$(dirname "$0")/.."
# (a real renderer, under a virtual display: the headless one keeps no MultiMesh data, so the grass would be lost, and
# the ground's textures are rendered with the terrain's own shader)
xvfb-run -a godot --path . res://tools/ExportRobloxWorld.tscn --rendering-driver opengl3
python3 tools/name_glb_meshes.py roblox/models/godot/*.glb
