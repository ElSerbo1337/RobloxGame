"""Builds the 42 low-poly cartoon pets (all eggs) and renders their preview images.

Run headless (bpy from pip, Python 3.13):
    python tools/blender/build_pets.py [PetId ... | EggId ...]

Writes assets/models/pets/<PetId>.fbx, assets/previews/pets/<PetId>.png (transparent
icon) and assets/previews/pets/<EggId>.png (all pets of one egg side by side).

Every pet is built from mesh parts with exactly one colour each. The part name carries
the colour (and an optional material), e.g. "Pet_F2D49B" or "Pet_FF7A1A_Neon", so the
Roblox side (src/shared/ModelLibrary.luau) can recolour the imported MeshParts without
a palette. Materials: Neon (glows), Glass (see-through), Metal (shiny).
The front of every pet faces Blender +Y (like the oven in build_models.py).
"""

import math
import os
import random
import sys

import bpy  # noqa: I001  (bpy must be imported before bmesh)
import bmesh
from mathutils import Euler, Vector

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
MODEL_DIR = os.path.join(ROOT, "assets", "models", "pets")
PREVIEW_DIR = os.path.join(ROOT, "assets", "previews", "pets")

EYE = "1E1E2A"
WHITE = "FFFFFF"
CHEEK = "FF9AAE"
NOSE = "3A2A2A"


def lin(c):
    c = c / 255
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def hex_rgba(h):
    return (lin(int(h[0:2], 16)), lin(int(h[2:4], 16)), lin(int(h[4:6], 16)), 1.0)


_materials = {}


def material(h, kind):
    key = (h, kind)
    if key in _materials:
        return _materials[key]
    mat = bpy.data.materials.new(f"{h}_{kind or 'Plastic'}")
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = hex_rgba(h)
    bsdf.inputs["Roughness"].default_value = 0.55
    if kind == "Neon":
        bsdf.inputs["Emission Color"].default_value = hex_rgba(h)
        bsdf.inputs["Emission Strength"].default_value = 3.0
    elif kind == "Metal":
        bsdf.inputs["Metallic"].default_value = 0.85
        bsdf.inputs["Roughness"].default_value = 0.3
    elif kind == "Glass":
        bsdf.inputs["Roughness"].default_value = 0.1
        bsdf.inputs["Alpha"].default_value = 0.45
    mat.diffuse_color = hex_rgba(h)
    _materials[key] = mat
    return mat


# ---------------------------------------------------------------- building blocks


def _active():
    return bpy.context.active_object


def _apply(obj):
    for o in bpy.context.selected_objects:
        o.select_set(False)
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)


class Pet:
    """Collects mesh pieces per (colour, material) and joins them into one part each."""

    def __init__(self):
        self.groups = {}

    def add(self, obj, h, kind=None, smooth=False):
        _apply(obj)
        obj["smooth"] = smooth
        self.groups.setdefault((h.upper(), kind), []).append(obj)
        return obj

    def finish(self):
        for (h, kind), objs in self.groups.items():
            for o in bpy.context.selected_objects:
                o.select_set(False)
            for o in objs:
                o.select_set(True)
            bpy.context.view_layer.objects.active = objs[0]
            if len(objs) > 1:
                bpy.ops.object.join()
            obj = bpy.context.view_layer.objects.active
            name = f"Pet_{h}" + (f"_{kind}" if kind else "")
            obj.name = name
            obj.data.name = name
            for poly in obj.data.polygons:
                poly.use_smooth = False
            obj.data.materials.clear()
            obj.data.materials.append(material(h, kind))


def sph(P, h, c, r, scale=(1, 1, 1), rot=(0, 0, 0), seg=14, rings=9, kind=None):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=seg, ring_count=rings, radius=r, location=c)
    o = _active()
    o.scale = scale
    o.rotation_euler = Euler(rot)
    return P.add(o, h, kind)


def ico(P, h, c, r, scale=(1, 1, 1), rot=(0, 0, 0), subdiv=1, kind=None, jit=0.0, seed=0):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=subdiv, radius=r, location=c)
    o = _active()
    o.scale = scale
    o.rotation_euler = Euler(rot)
    if jit:
        rnd = random.Random(seed)
        for v in o.data.vertices:
            v.co += Vector((rnd.uniform(-jit, jit), rnd.uniform(-jit, jit), rnd.uniform(-jit, jit)))
    return P.add(o, h, kind)


def cone(P, h, c, r1, r2, depth, rot=(0, 0, 0), verts=8, kind=None, scale=(1, 1, 1)):
    bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=r1, radius2=r2, depth=depth, location=c)
    o = _active()
    o.scale = scale
    o.rotation_euler = Euler(rot)
    return P.add(o, h, kind)


def cyl(P, h, c, r, depth, rot=(0, 0, 0), verts=10, kind=None, scale=(1, 1, 1)):
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=r, depth=depth, location=c)
    o = _active()
    o.scale = scale
    o.rotation_euler = Euler(rot)
    return P.add(o, h, kind)


def box(P, h, c, size, rot=(0, 0, 0), kind=None, bevel=0.0):
    bpy.ops.mesh.primitive_cube_add(size=1, location=c)
    o = _active()
    o.scale = size
    o.rotation_euler = Euler(rot)
    if bevel:
        _apply(o)
        mod = o.modifiers.new("Bevel", "BEVEL")
        mod.width = bevel
        mod.segments = 1
        bpy.ops.object.modifier_apply(modifier="Bevel")
    return P.add(o, h, kind)


def torus(P, h, c, major, minor, rot=(0, 0, 0), kind=None, seg=14, mseg=6, scale=(1, 1, 1)):
    bpy.ops.mesh.primitive_torus_add(major_radius=major, minor_radius=minor, major_segments=seg, minor_segments=mseg, location=c)
    o = _active()
    o.scale = scale
    o.rotation_euler = Euler(rot)
    return P.add(o, h, kind)


def flat(P, h, points, thickness, c=(0, 0, 0), rot=(0, 0, 0), kind=None):
    """Flat shape from 2D points (x, z) in the XZ plane, `thickness` deep along Y."""
    mesh = bpy.data.meshes.new("flat")
    obj = bpy.data.objects.new("flat", mesh)
    bpy.context.collection.objects.link(obj)
    bm = bmesh.new()
    front = [bm.verts.new((x, -thickness / 2, z)) for x, z in points]
    back = [bm.verts.new((x, thickness / 2, z)) for x, z in points]
    bm.faces.new(front)
    bm.faces.new(list(reversed(back)))
    n = len(points)
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new([front[i], front[j], back[j], back[i]])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    bm.to_mesh(mesh)
    bm.free()
    obj.location = c
    obj.rotation_euler = Euler(rot)
    return P.add(obj, h, kind)


def star_points(r_out, r_in, n=5):
    pts = []
    for i in range(n * 2):
        a = math.pi / 2 + i * math.pi / n
        r = r_out if i % 2 == 0 else r_in
        pts.append((math.cos(a) * r, math.sin(a) * r))
    return pts


def surface(center, radii, yaw, pitch, out=1.0):
    """Point on an ellipsoid: yaw 0 = front (+Y), positive yaw = right (+X); pitch up."""
    y, p = math.radians(yaw), math.radians(pitch)
    d = Vector((math.sin(y) * math.cos(p), math.cos(y) * math.cos(p), math.sin(p)))
    rx, ry, rz = radii if isinstance(radii, (tuple, list)) else (radii, radii, radii)
    return Vector(center) + Vector((d.x * rx, d.y * ry, d.z * rz)) * out


def eyes(P, head, radii, spread=27, pitch=8, size=0.15, color=EYE, kind=None, shine=True, sclera=None):
    for side in (-1, 1):
        yaw = side * spread
        pos = surface(head, radii, yaw, pitch, 0.93)
        rot = (math.radians(-pitch), 0, -math.radians(yaw))
        if sclera:
            sph(P, sclera, surface(head, radii, yaw, pitch, 0.9), size * 1.35, scale=(0.85, 0.5, 1.1), rot=rot, seg=12, rings=8)
            pos = surface(head, radii, yaw, pitch, 0.97)
        sph(P, color, pos, size, scale=(0.85, 0.55, 1.15), rot=rot, seg=12, rings=8, kind=kind)
        if shine:
            hl = surface(head, radii, yaw - side * 4, pitch + 6, 1.0 + size * 0.35)
            sph(P, WHITE, hl, size * 0.35, seg=8, rings=6)


def cheeks(P, head, radii, spread=48, pitch=-14, size=0.09, color=CHEEK):
    for side in (-1, 1):
        pos = surface(head, radii, side * spread, pitch, 0.97)
        sph(P, color, pos, size, scale=(1, 0.4, 0.7), rot=(0, 0, -math.radians(side * spread)), seg=10, rings=6)


def round_ears(P, h, head, R, size=0.22, spread=40, pitch=48, inner=None, flatness=0.35):
    for side in (-1, 1):
        pos = surface(head, R, side * spread, pitch, 0.95)
        rot = (0, side * math.radians(25), 0)
        sph(P, h, pos, size, scale=(1, flatness, 1), rot=rot, seg=12, rings=8)
        if inner:
            ipos = pos + Vector((0, size * flatness * 0.6, 0))
            sph(P, inner, ipos, size * 0.65, scale=(1, flatness * 0.6, 1), rot=rot, seg=10, rings=6)


