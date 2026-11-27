"""Renders the MEGA UPDATE store images (#115): new game icon and four thumbnails, each
thumbnail in German and English.

    lune run export-islands build/islands.json          (only needed for "atlantis" and "paradise")
    python tools/blender/render_mega.py [shot ...] [--preview]

Shots: icon (512 x 512), pets, atlantis, paradise, wheel (1920 x 1080 each). Without shot
names all five are rendered. Every scene is rendered ONCE; the German and English versions
only differ in the text, which is drawn afterwards with Pillow (render_store.draw-style, UI
font Fredoka, colours of docs/ui-style.md). --preview: quarter size, few samples, written
to build/store/. Output: docs/store/mega/<File>_<de|en>.png (icon: Icon.png).

Built like render_store.py (#61) from the repo's own Blender builders - the same code that
writes assets/models/*.fbx and assets/models/worlds/*.fbx (build_pets, build_secret_pets,
tools/blender/worlds/*.py, build_eggs, build_currency) - plus the exported island plan
for the Atlantis and Pizza Paradise islands (render_islands.build_scene). The texts name
no balancing numbers (prices, chances, bonuses still change in #108).
"""

import colorsys
import json
import math
import os
import random
import subprocess
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import bpy  # noqa: E402,I001
import bmesh  # noqa: E402
from mathutils import Vector  # noqa: E402

import build_currency as bc  # noqa: E402
import build_eggs as be  # noqa: E402
import build_models as bmod  # noqa: E402
import build_pets as bp  # noqa: E402
import build_secret_pets  # noqa: E402,F401  (registers the Secret pets of worlds 1-7)
import render_islands as ri  # noqa: E402
import render_store as rs  # noqa: E402
from worlds import atlantis, pizzaparadise  # noqa: E402

bp.PETS.update(atlantis.PETS)
bp.PETS.update(pizzaparadise.PETS)

ROOT = rs.ROOT
OUT_DIR = os.path.join(ROOT, "docs", "store", "mega")
PREVIEW_DIR = os.path.join(ROOT, "build", "store", "mega")
RAW_DIR = os.path.join(ROOT, "build", "store", "mega", "raw")
FONT = rs.FONT
ISLANDS = rs.ISLANDS

CREAM, DARK, COIN, ORANGE = rs.CREAM, rs.DARK, rs.COIN, rs.ORANGE
RED = (230, 70, 50)
GREEN = (90, 200, 90)

GAME = "PIZZA TOPPING SIMULATOR"
BIG = "MEGA UPDATE"

# Shot -> (file, size, samples, {lang: subtitle}); the icon has its banner instead.
SHOTS = {
    "icon": ("Icon", (512, 512), 96, None),
    "pets": ("Thumbnail1_Pets", (1920, 1080), 64, {"de": "Geheim-Pets & Glitzer-Pets", "en": "Secret Pets & Shiny Pets"}),
    "atlantis": ("Thumbnail2_Atlantis", (1920, 1080), 64, {"de": "Neue Welt: Atlantis", "en": "New World: Atlantis"}),
    "paradise": ("Thumbnail3_PizzaParadise", (1920, 1080), 64, {"de": "Neue Welt: Pizza-Paradies", "en": "New World: Pizza Paradise"}),
    "wheel": ("Thumbnail4_WheelQuests", (1920, 1080), 64, {"de": "Glücksrad & Quests", "en": "Lucky Wheel & Quests"}),
}
NEW = {"de": "NEU!", "en": "NEW!"}
QUESTS = {
    "de": ("Quests", ["Beläge sammeln", "Pizzen verkaufen", "Eier öffnen"]),
    "en": ("Quests", ["Collect toppings", "Sell pizzas", "Open eggs"]),
}

# Overlay extras a shot can set (the wheel shot puts the quest board on the right).
OVERLAY = {}

