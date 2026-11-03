#!/usr/bin/env python3
"""Renders the Godot game's sky (Main._environment: a ProceduralSkyMaterial, top 4a8fe0, horizon cfe6f5, ground
6d8f5a) into the six faces of a Roblox skybox, with Godot's own formula. Writes roblox/images/sky_*.png."""
import math
import os
from PIL import Image

TOP, HORIZON, GROUND_H, GROUND = (0x4A, 0x8F, 0xE0), (0xCF, 0xE6, 0xF5), (0xCF, 0xE6, 0xF5), (0x6D, 0x8F, 0x5A)
SKY_CURVE, GROUND_CURVE = 0.15, 0.02
N = 512
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "roblox", "images")


def srgb_to_lin(c):
    c /= 255.0
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def lin_to_srgb(c):
    c = max(0.0, min(1.0, c))
    return round(255 * (12.92 * c if c <= 0.0031308 else 1.055 * c ** (1 / 2.4) - 0.055))


def mix(a, b, t):
    # Godot mixes in linear light
    return tuple(lin_to_srgb(srgb_to_lin(x) + (srgb_to_lin(y) - srgb_to_lin(x)) * t) for x, y in zip(a, b))


def color(y):
    v_angle = math.acos(max(-1.0, min(1.0, y)))
    if y >= 0:
        c = 1.0 - v_angle / (math.pi * 0.5)
        return mix(HORIZON, TOP, max(0.0, min(1.0, 1.0 - (1.0 - c) ** (1.0 / SKY_CURVE))))
    c = (v_angle - math.pi * 0.5) / (math.pi * 0.5)
    return mix(GROUND_H, GROUND, max(0.0, min(1.0, 1.0 - (1.0 - c) ** (1.0 / GROUND_CURVE))))


def face(dirfn):
    img = Image.new("RGB", (N, N))
    px = img.load()
    for j in range(N):
        for i in range(N):
            u = (i + 0.5) / N * 2 - 1
            v = (j + 0.5) / N * 2 - 1
            x, y, z = dirfn(u, v)
            px[i, j] = color(y / math.sqrt(x * x + y * y + z * z))
    return img


os.makedirs(OUT, exist_ok=True)
side = face(lambda u, v: (u, -v, 1.0))     # every side face looks the same: the sky only changes with height
for name in ("ft", "bk", "lf", "rt"):
    side.save(os.path.join(OUT, f"sky_{name}.png"))
face(lambda u, v: (u, 1.0, v)).save(os.path.join(OUT, "sky_up.png"))
face(lambda u, v: (u, -1.0, v)).save(os.path.join(OUT, "sky_dn.png"))
print("wrote 6 sky faces to", OUT)