def pointed_ears(P, h, head, R, size=0.2, height=0.38, spread=34, pitch=52, inner=None, tilt=18):
    for side in (-1, 1):
        pos = surface(head, R, side * spread, pitch, 0.88)
        rot = (math.radians(-8), side * math.radians(tilt), 0)
        cone(P, h, pos + Vector((0, 0, height * 0.35)), size, 0.0, height, rot=rot, verts=4, scale=(1, 0.55, 1))
        if inner:
            cone(P, inner, pos + Vector((0, size * 0.25, height * 0.3)), size * 0.6, 0.0, height * 0.7, rot=rot, verts=4, scale=(1, 0.4, 1))


def long_ears(P, h, head, R, length=0.55, width=0.13, spread=18, inner=None, droop=(0, 0)):
    for i, side in enumerate((-1, 1)):
        pos = surface(head, R, side * spread, 70, 0.9) + Vector((0, 0, length * 0.75))
        rot = (math.radians(-8 + droop[i]), side * math.radians(12), 0)
        sph(P, h, pos, 1, scale=(width, width * 0.55, length), rot=rot, seg=10, rings=8)
        if inner:
            sph(P, inner, pos + Vector((0, width * 0.3, 0)), 1, scale=(width * 0.55, width * 0.35, length * 0.8), rot=rot, seg=8, rings=6)


def floppy_ears(P, h, head, R, size=0.2, spread=62, pitch=30):
    for side in (-1, 1):
        pos = surface(head, R, side * spread, pitch, 1.0)
        sph(P, h, pos + Vector((side * 0.06, 0, -0.12)), size, scale=(0.45, 0.8, 1.25), rot=(0, side * math.radians(-25), 0), seg=10, rings=7)


def horns(P, h, head, R, spread=30, pitch=58, length=0.35, r=0.08, tilt=30, kind=None):
    for side in (-1, 1):
        pos = surface(head, R, side * spread, pitch, 0.9)
        cone(P, h, pos + Vector((side * length * 0.15, 0, length * 0.4)), r, 0.01, length, rot=(math.radians(-15), side * math.radians(tilt), 0), verts=7, kind=kind)


def feet(P, h, spots, r=0.14):
    for x, y in spots:
        sph(P, h, (x, y, r * 0.55), r, scale=(1, 1.15, 0.6), seg=10, rings=6)


FOUR_FEET = [(-0.26, 0.24), (0.26, 0.24), (-0.26, -0.26), (0.26, -0.26)]
TWO_FEET = [(-0.2, 0.18), (0.2, 0.18)]

# Standard chibi proportions: round body, big head in front/above it.
BODY = (0, -0.05, 0.5)
BODY_R = (0.47, 0.5, 0.44)
HEAD = (0, 0.18, 1.18)
HEAD_R = 0.55


def critter(P, fur, belly=None, head_color=None, body_r=BODY_R, head=HEAD, R=HEAD_R, feet_color=None, feet_spots=FOUR_FEET, eye_size=0.15, eye_spread=27, eye_pitch=6, blush=True, nose=NOSE, muzzle=None, sclera=None):
    sph(P, fur, BODY, 1, scale=body_r)
    if belly:
        sph(P, belly, (0, BODY[1] + body_r[1] * 0.55, BODY[2] - 0.02), 1, scale=(body_r[0] * 0.65, body_r[1] * 0.5, body_r[2] * 0.75))
    sph(P, head_color or fur, head, R)
    if feet_spots:
        feet(P, feet_color or fur, feet_spots)
    eyes(P, head, R, spread=eye_spread, pitch=eye_pitch, size=eye_size, sclera=sclera)
    if blush:
        cheeks(P, head, R)
    if muzzle:
        sph(P, muzzle, surface(head, R, 0, -18, 0.8), R * 0.42, scale=(1, 0.7, 0.62))
    if nose:
        sph(P, nose, surface(head, R, 0, -10, 1.02 if not muzzle else 1.08), 0.06, scale=(1.2, 0.8, 0.8), seg=8, rings=6)
    return Vector(head), R


def tail_ball(P, h, r=0.16, z=0.5):
    sph(P, h, (0, BODY[1] - BODY_R[1] * 0.95, z), r)


def tail_curve(P, h, r=0.06, length=0.7, up=0.5, z=0.45, kind=None, tip=None):
    # Arc of small balls behind the body.
    n = 7
    for i in range(n):
        t = i / (n - 1)
        y = BODY[1] - BODY_R[1] * 0.9 - t * length * 0.6
        zz = z + math.sin(t * math.pi * 0.9) * up
        sph(P, tip if (tip and i == n - 1) else h, (0, y, zz), r * (1.25 if (tip and i == n - 1) else 1.0), seg=8, rings=6, kind=kind)


def wings_bird(P, h, spread=0.42, z=0.6, size=0.32, y=-0.05, kind=None, angle=25):
    for side in (-1, 1):
        sph(P, h, (side * spread, y, z), size, scale=(0.3, 0.8, 1.0), rot=(math.radians(15), side * math.radians(angle), 0), seg=10, rings=7, kind=kind)


def wings_dragon(P, h, z=0.85, y=-0.3, span=0.75, kind=None):
    pts = [(0, 0), (span, 0.45), (span * 0.95, -0.05), (span * 0.7, 0.05), (span * 0.6, -0.25), (span * 0.35, -0.1), (span * 0.2, -0.3)]
    for side in (-1, 1):
        p = [(x * side, zz) for x, zz in pts]
        if side < 0:
            p.reverse()
        flat(P, h, p, 0.05, c=(side * 0.2, y, z), rot=(math.radians(-15), 0, side * math.radians(-25)), kind=kind)


def leaf(P, h, c, length=0.35, width=0.16, rot=(0, 0, 0), kind=None):
    pts = []
    for i in range(9):
        t = i / 8
        pts.append((math.sin(t * math.pi) * width, t * length))
    for i in range(7, 0, -1):
        t = i / 8
        pts.append((-math.sin(t * math.pi) * width, t * length))
    return flat(P, h, pts, 0.03, c=c, rot=rot, kind=kind)


def beak(P, h, head, R, pitch=-5, length=0.22, r=0.1):
    pos = surface(head, R, 0, pitch, 0.95)
    cone(P, h, pos + Vector((0, length * 0.4, 0)), r, 0.0, length, rot=(math.radians(-90), 0, 0), verts=6)


def snout_long(P, h, head, R, length=0.32, r=0.22, pitch=-15, nose=NOSE):
    pos = surface(head, R, 0, pitch, 0.75)
    sph(P, h, pos + Vector((0, length * 0.5, 0)), 1, scale=(r, length, r * 0.8))
    if nose:
        sph(P, nose, pos + Vector((0, length * 1.45, r * 0.25)), 0.07, scale=(1.3, 0.8, 0.9), seg=8, rings=6)


def legs(P, h, spots, height=0.35, r=0.1, hoof=None):
    for x, y in spots:
        cyl(P, h, (x, y, height / 2), r, height, verts=8)
        if hoof:
            cyl(P, hoof, (x, y, 0.04), r * 1.1, 0.08, verts=8)


def spikes(P, h, n=4, y0=0.2, y1=-0.5, z=1.0, size=0.12, kind=None, curve=0.0):
    for i in range(n):
        t = i / max(n - 1, 1)
        y = y0 + (y1 - y0) * t
        zz = z - curve * t * t
        cone(P, h, (0, y, zz + size * 0.4), size, 0.0, size * 1.6, rot=(math.radians(-20), 0, 0), verts=4, kind=kind)


# ---------------------------------------------------------------- world 1 (Garten-Ei)


def dough_hamster(P):
    head, R = critter(P, "F2D29B", belly="FFF2D6", feet_color="E8B878", muzzle="FFF2D6")
    round_ears(P, "E8B878", head, R, size=0.17, spread=42, pitch=46, inner="FFC2B0")
    # Crust-coloured stripe and a little chef hat.
    sph(P, "D98E45", (0, -0.25, 0.85), 1, scale=(0.18, 0.3, 0.12))
    cyl(P, WHITE, head + Vector((0, -0.05, R * 0.95)), 0.24, 0.16, verts=12)
    ico(P, WHITE, head + Vector((0, -0.05, R * 1.22)), 0.3, scale=(1, 1, 0.6), subdiv=1)
    tail_ball(P, "E8B878", r=0.1)


def basil_bunny(P):
    head, R = critter(P, "F5F5EC", belly="FFFFFF", head_color="F5F5EC", feet_color="E6E6DA", muzzle="FFFFFF")
    long_ears(P, "F5F5EC", head, R, inner="8FD46A", droop=(0, 18))
    leaf(P, "3FA34D", head + Vector((0.18, 0.05, R * 0.82)), length=0.42, width=0.15, rot=(math.radians(-20), math.radians(30), 0))
    leaf(P, "57BF5A", head + Vector((-0.1, 0.0, R * 0.86)), length=0.34, width=0.13, rot=(math.radians(-15), math.radians(-35), 0))
    tail_ball(P, WHITE, r=0.16)


def tomato_cat(P):
    head, R = critter(P, "E8453C", belly="FF8A7A", feet_color="C9362E", nose="7A1F1A")
    pointed_ears(P, "E8453C", head, R, inner="FFB0A0")
    # Green calyx on top like a tomato.
    top = head + Vector((0, 0, R * 0.96))
    for i in range(5):
        a = i * 2 * math.pi / 5
        leaf(P, "3E9B3A", top, length=0.28, width=0.08, rot=(math.radians(80), 0, a))
    cyl(P, "2F7D2C", top + Vector((0, 0, 0.08)), 0.04, 0.18, verts=6)
    tail_curve(P, "E8453C", r=0.07, up=0.6)
    # Whiskers
    for side in (-1, 1):
        for k in (-1, 1):
            p = surface(head, R, side * 30, -12, 1.0)
            box(P, "FFE0D6", p + Vector((side * 0.12, 0.02, k * 0.04)), (0.22, 0.015, 0.015), rot=(0, side * k * 0.15, 0))