place, grab, pet, disk, ring, look_at, sky, ground = rs.place, rs.grab, rs.pet, rs.disk, rs.ring, rs.look_at, rs.sky, rs.ground
coin, gem, flat_material = rs.coin, rs.gem, rs.flat_material

# ---------------------------------------------------------------- helpers


def _bsdf(mat):
    return mat.node_tree.nodes.get("Principled BSDF")


def recolor(objs, fn, metallic=None, emission=0.0):
    """Gives every part its own material copy with base colour fn(rgb) (the eyes stay)."""
    for o in objs:
        if not o.data.materials or o.data.materials[0] is None:
            continue
        mat = o.data.materials[0].copy()
        bsdf = _bsdf(mat)
        r, g, b, a = bsdf.inputs["Base Color"].default_value
        lum = 0.2126 * r + 0.7152 * g + 0.0722 * b
        if lum < 0.02 or lum > 0.85:  # pupils, eye shine, white details
            continue
        new = fn((r, g, b), lum, o)
        bsdf.inputs["Base Color"].default_value = (*new, a)
        if metallic is not None:
            bsdf.inputs["Metallic"].default_value = metallic
            bsdf.inputs["Roughness"].default_value = 0.28
        if emission:
            bsdf.inputs["Emission Color"].default_value = (*new, 1)
            bsdf.inputs["Emission Strength"].default_value = emission
        o.data.materials[0] = mat


def gold_variant(objs):
    """Gold variant (#80): gold body, shines."""
    gold = (1.0, 0.62, 0.08)
    recolor(objs, lambda rgb, lum, o: tuple(c * min(1.0, 0.45 + lum * 2.2) for c in gold), metallic=0.75)


def rainbow_variant(objs, center):
    """Rainbow variant (#80): the hue runs around the pet."""

    index = {o.name: k for k, o in enumerate(objs)}

    def fn(rgb, lum, o):
        corners = [o.matrix_world @ Vector(c) for c in o.bound_box]
        p = sum(corners, Vector()) / 8 - Vector(center)
        hue = (index[o.name] * 0.137 + p.z * 0.35) % 1.0
        r, g, b = colorsys.hsv_to_rgb(hue, 0.65, 1.0)
        return (r * r, g * g, b * b)  # roughly linear

    recolor(objs, fn, emission=0.25)


def sparkle(location, size, rgb=(255, 245, 190), strength=6.0):
    """A four-pointed glitter star facing the camera side (+Y), glowing."""
    mat = flat_material("Sparkle", rgb, emission=strength)
    for sx, sz in ((size * 0.16, size), (size, size * 0.16)):
        bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=1, location=location)
        obj = bpy.context.active_object
        obj.scale = (sx, size * 0.08, sz)
        obj.data.materials.append(mat)


def sparkles(rnd, n, box, size=(0.12, 0.3), colors=((255, 245, 190), (255, 210, 90), (200, 240, 255), (255, 180, 240))):
    (x0, y0, z0), (x1, y1, z1) = box
    for _ in range(n):
        loc = (rnd.uniform(x0, x1), rnd.uniform(y0, y1), rnd.uniform(z0, z1))
        sparkle(loc, rnd.uniform(*size), rnd.choice(colors))


def bubble(location, radius):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=20, ring_count=12, radius=radius, location=location)
    obj = bpy.context.active_object
    obj.data.materials.append(flat_material("Bubble", (215, 245, 255), emission=0.6, alpha=0.45))
    bpy.ops.object.shade_smooth()


def egg_on_stand(egg_id, looks, x, y, width, yaw=0.0):
    place(rs.egg_stand(looks[egg_id]["accent"]), width, (x, y, 0), yaw=0)
    place(rs.egg(egg_id, looks), width * 0.58, (x, y, width * 0.223), yaw=yaw)


