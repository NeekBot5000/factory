"""Gives the exported web game's data file a per-build name (index.<version>.pck) and points the page at it.

Browsers and GitHub Pages cache index.pck by name, so after a deploy players could keep getting the old game
for a while. A new name on every build means the page always loads the build it came with.
Usage: python3 tools/version_web_pack.py build/web <version>
"""
import json
import os
import re
import sys

web, version = sys.argv[1], sys.argv[2]
html_path = os.path.join(web, "index.html")
html = open(html_path, encoding="utf-8").read()
m = re.search(r"GODOT_CONFIG = (\{.*?\});", html)
config = json.loads(m.group(1))
pack = "index.%s.pck" % version
os.replace(os.path.join(web, "index.pck"), os.path.join(web, pack))
config["mainPack"] = pack
sizes = config.get("fileSizes", {})
if "index.pck" in sizes:
    sizes[pack] = sizes.pop("index.pck")
html = html[: m.start(1)] + json.dumps(config, separators=(",", ":")) + html[m.end(1):]
open(html_path, "w", encoding="utf-8").write(html)
print("web pack ->", pack)
