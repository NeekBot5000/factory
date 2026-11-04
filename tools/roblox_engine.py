#!/usr/bin/env python3
"""Looks at the Roblox version in Roblox itself, from CI (the roblox-engine workflow). Results go to
roblox/tests/engine/out/.

1. Roblox's renders of the uploaded models as they are (uncoloured: WorldMeshes colours them in the game):
   thumb_<key>.png.
2. The world as a player sees it, drawn by Roblox's renderer:
   - the converted models and textures Roblox made from the uploads feed the game's own scripts in the Lune harness
     (tests/engine/scenes.luau);
   - each Godot view (tests/engine/views.json) is uploaded as a model with a ThumbnailCamera;
   - Roblox's thumbnail of it is scene_<view>.png, and pair_<view>.jpg puts Godot's view above it.
3. The game in a real Roblox server: the built place is saved as a new version of the experience (versionType=Saved,
   so the published game is untouched), and tests/engine/run.luau runs there with Open Cloud Luau Execution
   (physics, meshes, errors): engine.json.

Needs ROBLOX_API_KEY. The key's permissions:
- Assets Read and Write: for 1 and 2;
- Legacy Assets Manage (legacy-asset:manage): for 2, to download the converted assets;
- universe-places Write and Luau execution sessions Write: for 3, with ROBLOX_UNIVERSE_ID and ROBLOX_PLACE_ID.
It never prints the key, and says which step Roblox refused, so a missing permission is easy to add."""
import json
import os
import sys
import time
import urllib.error
import urllib.request

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "roblox")
OUT = os.path.join(ROOT, "tests", "engine", "out")
KEY = os.environ.get("ROBLOX_API_KEY", "")
UNIVERSE = os.environ.get("ROBLOX_UNIVERSE_ID", "")
PLACE = os.environ.get("ROBLOX_PLACE_ID", "")
PLACE_FILE = os.environ.get("PLACE_FILE", "Timber.rbxl")
os.makedirs(OUT, exist_ok=True)
report = {"steps": []}


def step(name, ok, detail=""):
    report["steps"].append({"step": name, "ok": ok, "detail": detail})
    print(("OK   " if ok else "FAIL ") + name + (f": {detail}" if detail else ""), flush=True)


def http(url, data=None, headers=None, method=None, auth=False, timeout=120):
    h = dict(headers or {})
    if auth:
        h["x-api-key"] = KEY
    for attempt in range(6):
        req = urllib.request.Request(url, data=data, headers=h, method=method)
        try:
            with urllib.request.urlopen(req, timeout=timeout) as r:
                return r.read()
        except urllib.error.HTTPError as e:
            if e.code != 429 or attempt == 5:
                raise
            time.sleep(10 * (attempt + 1))      # (Roblox's rate limit: wait and try again)


def err_text(e):
    if isinstance(e, urllib.error.HTTPError):
        return f"{e.code} {e.read().decode(errors='replace')[:300]}"
    return str(e)


# ------------------------------------------------------------------ 1. Roblox's renders of the uploaded models
lock = json.load(open(os.path.join(ROOT, "assets.lock.json")))
wanted = {a["key"]: a for a in json.load(open(os.path.join(ROOT, "assets.json")))}
models = {k: v["id"] for k, v in lock.items() if wanted.get(k, {}).get("type") == "Model"}


def thumbnail(aid, dest):
    """Roblox's render of an asset (its thumbnail), saved as a PNG. Returns the state, or raises."""
    got = {}
    for _ in range(24):
        info = json.loads(http(f"https://thumbnails.roblox.com/v1/assets?assetIds={aid}&size=768x432&format=Png&isCircular=false"))
        got = (info.get("data") or [{}])[0]
        if got.get("state") in ("Completed", "Blocked", "Error"):
            break
        time.sleep(5)
    if got.get("imageUrl") and got.get("state") == "Completed":
        open(dest, "wb").write(http(got["imageUrl"]))
    return got.get("state")


