"""Builds the login calendar pet (#101, CalendarFox) and renders its preview image.

Run headless (bpy from pip, Python 3.13):
    python tools/blender/build_calendar_pet.py

Same building blocks and output as build_pets.py: assets/models/pets/CalendarFox.fbx and
assets/previews/pets/CalendarFox.png (transparent icon). The pet is a day-30 trophy: a
warm orange fox wearing a little tear-off calendar between its ears (red binding with metal
rings, cream page with a gold "30" star), a golden laurel collar and a few Neon confetti
stars, so it reads as "special reward" without the Secret halo.

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
    pointed_ears,
    snout_long,
    sph,
    star_points,
    torus,
)
from mathutils import Vector  # noqa: E402

FUR = "F28A2E"
CREAM = "FFF1DA"
RED = "E8453C"
GOLD = "FFC83A"


def calendar_fox(P):
    head, R = critter(P, FUR, belly=CREAM, feet_color="3A2A2A", eye_size=0.15, nose="3A2A2A", muzzle=CREAM)
    pointed_ears(P, FUR, head, R, size=0.21, height=0.44, inner=CREAM)
    snout_long(P, CREAM, head, R, length=0.18, r=0.2, pitch=-18, nose="3A2A2A")
    # Big bushy tail with a cream tip.
    for i in range(5):
        t = i / 4
        sph(P, FUR if i < 4 else CREAM, (0.1 * t, -0.58 - t * 0.35, 0.5 + t * 0.55), 0.22 + math.sin(t * math.pi) * 0.08)
    # Golden laurel collar with a gold medal in front.
    torus(P, GOLD, (0, 0.1, 0.84), 0.3, 0.06, seg=16, kind="Metal")
    cyl(P, GOLD, (0, 0.42, 0.74), 0.11, 0.04, rot=(math.radians(90), 0, 0), verts=14, kind="Metal")
    flat(P, RED, star_points(0.07, 0.03), 0.02, c=(0, 0.45, 0.74))
    # Tear-off calendar standing on the head between the ears: red binding with metal
    # rings, cream page with a grid of day squares (the last one gold) and a gold star.
    top = Vector((0, 0.08, 1.78))
    tilt = (math.radians(8), 0, 0)
    box(P, CREAM, top, (0.4, 0.06, 0.34), rot=tilt, bevel=0.02)
    box(P, RED, top + Vector((0, -0.01, 0.2)), (0.44, 0.09, 0.1), rot=tilt, bevel=0.02)
    for x in (-0.12, 0.0, 0.12):
        torus(P, "C8CCD6", top + Vector((x, 0.0, 0.26)), 0.035, 0.012, rot=(0, math.radians(90), 0), seg=10, mseg=4, kind="Metal")
    for row in range(2):
        for col in range(4):
            last = row == 1 and col == 3
            pos = top + Vector((-0.135 + col * 0.09, 0.035, 0.07 - row * 0.09))
            box(P, GOLD if last else "D9C4A3", pos, (0.055, 0.02, 0.055), rot=tilt, kind="Metal" if last else None)
    flat(P, GOLD, star_points(0.07, 0.03), 0.03, c=top + Vector((0, 0.045, -0.11)), rot=tilt, kind="Neon")
    # Confetti stars floating around.
    for i, h in enumerate(["FFD24A", "FF7AA8", "5CD6FF"]):
        a = math.radians(40 + i * 120)
        c = Vector((math.cos(a) * 0.9, math.sin(a) * 0.55, 1.0 + (i % 2) * 0.35))
        flat(P, h, star_points(0.08, 0.035), 0.03, c=c, rot=(0, 0, a), kind="Neon")


CALENDAR = {"CalendarFox": calendar_fox}
bp.PETS.update(CALENDAR)


if __name__ == "__main__":
    for name in CALENDAR:
        bp.export_pet(name)
