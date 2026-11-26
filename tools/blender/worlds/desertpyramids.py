"""World 10 – Desert Pyramids (#84): 3 toppings, 6 pets of the Pyramid egg and the Secret pet.

Read by tools/blender/build_world.py (python tools/blender/build_world.py DesertPyramids).
The egg comes from its `look` in GameConfig (build_eggs.py), so it is not defined here.
Every topping is built from at least two colours (two parts), so Studio keeps it a Model.
"""

import math

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
    legs,
    pointed_ears,
    snout_long,
    sph,
    stick,
    surface,
    torus,
)
from mathutils import Vector

# Picture colours (sky, ground) of the world preview: warm desert sky over golden sand.
SKY = "F2B866"
GROUND = "E8C680"

# ---------------------------------------------------------------- toppings


def date():
    # Three glossy brown dates, each with a darker wrinkle band and a pale stem cap.
    for i, (x, y, rot) in enumerate(((-0.45, 0.25, 0.4), (0.4, 0.35, -0.3), (0.0, -0.4, 1.3))):
        c, s = math.cos(rot), math.sin(rot)
        body = bt.sphere(0.24, (x, y, 0.2), (2.1, 1, 0.85), 14, 9)
        body.rotation_euler = (0, 0, rot)
        bt.part(bt.applied(body), "7A3E1E")
        band = bt.sphere(0.2, (x, y, 0.27), (1.6, 0.55, 0.5), 10, 6)
        band.rotation_euler = (0, 0, rot)
        bt.part(bt.applied(band), "5A2A12")
        bt.part(bt.sphere(0.07, (x + c * 0.46, y + s * 0.46, 0.22), (1, 1, 0.8), 8, 5), "D8B070")


def prickly_pear():
    # Two halves of a prickly pear: magenta flesh with black seeds in a green-red skin,
    # and one whole fruit with little spine dots.
    for i, (cx, cy) in enumerate(((-0.4, 0.2), (0.42, 0.28))):
        outer = bt.outline(0.42, 20, 0.04, i, center=(cx, cy), stretch=(1, 1.2))
        inner = bt.outline(0.34, 20, 0.04, i, center=(cx, cy), stretch=(1, 1.2))
        bt.part(bt.band(outer, inner, 0.0, 0.16), "7AA04A")
        bt.part(bt.slab(inner, 0.0, 0.15), "D4206A")
        for k in range(7):
            a = k * 0.9 + i
            r = 0.08 + (k % 3) * 0.07
            bt.part(bt.sphere(0.025, (cx + math.cos(a) * r, cy + math.sin(a) * r * 1.2, 0.16), (1, 1, 0.6), 6, 4), "2A1A1A")
    whole = bt.ico(0.3, (0.0, -0.42, 0.26), (1, 1.25, 0.9), 2)
    bt.part(bt.jitter(whole, 0.01, 7), "C83A5A")
    for k in range(6):
        a = k * 1.05
        bt.part(bt.sphere(0.03, (math.cos(a) * 0.27, -0.42 + math.sin(a) * 0.33, 0.36), (1, 1, 1), 6, 4), "F4E08A")


def desert_truffle():
    # Three knobbly sand-coloured desert truffles, one cut open with pale marbled flesh.
    for i, (x, y, r) in enumerate(((-0.42, 0.22, 0.3), (0.4, 0.3, 0.26), (0.05, -0.38, 0.32))):
        t = bt.ico(r, (x, y, r * 0.75), (1, 1, 0.8), 2)
        bt.part(bt.jitter(t, 0.03, i), "B8875A" if i != 1 else "A07448")
    cut = bt.outline(0.2, 16, 0.08, 4, center=(0.05, -0.38))
    bt.part(bt.slab(cut, 0.5, 0.03), "F2E2C4")
    vein = [(0.05 + x, -0.38 + 0.05 * math.sin(x * 14)) for x in [i / 5 * 0.28 - 0.14 for i in range(6)]]
    bt.part(bt.strip(vein, 0.04, 0.52, 0.02), "C8A27A")


TOPPINGS = {"Date": date, "PricklyPear": prickly_pear, "DesertTruffle": desert_truffle}

# ---------------------------------------------------------------- pets (front = +Y)


