"""World 15 – Pizza Paradise (#89): 3 toppings, 6 pets of the divine egg and the Secret pet.

Read by tools/blender/build_world.py (python tools/blender/build_world.py PizzaParadise).
The egg comes from its `look` in GameConfig (build_eggs.py, pattern "Slices").
Every topping is built from at least two colours (two parts), so Studio keeps it a Model.
The golden last world of the pizza gods: gold, diamond cheese, rainbow basil, oven glow.
"""

import math

import build_secret_pets as bs
import build_toppings as bt
from build_pets import (
    beak,
    box,
    cheeks,
    cone,
    critter,
    cyl,
    eyes,
    feet,
    flat,
    horns,
    leaf,
    legs,
    pointed_ears,
    round_ears,
    snout_long,
    sph,
    surface,
    tail_curve,
    torus,
    wings_bird,
    wings_dragon,
)
from mathutils import Vector

# Picture colours (sky, ground) of the world preview: warm golden sky over a crust floor.
SKY = "FFD98A"
GROUND = "ECC468"

GOLD = "FFC438"
GOLD_DARK = "D89A20"
SALAMI = "B22834"
CHEESE = "FFD65C"
DIAMOND = "C8F0FF"
GLOW = "FFE278"
RAINBOW = ("FF5A5A", "FFA046", "FFDC50", "6EDC6E", "5AA0FF", "AA6EFF")

# ---------------------------------------------------------------- toppings


def gold_salami():
    # Two shiny golden salami slices with darker gold rims and pale fat dots.
    for k, (cx, cy, r) in enumerate(((-0.17, 0.05, 0.3), (0.22, -0.12, 0.26))):
        bt.part(bt.slab(bt.outline(r, 24, center=(cx, cy)), 0.0 + k * 0.03, 0.07), GOLD_DARK, kind="Metal")
        bt.part(bt.slab(bt.outline(r * 0.86, 24, center=(cx, cy)), 0.07 + k * 0.03, 0.02), GOLD, kind="Metal")
        for j in range(4):
            a = j * math.pi / 2 + k
            bt.part(bt.sphere(0.035, (cx + math.cos(a) * r * 0.45, cy + math.sin(a) * r * 0.45, 0.1 + k * 0.03), (1, 1, 0.4), 6, 4), "FFF2C8")


def diamond_cheese():
    # A wedge of cheese with sparkling diamond crystals growing out of it.
    bt.part(bt.slab([(-0.4, -0.25), (0.4, -0.25), (0.0, 0.35)], 0.0, 0.2), CHEESE)
    for k, (x, y, h) in enumerate(((-0.1, -0.05, 0.28), (0.12, 0.0, 0.22), (0.0, 0.15, 0.18))):
        bt.part(bt.cone(0.09, 0.0, h, (x, y, 0.2 + h / 2), verts=4), DIAMOND, kind="Glass")


def rainbow_basil():
    # Three basil leaves in rainbow colours fanned out from a little stem.
    for k, color in enumerate(("FF5A5A", "FFDC50", "6EDC6E", "5AA0FF", "AA6EFF")):
        a = math.radians(-60 + k * 30)
        cx, cy = math.sin(a) * 0.22, math.cos(a) * 0.22 - 0.1
        bt.part(bt.sphere(0.2, (cx, cy, 0.04), (0.55, 1, 0.18), 12, 6), color, kind="Neon" if k == 2 else None)
    bt.part(bt.cylinder(0.025, 0.2, (0, -0.2, 0.04), verts=6, rot=(math.pi / 2, 0, 0)), "3A8A3A")


TOPPINGS = {"GoldSalami": gold_salami, "DiamondCheese": diamond_cheese, "RainbowBasil": rainbow_basil}

# ---------------------------------------------------------------- pets (front = +Y)