def cheese_mouse(P):
    head, R = critter(P, "FFD34E", belly="FFE88A", feet_color="F2B630", nose="FF8FA3")
    round_ears(P, "FFD34E", head, R, size=0.27, spread=46, pitch=40, inner="FFB3C0")
    # Cheese holes
    for yaw, pitch, s in [(70, 30, 0.08), (-60, 20, 0.06), (150, 10, 0.1), (-140, 35, 0.07), (120, -20, 0.06)]:
        sph(P, "E0A41E", surface(BODY, BODY_R, yaw, pitch, 0.97), s, scale=(1, 1, 0.7), seg=8, rings=6)
    for yaw, pitch, s in [(-80, 40, 0.06), (100, 55, 0.05)]:
        sph(P, "E0A41E", surface(head, R, yaw, pitch, 0.97), s, seg=8, rings=6)
    tail_curve(P, "FF9FB0", r=0.04, up=0.5, length=0.9)


def olive_owl(P):
    body = Vector((0, 0, 0.72))
    R = (0.58, 0.55, 0.72)
    sph(P, "5E7A2E", body, 1, scale=R)
    sph(P, "B9C86E", surface(body, R, 0, -15, 0.55), 1, scale=(0.4, 0.3, 0.48))
    face = Vector((0, 0.12, 0.95))
    for side in (-1, 1):
        ring = surface(face, 0.45, side * 26, 8, 0.95)
        sph(P, "D9E3A0", ring, 0.2, scale=(1, 0.35, 1), rot=(0, 0, -math.radians(side * 26)))
    eyes(P, face, 0.45, spread=26, pitch=8, size=0.14)
    beak(P, "F2A23A", face, 0.45, pitch=-12, length=0.18, r=0.08)
    pointed_ears(P, "4A6224", body, R, size=0.14, height=0.3, spread=34, pitch=62)
    wings_bird(P, "4A6224", spread=0.55, z=0.65, size=0.4)
    feet(P, "F2A23A", [(-0.2, 0.2), (0.2, 0.2)], r=0.12)
    # Olive slice crown: dark olive ring with a red pimento.
    torus(P, "2E3A1A", body + Vector((0, -0.05, R[2] + 0.05)), 0.16, 0.06)
    sph(P, "E0483A", body + Vector((0, -0.05, R[2] + 0.06)), 0.07)


def pizza_dragon(P):
    head, R = critter(P, "F08A2C", belly="FFE2A6", feet_color="D9701E", nose="7A3A12", muzzle="FFC27A")
    horns(P, "FFF2D0", head, R, length=0.3)
    wings_dragon(P, "FFCF5A")
    spikes(P, "D9701E", n=4, y0=0.0, y1=-0.45, z=0.95, curve=0.35)
    tail_curve(P, "F08A2C", r=0.09, up=0.25, length=0.8, tip="D9701E")
    # Pepperoni spots on the back
    for yaw, pitch in [(140, 40), (-150, 30), (180, 10), (115, 5), (-120, 5)]:
        sph(P, "C8322C", surface(BODY, BODY_R, yaw, pitch, 0.98), 0.1, scale=(1, 1, 0.45), seg=10, rings=6)


# ---------------------------------------------------------------- world 2 (Bauernhof-Ei)


def farm_chick(P):
    body = Vector((0, 0, 0.62))
    R = (0.55, 0.55, 0.6)
    sph(P, "FFE04A", body, 1, scale=R)
    face = Vector((0, 0.1, 0.78))
    eyes(P, face, 0.5, spread=28, pitch=6, size=0.13)
    cheeks(P, face, 0.5, spread=50, pitch=-10)
    beak(P, "FF9A2E", face, 0.5, pitch=-4, length=0.2, r=0.09)
    wings_bird(P, "FFD02A", spread=0.52, z=0.55, size=0.28)
    feet(P, "FF9A2E", TWO_FEET, r=0.12)
    for i, a in enumerate((-20, 0, 20)):
        sph(P, "FFD02A", body + Vector((0, -0.05, R[2] + 0.08)), 0.1, scale=(0.5, 0.7, 1.6), rot=(0, math.radians(a), 0))


def corn_piglet(P):
    head, R = critter(P, "FFB3C1", belly="FFD3DC", feet_color="E88A9C", nose=None, eye_size=0.13)
    sp = surface(head, R, 0, -12, 0.92)
    cyl(P, "FF8FA5", sp + Vector((0, 0.06, 0)), 0.17, 0.14, rot=(math.radians(90), 0, 0), verts=12, scale=(1, 0.8, 1))
    for side in (-1, 1):
        sph(P, "B5566A", sp + Vector((side * 0.06, 0.14, 0)), 0.035, seg=6, rings=4)
    floppy_ears(P, "FF9FB3", head, R, spread=40, pitch=55)
    tail_curve(P, "FF9FB3", r=0.045, up=0.35, length=0.4, z=0.55)
    # Corn cob on its back
    c = Vector((0, -0.2, 0.98))
    sph(P, "FFD43B", c, 1, scale=(0.13, 0.3, 0.13), rot=(math.radians(-15), 0, 0))
    for i in range(4):
        a = math.radians(-60 + i * 40)
        leaf(P, "7CC24A", c + Vector((0, 0.18, -0.02)), length=0.3, width=0.07, rot=(math.radians(110), 0, a))


def pepper_goat(P):
    head, R = critter(P, "4CAF50", belly="8EDB7A", feet_color="2E7D32", muzzle="E8F5D0", feet_spots=None)
    legs(P, "4CAF50", FOUR_FEET, height=0.32, r=0.09, hoof="3A2A20")
    horns(P, "E8D2A0", head, R, spread=26, pitch=62, length=0.4, tilt=35)
    floppy_ears(P, "4CAF50", head, R, size=0.15, spread=70, pitch=25)
    sph(P, WHITE, surface(head, R, 0, -55, 0.9), 0.14, scale=(0.8, 0.6, 1.4))
    cyl(P, "2E7D32", head + Vector((0, -0.05, R * 0.98)), 0.05, 0.2, verts=6, rot=(0.3, 0, 0))
    # Bell pepper bumps on the back
    for yaw in (150, -150, 180):
        sph(P, "43A047", surface(BODY, BODY_R, yaw, 20, 0.9), 0.2, scale=(0.6, 0.6, 1))


def onion_cow(P):
    head, R = critter(P, "F5F0FA", belly="FFFFFF", muzzle="FFB8C8", feet_spots=None, nose="C06078")
    legs(P, "F5F0FA", FOUR_FEET, height=0.32, r=0.1, hoof="5A3A6A")
    horns(P, "FFF1C9", head, R, spread=48, pitch=42, length=0.28, tilt=70)
    floppy_ears(P, "B07CC8", head, R, size=0.13, spread=75, pitch=18)
    for yaw, pitch, s in [(80, 10, 0.18), (-100, 20, 0.2), (170, 30, 0.16), (-40, -20, 0.12)]:
        sph(P, "A35DB5", surface(BODY, BODY_R, yaw, pitch, 0.96), s, scale=(1, 1, 0.6), seg=10, rings=6)
    sph(P, "A35DB5", surface(head, R, -55, 35, 0.96), 0.14, scale=(1, 0.5, 1))
    # Onion sprout
    top = head + Vector((0, -0.05, R * 0.95))
    sph(P, "C89AD8", top, 0.16, scale=(1, 1, 0.8))
    for a in (-0.25, 0.25):
        cone(P, "6FBF4A", top + Vector((a * 0.4, 0, 0.25)), 0.04, 0.0, 0.42, rot=(0, a, 0), verts=5)


def hay_horse(P):
    body_r = (0.45, 0.6, 0.42)
    sph(P, "E6C35C", (0, -0.1, 0.72), 1, scale=body_r)
    legs(P, "E6C35C", [(-0.24, 0.3), (0.24, 0.3), (-0.24, -0.45), (0.24, -0.45)], height=0.5, r=0.1, hoof="7A4E22")
    head = Vector((0, 0.42, 1.35))
    R = 0.42
    sph(P, "E6C35C", head, R)
    snout_long(P, "F2D88A", head, R, length=0.22, r=0.24, pitch=-25)
    eyes(P, head, R, spread=34, pitch=12, size=0.12)
    pointed_ears(P, "E6C35C", head, R, size=0.1, height=0.25, spread=30, pitch=62)
    # Mane and tail of hay
    for i in range(6):
        t = i / 5
        ico(P, "B07A2E", (0, 0.35 - t * 0.55, 1.62 - t * 0.55), 0.12, jit=0.03, seed=i)
    for i in range(5):
        cone(P, "C08A3A", (0, -0.75 - i * 0.03, 0.75 - i * 0.07), 0.09, 0.02, 0.4, rot=(math.radians(-50 - i * 6), 0, 0), verts=5)
    # Straw hat
    cyl(P, "F2DC8A", head + Vector((0, -0.08, R * 0.9)), 0.42, 0.04, verts=14)
    cyl(P, "F2DC8A", head + Vector((0, -0.08, R * 1.05)), 0.2, 0.2, verts=12)
    cyl(P, "D9483A", head + Vector((0, -0.08, R * 0.98)), 0.21, 0.06, verts=12)