def date_gecko(P):
    green, light = "8CCB5A", "D8EFA0"
    body = Vector((0, -0.1, 0.32))
    sph(P, green, body, 1, scale=(0.32, 0.55, 0.24))
    sph(P, light, body + Vector((0, 0.05, -0.1)), 1, scale=(0.24, 0.45, 0.14))
    head = Vector((0, 0.5, 0.52))
    R = (0.36, 0.34, 0.28)
    sph(P, green, head, 1, scale=R)
    eyes(P, head + Vector((0, 0, 0.06)), R, spread=44, pitch=18, size=0.13)
    cheeks(P, head, R, spread=60, pitch=-12)
    for k in range(6):
        t = k / 5
        sph(P, green, (0.1 * math.sin(t * 3), -0.6 - t * 0.55, 0.28 - t * 0.12), 0.13 - t * 0.08, seg=8, rings=6)
    for x, y in ((-0.3, 0.25), (0.3, 0.25), (-0.3, -0.35), (0.3, -0.35)):
        sph(P, green, (x, y, 0.1), 1, scale=(0.12, 0.1, 0.07))
        for f in (-1, 0, 1):
            sph(P, light, (x + f * 0.06 + (0.04 if x > 0 else -0.04), y + 0.08, 0.06), 0.035, seg=6, rings=4)
    # A big date carried on the back.
    sph(P, "7A3E1E", body + Vector((0, -0.05, 0.3)), 1, scale=(0.16, 0.26, 0.14))
    sph(P, "D8B070", body + Vector((0, 0.2, 0.33)), 0.045)


def sand_scarab(P):
    shell, dark = "2E7A8A", "1E4A5A"
    body = Vector((0, -0.05, 0.42))
    sph(P, shell, body, 1, scale=(0.48, 0.55, 0.3), kind="Metal")
    box(P, dark, body + Vector((0, -0.05, 0.27)), (0.02, 0.9, 0.04))
    head = Vector((0, 0.5, 0.45))
    R = 0.28
    sph(P, dark, head, R)
    eyes(P, head, R, spread=36, pitch=10, size=0.1)
    cheeks(P, head, R, spread=56, pitch=-12, size=0.06)
    for side in (-1, 1):
        cone(P, "E8B860", head + Vector((side * 0.12, 0.1, 0.26)), 0.04, 0.0, 0.22, rot=(math.radians(-25), side * math.radians(20), 0), verts=5, kind="Metal")
        for k in range(3):
            stick(P, dark, (side * 0.35, 0.25 - k * 0.3, 0.3), (side * 0.62, 0.3 - k * 0.32, 0.04), 0.035, verts=6)
    # Pushing a little golden sun ball.
    sph(P, "FFC83A", (0, 0.98, 0.26), 0.24, kind="Metal")
    for k in range(4):
        a = k * math.pi / 2 + 0.4
        sph(P, "E8A030", (math.cos(a) * 0.2, 0.98 + math.sin(a) * 0.05, 0.26 + math.sin(a) * 0.2), 0.05)


def cactus_fennec(P):
    fur, cream = "E8C08A", "FFF0D8"
    head, R = critter(P, fur, belly=cream, feet_color="C89A60", nose="3A2A2A", eye_size=0.14)
    pointed_ears(P, fur, head, R, size=0.24, height=0.62, spread=38, pitch=46, inner="FFC0A0", tilt=24)
    snout_long(P, cream, head, R, length=0.16, r=0.18, pitch=-20)
    for i in range(4):
        t = i / 3
        sph(P, fur if i < 3 else cream, (0, -0.55 - t * 0.3, 0.45 + t * 0.4), 0.18 + math.sin(t * math.pi) * 0.05)
    # Prickly pear hat with spines.
    hat = head + Vector((0, -0.06, R * 0.92))
    sph(P, "C83A5A", hat, 1, scale=(0.2, 0.2, 0.24))
    for k in range(5):
        a = k * 1.26
        sph(P, "F4E08A", hat + Vector((math.cos(a) * 0.17, math.sin(a) * 0.17, 0.05 * (k % 2))), 0.025, seg=6, rings=4)
    cone(P, "6E9A3A", hat + Vector((0, 0, 0.24)), 0.07, 0.0, 0.14, verts=5)