def island(world_index, sky_colors):
    with open(ISLANDS) as f:
        data = json.load(f)
    data["islands"] = [i for i in data["islands"] if i.get("worldIndex") == world_index]
    data["bridges"], data["gates"] = [], []
    ri.build_scene(data, ())
    rs.remove_sell_box()
    ri.setup((1920, 1080))
    sky(*sky_colors)
    return data["config"]["groundY"], data["islands"][0]


to_b = rs.to_b


def lineup(pets, gy, eye, target, dist, spacing):
    """Places pets (name, height) side by side across the view, `dist` studs in front of the
    camera (Roblox x/z), each turned towards the camera. Middle pet first in the list."""
    dx, dz = target[0] - eye[0], target[2] - eye[2]
    n = math.hypot(dx, dz)
    dx, dz = dx / n, dz / n
    lx, lz = -dz, dx
    order = [0, -1, 1, -2, 2, -3, 3]
    for k, (name, h) in enumerate(pets):
        off = order[k] * spacing
        depth = dist + abs(order[k]) * spacing * 0.35
        x, z = eye[0] + dx * depth + lx * off, eye[2] + dz * depth + lz * off
        pos = to_b(x, gy, z)
        cam = to_b(*eye)
        yaw = math.degrees(math.atan2(-(cam.x - pos.x), cam.y - pos.y))
        place(pet(name), 0, pos, yaw=yaw, height=h)

# ---------------------------------------------------------------- shots


def shot_icon():
    """Pizza Zeus (Secret pet of the last world) on a golden platform, gold and rainbow
    pets at his sides, glitter all around. The banner is drawn afterwards."""
    bmod.reset_scene()
    ri.setup((512, 512))
    sky((255, 190, 120), (110, 70, 200), 0.48, 0.62)
    ground((150, 120, 220))
    disk(2.0, 0.3, (0, 0, 0.15), (255, 200, 40), emission=0.5)
    ring(2.12, 0.15, (0, 0, 0.32), (255, 236, 140), emission=4.0)
    place(pet("PizzaZeus"), 0, (0, 0, 0.3), yaw=0, height=3.6)
    left = place(pet("PizzaPhoenix"), 0, (-2.45, 1.1, 0), yaw=30, height=1.9)
    gold_variant(left)
    right = place(pet("PoseidonSeaDragon"), 0, (2.45, 1.1, 0), yaw=-30, height=1.9)
    rainbow_variant(right, (2.45, 1.1, 1.0))
    sparkles(random.Random(115), 12, ((-3.2, -1.0, 3.6), (3.2, 1.0, 4.8)), size=(0.14, 0.3))
    bpy.ops.object.light_add(type="POINT", location=(0, 4.0, 5.0))
    light = bpy.context.active_object
    light.data.energy = 120
    light.data.color = (1.0, 0.85, 0.55)
    # Room at the bottom for the MEGA UPDATE banner.
    look_at((0, 9.0, 2.6), (0, 0, 1.35), 48)


