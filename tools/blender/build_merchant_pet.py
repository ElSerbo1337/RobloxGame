"""Builds the travelling merchant pet (#107, MerchantCamel) and renders its preview image.

Run headless (bpy from pip, Python 3.13):
    python tools/blender/build_merchant_pet.py

Same building blocks and output as build_pets.py: assets/models/pets/MerchantCamel.fbx and
assets/previews/pets/MerchantCamel.png (transparent icon). A sandy camel with a hump, a
red-gold saddle blanket, two saddle bags, a little turban with a gem and a gold coin
floating above it, so it reads as "trader".

Without the Studio import the game shows its usual placeholder (round body in the
Mythic rarity colour with eyes, PetService / PetIcon), so nothing breaks before that.
"""

import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import build_pets as bp  # noqa: E402
from build_pets import (  # noqa: E402
    box,
    critter,
    cyl,
    flat,
    round_ears,
    snout_long,
    sph,
    star_points,
    torus,
)

FUR = "D9A55B"
LIGHT = "F2D3A0"
RED = "C8323C"
GOLD = "FFC83A"
PURPLE = "7A3FC8"


def merchant_camel(P):
    head, R = critter(P, FUR, belly=LIGHT, feet_color="6B4A2A", eye_size=0.14, nose="5A3A22", muzzle=LIGHT)
    round_ears(P, FUR, head, R, size=0.12, spread=60, pitch=40, inner=LIGHT)
    snout_long(P, LIGHT, head, R, length=0.38, r=0.2, pitch=-10, nose="5A3A22")
    # Hump on the back with a red-gold saddle blanket over it.
    sph(P, FUR, (0, -0.45, 1.3), 0.4, scale=(0.9, 1, 0.9))
    box(P, RED, (0, -0.2, 1.0), (0.95, 0.4, 0.06), rot=(math.radians(-20), 0, 0), bevel=0.02)
    for x in (-0.47, 0.47):
        box(P, GOLD, (x, -0.2, 0.95), (0.03, 0.52, 0.14), kind="Metal")
    # Saddle bags on both sides.
    for x in (-0.62, 0.62):
        box(P, "8A5A2E", (x, -0.1, 0.72), (0.16, 0.32, 0.3), bevel=0.04)
        cyl(P, GOLD, (x * 1.14, -0.1, 0.74), 0.05, 0.03, rot=(0, math.radians(90), 0), verts=10, kind="Metal")
    # Turban with a purple gem on the head.
    top = (head[0], head[1], head[2] + R * 0.85)
    torus(P, "F4ECDD", top, 0.24, 0.09, seg=16)
    sph(P, "F4ECDD", (top[0], top[1], top[2] + 0.06), 0.2, scale=(1, 1, 0.7))
    sph(P, PURPLE, (top[0], top[1] + 0.27, top[2]), 0.1, kind="Neon")
    # Gold coin floating above.
    cyl(P, GOLD, (0, 0.1, 2.15), 0.17, 0.04, rot=(math.radians(90), 0, 0), verts=18, kind="Metal")
    flat(P, "FFE89A", star_points(0.08, 0.035), 0.02, c=(0, 0.13, 2.15), rot=(math.radians(90), 0, 0), kind="Neon")


MERCHANT = {"MerchantCamel": merchant_camel}
bp.PETS.update(MERCHANT)


if __name__ == "__main__":
    for name in MERCHANT:
        bp.export_pet(name)
