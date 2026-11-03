#!/usr/bin/env python3
"""Gives every mesh in a .glb the name of the node that uses it (Godot's glTF writer leaves meshes unnamed, and an
import may name its parts after the mesh). Usage: python3 tools/name_glb_meshes.py file.glb [...]"""
import json
import struct
import sys

for path in sys.argv[1:]:
    data = open(path, "rb").read()
    magic, version, _length = struct.unpack("<III", data[:12])
    assert magic == 0x46546C67, path
    jlen, jtype = struct.unpack("<II", data[12:20])
    doc = json.loads(data[20:20 + jlen])
    rest = data[20 + jlen:]
    for node in doc.get("nodes", []):
        if "mesh" in node and node.get("name"):
            doc["meshes"][node["mesh"]]["name"] = node["name"]
    js = json.dumps(doc, separators=(",", ":")).encode()
    js += b" " * ((4 - len(js) % 4) % 4)
    out = struct.pack("<II", len(js), 0x4E4F534A) + js + rest
    open(path, "wb").write(struct.pack("<III", magic, version, 12 + len(out)) + out)
    print(f"{path}: named {sum(1 for n in doc.get('nodes', []) if 'mesh' in n)} meshes")