def golden_rooster(P):
    body = Vector((0, -0.05, 0.72))
    R = (0.5, 0.55, 0.6)
    sph(P, "FFC83A", body, 1, scale=R, kind="Metal")
    face = Vector((0, 0.18, 1.0))
    eyes(P, face, 0.42, spread=32, pitch=10, size=0.12)
    beak(P, "FF9A2E", face, 0.42, pitch=-4, length=0.2, r=0.09)
    sph(P, "E8322E", surface(face, 0.42, 0, -35, 0.9), 0.09, scale=(0.7, 0.7, 1.4))
    for i, (y, z) in enumerate([(0.18, 1.45), (0.05, 1.5), (-0.08, 1.43)]):
        sph(P, "E8322E", (0, y, z), 0.11, scale=(0.5, 1, 1.2))
    wings_bird(P, "F2B024", spread=0.48, z=0.7, size=0.35, kind="Metal")
    for i, a in enumerate((-35, -10, 15)):
        sph(P, "FF8A2A" if i % 2 else "E8322E", (0, -0.6, 1.0), 1, scale=(0.08, 0.15, 0.45), rot=(math.radians(a - 20), 0, 0))
    legs(P, "FF9A2E", [(-0.16, 0.05), (0.16, 0.05)], height=0.25, r=0.05)
    feet(P, "FF9A2E", [(-0.16, 0.12), (0.16, 0.12)], r=0.1)


# ---------------------------------------------------------------- world 3 (Strand-Ei)


def sand_crab(P):
    body = Vector((0, 0, 0.45))
    R = (0.6, 0.48, 0.32)
    sph(P, "F08A4B", body, 1, scale=R)
    for side in (-1, 1):
        stalk = Vector((side * 0.2, 0.3, 0.92))
        cyl(P, "F08A4B", stalk - Vector((0, 0, 0.2)), 0.035, 0.42, verts=6)
        sph(P, WHITE, stalk + Vector((0, 0, 0.06)), 0.11)
        sph(P, EYE, stalk + Vector((0, 0.08, 0.07)), 0.06)
        # Claws
        arm = Vector((side * 0.62, 0.35, 0.45))
        cyl(P, "F08A4B", arm - Vector((side * 0.1, 0.1, 0)), 0.05, 0.3, rot=(0, math.radians(90), side * math.radians(40)), verts=6)
        sph(P, "E8703A", arm + Vector((0, 0.1, 0.05)), 0.2, scale=(0.9, 1.1, 0.7))
        cone(P, "E8703A", arm + Vector((side * 0.02, 0.33, 0.1)), 0.08, 0.0, 0.22, rot=(math.radians(-80), 0, 0), verts=5)
        for k in range(3):
            leg_pos = Vector((side * 0.55, -0.05 - k * 0.2, 0.18))
            cyl(P, "E8703A", leg_pos, 0.04, 0.42, rot=(0, side * math.radians(50), 0), verts=6)
    cheeks(P, body, R, spread=30, pitch=10)
    # Little sun hat
    cyl(P, "FFF2C2", (0, -0.2, 0.76), 0.3, 0.03, verts=14)
    sph(P, "FFF2C2", (0, -0.2, 0.78), 0.16, scale=(1, 1, 0.7))
    cyl(P, "38B6D8", (0, -0.2, 0.8), 0.165, 0.05, verts=12)


def shell_turtle(P):
    head, R = critter(P, "7BC67B", head=(0, 0.45, 0.9), R=0.4, body_r=(0.42, 0.45, 0.32), feet_color="6BB56B", eye_size=0.12, nose=None)
    shell = Vector((0, -0.05, 0.62))
    sph(P, "FFB79A", shell, 1, scale=(0.62, 0.65, 0.5))
    for z, r in [(0.92, 0.38), (1.02, 0.22)]:
        torus(P, "F08A6E", (0, -0.05, z), r, 0.04, seg=16)
    cone(P, "FFD7C4", (0, -0.05, 1.12), 0.12, 0.0, 0.18, verts=8)
    sph(P, "6BB56B", (0, -0.72, 0.42), 0.1, scale=(1, 1.6, 0.8))


def shrimp_seal(P):
    body = Vector((0, -0.1, 0.48))
    R = (0.46, 0.68, 0.42)
    sph(P, "AEB9C8", body, 1, scale=R)
    sph(P, "E3E8EE", surface(body, R, 0, -20, 0.6), 1, scale=(0.3, 0.45, 0.25))
    head = Vector((0, 0.38, 1.0))
    Rh = 0.42
    sph(P, "AEB9C8", head, Rh)
    eyes(P, head, Rh, spread=28, pitch=8, size=0.14)
    sph(P, "E3E8EE", surface(head, Rh, 0, -22, 0.8), 0.18, scale=(1.1, 0.7, 0.6))
    sph(P, NOSE, surface(head, Rh, 0, -12, 1.03), 0.06, scale=(1.3, 0.8, 0.8))
    cheeks(P, head, Rh)
    for side in (-1, 1):
        sph(P, "FF8F6E", (side * 0.45, 0.2, 0.25), 1, scale=(0.25, 0.14, 0.07), rot=(0, 0, side * 0.5))
        sph(P, "FF8F6E", (side * 0.2, -0.78, 0.16), 1, scale=(0.22, 0.12, 0.06), rot=(0, 0, side * 0.6))
    # Shrimp hat curled on its head
    for i in range(6):
        a = math.radians(-30 + i * 40)
        p = head + Vector((0, -0.05, Rh + 0.05)) + Vector((math.cos(a) * 0.18, 0, math.sin(a) * 0.12 + 0.1))
        sph(P, "FF8F6E" if i % 2 == 0 else "FFB49A", p, 0.08 - i * 0.006)


def pineapple_parrot(P):
    body = Vector((0, -0.05, 0.68))
    R = (0.5, 0.5, 0.62)
    sph(P, "FFC93C", body, 1, scale=R)
    # Diamond pattern dots
    for yaw in range(-150, 181, 60):
        for pitch in (-25, 5, 35):
            sph(P, "E8A22A", surface(body, R, yaw + (pitch % 2) * 30, pitch, 0.98), 0.05, seg=6, rings=4)
    face = Vector((0, 0.15, 0.95))
    eyes(P, face, 0.42, spread=30, pitch=8, size=0.13)
    pos = surface(face, 0.42, 0, -8, 0.92)
    sph(P, "3A3A4A", pos + Vector((0, 0.12, -0.02)), 1, scale=(0.1, 0.16, 0.14), rot=(math.radians(25), 0, 0))
    cheeks(P, face, 0.42)
    wings_bird(P, "3FB24A", spread=0.5, z=0.62, size=0.36)
    for i, a in enumerate((-30, -10, 10, 30)):
        leaf(P, "2E9A3E" if i % 2 else "4CC25A", body + Vector((0, -0.05, R[2] - 0.05)), length=0.5, width=0.09, rot=(0, math.radians(a), 0))
    for i, a in enumerate((-20, 0, 20)):
        sph(P, "E8322E" if i == 1 else "3FB24A", (0, -0.6, 0.45), 1, scale=(0.07, 0.12, 0.4), rot=(math.radians(-50), math.radians(a), 0))
    feet(P, "3A3A4A", TWO_FEET, r=0.1)


def tuna_dolphin(P):
    body = Vector((0, 0, 0.62))
    R = (0.42, 0.85, 0.42)
    sph(P, "4F86C6", body, 1, scale=R, seg=16, rings=10)
    sph(P, "DDE7F2", surface(body, R, 0, -30, 0.55), 1, scale=(0.3, 0.7, 0.22))
    nose = surface(body, R, 0, -5, 0.95)
    sph(P, "4F86C6", nose + Vector((0, 0.12, -0.05)), 1, scale=(0.15, 0.22, 0.12))
    head = Vector((0, 0.35, 0.72))
    eyes(P, head, (0.4, 0.45, 0.35), spread=48, pitch=10, size=0.11)
    cheeks(P, head, (0.4, 0.45, 0.35), spread=60, pitch=-15)
    flat(P, "3A6AA6", [(0, 0), (0.12, 0.38), (-0.18, 0.05)], 0.06, c=(0, -0.1, 1.0), rot=(0, 0, math.radians(90)))
    for side in (-1, 1):
        sph(P, "3A6AA6", (side * 0.42, 0.2, 0.35), 1, scale=(0.22, 0.12, 0.05), rot=(0, side * 0.5, side * 0.6))
    flat(P, "3A6AA6", [(-0.4, 0.15), (0, -0.05), (0.4, 0.15), (0.3, -0.12), (0, -0.2), (-0.3, -0.12)], 0.06, c=(0, -0.95, 0.72), rot=(math.radians(90), 0, 0))
    # Silver tuna stripe
    sph(P, "C9D4E0", surface(body, R, 90, 0, 0.92), 1, scale=(0.03, 0.55, 0.06), seg=8, rings=4)
    sph(P, "C9D4E0", surface(body, R, -90, 0, 0.92), 1, scale=(0.03, 0.55, 0.06), seg=8, rings=4)


