"""Builds the low-poly cartoon models for world 1 and renders preview images.

Run headless (bpy from pip, Python 3.13):
    python tools/blender/build_models.py [asset-name ...]

Writes assets/models/<Name>.fbx and assets/previews/<Name>.png (plus Overview.png).
Every model is built from separately named mesh parts with exactly one colour each.
The Roblox side (src/shared/ModelLibrary.luau) recolours the imported MeshParts by
these part names, so the look never depends on how Studio imports the materials.
Keep part names and colours in sync with PALETTE in ModelLibrary.luau.
"""

import math
import os
import sys

import bpy  # noqa: I001  (bpy must be imported before bmesh)
import bmesh
from mathutils import Vector

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
MODEL_DIR = os.path.join(ROOT, "assets", "models")
PREVIEW_DIR = os.path.join(ROOT, "assets", "previews")


def rgb(r, g, b):
    # sRGB 0..255 -> linear 0..1 for Blender materials
    def lin(c):
        c = c / 255
        return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4

    return (lin(r), lin(g), lin(b), 1.0)


# Part name -> colour. Same values as ModelLibrary.PALETTE (Roblox side).
COLORS = {
    "Meat": (190, 38, 42),
    "Fat": (255, 196, 186),
    "Cap": (214, 168, 120),
    "Stem": (252, 242, 222),
    "Cheese": (255, 250, 236),
    "Dough": (240, 190, 105),
    "Crust": (214, 140, 60),
    "Sauce": (214, 52, 34),
    "Melt": (255, 214, 92),
    "Stone": (186, 176, 166),
    "Dome": (226, 112, 62),
    "Mouth": (52, 26, 18),
    "Glow": (255, 150, 40),
    "Chimney": (150, 78, 58),
    "Wood": (150, 96, 52),
    "Leaves": (96, 196, 82),
    "LeavesLight": (140, 220, 96),
    "Berry": (235, 60, 70),
    "Basil": (60, 160, 60),
    # Worlds 2-7 (#16)
    "Hay": (232, 196, 96),
    "Twine": (176, 128, 60),
    "Petal": (255, 206, 40),
    "Seed": (110, 70, 35),
    "BarnRed": (204, 62, 52),
    "Trim": (250, 246, 236),
    "Roof": (92, 72, 64),
    "PalmTrunk": (196, 150, 92),
    "PalmLeaf": (64, 182, 84),
    "Coconut": (120, 80, 45),
    "Canvas": (240, 84, 84),
    "Pine": (44, 128, 96),
    "Snow": (246, 250, 255),
    "Ice": (150, 214, 255),
    "Coal": (42, 42, 48),
    "Carrot": (255, 140, 40),
    "Basalt": (78, 62, 60),
    "Lava": (255, 112, 30),
    "Charcoal": (58, 46, 46),
    "CandyPink": (255, 92, 162),
    "CandyWhite": (255, 246, 250),
    "CandyRed": (232, 42, 62),
    "Wrapper": (120, 200, 242),
    "Frosting": (255, 182, 216),
    "MoonRock": (152, 152, 168),
    "Crater": (112, 112, 128),
    "PlanetBody": (150, 110, 232),
    "PlanetRing": (255, 202, 120),
    "Crystal": (110, 255, 212),
    "Hull": (240, 240, 246),
    "Fin": (232, 62, 62),
}

# Parts with these colours glow (Neon in Roblox) or are see-through (Glass).
GLOWING = {"Glow", "Lava", "Crystal"}
GLASSY = {"Ice"}

_materials = {}


def material(name):
    if name in _materials:
        return _materials[name]
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = rgb(*COLORS[name])
    bsdf.inputs["Roughness"].default_value = 0.7
    if name in GLASSY:
        bsdf.inputs["Roughness"].default_value = 0.1
        bsdf.inputs["Alpha"].default_value = 0.6
    if name in GLOWING:
        bsdf.inputs["Emission Color"].default_value = rgb(*COLORS[name])
        bsdf.inputs["Emission Strength"].default_value = 4.0
    mat.diffuse_color = rgb(*COLORS[name])
    _materials[name] = mat
    return mat


def reset_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    _materials.clear()


def finish(obj, color, name=None):
    """Applies transforms, flat shading and the single colour material."""
    obj.name = name or color
    obj.data.name = obj.name
    bpy.context.view_layer.objects.active = obj
    for o in bpy.context.selected_objects:
        o.select_set(False)
    obj.select_set(True)
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    for poly in obj.data.polygons:
        poly.use_smooth = False
    obj.data.materials.clear()
    obj.data.materials.append(material(color))
    return obj


