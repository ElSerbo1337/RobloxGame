"""World 9 – Jungle Temple (#83): 3 toppings, 6 pets of the jungle egg and the Secret pet.

Read by tools/blender/build_world.py (python tools/blender/build_world.py JungleTemple).
The egg comes from its `look` in GameConfig (build_eggs.py, pattern "Vines").
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
    beak,
    cheeks,
    cone,
    critter,
    cyl,
    eyes,
    feet,
    flat,
    leaf,
    pointed_ears,
    round_ears,
    sph,
    stick,
    surface,
    tail_curve,
    torus,
    wings_bird,
)
from mathutils import Vector

# Picture colours (sky, ground) of the world preview: misty rainforest green.
SKY = "7FB89A"
GROUND = "4E8C3A"

# ---------------------------------------------------------------- toppings


def mango():
    # Three juicy mango slices: golden flesh with a thin green-red skin along the round side.
    for i, (cx, cy, rot) in enumerate(((-0.45, 0.25, 0.3), (0.42, 0.3, -0.4), (0.0, -0.4, 1.4))):
        flesh = bt.outline(0.5, 20, 0.03, i, center=(cx, cy), stretch=(1, 0.5), rot=rot)
        bt.part(bt.slab(flesh, 0.02 * i, 0.16), "FFB52E")
        bt.part(bt.slab(bt.outline(0.34, 20, 0.03, i, center=(cx, cy), stretch=(1, 0.32), rot=rot), 0.02 * i + 0.16, 0.03), "FFD36A")
        skin_out = bt.outline(0.54, 20, 0.03, i, center=(cx, cy), stretch=(1, 0.56), rot=rot)
        bt.part(bt.band(skin_out, flesh, 0.02 * i, 0.12), "8DB33A" if i % 2 else "D9583A")


def cocoa_bean():
    # Five glossy cocoa beans, each with a darker groove along its length.
    spots = [(-0.5, 0.3, 0.4), (0.35, 0.45, -0.6), (0.55, -0.3, 1.1), (-0.25, -0.45, 0.2), (0.0, 0.05, 2.0)]
    for i, (x, y, rot) in enumerate(spots):
        c, s = math.cos(rot), math.sin(rot)
        bean = bt.sphere(0.3, (0, 0, 0.13), (1, 0.6, 0.42), 12, 8)
        bean = bt.deform(bean, lambda co, c=c, s=s, x=x, y=y: Vector((x + co.x * c - co.y * s, y + co.x * s + co.y * c, co.z)))
        bt.part(bt.jitter(bean, 0.01, i), "7A4424")
        groove = [(x - c * 0.24, y - s * 0.24), (x, y), (x + c * 0.24, y + s * 0.24)]
        bt.part(bt.strip(groove, 0.035, 0.235, 0.025), "3E200E")


def dragon_fruit():
    # Two round slices: white flesh full of black seeds inside a bright pink skin ring.
    for i, ((cx, cy), r) in enumerate((((-0.35, 0.15), 0.55), ((0.45, -0.25), 0.45))):
        z0 = 0.03 * i
        flesh = bt.outline(r * 0.86, 22, 0.03, i, center=(cx, cy))
        bt.part(bt.slab(flesh, z0, 0.14), "F6F0EC")
        bt.part(bt.band(bt.outline(r, 22, 0.03, i, center=(cx, cy)), flesh, z0, 0.15), "E8337E")
        for k in range(14):
            a = k * 2.399
            d = r * 0.7 * math.sqrt((k + 0.5) / 14)
            bt.part(bt.sphere(0.025, (cx + math.cos(a) * d, cy + math.sin(a) * d, z0 + 0.15), (1.4, 1, 0.5), 6, 4), "1A1A1A")
    # A little green scale leaf of the skin lies beside them.
    bt.part(bt.slab(bt.outline(0.16, 10, 0.0, 3, center=(0.55, 0.45), stretch=(1, 0.4), rot=0.7), 0.0, 0.05), "6CB33A")


TOPPINGS = {"Mango": mango, "CocoaBean": cocoa_bean, "DragonFruit": dragon_fruit}

# ---------------------------------------------------------------- pets (front = +Y)


def cocoa_frog(P):
    # Squat cocoa-brown frog with a cream belly, big eyes on top and a cocoa bean hat.
    body = Vector((0, 0, 0.42))
    sph(P, "8A5A34", body, 1, scale=(0.55, 0.5, 0.4))
    sph(P, "F0DCB8", body + Vector((0, 0.22, -0.05)), 1, scale=(0.38, 0.3, 0.28))
    head = Vector((0, 0.18, 0.78))
    R = (0.5, 0.4, 0.3)
    sph(P, "8A5A34", head, 1, scale=R)
    for side in (-1, 1):
        sph(P, "8A5A34", head + Vector((side * 0.24, 0.05, 0.24)), 0.17)
        sph(P, WHITE, head + Vector((side * 0.24, 0.14, 0.28)), 0.11)
        sph(P, "1E1E2A", head + Vector((side * 0.24, 0.22, 0.3)), 0.065)
        sph(P, "6A4228", (side * 0.38, 0.32, 0.08), 1, scale=(0.16, 0.2, 0.07))
        sph(P, "6A4228", (side * 0.42, -0.3, 0.1), 1, scale=(0.2, 0.26, 0.09))
    sph(P, "4A2A16", surface(head, R, 0, -15, 0.98), 1, scale=(0.24, 0.03, 0.03))
    cheeks(P, head, R, spread=55, pitch=-12, size=0.07)
    bean = head + Vector((0, -0.02, 0.4))
    sph(P, "7A4424", bean, 1, scale=(0.13, 0.2, 0.1), rot=(0, 0, 0.3))
    cyl(P, "3E200E", bean + Vector((0, 0, 0.09)), 0.015, 0.3, rot=(math.radians(90), 0, 0.3), verts=6)


def mango_toucan(P):
    # Black toucan with a white chest and a huge mango-coloured beak.
    sph(P, "22222A", BODY, 1, scale=(0.4, 0.44, 0.5))
    sph(P, WHITE, (0, 0.22, 0.62), 1, scale=(0.28, 0.2, 0.3))
    head = Vector((0, 0.12, 1.08))
    R = 0.36
    sph(P, "22222A", head, R)
    sph(P, WHITE, surface(head, R, 0, -20, 0.6), 1, scale=(0.24, 0.2, 0.2))
    eyes(P, head, R, spread=40, pitch=12, size=0.1)
    sph(P, "7FD8FF", surface(head, R, 40, 12, 0.92), 0.13, scale=(1, 0.4, 1))
    sph(P, "7FD8FF", surface(head, R, -40, 12, 0.92), 0.13, scale=(1, 0.4, 1))
    tip = surface(head, R, 0, -5, 0.9)
    sph(P, "FFB52E", tip + Vector((0, 0.32, 0.02)), 1, scale=(0.16, 0.38, 0.17))
    sph(P, "FF6A2A", tip + Vector((0, 0.62, -0.04)), 1, scale=(0.1, 0.14, 0.12))
    sph(P, "8DB33A", tip + Vector((0, 0.08, 0.08)), 1, scale=(0.15, 0.08, 0.1))
    wings_bird(P, "22222A", spread=0.38, z=0.58, size=0.32)
    flat(P, "22222A", [(-0.16, 0), (0.16, 0), (0.08, -0.45), (-0.08, -0.45)], 0.06, c=(0, -0.38, 0.32), rot=(math.radians(-30), 0, 0))
    feet(P, "4A8AD8", [(-0.16, 0.12), (0.16, 0.12)], r=0.1)


def vine_sloth(P):
    # Sleepy sloth with a dark eye mask, a liana wound round its belly and a leaf on its head.
    head, R = critter(P, "A8907A", belly="D8C8B0", muzzle="E8DCC8", feet_color="6A5440", eye_size=0.1, eye_spread=30)
    for side in (-1, 1):
        sph(P, "5A4632", surface(head, R, side * 27, 6, 0.93), 0.14, scale=(1.3, 0.45, 0.8), rot=(0, 0, side * 0.5))
        sph(P, "1E1E2A", surface(head, R, side * 27, 4, 1.02), 0.06)
        # Long claws reaching forward.
        for k in (-1, 0, 1):
            cone(P, "F0E6D0", (side * 0.36 + k * 0.05, 0.42, 0.42), 0.025, 0.0, 0.14, rot=(math.radians(-80), 0, 0), verts=4)
    torus(P, "4E8C3A", (0, -0.05, 0.52), 0.48, 0.04, rot=(math.radians(8), 0, 0), seg=18, mseg=4)
    for a in (40, 160, 280):
        r = math.radians(a)
        leaf(P, "6CB33A", (math.cos(r) * 0.48, -0.05 + math.sin(r) * 0.48, 0.55), length=0.2, width=0.08, rot=(0, math.radians(70), r))
    leaf(P, "6CB33A", head + Vector((0, -0.05, R * 0.95)), length=0.36, width=0.14, rot=(math.radians(-20), 0, 0))


def firefly_chameleon(P):
    # Green chameleon with a curled tail, turret eyes and glowing firefly spots on its back.
    green, light = "3FB04A", "A8E06A"
    sph(P, green, BODY, 1, scale=(0.34, 0.5, 0.4))
    sph(P, light, (0, 0.1, 0.38), 1, scale=(0.24, 0.36, 0.2))
    head = Vector((0, 0.42, 0.78))
    R = (0.3, 0.34, 0.3)
    sph(P, green, head, 1, scale=R)
    cone(P, green, head + Vector((0, -0.12, 0.3)), 0.18, 0.0, 0.3, rot=(math.radians(-30), 0, 0), verts=6)
    for side in (-1, 1):
        sph(P, light, head + Vector((side * 0.26, 0.04, 0.06)), 0.14)
        sph(P, "1E1E2A", head + Vector((side * 0.36, 0.08, 0.07)), 0.06)
    cheeks(P, head, R, spread=60, pitch=-20, size=0.06)
    sph(P, "2A7A34", surface(head, R, 0, -20, 0.98), 1, scale=(0.18, 0.03, 0.03))
    feet(P, green, [(-0.24, 0.22), (0.24, 0.22), (-0.24, -0.26), (0.24, -0.26)], r=0.11)
    # Curled tail: from the back of the body up and over into a spiral.
    for k in range(12):
        t = k / 11
        a = t * math.pi * 1.8
        r = 0.34 * (1 - t * 0.55)
        y = -0.62 - math.sin(a) * r
        z = 0.72 - math.cos(a) * r
        sph(P, green, (0, y, z), 0.12 * (1 - t * 0.5), seg=8, rings=6)
    for x, y, z in ((-0.18, -0.1, 0.86), (0.2, 0.05, 0.86), (0.0, -0.3, 0.8), (-0.12, 0.2, 0.86)):
        sph(P, "E8FF7A", (x, y, z), 0.05, kind="Neon")
    # A firefly sitting on the tail.
    sph(P, "3A3A2A", (0.08, -0.62, 1.12), 0.05)
    sph(P, "E8FF7A", (0.08, -0.68, 1.1), 0.05, kind="Neon")


def dragon_fruit_jaguar(P):
    # Pink jaguar with green dragon-fruit scales as ears and tail tip, and dark rosettes.
    pink, cream = "E8337E", "FFE0EC"
    head, R = critter(P, pink, belly=cream, muzzle=cream, feet_color="C42068")
    pointed_ears(P, "6CB33A", head, R, size=0.16, height=0.34, spread=36, pitch=52)
    for yaw, pitch in ((60, 20), (-60, 20), (120, 10), (-120, 10), (180, 30), (90, -10), (-90, -10)):
        torus(P, "5A1438", surface(BODY, BODY_R, yaw, pitch, 1.0), 0.07, 0.022, rot=bp.facing(yaw, pitch - 90), seg=10, mseg=3)
    for side in (-1, 1):
        sph(P, "5A1438", surface(head, R, side * 50, 30, 1.0), 0.05)
    tail_curve(P, pink, r=0.07, length=0.8, up=0.55, tip="6CB33A")
    for k in range(3):
        a = math.radians(k * 120)
        cone(P, "6CB33A", (math.cos(a) * 0.08, BODY[1] - 0.95 + math.sin(a) * 0.05, 0.98), 0.05, 0.0, 0.18, rot=(math.radians(-30), 0, a), verts=4)


def jade_temple_serpent(P):
    # Jade serpent coiled in three rings, its head raised with a golden temple headdress.
    jade, light, gold = "1FA06A", "8FE0B0", "FFC83A"
    for ring, (r, z) in enumerate(((0.5, 0.16), (0.38, 0.42), (0.26, 0.66))):
        n = 12 - ring * 2
        for k in range(n):
            a = k / n * math.pi * 2
            sph(P, jade if k % 3 else light, (math.cos(a) * r, math.sin(a) * r - 0.05, z), 0.17 - ring * 0.02, seg=10, rings=7)
    neck = [(0, 0.1, 0.85), (0, 0.18, 1.05), (0, 0.22, 1.25)]
    for p in neck:
        sph(P, jade, p, 0.15, seg=10, rings=7)
    head = Vector((0, 0.3, 1.45))
    HR = (0.3, 0.36, 0.24)
    sph(P, jade, head, 1, scale=HR)
    sph(P, light, surface(head, HR, 0, -30, 0.7), 1, scale=(0.2, 0.22, 0.1))
    eyes(P, head, HR, spread=38, pitch=18, size=0.09, color="7FFFC0", kind="Neon")
    cheeks(P, head, HR, spread=58, pitch=-12, size=0.05)
    cone(P, "E8337E", surface(head, HR, 0, -18, 1.0) + Vector((0, 0.08, 0)), 0.03, 0.0, 0.16, rot=(math.radians(-90), 0, 0), verts=4)
    # Headdress: a golden band with three tall plates and a jade stone.
    torus(P, gold, head + Vector((0, -0.02, 0.16)), 0.22, 0.035, kind="Metal")
    for k, dx in enumerate((-0.14, 0.0, 0.14)):
        flat(P, gold, [(-0.06, 0), (0.06, 0), (0.0, 0.26 if k == 1 else 0.18)], 0.04, c=head + Vector((dx, -0.05, 0.2)), kind="Metal")
    sph(P, "7FFFC0", head + Vector((0, 0.14, 0.22)), 0.05, kind="Neon")


def golden_monkey_king(P):
    # Golden monkey with a cream face, a temple crown, a staff and a halo (Secret pet).
    gold_fur, face = "E8B33A", "FFE8C0"
    head, R = critter(P, gold_fur, belly=face, muzzle=face, feet_color="B8862A", sclera=None)
    round_ears(P, gold_fur, head, R, size=0.16, spread=80, pitch=10, inner=face)
    sph(P, face, surface(head, R, 0, 8, 0.75), R * 0.6, scale=(1.1, 0.6, 0.9))
    eyes(P, head, R, spread=22, pitch=8, size=0.12)
    tail_curve(P, gold_fur, r=0.06, length=0.9, up=0.8)
    crown = head + Vector((0, -0.04, R * 0.86))
    cyl(P, "FFD84A", crown, 0.26, 0.12, verts=12, kind="Metal")
    for k in range(6):
        a = math.radians(k * 60 + 90)
        cone(P, "FFD84A", crown + Vector((math.cos(a) * 0.24, math.sin(a) * 0.24, 0.13)), 0.05, 0.0, 0.18, verts=4, kind="Metal")
    sph(P, "1FA06A", crown + Vector((0, 0.26, 0.04)), 0.06, kind="Neon")
    stick(P, "8A5A34", (0.5, 0.25, 0.05), (0.56, 0.3, 1.4), 0.035)
    sph(P, "7FFFC0", (0.56, 0.3, 1.48), 0.09, kind="Neon")
    for k in range(3):
        leaf(P, "6CB33A", (0.56, 0.3, 1.4), length=0.22, width=0.08, rot=(math.radians(50), 0, math.radians(k * 120)))
    bs.halo(P, "FFE89A", head, R, lift=0.55)
    bs.sparkles(P, "FFF2B0", (0, 0, 0.8), radius=1.0)


PETS = {
    "CocoaFrog": cocoa_frog,
    "MangoToucan": mango_toucan,
    "VineSloth": vine_sloth,
    "FireflyChameleon": firefly_chameleon,
    "DragonFruitJaguar": dragon_fruit_jaguar,
    "JadeTempleSerpent": jade_temple_serpent,
    "GoldenMonkeyKing": golden_monkey_king,
}

# Unused imports kept out of the linter's way (shared building blocks).
_ = (beak, cheeks)