def coral_kraken(P):
    head = Vector((0, 0, 1.0))
    R = (0.6, 0.55, 0.7)
    sph(P, "FF6F7F", head, 1, scale=R)
    eyes(P, head + Vector((0, 0, -0.1)), R, spread=28, pitch=-5, size=0.16)
    cheeks(P, head + Vector((0, 0, -0.15)), R, spread=50, pitch=-20)
    for i in range(8):
        a = i * 2 * math.pi / 8
        for k in range(5):
            t = k / 4
            r = 0.42 + t * 0.3
            p = Vector((math.sin(a) * r, math.cos(a) * r, 0.45 - t * 0.35 + (t * t) * 0.3))
            sph(P, "FF6F7F" if k < 4 else "FF9AA6", p, 0.13 - t * 0.06, seg=8, rings=6)
    for yaw, pitch in [(120, 30), (-130, 45), (170, 10), (60, 55), (-70, 60)]:
        sph(P, "FFD0D6", surface(head, R, yaw, pitch, 0.98), 0.07, seg=8, rings=6, kind="Neon")
    # Coral crown
    top = head + Vector((0, -0.1, R[2] - 0.05))
    for a, h in [(-0.5, 0.45), (0.0, 0.6), (0.5, 0.42)]:
        cyl(P, "FF9A3C", top + Vector((a * 0.3, 0, h * 0.5)), 0.05, h, rot=(0, a, 0), verts=6)
        sph(P, "FF9A3C", top + Vector((a * 0.3 + math.sin(a) * h * 0.5, 0, h * 0.95)), 0.08, seg=8, rings=6)


# ---------------------------------------------------------------- world 4 (Eis-Ei)


def ice_penguin(P):
    body = Vector((0, 0, 0.75))
    R = (0.5, 0.48, 0.72)
    sph(P, "2B3440", body, 1, scale=R)
    sph(P, WHITE, surface(body, R, 0, -5, 0.45), 1, scale=(0.38, 0.3, 0.6))
    face = Vector((0, 0.1, 1.05))
    eyes(P, face, 0.42, spread=24, pitch=6, size=0.12)
    cheeks(P, face, 0.42)
    beak(P, "FF9A2E", face, 0.42, pitch=-8, length=0.18, r=0.08)
    wings_bird(P, "2B3440", spread=0.5, z=0.7, size=0.36, angle=15)
    feet(P, "FF9A2E", TWO_FEET, r=0.14)
    # Ice-blue scarf and beanie
    torus(P, "6EC6F0", (0, 0, 0.98), 0.4, 0.08, seg=16)
    box(P, "6EC6F0", (0.25, 0.32, 0.82), (0.12, 0.05, 0.3), rot=(0, 0, 0.3))
    sph(P, "6EC6F0", (0, -0.02, 1.38), 1, scale=(0.38, 0.38, 0.2))
    sph(P, WHITE, (0, -0.02, 1.62), 0.1)


def snow_fox(P):
    head, R = critter(P, "F5FAFF", belly="FFFFFF", feet_color="CFE6F5", eye_size=0.14, nose="2B3440")
    pointed_ears(P, "F5FAFF", head, R, size=0.2, height=0.42, inner="BFE3F8")
    snout_long(P, WHITE, head, R, length=0.18, r=0.2, pitch=-18)
    # Big fluffy tail with blue tip
    for i in range(5):
        t = i / 4
        sph(P, "F5FAFF" if i < 4 else "9FD6F5", (0.1 * t, -0.55 - t * 0.35, 0.5 + t * 0.55), 0.22 + math.sin(t * math.pi) * 0.08)
    torus(P, "5AA9E6", (0, 0.1, 0.84), 0.3, 0.07, seg=14)


def pea_walrus(P):
    body = Vector((0, -0.1, 0.55))
    R = (0.6, 0.62, 0.52)
    sph(P, "8BC34A", body, 1, scale=R)
    head = Vector((0, 0.32, 1.0))
    Rh = 0.46
    sph(P, "8BC34A", head, Rh)
    eyes(P, head, Rh, spread=30, pitch=14, size=0.12)
    mz = surface(head, Rh, 0, -20, 0.85)
    for side in (-1, 1):
        sph(P, "B5DC7E", mz + Vector((side * 0.12, 0.05, 0)), 0.17)
        cone(P, WHITE, mz + Vector((side * 0.1, 0.12, -0.25)), 0.05, 0.01, 0.35, verts=6, rot=(math.radians(180), 0, 0))
        sph(P, "6FA63A", (side * 0.55, 0.15, 0.15), 1, scale=(0.25, 0.15, 0.06), rot=(0, 0, side * 0.5))
    sph(P, NOSE, mz + Vector((0, 0.12, 0.12)), 0.06)
    # Peas on top
    for i, p in enumerate([(0, -0.1, 1.48), (0.15, -0.05, 1.44), (-0.14, 0.0, 1.43)]):
        sph(P, "5FAE2E", p, 0.1)


def salmon_bear(P):
    head, R = critter(P, "8D5A3B", belly="C99470", feet_color="6E4229", muzzle="D9B08C")
    round_ears(P, "8D5A3B", head, R, size=0.16, spread=44, pitch=44, inner="C99470")
    # Salmon held in the arms
    fish = Vector((0, 0.5, 0.65))
    sph(P, "FA8A6E", fish, 1, scale=(0.4, 0.12, 0.15), seg=12, rings=8)
    flat(P, "E8705A", [(0, 0), (0.18, 0.15), (0.18, -0.15)], 0.04, c=fish + Vector((0.38, 0, 0)))
    sph(P, EYE, fish + Vector((-0.28, 0.1, 0.04)), 0.03, seg=6, rings=4)
    for side in (-1, 1):
        sph(P, "8D5A3B", (side * 0.32, 0.42, 0.6), 0.13)


def lettuce_yeti(P):
    head, R = critter(P, "F2F7F2", belly=WHITE, feet_color="D6E8D6", head_color="F2F7F2", muzzle="BFE6F0", nose="3A6A8A", body_r=(0.55, 0.5, 0.5))
    horns(P, "B8E8FF", head, R, spread=44, pitch=40, length=0.3, tilt=60, kind="Glass")
    # Lettuce leaf hair
    for i, (a, t) in enumerate([(-50, 0.2), (-20, 0.0), (15, -0.1), (45, 0.1), (0, -0.4), (-35, -0.35), (35, -0.3)]):
        leaf(P, "8FD45A" if i % 2 else "B6E86E", head + Vector((math.sin(math.radians(a)) * 0.25, -0.1 + t * 0.3, R * 0.75)), length=0.42, width=0.18, rot=(math.radians(-25 + t * 40), math.radians(a), 0))
    for side in (-1, 1):
        sph(P, "F2F7F2", (side * 0.5, 0.15, 0.5), 0.17, scale=(1, 1, 1.4))


def frost_phoenix(P):
    body = Vector((0, 0, 0.8))
    R = (0.42, 0.48, 0.55)
    sph(P, "8FD8FF", body, 1, scale=R)
    face = Vector((0, 0.12, 1.05))
    eyes(P, face, 0.4, spread=28, pitch=8, size=0.12)
    beak(P, "E8F6FF", face, 0.4, pitch=-6, length=0.2, r=0.08)
    for side in (-1, 1):
        for k in range(3):
            sph(P, "C8EEFF", (side * (0.5 + k * 0.18), -0.1, 0.95 + k * 0.12), 1, scale=(0.32, 0.08, 0.12), rot=(0, side * math.radians(-20 - k * 15), 0), kind="Glass")
    for i, a in enumerate((-25, 0, 25)):
        cone(P, "5AB8F0", (0, -0.05, R[2] + 0.95 + (0.1 if i == 1 else 0)), 0.06, 0.0, 0.35, rot=(math.radians(-15), math.radians(a), 0), verts=5)
    for i, a in enumerate((-30, 0, 30)):
        sph(P, "C8EEFF", (math.sin(math.radians(a)) * 0.2, -0.65, 0.55), 1, scale=(0.08, 0.25, 0.45), rot=(math.radians(-55), math.radians(a), 0), kind="Glass")
    ico(P, "E8FBFF", (0, 0.42, 0.65), 0.08, kind="Neon")
    feet(P, "5AB8F0", TWO_FEET, r=0.1)


# ---------------------------------------------------------------- world 5 (Vulkan-Ei)


def long_body(P, color, segments, r0, r1, z, length, belly=None):
    pts = []
    for i in range(segments):
        t = i / (segments - 1)
        y = 0.4 - t * length
        r = r0 + (r1 - r0) * t
        zz = z + math.sin(t * math.pi * 1.5) * 0.06
        pts.append((y, zz, r))
        sph(P, color, (0, y, zz), r, scale=(1, 1.2, 0.85), seg=12, rings=8)
    return pts


def lava_lizard(P):
    long_body(P, "4A3A3A", 5, 0.32, 0.12, 0.38, 1.3)
    head = Vector((0, 0.65, 0.55))
    R = (0.36, 0.42, 0.3)
    sph(P, "4A3A3A", head, 1, scale=R)
    eyes(P, head + Vector((0, 0, 0.05)), R, spread=32, pitch=12, size=0.12, sclera=WHITE)
    for yaw, pitch, y in [(90, 40, 0.3), (-90, 40, 0.0), (0, 80, 0.15), (60, 70, -0.25), (-60, 70, -0.5)]:
        sph(P, "FF7A1A", (math.sin(math.radians(yaw)) * 0.15, y, 0.62 - abs(y) * 0.15), 0.07, scale=(1, 1.4, 0.5), seg=8, rings=4, kind="Neon")
    for x, y in [(-0.3, 0.35), (0.3, 0.35), (-0.25, -0.2), (0.25, -0.2)]:
        sph(P, "3A2C2C", (x, y, 0.1), 0.11, scale=(1.4, 1, 0.6))
    spikes(P, "FF7A1A", n=4, y0=0.35, y1=-0.5, z=0.62, size=0.08, kind="Neon", curve=0.25)


