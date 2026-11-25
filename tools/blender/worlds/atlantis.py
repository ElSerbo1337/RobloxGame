"""World 8 – Atlantis (#82): 3 toppings, 6 pets of the Atlantis egg and the Secret pet.

Read by tools/blender/build_world.py (python tools/blender/build_world.py Atlantis).
The egg comes from its `look` in GameConfig (build_eggs.py), so it is not defined here.
Every topping is built from at least two colours (two parts), so Studio keeps it a Model.
"""

import math

import build_pets as bp
import build_secret_pets as bs
import build_toppings as bt
from build_pets import (
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
    leaf,
    round_ears,
    sph,
    surface,
    torus,
)
from mathutils import Vector

# Picture colours (sky, ground) of the world preview: sea-floor sand under blue water.
SKY = "2E7FB8"
GROUND = "DED4B0"

# ---------------------------------------------------------------- toppings


def seaweed():
    # Two wavy ribbons of dark kelp with a lighter middle vein and little air bladders.
    for k, (y0, rot) in enumerate(((-0.25, 0.0), (0.3, 0.5))):
        path = [(x, y0 + 0.22 * math.sin(x * 2.6 + k)) for x in [i / 7 * 1.9 - 0.95 for i in range(8)]]
        path = [(x * math.cos(rot) - y * math.sin(rot), x * math.sin(rot) + y * math.cos(rot)) for x, y in path]
        bt.part(bt.strip(path, 0.34, 0.02 * k, 0.07), "2F7A3A")
        bt.part(bt.strip(path, 0.08, 0.02 * k + 0.05, 0.03), "6CC46A")
        for i in (1, 4, 6):
            x, y = path[i]
            bt.part(bt.sphere(0.07, (x, y, 0.1 + 0.02 * k), (1, 1, 0.7), 8, 5), "8FD86A")


def pearl_capers():
    # Five round green capers, three of them with a tiny shining pearl on top.
    spots = [(-0.5, 0.3, 0.3), (0.35, 0.45, 0.28), (0.55, -0.25, 0.3), (-0.2, -0.45, 0.27), (0.0, 0.0, 0.32)]
    for i, (x, y, r) in enumerate(spots):
        caper = bt.ico(r, (x, y, r * 0.8), (1, 1, 0.82), subdiv=2)
        bt.part(bt.jitter(caper, 0.015, i), "6E9A3A")
        bt.part(bt.sphere(r * 0.35, (x - r * 0.3, y + r * 0.25, r * 1.45), (1, 1, 0.5), 8, 5), "9CC45A")
        if i % 2 == 0:
            bt.part(bt.sphere(r * 0.42, (x + r * 0.25, y - r * 0.2, r * 1.55), (1, 1, 1), 10, 7), "F4F0FF", "Glass")


def squid_rings():
    # Three golden fried squid rings, the pale squid inside showing at the cut.
    for i, (c, r) in enumerate((((-0.42, 0.3), 0.5), ((0.45, 0.28), 0.46), ((0.0, -0.42), 0.48))):
        z0 = 0.03 * i
        outer = bt.outline(r, 20, 0.05, i, center=c)
        inner = bt.outline(r * 0.55, 20, 0.05, i, center=c)
        bt.part(bt.band(outer, inner, z0, 0.16), "E8A23C")
        mid_out = bt.outline(r * 0.8, 20, 0.05, i, center=c)
        mid_in = bt.outline(r * 0.66, 20, 0.05, i, center=c)
        bt.part(bt.band(mid_out, mid_in, z0 + 0.12, 0.05), "FFF1DA")
        for k in range(4):
            a = k * 1.7 + i
            bt.part(bt.sphere(0.05, (c[0] + math.cos(a) * r * 0.9, c[1] + math.sin(a) * r * 0.9, z0 + 0.16), (1, 1, 0.6), 6, 4), "C47A22")


TOPPINGS = {"Seaweed": seaweed, "PearlCapers": pearl_capers, "SquidRings": squid_rings}

# ---------------------------------------------------------------- pets (front = +Y)


