"""World 14 – Cloud City (#88): 3 toppings, 6 pets of the cloud egg and the Secret pet.

Read by tools/blender/build_world.py (python tools/blender/build_world.py CloudCity).
The egg comes from its `look` in GameConfig (build_eggs.py, pattern "Clouds").
Every topping is built from at least two colours (two parts), so Studio keeps it a Model.
Kid-friendly sky critters: round bodies, big eyes, clouds, sunshine and rainbow colours.
"""

import math

import build_secret_pets as bs
import build_toppings as bt
from build_pets import (
    beak,
    cheeks,
    cone,
    critter,
    cyl,
    eyes,
    feet,
    flat,
    legs,
    long_ears,
    sph,
    star_points,
    surface,
    tail_ball,
    tail_curve,
    torus,
    wings_bird,
)
from mathutils import Vector

# Picture colours (sky, ground) of the world preview: warm golden sky over a cloud floor.
SKY = "9FD4FF"
GROUND = "FFF0C8"

CLOUD = "FFFFFF"
CLOUD_SHADE = "E2E8F8"
GOLD = "FFC850"
SUN = "FFE27A"
RAINBOW = ("FF5A5A", "FFA046", "FFDC50", "6EDC6E", "5AA0FF", "AA6EFF")

# ---------------------------------------------------------------- toppings


def cloud_mozzarella():
    # A fluffy cloud of mozzarella: soft white puffs on a pale cream base with a golden edge.
    bt.part(bt.slab(bt.outline(0.46, 20, 0.06, 3, stretch=(1, 0.8)), 0.0, 0.05), "FFF4D8")
    for k, (x, y, r) in enumerate(((-0.2, 0.0, 0.22), (0.12, 0.06, 0.26), (0.32, -0.08, 0.17), (-0.02, -0.2, 0.18))):
        bt.part(bt.sphere(r, (x, y, 0.08 + r * 0.4), (1, 1, 0.6), 14, 9), CLOUD if k % 2 == 0 else "F4F6FF")


def sunflower_seeds():
    # A little pile of striped sunflower seeds: dark grey shells with pale stripes.
    for k, (x, y, rot) in enumerate(((-0.25, 0.1, 0.3), (0.05, 0.2, -0.6), (0.28, 0.0, 1.1), (-0.05, -0.2, 0.9), (0.22, -0.28, -0.2))):
        bt.part(bt.sphere(0.13, (x, y, 0.06), (1.6, 0.8, 0.5), 10, 6), "4A4650")
        bt.part(bt.cylinder(0.012, 0.36, (x, y, 0.1), verts=6, rot=(0, math.pi / 2, rot)), "F0ECE0")


def starfruit():
    # Two golden starfruit slices: five-pointed stars with a pale centre and seeds.
    for k, (cx, cy, r) in enumerate(((-0.2, 0.08, 0.3), (0.28, -0.15, 0.24))):
        bt.part(bt.slab(bt.star(r, r * 0.55, 5, center=(cx, cy), rot=k * 0.4), 0.0, 0.09), "FFD23A")
        bt.part(bt.slab(bt.star(r * 0.45, r * 0.25, 5, center=(cx, cy), rot=k * 0.4), 0.09, 0.02), "FFF0A0")
        for j in range(5):
            a = k * 0.4 + j * 2 * math.pi / 5 + math.pi / 2
            bt.part(bt.sphere(0.03, (cx + math.cos(a) * r * 0.3, cy + math.sin(a) * r * 0.3, 0.11), (1, 0.6, 0.5), 6, 4), "8A6A30")


TOPPINGS = {"CloudMozzarella": cloud_mozzarella, "SunflowerSeeds": sunflower_seeds, "Starfruit": starfruit}

# ---------------------------------------------------------------- pets (front = +Y)


def cloud_puff(P, at, size=0.2, color=CLOUD):
    # Three flattened balls in a row: a little cloud.
    at = Vector(at)
    for dx, r in ((-size * 0.9, size * 0.7), (0, size), (size * 0.9, size * 0.7)):
        sph(P, color, at + Vector((dx, 0, 0)), r, scale=(1, 0.8, 0.7))


