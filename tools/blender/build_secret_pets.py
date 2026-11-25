"""Builds the 7 Secret pets of the old worlds (#81) and renders their preview images.

Run headless (bpy from pip, Python 3.13):
    python tools/blender/build_secret_pets.py [PetId ...]

Same building blocks and output as build_pets.py: assets/models/pets/<PetId>.fbx,
assets/previews/pets/<PetId>.png and one sheet assets/previews/pets/SecretPets.png with
all Secret pets side by side. Secret pets are showier than Mythic ones: a floating
Neon halo, glowing eyes or markings and a few orbiting sparkle stars, so they read as
"Secret" from far away even without the aura effect.
"""

import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import build_pets as bp  # noqa: E402
from build_pets import (  # noqa: E402
    BODY,
    BODY_R,
    WHITE,
    box,
    cheeks,
    cone,
    critter,
    cyl,
    eyes,
    flat,
    horns,
    ico,
    leaf,
    pointed_ears,
    round_ears,
    snout_long,
    sph,
    spikes,
    star_points,
    surface,
    tail_curve,
    torus,
    wings_bird,
    wings_dragon,
)
from mathutils import Vector  # noqa: E402

PREVIEW_DIR = bp.PREVIEW_DIR


def halo(P, h, head, R, lift=0.42, major=0.3):
    """Glowing ring floating above the head: the Secret mark of every Secret pet."""
    torus(P, h, head + Vector((0, -0.05, R + lift)), major, 0.045, rot=(math.radians(12), 0, 0), kind="Neon", seg=18)


def sparkles(P, h, center, radius=0.95, n=3, z=0.0, size=0.09):
    """Small Neon stars hovering around the pet."""
    for i in range(n):
        a = math.radians(35 + i * 360 / n)
        c = Vector(center) + Vector((math.cos(a) * radius, math.sin(a) * radius * 0.6, z + (i % 2) * 0.35))
        flat(P, h, star_points(size, size * 0.45), 0.04, c=c, rot=(0, 0, a), kind="Neon")


# ---------------------------------------------------------------- world 1: Mozzarella-Geist


def mozzarella_ghost(P):
    # Floating stretchy-cheese ghost: no feet, wavy cheese strands below.
    body = Vector((0, 0, 0.85))
    R = (0.55, 0.52, 0.62)
    sph(P, "FFF8E6", body, 1, scale=R, seg=16, rings=10)
    for i in range(5):
        a = math.radians(i * 72 + 18)
        cone(P, "FFF8E6", (math.cos(a) * 0.36, math.sin(a) * 0.34, 0.32), 0.17, 0.02, 0.42, rot=(math.pi, 0, 0), verts=8)
    eyes(P, body + Vector((0, 0, 0.12)), (0.55, 0.52, 0.5), spread=24, pitch=10, size=0.13, color="2E8BFF", kind="Neon")
    cheeks(P, body + Vector((0, 0, 0.12)), (0.55, 0.52, 0.5), spread=46, pitch=-10)
    sph(P, "3A2A2A", surface(body, R, 0, -12, 0.98), 0.08, scale=(1.4, 0.5, 0.7), seg=8, rings=6)
    # Basil leaf and tomato drop on top, a little pizza peel as "arm".
    leaf(P, "3FA34D", body + Vector((0.12, 0, R[2] - 0.02)), length=0.36, width=0.13, rot=(math.radians(-20), math.radians(30), 0))
    sph(P, "E8453C", body + Vector((-0.12, 0.02, R[2] + 0.02)), 0.11)
    cyl(P, "C89A5A", (0.62, 0.18, 0.8), 0.035, 0.55, rot=(0, math.radians(35), 0), verts=6)
    cyl(P, "D9B07A", (0.82, 0.18, 1.08), 0.2, 0.04, rot=(0, math.radians(35), 0), verts=12)
    halo(P, "7FE8FF", body, R[2], lift=0.3)
    sparkles(P, "BFF4FF", (0, 0, 0.7))