def gold_salami_piglet(P):
    # A round golden piglet with salami spots and a curly tail.
    head, R = critter(P, GOLD, belly="FFE8A0", feet_color=GOLD_DARK, head=(0, 0.34, 0.95), R=0.38, nose=None)
    cyl(P, "FFB0A0", surface(head, R, 0, -6, 0.98), 0.12, 0.08, rot=(math.radians(90), 0, 0), verts=14)
    for side in (-1, 1):
        sph(P, "6A3030", surface(head, R, side * 8, -6, 1.04), 0.025)
    pointed_ears(P, GOLD_DARK, head, R, size=0.14, height=0.22)
    for k, (x, y, z) in enumerate(((-0.25, -0.1, 0.75), (0.22, 0.0, 0.8), (0.0, -0.3, 0.85))):
        cyl(P, SALAMI, (x, y, z), 0.09, 0.03, rot=(0, math.radians(90 if k % 2 == 0 else 60), 0), verts=12)
    tail_curve(P, GOLD, r=0.04, length=0.3, up=0.4, z=0.6)


def diamond_cheese_mouse(P):
    # A cheese-yellow mouse with diamond ears and a tiny diamond on its nose.
    head, R = critter(P, CHEESE, belly="FFF0B0", feet_color="E8B840", head=(0, 0.3, 0.92), R=0.36)
    round_ears(P, DIAMOND, head, R, size=0.24, inner="E8FAFF")
    cone(P, DIAMOND, surface(head, R, 0, 50, 1.0), 0.07, 0.0, 0.14, verts=4, kind="Glass")
    tail_curve(P, CHEESE, r=0.035, length=0.6, up=0.3, z=0.5, tip=DIAMOND)


def rainbow_basil_chameleon(P):
    # A chameleon in rainbow stripes with a crest of basil leaves and a curled tail.
    for k, color in enumerate(RAINBOW):
        sph(P, color, (0, 0.2 - k * 0.1, 0.62), 1, scale=(0.3, 0.08, 0.28 - abs(k - 2.5) * 0.02))
    head = Vector((0, 0.42, 0.82))
    R = 0.28
    sph(P, "6EDC6E", head, R)
    eyes(P, head, R, spread=40, pitch=8, size=0.12)
    cheeks(P, head, R)
    for k in range(4):
        leaf(P, "3AAA4A", (0, 0.3 - k * 0.16, 0.95 - k * 0.04), length=0.22, width=0.1, rot=(math.radians(-70), 0, 0))
    tail_curve(P, "AA6EFF", r=0.06, length=0.7, up=0.2, z=0.5)
    legs(P, "4AAA5A", [(-0.18, 0.2), (0.18, 0.2), (-0.18, -0.25), (0.18, -0.25)], height=0.32, r=0.06)


def pizza_phoenix(P):
    # A fiery bird of oven embers: glowing orange body, flame crest, pizza-slice wings.
    sph(P, "FF8A2A", (0, 0, 0.7), 1, scale=(0.34, 0.38, 0.4))
    head = Vector((0, 0.16, 1.06))
    R = 0.28
    sph(P, "FFA040", head, R)
    eyes(P, head, R, spread=30, pitch=6, size=0.11)
    cheeks(P, head, R)
    beak(P, GOLD, head, R, length=0.16, r=0.07)
    for k in range(3):
        cone(P, "FFD040" if k == 1 else "FF5A2A", head + Vector(((k - 1) * 0.1, -0.08, R * 0.9)), 0.07, 0.0, 0.3, rot=(math.radians(-20), 0, 0), verts=6, kind="Neon")
    for side in (-1, 1):
        flat(P, CHEESE, [(0, 0), (0.6, 0.2), (0.55, -0.15)], 0.05, c=(side * 0.3, -0.05, 0.85), rot=(math.radians(15), 0, math.radians(90 - side * 90)))
        sph(P, SALAMI, (side * 0.6, -0.05, 0.88), 0.06)
    tail_curve(P, "FF5A2A", r=0.06, length=0.6, up=0.2, z=0.55, kind="Neon")
    feet(P, GOLD_DARK, [(-0.1, 0.05), (0.1, 0.05)], r=0.07)


