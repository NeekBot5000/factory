#!/bin/sh
# Renders the Godot game's sounds into roblox/sounds/timber-sounds.ogg (upload it to Roblox once) and writes
# roblox/src/shared/SoundSheet.luau, the table of where each sound is in that file.
set -e
cd "$(dirname "$0")/.."
godot --headless --path . res://tools/ExportSounds.tscn
ffmpeg -loglevel error -y -i roblox/sounds/timber-sounds.wav -c:a libvorbis -q:a 6 roblox/sounds/timber-sounds.ogg
rm roblox/sounds/timber-sounds.wav
ls -l roblox/sounds/timber-sounds.ogg
