"""World 13 – Crystal Cave (#87): 3 toppings, 6 pets of the crystal egg and the Secret pet.

Read by tools/blender/build_world.py (python tools/blender/build_world.py CrystalCave).
The egg comes from its `look` in GameConfig (build_eggs.py, pattern "Crystals").
Every topping is built from at least two colours (two parts), so Studio keeps it a Model.
Kid-friendly cave critters: round bodies, big eyes, crystals instead of sharp spikes.
"""

import math

import build_secret_pets as bs
import build_toppings as bt
from build_pets import (
    BODY,
    BODY_R,
    cheeks,
    cone,
    critter,
    cyl,
    eyes,
    feet,
    flat,
    ico,
    pointed_ears,
    sph,
    surface,
    tail_curve,
    torus,
    wings_dragon,
)
from mathutils import Vector

# Picture colours (sky, ground) of the world preview: deep violet cave over amethyst rock.
SKY = "4A3A78"
GROUND = "706490"

CRYSTAL = "B078FF"
CYAN = "7FF0FF"
PINK = "FF96E6"

# ---------------------------------------------------------------- toppings


def crystal_salt():
    # A little heap of crystal salt: pale cubes of rock salt with violet and cyan crystals.
    bt.part(bt.slab(bt.outline(0.48, 20, 0.08, 4, stretch=(1, 0.85)), 0.0, 0.06), "E8E4F4")
    for k, (x, y, s) in enumerate(((-0.25, 0.1, 0.22), (0.2, 0.2, 0.18), (0.05, -0.25, 0.2), (0.32, -0.15, 0.14), (-0.3, -0.25, 0.13))):
        cube = bt.cylinder(s * 0.7, s, (x, y, 0.06 + s / 2), verts=4, rot=(0, 0, k * 0.7))
        bt.part(cube, "FFFFFF" if k % 2 == 0 else "D8CCF4", "Glass")
    for k, (x, y) in enumerate(((0.0, 0.05), (-0.12, -0.08), (0.18, -0.02))):
        bt.part(bt.cone(0.07, 0.0, 0.3, (x, y, 0.28), verts=6, rot=(0.2 * (k - 1), 0.15, 0)), CRYSTAL if k != 1 else CYAN, "Neon")


def glow_mushroom():
    # Two glowing cave mushrooms lying on their side: pale stems, glowing cyan caps with spots.
    for k, (cx, cy, rot, size) in enumerate(((-0.2, 0.05, 0.4, 1.0), (0.3, -0.2, -0.9, 0.75))):
        c, s = math.cos(rot), math.sin(rot)
        bt.part(bt.cylinder(0.08 * size, 0.42 * size, (cx - c * 0.15 * size, cy - s * 0.15 * size, 0.09), verts=10, rot=(0, math.pi / 2, rot)), "F0ECF8")
        cap = (cx + c * 0.12 * size, cy + s * 0.12 * size, 0.16)
        bt.part(bt.sphere(0.26 * size, cap, (0.55, 1, 1), 14, 9), CYAN if k == 0 else "9AFFD0", "Neon")
        for j in range(3):
            a = j * 2.1
            bt.part(bt.sphere(0.04 * size, (cap[0] + c * 0.06, cap[1] + math.cos(a) * 0.14 * size, cap[2] + math.sin(a) * 0.14 * size + 0.04), (1, 1, 0.6), 6, 4), "FFFFFF")


def amethyst_olive():
    # Three olive rings cut from amethyst: violet glassy rings with a dark hole and a shine.
    for i, (cx, cy) in enumerate(((-0.3, 0.15), (0.3, 0.2), (0.0, -0.3))):
        outer = bt.outline(0.24, 18, 0.03, i + 2, center=(cx, cy), stretch=(1, 0.82))
        inner = bt.outline(0.1, 18, 0.0, i, center=(cx, cy), stretch=(1, 0.82))
        bt.part(bt.band(outer, inner, 0.0, 0.12), "8A4AE0", "Glass")
        bt.part(bt.slab(inner, 0.0, 0.05), "3A1E6A")
        bt.part(bt.sphere(0.04, (cx - 0.12, cy + 0.08, 0.13), (1, 1, 0.5), 6, 4), "F4E4FF")


