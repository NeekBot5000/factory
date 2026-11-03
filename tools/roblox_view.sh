#!/bin/sh
# The visual check: renders this game and what the Roblox scripts build from the same cameras, side by side.
#   tools/roblox_view.sh [out dir]      (needs rojo, lune, godot and xvfb-run; writes pair_<view>.png)
set -e
cd "$(dirname "$0")/.."
OUT="${1:-/tmp/roblox_view}"
mkdir -p "$OUT"
rojo build -o "$OUT/Timber.rbxl" roblox
xvfb-run -a godot --path . res://tools/RobloxView.tscn --rendering-driver opengl3 -- godot "$OUT"
lune run roblox/tests/lune/dump.luau "$OUT/Timber.rbxl" "$OUT/roblox_scene.json" "$OUT/views.json"
xvfb-run -a godot --path . res://tools/RobloxView.tscn --rendering-driver opengl3 -- roblox "$OUT" "$OUT/roblox_scene.json"
python3 - "$OUT" <<'PY'
import sys, glob, os
from PIL import Image
out = sys.argv[1]
for g in glob.glob(out + "/godot_*.png"):
    v = os.path.basename(g)[6:-4]
    a, b = Image.open(g), Image.open(f"{out}/roblox_{v}.png")
    w, h = a.size
    im = Image.new("RGB", (w, h * 2))
    im.paste(a, (0, 0))
    im.paste(b, (0, h))
    im.save(f"{out}/pair_{v}.png")
print("pairs in", out, "(top: Godot, bottom: Roblox)")
PY
