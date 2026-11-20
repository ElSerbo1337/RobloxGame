"""Renders the Roblox store images (#61): game icon and three thumbnails.

    lune run export-islands build/islands.json          (only needed for "islands" and "collect")
    python tools/blender/render_store.py [shot ...] [--preview]

Shots: icon (512 x 512), collect, islands, pets (1920 x 1080 each). Without shot names all
four are rendered. --preview renders at a quarter of the size with few samples, for a quick
look at the framing (STORE_PREVIEW_SCALE=0.5 for a bigger preview). Writes docs/store/<File>.png (preview: build/store/<File>.png).

Everything is built from the repo's own Blender builders (build_models, build_pets,
build_eggs, build_toppings, build_currency) and the island plan, in the shared day look of
#45 (render_islands.setup). The title on the thumbnails is drawn afterwards with Pillow in
the UI font (tools/fonts/Fredoka.ttf, SIL OFL, see tools/fonts/OFL.txt) and the UI colours
of docs/ui-style.md. Each shot runs in its own Blender process (the builders keep material
caches per scene).
"""

import json
import math
import os
import subprocess
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import bpy  # noqa: E402,I001
from mathutils import Matrix, Vector  # noqa: E402

import build_currency as bc  # noqa: E402
import build_eggs as be  # noqa: E402
import build_models as bmod  # noqa: E402
import build_pets as bp  # noqa: E402
import build_toppings as bt  # noqa: E402
import render_islands as ri  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT_DIR = os.path.join(ROOT, "docs", "store")
PREVIEW_DIR = os.path.join(ROOT, "build", "store")
RAW_DIR = os.path.join(ROOT, "build", "store", "raw")
FONT = os.path.join(ROOT, "tools", "fonts", "Fredoka.ttf")
ISLANDS = os.path.join(ROOT, "build", "islands.json")

TITLE = "PIZZA TOPPING SIMULATOR"
CREAM = (255, 248, 230)
DARK = (60, 35, 20)
COIN = (255, 200, 40)
ORANGE = (240, 130, 60)

# Shot -> (output file, size, samples, title, subtitle)
SHOTS = {
    "icon": ("Icon", (512, 512), 96, None, None),
    "collect": ("Thumbnail1_Collect", (1920, 1080), 64, TITLE, "Collect · Bake · Sell"),
    "islands": ("Thumbnail2_Islands", (1920, 1080), 64, TITLE, "Unlock 7 Worlds"),
    "pets": ("Thumbnail3_Pets", (1920, 1080), 64, TITLE, "Hatch 70 Pets"),
}


# Labels drawn over the picture in the UI style: (Blender point, text), set by a shot.
LABELS = []

# ---------------------------------------------------------------- placing models


def grab(builder):
    """Runs a builder and returns the mesh objects it added."""
    before = set(bpy.context.scene.objects)
    builder()
    bpy.context.view_layer.update()
    return [o for o in bpy.context.scene.objects if o not in before and o.type == "MESH"]


def place(objs, width, location, yaw=0.0, tilt=(0.0, 0.0), height=None):
    """Scales the objects so their widest horizontal side is `width` (or their height is
    `height`), puts their bottom center at `location` and turns them by `yaw` (degrees,
    around Z; the models' front is +Y). `tilt` = (x, y) degrees after the yaw."""
    lo, hi = bmod.scene_bounds(objs)
    k = height / (hi.z - lo.z) if height else width / max(hi.x - lo.x, hi.y - lo.y)
    pivot = Vector(((lo.x + hi.x) / 2, (lo.y + hi.y) / 2, lo.z))
    m = (
        Matrix.Translation(Vector(location))
        @ Matrix.Rotation(math.radians(tilt[0]), 4, "X")
        @ Matrix.Rotation(math.radians(tilt[1]), 4, "Y")
        @ Matrix.Rotation(math.radians(yaw), 4, "Z")
        @ Matrix.Scale(k, 4)
        @ Matrix.Translation(-pivot)
    )
    for o in objs:
        o.matrix_world = m @ o.matrix_world
    bpy.context.view_layer.update()
    return objs