TOPPINGS = {"CrystalSalt": crystal_salt, "GlowMushroom": glow_mushroom, "AmethystOlive": amethyst_olive}

# ---------------------------------------------------------------- pets (front = +Y)


def crystal_tuft(P, at, colors=(CRYSTAL, CYAN, PINK), size=0.12, kind=None):
    # Three small crystals leaning apart, used as back tufts and crowns.
    at = Vector(at)
    for k, lean in enumerate((-25, 0, 25)):
        cone(P, colors[k % len(colors)], at + Vector((math.sin(math.radians(lean)) * size, 0, size * 0.6)), size * 0.5, 0.0, size * 2.2, rot=(0, math.radians(lean), 0), verts=5, kind=kind)


def crystal_bat(P):
    # Round lilac bat with big ears, crystal wings and a little salt crystal on its head.
    body = Vector((0, 0, 0.8))
    sph(P, "9A86C8", body, 1, scale=(0.4, 0.38, 0.42))
    head = Vector((0, 0.1, 1.2))
    R = 0.36
    sph(P, "9A86C8", head, R)
    eyes(P, head, R, spread=30, pitch=6, size=0.13)
    cheeks(P, head, R)
    pointed_ears(P, "9A86C8", head, R, size=0.15, height=0.36, inner="E0C8FF")
    wings_dragon(P, CYAN, z=0.9, y=-0.05, span=0.85, kind="Glass")
    crystal_tuft(P, head + Vector((0, -0.05, R * 0.85)), colors=("FFFFFF", CYAN, "FFFFFF"), size=0.08)
    feet(P, "6A5A98", [(-0.14, 0.05), (0.14, 0.05)], r=0.1)


def glowshroom_snail(P):
    # Soft teal snail with a glowing mushroom cap as its shell and tiny mushrooms on top.
    sph(P, "6ACFB8", (0, 0.05, 0.25), 1, scale=(0.3, 0.75, 0.22))
    head = Vector((0, 0.6, 0.62))
    R = 0.3
    sph(P, "6ACFB8", head, R)
    eyes(P, head, R, spread=28, pitch=8, size=0.11)
    cheeks(P, head, R)
    for side in (-1, 1):
        cyl(P, "6ACFB8", head + Vector((side * 0.1, 0, 0.32)), 0.03, 0.26, rot=(0, side * math.radians(15), 0), verts=6)
        sph(P, CYAN, head + Vector((side * 0.14, 0, 0.46)), 0.05, kind="Neon")
    sph(P, "F0ECF8", (0, -0.15, 0.5), 1, scale=(0.32, 0.36, 0.3))
    sph(P, CYAN, (0, -0.15, 0.78), 1, scale=(0.5, 0.52, 0.28), kind="Neon")
    for x, y in ((-0.2, -0.05), (0.18, -0.25), (0.02, 0.1), (-0.05, -0.38)):
        sph(P, "FFFFFF", (x, y, 0.98), 0.05, scale=(1, 1, 0.5))
    cyl(P, "F0ECF8", (0.2, -0.3, 1.08), 0.03, 0.14, verts=6)
    sph(P, "9AFFD0", (0.2, -0.3, 1.16), 1, scale=(0.08, 0.08, 0.05), kind="Neon")