def kelp_snail(P):
    sph(P, "B8E0A0", (0, 0.1, 0.2), 1, scale=(0.36, 0.78, 0.2))
    head = Vector((0, 0.55, 0.52))
    HR = 0.3
    sph(P, "B8E0A0", head, HR)
    eyes(P, head, HR, spread=30, pitch=6, size=0.1)
    cheeks(P, head, HR, spread=50, pitch=-14, size=0.06)
    for side in (-1, 1):
        cyl(P, "B8E0A0", head + Vector((side * 0.12, 0, 0.34)), 0.035, 0.26, rot=(0, side * 0.3, 0), verts=6)
        sph(P, "8FC47A", head + Vector((side * 0.17, 0, 0.48)), 0.06)
    shell = Vector((0, -0.2, 0.66))
    sph(P, "2E9C8A", shell, 1, scale=(0.3, 0.46, 0.46))
    for k, r in enumerate((0.42, 0.3, 0.18)):
        torus(P, "7FD8C4", shell + Vector((0.27 - k * 0.02, 0.04 * k, 0.04 * k)), r, 0.035, rot=(0, math.radians(90), 0), seg=16, mseg=4)
    leaf(P, "3FA34D", shell + Vector((0, -0.05, 0.4)), length=0.4, width=0.1, rot=(math.radians(-15), 0, 0))
    leaf(P, "3FA34D", shell + Vector((0.05, -0.15, 0.38)), length=0.3, width=0.08, rot=(math.radians(-35), math.radians(30), 0))


def bubble_pufferfish(P):
    body = Vector((0, 0, 0.68))
    R = 0.56
    sph(P, "FFC857", body, R, seg=16, rings=10)
    sph(P, "FFF2C8", surface(body, R, 0, -35, 0.6), 1, scale=(0.36, 0.3, 0.3))
    eyes(P, body + Vector((0, 0, 0.1)), R, spread=30, pitch=12, size=0.14)
    cheeks(P, body + Vector((0, 0, 0.05)), R, spread=52, pitch=-10)
    sph(P, "E8604A", surface(body, R, 0, -12, 0.98), 0.07, scale=(1.2, 0.6, 0.8), seg=8, rings=5)
    for yaw in range(0, 360, 45):
        for pitch in (-25, 20, 55):
            if abs(yaw) < 40 and pitch < 50:
                continue
            p = surface(body, R, yaw, pitch, 0.98)
            d = (p - body).normalized()
            cone(P, "E8A83A", p + d * 0.05, 0.05, 0.0, 0.14, rot=d.to_track_quat("Z", "Y").to_euler(), verts=4)
    for side in (-1, 1):
        sph(P, "FFB040", (side * 0.55, 0.05, 0.62), 1, scale=(0.05, 0.16, 0.12), rot=(0, 0, side * 0.4))
    flat(P, "FFB040", [(0, 0), (0.25, 0.22), (0.25, -0.22)], 0.05, c=(0, -0.58, 0.68), rot=(0, 0, math.radians(90)))
    for k, (x, z, r) in enumerate(((0.35, 1.35, 0.1), (0.5, 1.6, 0.07), (0.2, 1.75, 0.05))):
        sph(P, "BFEFFF", (x, 0.2, z), r, kind="Glass")


def caper_clownfish(P):
    body = Vector((0, 0, 0.6))
    R = (0.38, 0.7, 0.42)
    sph(P, "FF7A2A", body, 1, scale=R, seg=16, rings=10)
    for y in (0.32, -0.12):
        sph(P, WHITE, body + Vector((0, y, 0)), 1, scale=(R[0] * 1.03, 0.07, R[2] * 1.03), seg=14, rings=8)
    head = body + Vector((0, 0.3, 0.08))
    eyes(P, head, (0.36, 0.4, 0.36), spread=50, pitch=10, size=0.11)
    cheeks(P, head, (0.36, 0.4, 0.36), spread=64, pitch=-15)
    for side in (-1, 1):
        sph(P, "FF7A2A", (side * 0.38, 0.15, 0.42), 1, scale=(0.16, 0.12, 0.05), rot=(0, side * 0.5, side * 0.5))
    flat(P, "2A2A2A", [(0.0, 0.0), (0.32, 0.3), (0.32, -0.3)], 0.06, c=(0, -0.68, 0.6), rot=(0, 0, math.radians(90)))
    flat(P, "FF7A2A", [(-0.2, 0), (0.2, 0), (0.05, 0.22)], 0.05, c=(0, -0.05, 0.98), rot=(0, 0, math.radians(90)))
    # A big caper on the head with a pearl.
    bp.ico(P, "6E9A3A", (0, 0.1, 1.1), 0.14, scale=(1, 1, 0.85), subdiv=2)
    sph(P, "F4F0FF", (0.06, 0.12, 1.24), 0.06, kind="Glass")