def pet(name):
    def build():
        P = bp.Pet()
        bp.PETS[name](P)
        P.finish()

    return grab(build)


def egg(egg_id, looks):
    return grab(lambda: be.build_egg(looks[egg_id]))


def egg_stand(accent):
    objs = grab(be.build_stand)
    tint(objs, "StandTrim", accent)
    return objs


def tint(objs, part, hex_color):
    """Gives the named part its own material copy in `hex_color` (like the game's tinting)."""
    for o in objs:
        if o.name.startswith(part):
            mat = o.data.materials[0].copy()
            rgba = be.rgba(be.hex_rgb(hex_color))
            mat.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = rgba
            o.data.materials[0] = mat


def topping(name):
    if name in bt.MODELS:
        return grab(lambda: bt.build(name))
    return grab(bmod.MODELS[name])


def flat_material(name, rgb, emission=0.0, alpha=1.0):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    color = (ri.lin(rgb[0]), ri.lin(rgb[1]), ri.lin(rgb[2]), 1)
    bsdf.inputs["Base Color"].default_value = color
    bsdf.inputs["Roughness"].default_value = 0.7
    if emission:
        bsdf.inputs["Emission Color"].default_value = color
        bsdf.inputs["Emission Strength"].default_value = emission
    bsdf.inputs["Alpha"].default_value = alpha
    return mat


def disk(radius, depth, location, rgb, emission=0.0, verts=48, alpha=1.0):
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=radius, depth=depth, location=location)
    obj = bpy.context.active_object
    obj.data.materials.append(flat_material("Disk", rgb, emission, alpha))
    return obj


def ring(radius, thickness, location, rgb, emission=0.0):
    bpy.ops.mesh.primitive_torus_add(major_radius=radius, minor_radius=thickness, major_segments=48, minor_segments=8, location=location)
    obj = bpy.context.active_object
    obj.scale = (1, 1, 0.35)
    obj.data.materials.append(flat_material("Ring", rgb, emission))
    return obj


def text3d(body, size, location, rotation, rgb, emission=0.0, extrude=0.02):
    bpy.ops.object.text_add(location=location, rotation=rotation)
    obj = bpy.context.active_object
    obj.data.body = body
    obj.data.font = bpy.data.fonts.load(FONT)
    obj.data.size = size
    obj.data.extrude = extrude
    obj.data.align_x = "CENTER"
    obj.data.align_y = "CENTER"
    obj.data.materials.append(flat_material("Text", rgb, emission))
    return obj


def look_at(eye, target, lens):
    bpy.ops.object.camera_add(location=eye)
    cam = bpy.context.active_object
    cam.data.lens = lens
    cam.data.clip_end = 5000
    cam.rotation_euler = (Vector(target) - Vector(eye)).to_track_quat("-Z", "Y").to_euler()
    bpy.context.scene.camera = cam
    return cam


def sky(bottom, top, low=0.45, high=0.75):
    """Vertical sky gradient, like render_islands.setup."""
    nodes = bpy.context.scene.world.node_tree.nodes
    ramp = next(n for n in nodes if n.type == "VALTORGB")
    ramp.color_ramp.elements[0].position = low
    ramp.color_ramp.elements[0].color = (*(ri.lin(c) for c in bottom), 1)
    ramp.color_ramp.elements[1].position = high
    ramp.color_ramp.elements[1].color = (*(ri.lin(c) for c in top), 1)


def ground(rgb, size=400):
    bpy.ops.mesh.primitive_plane_add(size=size, location=(0, 0, 0))
    bpy.context.active_object.data.materials.append(flat_material("Ground", rgb))


def coin(location, width, yaw=0.0, tilt=(70.0, 0.0)):
    return place(grab(lambda: bc.build("Coin")), width, location, yaw, tilt)


def gem(location, width, yaw=0.0):
    return place(grab(lambda: bc.build("Gem")), width, location, yaw)