def oasis_camel(P):
    fur, dark = "D8A868", "A87840"
    body = Vector((0, -0.1, 0.8))
    sph(P, fur, body, 1, scale=(0.42, 0.62, 0.38))
    sph(P, fur, body + Vector((0, -0.05, 0.38)), 1, scale=(0.26, 0.3, 0.28))
    legs(P, fur, [(-0.22, 0.3), (0.22, 0.3), (-0.22, -0.45), (0.22, -0.45)], height=0.55, r=0.09, hoof=dark)
    stick(P, fur, (0, 0.4, 0.9), (0, 0.6, 1.35), 0.13)
    head = Vector((0, 0.7, 1.5))
    R = 0.34
    sph(P, fur, head, R)
    snout_long(P, "E8C08A", head, R, length=0.2, r=0.2, pitch=-20, nose=dark)
    eyes(P, head, R, spread=34, pitch=14, size=0.11)
    cheeks(P, head, R, spread=56, pitch=-8, size=0.06)
    for side in (-1, 1):
        sph(P, fur, surface(head, R, side * 70, 45, 0.95), 1, scale=(0.06, 0.04, 0.1))
    # Colourful saddle blanket with tassels and a little palm tuft on the hump.
    box(P, "2E6FB0", body + Vector((0, 0.15, 0.36)), (0.7, 0.36, 0.05), rot=(math.radians(-8), 0, 0))
    box(P, "D4206A", body + Vector((0, 0.15, 0.39)), (0.72, 0.1, 0.04), rot=(math.radians(-8), 0, 0))
    for side in (-1, 1):
        sph(P, "FFC83A", body + Vector((side * 0.38, 0.15, 0.22)), 0.05)
    top = body + Vector((0, -0.05, 0.68))
    for k in range(4):
        a = k * math.pi / 2
        flat(P, "4A9A4A", [(0, 0), (0.24, 0.05), (0.3, -0.02), (0.22, -0.06)], 0.03, c=top, rot=(0, math.radians(-25), a))
    sph(P, "7A3E1E", top, 0.05)
    sph(P, dark, (0, -0.75, 0.85), 0.07)


def pharaoh_cat(P):
    fur, gold, blue = "3A3040", "FFC83A", "2E5FB0"
    head, R = critter(P, fur, belly="5A5068", feet_color="2A2030", nose="E88AA0", eye_size=0.15, sclera=WHITE)
    pointed_ears(P, fur, head, R, size=0.18, height=0.36, inner="E88AA0")
    # Nemes headdress: striped cloth over the head and down both sides.
    sph(P, gold, head + Vector((0, -0.08, 0.1)), 1, scale=(R * 1.04, R * 0.95, R * 0.95))
    for k in range(4):
        torus(P, blue, head + Vector((0, -0.08, 0.38 - k * 0.14)), R * (0.72 + k * 0.1), 0.03, rot=(math.radians(-14), 0, 0), seg=16, mseg=4)
    for side in (-1, 1):
        box(P, gold, head + Vector((side * R * 0.85, 0.05, -0.38)), (0.16, 0.2, 0.42))
        for k in range(3):
            box(P, blue, head + Vector((side * R * 0.86, 0.05, -0.25 - k * 0.12)), (0.17, 0.21, 0.035))
    face = surface(head, R, 0, -8, 0.5)
    FR = R * 0.78
    sph(P, fur, face, FR)
    eyes(P, face, FR, spread=27, pitch=6, size=0.14, sclera=WHITE)
    cheeks(P, face, FR)
    sph(P, "E88AA0", surface(face, FR, 0, -10, 1.02), 0.05, scale=(1.2, 0.8, 0.8), seg=8, rings=6)
    # Golden collar with a blue gem and a cobra on the forehead.
    torus(P, gold, (0, 0.05, 0.88), 0.32, 0.06, kind="Metal")
    sph(P, blue, (0, 0.36, 0.84), 0.07, kind="Glass")
    cone(P, gold, surface(head, R, 0, 40, 1.0), 0.06, 0.02, 0.2, rot=(math.radians(-20), 0, 0), verts=6, kind="Metal")
    for i in range(6):
        t = i / 5
        sph(P, fur, (0, -0.5 - t * 0.35, 0.4 + math.sin(t * math.pi) * 0.45), 0.07, seg=8, rings=6)
    sph(P, gold, (0, -0.85, 0.42), 0.08, kind="Metal")