def shot_pets():
    """The Secret pet in the middle, gold and rainbow variants, glitter, new eggs behind."""
    bmod.reset_scene()
    ri.setup((1920, 1080))
    sky((255, 222, 170), (130, 110, 230), 0.45, 0.7)
    ground((150, 120, 220))
    looks = be.read_looks()
    for egg_id, x in (("AtlantisEgg", -5.4), ("DivineEgg", 5.4)):
        egg_on_stand(egg_id, looks, x, -6.4, 3.0, yaw=-15 if x < 0 else 15)
    # Middle: Pizza Zeus on the golden platform.
    disk(1.9, 0.3, (0, 0.4, 0.15), (255, 200, 40), emission=0.4)
    ring(2.05, 0.14, (0, 0.4, 0.32), (255, 236, 140), emission=4.0)
    place(pet("PizzaZeus"), 0, (0, 0.4, 0.3), yaw=0, height=3.5)
    # Gold variants left, rainbow variants right, Secret pets of other worlds outside.
    gold_l = place(pet("OlympusPizzaDragon"), 0, (-3.0, 0.2, 0), yaw=20, height=2.4)
    gold_variant(gold_l)
    gold_s = place(pet("GoldSalamiPiglet"), 0, (-4.6, 1.2, 0), yaw=25, height=1.5)
    gold_variant(gold_s)
    rain_l = place(pet("PoseidonSeaDragon"), 0, (3.0, 0.2, 0), yaw=-20, height=2.4)
    rainbow_variant(rain_l, (3.0, 0.2, 1.0))
    rain_s = place(pet("BubblePufferfish"), 0, (4.6, 1.2, 0), yaw=-25, height=1.5)
    rainbow_variant(rain_s, (4.9, 1.0, 0.7))
    place(pet("PearlKingOtter"), 0, (-6.0, 0.0, 0), yaw=28, height=1.9)
    place(pet("BlackHoleCat"), 0, (6.0, 0.0, 0), yaw=-28, height=1.9)
    for i, (x, y) in enumerate(((-2.0, 2.6), (2.0, 2.6))):
        gem((x, y, 0.05), 0.5, yaw=i * 35)
    sparkles(random.Random(1150), 46, ((-7.5, -3.0, 0.6), (7.5, 2.0, 5.2)))
    bpy.ops.object.light_add(type="POINT", location=(0, 4.5, 5.5))
    light = bpy.context.active_object
    light.data.energy = 320
    light.data.color = (1.0, 0.85, 0.55)
    look_at((0, 11.2, 3.6), (0, -1.6, 2.2), 28)


def shot_atlantis():
    """The sunken temple of Atlantis with its pets in front and bubbles rising."""
    gy, isl = island(8, ((150, 225, 245), (25, 95, 175), 0.42, 0.72))
    lx, lz = isl["stations"]["Landmark"]["position"][0], isl["stations"]["Landmark"]["position"][2]
    # Pets on the sand in front of the temple stairs (the temple is at x -48, z -1766).
    eye, target = (lx + 40, gy + 8, lz + 52), (lx, gy + 11, lz)
    lineup([("PoseidonSeaDragon", 7.5), ("PearlMantaRay", 3.6), ("PearlKingOtter", 5.0), ("CaperClownfish", 4.0),
            ("LanternAnglerfish", 4.5)], gy, eye, target, 30, 6.5)
    rnd = random.Random(82)
    for _ in range(40):
        bubble(to_b(lx + rnd.uniform(-25, 40), gy + rnd.uniform(3, 30), lz + rnd.uniform(-10, 30)), rnd.uniform(0.3, 1.1))
    look_at(to_b(*eye), to_b(*target), 28)


def shot_paradise():
    """The golden pizza statue of Pizza Paradise, its pets in front, coins and glitter."""
    gy, isl = island(15, ((255, 190, 130), (140, 90, 210), 0.42, 0.7))
    lx, lz = isl["stations"]["Landmark"]["position"][0], isl["stations"]["Landmark"]["position"][2]
    eye, target = (lx + 58, gy + 7, lz + 74), (lx, gy + 21, lz)
    lineup([("OlympusPizzaDragon", 10.0), ("OvenTitan", 8.0), ("PizzaPhoenix", 7.0), ("GoldSalamiPiglet", 5.0),
            ("DiamondCheeseMouse", 5.0)], gy, eye, target, 46, 9.0)
    rnd = random.Random(89)
    for i in range(9):
        rs.coin(to_b(lx + rnd.uniform(-6, 34), gy + rnd.uniform(9, 24), lz + rnd.uniform(18, 40)), 1.6,
                yaw=rnd.uniform(-60, 60), tilt=(80, rnd.uniform(-20, 20)))
    for _ in range(36):
        sparkle(to_b(lx + rnd.uniform(-25, 40), gy + rnd.uniform(4, 40), lz + rnd.uniform(-10, 40)), rnd.uniform(0.4, 1.0),
                rnd.choice(((255, 245, 190), (255, 210, 90))))
    look_at(to_b(*eye), to_b(*target), 30)