def join(objs, color, name=None):
    for o in bpy.context.selected_objects:
        o.select_set(False)
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    if len(objs) > 1:
        bpy.ops.object.join()
    return finish(bpy.context.view_layer.objects.active, color, name)


def cylinder(radius, depth, verts, loc=(0, 0, 0), rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=radius, depth=depth, location=loc, rotation=rot)
    return bpy.context.active_object


def ico(radius, subdiv, loc=(0, 0, 0), scale=(1, 1, 1)):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=subdiv, radius=radius, location=loc)
    obj = bpy.context.active_object
    obj.scale = scale
    return obj


def uv_sphere(radius, segments, rings, loc=(0, 0, 0), scale=(1, 1, 1)):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments, ring_count=rings, radius=radius, location=loc)
    obj = bpy.context.active_object
    obj.scale = scale
    return obj


def cut_below(obj, z):
    """Removes the part of a mesh below height z (in object space after transforms)."""
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bmesh.ops.bisect_plane(
        bm,
        geom=bm.verts[:] + bm.edges[:] + bm.faces[:],
        plane_co=Vector((0, 0, z)),
        plane_no=Vector((0, 0, 1)),
        clear_inner=True,
    )
    edges = [e for e in bm.edges if e.is_boundary]
    if edges:
        bmesh.ops.holes_fill(bm, edges=edges)
    bm.to_mesh(obj.data)
    bm.free()
    return obj


def jitter(obj, amount, seed):
    """Moves vertices a little for a hand-made low-poly look (deterministic)."""
    import random

    rnd = random.Random(seed)
    for v in obj.data.vertices:
        v.co += Vector((rnd.uniform(-amount, amount), rnd.uniform(-amount, amount), rnd.uniform(-amount, amount)))


# ---------------------------------------------------------------- models
# Sizes in Blender units; Roblox scales every model to its target size anyway.


def build_salami():
    meat = cylinder(1.0, 0.22, 14, loc=(0, 0, 0.11))
    bpy.ops.object.modifier_add(type="BEVEL")
    meat.modifiers["Bevel"].width = 0.06
    meat.modifiers["Bevel"].segments = 1
    bpy.ops.object.modifier_apply(modifier="Bevel")
    finish(meat, "Meat")
    dots = []
    spots = [(0.0, 0.0, 0.16), (0.5, 0.35, 0.13), (-0.45, 0.42, 0.12), (-0.35, -0.5, 0.14), (0.45, -0.38, 0.11), (0.05, 0.7, 0.09), (0.72, -0.02, 0.08), (-0.72, -0.05, 0.1)]
    for x, y, r in spots:
        dots.append(cylinder(r, 0.04, 8, loc=(x, y, 0.235)))
    join(dots, "Fat")


def build_mushroom():
    cap = uv_sphere(0.9, 10, 6, loc=(0, 0, 0.55), scale=(1, 1, 0.75))
    cut_below(cap, 0.75)
    jitter(cap, 0.03, 1)
    finish(cap, "Cap")
    stem = cylinder(0.38, 0.85, 8, loc=(0, 0, 0.43))
    bpy.context.view_layer.objects.active = stem
    bm = bmesh.new()
    bm.from_mesh(stem.data)
    for v in bm.verts:  # slightly wider at the bottom
        if v.co.z < 0:
            v.co.x *= 1.2
            v.co.y *= 1.2
    bm.to_mesh(stem.data)
    bm.free()
    finish(stem, "Stem")


def build_mozzarella():
    # Mozzarella balls with a basil leaf on top.
    balls = [
        uv_sphere(0.55, 10, 7, loc=(0, -0.05, 0.42), scale=(1.0, 1.0, 0.78)),
        uv_sphere(0.42, 10, 7, loc=(0.62, 0.32, 0.33), scale=(1.0, 1.0, 0.8)),
        uv_sphere(0.38, 10, 7, loc=(-0.58, 0.38, 0.3), scale=(1.0, 1.0, 0.8)),
    ]
    for i, b in enumerate(balls):
        bpy.context.view_layer.objects.active = b
        bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
        jitter(b, 0.015, 10 + i)
    join(balls, "Cheese")
    leaf = uv_sphere(0.3, 8, 4, loc=(0.05, 0.05, 0.84), scale=(1.0, 0.5, 0.18))
    leaf.rotation_euler = (0.25, 0, 0.6)
    finish(leaf, "Basil")