def amethyst_hedgehog(P):
    # Round sand-coloured hedgehog whose spines are soft amethyst crystals.
    head, R = critter(P, "C8A888", belly="F4E4D0", feet_color="A8886A", head=(0, 0.35, 0.82), R=0.4, muzzle="F4E4D0")
    for row, z in enumerate((0.7, 0.92)):
        for k in range(5):
            a = math.radians(-70 + k * 35 + row * 17)
            base = Vector((math.sin(a) * 0.38, -0.12 - math.cos(a) * 0.1 - row * 0.08, z))
            cone(P, CRYSTAL if (k + row) % 2 == 0 else PINK, base, 0.09, 0.0, 0.34, rot=(math.radians(-35), math.sin(a) * 0.6, 0), verts=5, kind="Glass")
    cone(P, CYAN, (0, -0.1, 1.08), 0.08, 0.0, 0.3, rot=(math.radians(-10), 0, 0), verts=5, kind="Neon")


def cave_axolotl(P):
    # Pale pink axolotl from the underground lake: wide smile, glowing gill fronds, a tail fin.
    sph(P, "FFC4DC", (0, -0.05, 0.42), 1, scale=(0.36, 0.55, 0.3))
    head = Vector((0, 0.42, 0.7))
    R = (0.42, 0.36, 0.32)
    sph(P, "FFC4DC", head, 1, scale=R)
    eyes(P, head, R, spread=36, pitch=12, size=0.11)
    cheeks(P, head, R)
    flat(P, "C85A8A", [(-0.14, 0), (0.14, 0), (0.1, -0.03), (-0.1, -0.03)], 0.02, c=surface(head, R, 0, -12, 0.98))
    for side in (-1, 1):
        for k in range(3):
            base = head + Vector((side * 0.36, -0.05, 0.12 - k * 0.12))
            cone(P, PINK if k != 1 else CYAN, base + Vector((side * 0.12, 0, 0.04)), 0.05, 0.0, 0.28, rot=(0, side * math.radians(70 - k * 20), 0), verts=6, kind="Neon")
    tail_curve(P, "FFC4DC", r=0.1, length=0.7, up=0.1, z=0.4)
    flat(P, "FFB0D0", [(0, 0), (0.0, 0.3), (-0.05, 0.0)], 0.03, c=(0, -0.75, 0.48), rot=(0, 0, math.radians(90)), kind="Glass")
    feet(P, "F0A0C0", [(-0.25, 0.25), (0.25, 0.25), (-0.25, -0.25), (0.25, -0.25)], r=0.1)


def geode_golem(P):
    # Chunky round rock golem split open like a geode: a glowing amethyst core in its chest.
    ico(P, "7A7088", (0, -0.05, 0.55), 1, scale=(0.5, 0.45, 0.5), subdiv=2, jit=0.03, seed=3)
    sph(P, "5A2A9A", (0, 0.3, 0.6), 1, scale=(0.24, 0.12, 0.28))
    for k, (x, z) in enumerate(((-0.08, 0.6), (0.08, 0.52), (0.0, 0.72))):
        cone(P, CRYSTAL if k != 2 else PINK, (x, 0.38, z), 0.05, 0.0, 0.18, rot=(math.radians(-80), 0, 0), verts=5, kind="Neon")
    head = Vector((0, 0.15, 1.18))
    R = 0.36
    ico(P, "8A8098", head, R, subdiv=2, jit=0.02, seed=5)
    eyes(P, head, R, spread=28, pitch=6, size=0.12, color="3A1E6A")
    cheeks(P, head, R)
    crystal_tuft(P, head + Vector((0, -0.05, R * 0.8)), size=0.12, kind="Glass")
    for side in (-1, 1):
        ico(P, "7A7088", (side * 0.55, 0.05, 0.6), 0.18, subdiv=1, jit=0.02, seed=7 + side)
    feet(P, "5A5068", [(-0.22, 0.05), (0.22, 0.05)], r=0.16)


