#!/usr/bin/env python3
"""Downloads each uploaded Model asset (roblox/assets.lock.json) and saves it as an .rbxm, so a Lune script can
print what Roblox made of it (part names, sizes, positions). Used by the roblox-assets workflow to check imports.
Needs ROBLOX_API_KEY. Writes build/assets/<key>.rbxm; prints why when an asset can't be fetched."""
import json
import os
import sys
import urllib.error
import urllib.request

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "roblox")
key = os.environ.get("ROBLOX_API_KEY", "")
lock = json.load(open(os.path.join(ROOT, "assets.lock.json")))
wanted = {a["key"]: a for a in json.load(open(os.path.join(ROOT, "assets.json")))}
os.makedirs("build/assets", exist_ok=True)
for k, v in lock.items():
    if wanted.get(k, {}).get("type") != "Model":
        continue
    url = f"https://apis.roblox.com/asset-delivery-api/v1/assetId/{v['id']}"
    try:
        req = urllib.request.Request(url, headers={"x-api-key": key})
        with urllib.request.urlopen(req, timeout=60) as r:
            info = json.loads(r.read())
        loc = info.get("location")
        if not loc:
            print(f"{k}: no download location: {info}")
            continue
        with urllib.request.urlopen(loc, timeout=120) as r:
            data = r.read()
        open(f"build/assets/{k}.rbxm", "wb").write(data)
        print(f"{k}: downloaded {len(data)} bytes")
    except urllib.error.HTTPError as e:
        print(f"{k}: {e.code} {e.read().decode(errors='replace')[:300]}")
    except Exception as e:  # noqa: BLE001
        print(f"{k}: {e}")
sys.exit(0)