def build_pizza():
    dough = cylinder(1.0, 0.12, 20, loc=(0, 0, 0.06))
    finish(dough, "Dough")
    bpy.ops.mesh.primitive_torus_add(major_radius=0.95, minor_radius=0.12, major_segments=20, minor_segments=6, location=(0, 0, 0.13))
    crust = bpy.context.active_object
    crust.scale = (1, 1, 0.9)
    jitter(crust, 0.012, 3)
    finish(crust, "Crust")
    sauce = cylinder(0.86, 0.04, 20, loc=(0, 0, 0.13))
    finish(sauce, "Sauce")
    # Melted cheese: one layer with a wavy edge, so sauce peeks out at the rim.
    melt = cylinder(0.74, 0.05, 30, loc=(0, 0, 0.16))
    for v in melt.data.vertices:
        r = math.hypot(v.co.x, v.co.y)
        if r > 0.1:
            angle = math.atan2(v.co.y, v.co.x)
            k = 1 + 0.11 * math.sin(5 * angle) + 0.05 * math.sin(11 * angle + 1)
            v.co.x *= k
            v.co.y *= k
    finish(melt, "Melt")


def build_oven():
    # Classic dome pizza oven. The mouth faces Blender +Y, which the FBX export
    # turns into Roblox's front (-Z). ModelLibrary has a yaw fix if Studio differs.
    base = cylinder(2.3, 1.6, 10, loc=(0, 0, 0.8))
    jitter(base, 0.04, 20)
    finish(base, "Stone")
    dome = uv_sphere(2.05, 12, 8, loc=(0, 0, 1.6), scale=(1, 1, 0.92))
    cut_below(dome, 1.6)
    jitter(dome, 0.04, 21)
    finish(dome, "Dome")
    # Arch around the mouth
    bpy.ops.mesh.primitive_torus_add(major_radius=0.95, minor_radius=0.2, major_segments=12, minor_segments=5, location=(0, 1.95, 1.7), rotation=(math.pi / 2, 0, 0))
    arch = bpy.context.active_object
    cut_below(arch, 1.55)
    finish(arch, "Chimney", "Arch")
    mouth = cylinder(0.85, 0.2, 12, loc=(0, 1.9, 1.7), rot=(math.pi / 2, 0, 0))
    cut_below(mouth, 1.6)
    finish(mouth, "Mouth")
    glow = cylinder(0.6, 0.1, 10, loc=(0, 1.98, 1.65), rot=(math.pi / 2, 0, 0))
    cut_below(glow, 1.61)
    finish(glow, "Glow")
    chimney = cylinder(0.32, 1.4, 8, loc=(0.6, -0.9, 3.6))
    top = cylinder(0.42, 0.2, 8, loc=(0.6, -0.9, 4.3))
    join([chimney, top], "Chimney")


def build_tree():
    trunk = cylinder(0.28, 2.2, 7, loc=(0, 0, 1.1))
    bm = bmesh.new()
    bm.from_mesh(trunk.data)
    for v in bm.verts:
        if v.co.z > 0:
            v.co.x *= 0.7
            v.co.y *= 0.7
    bm.to_mesh(trunk.data)
    bm.free()
    finish(trunk, "Wood")
    dark = [ico(1.25, 1, loc=(0, 0, 2.8)), ico(0.85, 1, loc=(0.75, 0.3, 2.35))]
    light = [ico(0.95, 1, loc=(-0.55, -0.35, 3.35)), ico(0.75, 1, loc=(0.3, 0.2, 3.75))]
    for i, b in enumerate(dark + light):
        bpy.context.view_layer.objects.active = b
        bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
        jitter(b, 0.08, 30 + i)
    join(dark, "Leaves")
    join(light, "LeavesLight")


def build_bush():
    blobs = [ico(0.75, 1, loc=(0, 0, 0.55)), ico(0.6, 1, loc=(0.7, 0.15, 0.42)), ico(0.55, 1, loc=(-0.65, 0.1, 0.4))]
    for i, b in enumerate(blobs):
        bpy.context.view_layer.objects.active = b
        bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
        jitter(b, 0.06, 40 + i)
        cut_below(b, 0.0)
    join(blobs, "Leaves")
    berries = [ico(0.11, 1, loc=p) for p in [(0.2, 0.72, 0.62), (-0.55, 0.5, 0.55), (0.9, 0.38, 0.45), (-0.1, 0.55, 1.0), (0.5, 0.5, 0.85)]]
    join(berries, "Berry")


def cone(r1, r2, depth, verts, loc=(0, 0, 0), rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=r1, radius2=r2, depth=depth, location=loc, rotation=rot)
    return bpy.context.active_object


