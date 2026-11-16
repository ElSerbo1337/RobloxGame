"""Builds the low-poly cartoon models for world 1 and renders preview images.

Run headless (bpy from pip, Python 3.13):
    python tools/blender/build_models.py [asset-name ...]

Writes assets/models/<Name>.fbx and assets/previews/<Name>.png (plus Overview.png).
Every model is built from separately named mesh parts with exactly one colour each.
The Roblox side (src/shared/ModelLibrary.luau) recolours the imported MeshParts by
these part names, so the look never depends on how Studio imports the materials.
Keep part names and colours in sync with PALETTES in ModelLibrary.luau.
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


# Part name -> colour. Same values as ModelLibrary.PALETTES (Roblox side).
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
}

_materials = {}


def material(name):
    if name in _materials:
        return _materials[name]
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = rgb(*COLORS[name])
    bsdf.inputs["Roughness"].default_value = 0.7
    if name == "Glow":
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


MODELS = {
    "Salami": build_salami,
    "Mushroom": build_mushroom,
    "Mozzarella": build_mozzarella,
    "Pizza": build_pizza,
    "PizzaOven": build_oven,
    "Tree": build_tree,
    "Bush": build_bush,
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


def setup_render(objs, path, size=640, distance=2.5):
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
    bg.inputs["Color"].default_value = rgb(255, 236, 200)
    bg.inputs["Strength"].default_value = 0.9

    lo, hi = scene_bounds(objs)
    center = (lo + hi) / 2
    radius = max((hi - lo).length / 2, 0.5)

    # Soft ground so the model doesn't float
    bpy.ops.mesh.primitive_plane_add(size=radius * 12, location=(center.x, center.y, lo.z))
    ground = bpy.context.active_object
    gmat = bpy.data.materials.new("PreviewGround")
    gmat.use_nodes = True
    gmat.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = rgb(150, 215, 120)
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


if __name__ == "__main__":
    names = [a for a in sys.argv[1:] if a in MODELS or a == "Overview"] or list(MODELS) + ["Overview"]
    for n in names:
        if n == "Overview":
            overview()
        else:
            export(n)