# ------------------------------------------------------------------ 1b. the world as a player sees it, drawn by Roblox
# The converted models and textures Roblox made from the uploads, fed to the game's own WorldMeshes in the Lune
# harness (tests/engine/scenes.luau); each Godot view is uploaded as a model with a ThumbnailCamera, and Roblox's
# thumbnail of it is the scene drawn by Roblox's renderer: out/scene_<view>.png, out/pair_<view>.jpg (Godot above).
def scenes():
    os.makedirs("build/assets", exist_ok=True)
    missing = []
    for k, v in lock.items():
        if wanted.get(k, {}).get("type") not in ("Model", "Decal"):
            continue
        try:
            info = json.loads(http(f"https://apis.roblox.com/asset-delivery-api/v1/assetId/{v['id']}", auth=True))
            open(f"build/assets/{k}.rbxm", "wb").write(http(info["location"]))
        except Exception as e:  # noqa: BLE001
            missing.append(f"{k}: {err_text(e)}")
    if missing:
        step("download what Roblox made of the uploads", False,
             f"{len(missing)} failed, e.g. {missing[0]} - the key needs the legacy-asset:manage permission (Legacy Assets > Manage)")
        return
    step("download what Roblox made of the uploads", True)
    # (kept in the repo too, so the scenes can be rebuilt and checked without Roblox: roblox/tests/engine/cache/)
    import shutil
    cache = os.path.join(ROOT, "tests", "engine", "cache")
    os.makedirs(cache, exist_ok=True)
    for f in os.listdir("build/assets"):
        shutil.copy(os.path.join("build/assets", f), os.path.join(cache, f))
    import subprocess
    env = dict(os.environ, TIMBER_ASSETS="build/assets")
    r = subprocess.run([os.environ.get("LUNE", "./luau/lune"), "run", "roblox/tests/engine/scenes.luau", PLACE_FILE, "build/scenes"],
                       env=env, capture_output=True, text=True, timeout=900)
    print("\n".join(l for l in (r.stdout + r.stderr).splitlines() if l.startswith("SCENES") or "warn" in l.lower() or "error" in l.lower())[:6000], flush=True)
    if r.returncode != 0:
        step("build the scenes with the game's scripts", False, (r.stderr or r.stdout)[-600:])
        return
    step("build the scenes with the game's scripts", True)
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    import roblox_assets as ra
    user = os.environ.get("ROBLOX_USER_ID", "")
    slock_path = os.path.join(ROOT, "tests", "engine", "scenes.lock.json")
    slock = json.load(open(slock_path)) if os.path.exists(slock_path) else {}
    views = json.load(open(os.path.join(ROOT, "tests", "engine", "views.json")))
    for v in views:
        name = v["name"]
        path = f"build/scenes/{name}.rbxm"
        req = {"assetType": "Model", "displayName": f"Timber view {name}", "description": "Timber: a view of the game for the visual check",
               "creationContext": {"creator": {"userId": str(user)}}}
        try:
            aid = None
            if name in slock:
                try:
                    body, btype = ra.multipart({**req, "assetId": slock[name]}, path, "model/x-rbxm")
                    aid = ra.wait(ra.call("PATCH", f"{ra.API}/assets/{slock[name]}", KEY, body, btype), KEY)
                except RuntimeError as e:
                    print(f"{name}: couldn't update ({e}), uploading anew", flush=True)
            if aid is None:
                body, btype = ra.multipart(req, path, "model/x-rbxm")
                aid = ra.wait(ra.call("POST", f"{ra.API}/assets", KEY, body, btype), KEY)
            slock[name] = aid
            state = thumbnail(aid, os.path.join(OUT, f"scene_{name}.png"))
            step(f"Roblox's render of the {name} view", state == "Completed", f"asset {aid}: {state}")
        except Exception as e:  # noqa: BLE001
            step(f"Roblox's render of the {name} view", False, err_text(e))
    json.dump(slock, open(slock_path, "w"), indent=2, sort_keys=True)
    try:
        from PIL import Image
        for v in views:
            g = os.path.join(ROOT, "tests", "engine", "godot", f"godot_{v['name']}.jpg")
            r_ = os.path.join(OUT, f"scene_{v['name']}.png")
            if os.path.exists(g) and os.path.exists(r_):
                a, b = Image.open(g).convert("RGB"), Image.open(r_).convert("RGB").resize(Image.open(g).size)
                im = Image.new("RGB", (a.width, a.height * 2))
                im.paste(a, (0, 0))
                im.paste(b, (0, a.height))
                im.save(os.path.join(OUT, f"pair_{v['name']}.jpg"), quality=85)
    except Exception as e:  # noqa: BLE001
        print("pairs:", e, flush=True)


