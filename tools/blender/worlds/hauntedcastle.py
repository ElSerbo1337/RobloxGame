"""World 11 – Haunted Castle (#85): 3 toppings, 6 pets of the spooky egg and the Secret pet.

Read by tools/blender/build_world.py (python tools/blender/build_world.py HauntedCastle).
The egg comes from its `look` in GameConfig (build_eggs.py, pattern "Bats").
Every topping is built from at least two colours (two parts), so Studio keeps it a Model.
Kid-friendly spooky: round, cute shapes, big eyes, no teeth beyond tiny fangs.
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
    sph,
    stick,
    surface,
    tail_curve,
    torus,
    wings_bird,
    wings_dragon,
)
from mathutils import Vector

# Picture colours (sky, ground) of the world preview: violet dusk over dusky grass.
SKY = "8A7AB8"
GROUND = "60765C"

# ---------------------------------------------------------------- toppings


def pumpkin():
    # Two little pumpkin wedges and a whole mini pumpkin: orange flesh, darker ribs, green stem.
    for i, (cx, cy, rot) in enumerate(((-0.45, 0.3, 0.4), (0.45, 0.32, -0.5))):
        flesh = bt.outline(0.42, 18, 0.03, i, center=(cx, cy), stretch=(1, 0.55), rot=rot)
        bt.part(bt.slab(flesh, 0.02 * i, 0.14), "FF9A2E")
        skin = bt.outline(0.46, 18, 0.03, i, center=(cx, cy), stretch=(1, 0.6), rot=rot)
        bt.part(bt.band(skin, flesh, 0.02 * i, 0.12), "E06A1A")
        bt.part(bt.slab(bt.outline(0.2, 12, 0.02, i, center=(cx, cy), stretch=(1, 0.35), rot=rot), 0.02 * i + 0.14, 0.02), "FFD27A")
    for k in range(5):
        a = k * math.pi * 2 / 5
        bt.part(bt.sphere(0.2, (0.05 + math.cos(a) * 0.12, -0.38 + math.sin(a) * 0.12, 0.22), (1, 1, 0.9), 10, 7), "F07A22")
    bt.part(bt.cylinder(0.045, 0.16, (0.05, -0.38, 0.46), 6), "5E7A2E")


def ghost_mushroom():
    # Three pale glowing ghost mushrooms: white-blue caps with a faint glow and cute dot eyes.
    for i, ((cx, cy), size) in enumerate((((-0.35, 0.15), 1.0), ((0.45, 0.3), 0.75), ((0.15, -0.45), 0.6))):
        cap = bt.sphere(0.42 * size, (cx, cy, 0.42 * size), (1, 1, 0.7), 14, 8)
        bt.part(bt.cut_below(cap, 0.42 * size), "DDE8FF")
        bt.part(bt.cylinder(0.16 * size, 0.46 * size, (cx, cy, 0.23 * size), 10), "F4F0FF")
        bt.part(bt.sphere(0.2 * size, (cx, cy, 0.62 * size), (1, 1, 0.4), 8, 5), "B8D8FF", "Neon")
        for side in (-1, 1):
            bt.part(bt.sphere(0.04 * size, (cx + side * 0.1 * size, cy + 0.36 * size, 0.6 * size), (1, 0.6, 1.3), 6, 4), "3A3050")


def gummy_bat_wings():
    # Four gummy bat wings: a pointed bat wing with three scallops along the bottom edge,
    # in purple and green gummy, each with a lighter inner shine.
    edge_top = [(0.0, 0.0), (0.18, 0.2), (0.42, 0.32), (0.66, 0.3), (0.82, 0.18)]
    edge_bottom = [(0.62, 0.02), (0.55, 0.1), (0.42, -0.06), (0.32, 0.02), (0.2, -0.14), (0.1, -0.08)]
    shape = edge_top + edge_bottom
    spots = [(-0.75, 0.15, 0.3, "8A3AD8"), (0.0, 0.42, -0.2, "5AD860"), (-0.4, -0.45, 0.1, "5AD860"), (0.25, -0.25, 0.5, "8A3AD8")]
    for i, (cx, cy, rot, color) in enumerate(spots):
        c, s = math.cos(rot), math.sin(rot)

        def place(pts, k=1.0, c=c, s=s, cx=cx, cy=cy):
            return [(cx + (x * k * c - y * k * s), cy + (x * k * s + y * k * c)) for x, y in pts]

        z0 = 0.02 * i
        bt.part(bt.slab(place(shape), z0, 0.12), color)
        shine = [(0.12, 0.06), (0.3, 0.18), (0.52, 0.22), (0.4, 0.1), (0.2, 0.04)]
        bt.part(bt.slab(place(shine), z0 + 0.1, 0.04), "C890FF" if color == "8A3AD8" else "A8F0A0")


TOPPINGS = {"Pumpkin": pumpkin, "GhostMushroom": ghost_mushroom, "GummyBatWings": gummy_bat_wings}

# ---------------------------------------------------------------- pets (front = +Y)


def pumpkin_kitten(P):
    # Orange kitten with a pumpkin-rib belly and a little pumpkin hat with a curly stem.
    head, R = critter(P, "FF9A3E", belly="FFE0B0", muzzle="FFE8C8", feet_color="E07A2A")
    pointed_ears(P, "FF9A3E", head, R, inner="FFC8A0")
    tail_curve(P, "FF9A3E", r=0.07, length=0.7, up=0.6, tip="5E7A2E")
    for k in (-1, 1):
        sph(P, "E8701E", surface(BODY, BODY_R, k * 25, 10, 0.98), 1, scale=(0.05, 0.05, 0.3))
    hat = head + Vector((0, -0.02, R * 0.92))
    sph(P, "F07A22", hat, 1, scale=(0.3, 0.3, 0.2))
    cyl(P, "5E7A2E", hat + Vector((0, 0, 0.2)), 0.04, 0.16, verts=6)
    leaf(P, "6CB33A", hat + Vector((0.06, 0, 0.24)), length=0.2, width=0.08, rot=(0, math.radians(60), 0))


def ghost_puppy(P):
    # Floating white ghost puppy: round body melting into a wavy tail, floppy ears, tongue.
    body = Vector((0, 0, 0.75))
    R = (0.45, 0.5, 0.45)
    sph(P, "F4F6FF", body, 1, scale=R, seg=16, rings=10)
    for i in range(4):
        a = math.radians(i * 90 + 45)
        cone(P, "F4F6FF", (math.cos(a) * 0.28, math.sin(a) * 0.28 - 0.1, 0.3), 0.15, 0.02, 0.38, rot=(math.pi, 0, 0), verts=8)
    head = Vector((0, 0.3, 1.2))
    HR = 0.42
    sph(P, "F4F6FF", head, HR)
    for side in (-1, 1):
        sph(P, "D8DCF4", head + Vector((side * 0.4, -0.02, 0.05)), 1, scale=(0.1, 0.16, 0.3), rot=(0, side * 0.3, 0))
    eyes(P, head, HR, spread=26, pitch=6, size=0.12, color="5A7AFF", kind="Neon")
    cheeks(P, head, HR)
    sph(P, "3A2A3A", surface(head, HR, 0, -8, 1.02), 0.06, scale=(1.2, 0.8, 0.8))
    sph(P, "FF8AA8", surface(head, HR, 0, -28, 0.95), 1, scale=(0.07, 0.05, 0.1))
    sph(P, "A8B8FF", body + Vector((0, -0.4, 0.2)), 0.1, kind="Neon")


def gummy_bat(P):
    # Round purple gummy bat with big wings, tiny fangs and a green gummy belly.
    body = Vector((0, 0, 0.75))
    sph(P, "8A3AD8", body, 1, scale=(0.42, 0.4, 0.45))
    sph(P, "5AD860", body + Vector((0, 0.24, -0.05)), 1, scale=(0.26, 0.18, 0.3))
    head = Vector((0, 0.1, 1.22))
    R = 0.38
    sph(P, "8A3AD8", head, R)
    pointed_ears(P, "8A3AD8", head, R, size=0.14, height=0.32, inner="C890FF")
    eyes(P, head, R, spread=26, pitch=8, size=0.12)
    cheeks(P, head, R)
    for side in (-1, 1):
        cone(P, WHITE, surface(head, R, side * 8, -30, 0.95), 0.03, 0.0, 0.08, rot=(math.pi, 0, 0), verts=4)
    wings_dragon(P, "6A2AB0", z=0.95, y=-0.05, span=0.85)
    feet(P, "6A2AB0", [(-0.14, 0.05), (0.14, 0.05)], r=0.09)


def lantern_raven(P):
    # Black raven with violet sheen, holding a little glowing orange lantern.
    sph(P, "2A2438", BODY, 1, scale=(0.4, 0.44, 0.5))
    sph(P, "5A4A80", (0, 0.24, 0.6), 1, scale=(0.26, 0.18, 0.28))
    head = Vector((0, 0.12, 1.08))
    R = 0.36
    sph(P, "2A2438", head, R)
    eyes(P, head, R, spread=34, pitch=10, size=0.11, color="FFB43A", kind="Neon")
    cheeks(P, head, R)
    beak(P, "FFC83A", head, R)
    wings_bird(P, "3A3050", spread=0.38, z=0.58, size=0.32)
    flat(P, "2A2438", [(-0.16, 0), (0.16, 0), (0.1, -0.42), (-0.1, -0.42)], 0.06, c=(0, -0.38, 0.32), rot=(math.radians(-30), 0, 0))
    feet(P, "FFC83A", [(-0.16, 0.12), (0.16, 0.12)], r=0.09)
    # Lantern hanging from a little stick under the wing.
    stick(P, "6A4A2A", (0.42, 0.2, 0.55), (0.62, 0.42, 0.62), 0.025)
    lamp = Vector((0.62, 0.42, 0.44))
    cyl(P, "3A3050", lamp + Vector((0, 0, 0.14)), 0.1, 0.05, verts=8)
    sph(P, "FF9A2E", lamp, 1, scale=(0.09, 0.09, 0.12), kind="Neon")
    cyl(P, "3A3050", lamp + Vector((0, 0, -0.13)), 0.1, 0.04, verts=8)


def moonlight_wolf(P):
    # Silver-blue wolf pup with a glowing crescent moon on its forehead and a fluffy tail.
    head, R = critter(P, "9AA8D8", belly="E4E8FF", muzzle="E4E8FF", feet_color="7A88B8")
    pointed_ears(P, "9AA8D8", head, R, size=0.18, height=0.42, inner="E4E8FF")
    moon = bp.crescent_points(0.14)
    flat(P, "FFF2A8", moon, 0.04, c=surface(head, R, 0, 40, 1.0), rot=(math.radians(-40), 0, 0), kind="Neon")
    for k in range(7):
        t = k / 6
        sph(P, "9AA8D8" if k < 5 else "E4E8FF", (0, BODY[1] - 0.45 - t * 0.35, 0.5 + math.sin(t * 2.4) * 0.45), 0.14 + 0.05 * math.sin(t * math.pi), seg=8, rings=6)
    bs.sparkles(P, "DDE4FF", (0, 0, 0.9), radius=0.8, n=2, size=0.06)


def phantom_dragon(P):
    # Translucent-looking pale violet dragon ghost: wispy tail instead of legs, glowing eyes,
    # little horns and ghostly wings.
    body = Vector((0, 0, 0.85))
    R = (0.48, 0.55, 0.5)
    sph(P, "C8B8FF", body, 1, scale=R, seg=16, rings=10)
    sph(P, "EEE8FF", body + Vector((0, 0.28, -0.05)), 1, scale=(0.3, 0.2, 0.35))
    for k in range(6):
        t = k / 5
        sph(P, "C8B8FF", (math.sin(t * 3) * 0.15, -0.35 - t * 0.5, 0.45 - t * 0.25), 0.22 * (1 - t * 0.7), seg=10, rings=7)
    head = Vector((0, 0.35, 1.45))
    HR = (0.36, 0.4, 0.32)
    sph(P, "C8B8FF", head, 1, scale=HR)
    sph(P, "EEE8FF", surface(head, HR, 0, -20, 0.8), 1, scale=(0.2, 0.18, 0.13))
    eyes(P, head, HR, spread=30, pitch=10, size=0.1, color="7AF0FF", kind="Neon")
    cheeks(P, head, HR)
    for side in (-1, 1):
        cone(P, "8A70D8", head + Vector((side * 0.17, -0.1, 0.27)), 0.06, 0.0, 0.24, rot=(math.radians(-25), side * math.radians(15), 0), verts=6)
    wings_dragon(P, "A890F0", z=1.05, y=-0.2, span=0.8)
    for x, y, z in ((-0.2, -0.1, 1.2), (0.25, 0.0, 1.0), (0.0, -0.4, 1.3)):
        sph(P, "B8F4FF", (x, y, z), 0.04, kind="Neon")


def count_fangtastic(P):
    # Friendly vampire bat count (Secret pet): round dark-violet bat in a red-lined cape,
    # a tiny bow tie, little fangs, a golden crown and a halo.
    body = Vector((0, 0, 0.72))
    sph(P, "4A2A6E", body, 1, scale=(0.44, 0.42, 0.46))
    sph(P, "F4F0FF", body + Vector((0, 0.3, 0.1)), 1, scale=(0.2, 0.12, 0.26))
    flat(P, "D8283A", [(-0.1, 0.0), (0.1, 0.0), (0.0, -0.08)], 0.05, c=body + Vector((0, 0.42, 0.3)))
    sph(P, "D8283A", body + Vector((0, 0.43, 0.3)), 0.04)
    # Cape: two wide flats behind the body, dark outside, red inside.
    for side in (-1, 1):
        pts = [(0, 0.35), (side * 0.6, 0.2), (side * 0.7, -0.45), (side * 0.3, -0.35), (0, -0.4)]
        if side < 0:
            pts.reverse()
        flat(P, "2A1A3A", pts, 0.04, c=(0, -0.3, 0.75), rot=(0, 0, side * math.radians(-12)))
        flat(P, "D8283A", [(x * 0.85, z * 0.85) for x, z in pts], 0.03, c=(0, -0.26, 0.75), rot=(0, 0, side * math.radians(-12)))
    head = Vector((0, 0.12, 1.24))
    R = 0.4
    sph(P, "4A2A6E", head, R)
    pointed_ears(P, "4A2A6E", head, R, size=0.15, height=0.36, inner="C890FF")
    eyes(P, head, R, spread=26, pitch=8, size=0.13, color="FF4A6A", kind="Neon")
    cheeks(P, head, R)
    for side in (-1, 1):
        cone(P, WHITE, surface(head, R, side * 9, -30, 0.96), 0.035, 0.0, 0.09, rot=(math.pi, 0, 0), verts=4)
    crown = head + Vector((0, -0.04, R * 0.9))
    cyl(P, "FFD84A", crown, 0.2, 0.1, verts=10, kind="Metal")
    for k in range(5):
        a = math.radians(k * 72 + 90)
        cone(P, "FFD84A", crown + Vector((math.cos(a) * 0.18, math.sin(a) * 0.18, 0.11)), 0.045, 0.0, 0.14, verts=4, kind="Metal")
    sph(P, "D8283A", crown + Vector((0, 0.2, 0.03)), 0.05, kind="Neon")
    feet(P, "2A1A3A", [(-0.14, 0.05), (0.14, 0.05)], r=0.09)
    bs.halo(P, "FFE89A", head, R, lift=0.55)
    bs.sparkles(P, "F0D8FF", (0, 0, 0.8), radius=1.0)


PETS = {
    "PumpkinKitten": pumpkin_kitten,
    "GhostPuppy": ghost_puppy,
    "GummyBat": gummy_bat,
    "LanternRaven": lantern_raven,
    "MoonlightWolf": moonlight_wolf,
    "PhantomDragon": phantom_dragon,
    "CountFangtastic": count_fangtastic,
}

# Unused imports kept out of the linter's way (shared building blocks).
_ = (torus,)