# ---------------------------------------------------------------- world 2: Vogelscheuchen-Rabe


def scarecrow_raven(P):
    body = Vector((0, 0, 0.66))
    R = (0.5, 0.52, 0.6)
    sph(P, "2A2440", body, 1, scale=R)
    face = Vector((0, 0.1, 0.92))
    sph(P, "2A2440", face, 0.44)
    eyes(P, face, 0.44, spread=28, pitch=8, size=0.12, color="FFB020", kind="Neon")
    cone(P, "F2A23A", surface(face, 0.44, 0, -6, 0.9) + Vector((0, 0.12, 0)), 0.1, 0.0, 0.28, rot=(math.radians(-90), 0, 0), verts=6)
    wings_bird(P, "3A3258", spread=0.52, z=0.62, size=0.42)
    # Patched straw hat and a scarf.
    cyl(P, "D9B44A", face + Vector((0, -0.03, 0.36)), 0.5, 0.05, verts=16)
    cone(P, "E8C65A", face + Vector((0, -0.03, 0.55)), 0.28, 0.12, 0.36, verts=12)
    box(P, "B8322A", face + Vector((0.12, 0.05, 0.47)), (0.12, 0.03, 0.1), rot=(0, 0, 0.3))
    torus(P, "B8322A", (0, 0.02, 0.98), 0.3, 0.07, rot=(math.radians(8), 0, 0))
    for side in (-1, 1):
        cone(P, "E8C65A", (side * 0.55, 0.0, 0.42), 0.06, 0.0, 0.3, rot=(0, side * math.radians(150), 0), verts=5)
    bp.feet(P, "F2A23A", [(-0.18, 0.18), (0.18, 0.18)], r=0.11)
    halo(P, "FFD24A", face, 0.44, lift=0.55)
    sparkles(P, "FFE89A", (0, 0, 0.6))


# ---------------------------------------------------------------- world 3: Schatz-Oktopus


def treasure_octopus(P):
    head = Vector((0, 0, 0.95))
    R = (0.55, 0.52, 0.6)
    sph(P, "8E4DE0", head, 1, scale=R, seg=16, rings=10)
    for yaw, pitch, s in [(60, 35, 0.08), (-50, 50, 0.07), (150, 20, 0.1), (-140, 10, 0.08)]:
        sph(P, "C79BFF", surface(head, R, yaw, pitch, 0.97), s, scale=(1, 1, 0.5), seg=8, rings=6)
    eyes(P, head, R, spread=26, pitch=0, size=0.14, sclera=WHITE)
    cheeks(P, head, R, spread=46, pitch=-20)
    for i in range(8):
        a = math.radians(i * 45 + 22.5)
        base = Vector((math.cos(a) * 0.3, math.sin(a) * 0.3, 0.45))
        for k in range(4):
            t = k / 3
            p = base + Vector((math.cos(a) * t * 0.35, math.sin(a) * t * 0.35, -t * 0.3 + math.sin(t * 3) * 0.06))
            sph(P, "7A3CCC", p, 0.11 * (1 - t * 0.45), seg=8, rings=6)
    # Pirate crown with jewels and a gold coin.
    top = head + Vector((0, -0.02, R[2] - 0.05))
    cyl(P, "FFC83A", top + Vector((0, 0, 0.06)), 0.26, 0.12, verts=10, kind="Metal")
    for i in range(5):
        a = math.radians(i * 72)
        cone(P, "FFC83A", top + Vector((math.cos(a) * 0.22, math.sin(a) * 0.22, 0.2)), 0.07, 0.0, 0.16, verts=4, kind="Metal")
    sph(P, "FF3A6A", top + Vector((0, 0.25, 0.08)), 0.05, kind="Neon")
    cyl(P, "FFC83A", (0.6, 0.35, 0.3), 0.15, 0.04, rot=(math.radians(70), 0, 0.4), verts=14, kind="Metal")
    halo(P, "5CF0FF", head, R[2], lift=0.42)
    sparkles(P, "FFF3A0", (0, 0, 0.8))