def cube(size, loc=(0, 0, 0), rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc, rotation=rot)
    obj = bpy.context.active_object
    obj.scale = size
    return obj


def prism(points, depth):
    """Extrudes a polygon of (x, z) points along Y (centered)."""
    mesh = bpy.data.meshes.new("prism")
    obj = bpy.data.objects.new("prism", mesh)
    bpy.context.collection.objects.link(obj)
    bm = bmesh.new()
    front = [bm.verts.new((x, -depth / 2, z)) for x, z in points]
    back = [bm.verts.new((x, depth / 2, z)) for x, z in points]
    bm.faces.new(front)
    bm.faces.new(list(reversed(back)))
    for i in range(len(points)):
        j = (i + 1) % len(points)
        bm.faces.new([front[i], front[j], back[j], back[i]])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    bm.to_mesh(mesh)
    bm.free()
    return obj


def applied(obj):
    """Applies location/rotation/scale so pieces can be joined safely."""
    for o in bpy.context.selected_objects:
        o.select_set(False)
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    return obj


# ---------------------------------------------------------------- world 2: Bauernhof


def build_hay_bale():
    bale = cylinder(0.75, 1.6, 10, rot=(0, math.pi / 2, 0), loc=(0, 0, 0.75))
    jitter(applied(bale), 0.03, 50)
    finish(bale, "Hay")
    straps = [applied(cylinder(0.77, 0.12, 10, rot=(0, math.pi / 2, 0), loc=(x, 0, 0.75))) for x in (-0.45, 0.45)]
    join(straps, "Twine")


def build_sunflower():
    stem = applied(cylinder(0.07, 2.2, 6, loc=(0, 0, 1.1)))
    leaves = [applied(uv_sphere(0.3, 8, 4, loc=(s * 0.25, 0, 0.9 + i * 0.4), scale=(1, 0.35, 0.12))) for i, s in enumerate((-1, 1))]
    join([stem] + leaves, "Leaves")
    petals = []
    for i in range(12):
        a = i * math.tau / 12
        petal = uv_sphere(0.22, 8, 4, loc=(math.cos(a) * 0.42, 0.05, 2.25 + math.sin(a) * 0.42), scale=(0.5, 0.25, 1))
        petal.rotation_euler = (0, -a + math.pi / 2, 0)
        petals.append(applied(petal))
    join(petals, "Petal")
    seed = cylinder(0.3, 0.16, 12, rot=(math.pi / 2, 0, 0), loc=(0, 0.1, 2.25))
    finish(seed, "Seed")


def build_barn():
    body = cube((4, 3.2, 2.6), loc=(0, 0, 1.3))
    finish(body, "BarnRed")
    roof_l = applied(cube((2.55, 3.5, 0.18), loc=(-1.0, 0, 3.33), rot=(0, math.radians(-33), 0)))
    roof_r = applied(cube((2.55, 3.5, 0.18), loc=(1.0, 0, 3.33), rot=(0, math.radians(33), 0)))
    join([roof_l, roof_r], "Roof")
    finish(prism([(-2, 2.6), (2, 2.6), (0, 3.9)], 3.2), "BarnRed", "Gable")
    trims = [
        applied(cube((1.6, 0.08, 1.8), loc=(0, 1.62, 0.9))),
        applied(cube((0.7, 0.08, 0.7), loc=(0, 1.62, 2.75))),
    ]
    join(trims, "Trim")
    cross = [
        applied(cube((1.9, 0.1, 0.12), loc=(0, 1.68, 0.9), rot=(0, math.radians(43), 0))),
        applied(cube((1.9, 0.1, 0.12), loc=(0, 1.68, 0.9), rot=(0, math.radians(-43), 0))),
    ]
    join(cross, "BarnRed", "DoorCross")


def build_fence():
    posts = [applied(cube((0.18, 0.18, 1.1), loc=(x, 0, 0.55))) for x in (-1.4, 0, 1.4)]
    rails = [applied(cube((3.0, 0.1, 0.16), loc=(0, 0, z))) for z in (0.45, 0.85)]
    join(posts + rails, "Trim")


# ---------------------------------------------------------------- world 3: Strand