def cloud_lamb(P):
    # A woolly lamb made of cloud: white puff body, soft grey face, little hooves.
    for k, (x, y, z) in enumerate(((0, -0.05, 0.6), (-0.22, 0.05, 0.7), (0.22, 0.05, 0.7), (0, -0.25, 0.75), (0, 0.1, 0.85))):
        sph(P, CLOUD if k % 2 == 0 else CLOUD_SHADE, (x, y, z), 0.3)
    head = Vector((0, 0.42, 0.95))
    R = 0.28
    sph(P, "C8C4D4", head, R)
    eyes(P, head, R, spread=30, pitch=6, size=0.11)
    cheeks(P, head, R)
    cloud_puff(P, head + Vector((0, -0.04, R * 0.85)), size=0.12)
    for side in (-1, 1):
        sph(P, "C8C4D4", head + Vector((side * 0.3, -0.02, 0.05)), 1, scale=(0.14, 0.06, 0.07))
    legs(P, "9A96A8", [(-0.18, 0.15), (0.18, 0.15), (-0.18, -0.2), (0.18, -0.2)], height=0.35, r=0.07)


def sunflower_finch(P):
    # Round yellow finch with a sunflower crest (petals around a brown centre).
    sph(P, "FFD84A", (0, 0, 0.6), 1, scale=(0.36, 0.38, 0.4))
    head = Vector((0, 0.12, 1.0))
    R = 0.3
    sph(P, "FFD84A", head, R)
    eyes(P, head, R, spread=30, pitch=6, size=0.11)
    cheeks(P, head, R)
    beak(P, "FF9A3A", head, R, length=0.16, r=0.07)
    wings_bird(P, "E8A82A", spread=0.36, z=0.6, size=0.26)
    crest = head + Vector((0, -0.05, R * 0.95))
    cyl(P, "7A4A2A", crest, 0.1, 0.05, rot=(math.radians(-20), 0, 0), verts=12)
    for k in range(8):
        a = k * math.pi / 4
        sph(P, "FFC020", crest + Vector((math.cos(a) * 0.15, math.sin(a) * 0.05, math.sin(a) * 0.13)), 1, scale=(0.07, 0.03, 0.05))
    feet(P, "E88A3A", [(-0.1, 0.05), (0.1, 0.05)], r=0.07)


def starfruit_bunny(P):
    # Pale golden bunny with long ears and a starfruit star on its forehead.
    head, R = critter(P, "FFF0C0", belly="FFFFFF", feet_color="F0D890", head=(0, 0.3, 0.95), R=0.38)
    long_ears(P, "FFF0C0", head, R, length=0.5, width=0.12, inner="FFD23A")
    flat(P, "FFD23A", star_points(0.12, 0.06, 5), 0.04, c=surface(head, R, 0, 30, 1.0), rot=(math.radians(-60), 0, 0), kind="Neon")
    tail_ball(P, CLOUD, r=0.14, z=0.5)


def rainbow_hummingbird(P):
    # Tiny round hummingbird in rainbow stripes with a long beak and glowing wing tips.
    for k, color in enumerate(RAINBOW):
        sph(P, color, (0, -0.25 + k * 0.08, 0.7), 1, scale=(0.3 - abs(k - 2.5) * 0.03, 0.06, 0.3 - abs(k - 2.5) * 0.03))
    head = Vector((0, 0.32, 0.98))
    R = 0.26
    sph(P, "5AD0C8", head, R)
    eyes(P, head, R, spread=30, pitch=6, size=0.1)
    cheeks(P, head, R)
    beak(P, "3A3A48", head, R, length=0.36, r=0.04)
    wings_bird(P, "AA6EFF", spread=0.32, z=0.8, size=0.3, angle=55, kind="Glass")
    for side in (-1, 1):
        sph(P, SUN, (side * 0.62, 0.0, 1.05), 0.05, kind="Neon")