def lantern_anglerfish(P):
    body = Vector((0, 0, 0.62))
    R = (0.5, 0.56, 0.5)
    sph(P, "2A3A6A", body, 1, scale=R, seg=16, rings=10)
    sph(P, "4A5A8A", surface(body, R, 0, -40, 0.6), 1, scale=(0.36, 0.3, 0.22))
    eyes(P, body + Vector((0, 0, 0.12)), R, spread=32, pitch=16, size=0.14, color="FFE06A", kind="Neon")
    # Wide grin with little teeth.
    mouth = surface(body, R, 0, -12, 0.98)
    sph(P, "1A1A2E", mouth, 1, scale=(0.3, 0.06, 0.08))
    for x in (-0.2, -0.1, 0.0, 0.1, 0.2):
        cone(P, WHITE, mouth + Vector((x, 0.03, 0.06)), 0.035, 0.0, 0.08, rot=(math.pi, 0, 0), verts=4)
    # The lure: a curved stalk with a glowing lantern.
    for k in range(5):
        t = k / 4
        sph(P, "4A5A8A", (0, 0.1 + t * 0.35, 1.08 + math.sin(t * math.pi) * 0.25), 0.04, seg=6, rings=4)
    sph(P, "7FE8FF", (0, 0.5, 1.02), 0.11, kind="Neon")
    for side in (-1, 1):
        sph(P, "3A4A7A", (side * 0.5, 0.0, 0.5), 1, scale=(0.06, 0.18, 0.14), rot=(0, 0, side * 0.5))
    flat(P, "3A4A7A", [(0, 0), (0.28, 0.25), (0.28, -0.25)], 0.05, c=(0, -0.55, 0.62), rot=(0, 0, math.radians(90)))


def pearl_manta_ray(P):
    body = Vector((0, 0, 0.55))
    wing = [(0.0, 0.42), (0.95, -0.05), (0.75, -0.2), (0.0, -0.4), (-0.75, -0.2), (-0.95, -0.05)]
    # Wings as a flat diamond lying in the XY plane (flat() builds in XZ, turned up).
    flat(P, "3E56B8", wing, 0.12, c=body, rot=(math.radians(-90), 0, 0))
    flat(P, "E6ECFF", [(x * 0.8, z * 0.8) for x, z in wing], 0.1, c=body + Vector((0, 0, -0.03)), rot=(math.radians(-90), 0, 0))
    sph(P, "3E56B8", body + Vector((0, 0.05, 0.06)), 1, scale=(0.34, 0.42, 0.18))
    head = body + Vector((0, 0.38, 0.1))
    eyes(P, head, (0.26, 0.2, 0.16), spread=48, pitch=25, size=0.08)
    cheeks(P, head, (0.26, 0.2, 0.16), spread=62, pitch=-5, size=0.05)
    for side in (-1, 1):
        cone(P, "2E46A0", head + Vector((side * 0.17, 0.1, 0.02)), 0.05, 0.0, 0.18, rot=(math.radians(-80), 0, 0), verts=5)
    for k in range(6):
        sph(P, "2E46A0", (0, -0.42 - k * 0.12, 0.55 + k * 0.02), 0.035 - k * 0.003, seg=6, rings=4)
    # Pearl spots along the back and a big pearl on top.
    for x, y in ((-0.45, -0.05), (0.45, -0.05), (-0.25, -0.18), (0.25, -0.18)):
        sph(P, "F4F0FF", body + Vector((x, y, 0.08)), 0.05, kind="Glass")
    sph(P, "FFF6E6", body + Vector((0, -0.05, 0.28)), 0.13, kind="Metal")