def build_palm():
    pieces = []
    for i in range(6):
        t = i / 5
        pieces.append(applied(cylinder(0.24 - t * 0.06, 0.7, 7, loc=(t * t * 0.9, 0, 0.35 + i * 0.62), rot=(0, math.radians(8 + t * 14), 0))))
    join(pieces, "PalmTrunk")
    top = (0.9, 0, 3.9)
    leaves = []
    for i in range(7):
        a = i * math.tau / 7
        leaf = uv_sphere(1.0, 8, 4, loc=(top[0] + math.cos(a) * 0.95, math.sin(a) * 0.95, top[2] - 0.15), scale=(1.1, 0.32, 0.08))
        leaf.rotation_euler = (math.radians(-18) * 0, math.radians(22), a)
        applied(leaf)
        leaves.append(leaf)
    join(leaves, "PalmLeaf")
    nuts = [applied(uv_sphere(0.18, 8, 6, loc=(top[0] + x, y, top[2] - 0.3))) for x, y in ((0.15, 0.1), (-0.12, 0.12), (0.0, -0.17))]
    join(nuts, "Coconut")


def build_umbrella():
    pole = applied(cylinder(0.05, 2.6, 6, loc=(0, 0, 1.3)))
    finish(pole, "Trim", "Pole")
    canopy = applied(cone(1.5, 0.0, 0.6, 12, loc=(0, 0, 2.55)))
    finish(canopy, "Canvas")
    white = [applied(cone(0.45, 0.0, 0.2, 12, loc=(0, 0, 2.78)))]
    for i in range(12):
        a = (i + 0.5) * math.tau / 12
        white.append(applied(uv_sphere(0.16, 8, 5, loc=(math.cos(a) * 1.45, math.sin(a) * 1.45, 2.27), scale=(1, 1, 0.7))))
    join(white, "Trim")


def build_beach_rock():
    rock = ico(1.0, 1, loc=(0, 0, 0.45), scale=(1.2, 0.9, 0.6))
    jitter(applied(rock), 0.1, 60)
    cut_below(rock, 0.0)
    finish(rock, "Stone")


# ---------------------------------------------------------------- world 4: Eisberge


def build_snow_pine():
    trunk = applied(cylinder(0.2, 0.8, 6, loc=(0, 0, 0.4)))
    finish(trunk, "Wood")
    greens, snows = [], []
    for i, (r, z) in enumerate([(1.3, 1.2), (1.0, 2.0), (0.7, 2.7)]):
        greens.append(applied(cone(r, 0.0, 1.3, 8, loc=(0, 0, z))))
        snows.append(applied(cone(r * 0.55, 0.0, 0.6, 8, loc=(0, 0, z + 0.38))))
    join(greens, "Pine")
    join(snows, "Snow")


def build_ice_crystal():
    shards = []
    for i, (x, y, h, tilt) in enumerate([(0, 0, 2.4, 0), (0.45, 0.1, 1.5, 22), (-0.4, 0.15, 1.7, -18), (0.1, -0.4, 1.2, 15)]):
        shard = cylinder(0.32, h, 6, loc=(x, y, h / 2), rot=(math.radians(tilt * 0.5), math.radians(tilt), 0))
        applied(shard)
        tip = cone(0.32, 0.0, 0.5, 6, loc=(x + math.sin(math.radians(tilt)) * h / 2, y, h + 0.2), rot=(math.radians(tilt * 0.5), math.radians(tilt), 0))
        shards += [shard, applied(tip)]
    join(shards, "Ice")


def build_snowman():
    balls = [applied(ico(r, 2, loc=(0, 0, z))) for r, z in ((0.75, 0.7), (0.55, 1.75), (0.4, 2.5))]
    join(balls, "Snow")
    coal = [applied(uv_sphere(0.06, 6, 4, loc=(x, 0.37, z))) for x, z in ((-0.13, 2.6), (0.13, 2.6), (0, 1.85), (0, 1.6))]
    join(coal, "Coal")
    nose = cone(0.08, 0.0, 0.45, 6, loc=(0, 0.55, 2.5), rot=(math.radians(-90), 0, 0))
    finish(applied(nose), "Carrot")
    scarf = applied(cylinder(0.5, 0.16, 10, loc=(0, 0, 2.15)))
    finish(scarf, "Canvas")


# ---------------------------------------------------------------- world 5: Vulkan


def build_volcano():
    mountain = cone(3.2, 0.9, 3.4, 10, loc=(0, 0, 1.7))
    jitter(applied(mountain), 0.12, 70)
    finish(mountain, "Basalt")
    pool = cylinder(0.85, 0.12, 10, loc=(0, 0, 3.38))
    streams = [applied(pool)]
    for i, a in enumerate((0.3, 2.4, 4.4)):
        stream = cube((0.32, 0.14, 3.0), loc=(math.cos(a) * 2.0, math.sin(a) * 2.0, 1.75))
        stream.rotation_euler = (0, math.radians(-34), a)
        streams.append(applied(stream))
    join(streams, "Lava")