def loaded_pizza(width, location, yaw=0.0, tilt=(0.0, 0.0), toppings=("Salami", "Mushroom", "Mozzarella")):
    """The game's pizza with world 1 toppings on top, as one group."""
    objs = grab(bmod.build_pizza)
    spots = [(0.0, 0.0), (0.45, 0.2), (-0.4, 0.3), (0.1, -0.5), (-0.35, -0.35), (0.5, -0.25), (-0.05, 0.55), (0.32, 0.5), (-0.6, -0.02)]
    for i, (x, y) in enumerate(spots):
        name = toppings[i % len(toppings)]
        objs += place(topping(name), 0.42 if name != "Mozzarella" else 0.36, (x, y, 0.19), yaw=i * 47)
    return place(objs, width, location, yaw, tilt)


# ---------------------------------------------------------------- shots


def shot_icon():
    """Pizza dragon with a loaded pizza in front of the dome oven."""
    bmod.reset_scene()
    ri.setup((512, 512))
    sky((200, 230, 255), (90, 160, 245), 0.48, 0.6)
    ground((110, 200, 90))
    disk(3.6, 0.08, (0, -1.6, 0.04), (240, 220, 180))
    place(grab(bmod.build_oven), 4.6, (0.6, -3.2, 0.08), yaw=-8)
    place(pet("PizzaDragon"), 0, (-1.1, 0.2, 0.08), yaw=22, height=3.3)
    loaded_pizza(2.7, (0.75, 2.2, 0.35), yaw=-15, tilt=(-22, 0), toppings=("Salami", "Mushroom"))
    coin((2.45, -0.6, 3.6), 0.85, yaw=-30, tilt=(80, 12))
    coin((-2.45, -1.2, 3.9), 0.7, yaw=30, tilt=(75, -15))
    look_at((0.2, 8.6, 4.6), (0.1, -0.2, 1.5), 44)


def remove_sell_box():
    for o in list(bpy.context.scene.objects):
        if o.type == "MESH" and o.data.materials and o.data.materials[0].name.startswith("ForceField"):
            bpy.data.objects.remove(o)


def to_b(x, y, z):
    return ri.to_blender(x, y, z)


def shot_collect():
    """World 1: topping field in front, player with a pizza, glowing sell marking at the oven."""
    with open(ISLANDS) as f:
        data = json.load(f)
    data["islands"] = [i for i in data["islands"] if i.get("worldIndex") == 1]
    data["bridges"], data["gates"] = [], []
    ri.build_scene(data, ())
    remove_sell_box()
    ri.setup((1920, 1080))
    gy = data["config"]["groundY"]
    st = data["islands"][0]["stations"]
    ox, oz = st["Oven"]["position"][0], st["Oven"]["position"][2]
    # Sell marking as GroundMarker builds it: 14 x 10 plate 9.5 studs in front of the oven's
    # mouth (the oven faces -X here), neon rim, the word on top.
    sx, sz = ox - 9.5, oz
    bpy.ops.mesh.primitive_cube_add(size=1, location=to_b(sx, gy + 0.1, sz))
    rim = bpy.context.active_object
    rim.scale = (10.6, 14.6, 0.2)
    rim.data.materials.append(flat_material("SellRim", (255, 150, 40), emission=3.0))
    bpy.ops.mesh.primitive_cube_add(size=1, location=to_b(sx, gy + 0.15, sz))
    plate = bpy.context.active_object
    plate.scale = (9.4, 13.4, 0.22)
    plate.data.materials.append(flat_material("SellPlate", (255, 200, 90), emission=1.0))
    # The word turned towards the camera (it looks along +Z), so it reads in the picture.
    text3d("VERKAUFEN", 1.8, to_b(sx, gy + 0.3, sz), (0, 0, math.pi), CREAM, emission=0.6, extrude=0.1)
    # Seen from the field the word on the floor is tiny, so the picture also gets a label.
    LABELS.append((to_b(sx, gy + 5, sz), "SELL"))
    # Toppings on the field (field centre z = -25, the camera looks from +X/+Z).
    import random

    rnd = random.Random(61)
    names = ["Salami"] * 6 + ["Mushroom"] * 4 + ["Mozzarella"] * 2
    for i in range(110):
        x = rnd.uniform(-35, 50)
        z = rnd.uniform(0, 24)
        name = names[i % len(names)]
        place(topping(name), 2.4 if name != "Mozzarella" else 2.0, to_b(x, gy, z), yaw=rnd.uniform(0, 360))
    # Player in front of the sell marking, holding a loaded pizza over the head.
    px, pz = 12, 36
    ri.avatar((px, gy, pz), math.radians(-60))
    loaded_pizza(4.4, to_b(px, gy + 5.4, pz), yaw=10, tilt=(-32, 0))
    # A pet following the player.
    place(pet("TomatoCat"), 0, to_b(px - 4.0, gy, pz + 1.0), yaw=-150, height=3.4)
    # Coins popping out of the oven.
    for i, (dx, dy, dz) in enumerate(((-3, 9, 2), (-6, 11, -2), (-1, 12, -4), (-8, 8, 3))):
        coin(to_b(ox + dx, gy + dy, oz + dz), 1.8, yaw=i * 40 - 60, tilt=(80, 10))
    look_at(to_b(-25, 30, -60), to_b(20, 2, 66), 55)