# ------------------------------------------------------------------ 2. the game in a real Roblox server
def engine():
    if not (KEY and UNIVERSE and PLACE):
        step("run the game in a Roblox server", False, "set ROBLOX_UNIVERSE_ID and ROBLOX_PLACE_ID (repository variables) and ROBLOX_API_KEY")
        return
    try:
        body = open(PLACE_FILE, "rb").read()
        res = json.loads(http(f"https://apis.roblox.com/universes/v1/{UNIVERSE}/places/{PLACE}/versions?versionType=Saved", data=body,
                              headers={"Content-Type": "application/octet-stream"}, method="POST", auth=True))
        version = res["versionNumber"]
        step("save the built place as a new version (not published)", True, f"version {version}")
    except Exception as e:  # noqa: BLE001
        step("save the built place as a new version (not published)", False,
             err_text(e) + " - the key needs universe-places Write for this experience")
        return
    script = open(os.path.join(ROOT, "tests", "engine", "run.luau")).read()
    try:
        task = json.loads(http(f"https://apis.roblox.com/cloud/v2/universes/{UNIVERSE}/places/{PLACE}/versions/{version}/luau-execution-session-tasks",
                               data=json.dumps({"script": script, "timeout": "290s"}).encode(),
                               headers={"Content-Type": "application/json"}, method="POST", auth=True))
        path = task["path"]
        step("start a Luau execution task on it", True, path)
    except Exception as e:  # noqa: BLE001
        step("start a Luau execution task on it", False,
             err_text(e) + " - the key needs universe.place.luau-execution-session Write for this experience")
        return
    state, t = None, None
    deadline = time.time() + 420
    while time.time() < deadline:
        time.sleep(5)
        try:
            t = json.loads(http(f"https://apis.roblox.com/cloud/v2/{path}", auth=True))
        except Exception as e:  # noqa: BLE001
            print("poll:", err_text(e), flush=True)
            continue
        state = t.get("state")
        if state in ("COMPLETE", "FAILED", "CANCELLED"):
            break
    try:
        logs = json.loads(http(f"https://apis.roblox.com/cloud/v2/{path}/logs?maxPageSize=10000", auth=True))
    except Exception as e:  # noqa: BLE001
        logs = {"error": err_text(e)}
    json.dump(logs, open(os.path.join(OUT, "engine_logs.json"), "w"), indent=1)
    if state != "COMPLETE":
        step("the task finished", False, f"{state}: {json.dumps((t or {}).get('error'))[:600]}")
        return
    results = (t.get("output") or {}).get("results") or []
    data = json.loads(results[0]) if results and isinstance(results[0], str) else results
    json.dump(data, open(os.path.join(OUT, "engine.json"), "w"), indent=1)
    step("the task finished", True)
    for c in (data or {}).get("checks", []):
        print(("PASS " if c.get("ok") else "FAIL ") + c.get("name", "?") + "  " + json.dumps(c.get("detail")), flush=True)
    for line in (data or {}).get("logs", []):
        print("LOG  " + line, flush=True)


for k, aid in models.items():
    try:
        state = thumbnail(aid, os.path.join(OUT, f"thumb_{k}.png"))
        step(f"Roblox's render of {k} (uncoloured: WorldMeshes colours it in the game)", state == "Completed", state)
    except Exception as e:  # noqa: BLE001
        step(f"Roblox's render of {k}", False, err_text(e))
scenes()
engine()
json.dump(report, open(os.path.join(OUT, "report.json"), "w"), indent=1)
sys.exit(0)
