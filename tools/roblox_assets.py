#!/usr/bin/env python3
"""Uploads Timber's Roblox assets (sounds, images, models) with Roblox Open Cloud, and writes their IDs into the game.

  roblox/assets.json          what to upload: [{"key", "file", "type", "name"}]
  roblox/assets.lock.json     what's been uploaded: key -> {"sha256", "id"} (only new or changed files go up)
  roblox/src/shared/Assets.luau   key -> asset id, for the game to read (made from the lock file)

Needs ROBLOX_API_KEY (an Open Cloud key with the Assets API's read and write permissions) and ROBLOX_USER_ID (the
account that owns the key). GitHub Actions runs this on every push that changes an asset
(.github/workflows/roblox-assets.yml). It can also run by hand: python3 tools/roblox_assets.py [--dry-run]
"""
import hashlib
import json
import os
import sys
import time
import urllib.error
import urllib.request
import uuid

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "roblox")
API = os.environ.get("ROBLOX_ASSETS_API", "https://apis.roblox.com/assets/v1")   # (tests point this at a fake)
CONTENT_TYPES = {
    ".ogg": "audio/ogg", ".mp3": "audio/mpeg", ".wav": "audio/wav", ".flac": "audio/flac",
    ".png": "image/png", ".jpg": "image/jpeg", ".jpeg": "image/jpeg", ".bmp": "image/bmp", ".tga": "image/tga",
    ".fbx": "model/fbx", ".glb": "model/gltf-binary", ".gltf": "model/gltf+json",
}


def multipart(request: dict, path: str, content_type: str):
    boundary = uuid.uuid4().hex
    with open(path, "rb") as f:
        data = f.read()
    body = (
        f"--{boundary}\r\nContent-Disposition: form-data; name=\"request\"\r\n\r\n{json.dumps(request)}\r\n"
        f"--{boundary}\r\nContent-Disposition: form-data; name=\"fileContent\"; filename=\"{os.path.basename(path)}\"\r\n"
        f"Content-Type: {content_type}\r\n\r\n"
    ).encode() + data + f"\r\n--{boundary}--\r\n".encode()
    return body, f"multipart/form-data; boundary={boundary}"


def call(method: str, url: str, key: str, body: bytes | None = None, content_type: str | None = None) -> dict:
    req = urllib.request.Request(url, data=body, method=method, headers={"x-api-key": key})
    if content_type:
        req.add_header("Content-Type", content_type)
    try:
        with urllib.request.urlopen(req, timeout=120) as res:
            return json.loads(res.read() or b"{}")
    except urllib.error.HTTPError as e:
        raise RuntimeError(f"{method} {url}: {e.code} {e.read().decode(errors='replace')[:500]}") from None


def wait(op: dict, key: str) -> str:
    """Polls an upload operation until Roblox has processed it; returns the asset id."""
    path = op.get("path") or ""
    for _ in range(60):
        if op.get("done"):
            if "response" in op:
                return str(op["response"]["assetId"])
            raise RuntimeError(f"upload failed: {json.dumps(op.get('error') or op)}")
        time.sleep(2)
        op = call("GET", f"{API}/{path}", key)
    raise RuntimeError(f"upload still processing after 2 minutes: {path}")


def write_luau(lock: dict) -> None:
    lines = [f'\t{k} = "{v["id"]}",' for k, v in sorted(lock.items())]
    text = ("--!strict\n-- Asset IDs on Roblox, made by tools/roblox_assets.py after each upload. Don't edit by hand.\n"
            "return {\n" + "\n".join(lines) + ("\n" if lines else "") + "}\n")
    with open(os.path.join(ROOT, "src", "shared", "Assets.luau"), "w") as f:
        f.write(text)


def main() -> int:
    dry = "--dry-run" in sys.argv
    with open(os.path.join(ROOT, "assets.json")) as f:
        wanted = json.load(f)
    lock_path = os.path.join(ROOT, "assets.lock.json")
    lock = {}
    if os.path.exists(lock_path):
        with open(lock_path) as f:
            lock = json.load(f)
    key = os.environ.get("ROBLOX_API_KEY", "")
    user = os.environ.get("ROBLOX_USER_ID", "")
    if not dry and (not key or not user):
        print("ROBLOX_API_KEY and ROBLOX_USER_ID aren't set: nothing uploaded (see roblox/SETUP.md).")
        if os.environ.get("REQUIRE_KEY"):
            print("::error::The ROBLOX_API_KEY secret is empty here. Add it under Settings > Secrets and variables >"
                  " Actions > Secrets > New repository secret (not an Environment, Codespaces or Dependabot secret).")
            return 1
        return 0
    changed = 0
    for a in wanted:
        path = os.path.join(ROOT, a["file"])
        with open(path, "rb") as f:
            digest = hashlib.sha256(f.read()).hexdigest()
        old = lock.get(a["key"])
        if old and old["sha256"] == digest:
            print(f"{a['key']}: up to date ({old['id']})")
            continue
        ctype = CONTENT_TYPES[os.path.splitext(path)[1].lower()]
        request = {
            "assetType": a["type"],
            "displayName": a["name"],
            "description": a.get("description", "Timber game asset"),
            "creationContext": {"creator": {"userId": str(user or "0")}},
        }
        if dry:
            body, btype = multipart(request, path, ctype)
            print(f"{a['key']}: would upload {a['file']} ({len(body)} bytes, {btype.split(';')[0]}, {ctype})")
            continue
        asset_id = None
        if old:
            # a new version of the same asset keeps its id (if Roblox allows updating this type)
            try:
                body, btype = multipart({**request, "assetId": old["id"]}, path, ctype)
                asset_id = wait(call("PATCH", f"{API}/assets/{old['id']}", key, body, btype), key)
                print(f"{a['key']}: updated {asset_id}")
            except RuntimeError as e:
                print(f"{a['key']}: couldn't update, uploading as a new asset ({e})")
        if asset_id is None:
            body, btype = multipart(request, path, ctype)
            asset_id = wait(call("POST", f"{API}/assets", key, body, btype), key)
            print(f"{a['key']}: uploaded as {asset_id}")
        lock[a["key"]] = {"sha256": digest, "id": asset_id}
        changed += 1
    if not dry:
        with open(lock_path, "w") as f:
            json.dump(lock, f, indent=2, sort_keys=True)
            f.write("\n")
        write_luau(lock)
    print(f"ASSETS done: {changed} uploaded")
    return 0


if __name__ == "__main__":
    sys.exit(main())