def shot_islands():
    """The island chain, spawn island in front, volcano and space at the back."""
    with open(ISLANDS) as f:
        data = json.load(f)
    ri.build_scene(data, ())
    ri.setup((1920, 1080))
    look_at(to_b(900, 520, 260), to_b(-40, -10, -540), 36)


def shot_pets():
    """Egg stands in a row, pets in front, the mythic dragon highlighted in the middle."""
    bmod.reset_scene()
    ri.setup((1920, 1080))
    sky((255, 236, 200), (150, 200, 250), 0.45, 0.7)
    ground((110, 200, 90))
    looks = be.read_looks()
    stands = [("GardenEgg", -6.6), ("SpaceEgg", -3.3), ("VolcanoEgg", 3.3), ("CandyEgg", 6.6)]
    for egg_id, x in stands:
        look = looks[egg_id]
        place(egg_stand(look["accent"]), 3.0, (x, -6.0, 0), yaw=0)
        place(egg(egg_id, looks), 1.75, (x, -6.0, 0.67), yaw=-15 if x < 0 else 15)
    # Fancy egg behind the dragon.
    place(egg_stand(looks["NebulaEgg"]["accent"]), 3.4, (0, -8.0, 0), yaw=0)
    place(egg("NebulaEgg", looks), 2.0, (0, -8.0, 0.76))
    row = [("DoughHamster", -6.3, 1.6, 25), ("TomatoCat", -4.6, 1.8, 15), ("CottonCandyUnicorn", -2.5, 1.9, 8),
           ("FrostPhoenix", 2.6, 2.0, -8), ("OliveOwl", 4.7, 1.8, -15), ("StoneOvenPhoenix", 6.3, 1.8, -25)]
    for name, x, h, yaw in row:
        place(pet(name), 0, (x, -0.8 + abs(x) * 0.12, 0), yaw=yaw, height=h)
    # The rare one: golden platform with a glowing ring and gems around it.
    disk(1.9, 0.3, (0, 0.4, 0.15), (255, 200, 40), emission=0.4)
    ring(2.05, 0.14, (0, 0.4, 0.32), (255, 230, 120), emission=4.0)
    place(pet("GalaxyDragon"), 0, (0, 0.4, 0.3), yaw=0, height=3.4)
    for i, (x, y) in enumerate(((-2.3, 1.9), (2.3, 1.9), (-1.2, 2.9), (1.2, 2.9))):
        gem((x, y, 0.05), 0.5, yaw=i * 35)
    bpy.ops.object.light_add(type="POINT", location=(0, 4.5, 5.5))
    light = bpy.context.active_object
    light.data.energy = 300
    light.data.color = (1.0, 0.85, 0.5)
    look_at((0, 11.5, 3.6), (0, -1.6, 1.5), 28)