def sky_whale(P):
    # A friendly sky-blue whale floating on a cloud, white belly, little cloud spout.
    sph(P, "7AB8F0", (0, 0, 0.8), 1, scale=(0.48, 0.7, 0.42))
    sph(P, "F0F6FF", (0, 0.1, 0.62), 1, scale=(0.38, 0.55, 0.22))
    head = Vector((0, 0.38, 0.9))
    R = (0.42, 0.3, 0.36)
    eyes(P, head, R, spread=40, pitch=4, size=0.11)
    cheeks(P, head, R)
    tail_curve(P, "7AB8F0", r=0.12, length=0.5, up=0.3, z=0.85)
    for side in (-1, 1):
        flat(P, "5A98D8", [(0, 0), (0.3, 0.05), (0.25, -0.15)], 0.05, c=(side * 0.15, -1.0, 1.05), rot=(0, 0, math.radians(90 + side * 90)))
        flat(P, "5A98D8", [(0, 0), (0.28, -0.1), (0.1, -0.2)], 0.05, c=(side * 0.42, 0.2, 0.6), rot=(0, 0, math.radians(90 - side * 90)))
    cloud_puff(P, (0, 0.15, 1.38), size=0.1)
    cloud_puff(P, (0, -0.1, 0.25), size=0.32, color=CLOUD_SHADE)


def sun_pegasus(P):
    # Golden winged pony with a glowing sun mane and rainbow wing feathers.
    head, R = critter(P, "FFE8B0", belly="FFF6DC", feet_color=GOLD, head=(0, 0.42, 1.12), R=0.34, muzzle="FFF0D0")
    for k in range(6):
        a = math.radians(-60 + k * 24)
        cone(P, SUN if k % 2 == 0 else "FFB030", head + Vector((0, -0.18 - k * 0.03, 0.2 + math.cos(a) * 0.12)), 0.07, 0.0, 0.26, rot=(math.radians(-50), 0, 0), verts=6, kind="Neon")
    for side in (-1, 1):
        for k, color in enumerate(RAINBOW[::2]):
            flat(P, color, [(0, 0), (0.5 - k * 0.08, 0.12), (0.42 - k * 0.08, -0.06)], 0.03, c=(side * 0.3, -0.05 - k * 0.04, 0.95 + k * 0.05), rot=(math.radians(20), 0, math.radians(90 - side * 90)), kind="Glass")
    cone(P, GOLD, surface(head, R, 0, 55, 0.95), 0.05, 0.0, 0.3, rot=(math.radians(-25), 0, 0), verts=6, kind="Metal")
    tail_curve(P, SUN, r=0.07, length=0.6, up=0.4, z=0.6, kind="Neon")
    bs.sparkles(P, "FFF6C8", (0, 0, 0.9), radius=0.95, n=2, size=0.06)


def cloud_king_griffin(P):
    # Secret pet: a proud little griffin - golden eagle head with a cloud mane, white wings,
    # a lion body, a gold crown with a sun gem and the Secret halo.
    head, R = critter(P, "E8B860", belly="FFE8B0", feet_color="C8903A", head=(0, 0.38, 1.12), R=0.36, nose=None)
    sph(P, "F4F0E8", head, R * 1.02)
    eyes(P, head, R, spread=30, pitch=8, size=0.12)
    beak(P, GOLD, head, R, length=0.2, r=0.09)
    for k in range(6):
        a = k * math.pi / 5 - math.pi / 2
        sph(P, CLOUD if k % 2 == 0 else CLOUD_SHADE, head + Vector((math.cos(a) * 0.36, -0.12, math.sin(a) * 0.2)), 0.14)
    wings_bird(P, CLOUD, spread=0.44, z=0.85, size=0.4, angle=40)
    torus(P, "FFD24A", head + Vector((0, -0.02, R * 0.95)), 0.17, 0.035, kind="Metal", seg=16)
    for k in range(5):
        a = k * 2 * math.pi / 5
        cone(P, "FFD24A", head + Vector((math.cos(a) * 0.15, math.sin(a) * 0.15, R * 0.95 + 0.1)), 0.04, 0.0, 0.14, verts=4, kind="Metal")
    sph(P, SUN, head + Vector((0, 0.16, R * 0.95 + 0.06)), 0.05, kind="Neon")
    tail_curve(P, "E8B860", r=0.05, length=0.6, up=0.5, z=0.5, tip=CLOUD)
    bs.halo(P, "FFE89A", head, 0.4, lift=0.62)
    bs.sparkles(P, "FFF6C8", (0, 0, 0.8), radius=1.0)


PETS = {
    "CloudLamb": cloud_lamb,
    "SunflowerFinch": sunflower_finch,
    "StarfruitBunny": starfruit_bunny,
    "RainbowHummingbird": rainbow_hummingbird,
    "SkyWhale": sky_whale,
    "SunPegasus": sun_pegasus,
    "CloudKingGriffin": cloud_king_griffin,
}