def poseidon_sea_dragon(P):
    teal, light, gold = "1FA2A6", "8FE6D8", "FFC83A"
    # Serpent body: a wave of balls behind the head.
    for k in range(9):
        t = k / 8
        r = 0.3 - t * 0.17
        y = -0.1 - t * 1.0
        z = 0.32 + math.sin(t * math.pi * 1.6) * 0.22
        sph(P, teal, (0, y, z), r, seg=12, rings=8)
        if k % 2 == 0:
            cone(P, light, (0, y, z + r * 0.9), r * 0.4, 0.0, r * 0.7, rot=(math.radians(-20), 0, 0), verts=4)
    head = Vector((0, 0.32, 0.9))
    HR = 0.42
    sph(P, teal, head, HR)
    sph(P, light, surface(head, HR, 0, -25, 0.7), 1, scale=(0.26, 0.3, 0.16))
    eyes(P, head, HR, spread=30, pitch=10, size=0.13)
    cheeks(P, head, HR, spread=52, pitch=-16)
    for side in (-1, 1):
        cone(P, gold, surface(head, HR, side * 32, 55, 0.9) + Vector((side * 0.05, -0.05, 0.12)), 0.06, 0.0, 0.36, rot=(math.radians(-30), side * math.radians(30), 0), verts=6, kind="Metal")
        flat(P, light, [(0, 0), (0.35, 0.2), (0.3, -0.12)], 0.04, c=surface(head, HR, side * 80, 0, 0.9), rot=(0, 0, side * math.radians(-90) if side > 0 else math.radians(90)))
    # Golden crown and a small trident beside it.
    torus(P, gold, head + Vector((0, -0.02, HR * 0.86)), 0.2, 0.04, kind="Metal")
    for k in range(5):
        a = math.radians(k * 72)
        cone(P, gold, head + Vector((math.cos(a) * 0.2, math.sin(a) * 0.2 - 0.02, HR * 0.86 + 0.1)), 0.04, 0.0, 0.16, verts=4, kind="Metal")
    cyl(P, gold, (0.5, 0.2, 0.75), 0.03, 1.1, rot=(0, math.radians(8), 0), verts=6, kind="Metal")
    for dx in (-0.1, 0.0, 0.1):
        cone(P, gold, (0.58 + dx, 0.2, 1.38), 0.035, 0.0, 0.2, verts=4, kind="Metal")
    box(P, gold, (0.58, 0.2, 1.28), (0.24, 0.05, 0.04), kind="Metal")
    sph(P, "7FE8FF", (0.58, 0.2, 1.52), 0.06, kind="Neon")


def pearl_king_otter(P):
    fur, cream = "8A5A3A", "F0DCC0"
    head, R = critter(P, fur, belly=cream, muzzle=cream, feet_color="6A4228", sclera=None)
    round_ears(P, fur, head, R, size=0.12, spread=58, pitch=40, inner="6A4228")
    for side in (-1, 1):
        for k in range(3):
            sph(P, "3A2A2A", surface(head, R, side * (18 + k * 6), -18 - k * 3, 1.02), 0.012, seg=6, rings=4)
    # Flat otter tail.
    sph(P, "6A4228", (0, BODY[1] - BODY_R[1] * 1.1, 0.2), 1, scale=(0.18, 0.4, 0.07))
    # Holding a giant glowing pearl in both paws.
    pearl = Vector((0, 0.55, 0.55))
    sph(P, "DFF6FF", pearl, 0.22, kind="Neon")
    for side in (-1, 1):
        sph(P, fur, pearl + Vector((side * 0.22, -0.02, -0.02)), 0.1)
    # Crown of gold with pearls.
    crown = head + Vector((0, -0.04, R * 0.88))
    cyl(P, "FFC83A", crown, 0.24, 0.12, verts=12, kind="Metal")
    for k in range(5):
        a = math.radians(k * 72 + 90)
        cone(P, "FFC83A", crown + Vector((math.cos(a) * 0.22, math.sin(a) * 0.22, 0.12)), 0.06, 0.0, 0.16, verts=4, kind="Metal")
        sph(P, "F4F0FF", crown + Vector((math.cos(a) * 0.22, math.sin(a) * 0.22, 0.22)), 0.035, kind="Glass")
    bs.halo(P, "7FE8FF", head, R, lift=0.5)
    bs.sparkles(P, "C8F6FF", (0, 0, 0.8), radius=1.0)


PETS = {
    "KelpSnail": kelp_snail,
    "BubblePufferfish": bubble_pufferfish,
    "CaperClownfish": caper_clownfish,
    "LanternAnglerfish": lantern_anglerfish,
    "PearlMantaRay": pearl_manta_ray,
    "PoseidonSeaDragon": poseidon_sea_dragon,
    "PearlKingOtter": pearl_king_otter,
}