# Fields of GameConfig.luckyWheel (clockwise from the top): colour and icon.
WHEEL = [((255, 200, 40), "coin"), ((60, 230, 255), "gem"), ((170, 110, 230), "potion"), ((40, 170, 230), "gem"),
         ((240, 150, 30), "coin"), ((130, 70, 200), "potion"), ((30, 110, 210), "gem"), ((230, 70, 50), "jackpot")]


def wedge(radius, a0, a1, depth, center, rgb):
    """Pie slice in the XZ plane (facing +Y), angles clockwise from the top as seen from +Y."""
    mesh = bpy.data.meshes.new("Wedge")
    obj = bpy.data.objects.new("Wedge", mesh)
    bpy.context.collection.objects.link(obj)
    bm = bmesh.new()
    pts = [(0.0, 0.0)] + [(-math.sin(a) * radius, math.cos(a) * radius) for a in (a0 + (a1 - a0) * k / 10 for k in range(11))]
    front = [bm.verts.new((x, depth / 2, z)) for x, z in pts]
    back = [bm.verts.new((x, -depth / 2, z)) for x, z in pts]
    bm.faces.new(front)
    bm.faces.new(list(reversed(back)))
    for i in range(len(pts)):
        j = (i + 1) % len(pts)
        bm.faces.new([front[i], front[j], back[j], back[i]])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    bm.to_mesh(mesh)
    bm.free()
    obj.location = center
    obj.data.materials.append(flat_material("Wedge", rgb))
    return obj


def potion(location, height, rgb=(190, 120, 255)):
    x, y, z = location
    bpy.ops.mesh.primitive_uv_sphere_add(segments=20, ring_count=12, radius=height * 0.36, location=(x, y, z + height * 0.36))
    bpy.context.active_object.data.materials.append(flat_material("Potion", rgb, emission=1.2, alpha=0.85))
    bpy.ops.mesh.primitive_cylinder_add(vertices=12, radius=height * 0.12, depth=height * 0.3, location=(x, y, z + height * 0.82))
    bpy.context.active_object.data.materials.append(flat_material("Neck", (230, 240, 255)))
    bpy.ops.mesh.primitive_cylinder_add(vertices=12, radius=height * 0.14, depth=height * 0.12, location=(x, y, z + height * 1.0))
    bpy.context.active_object.data.materials.append(flat_material("Cork", (170, 110, 60)))