BUILDERS = {"icon": shot_icon, "collect": shot_collect, "islands": shot_islands, "pets": shot_pets}


# ---------------------------------------------------------------- title overlay


def draw_title(path_in, path_out, title, subtitle, labels=()):
    from PIL import Image, ImageDraw, ImageEnhance, ImageFont

    img = Image.open(path_in).convert("RGB")
    # A bit more punch, like the game's colour correction.
    img = ImageEnhance.Contrast(ImageEnhance.Color(img).enhance(1.25)).enhance(1.12)
    if title:
        w, h = img.size
        draw = ImageDraw.Draw(img)
        big = ImageFont.truetype(FONT, int(h * 0.11))
        big.set_variation_by_name("Bold")
        small = ImageFont.truetype(FONT, int(h * 0.05))
        small.set_variation_by_name("Bold")
        stroke = max(2, int(h * 0.012))
        y = int(h * 0.04)
        # Soft shadow, then the title in coin yellow with a dark outline.
        draw.text((w / 2 + stroke, y + stroke * 1.5), title, font=big, anchor="ma", fill=DARK, stroke_width=stroke, stroke_fill=DARK)
        draw.text((w / 2, y), title, font=big, anchor="ma", fill=COIN, stroke_width=stroke, stroke_fill=DARK)
        if subtitle:
            sy = y + int(h * 0.135)
            box = draw.textbbox((w / 2, sy), subtitle, font=small, anchor="ma")
            pad = int(h * 0.015)
            draw.rounded_rectangle((box[0] - pad * 2, box[1] - pad, box[2] + pad * 2, box[3] + pad), radius=int(h * 0.03),
                                   fill=ORANGE, outline=DARK, width=max(2, stroke // 2))
            draw.text((w / 2, sy), subtitle, font=small, anchor="ma", fill=CREAM, stroke_width=max(1, stroke // 3), stroke_fill=DARK)
    draw = ImageDraw.Draw(img)
    for x, y, text in labels:
        h = img.size[1]
        font = ImageFont.truetype(FONT, int(h * 0.045))
        font.set_variation_by_name("Bold")
        box = draw.textbbox((x, y), text, font=font, anchor="mb")
        pad = int(h * 0.014)
        tip = int(h * 0.025)
        rect = (box[0] - pad * 2, box[1] - pad, box[2] + pad * 2, box[3] + pad)
        draw.polygon([(x - tip, rect[3] - 2), (x + tip, rect[3] - 2), (x, rect[3] + tip)], fill=COIN, outline=DARK, width=4)
        draw.rounded_rectangle(rect, radius=int(h * 0.025), fill=COIN, outline=DARK, width=4)
        draw.text((x, y), text, font=font, anchor="mb", fill=CREAM, stroke_width=3, stroke_fill=DARK)
    img.save(path_out)


# ---------------------------------------------------------------- main


def render_shot(shot, preview):
    name, size, samples, title, subtitle = SHOTS[shot]
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
    from bpy_extras.object_utils import world_to_camera_view

    w, h = size
    labels = []
    for point, text in LABELS:
        u, v, _ = world_to_camera_view(scene, scene.camera, point)
        labels.append((u * w, (1 - v) * h, text))
    if preview:
        labels = [(x * scale, y * scale, t) for x, y, t in labels]
    draw_title(raw, os.path.join(out_dir, f"{name}.png"), title, subtitle, labels)
    print(f"rendered {shot} -> {out_dir}/{name}.png")


if __name__ == "__main__":
    args = sys.argv[1:]
    preview = "--preview" in args
    shots = [a for a in args if a in SHOTS] or list(SHOTS)
    if len(shots) == 1:
        render_shot(shots[0], preview)
    else:
        for s in shots:
            subprocess.run([sys.executable, __file__, s] + (["--preview"] if preview else []), check=True)