def build_lava_rock():
    rock = ico(1.0, 1, loc=(0, 0, 0.55), scale=(1.1, 1.0, 0.75))
    jitter(applied(rock), 0.12, 71)
    cut_below(rock, 0.0)
    finish(rock, "Basalt")
    cracks = [applied(cube((0.12, 0.6, 0.08), loc=(x, y, z), rot=(0.4, 0.2, r))) for x, y, z, r in ((0.3, 0.85, 0.6, 0.2), (-0.4, 0.75, 0.45, -0.5), (0.8, 0.0, 0.5, 1.2))]
    join(cracks, "Lava")


def build_dead_tree():
    parts = [applied(cylinder(0.22, 2.2, 6, loc=(0, 0, 1.1)))]
    for a, z, tilt in ((0.4, 1.6, 40), (2.6, 1.9, 35), (4.5, 1.3, 45)):
        branch = cylinder(0.08, 1.0, 5, loc=(math.cos(a) * 0.35, math.sin(a) * 0.35, z + 0.3))
        branch.rotation_euler = (0, math.radians(tilt), a)
        parts.append(applied(branch))
    join(parts, "Charcoal")


# ---------------------------------------------------------------- world 6: Süßigkeitenland


def build_lollipop():
    stick = applied(cylinder(0.07, 2.4, 6, loc=(0, 0, 1.2)))
    finish(stick, "CandyWhite", "Stick")
    disc = cylinder(0.9, 0.3, 20, loc=(0, 0, 2.9), rot=(math.pi / 2, 0, 0))
    finish(applied(disc), "CandyPink")
    swirl = []
    for i in range(3):
        bpy.ops.mesh.primitive_torus_add(major_radius=0.25 + i * 0.22, minor_radius=0.06, major_segments=16, minor_segments=4, location=(0, 0.16, 2.9), rotation=(math.pi / 2, 0, 0))
        swirl.append(applied(bpy.context.active_object))
    join(swirl, "CandyWhite")


def build_candy_cane():
    reds, whites = [], []
    for i in range(10):
        piece = cylinder(0.16, 0.3, 8, loc=(0, 0, 0.15 + i * 0.3))
        (reds if i % 2 == 0 else whites).append(applied(piece))
    for i in range(7):
        a = math.pi * i / 6
        piece = uv_sphere(0.17, 8, 6, loc=(0.4 - math.cos(a) * 0.4, 0, 3.0 + math.sin(a) * 0.4))
        (reds if i % 2 == 0 else whites).append(applied(piece))
    join(reds, "CandyRed")
    join(whites, "CandyWhite")


def build_cupcake():
    wrap = cone(0.75, 1.0, 1.0, 12, loc=(0, 0, 0.5))
    finish(applied(wrap), "Wrapper")
    frost = [applied(uv_sphere(r, 12, 7, loc=(0, 0, z), scale=(1, 1, 0.6))) for r, z in ((1.05, 1.1), (0.75, 1.45), (0.42, 1.75))]
    join(frost, "Frosting")
    cherry = applied(uv_sphere(0.2, 10, 6, loc=(0, 0, 2.05)))
    finish(cherry, "Berry")


# ---------------------------------------------------------------- world 7: Weltraum


def build_moon_rock():
    rock = ico(1.0, 2, loc=(0, 0, 0.5), scale=(1.3, 1.1, 0.65))
    jitter(applied(rock), 0.06, 80)
    cut_below(rock, 0.0)
    finish(rock, "MoonRock")
    craters = [applied(cylinder(r, 0.08, 10, loc=(x, y, z), rot=(rx, ry, 0))) for r, x, y, z, rx, ry in ((0.3, 0.3, 0.2, 0.95, 0.15, 0.25), (0.2, -0.5, 0.3, 0.8, -0.3, -0.5), (0.18, 0.2, 0.8, 0.6, -1.0, 0.2))]
    join(craters, "Crater")


def build_planet():
    body = applied(uv_sphere(1.0, 16, 10, loc=(0, 0, 1.0)))
    finish(body, "PlanetBody")
    bpy.ops.mesh.primitive_torus_add(major_radius=1.55, minor_radius=0.12, major_segments=24, minor_segments=4, location=(0, 0, 1.0), rotation=(math.radians(70), math.radians(15), 0))
    ring = bpy.context.active_object
    ring.scale = (1, 1, 0.25)
    finish(applied(ring), "PlanetRing")