def shot_wheel():
    """The lucky wheel (as WheelService builds it: wooden stand, gold rim with lights, 8
    coloured fields, red pointer) with prize icons, a pet and flying prizes. The quest
    board is drawn on the right afterwards."""
    bmod.reset_scene()
    ri.setup((1920, 1080))
    sky((255, 236, 200), (120, 180, 250), 0.45, 0.72)
    ground((110, 200, 90))
    cx, cy, cz, r = 3.0, 0.0, 3.3, 2.9
    # Stand: two wooden legs and a foot.
    wood = flat_material("Wood", (150, 95, 55))
    for side in (-1, 1):
        bpy.ops.mesh.primitive_cube_add(size=1, location=(cx + side * 1.2, cy - 0.35, cz / 2))
        leg = bpy.context.active_object
        leg.scale = (0.35, 0.35, cz + 0.6)
        leg.rotation_euler = (0, math.radians(-side * 12), 0)
        leg.data.materials.append(wood)
    bpy.ops.mesh.primitive_cube_add(size=1, location=(cx, cy - 0.35, 0.2))
    foot = bpy.context.active_object
    foot.scale = (3.6, 1.4, 0.4)
    foot.data.materials.append(wood)
    spin = math.radians(-12)  # caught mid-spin
    for i, (rgb, icon) in enumerate(WHEEL):
        a0, a1 = spin + math.radians(i * 45 - 22.5), spin + math.radians(i * 45 + 22.5)
        wedge(r, a0, a1, 0.3, (cx, cy, cz), rgb)
        mid = (a0 + a1) / 2
        ix, iz = cx - math.sin(mid) * r * 0.64, cz + math.cos(mid) * r * 0.64
        if icon == "coin":
            coin((ix, cy + 0.2, iz - 0.4), 0.85, yaw=0, tilt=(90, 0))
        elif icon == "gem":
            gem((ix, cy + 0.2, iz - 0.35), 0.75)
        elif icon == "potion":
            potion((ix, cy + 0.3, iz - 0.4), 0.8)
        else:
            sparkle((ix, cy + 0.3, iz), 0.6, (255, 230, 90), 8.0)
            gem((ix - 0.25, cy + 0.35, iz - 0.45), 0.5)
            potion((ix + 0.3, cy + 0.35, iz - 0.45), 0.5)
    # Gold rim, hub and 16 lights.
    bpy.ops.mesh.primitive_torus_add(major_radius=r + 0.1, minor_radius=0.24, major_segments=64, minor_segments=10,
                                     location=(cx, cy, cz), rotation=(math.radians(90), 0, 0))
    bpy.context.active_object.data.materials.append(flat_material("Rim", (255, 195, 40)))
    bpy.ops.mesh.primitive_cylinder_add(vertices=32, radius=0.42, depth=0.5, location=(cx, cy + 0.1, cz), rotation=(math.radians(90), 0, 0))
    bpy.context.active_object.data.materials.append(flat_material("Hub", (255, 215, 80), emission=0.5))
    for k in range(16):
        a = math.radians(k * 22.5)
        bpy.ops.mesh.primitive_uv_sphere_add(segments=12, ring_count=8, radius=0.13,
                                             location=(cx - math.sin(a) * (r + 0.1), cy + 0.2, cz + math.cos(a) * (r + 0.1)))
        bpy.context.active_object.data.materials.append(flat_material("Bulb", (255, 245, 200), emission=6.0))
    # Pointer at the top.
    bpy.ops.mesh.primitive_cone_add(vertices=3, radius1=0.45, depth=0.9, location=(cx, cy + 0.25, cz + r + 0.35), rotation=(0, math.radians(180), 0))
    bpy.context.active_object.data.materials.append(flat_material("Pointer", (230, 50, 40)))
    # A pet cheering next to the wheel and prizes flying out.
    place(pet("TomatoCat"), 0, (cx + 3.9, 1.6, 0), yaw=-30, height=1.7)
    place(pet("CottonCandyUnicorn"), 0, (cx - 4.3, 1.4, 0), yaw=30, height=1.7)
    rnd = random.Random(98)
    for i in range(6):
        coin((cx + rnd.uniform(-4.8, 4.8), cy + rnd.uniform(0.8, 2.2), rnd.uniform(1.0, 6.5)), 0.55, yaw=rnd.uniform(-60, 60),
             tilt=(rnd.uniform(60, 90), rnd.uniform(-25, 25)))
    for i in range(4):
        gem((cx + rnd.uniform(-4.5, 4.5), cy + rnd.uniform(0.8, 2.2), rnd.uniform(0.8, 6.0)), 0.45, yaw=i * 30)
    sparkles(random.Random(97), 18, ((cx - 4.8, 0.5, 1.0), (cx + 4.8, 2.0, 7.2)))
    OVERLAY["quests"] = True
    look_at((-0.2, 16.0, 4.6), (-0.2, -0.5, 4.4), 30)


BUILDERS = {"icon": shot_icon, "pets": shot_pets, "atlantis": shot_atlantis, "paradise": shot_paradise, "wheel": shot_wheel}

# ---------------------------------------------------------------- text overlay


