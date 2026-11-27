"""World 12 – Dino Age (#86): 3 toppings, 6 pets of the fossil egg and the Secret pet.

Read by tools/blender/build_world.py (python tools/blender/build_world.py DinoAge).
The egg comes from its `look` in GameConfig (build_eggs.py, pattern "Footprints").
Every topping is built from at least two colours (two parts), so Studio keeps it a Model.
Kid-friendly baby dinos: round bodies, big eyes, soft spikes, no sharp teeth.
"""

import math

import build_secret_pets as bs
import build_toppings as bt
from build_pets import (
    BODY,
    BODY_R,
    WHITE,
    cheeks,
    cone,
    critter,
    cyl,
    eyes,
    feet,
    flat,
    leaf,
    sph,
    spikes,
    surface,
    wings_dragon,
)
from mathutils import Vector

# Picture colours (sky, ground) of the world preview: warm hazy sky over fern-green grass.
SKY = "E8B888"
GROUND = "70963E"

# ---------------------------------------------------------------- toppings


def fern_spinach():
    # Three curled fern-spinach leaves: dark green leaf, lighter midrib, a rolled-up tip.
    for i, (cx, cy, rot) in enumerate(((-0.4, 0.2, 0.5), (0.4, 0.3, -0.6), (0.05, -0.4, 1.6))):
        leaf_pts = bt.outline(0.45, 20, 0.08, i + 3, center=(cx, cy), stretch=(1, 0.42), rot=rot)
        bt.part(bt.slab(leaf_pts, 0.02 * i, 0.08), "3E8A34")
        c, s = math.cos(rot), math.sin(rot)
        rib = [(cx - c * 0.4, cy - s * 0.4), (cx + c * 0.4, cy + s * 0.4)]
        bt.part(bt.strip(rib, 0.05, 0.02 * i + 0.08, 0.03), "8ACB5A")
        bt.part(bt.sphere(0.09, (cx + c * 0.42, cy + s * 0.42, 0.02 * i + 0.1), (1, 1, 0.7), 8, 5), "56A040")


def prehistoric_egg():
    # A sliced boiled prehistoric egg and a whole speckled mini egg: white with a big orange
    # yolk, the whole one cream with brown spots.
    white = bt.outline(0.42, 20, 0.02, 1, center=(-0.25, 0.1), stretch=(1, 0.8))
    bt.part(bt.slab(white, 0.0, 0.14), "FFF8EA")
    bt.part(bt.slab(bt.outline(0.2, 16, 0.02, 2, center=(-0.22, 0.12)), 0.14, 0.04), "FFA22E")
    bt.part(bt.sphere(0.26, (0.45, -0.3, 0.3), (0.85, 0.85, 1.15), 14, 9), "EADCB4")
    for k in range(5):
        a = k * 1.3
        bt.part(bt.sphere(0.05, (0.45 + math.cos(a) * 0.2, -0.3 + math.sin(a) * 0.2, 0.3 + (k % 3 - 1) * 0.12), (1, 1, 0.5), 6, 4), "8A6440")


def amber_honey():
    # Three drops of golden amber honey, each with a darker core and a tiny bug-free shine.
    for i, ((cx, cy), size) in enumerate((((-0.35, 0.2), 1.0), ((0.4, 0.25), 0.8), ((0.05, -0.4), 0.7))):
        drop = bt.outline(0.36 * size, 18, 0.06, i + 7, center=(cx, cy), stretch=(1, 1.15))
        bt.part(bt.slab(drop, 0.0, 0.16 * size), "FFB02E", "Glass")
        bt.part(bt.slab(bt.outline(0.18 * size, 12, 0.03, i, center=(cx, cy)), 0.14 * size, 0.04), "C86A10")
        bt.part(bt.sphere(0.05 * size, (cx - 0.12 * size, cy + 0.12 * size, 0.2 * size), (1, 1, 0.5), 6, 4), "FFF0B0")


TOPPINGS = {"FernSpinach": fern_spinach, "PrehistoricEgg": prehistoric_egg, "AmberHoney": amber_honey}

# ---------------------------------------------------------------- pets (front = +Y)


def dino_tail(P, h, length=0.8, r=0.2, z=0.45, tip=None):
    # Thick tapering tail behind the body.
    n = 6
    for i in range(n):
        t = i / (n - 1)
        sph(P, tip if (tip and i == n - 1) else h, (0, BODY[1] - BODY_R[1] * 0.8 - t * length, z - t * 0.25), r * (1 - t * 0.6), seg=10, rings=7)