def build_space_crystal():
    shards = []
    for x, y, h, tilt in ((0, 0, 2.0, 0), (0.4, 0.2, 1.3, 25), (-0.35, -0.1, 1.5, -20)):
        shard = cone(0.35, 0.0, h, 5, loc=(x, y, h / 2), rot=(0, math.radians(tilt), 0))
        shards.append(applied(shard))
    join(shards, "Crystal")
    base = ico(0.6, 1, loc=(0, 0, 0.1), scale=(1.2, 1.2, 0.5))
    finish(applied(base), "MoonRock", "Base")


def build_rocket():
    hull = [applied(cylinder(0.5, 2.4, 12, loc=(0, 0, 1.6))), applied(cone(0.5, 0.0, 1.0, 12, loc=(0, 0, 3.3)))]
    join(hull, "Hull")
    fins = []
    for i in range(3):
        a = i * math.tau / 3
        fin = cube((0.08, 0.6, 0.8), loc=(math.cos(a) * 0.6, math.sin(a) * 0.6, 0.75))
        fin.rotation_euler = (0, 0, a + math.pi / 2)
        fins.append(applied(fin))
    fins.append(applied(cone(0.52, 0.3, 0.3, 12, loc=(0, 0, 3.0))))
    join(fins, "Fin")
    window = applied(cylinder(0.22, 0.1, 12, loc=(0, 0.5, 2.3), rot=(math.pi / 2, 0, 0)))
    finish(window, "Ice")
    flame = applied(cone(0.32, 0.0, 0.7, 8, loc=(0, 0, 0.0), rot=(math.pi, 0, 0)))
    finish(flame, "Glow")


MODELS = {
    "Salami": build_salami,
    "Mushroom": build_mushroom,
    "Mozzarella": build_mozzarella,
    "Pizza": build_pizza,
    "PizzaOven": build_oven,
    "Tree": build_tree,
    "Bush": build_bush,
    # Worlds 2-7 (#16)
    "HayBale": build_hay_bale,
    "Sunflower": build_sunflower,
    "Barn": build_barn,
    "Fence": build_fence,
    "PalmTree": build_palm,
    "BeachUmbrella": build_umbrella,
    "BeachRock": build_beach_rock,
    "SnowPine": build_snow_pine,
    "IceCrystal": build_ice_crystal,
    "Snowman": build_snowman,
    "LavaMountain": build_volcano,
    "LavaRock": build_lava_rock,
    "DeadTree": build_dead_tree,
    "Lollipop": build_lollipop,
    "CandyCane": build_candy_cane,
    "Cupcake": build_cupcake,
    "MoonRock": build_moon_rock,
    "Planet": build_planet,
    "SpaceCrystal": build_space_crystal,
    "Rocket": build_rocket,
}

# Deco of worlds 2-7, for the per-world overview renders.
WORLD_DECO = {
    "Farm": (["Barn", "HayBale", "Sunflower", "Fence", "Tree"], (255, 232, 190), (196, 170, 100)),
    "Beach": (["PalmTree", "BeachUmbrella", "BeachRock"], (190, 236, 255), (240, 220, 160)),
    "Icebergs": (["SnowPine", "IceCrystal", "Snowman"], (214, 236, 255), (225, 240, 250)),
    "Volcano": (["LavaMountain", "LavaRock", "DeadTree"], (110, 50, 45), (70, 55, 55)),
    "CandyLand": (["Lollipop", "CandyCane", "Cupcake"], (255, 224, 240), (255, 190, 220)),
    "Space": (["Planet", "Rocket", "SpaceCrystal", "MoonRock"], (30, 30, 60), (150, 150, 165)),
}

# ---------------------------------------------------------------- render


def scene_bounds(objs):
    lo = Vector((1e9, 1e9, 1e9))
    hi = Vector((-1e9, -1e9, -1e9))
    for o in objs:
        for corner in o.bound_box:
            w = o.matrix_world @ Vector(corner)
            lo = Vector(map(min, lo, w))
            hi = Vector(map(max, hi, w))
    return lo, hi