# ---------------------------------------------------------------- world 4: Polarlicht-Wolf


def aurora_wolf(P):
    head, R = critter(P, "DCEBFF", belly="FFFFFF", feet_color="C3D8F5", nose="2A3A5A", muzzle="FFFFFF", blush=False)
    pointed_ears(P, "DCEBFF", head, R, inner="8FF5D2", height=0.42)
    snout_long(P, "FFFFFF", head, R, length=0.22, r=0.18, pitch=-18, nose="2A3A5A")
    # Aurora mane: glowing bands in green, teal and violet over head and back.
    for i, h in enumerate(["5CFFB0", "4ADFFF", "B07CFF"]):
        torus(P, h, (0, -0.1 - i * 0.2, 0.92 - i * 0.1), 0.34 - i * 0.04, 0.05, rot=(math.radians(25 + i * 15), 0, 0), kind="Neon")
    tail_curve(P, "DCEBFF", r=0.1, up=0.7, length=0.8, tip="8FF5D2")
    for yaw, pitch in [(140, 30), (-150, 35), (180, 5)]:
        flat(P, "BFF8FF", star_points(0.07, 0.03), 0.03, c=surface(BODY, BODY_R, yaw, pitch, 1.0), kind="Neon")
    halo(P, "8FF5D2", head, R)
    sparkles(P, "C9FFF0", (0, 0, 0.7))


# ---------------------------------------------------------------- world 5: Obsidian-Drache


def obsidian_dragon(P):
    head, R = critter(P, "2A2230", belly="4A3A50", feet_color="1C1620", nose="FF5A1A", muzzle="3A2E42", blush=False)
    eyes(P, head, R, spread=27, pitch=6, size=0.16, color="FF6A1A", kind="Neon", shine=False)
    horns(P, "FF8A2A", head, R, length=0.4, kind="Neon")
    wings_dragon(P, "3A2E42", span=0.9)
    spikes(P, "FF6A1A", n=5, y0=0.05, y1=-0.55, z=0.98, curve=0.4, kind="Neon")
    tail_curve(P, "2A2230", r=0.1, up=0.3, length=0.9, tip="FF6A1A")
    # Glowing lava cracks on the body.
    for yaw, pitch in [(70, 10), (-70, 15), (120, -10), (-120, -5), (0, -30)]:
        box(P, "FF7A1A", surface(BODY, BODY_R, yaw, pitch, 0.99), (0.16, 0.03, 0.03), rot=(0, 0, math.radians(yaw)), kind="Neon")
    for yaw in (-40, 40):
        ico(P, "4A3A50", surface(head, R, yaw, 40, 0.95), 0.1, subdiv=1, jit=0.02, seed=yaw)
    halo(P, "FF9A3A", head, R, lift=0.5)
    sparkles(P, "FFC07A", (0, 0, 0.7))


# ---------------------------------------------------------------- world 6: Lebkuchen-Golem


