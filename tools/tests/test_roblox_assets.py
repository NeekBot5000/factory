#!/usr/bin/env python3
"""Runs tools/roblox_assets.py against a fake Open Cloud server: upload, wait for processing, write the ids back,
and skip files that haven't changed. python3 tools/tests/test_roblox_assets.py"""
import http.server
import json
import os
import shutil
import subprocess
import sys
import tempfile
import threading

HERE = os.path.dirname(os.path.abspath(__file__))
seen = []


class Fake(http.server.BaseHTTPRequestHandler):
    polls = 0

    def log_message(self, *a):
        pass

    def reply(self, obj):
        data = json.dumps(obj).encode()
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.end_headers()
        self.wfile.write(data)

    def do_POST(self):
        body = self.rfile.read(int(self.headers["Content-Length"]))
        seen.append(("POST", self.path, self.headers["x-api-key"], self.headers["Content-Type"], body))
        self.reply({"path": "operations/op1", "done": False})

    def do_GET(self):
        Fake.polls += 1
        seen.append(("GET", self.path))
        if Fake.polls < 2:
            self.reply({"path": "operations/op1", "done": False})
        else:
            self.reply({"path": "operations/op1", "done": True, "response": {"assetId": "1234567"}})


def main():
    srv = http.server.HTTPServer(("127.0.0.1", 0), Fake)
    threading.Thread(target=srv.serve_forever, daemon=True).start()
    tmp = tempfile.mkdtemp()
    os.makedirs(os.path.join(tmp, "tools"))
    os.makedirs(os.path.join(tmp, "roblox", "src", "shared"))
    os.makedirs(os.path.join(tmp, "roblox", "sounds"))
    shutil.copy(os.path.join(HERE, "..", "roblox_assets.py"), os.path.join(tmp, "tools"))
    with open(os.path.join(tmp, "roblox", "sounds", "a.ogg"), "wb") as f:
        f.write(b"OggS fake audio")
    with open(os.path.join(tmp, "roblox", "assets.json"), "w") as f:
        json.dump([{"key": "SoundSheet", "file": "sounds/a.ogg", "type": "Audio", "name": "Timber sounds"}], f)
    env = dict(os.environ, ROBLOX_API_KEY="k123", ROBLOX_USER_ID="42", ROBLOX_ASSETS_API=f"http://127.0.0.1:{srv.server_port}/assets/v1",
               NO_PROXY="127.0.0.1", no_proxy="127.0.0.1")
    run = lambda: subprocess.run([sys.executable, os.path.join(tmp, "tools", "roblox_assets.py")], env=env, capture_output=True, text=True)
    fails = 0

    def check(ok, msg):
        nonlocal fails
        print(("PASS " if ok else "FAIL ") + msg)
        fails += 0 if ok else 1

    out = run()
    post = [s for s in seen if s[0] == "POST"]
    check(out.returncode == 0 and len(post) == 1, "uploads the new file once")
    if post:
        _, path, key, ctype, body = post[0]
        req = json.loads(body.split(b'name="request"\r\n\r\n')[1].split(b"\r\n")[0])
        check(path == "/assets/v1/assets" and key == "k123" and ctype.startswith("multipart/form-data"), "to the Assets API, with the key")
        check(req["assetType"] == "Audio" and req["creationContext"]["creator"]["userId"] == "42", "as audio owned by the right account")
        check(b"Content-Type: audio/ogg" in body and b"OggS fake audio" in body, "with the file as audio/ogg")
    check(any(s[0] == "GET" and s[1] == "/assets/v1/operations/op1" for s in seen), "waits for Roblox to process it")
    luau = open(os.path.join(tmp, "roblox", "src", "shared", "Assets.luau")).read()
    check('SoundSheet = "1234567"' in luau, "writes the new id where the game reads it")
    n = len(seen)
    out2 = run()
    check(out2.returncode == 0 and len(seen) == n and "up to date" in out2.stdout, "doesn't upload an unchanged file again")
    env2 = dict(env, ROBLOX_API_KEY="")
    out3 = subprocess.run([sys.executable, os.path.join(tmp, "tools", "roblox_assets.py")], env=env2, capture_output=True, text=True)
    check(out3.returncode == 0 and "aren't set" in out3.stdout, "without a key it says so and does nothing")
    srv.shutdown()
    shutil.rmtree(tmp)
    print("\nASSETS TEST RESULT: " + ("PASS" if fails == 0 else "FAIL"))
    return 1 if fails else 0


if __name__ == "__main__":
    sys.exit(main())