def fern_raptor(P):
    # Little green raptor standing on two legs, fern leaves on its back and a cream belly.
    sph(P, "6CBF4A", (0, -0.05, 0.62), 1, scale=(0.38, 0.45, 0.42))
    sph(P, "F4F0C8", (0, 0.2, 0.58), 1, scale=(0.24, 0.2, 0.3))
    head = Vector((0, 0.3, 1.15))
    R = 0.4
    sph(P, "6CBF4A", head, R)
    sph(P, "86D060", surface(head, R, 0, -18, 0.75), 1, scale=(0.24, 0.26, 0.18))
    eyes(P, head, R, spread=30, pitch=10, size=0.13)
    cheeks(P, head, R)
    dino_tail(P, "6CBF4A", length=0.7, r=0.18, z=0.55)
    for k, y in enumerate((0.0, -0.25, -0.5)):
        leaf(P, "3E8A34", (0, y, 0.98 - k * 0.12), length=0.3, width=0.1, rot=(math.radians(-40), 0, 0))
    for side in (-1, 1):
        sph(P, "6CBF4A", (side * 0.32, 0.25, 0.65), 1, scale=(0.07, 0.14, 0.07))
    feet(P, "4E9A36", [(-0.18, 0.05), (0.18, 0.05)], r=0.13)


def mini_triceratops(P):
    # Round blue-grey baby triceratops with a frill, two small horns and a nose horn.
    head, R = critter(P, "7A9AC8", belly="DDE6F4", feet_color="5A7AA8", muzzle="9AB4DA")
    dino_tail(P, "7A9AC8", length=0.5, r=0.16)
    frill = head + Vector((0, -0.25, 0.1))
    cyl(P, "F0B060", frill, 0.62, 0.08, rot=(math.radians(-70), 0, 0), verts=16)
    for side in (-1, 1):
        cone(P, "FFF4DC", surface(head, R, side * 20, 30, 0.95), 0.07, 0.0, 0.32, rot=(math.radians(-50), side * math.radians(10), 0), verts=6)
    cone(P, "FFF4DC", surface(head, R, 0, -12, 1.12), 0.06, 0.0, 0.2, rot=(math.radians(-60), 0, 0), verts=6)


def amber_stegosaurus(P):
    # Amber-orange stegosaurus with glowing amber plates along its back.
    head, R = critter(P, "E0963A", belly="FFE4B0", feet_color="B8722A", head=(0, 0.42, 0.85), R=0.36)
    dino_tail(P, "E0963A", length=0.75, r=0.2)
    for i in range(4):
        y = 0.2 - i * 0.22
        cone(P, "FFC24A", (0, y, 1.0 - abs(i - 1.5) * 0.06), 0.16, 0.0, 0.3, rot=(0, 0, math.radians(45)), verts=4, kind="Neon")
    for side in (-1, 1):
        cone(P, "FFF4DC", (side * 0.06, -0.95, 0.3), 0.04, 0.0, 0.16, rot=(0, side * math.radians(60), 0), verts=4)


def volcano_pterodactyl(P):
    # Dark red flying pterodactyl with orange wing membranes, a head crest and a glowing chest.
    body = Vector((0, 0, 0.8))
    sph(P, "A83A2A", body, 1, scale=(0.34, 0.4, 0.4))
    sph(P, "FF8A3A", body + Vector((0, 0.26, 0)), 0.1, kind="Neon")
    head = Vector((0, 0.32, 1.22))
    R = 0.32
    sph(P, "A83A2A", head, R)
    eyes(P, head, R, spread=30, pitch=10, size=0.11)
    cheeks(P, head, R)
    cone(P, "E8C870", surface(head, R, 0, -10, 0.9) + Vector((0, 0.15, 0)), 0.09, 0.0, 0.36, rot=(math.radians(-90), 0, 0), verts=6)
    cone(P, "D85A2A", head + Vector((0, -0.3, 0.2)), 0.08, 0.0, 0.4, rot=(math.radians(60), 0, 0), verts=4)
    wings_dragon(P, "FF8A3A", z=0.95, y=-0.05, span=0.95)
    for side in (-1, 1):
        sph(P, "7A2A1E", (side * 0.12, 0.05, 0.4), 0.08)


def lava_ankylosaurus(P):
    # Wide, low ankylosaurus with a basalt shell, glowing lava cracks and a club tail.
    sph(P, "5A4A46", (0, -0.05, 0.5), 1, scale=(0.55, 0.6, 0.38))
    for x, y in ((-0.25, 0.15), (0.25, 0.1), (0.0, -0.15), (-0.2, -0.35), (0.22, -0.32)):
        sph(P, "FF6A1E", (x, y, 0.86), 0.06, kind="Neon")
    for x, y in ((-0.38, 0.0), (0.38, -0.05), (0.0, 0.25), (0.0, -0.45)):
        cone(P, "3A302E", (x, y, 0.8), 0.08, 0.0, 0.16, verts=5)
    head = Vector((0, 0.55, 0.62))
    R = 0.3
    sph(P, "7A6A64", head, R)
    eyes(P, head, R, spread=32, pitch=10, size=0.1)
    cheeks(P, head, R)
    dino_tail(P, "5A4A46", length=0.55, r=0.14, z=0.38)
    sph(P, "3A302E", (0, -1.05, 0.25), 0.18)
    sph(P, "FF6A1E", (0, -1.05, 0.42), 0.05, kind="Neon")
    feet(P, "3A302E", [(-0.35, 0.3), (0.35, 0.3), (-0.35, -0.3), (0.35, -0.3)], r=0.12)