def setup_render(objs, path, size=640, distance=2.5, sky=(255, 236, 200), ground_color=(150, 215, 120)):
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = 48
    scene.cycles.use_denoising = True
    scene.render.resolution_x = size
    scene.render.resolution_y = size
    scene.render.film_transparent = False
    scene.view_settings.view_transform = "Standard"

    world = bpy.data.worlds.new("World")
    scene.world = world
    world.use_nodes = True
    bg = world.node_tree.nodes["Background"]
    bg.inputs["Color"].default_value = rgb(*sky)
    bg.inputs["Strength"].default_value = 0.9

    lo, hi = scene_bounds(objs)
    center = (lo + hi) / 2
    radius = max((hi - lo).length / 2, 0.5)

    # Soft ground so the model doesn't float
    bpy.ops.mesh.primitive_plane_add(size=radius * 12, location=(center.x, center.y, lo.z))
    ground = bpy.context.active_object
    gmat = bpy.data.materials.new("PreviewGround")
    gmat.use_nodes = True
    gmat.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = rgb(*ground_color)
    ground.data.materials.append(gmat)

    bpy.ops.object.light_add(type="SUN", rotation=(math.radians(50), math.radians(10), math.radians(-35)))
    sun = bpy.context.active_object
    sun.data.energy = 3.5
    sun.data.angle = math.radians(8)

    direction = Vector((0.0, 1.0, 0.0))  # camera looks at the model's +Y side (the front)
    direction.rotate(__import__("mathutils").Euler((0, 0, math.radians(-30))))
    cam_pos = center + direction * radius * distance + Vector((0, 0, radius * distance * 0.6))
    bpy.ops.object.camera_add(location=cam_pos)
    cam = bpy.context.active_object
    cam.data.lens = 50
    look = center - cam_pos
    cam.rotation_euler = look.to_track_quat("-Z", "Y").to_euler()
    scene.camera = cam

    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)


def model_objects():
    return [o for o in bpy.context.scene.objects if o.type == "MESH"]


def export(name):
    reset_scene()
    MODELS[name]()
    objs = model_objects()
    for o in bpy.context.scene.objects:
        o.select_set(o in objs)
    os.makedirs(MODEL_DIR, exist_ok=True)
    bpy.ops.export_scene.fbx(
        filepath=os.path.join(MODEL_DIR, f"{name}.fbx"),
        use_selection=True,
        object_types={"MESH"},
        mesh_smooth_type="FACE",
        apply_scale_options="FBX_SCALE_ALL",
        axis_forward="-Z",
        axis_up="Y",
        bake_space_transform=True,
    )
    os.makedirs(PREVIEW_DIR, exist_ok=True)
    setup_render(objs, os.path.join(PREVIEW_DIR, f"{name}.png"))
    print(f"built {name}: {[o.name for o in objs]}")


def overview():
    reset_scene()
    # Camera looks from +Y: big things in the back (-Y), toppings in front.
    layout = [
        ("PizzaOven", (0, -3.5, 0), 1.0),
        ("Tree", (-5.2, -4.5, 0), 1.2),
        ("Bush", (4.6, -3.2, 0), 1.0),
        ("Pizza", (0, 1.4, 0), 1.3),
        ("Salami", (-3.4, 1.8, 0), 0.9),
        ("Mushroom", (-2.0, 3.6, 0), 0.9),
        ("Mozzarella", (3.2, 2.2, 0), 0.9),
    ]
    for name, offset, scale in layout:
        before = set(bpy.context.scene.objects)
        MODELS[name]()
        for o in set(bpy.context.scene.objects) - before:
            o.scale = (scale, scale, scale)
            o.location = Vector(offset) + o.location * scale
    objs = model_objects()
    setup_render(objs, os.path.join(PREVIEW_DIR, "Overview.png"), size=960, distance=1.95)


def world_overview(world):
    """All deco models of one world side by side (largest first, at the back)."""
    reset_scene()
    names, sky, ground = WORLD_DECO[world]
    x = 0.0
    for i, name in enumerate(names):
        before = set(bpy.context.scene.objects)
        MODELS[name]()
        new = [o for o in set(bpy.context.scene.objects) - before if o.type == "MESH"]
        lo, hi = scene_bounds(new)
        width = hi.x - lo.x
        for o in new:
            o.location = o.location + Vector((x - lo.x, -1.2 if i == 0 else 1.0 * (i % 2), 0))
        x += width + 0.6
    objs = model_objects()
    setup_render(objs, os.path.join(PREVIEW_DIR, f"World_{world}.png"), size=960, distance=2.7, sky=sky, ground_color=ground)


if __name__ == "__main__":
    args = sys.argv[1:]
    names = [a for a in args if a in MODELS or a == "Overview" or a in WORLD_DECO]
    if not names:
        names = list(MODELS) + ["Overview"] + list(WORLD_DECO)
    for n in names:
        if n == "Overview":
            overview()
        elif n in WORLD_DECO:
            world_overview(n)
        else:
            export(n)