def chili_salamander(P):
    long_body(P, "E8322E", 5, 0.3, 0.1, 0.38, 1.35)
    head = Vector((0, 0.65, 0.55))
    R = (0.38, 0.4, 0.32)
    sph(P, "E8322E", head, 1, scale=R)
    eyes(P, head + Vector((0, 0, 0.05)), R, spread=32, pitch=10, size=0.12, sclera=WHITE)
    cheeks(P, head, R, spread=60, pitch=-5)
    cyl(P, "3E9B3A", head + Vector((0, -0.1, 0.32)), 0.12, 0.08, verts=8)
    cyl(P, "3E9B3A", head + Vector((0, -0.2, 0.45)), 0.04, 0.25, rot=(-0.6, 0, 0), verts=6)
    for x, y in [(-0.3, 0.35), (0.3, 0.35), (-0.25, -0.25), (0.25, -0.25)]:
        sph(P, "C8261F", (x, y, 0.1), 0.11, scale=(1.4, 1, 0.6))
    for side in (-1, 1):
        for k in range(3):
            sph(P, "FFB02E", (side * 0.32, 0.25 - k * 0.22, 0.4), 0.05, seg=6, rings=4)


def magma_mole(P):
    head, R = critter(P, "7A5040", belly="9A7060", feet_color="FF7A1A", eye_size=0.09, nose=None, body_r=(0.52, 0.5, 0.46), sclera=WHITE)
    sph(P, "FF8FA8", surface(head, R, 0, -12, 1.02), 0.13, scale=(1.2, 0.9, 0.9))
    for side in (-1, 1):
        for k in range(3):
            cone(P, "FF7A1A", (side * (0.35 + k * 0.05), 0.48, 0.18 + k * 0.08), 0.04, 0.0, 0.15, rot=(math.radians(-70), 0, 0), verts=5, kind="Neon")
    # Hard hat with a lamp
    sph(P, "FFC21A", head + Vector((0, -0.02, R * 0.62)), 1, scale=(0.48, 0.5, 0.32))
    cyl(P, "FFC21A", head + Vector((0, 0.02, R * 0.62)), 0.52, 0.04, verts=14)
    cyl(P, "FFF6A0", head + Vector((0, R * 0.62, R * 0.88)), 0.08, 0.06, rot=(math.radians(70), 0, 0), verts=10, kind="Neon")


def jalapeno_golem(P):
    box(P, "3C8F3A", (0, 0, 0.62), (0.85, 0.65, 0.65), bevel=0.05)
    box(P, "4CAF50", (0, 0.05, 1.25), (0.62, 0.55, 0.55), bevel=0.05)
    for side in (-1, 1):
        box(P, "3C8F3A", (side * 0.58, 0.05, 0.55), (0.25, 0.3, 0.6), bevel=0.04)
        box(P, "2E7D32", (side * 0.25, 0, 0.12), (0.28, 0.32, 0.24), bevel=0.04)
        box(P, "FFF06A", (side * 0.14, 0.33, 1.3), (0.12, 0.04, 0.1), kind="Neon")
    box(P, "2E7D32", (0, 0.33, 1.12), (0.25, 0.03, 0.05))
    cyl(P, "6B4A2A", (0, -0.05, 1.6), 0.06, 0.18, verts=6)
    cone(P, "6B4A2A", (0.08, -0.05, 1.72), 0.05, 0.03, 0.15, rot=(0, 1.2, 0), verts=6)
    for x, z in [(-0.2, 0.75), (0.25, 0.5), (0.0, 0.4)]:
        box(P, "8EDB7A", (x, 0.33, z), (0.08, 0.03, 0.08))


def fire_wolf(P):
    head, R = critter(P, "8A2A2A", belly="C24A2A", feet_color="5A1A1A", nose="2A1010", eye_size=0.13, sclera=WHITE)
    pointed_ears(P, "8A2A2A", head, R, size=0.18, height=0.4, inner="FF9A3A")
    snout_long(P, "A83A30", head, R, length=0.2, r=0.2, pitch=-18, nose="2A1010")
    # Flame mane and tail
    for i, (yaw, pitch) in enumerate([(-50, 20), (50, 20), (-25, 70), (25, 70), (0, 85), (-80, -10), (80, -10)]):
        p = surface(head, R, yaw + 180 if pitch < 60 else yaw, pitch, 0.9)
        cone(P, "FF7A1A" if i % 2 else "FFC23A", p, 0.14, 0.0, 0.45, rot=(math.radians(-30), math.radians(yaw * 0.6), 0), verts=6, kind="Neon")
    for i in range(3):
        cone(P, "FF7A1A" if i != 1 else "FFC23A", (0, -0.55 - i * 0.05, 0.55 + i * 0.12), 0.18 - i * 0.04, 0.0, 0.5, rot=(math.radians(-50), 0, 0), verts=6, kind="Neon")


def lava_titan(P):
    ico(P, "3A2E2E", (0, -0.05, 0.62), 0.62, scale=(1, 0.85, 0.85), jit=0.05, seed=1)
    ico(P, "4A3A36", (0, 0.1, 1.32), 0.48, jit=0.04, seed=2)
    for side in (-1, 1):
        ico(P, "3A2E2E", (side * 0.72, 0.05, 0.75), 0.28, jit=0.04, seed=3 + side)
        ico(P, "3A2E2E", (side * 0.8, 0.15, 0.4), 0.24, jit=0.04, seed=5 + side)
        ico(P, "2E2424", (side * 0.3, 0, 0.18), 0.22, jit=0.03, seed=7 + side)
        box(P, "FFDA3A", (side * 0.16, 0.5, 1.38), (0.14, 0.05, 0.08), rot=(0, side * 0.2, 0), kind="Neon")
        horns(P, "2A2020", Vector((0, 0.1, 1.32)), 0.48, spread=38, pitch=50, length=0.45, r=0.1, tilt=40)
    box(P, "FF6A1A", (0, 0.5, 1.18), (0.22, 0.05, 0.05), kind="Neon")
    # Lava cracks
    for p, s, r in [((0.2, 0.5, 0.7), (0.06, 0.04, 0.35), 0.4), ((-0.25, 0.48, 0.55), (0.05, 0.04, 0.28), -0.5), ((0.0, 0.52, 0.45), (0.25, 0.04, 0.05), 0.1), ((0.7, 0.3, 0.75), (0.04, 0.04, 0.2), 0.3)]:
        box(P, "FF7A1A", p, s, rot=(0, r, 0), kind="Neon")
    ico(P, "FF7A1A", (0, -0.1, 1.78), 0.14, kind="Neon")


# ---------------------------------------------------------------- world 6 (Süßigkeiten-Ei)


def gummy_worm(P):
    colors = ["FF4F7A", "FFB02E", "FFE84A", "6FD65A", "4FB8FF", "B06AF0"]
    for i in range(6):
        t = i / 5
        y = -0.6 + t * 1.0
        z = 0.22 + math.sin(t * math.pi * 1.6) * 0.18 + (0.25 if i == 5 else 0)
        sph(P, colors[i], (0, y, z + (0.2 * t * t)), 0.24 + (0.06 if i == 5 else 0), kind="Glass")
    head = Vector((0, 0.4, 0.82))
    eyes(P, head, 0.3, spread=28, pitch=10, size=0.1)
    cheeks(P, head, 0.3, spread=50, pitch=-10, size=0.06)
    for side in (-1, 1):
        for k in range(4):
            sph(P, WHITE, (side * 0.2, -0.4 + k * 0.28, 0.45 + k * 0.08), 0.03, seg=6, rings=4)


def lollipop_poodle(P):
    head, R = critter(P, "FFB6D9", head_color="FFC8E2", feet_color="FF8FC4", nose="7A3A5A", eye_size=0.13, feet_spots=None)
    legs(P, "FFB6D9", FOUR_FEET, height=0.3, r=0.07)
    for x, y in FOUR_FEET:
        sph(P, "FF8FC4", (x, y, 0.12), 0.14)
    for yaw, pitch in [(0, 70), (-40, 50), (40, 50), (0, 40)]:
        ico(P, "FF9ACB", surface(head, R, yaw + (180 if yaw == 0 and pitch == 40 else 0), pitch, 0.95), 0.2, subdiv=1)
    for side in (-1, 1):
        ico(P, "FF8FC4", surface(head, R, side * 80, 0, 0.98), 0.2, scale=(0.7, 0.8, 1.3))
    # Lollipop tail
    cyl(P, WHITE, (0, -0.6, 0.75), 0.03, 0.5, rot=(math.radians(-30), 0, 0), verts=6)
    cyl(P, "FF4F8A", (0, -0.75, 1.05), 0.2, 0.06, rot=(math.radians(60), 0, 0), verts=16)
    torus(P, WHITE, (0, -0.72, 1.07), 0.12, 0.025, rot=(math.radians(60), 0, 0))