def _font(size):
    from PIL import ImageFont

    font = ImageFont.truetype(FONT, size)
    font.set_variation_by_name("Bold")
    return font


def outlined(draw, xy, text, font, fill, stroke, anchor="ma", shadow=True):
    x, y = xy
    if shadow:
        draw.text((x + stroke, y + stroke * 1.5), text, font=font, anchor=anchor, fill=DARK, stroke_width=stroke, stroke_fill=DARK)
    draw.text((x, y), text, font=font, anchor=anchor, fill=fill, stroke_width=stroke, stroke_fill=DARK)


def pill(draw, xy, text, font, fill, h, anchor="ma"):
    x, y = xy
    stroke = max(2, int(h * 0.006))
    box = draw.textbbox((x, y), text, font=font, anchor=anchor)
    pad = int(h * 0.016)
    draw.rounded_rectangle((box[0] - pad * 2, box[1] - pad, box[2] + pad * 2, box[3] + pad), radius=int(h * 0.03),
                           fill=fill, outline=DARK, width=stroke)
    draw.text((x, y), text, font=font, anchor=anchor, fill=CREAM, stroke_width=max(1, stroke - 1), stroke_fill=DARK)


def starburst(draw, center, radius, text, font):
    cx, cy = center
    pts = []
    for k in range(32):
        a = math.pi * 2 * k / 32 - math.pi / 2
        rr = radius if k % 2 == 0 else radius * 0.78
        pts.append((cx + math.cos(a) * rr, cy + math.sin(a) * rr))
    draw.polygon(pts, fill=RED, outline=DARK, width=max(3, int(radius * 0.06)))
    draw.text((cx, cy), text, font=font, anchor="mm", fill=CREAM, stroke_width=max(2, int(radius * 0.05)), stroke_fill=DARK)


def quest_board(draw, img, lang):
    w, h = img.size
    title, rows = QUESTS[lang]
    x0, y0, x1 = int(w * 0.655), int(h * 0.34), int(w * 0.965)
    row_h = int(h * 0.135)
    y1 = y0 + int(h * 0.11) + row_h * len(rows) + int(h * 0.02)
    draw.rounded_rectangle((x0 + 8, y0 + 10, x1 + 8, y1 + 10), radius=int(h * 0.035), fill=DARK)
    draw.rounded_rectangle((x0, y0, x1, y1), radius=int(h * 0.035), fill=CREAM, outline=DARK, width=6)
    # Header strip with a scroll icon.
    draw.rounded_rectangle((x0, y0, x1, y0 + int(h * 0.09)), radius=int(h * 0.035), fill=ORANGE, outline=DARK, width=6)
    outlined(draw, ((x0 + x1) / 2, y0 + int(h * 0.045)), title, _font(int(h * 0.055)), CREAM, 4, anchor="mm", shadow=False)
    font = _font(int(h * 0.036))
    progress = (1.0, 0.7, 0.35)
    for k, label in enumerate(rows):
        ry = y0 + int(h * 0.11) + row_h * k
        draw.text((x0 + int(w * 0.018), ry), label, font=font, anchor="la", fill=DARK)
        bx0, by0 = x0 + int(w * 0.018), ry + int(h * 0.055)
        bx1, by1 = x1 - int(w * 0.06), by0 + int(h * 0.04)
        draw.rounded_rectangle((bx0, by0, bx1, by1), radius=int(h * 0.02), fill=(225, 210, 185), outline=DARK, width=4)
        fill_x = bx0 + (bx1 - bx0) * progress[k]
        if progress[k] > 0.06:
            draw.rounded_rectangle((bx0, by0, fill_x, by1), radius=int(h * 0.02), fill=GREEN, outline=DARK, width=4)
        # Done mark (a drawn tick) or a small gift box on the right.
        mx, my = x1 - int(w * 0.03), (by0 + by1) / 2
        rr = int(h * 0.026)
        if progress[k] >= 1.0:
            draw.ellipse((mx - rr, my - rr, mx + rr, my + rr), fill=GREEN, outline=DARK, width=4)
            draw.line([(mx - rr * 0.5, my), (mx - rr * 0.1, my + rr * 0.45), (mx + rr * 0.55, my - rr * 0.45)], fill=CREAM, width=7)
        else:
            draw.rectangle((mx - rr, my - rr * 0.7, mx + rr, my + rr), fill=RED, outline=DARK, width=4)
            draw.rectangle((mx - rr * 0.2, my - rr * 0.7, mx + rr * 0.2, my + rr), fill=COIN)