def sun_sphinx(P):
    fur, gold, blue = "E8B860", "FFC83A", "2E5FB0"
    # Lying lion body with paws stretched to the front.
    body = Vector((0, -0.2, 0.42))
    sph(P, fur, body, 1, scale=(0.42, 0.7, 0.36))
    for side in (-1, 1):
        sph(P, fur, (side * 0.22, 0.55, 0.14), 1, scale=(0.13, 0.32, 0.12))
        sph(P, fur, (side * 0.4, -0.5, 0.18), 1, scale=(0.14, 0.24, 0.16))
    head = Vector((0, 0.35, 1.05))
    R = 0.46
    sph(P, gold, head + Vector((0, -0.06, 0.05)), 1, scale=(R * 1.08, R * 0.96, R * 1.05))
    for k in range(4):
        torus(P, blue, head + Vector((0, -0.06, 0.4 - k * 0.15)), R * (0.75 + k * 0.1), 0.03, rot=(math.radians(-14), 0, 0), seg=16, mseg=4)
    for side in (-1, 1):
        box(P, gold, head + Vector((side * R * 0.85, 0.05, -0.4)), (0.18, 0.22, 0.46))
    face = surface(head, R, 0, -8, 0.5)
    FR = R * 0.78
    sph(P, fur, face, FR)
    eyes(P, face, FR, spread=28, pitch=6, size=0.13)
    cheeks(P, face, FR)
    sph(P, "8A5A2A", surface(face, FR, 0, -10, 1.02), 0.05, scale=(1.2, 0.8, 0.8), seg=8, rings=6)
    # Wings of gold feathers and a glowing sun disc behind the head.
    for side in (-1, 1):
        for k in range(4):
            cone(P, gold if k % 2 == 0 else "FFE08A", (side * (0.42 + k * 0.06), -0.25 - k * 0.12, 0.78 + k * 0.1), 0.08, 0.0, 0.55 - k * 0.06, rot=(math.radians(-60), side * math.radians(55 + k * 6), 0), verts=5, kind="Metal")
    cyl(P, "FFB830", head + Vector((0, -0.42, 0.25)), 0.55, 0.05, rot=(math.radians(90), 0, 0), verts=20, kind="Neon")
    for k in range(8):
        a = k * math.pi / 4
        cone(P, "FFE08A", head + Vector((math.cos(a) * 0.66, -0.44, 0.25 + math.sin(a) * 0.66)), 0.06, 0.0, 0.18, rot=(0, -a + math.pi / 2, 0), verts=4, kind="Neon")
    sph(P, fur, (0, -0.95, 0.3), 0.08)


def scorpion_king(P):
    shell, dark, gold = "3A2A4A", "241830", "FFC83A"
    body = Vector((0, 0.05, 0.42))
    sph(P, shell, body, 1, scale=(0.4, 0.55, 0.28))
    head = Vector((0, 0.5, 0.6))
    R = 0.34
    sph(P, shell, head, R)
    eyes(P, head, R, spread=32, pitch=12, size=0.12, sclera=WHITE)
    cheeks(P, head, R, spread=54, pitch=-10, size=0.06)
    for side in (-1, 1):
        stick(P, shell, (side * 0.32, 0.45, 0.45), (side * 0.6, 0.85, 0.42), 0.06, verts=6)
        claw = Vector((side * 0.62, 1.02, 0.42))
        sph(P, shell, claw, 1, scale=(0.14, 0.2, 0.1))
        cone(P, dark, claw + Vector((side * 0.06, 0.2, 0.02)), 0.06, 0.0, 0.2, rot=(math.radians(-80), 0, 0), verts=5)
        cone(P, dark, claw + Vector((-side * 0.06, 0.2, 0.02)), 0.05, 0.0, 0.16, rot=(math.radians(-80), 0, 0), verts=5)
        for k in range(3):
            stick(P, dark, (side * 0.3, 0.2 - k * 0.22, 0.35), (side * 0.6, 0.15 - k * 0.25, 0.04), 0.03, verts=6)
    # Tail arching over the back with a golden stinger.
    for k in range(11):
        t = k / 10
        a = t * math.pi * 1.25
        sph(P, shell, (0, -0.42 - math.sin(a) * 0.42, 0.45 + (1 - math.cos(a)) * 0.45), 0.15 - t * 0.05, seg=10, rings=7)
    cone(P, gold, (0, -0.02, 1.18), 0.08, 0.0, 0.26, rot=(math.radians(-140), 0, 0), verts=6, kind="Metal")
    # Golden crown with gems.
    crown = head + Vector((0, -0.04, R * 0.88))
    cyl(P, gold, crown, 0.2, 0.1, verts=12, kind="Metal")
    for k in range(5):
        a = math.radians(k * 72 + 90)
        cone(P, gold, crown + Vector((math.cos(a) * 0.18, math.sin(a) * 0.18, 0.1)), 0.05, 0.0, 0.14, verts=4, kind="Metal")
    sph(P, "2E6FB0", crown + Vector((0, 0.2, 0.02)), 0.045, kind="Glass")
    bs.halo(P, "FFE08A", head, R, lift=0.45, major=0.26)
    bs.sparkles(P, "FFE8A0", (0, 0, 0.8), radius=1.0)


PETS = {
    "DateGecko": date_gecko,
    "SandScarab": sand_scarab,
    "CactusFennec": cactus_fennec,
    "OasisCamel": oasis_camel,
    "PharaohCat": pharaoh_cat,
    "SunSphinx": sun_sphinx,
    "ScorpionKing": scorpion_king,
}

# Unused imports kept out of the linter's way.
_ = (BODY, BODY_R)