def gingerbread_golem(P):
    body = Vector((0, 0, 0.62))
    R = (0.55, 0.42, 0.55)
    sph(P, "B8733A", body, 1, scale=R)
    head = Vector((0, 0.05, 1.28))
    HR = 0.46
    sph(P, "B8733A", head, HR)
    eyes(P, head, HR, spread=26, pitch=8, size=0.12)
    cheeks(P, head, HR, color="FF7AA8")
    # Icing smile, icing zigzag on arms and legs, gumdrop buttons.
    for yaw, pitch in [(-14, -18), (-7, -23), (0, -25), (7, -23), (14, -18)]:
        sph(P, WHITE, surface(head, HR, yaw, pitch, 1.0), 0.03, seg=6, rings=4)
    for side in (-1, 1):
        sph(P, "B8733A", (side * 0.62, 0.02, 0.78), 1, scale=(0.26, 0.18, 0.16))
        torus(P, WHITE, (side * 0.78, 0.02, 0.78), 0.1, 0.02, rot=(0, math.radians(90), 0), seg=10, mseg=4)
        sph(P, "B8733A", (side * 0.24, 0.02, 0.16), 1, scale=(0.18, 0.18, 0.2))
    for i, h in enumerate(["FF3A6A", "3AD06A", "3A9AFF"]):
        sph(P, h, (0, R[1] * 0.92, 0.85 - i * 0.2), 0.075, kind="Glass")
    # Candy-cane crown.
    for i in range(5):
        a = math.radians(i * 72)
        cyl(P, "FF3A4A" if i % 2 == 0 else WHITE, head + Vector((math.cos(a) * 0.2, math.sin(a) * 0.2, HR * 0.95)), 0.04, 0.24, verts=6)
    torus(P, "FFC83A", head + Vector((0, 0, HR * 0.86)), 0.22, 0.04, kind="Metal")
    halo(P, "FF7AE0", head, HR, lift=0.45)
    sparkles(P, "FFC0F0", (0, 0, 0.7))


# ---------------------------------------------------------------- world 7: Schwarzloch-Katze


def black_hole_cat(P):
    head, R = critter(P, "141428", belly="24244A", feet_color="0C0C1C", nose="FF7AE0", blush=False)
    eyes(P, head, R, spread=27, pitch=6, size=0.16, color="B07CFF", kind="Neon", shine=False)
    pointed_ears(P, "141428", head, R, inner="6A4AE0")
    tail_curve(P, "141428", r=0.07, up=0.8, length=0.9, tip="B07CFF")
    # Accretion disk around the body and stars on the fur.
    torus(P, "FF9A3A", (0, -0.05, 0.55), 0.68, 0.035, rot=(math.radians(18), math.radians(8), 0), kind="Neon", seg=24)
    torus(P, "B07CFF", (0, -0.05, 0.55), 0.82, 0.025, rot=(math.radians(18), math.radians(8), 0), kind="Neon", seg=24)
    for yaw, pitch in [(60, 30), (-70, 20), (150, 40), (-140, 10), (180, 50)]:
        flat(P, WHITE, star_points(0.06, 0.025), 0.03, c=surface(BODY, BODY_R, yaw, pitch, 1.0), kind="Neon")
    for yaw, pitch in [(-60, 45), (70, 50)]:
        sph(P, WHITE, surface(head, R, yaw, pitch, 1.0), 0.03, kind="Neon", seg=6, rings=4)
    halo(P, "D0B0FF", head, R)
    sparkles(P, "E8DAFF", (0, 0, 0.8), radius=1.05)


SECRET = {
    "MozzarellaGhost": mozzarella_ghost,
    "ScarecrowRaven": scarecrow_raven,
    "TreasureOctopus": treasure_octopus,
    "AuroraWolf": aurora_wolf,
    "ObsidianDragon": obsidian_dragon,
    "GingerbreadGolem": gingerbread_golem,
    "BlackHoleCat": black_hole_cat,
}
bp.PETS.update(SECRET)


def secret_sheet():
    bp.reset_scene()
    objs = []
    names = list(SECRET)
    for i, name in enumerate(names):
        objs += bp.build(name, offset=(((len(names) - 1) / 2 - i) * 1.9, 0, 0))
    bp.render(objs, os.path.join(PREVIEW_DIR, "SecretPets.png"), (200 * len(names), 400), "1C1830", ground="2E2848", distance=2.95, yaw=0, lift=0.14, samples=48)
    print("sheet SecretPets")


if __name__ == "__main__":
    args = [a for a in sys.argv[1:] if a in SECRET] or list(SECRET)
    for name in args:
        bp.export_pet(name)
    secret_sheet()