def marshmallow_sheep(P):
    for i, (x, y, z) in enumerate([(0, -0.05, 0.55), (0.3, 0, 0.5), (-0.3, 0, 0.5), (0, -0.35, 0.55), (0.25, -0.3, 0.8), (-0.25, -0.3, 0.8), (0, 0.05, 0.88)]):
        cyl(P, "FFF4F8" if i % 2 else "FFE0EC", (x, y, z), 0.26, 0.34, rot=(math.radians(90 if i % 3 else 0), 0, 0), verts=12)
    head = Vector((0, 0.42, 1.0))
    R = 0.36
    sph(P, "FFB3CC", head, R)
    eyes(P, head, R, spread=28, pitch=8, size=0.11)
    cheeks(P, head, R, size=0.07)
    cyl(P, WHITE, head + Vector((0, -0.05, 0.3)), 0.18, 0.18, verts=12)
    floppy_ears(P, "FF9ABA", head, R, size=0.14, spread=78, pitch=10)
    legs(P, "D98AA6", [(-0.22, 0.2), (0.22, 0.2), (-0.22, -0.3), (0.22, -0.3)], height=0.3, r=0.08)


def choco_bear(P):
    head, R = critter(P, "6B3E26", belly="A0643A", feet_color="4E2A18", muzzle="C08850", nose="2A1408")
    round_ears(P, "6B3E26", head, R, size=0.17, spread=44, pitch=44, inner="A0643A")
    # Chocolate bar squares on the belly
    for i in range(2):
        for k in range(2):
            box(P, "4E2A18", (-0.09 + i * 0.18, 0.4, 0.38 + k * 0.17), (0.15, 0.06, 0.14), bevel=0.02)
    # Drip of chocolate on the head
    sph(P, "4E2A18", head + Vector((0, -0.02, R * 0.72)), 1, scale=(0.4, 0.42, 0.2))
    for yaw in (-40, 0, 40):
        sph(P, "4E2A18", surface(head, R, yaw, 40, 0.98), 0.07, scale=(1, 1, 1.6), seg=8, rings=6)
    sph(P, "FF4F6A", head + Vector((0, -0.02, R * 0.98)), 0.1)


def cotton_candy_unicorn(P):
    head, R = critter(P, "FFFFFF", belly="FFF0FA", feet_spots=None, nose="FF8FB8", muzzle="FFE6F2", eye_size=0.14)
    legs(P, "FFFFFF", FOUR_FEET, height=0.32, r=0.09, hoof="C8A2FF")
    pointed_ears(P, WHITE, head, R, size=0.12, height=0.3, spread=40, pitch=55, inner="FFC2E0")
    # Spiral golden horn
    hpos = surface(head, R, 0, 55, 0.95)
    cone(P, "FFD24A", hpos + Vector((0, 0.05, 0.25)), 0.1, 0.0, 0.55, rot=(math.radians(15), 0, 0), verts=8, kind="Metal")
    for k in range(3):
        torus(P, "FFE89A", hpos + Vector((0, 0.03 + k * 0.03, 0.08 + k * 0.13)), 0.08 - k * 0.022, 0.018, rot=(math.radians(15), 0, 0), kind="Metal")
    # Cotton candy mane and tail
    for i, (y, z, c) in enumerate([(0.0, 1.62, "FFB3DE"), (-0.18, 1.48, "B3E0FF"), (-0.32, 1.28, "FFB3DE"), (-0.4, 1.02, "D8B3FF")]):
        ico(P, c, (0, y, z), 0.2, subdiv=2, jit=0.03, seed=i)
    for i, c in enumerate(["FFB3DE", "B3E0FF", "D8B3FF"]):
        ico(P, c, (0, -0.6 - i * 0.08, 0.6 + i * 0.12), 0.18 - i * 0.02, subdiv=2, jit=0.03, seed=10 + i)


def caramel_griffin(P):
    sph(P, "D9963A", BODY, 1, scale=(0.48, 0.58, 0.44))
    legs(P, "D9963A", [(-0.24, -0.35), (0.24, -0.35)], height=0.3, r=0.1)
    feet(P, "FFC24A", [(-0.24, 0.28), (0.24, 0.28)], r=0.14)
    head = Vector((0, 0.2, 1.2))
    R = 0.48
    sph(P, "FFF2D8", head, R)
    eyes(P, head, R, spread=28, pitch=8, size=0.14)
    beak(P, "FFC24A", head, R, pitch=-10, length=0.25, r=0.11)
    cheeks(P, head, R)
    for yaw in (-35, 0, 35):
        sph(P, "FFF2D8", surface(head, R, yaw + 180, 40, 0.95), 1, scale=(0.08, 0.12, 0.3), rot=(math.radians(-40), 0, 0))
    wings_dragon(P, "B8742A", z=0.85, y=-0.25, span=0.8)
    tail_curve(P, "D9963A", r=0.06, up=0.4, length=0.7, tip="8A4E1A")
    # Caramel drizzle
    for yaw, pitch in [(150, 55), (-150, 50), (180, 70)]:
        sph(P, "8A4E1A", surface(BODY, (0.48, 0.58, 0.44), yaw, pitch, 0.97), 0.1, scale=(1.5, 1, 0.4), kind="Glass")


# ---------------------------------------------------------------- world 7 (Weltraum-Ei)


def moon_mouse(P):
    head, R = critter(P, "D6D8E0", belly="ECEEF4", feet_color="B8BAC6", nose="FF9AB8")
    round_ears(P, "D6D8E0", head, R, size=0.27, spread=46, pitch=40, inner="B8BAC6")
    for yaw, pitch, s in [(-40, 30, 0.08), (50, 50, 0.06), (130, 20, 0.1), (-120, 10, 0.08), (170, 40, 0.07)]:
        target = head if abs(yaw) < 60 else Vector(BODY)
        radii = R if abs(yaw) < 60 else BODY_R
        torus(P, "A8AAB8", surface(target, radii, yaw, pitch, 0.98), s, 0.02, rot=(math.radians(90 - pitch), 0, -math.radians(yaw)), seg=10, mseg=4)
    tail_curve(P, "B8BAC6", r=0.04, up=0.5, length=0.9)
    # Tiny antenna with a star
    cyl(P, "8890A8", head + Vector((0.15, 0, R * 1.0)), 0.02, 0.3, verts=6, rot=(0, 0.3, 0))
    sph(P, "FFE66A", head + Vector((0.2, 0, R * 1.0 + 0.18)), 0.06, kind="Neon")


def star_cat(P):
    head, R = critter(P, "2E3A7A", belly="4A5AA8", feet_color="222C60", nose="FF9AD0", eye_size=0.13, sclera=WHITE)
    pointed_ears(P, "2E3A7A", head, R, inner="8A9AF0")
    flat(P, "FFE66A", star_points(0.14, 0.06), 0.04, c=surface(head, R, 0, 35, 1.0), rot=(math.radians(-35), 0, 0), kind="Neon")
    tail_curve(P, "2E3A7A", r=0.07, up=0.6, tip="2E3A7A")
    flat(P, "FFE66A", star_points(0.16, 0.07), 0.05, c=(0, -0.95, 0.95), kind="Neon")
    for yaw, pitch in [(120, 30), (-130, 50), (170, 0), (80, -10)]:
        sph(P, "FFFFFF", surface(BODY, BODY_R, yaw, pitch, 0.99), 0.03, seg=6, rings=4, kind="Neon")


def alien_frog(P):
    body = Vector((0, 0, 0.45))
    R = (0.55, 0.5, 0.42)
    sph(P, "7CF05A", body, 1, scale=R)
    sph(P, "C8FFA8", surface(body, R, 0, -20, 0.6), 1, scale=(0.38, 0.3, 0.25))
    for side in (-1, 1):
        e = Vector((side * 0.25, 0.15, 0.85))
        sph(P, "7CF05A", e, 0.2)
        sph(P, EYE, e + Vector((0, 0.13, 0.02)), 0.12, scale=(1, 0.6, 1.1))
        sph(P, WHITE, e + Vector((-side * 0.03, 0.2, 0.07)), 0.04)
        cyl(P, "5AC83A", (side * 0.12, 0.0, 1.05), 0.02, 0.35, rot=(0, side * 0.3, 0), verts=6)
        sph(P, "E86AFF", (side * 0.17, 0.0, 1.24), 0.07, kind="Neon")
        sph(P, "5AC83A", (side * 0.45, 0.25, 0.08), 0.15, scale=(1.3, 1.3, 0.4))
        sph(P, "5AC83A", (side * 0.48, -0.25, 0.12), 0.2, scale=(1, 1.6, 0.6))
    cheeks(P, body + Vector((0, 0, 0.1)), R, spread=45, pitch=0)
    for yaw, pitch in [(140, 40), (-150, 30), (180, 60), (100, 50)]:
        sph(P, "3ADF9A", surface(body, R, yaw, pitch, 0.98), 0.06, scale=(1, 1, 0.5), seg=8, rings=4, kind="Neon")


def rocket_dog(P):
    head, R = critter(P, "F5F0E6", belly=WHITE, feet_color="D8CFC0", muzzle=WHITE, eye_size=0.14)
    floppy_ears(P, "C89A6A", head, R, size=0.18, spread=70, pitch=30)
    sph(P, "C89A6A", surface(head, R, -40, 30, 0.97), 0.18, scale=(1, 0.4, 1))
    # Glass helmet
    sph(P, "BFE8FF", head, R * 1.28, seg=16, rings=10, kind="Glass")
    torus(P, "8890A8", head - Vector((0, 0, R * 0.95)), R * 0.95, 0.06, seg=16)
    # Rocket backpack with flame
    back = Vector((0, -0.55, 0.6))
    for side in (-1, 1):
        cyl(P, "E8322E", back + Vector((side * 0.17, 0, 0)), 0.13, 0.55, verts=10)
        cone(P, "E8322E", back + Vector((side * 0.17, 0, 0.38)), 0.13, 0.0, 0.22, verts=10)
        cone(P, "FFB02E", back + Vector((side * 0.17, 0, -0.42)), 0.1, 0.0, 0.3, rot=(math.pi, 0, 0), verts=8, kind="Neon")
    box(P, "8890A8", back + Vector((0, 0.08, 0.05)), (0.3, 0.12, 0.3))