def prism_dragon(P):
    # Sleek crystal dragon: lilac body, prism wings in rainbow glass, glowing crystal spines.
    sph(P, "B8A0F0", (0, -0.05, 0.62), 1, scale=(0.4, 0.5, 0.42))
    sph(P, "E8DEFF", (0, 0.24, 0.58), 1, scale=(0.24, 0.2, 0.3))
    head = Vector((0, 0.34, 1.22))
    R = (0.36, 0.42, 0.34)
    sph(P, "B8A0F0", head, 1, scale=R)
    eyes(P, head, R, spread=30, pitch=10, size=0.12)
    cheeks(P, head, R)
    for side in (-1, 1):
        cone(P, CYAN, surface(head, R, side * 22, 40, 0.95), 0.06, 0.0, 0.3, rot=(math.radians(-30), side * math.radians(18), 0), verts=5, kind="Neon")
    wings_dragon(P, PINK, z=0.95, y=-0.2, span=0.95, kind="Glass")
    for k in range(5):
        y = 0.1 - k * 0.24
        cone(P, (CRYSTAL, CYAN, PINK)[k % 3], (0, y, 1.02 - k * 0.07), 0.08, 0.0, 0.24, rot=(math.radians(-20), 0, 0), verts=5, kind="Neon")
    tail_curve(P, "B8A0F0", r=0.09, length=0.9, up=0.35, z=0.5, tip=CYAN)
    feet(P, "8A70C8", [(-0.2, 0.05), (0.2, 0.05)], r=0.14)
    bs.sparkles(P, "E8F8FF", (0, 0, 0.9), radius=0.95, n=2, size=0.06)


def diamond_mole_king(P):
    # Secret pet: a happy brown mole with a miner's helmet (glowing lamp), pink nose and big
    # digging paws, a diamond crown on the helmet and the Secret halo.
    head, R = critter(P, "6A5048", belly="C8A898", feet_color="FFB0C0", head=(0, 0.25, 1.05), R=0.46, muzzle="8A6A60", nose=None, eye_size=0.1)
    sph(P, "FF8AAA", surface(head, R, 0, -16, 1.12), 0.09, scale=(1.3, 0.9, 0.9))
    for side in (-1, 1):
        sph(P, "FFB0C0", (side * 0.48, 0.3, 0.55), 1, scale=(0.12, 0.2, 0.08))
        for k in (-1, 0, 1):
            cone(P, "F4F0E8", (side * 0.52 + k * 0.06, 0.48, 0.55), 0.03, 0.0, 0.1, rot=(math.radians(-90), 0, 0), verts=4)
    helmet = head + Vector((0, -0.02, R * 0.55))
    sph(P, "FFC83A", helmet, 1, scale=(0.48, 0.5, 0.3), kind="Metal")
    cyl(P, "FFC83A", helmet + Vector((0, 0, -0.05)), 0.52, 0.05, verts=18, kind="Metal")
    cyl(P, "FFFBE0", helmet + Vector((0, 0.42, 0.06)), 0.1, 0.08, rot=(math.radians(90), 0, 0), verts=12, kind="Neon")
    # Diamond crown on top of the helmet.
    torus(P, "FFD24A", helmet + Vector((0, 0, 0.27)), 0.2, 0.04, kind="Metal", seg=16)
    for k in range(5):
        a = k * 2 * math.pi / 5
        cone(P, "FFFFFF" if k % 2 == 0 else CYAN, helmet + Vector((math.cos(a) * 0.18, math.sin(a) * 0.18, 0.4)), 0.06, 0.0, 0.2, verts=4, kind="Glass")
    bs.halo(P, "FFE89A", head, 0.46, lift=0.62)
    bs.sparkles(P, "E8F8FF", (0, 0, 0.8), radius=1.0)


PETS = {
    "CrystalBat": crystal_bat,
    "GlowshroomSnail": glowshroom_snail,
    "AmethystHedgehog": amethyst_hedgehog,
    "CaveAxolotl": cave_axolotl,
    "GeodeGolem": geode_golem,
    "PrismDragon": prism_dragon,
    "DiamondMoleKing": diamond_mole_king,
}
