#!/usr/bin/env python3
"""Looks at the Roblox version in Roblox itself, from CI (the roblox-engine workflow):

1. Roblox's own renders of the uploaded models (the thumbnail service draws them with Roblox's renderer), and
   Roblox's 3D version of each (the OBJ, materials and textures it made from the .glb). These go to
   roblox/tests/engine/out/thumb_<key>.png and out/3d/<key>/, so they can be rendered next to the Godot game.
2. A real Roblox server running the game: it saves the Rojo-built place as a new version of the experience
   (versionType=Saved, so the published game is untouched), runs roblox/tests/engine/run.luau there with Open Cloud
   Luau Execution, and writes what it returns to out/engine.json.

Needs ROBLOX_API_KEY. Part 2 also needs ROBLOX_UNIVERSE_ID and ROBLOX_PLACE_ID, and the key needs the
universe-places Write and universe.place.luau-execution-session Write permissions (roblox/SETUP.md). It never
prints the key, and says exactly which step Roblox refused, so a missing permission is easy to add."""
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
os.makedirs(os.path.join(OUT, "3d"), exist_ok=True)
report = {"steps": []}


def step(name, ok, detail=""):
    report["steps"].append({"step": name, "ok": ok, "detail": detail})
    print(("OK   " if ok else "FAIL ") + name + (f": {detail}" if detail else ""), flush=True)


def http(url, data=None, headers=None, method=None, auth=False, timeout=120):
    h = dict(headers or {})
    if auth:
        h["x-api-key"] = KEY
    req = urllib.request.Request(url, data=data, headers=h, method=method)
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return r.read()


def err_text(e):
    if isinstance(e, urllib.error.HTTPError):
        return f"{e.code} {e.read().decode(errors='replace')[:300]}"
    return str(e)


def cdn(h):
    # Roblox's CDN host for a hash (the same rule its clients use)
    i = 31
    for c in h[:32]:
        i ^= ord(c)
    return f"https://t{i % 8}.rbxcdn.com/{h}"


# ------------------------------------------------------------------ 1. Roblox's renders of the uploaded models
lock = json.load(open(os.path.join(ROOT, "assets.lock.json")))
wanted = {a["key"]: a for a in json.load(open(os.path.join(ROOT, "assets.json")))}
models = {k: v["id"] for k, v in lock.items() if wanted.get(k, {}).get("type") == "Model"}
for k, aid in models.items():
    try:
        got = None
        for _ in range(6):
            info = json.loads(http(f"https://thumbnails.roblox.com/v1/assets?assetIds={aid}&size=768x432&format=Png&isCircular=false"))
            got = (info.get("data") or [{}])[0]
            if got.get("state") == "Completed":
                break
            time.sleep(5)
        if got and got.get("imageUrl"):
            open(os.path.join(OUT, f"thumb_{k}.png"), "wb").write(http(got["imageUrl"]))
            step(f"Roblox's render of {k}", True, got.get("state"))
        else:
            step(f"Roblox's render of {k}", False, json.dumps(got))
    except Exception as e:  # noqa: BLE001
        step(f"Roblox's render of {k}", False, err_text(e))
    try:
        got = None
        for _ in range(6):
            got = json.loads(http(f"https://thumbnails.roblox.com/v1/assets-thumbnail-3d?assetId={aid}"))
            if got.get("state") == "Completed":
                break
            time.sleep(5)
        if got and got.get("imageUrl"):
            meta = json.loads(http(got["imageUrl"]))
            d = os.path.join(OUT, "3d", k)
            os.makedirs(d, exist_ok=True)
            json.dump(meta, open(os.path.join(d, "meta.json"), "w"), indent=1)
            open(os.path.join(d, "model.obj"), "wb").write(http(cdn(meta["obj"])))
            open(os.path.join(d, "model.mtl"), "wb").write(http(cdn(meta["mtl"])))
            for t in meta.get("textures", []):
                open(os.path.join(d, t), "wb").write(http(cdn(t)))
            step(f"Roblox's 3D version of {k}", True, f"{len(meta.get('textures', []))} textures")
        else:
            step(f"Roblox's 3D version of {k}", False, json.dumps(got))
    except Exception as e:  # noqa: BLE001
        step(f"Roblox's 3D version of {k}", False, err_text(e))

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


engine()
json.dump(report, open(os.path.join(OUT, "report.json"), "w"), indent=1)
sys.exit(0)