def comet_whale(P):
    body = Vector((0, 0, 0.7))
    R = (0.55, 0.85, 0.52)
    sph(P, "3A6AE8", body, 1, scale=R, seg=16, rings=10)
    sph(P, "BFD4FF", surface(body, R, 0, -35, 0.5), 1, scale=(0.4, 0.65, 0.25))
    head = Vector((0, 0.35, 0.82))
    eyes(P, head, (0.5, 0.5, 0.38), spread=55, pitch=5, size=0.11)
    cheeks(P, head, (0.5, 0.5, 0.38), spread=65, pitch=-15)
    for side in (-1, 1):
        sph(P, "2E56C8", (side * 0.55, 0.15, 0.4), 1, scale=(0.28, 0.14, 0.06), rot=(0, side * 0.4, side * 0.5))
    flat(P, "2E56C8", [(-0.45, 0.2), (0, -0.05), (0.45, 0.2), (0.32, -0.1), (0, -0.2), (-0.32, -0.1)], 0.06, c=(0, -0.95, 0.85), rot=(math.radians(70), 0, 0))
    # Comet trail and spout
    for i in range(4):
        sph(P, ["FFE66A", "FFB02E", "FF7A3A", "FF4F7A"][i], (0, -1.05 - i * 0.2, 1.0 + i * 0.12), 0.14 - i * 0.025, kind="Neon")
    for i, a in enumerate((-0.4, 0, 0.4)):
        sph(P, "BFF4FF", (math.sin(a) * 0.15, 0.1, 1.3 + (0.1 if i == 1 else 0)), 0.07, kind="Neon")
    for yaw, pitch in [(120, 40), (-120, 40), (170, 20), (90, 60), (-80, 65)]:
        sph(P, WHITE, surface(body, R, yaw, pitch, 0.99), 0.035, seg=6, rings=4, kind="Neon")


def galaxy_dragon(P):
    head, R = critter(P, "4A2A8A", belly="8A6AE8", feet_color="2E1A5A", muzzle="6A4AB8", nose="1A0E30", eye_size=0.13, sclera=WHITE)
    horns(P, "E8D2FF", head, R, length=0.35, kind="Neon")
    wings_dragon(P, "2E1A5A", span=0.85)
    spikes(P, "C86AFF", n=4, y0=0.0, y1=-0.45, z=0.95, curve=0.35, kind="Neon")
    tail_curve(P, "4A2A8A", r=0.09, up=0.25, length=0.8, tip="C86AFF")
    for yaw, pitch in [(130, 30), (-140, 40), (170, 0), (100, -10), (-90, 15), (60, 50)]:
        flat(P, "FFF2A0", star_points(0.06, 0.025), 0.02, c=surface(BODY, BODY_R, yaw, pitch, 1.0), rot=(0, 0, -math.radians(yaw)), kind="Neon")
    flat(P, "FFF2A0", star_points(0.1, 0.04), 0.03, c=surface(head, R, 40, 40, 1.0), rot=(math.radians(-40), 0, -math.radians(40)), kind="Neon")


# ---------------------------------------------------------------- registry

EGGS = {
    "GardenEgg": ["DoughHamster", "BasilBunny", "TomatoCat", "CheeseMouse", "OliveOwl", "PizzaDragon"],
    "FarmEgg": ["FarmChick", "CornPiglet", "PepperGoat", "OnionCow", "HayHorse", "GoldenRooster"],
    "BeachEgg": ["SandCrab", "ShellTurtle", "ShrimpSeal", "PineappleParrot", "TunaDolphin", "CoralKraken"],
    "IceEgg": ["IcePenguin", "SnowFox", "PeaWalrus", "SalmonBear", "LettuceYeti", "FrostPhoenix"],
    "VolcanoEgg": ["LavaLizard", "ChiliSalamander", "MagmaMole", "JalapenoGolem", "FireWolf", "LavaTitan"],
    "CandyEgg": ["GummyWorm", "LollipopPoodle", "MarshmallowSheep", "ChocoBear", "CottonCandyUnicorn", "CaramelGriffin"],
    "SpaceEgg": ["MoonMouse", "StarCat", "AlienFrog", "RocketDog", "CometWhale", "GalaxyDragon"],
}

# Background / ground colours of the egg sheets (match the world look).
SHEET_COLORS = {
    "GardenEgg": ("FFECC8", "96D778"),
    "FarmEgg": ("FFE6B0", "C4AA64"),
    "BeachEgg": ("C8F0FF", "F0DCA0"),
    "IceEgg": ("DDF0FF", "E6F4FC"),
    "VolcanoEgg": ("5A3030", "463737"),
    "CandyEgg": ("FFE0F0", "FFBEDC"),
    "SpaceEgg": ("1E1E3C", "8C8CA0"),
}


def _snake(name):
    out = ""
    for i, ch in enumerate(name):
        if ch.isupper() and i > 0:
            out += "_"
        out += ch.lower()
    return out


PETS = {pet: globals()[_snake(pet)] for pets in EGGS.values() for pet in pets}

# ---------------------------------------------------------------- render


def reset_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    _materials.clear()


def build(name, offset=(0, 0, 0)):
    before = set(bpy.context.scene.objects)
    P = Pet()
    PETS[name](P)
    P.finish()
    objs = [o for o in set(bpy.context.scene.objects) - before if o.type == "MESH"]
    for o in objs:
        o.location = Vector(offset) + o.location
    return objs


def bounds(objs):
    bpy.context.view_layer.update()
    lo = Vector((1e9, 1e9, 1e9))
    hi = Vector((-1e9, -1e9, -1e9))
    for o in objs:
        for corner in o.bound_box:
            w = o.matrix_world @ Vector(corner)
            lo = Vector(map(min, lo, w))
            hi = Vector(map(max, hi, w))
    return lo, hi


def render(objs, path, size, background, ground=None, distance=2.6, yaw=-28, lift=0.35, samples=40):
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = samples
    scene.cycles.use_denoising = True
    scene.render.resolution_x = size[0]
    scene.render.resolution_y = size[1]
    scene.render.film_transparent = background is None
    scene.render.image_settings.color_mode = "RGBA" if background is None else "RGB"
    scene.view_settings.view_transform = "Standard"

    world = bpy.data.worlds.new("World")
    scene.world = world
    world.use_nodes = True
    bg = world.node_tree.nodes["Background"]
    bg.inputs["Color"].default_value = hex_rgba(background or "FFF4E0")
    bg.inputs["Strength"].default_value = 0.9

    lo, hi = bounds(objs)
    center = (lo + hi) / 2
    radius = max((hi - lo).length / 2, 0.5)

    if ground:
        bpy.ops.mesh.primitive_plane_add(size=radius * 14, location=(center.x, center.y, lo.z))
        g = bpy.context.active_object
        gmat = bpy.data.materials.new("Ground")
        gmat.use_nodes = True
        gmat.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = hex_rgba(ground)
        g.data.materials.append(gmat)

    bpy.ops.object.light_add(type="SUN", rotation=(math.radians(45), math.radians(10), math.radians(-30)))
    sun = bpy.context.active_object
    sun.data.energy = 3.2
    sun.data.angle = math.radians(10)
    bpy.ops.object.light_add(type="SUN", rotation=(math.radians(60), 0, math.radians(150)))
    bpy.context.active_object.data.energy = 0.8

    direction = Vector((0.0, 1.0, 0.0))
    direction.rotate(Euler((0, 0, math.radians(yaw))))
    cam_pos = center + direction * radius * distance + Vector((0, 0, radius * distance * lift))
    bpy.ops.object.camera_add(location=cam_pos)
    cam = bpy.context.active_object
    cam.data.lens = 50
    cam.rotation_euler = (center - cam_pos).to_track_quat("-Z", "Y").to_euler()
    scene.camera = cam
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)


def export_pet(name):
    reset_scene()
    objs = build(name)
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
    render(objs, os.path.join(PREVIEW_DIR, f"{name}.png"), (384, 384), None, distance=2.35, yaw=-22, lift=0.25)
    print(f"built {name}: {sorted(o.name for o in objs)}")


def egg_sheet(egg):
    reset_scene()
    objs = []
    for i, name in enumerate(EGGS[egg]):
        # Camera looks from +Y, so +X is on the left: first pet (most common) on the left.
        objs += build(name, offset=((2.5 - i) * 1.75, 0, 0))
    sky, ground = SHEET_COLORS[egg]
    render(objs, os.path.join(PREVIEW_DIR, f"{egg}.png"), (1200, 400), sky, ground=ground, distance=2.95, yaw=0, lift=0.14, samples=48)
    print(f"sheet {egg}")


if __name__ == "__main__":
    args = sys.argv[1:]
    pets = [a for a in args if a in PETS]
    eggs = [a for a in args if a in EGGS]
    if not args:
        pets = list(PETS)
        eggs = list(EGGS)
    for p in pets:
        export_pet(p)
    for e in eggs:
        egg_sheet(e)