def compose(raw, out, lang, subtitle):
    from PIL import Image, ImageDraw, ImageEnhance

    img = Image.open(raw).convert("RGB")
    img = ImageEnhance.Contrast(ImageEnhance.Color(img).enhance(1.25)).enhance(1.12)
    w, h = img.size
    draw = ImageDraw.Draw(img)
    if subtitle is None:
        # Icon: MEGA UPDATE banner at the bottom (the same in both languages).
        band = (int(w * 0.04), int(h * 0.74), int(w * 0.96), int(h * 0.95))
        draw.rounded_rectangle((band[0] + 5, band[1] + 7, band[2] + 5, band[3] + 7), radius=int(h * 0.05), fill=DARK)
        draw.rounded_rectangle(band, radius=int(h * 0.05), fill=RED, outline=DARK, width=7)
        outlined(draw, (w / 2, (band[1] + band[3]) / 2 - 2), BIG, _font(int(h * 0.125)), COIN, 6, anchor="mm", shadow=False)
    else:
        outlined(draw, (w / 2, int(h * 0.025)), GAME, _font(int(h * 0.05)), CREAM, max(2, int(h * 0.006)))
        outlined(draw, (w / 2, int(h * 0.075)), BIG, _font(int(h * 0.13)), COIN, max(3, int(h * 0.013)))
        pill(draw, (w / 2, int(h * 0.225)), subtitle, _font(int(h * 0.05)), ORANGE, h)
        starburst(draw, (int(w * 0.085), int(h * 0.15)), int(h * 0.105), NEW[lang], _font(int(h * 0.05)))
        if OVERLAY.get("quests"):
            quest_board(draw, img, lang)
    img.save(out)


# ---------------------------------------------------------------- main


def render_shot(shot, preview):
    name, size, samples, subtitles = SHOTS[shot]
    BUILDERS[shot]()
    scene = bpy.context.scene
    scale = float(os.environ.get("STORE_PREVIEW_SCALE", "0.25")) if preview else 1.0
    scene.render.resolution_x, scene.render.resolution_y = int(size[0] * scale), int(size[1] * scale)
    scene.cycles.samples = 12 if preview else samples
    scene.render.image_settings.file_format = "PNG"
    os.makedirs(RAW_DIR, exist_ok=True)
    raw = os.path.join(RAW_DIR, f"{name}.png")
    scene.render.filepath = raw
    bpy.ops.render.render(write_still=True)
    out_dir = PREVIEW_DIR if preview else OUT_DIR
    os.makedirs(out_dir, exist_ok=True)
    if subtitles is None:
        compose(raw, os.path.join(out_dir, f"{name}.png"), "en", None)
    else:
        for lang, subtitle in subtitles.items():
            compose(raw, os.path.join(out_dir, f"{name}_{lang}.png"), lang, subtitle)
    print(f"rendered {shot} -> {out_dir}/{name}")


if __name__ == "__main__":
    args = sys.argv[1:]
    preview = "--preview" in args
    shots = [a for a in args if a in SHOTS] or list(SHOTS)
    if len(shots) == 1:
        render_shot(shots[0], preview)
    else:
        for s in shots:
            subprocess.run([sys.executable, __file__, s] + (["--preview"] if preview else []), check=True)