def primal_t_rex(P):
    # Green-gold baby T-Rex, big head with a wide smile, tiny arms, back spikes that glow.
    sph(P, "4E9A3A", (0, -0.05, 0.62), 1, scale=(0.42, 0.48, 0.46))
    sph(P, "F0E0A0", (0, 0.24, 0.58), 1, scale=(0.26, 0.2, 0.32))
    head = Vector((0, 0.32, 1.25))
    R = (0.42, 0.5, 0.38)
    sph(P, "4E9A3A", head, 1, scale=R)
    flat(P, WHITE, [(-0.2, 0), (0.2, 0), (0.16, -0.04), (-0.16, -0.04)], 0.02, c=surface(head, R, 0, -25, 0.97))
    eyes(P, head, R, spread=32, pitch=14, size=0.12)
    cheeks(P, head, R)
    dino_tail(P, "4E9A3A", length=0.85, r=0.22, z=0.55)
    spikes(P, "FFD24A", n=5, y0=0.1, y1=-0.9, z=1.0, size=0.1, kind="Neon", curve=0.4)
    for side in (-1, 1):
        sph(P, "4E9A3A", (side * 0.3, 0.32, 0.72), 1, scale=(0.06, 0.12, 0.06))
    feet(P, "3A7A2A", [(-0.2, 0.05), (0.2, 0.05)], r=0.15)
    bs.sparkles(P, "FFE89A", (0, 0, 0.9), radius=0.9, n=2, size=0.06)


def pizzasaurus_rex(P):
    # Secret pet: a happy orange T-Rex with pepperoni spots, a pizza-slice crown, a little
    # chef scarf and the Secret halo.
    sph(P, "F08A3A", (0, -0.05, 0.62), 1, scale=(0.44, 0.5, 0.48))
    sph(P, "FFE4A8", (0, 0.26, 0.58), 1, scale=(0.27, 0.2, 0.33))
    for x, y, z in ((-0.3, -0.1, 0.8), (0.32, 0.0, 0.65), (0.0, -0.35, 0.95), (-0.15, -0.3, 0.45)):
        sph(P, "C8302A", (x, y, z), 1, scale=(0.09, 0.09, 0.04))
    head = Vector((0, 0.34, 1.28))
    R = (0.44, 0.5, 0.4)
    sph(P, "F08A3A", head, 1, scale=R)
    eyes(P, head, R, spread=32, pitch=14, size=0.13, color="2A1A10")
    cheeks(P, head, R)
    flat(P, WHITE, [(-0.22, 0), (0.22, 0), (0.18, -0.05), (-0.18, -0.05)], 0.02, c=surface(head, R, 0, -25, 0.97))
    dino_tail(P, "F08A3A", length=0.85, r=0.23, z=0.55)
    # Pizza-slice crown: a cheese triangle with a crust and two pepperoni.
    top = head + Vector((0, -0.05, 0.42))
    flat(P, "FFD24A", [(-0.25, 0), (0.25, 0), (0, 0.42)], 0.06, c=top, kind="Metal")
    cyl(P, "C88A40", top, 0.05, 0.52, rot=(0, math.radians(90), 0), verts=8)
    for x, z in ((-0.06, 0.12), (0.06, 0.24)):
        sph(P, "C8302A", top + Vector((x, 0.04, z)), 1, scale=(0.05, 0.02, 0.05))
    cyl(P, "D8283A", (0, 0.12, 0.98), 0.3, 0.08, verts=14)
    feet(P, "C86A2A", [(-0.2, 0.05), (0.2, 0.05)], r=0.15)
    bs.halo(P, "FFE89A", head, 0.42, lift=0.42)
    bs.sparkles(P, "FFD8A0", (0, 0, 0.8), radius=1.0)


PETS = {
    "FernRaptor": fern_raptor,
    "MiniTriceratops": mini_triceratops,
    "AmberStegosaurus": amber_stegosaurus,
    "VolcanoPterodactyl": volcano_pterodactyl,
    "LavaAnkylosaurus": lava_ankylosaurus,
    "PrimalTRex": primal_t_rex,
    "PizzasaurusRex": pizzasaurus_rex,
}