def oven_titan(P):
    # A friendly golem shaped like a golden dome oven, its mouth glowing like embers.
    sph(P, GOLD, (0, 0, 0.75), 1, scale=(0.5, 0.48, 0.55))
    box(P, "FF8A2A", (0, 0.44, 0.65), (0.36, 0.06, 0.24), kind="Neon")
    head = Vector((0, 0.3, 1.18))
    R = 0.26
    sph(P, GOLD_DARK, head, R)
    eyes(P, head, R, spread=30, pitch=4, size=0.1)
    cyl(P, GOLD_DARK, (0.25, -0.15, 1.35), 0.08, 0.35, verts=10)
    sph(P, "DDDDDD", (0.25, -0.15, 1.6), 0.08, kind="Glass")
    for side in (-1, 1):
        sph(P, GOLD_DARK, (side * 0.55, 0.05, 0.75), 0.15)
    legs(P, GOLD_DARK, [(-0.2, 0.0), (0.2, 0.0)], height=0.35, r=0.12)


def olympus_pizza_dragon(P):
    # The pizza gods' dragon: golden scales, a pizza-slice crest, laurel of basil and
    # glowing rainbow wings.
    head, R = critter(P, GOLD, belly="FFE8A0", feet_color=GOLD_DARK, head=(0, 0.42, 1.12), R=0.36, nose=None)
    snout_long(P, GOLD, head, R, length=0.26, r=0.18, nose=GOLD_DARK)
    horns(P, "FFF2C8", head, R, length=0.3, r=0.06)
    for k in range(5):
        a = math.radians(-60 + k * 30)
        leaf(P, "3AAA4A", head + Vector((math.sin(a) * R * 0.95, -0.05, R * 0.6 + math.cos(a) * 0.1)), length=0.16, width=0.08, rot=(0, a, 0))
    wings_dragon(P, "FFA046", z=0.95, kind="Glass")
    for k in range(3):
        flat(P, CHEESE, [(0, 0), (0.12, 0.2), (-0.12, 0.2)], 0.04, c=(0, -0.05 - k * 0.22, 1.2 - k * 0.12), rot=(math.radians(90), 0, 0))
    tail_curve(P, GOLD, r=0.08, length=0.7, up=0.3, z=0.6, tip=SALAMI)
    bs.sparkles(P, GLOW, (0, 0, 0.9), radius=0.95, n=2, size=0.06)


def pizza_zeus(P):
    # Secret pet: Pizza Zeus - a little god with a fluffy cheese-white beard, a basil laurel
    # wreath, a golden toga band and a glowing cheese lightning bolt, plus the Secret halo.
    head, R = critter(P, "FFE0C0", belly="FFFFFF", feet_color=GOLD, head=(0, 0.3, 1.1), R=0.38, nose=None)
    for k in range(7):
        a = math.radians(-70 + k * 23)
        sph(P, "FFF8E8", surface(head, R, math.degrees(a) * 0.9, -35, 0.95), 0.13)
    for k in range(8):
        a = k * 2 * math.pi / 8
        leaf(P, "3AAA4A", head + Vector((math.cos(a) * R * 0.95, math.sin(a) * R * 0.95, R * 0.55)), length=0.14, width=0.07, rot=(0, 0, a))
    torus(P, GOLD, (0, 0, 0.78), 0.4, 0.04, rot=(math.radians(60), 0, 0), kind="Metal", seg=18)
    flat(P, CHEESE, [(0, 0.5), (0.12, 0.15), (0.02, 0.15), (0.14, -0.2), (-0.06, 0.08), (0.04, 0.08)], 0.05, c=(0.5, 0.1, 0.8), rot=(math.radians(90), 0, 0), kind="Neon")
    bs.halo(P, GLOW, head, 0.4, lift=0.62)
    bs.sparkles(P, "FFF6C8", (0, 0, 0.8), radius=1.0)


PETS = {
    "GoldSalamiPiglet": gold_salami_piglet,
    "DiamondCheeseMouse": diamond_cheese_mouse,
    "RainbowBasilChameleon": rainbow_basil_chameleon,
    "PizzaPhoenix": pizza_phoenix,
    "OvenTitan": oven_titan,
    "OlympusPizzaDragon": olympus_pizza_dragon,
    "PizzaZeus": pizza_zeus,
}
