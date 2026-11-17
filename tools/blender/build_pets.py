"""Builds the 70 low-poly cartoon pets (all eggs) and renders their preview images.

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
from mathutils import Euler, Matrix, Vector

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


# ---------------------------------------------------------------- helpers for the second eggs (#40)


def aim(direction):
    """Rotation that turns +Z (the axis of cylinders and cones) towards `direction`."""
    return Vector((0, 0, 1)).rotation_difference(Vector(direction).normalized()).to_euler()


def at(c, rot, v):
    """Point `v` given in the local frame of something at `c` turned by `rot`."""
    return Vector(c) + Euler(rot).to_matrix() @ Vector(v)


def facing(yaw, pitch):
    """Rotation that turns local +Y outwards at (yaw, pitch) of `surface`, local +Z along the meridian."""
    return (math.radians(pitch), 0, -math.radians(yaw))


def stick(P, h, a, b, r, r2=None, verts=8, kind=None):
    a, b = Vector(a), Vector(b)
    d = b - a
    if r2 is None:
        return cyl(P, h, (a + b) / 2, r, d.length, rot=aim(d), verts=verts, kind=kind)
    return cone(P, h, (a + b) / 2, r, r2, d.length, rot=aim(d), verts=verts, kind=kind)


def chain(P, colors, points, radii, kind=None):
    for i, p in enumerate(points):
        r = radii[i] if isinstance(radii, (list, tuple)) else radii
        sph(P, colors[i % len(colors)], p, r, seg=10, rings=7, kind=kind)


def lobed_leaf(P, h, c, length=0.34, width=0.12, rot=(0, 0, 0), lobes=3, kind=None):
    """Leaf with a wavy edge (rocket/rucola), pointing along local +Z."""
    n = lobes * 2 + 1
    right = []
    for i in range(1, n + 1):
        t = i / (n + 1)
        right.append((math.sin(t * math.pi) * width * (1.0 if i % 2 else 0.55), t * length))
    pts = [(0, 0)] + right + [(0, length)] + [(-x, z) for x, z in reversed(right)]
    return flat(P, h, pts, 0.03, c=c, rot=rot, kind=kind)


def scallop(P, h, c, size, rot=(0, 0, 0), rib=None, thickness=0.05):
    """Scallop shell: a fan opening along local +Z, flat side facing ±Y."""
    pts = [(size * 0.14, -size * 0.12)]
    for i in range(13):
        a = math.radians(15 + i * 12.5)
        r = size * (1.0 if i % 2 == 0 else 0.92)
        pts.append((math.cos(a) * r, math.sin(a) * r))
    pts.append((-size * 0.14, -size * 0.12))
    flat(P, h, pts, thickness, c=c, rot=rot)
    if rib:
        base = Euler(rot).to_matrix()
        for k in range(5):
            ang = math.radians(35 + k * 27.5)
            for side in (-1, 1):
                mid = at(c, rot, (math.cos(ang) * size * 0.5, side * thickness * 0.55, math.sin(ang) * size * 0.5))
                turn = (base @ Matrix.Rotation(-ang, 3, "Y")).to_euler()
                box(P, rib, mid, (size * 0.8, 0.02, 0.03), rot=turn)


def wheat_ear(P, base, direction, length=0.45, grain="FFD24A", stem="C89A3A", kind="Metal"):
    d = Vector(direction).normalized()
    base = Vector(base)
    side = d.cross(Vector((0, 1, 0)))
    if side.length < 0.1:
        side = d.cross(Vector((1, 0, 0)))
    side.normalize()
    stick(P, stem, base, base + d * length * 0.45, 0.018, verts=5)
    for k in range(5):
        p = base + d * length * (0.45 + k * 0.1)
        for s in (-1, 1):
            sph(P, grain, p + side * s * 0.035, 0.045, scale=(0.75, 0.75, 1.4), rot=aim(d + side * s * 0.5), seg=8, rings=5, kind=kind)
    sph(P, grain, base + d * length * 0.98, 0.04, scale=(0.75, 0.75, 1.4), rot=aim(d), seg=8, rings=5, kind=kind)


def crescent_points(r, off=0.38):
    """Crescent moon (bulging to the left) as 2D points."""
    s60 = math.sin(math.radians(60))
    ri = math.hypot(0.5 - off, s60) * r
    a_in = math.degrees(math.atan2(s60, 0.5 - off))
    pts = []
    for i in range(11):
        a = math.radians(60 + i * 24)
        pts.append((math.cos(a) * r, math.sin(a) * r))
    for i in range(1, 10):
        a = math.radians(360 - a_in - i * (360 - 2 * a_in) / 10)
        pts.append((off * r + math.cos(a) * ri, math.sin(a) * ri))
    return pts


def stripe(P, h, center, radii, yaw, pitch, length, width=0.035, across=False, kind=None):
    """Thin stripe lying on an ellipsoid; along the meridian, or along the latitude if `across`."""
    scale = (length, 0.025, width) if across else (width, 0.025, length)
    sph(P, h, surface(center, radii, yaw, pitch, 0.98), 1, scale=scale, rot=facing(yaw, pitch), seg=10, rings=6, kind=kind)


def paws(P, h, y, z, spread=0.27, r=0.12):
    for side in (-1, 1):
        sph(P, h, (side * spread, y, z), r)


# ---------------------------------------------------------------- world 1, second egg (Steinofen-Ei)


def rucola_hedgehog(P):
    head, R = critter(P, "9A6A44", belly="F2DDBE", head_color="E8C9A0", feet_color="6E4A30", nose=None, eye_size=0.14)
    snout_long(P, "F2DDBE", head, R, length=0.26, r=0.15, pitch=-14)
    round_ears(P, "C99A70", head, R, size=0.1, spread=62, pitch=30, inner="FFC2B0")
    # Rocket leaves as spines: a crown on the head and all over the back.
    greens = ["3F8F3A", "5DB04A", "2E7A32"]
    spots = [(Vector(BODY), BODY_R, yaw, pitch) for yaw in (90, 125, 160, 200, 235, 270) for pitch in (-5, 25, 55)]
    spots += [(head, (R, R, R), yaw, pitch) for yaw in (100, 135, 180, 225, 260) for pitch in (20, 50)]
    spots += [(head, (R, R, R), yaw, 72) for yaw in (-60, -30, 0, 30, 60)]
    spots += [(head, (R, R, R), yaw, 45) for yaw in (-80, 80)]
    for i, (center, radii, yaw, pitch) in enumerate(spots):
        pos = surface(center, radii, yaw, pitch, 0.85)
        d = (pos - Vector(center)).normalized() + Vector((0, -0.6, 0.45))
        lobed_leaf(P, greens[i % 3], pos, length=0.42, width=0.12, rot=aim(d))


def parmesan_raccoon(P):
    fur = "8E8E98"
    head, R = critter(P, fur, belly="D8D8E0", feet_color="4A4A54", muzzle="F0F0F4", nose="22222A", eye_size=0.14)
    round_ears(P, fur, head, R, size=0.16, spread=40, pitch=48, inner="F0F0F4")
    # Bandit mask behind the eyes and a white blaze above.
    for side in (-1, 1):
        sph(P, "33333D", surface(head, R, side * 30, 6, 0.86), 0.2, scale=(1.35, 0.4, 0.85), rot=(0, 0, -math.radians(side * 30)))
    sph(P, "F0F0F4", surface(head, R, 0, 42, 0.93), 0.11, scale=(0.6, 0.4, 1.0), rot=facing(0, 42))
    # Ringed tail
    for i in range(6):
        t = i / 5
        sph(P, fur if i % 2 == 0 else "33333D", (0, -0.5 - t * 0.38, 0.32 + t * 0.6), 0.17 - t * 0.03)
    # Wedge of parmesan with its rind, held in both paws
    wedge = Vector((0, 0.58, 0.5))
    flat(P, "F7E7A8", [(-0.24, -0.1), (0.24, -0.1), (0.03, 0.22)], 0.2, c=wedge)
    box(P, "D9A43E", wedge + Vector((0, 0, -0.12)), (0.5, 0.22, 0.05), bevel=0.01)
    for x, z in [(-0.08, 0.0), (0.06, 0.06), (0.0, -0.05)]:
        sph(P, "FFF6D2", wedge + Vector((x, 0.1, z)), 0.025, seg=6, rings=4)
    paws(P, "4A4A54", 0.55, 0.5, spread=0.27, r=0.1)


def truffle_fox(P):
    fur = "E8782E"
    head, R = critter(P, fur, belly="FFF2E0", feet_color="4A2A1C", nose="2A1A10", eye_size=0.14)
    pointed_ears(P, fur, head, R, size=0.2, height=0.42, inner="FFF2E0")
    snout_long(P, "FFF2E0", head, R, length=0.18, r=0.2, pitch=-18, nose="2A1A10")
    for i in range(5):
        t = i / 4
        sph(P, fur if i < 4 else "FFF2E0", (-0.1 * t, -0.55 - t * 0.35, 0.5 + t * 0.55), 0.22 + math.sin(t * math.pi) * 0.08)
    # Plate (tilted to the viewer) with a black truffle and two slices
    plate = Vector((0, 0.6, 0.44))
    rot = (math.radians(-25), 0, 0)
    cyl(P, WHITE, plate, 0.28, 0.04, rot=rot, verts=18)
    ico(P, "3A2A22", at(plate, rot, (-0.06, -0.02, 0.13)), 0.14, subdiv=2, jit=0.025, seed=4)
    for k, (x, y) in enumerate([(0.13, 0.06), (0.15, -0.07)]):
        cyl(P, "8A6A52", at(plate, rot, (x, y, 0.035 + k * 0.015)), 0.08, 0.02, rot=rot, verts=12)
        cyl(P, "C8AA92", at(plate, rot, (x, y, 0.046 + k * 0.015)), 0.04, 0.005, rot=rot, verts=10)
    paws(P, "4A2A1C", 0.55, 0.48, spread=0.3, r=0.1)


def stone_oven_phoenix(P):
    body = Vector((0, -0.05, 0.6))
    Rb = (0.5, 0.5, 0.56)
    sph(P, "C8B4A0", body, 1, scale=Rb)
    # Bricks on the dome, leaving room for the oven mouth
    for pitch, n, off in ((-12, 9, 0), (18, 8, 22), (46, 6, 0)):
        for i in range(n):
            yaw = off + i * 360 / n
            if abs(((yaw + 180) % 360) - 180) < 45 and pitch < 30:
                continue
            box(P, "A8927E", surface(body, Rb, yaw, pitch, 0.97), (0.17, 0.07, 0.08), rot=facing(yaw, pitch))
    mouth = surface(body, Rb, 0, -14, 0.9)
    arch = [(-0.2, -0.14), (0.2, -0.14)] + [(math.cos(math.radians(a)) * 0.2, 0.04 + math.sin(math.radians(a)) * 0.2) for a in range(0, 181, 20)]
    flat(P, "6A5A50", [(x * 1.3, z * 1.25) for x, z in arch], 0.12, c=mouth)
    flat(P, "FF8A2A", arch, 0.06, c=mouth + Vector((0, 0.06, 0)), kind="Neon")
    # Chimney with a puff of smoke
    cyl(P, "8A7A6E", (0.12, -0.32, 1.08), 0.08, 0.3, verts=8)
    ico(P, "E8E2DA", (0.16, -0.36, 1.33), 0.08, jit=0.01, seed=7)
    # Fiery bird head
    head = Vector((0, 0.1, 1.32))
    Rh = 0.36
    sph(P, "FF9A3A", head, Rh)
    eyes(P, head, Rh, spread=30, pitch=6, size=0.12)
    cheeks(P, head, Rh, size=0.07)
    beak(P, "FFD24A", head, Rh, pitch=-8, length=0.18, r=0.08)
    for a, c in ((-28, "FF6A1A"), (0, "FFC23A"), (28, "FF6A1A")):
        d = Vector((math.sin(math.radians(a)) * 0.6, -0.45, 1))
        cone(P, c, head + Vector((math.sin(math.radians(a)) * 0.1, -0.08, Rh * 0.8)) + d.normalized() * 0.2, 0.08, 0.0, 0.42, rot=aim(d), verts=6, kind="Neon")
    # Flame wings and tail
    for side in (-1, 1):
        for k, c in enumerate(("FF6A1A", "FFA02A", "FFD24A")):
            d = Vector((side * 1.0, -0.3, 0.4 + k * 0.4))
            sph(P, c, Vector((side * 0.42, -0.1, 0.78)) + d.normalized() * 0.3, 1, scale=(0.09, 0.09, 0.32), rot=aim(d), kind="Neon")
    for k, c in enumerate(("FFA02A", "FF6A1A", "FFD24A")):
        d = Vector(((k - 1) * 0.5, -1, 0.5))
        sph(P, c, Vector((0, -0.5, 0.55)) + d.normalized() * 0.3, 1, scale=(0.08, 0.08, 0.34), rot=aim(d), kind="Neon")
    feet(P, "FFD24A", TWO_FEET, r=0.12)


# ---------------------------------------------------------------- world 2, second egg (Scheunen-Ei)


def pumpkin_cat(P):
    head, R = critter(P, "F28A1E", head_color="F59A3A", feet_color="C86A14", nose="7A3A10", eye_size=0.14)
    pointed_ears(P, "F59A3A", head, R, inner="FFD0A0")
    # Pumpkin body: ribbed lobes around the middle
    for i in range(8):
        a = math.radians(i * 45)
        sph(P, "F28A1E" if i % 2 else "D86410", (math.sin(a) * 0.22, BODY[1] + math.cos(a) * 0.22, BODY[2]), 1, scale=(0.25, 0.22, 0.43), rot=(0, 0, -a))
    for i in range(8):
        a = math.radians(i * 45 + 22.5)
        stripe(P, "B8500C", BODY, BODY_R, math.degrees(a), 0, 0.22, width=0.03)
    # Stem with a leaf and a curly vine tail
    top = head + Vector((0, -0.05, R * 0.95))
    stick(P, "6A7A2A", top, top + Vector((0.05, -0.04, 0.2)), 0.05, r2=0.035, verts=6)
    leaf(P, "4E9A3A", top + Vector((0.04, -0.02, 0.08)), length=0.28, width=0.11, rot=(math.radians(-20), math.radians(55), 0))
    tail_curve(P, "5A9A3A", r=0.045, up=0.6, length=0.8)
    leaf(P, "4E9A3A", (0, -1.0, 0.95), length=0.2, width=0.08, rot=(math.radians(30), 0, 0))


def butter_donkey(P):
    fur = "A8A2AE"
    sph(P, fur, (0, -0.1, 0.72), 1, scale=(0.45, 0.6, 0.42))
    sph(P, "E6E2EA", (0, 0.25, 0.62), 1, scale=(0.3, 0.28, 0.28))
    legs(P, fur, [(-0.24, 0.3), (0.24, 0.3), (-0.24, -0.45), (0.24, -0.45)], height=0.5, r=0.1, hoof="4A4048")
    head = Vector((0, 0.42, 1.35))
    R = 0.42
    sph(P, fur, head, R)
    snout_long(P, "E6E2EA", head, R, length=0.22, r=0.25, pitch=-25)
    eyes(P, head, R, spread=34, pitch=12, size=0.12)
    cheeks(P, head, R, size=0.07)
    long_ears(P, fur, head, R, length=0.4, width=0.11, spread=34, inner="F0C0C8", droop=(14, -4))
    for i in range(4):
        ico(P, "FFE070", (0, 0.1 - i * 0.14, 1.72 - i * 0.16), 0.1, jit=0.02, seed=20 + i)
    stick(P, fur, (0, -0.65, 0.85), (0, -0.82, 0.55), 0.035)
    ico(P, "5A5260", (0, -0.84, 0.5), 0.08, jit=0.02, seed=25)
    # Butter dish on the back and a melting pat on the head
    dish = Vector((0, -0.2, 1.13))
    cyl(P, "8EC8F0", dish, 0.32, 0.05, verts=18)
    box(P, "FFE070", dish + Vector((0, 0, 0.11)), (0.36, 0.22, 0.17), bevel=0.03)
    box(P, "FFF2B0", dish + Vector((0.06, 0.02, 0.21)), (0.14, 0.12, 0.04), bevel=0.01)
    top = head + Vector((0, 0.06, R * 0.95))
    box(P, "FFE070", top + Vector((0, 0, 0.04)), (0.3, 0.24, 0.15), rot=(0.12, 0, 0.15), bevel=0.03)
    box(P, "FFF2B0", top + Vector((0.03, 0.02, 0.13)), (0.12, 0.1, 0.04), rot=(0.12, 0, 0.4), bevel=0.01)
    for x, y in ((0.1, 0.13), (-0.09, 0.12), (0.0, 0.14)):
        sph(P, "FFE070", top + Vector((x, y, -0.05)), 0.045, scale=(1, 1, 1.8))


def honey_bear(P):
    fur = "E0A040"
    head, R = critter(P, fur, belly="FFD88A", feet_color="B07A28", muzzle="FFE6B0", nose="4A2A10")
    round_ears(P, fur, head, R, size=0.16, spread=44, pitch=44, inner="FFD88A")
    # Honey dripping from the head
    sph(P, "FFB41E", head + Vector((0, -0.02, R * 0.84)), 1, scale=(0.3, 0.3, 0.14))
    for yaw in (-32, 22):
        sph(P, "FFB41E", surface(head, R, yaw, 50, 0.99), 0.055, scale=(1, 1, 1.8))
    # Honey pot with a dipper
    pot = Vector((0, 0.58, 0.48))
    sph(P, "C0703A", pot, 1, scale=(0.25, 0.23, 0.22))
    cyl(P, "C0703A", pot + Vector((0, 0, 0.19)), 0.16, 0.1, verts=14)
    torus(P, "9A5424", pot + Vector((0, 0, 0.25)), 0.16, 0.035)
    cyl(P, "FFB41E", pot + Vector((0, 0, 0.255)), 0.15, 0.03, verts=14)
    sph(P, "FFB41E", pot + Vector((0.1, 0.13, 0.17)), 0.05, scale=(1, 1, 1.8))
    stick(P, "C89A5A", pot + Vector((0.02, 0, 0.2)), pot + Vector((-0.14, -0.05, 0.55)), 0.022)
    for k in range(3):
        torus(P, "C89A5A", pot + Vector((0.0 - k * 0.012, 0, 0.27 + k * 0.035)), 0.045, 0.018)
    paws(P, fur, 0.52, 0.55, spread=0.3)
    # Little bee buzzing by the ear
    bee = head + Vector((0.45, 0.1, 0.4))
    sph(P, "FFD21E", bee, 0.09, scale=(1, 1.3, 1))
    for y in (0.02, -0.05):
        cyl(P, "2A2A2A", bee + Vector((0, y, 0)), 0.09 - abs(y) * 0.25, 0.035, rot=(math.radians(90), 0, 0), verts=12)
    for side in (-1, 1):
        sph(P, "EAF6FF", bee + Vector((side * 0.06, -0.02, 0.1)), 0.06, scale=(0.6, 1, 0.3), rot=(0, side * 0.5, 0), kind="Glass")
    sph(P, EYE, bee + Vector((0.03, 0.1, 0.02)), 0.018, seg=6, rings=4)
    sph(P, EYE, bee + Vector((-0.03, 0.1, 0.02)), 0.018, seg=6, rings=4)


def gold_grain_bull(P):
    fur = "8A4A2A"
    sph(P, fur, (0, -0.1, 0.72), 1, scale=(0.54, 0.62, 0.46))
    sph(P, "6E3A1E", (0, 0.05, 1.0), 1, scale=(0.46, 0.32, 0.26))
    legs(P, fur, [(-0.27, 0.28), (0.27, 0.28), (-0.27, -0.45), (0.27, -0.45)], height=0.48, r=0.12, hoof="3A2418")
    head = Vector((0, 0.45, 1.2))
    R = 0.42
    sph(P, fur, head, R)
    muzzle = surface(head, R, 0, -26, 0.82)
    sph(P, "E8B890", muzzle, 0.26, scale=(1.15, 0.7, 0.75))
    for side in (-1, 1):
        sph(P, "6A3A2A", muzzle + Vector((side * 0.09, 0.17, 0.02)), 0.035, seg=6, rings=4)
    torus(P, "FFC83A", muzzle + Vector((0, 0.19, -0.1)), 0.08, 0.02, rot=(math.radians(90), 0, 0), kind="Metal")
    eyes(P, head, R, spread=36, pitch=14, size=0.12)
    cheeks(P, head, R, size=0.07, spread=56, pitch=-8)
    horns(P, "FFC83A", head, R, spread=58, pitch=34, length=0.5, r=0.1, tilt=78, kind="Metal")
    floppy_ears(P, fur, head, R, size=0.12, spread=80, pitch=10)
    # Crown and collar of golden wheat
    for x in (-0.12, 0.0, 0.12):
        wheat_ear(P, head + Vector((x, -0.05, R * 0.85)), (x * 2.2, -0.15, 1), length=0.42)
    for k in range(7):
        a = math.radians(-70 + k * 23.3)
        base = Vector((math.sin(a) * 0.36, 0.2 + math.cos(a) * 0.3, 0.86))
        wheat_ear(P, base, (math.sin(a), math.cos(a) * 0.6, -0.4), length=0.3)
    sph(P, "FFC83A", (0, 0.52, 0.76), 0.08, kind="Metal")
    stick(P, fur, (0, -0.68, 0.85), (0, -0.85, 0.5), 0.035)
    ico(P, "FFC83A", (0, -0.87, 0.45), 0.08, jit=0.02, seed=26, kind="Metal")


# ---------------------------------------------------------------- world 3, second egg (Muschel-Ei)


def coconut_monkey(P):
    fur = "8A5A3A"
    head, R = critter(P, fur, belly="E8C8A0", feet_color="6A4028", muzzle="F0D2AE", nose="3A2418", eye_size=0.15)
    round_ears(P, fur, head, R, size=0.17, spread=88, pitch=8, inner="F0D2AE", flatness=0.4)
    # Half coconut shell as a helmet
    cap = head + Vector((0, -0.02, R * 0.64))
    sph(P, "5A3A22", cap, 1, scale=(0.5, 0.5, 0.3))
    torus(P, "FFF8EE", cap + Vector((0, 0, -0.03)), 0.47, 0.035, seg=20)
    for yaw in (0, 120, 240):
        sph(P, "3A2414", cap + Vector((math.sin(math.radians(yaw)) * 0.1, math.cos(math.radians(yaw)) * 0.1, 0.29)), 0.03, seg=6, rings=4)
    # Coconut drink with straw and paper umbrella
    nut = Vector((0, 0.6, 0.48))
    sph(P, "5A3A22", nut, 1, scale=(0.2, 0.2, 0.16))
    cyl(P, WHITE, nut + Vector((0, 0, 0.145)), 0.12, 0.04, verts=14)
    stick(P, "FF5A8A", nut + Vector((0.04, 0, 0.1)), nut + Vector((0.12, -0.05, 0.42)), 0.022)
    stick(P, WHITE, nut + Vector((-0.06, 0, 0.1)), nut + Vector((-0.12, 0.02, 0.4)), 0.012)
    cone(P, "38B6D8", nut + Vector((-0.12, 0.02, 0.42)), 0.15, 0.0, 0.08, verts=8)
    paws(P, fur, 0.55, 0.5, spread=0.26, r=0.1)
    tail_curve(P, fur, r=0.05, up=0.8, length=0.9, tip="6A4028")


def shell_seahorse(P):
    c1, c2 = "FF8A6A", "FFD0A0"
    torso = Vector((0, 0, 0.8))
    Rt = (0.34, 0.3, 0.46)
    sph(P, c1, torso, 1, scale=Rt)
    for k in range(4):
        p = -40 + k * 22
        sph(P, c2, surface(torso, Rt, 0, p, 0.92), 1, scale=(0.2, 0.07, 0.06), rot=facing(0, p))
    head = Vector((0, 0.05, 1.36))
    Rh = 0.32
    sph(P, c1, head, Rh)
    eyes(P, head, Rh, spread=40, pitch=10, size=0.12)
    cheeks(P, head, Rh, spread=58, pitch=-12, size=0.07)
    stick(P, c1, head + Vector((0, 0.2, -0.06)), head + Vector((0, 0.48, -0.1)), 0.07)
    sph(P, "E8705A", head + Vector((0, 0.48, -0.1)), 0.08)
    for a in (-25, 0, 25):
        cone(P, c2, head + Vector((math.sin(math.radians(a)) * 0.12, -0.05, Rh * 0.92)), 0.06, 0.0, 0.16, rot=(math.radians(-15), math.radians(a), 0), verts=5)
    # Glassy fins
    flat(P, "FFC8D8", [(0, -0.25), (-0.16, -0.2), (-0.22, 0), (-0.16, 0.2), (0, 0.25)], 0.03, c=(0, -0.26, 0.85), rot=(0, 0, math.radians(90)), kind="Glass")
    for side in (-1, 1):
        sph(P, "FFC8D8", (side * 0.32, 0.0, 1.22), 0.12, scale=(0.3, 0.8, 1), rot=(0, side * 0.4, 0), kind="Glass")
    # Curled tail
    cy, cz = -0.22, 0.33
    pts, radii = [], []
    for i in range(12):
        t = i / 11
        th = -t * 1.75 * math.pi
        r = 0.27 * (1 - 0.6 * t)
        pts.append((0, cy + r * math.cos(th), cz + r * math.sin(th)))
        radii.append(0.15 - 0.1 * t)
    chain(P, [c1], pts, radii)
    # Big scallop shell held on the chest
    scallop(P, "FFB0C0", torso + Vector((0, 0.32, -0.08)), 0.24, rib="E87A98")


def sardine_shark(P):
    c = "5A7A9A"
    body = Vector((0, 0, 0.6))
    R = (0.45, 0.82, 0.45)
    sph(P, c, body, 1, scale=R, seg=16, rings=10)
    sph(P, "EEF2F6", surface(body, R, 0, -35, 0.55), 1, scale=(0.34, 0.66, 0.24))
    head = Vector((0, 0.38, 0.72))
    HR = (0.42, 0.45, 0.38)
    eyes(P, head, HR, spread=46, pitch=14, size=0.11)
    cheeks(P, head, HR, spread=62, pitch=-12)
    # Grin with little teeth
    for yaw in (-28, -14, 0, 14, 28):
        p = surface(body, R, yaw, -14 + abs(yaw) * 0.15, 0.99)
        sph(P, "3A2A3A", p, 0.05, scale=(1.4, 0.6, 0.6), rot=(0, 0, -math.radians(yaw)), seg=8, rings=5)
        cone(P, WHITE, p + Vector((0, 0.03, 0.03)), 0.04, 0.0, 0.09, rot=(math.pi, 0, 0), verts=5)
    for side in (-1, 1):
        for yaw in (62, 70, 78):
            stripe(P, "44627E", body, R, side * yaw, 2, 0.1, width=0.015)
        sph(P, "4A6A8A", (side * 0.45, 0.15, 0.35), 1, scale=(0.26, 0.13, 0.05), rot=(0, side * 0.6, side * 0.5))
    flat(P, "4A6A8A", [(0.24, 0), (-0.22, 0), (-0.2, 0.42)], 0.06, c=(0, -0.08, 0.96), rot=(0, 0, math.radians(90)))
    flat(P, "4A6A8A", [(0.1, 0), (-0.32, 0.42), (-0.18, 0), (-0.32, -0.3)], 0.06, c=(0, -0.75, 0.62), rot=(0, 0, math.radians(90)))
    # Open sardine tin on the head
    tin = Vector((0, 0.26, 1.08))
    box(P, "C8D0DA", tin, (0.42, 0.28, 0.07), kind="Metal", bevel=0.02)
    cyl(P, "C8D0DA", tin + Vector((0, -0.16, 0.06)), 0.05, 0.42, rot=(0, math.radians(90), 0), kind="Metal")
    for x in (-0.12, 0.0, 0.12):
        f = tin + Vector((x, 0.0, 0.05))
        sph(P, "8AA6C8", f, 1, scale=(0.05, 0.12, 0.04))
        cone(P, "6A86A8", f + Vector((0, -0.14, 0)), 0.0, 0.05, 0.06, rot=(math.radians(90), 0, 0), verts=4, scale=(1, 1, 0.5))
        sph(P, EYE, f + Vector((0, 0.09, 0.025)), 0.012, seg=6, rings=4)


def pearl_sea_serpent(P):
    c, belly = "2EB8A8", "E8F5C8"
    # Coil on the ground ending at the front, then the neck rises
    pts, radii = [], []
    for i in range(16):
        t = i / 15
        a = math.radians(120 + t * 330)
        pts.append((math.cos(a) * 0.42, -0.1 + math.sin(a) * 0.42, 0.18 + t * 0.04))
        radii.append(0.08 + 0.12 * t)
    for i in range(1, 7):
        s = i / 6
        pts.append((0, 0.32 - 0.25 * s, 0.22 + 0.85 * s))
        radii.append(0.2 - 0.04 * s)
    chain(P, [c], pts, radii)
    for i in range(4, 15, 3):
        x, y, z = pts[i]
        sph(P, belly, (x, y, z + radii[i] * 0.75), radii[i] * 0.45, scale=(1, 1, 0.5))
    # Head with a snout and glassy frills
    head = Vector((0, 0.14, 1.3))
    HR = (0.3, 0.34, 0.27)
    sph(P, c, head, 1, scale=HR)
    sph(P, "5ED8C8", head + Vector((0, 0.27, -0.07)), 1, scale=(0.18, 0.16, 0.13))
    for side in (-1, 1):
        sph(P, "1A6A60", head + Vector((side * 0.06, 0.42, -0.02)), 0.025, seg=6, rings=4)
        flat(P, "8AF0E0", [(0, 0), (-0.3, 0.14), (-0.26, 0.28), (-0.12, 0.3), (0.02, 0.18)], 0.03, c=head + Vector((side * 0.25, -0.02, -0.02)), rot=(0, side * 0.3, math.radians(90)), kind="Glass")
    eyes(P, head, HR, spread=36, pitch=12, size=0.1)
    cheeks(P, head, HR, spread=55, pitch=-14, size=0.06)
    for k in range(3):
        x, y, z = pts[-2 - k * 2]
        flat(P, "8AF0E0", [(0, -0.1), (-0.14, -0.06), (-0.16, 0.06), (0, 0.1)], 0.03, c=(0, y - 0.12, z), rot=(0, 0, math.radians(90)), kind="Glass")
    # Pearl necklace and an open clam with a big pearl on the head
    nx, ny, nz = pts[-3]
    for k in range(10):
        a = k * 2 * math.pi / 10
        sph(P, "FFF6FA", (nx + math.cos(a) * 0.2, ny + math.sin(a) * 0.2, nz), 0.045, seg=8, rings=6)
    crown = head + Vector((0, -0.04, HR[2] * 0.85))
    scallop(P, "F8D8E8", crown, 0.2, rot=(math.radians(-90), 0, 0), rib="E8A8C8", thickness=0.04)
    scallop(P, "F8D8E8", crown + Vector((0, -0.02, 0.02)), 0.2, rot=(math.radians(-25), 0, 0), rib="E8A8C8", thickness=0.04)
    sph(P, "FFF8F0", crown + Vector((0, 0.1, 0.1)), 0.1, seg=16, rings=10)
    sph(P, WHITE, crown + Vector((0.035, 0.17, 0.15)), 0.025, seg=6, rings=4, kind="Neon")


# ---------------------------------------------------------------- world 4, second egg (Gletscher-Ei)


def mint_reindeer(P):
    fur = "8EDDB8"
    head, R = critter(P, fur, belly="E2F7EC", feet_spots=None, muzzle="E2F7EC", nose="E8322E", eye_size=0.14)
    legs(P, fur, FOUR_FEET, height=0.32, r=0.09, hoof="4A2A1A")
    pointed_ears(P, fur, head, R, size=0.12, height=0.26, spread=70, pitch=32, inner="FFC2D0", tilt=60)
    # Antlers
    for side in (-1, 1):
        base = surface(head, R, side * 26, 62, 0.9)
        tip = base + Vector((side * 0.28, -0.08, 0.5))
        stick(P, "6A4028", base, tip, 0.04)
        for f, off in ((0.45, (side * 0.18, 0.08, 0.16)), (0.75, (-side * 0.05, 0.1, 0.18))):
            p = base + (tip - base) * f
            stick(P, "6A4028", p, p + Vector(off), 0.03)
            sph(P, "6A4028", p + Vector(off), 0.03)
        sph(P, "6A4028", tip, 0.04)
    # Mint leaves between the antlers
    for a in (-35, 35):
        leaf(P, "2EA84A", head + Vector((math.sin(math.radians(a)) * 0.08, -0.02, R * 0.88)), length=0.3, width=0.12, rot=(math.radians(-15), math.radians(a), 0))
    # Chocolate chips
    for center, radii, yaw, pitch in [(Vector(BODY), BODY_R, y, p) for y, p in ((60, 20), (-70, 35), (150, 40), (-140, 15), (110, -10), (-100, -5), (180, 55), (-30, 45))] + [(head, (R, R, R), -60, 40), (head, (R, R, R), 62, 48)]:
        pos = surface(center, radii, yaw, pitch, 0.96)
        cone(P, "4A2A1A", pos, 0.05, 0.0, 0.08, rot=aim(pos - Vector(center)), verts=6)
    # Mint candy on a red ribbon
    torus(P, "E8322E", (0, 0.12, 0.84), 0.3, 0.04, seg=18)
    candy = Vector((0, 0.46, 0.74))
    cyl(P, WHITE, candy, 0.11, 0.04, rot=(math.radians(90), 0, 0), verts=16)
    for k in range(4):
        a = math.radians(k * 90)
        b = a + math.radians(45)
        flat(P, "3EC27A", [(0, 0), (math.cos(a) * 0.1, math.sin(a) * 0.1), (math.cos(b) * 0.1, math.sin(b) * 0.1)], 0.01, c=candy + Vector((0, 0.022, 0)))


def sundae_polar_bear(P):
    fur = "F4F8FB"
    head, R = critter(P, fur, belly=WHITE, feet_color="D8E2EA", muzzle=WHITE, nose="2A2A3A", eye_size=0.14)
    round_ears(P, fur, head, R, size=0.14, spread=44, pitch=44, inner="D8E2EA")
    # Sundae glass hugged in front
    cup = Vector((0, 0.72, 0.0))
    cyl(P, "D8F0FF", cup + Vector((0, 0, 0.03)), 0.14, 0.04, verts=14, kind="Glass")
    stick(P, "D8F0FF", cup + Vector((0, 0, 0.04)), cup + Vector((0, 0, 0.2)), 0.035, kind="Glass")
    cone(P, "D8F0FF", cup + Vector((0, 0, 0.35)), 0.07, 0.24, 0.3, verts=16, kind="Glass")
    cone(P, "FF9AB8", cup + Vector((0, 0, 0.34)), 0.05, 0.2, 0.24, verts=14)
    for x, col in ((-0.1, "FF8AAE"), (0.1, "7A4A2E")):
        sph(P, col, cup + Vector((x, 0, 0.55)), 0.13)
    sph(P, "FFF2C8", cup + Vector((0, 0.02, 0.7)), 0.12)
    for x, y, z in ((-0.06, 0.1, 0.62), (0.07, 0.09, 0.66), (0.0, 0.1, 0.76)):
        sph(P, "5A3018", cup + Vector((x, y, z)), 0.035, scale=(1, 1, 1.6))
    sph(P, WHITE, cup + Vector((0, 0.03, 0.82)), 0.09, scale=(1, 1, 0.8))
    cone(P, WHITE, cup + Vector((0, 0.03, 0.9)), 0.06, 0.0, 0.08, verts=8)
    sph(P, "E8203A", cup + Vector((0, 0.04, 0.98)), 0.055)
    stick(P, "3E7A2A", cup + Vector((0, 0.04, 1.02)), cup + Vector((0.03, 0.0, 1.12)), 0.01, verts=5)
    box(P, "E8B060", cup + Vector((0.13, -0.03, 0.78)), (0.05, 0.03, 0.26), rot=(0, 0.45, 0))
    paws(P, fur, 0.58, 0.45, spread=0.28)


def vanilla_mammoth(P):
    fur, dark = "B8865A", "8A5E3A"
    sph(P, fur, (0, -0.12, 0.68), 1, scale=(0.56, 0.62, 0.5))
    sph(P, dark, (0, -0.2, 1.05), 1, scale=(0.42, 0.44, 0.25))
    legs(P, fur, [(-0.28, 0.22), (0.28, 0.22), (-0.28, -0.45), (0.28, -0.45)], height=0.4, r=0.14, hoof="F5E6C8")
    head = Vector((0, 0.3, 1.12))
    R = 0.44
    sph(P, fur, head, R)
    ico(P, dark, head + Vector((0, -0.05, R * 0.92)), 0.2, jit=0.04, seed=31)
    eyes(P, head, R, spread=34, pitch=16, size=0.12)
    cheeks(P, head, R, spread=56, pitch=-4)
    for side in (-1, 1):
        sph(P, fur, surface(head, R, side * 80, 5, 0.95), 0.22, scale=(0.35, 0.8, 1.0), rot=(0, 0, -math.radians(side * 80)))
        base = surface(head, R, side * 24, -30, 0.9)
        mid = base + Vector((side * 0.08, 0.22, -0.1))
        stick(P, WHITE, base, mid, 0.055, r2=0.045)
        stick(P, WHITE, mid, mid + Vector((side * 0.03, 0.08, 0.16)), 0.045, r2=0.01)
    # Trunk curling up around a vanilla ice cream cone
    trunk = [(0, 0.62, 1.0), (0, 0.72, 0.84), (0, 0.76, 0.67), (0, 0.78, 0.52), (0, 0.84, 0.42), (0, 0.93, 0.41), (0, 0.99, 0.48)]
    chain(P, [fur], trunk, [0.13, 0.12, 0.11, 0.1, 0.09, 0.085, 0.08])
    cone(P, "D9A04A", (0, 1.02, 0.63), 0.0, 0.12, 0.3, verts=10)
    for k in range(3):
        torus(P, "B8803A", (0, 1.02, 0.56 + k * 0.07), 0.035 + k * 0.03, 0.01, seg=10, mseg=4)
    sph(P, "FFF4D6", (0, 1.02, 0.82), 0.14)
    sph(P, "FFF4D6", (0.06, 1.1, 0.74), 0.045, scale=(1, 1, 1.6))
    # Vanilla flower and pods behind the ear
    flower = surface(head, R, -42, 48, 1.0)
    for k in range(5):
        a = math.radians(k * 72)
        sph(P, "FFF2A8", flower + Vector((math.cos(a) * 0.07, 0.02, math.sin(a) * 0.07)), 0.05, scale=(1, 0.4, 0.6), rot=(0, -a, 0))
    sph(P, "FFC83A", flower + Vector((0, 0.04, 0)), 0.03)
    for k in range(2):
        stick(P, "3A2418", flower + Vector((0.04 + k * 0.04, -0.05, -0.05)), flower + Vector((0.12 + k * 0.05, -0.12, 0.25)), 0.018, verts=5)
    stick(P, fur, (0, -0.72, 0.8), (0, -0.82, 0.5), 0.035)
    ico(P, dark, (0, -0.84, 0.46), 0.07, jit=0.02, seed=32)


def sorbet_narwhal(P):
    body = Vector((0, -0.05, 0.62))
    R = (0.48, 0.78, 0.46)
    sph(P, "FFB0C8", body, 1, scale=R, seg=16, rings=10)
    sph(P, "FFF0DA", surface(body, R, 0, -35, 0.55), 1, scale=(0.34, 0.6, 0.24))
    head = Vector((0, 0.35, 0.72))
    HR = (0.42, 0.45, 0.38)
    eyes(P, head, HR, spread=44, pitch=12, size=0.12)
    cheeks(P, head, HR, spread=60, pitch=-12)
    # Spiral ice tusk
    base = surface(body, R, 0, 18, 0.92)
    d = Vector((0, 1, 0.9)).normalized()
    cone(P, "E0F6FF", base + d * 0.3, 0.07, 0.0, 0.6, rot=aim(d), verts=8)
    for k in range(4):
        torus(P, "9FE8FF", base + d * (0.1 + k * 0.12), 0.064 - k * 0.012, 0.014, rot=aim(d), kind="Neon", seg=10, mseg=4)
    for side in (-1, 1):
        sph(P, "F590B0", (side * 0.46, 0.2, 0.35), 1, scale=(0.26, 0.13, 0.05), rot=(0, side * 0.4, side * 0.5))
    flat(P, "F590B0", [(-0.42, 0.18), (0, -0.05), (0.42, 0.18), (0.3, -0.1), (0, -0.2), (-0.3, -0.1)], 0.06, c=(0, -0.88, 0.68), rot=(math.radians(80), 0, 0))
    # Three sorbet scoops in a waffle bowl on the back
    bowl = Vector((0, -0.15, 1.05))
    sph(P, "D9A04A", bowl, 1, scale=(0.3, 0.3, 0.16))
    for x, y, z, col in ((-0.12, 0.02, 0.14, "FF5A8A"), (0.12, 0.02, 0.14, "FFB040"), (0, -0.06, 0.28, "9AE05A")):
        sph(P, col, bowl + Vector((x, y, z)), 0.15)
    leaf(P, "2EA84A", bowl + Vector((0.03, -0.06, 0.4)), length=0.18, width=0.07, rot=(0, math.radians(25), 0))
    for p in ((0.5, 0.3, 1.2), (-0.55, -0.2, 1.1), (0.45, -0.6, 0.95)):
        flat(P, "CFF4FF", star_points(0.06, 0.025, n=4), 0.02, c=p, kind="Neon")


# ---------------------------------------------------------------- world 5, second egg (Magma-Ei)


def pepper_scorpion(P):
    dark = "2E2626"
    shell = Vector((0, 0.2, 0.32))
    SR = (0.42, 0.4, 0.26)
    sph(P, dark, shell, 1, scale=SR)
    eyes(P, shell, SR, spread=30, pitch=28, size=0.12, sclera=WHITE)
    cheeks(P, shell, SR, spread=50, pitch=8, size=0.07)
    sph(P, "3A302E", (0, -0.15, 0.3), 1, scale=(0.32, 0.26, 0.2))
    for side in (-1, 1):
        for k in range(3):
            a = Vector((side * 0.3, 0.25 - k * 0.2, 0.25))
            b = a + Vector((side * 0.22, 0.02, 0.05))
            stick(P, dark, a, b, 0.035)
            stick(P, dark, b, b + Vector((side * 0.06, 0, -0.26)), 0.03)
        # Chili-red claws
        arm0 = Vector((side * 0.28, 0.4, 0.3))
        arm1 = Vector((side * 0.46, 0.62, 0.36))
        stick(P, "E8322E", arm0, arm1, 0.05)
        sph(P, "E8322E", arm1 + Vector((0, 0.1, 0.02)), 1, scale=(0.14, 0.17, 0.11))
        for f in (-1, 1):
            cone(P, "C8261F", arm1 + Vector((side * 0.05 * f, 0.3, 0.03)), 0.05, 0.0, 0.18, rot=(math.radians(-90), 0, 0), verts=5)
    # Tail of black, pink and green peppercorns with a red chili stinger
    cy, cz, r = -0.42, 0.72, 0.38
    colors = ["2E2626", "E86A8A", "6A9A3A"]
    end = None
    for i in range(9):
        th = math.radians(-90 + i * 30)
        p = Vector((0, cy - r * math.cos(th), cz + r * math.sin(th)))
        ico(P, colors[i % 3], p, 0.12 - i * 0.004, subdiv=2, jit=0.015, seed=60 + i)
        end = p
    d = Vector((0, 0.8, -0.5)).normalized()
    sph(P, "E8322E", end + d * 0.18, 1, scale=(0.08, 0.08, 0.2), rot=aim(d))
    cone(P, "E8322E", end + d * 0.4, 0.06, 0.0, 0.16, rot=aim(d), verts=8)
    cyl(P, "3E8F2E", end + d * 0.03, 0.07, 0.05, rot=aim(d), verts=8)


def habanero_rhino(P):
    c = "FF8A1E"
    sph(P, c, (0, -0.1, 0.62), 1, scale=(0.52, 0.62, 0.44))
    sph(P, "FFC07A", (0, 0.2, 0.5), 1, scale=(0.36, 0.3, 0.26))
    legs(P, c, [(-0.27, 0.25), (0.27, 0.25), (-0.27, -0.42), (0.27, -0.42)], height=0.36, r=0.13, hoof="5A2A14")
    head = Vector((0, 0.42, 0.92))
    R = 0.4
    sph(P, c, head, R)
    snout = surface(head, R, 0, -25, 0.75)
    sph(P, "FFC07A", snout, 0.24, scale=(1.05, 0.9, 0.7))
    for side in (-1, 1):
        sph(P, "8A3A14", snout + Vector((side * 0.08, 0.2, 0.02)), 0.03, seg=6, rings=4)
    eyes(P, head, R, spread=38, pitch=14, size=0.12)
    cheeks(P, head, R, size=0.07, spread=56, pitch=-8)
    pointed_ears(P, c, head, R, size=0.1, height=0.22, spread=42, pitch=56, inner="FFC07A")

    # Horns are habanero peppers: lantern shape, pointed tip, green cap
    def habanero(base, d, s):
        d = Vector(d).normalized()
        cyl(P, "3E8F2E", base, 0.09 * s, 0.05, rot=aim(d), verts=8)
        sph(P, "FF6A0A", base + d * 0.13 * s, 1, scale=(0.14 * s, 0.14 * s, 0.17 * s), rot=aim(d))
        for k in range(4):
            a = k * math.pi / 2
            sph(P, "E8560A", base + d * 0.13 * s + (aim(d).to_matrix() @ Vector((math.cos(a), math.sin(a), 0))) * 0.12 * s, 1, scale=(0.03 * s, 0.03 * s, 0.13 * s), rot=aim(d))
        cone(P, "FF6A0A", base + d * 0.33 * s, 0.08 * s, 0.0, 0.16 * s, rot=aim(d), verts=8)

    habanero(surface(head, R, 0, -5, 1.1) + Vector((0, 0.05, 0.05)), (0, 0.5, 1), 1.0)
    habanero(surface(head, R, 0, 30, 0.98), (0, 0.2, 1), 0.65)
    # Back plates and pepper rings with seeds
    for k in range(3):
        cone(P, "E0661A", (0, 0.05 - k * 0.25, 1.02 - k * 0.04), 0.13, 0.0, 0.2, verts=4, scale=(0.4, 1, 1))
    for side in (-1, 1):
        p = surface((0, -0.1, 0.62), (0.52, 0.62, 0.44), side * 95, 10, 0.98)
        torus(P, "E8560A", p, 0.11, 0.03, rot=facing(side * 95, 10 + 90), seg=12, mseg=5)
        for k in range(3):
            a = k * 2 * math.pi / 3
            sph(P, "FFF0B0", p + Vector((0, math.cos(a) * 0.05, math.sin(a) * 0.05)), 0.02, seg=6, rings=4)
    stick(P, c, (0, -0.7, 0.7), (0, -0.85, 0.45), 0.035)


def curry_tiger(P):
    c, dark = "F0A830", "6A3A1A"
    head, R = critter(P, c, belly="FFF0D0", feet_color="D08A20", muzzle="FFF0D0", nose="C84A6A", eye_size=0.14)
    round_ears(P, c, head, R, size=0.15, spread=44, pitch=44, inner="FFF0D0")
    for yaw in (-14, 0, 14):
        stripe(P, dark, head, (R, R, R), yaw, 54 - abs(yaw) * 0.5, 0.1)
    for side in (-1, 1):
        for p in (-2, 14):
            stripe(P, dark, head, (R, R, R), side * 78, p, 0.1, across=True)
        for yaw in (75, 110, 145):
            stripe(P, dark, BODY, BODY_R, side * yaw, 15, 0.2, width=0.04)
    stripe(P, dark, BODY, BODY_R, 180, 25, 0.2, width=0.04)
    # Ringed tail
    for i in range(7):
        t = i / 6
        sph(P, c if i % 2 == 0 else dark, (0, -0.5 - t * 0.35, 0.45 + math.sin(t * math.pi * 0.9) * 0.5), 0.07)
    # Bowl of curry with rice, tilted to the viewer, and some steam
    bowl = Vector((0, 0.6, 0.48))
    rot = (math.radians(-22), 0, 0)
    cone(P, WHITE, bowl, 0.14, 0.26, 0.18, rot=rot, verts=18)
    torus(P, "38A0D8", at(bowl, rot, (0, 0, 0.085)), 0.26, 0.02, rot=rot, seg=18, mseg=4)
    cyl(P, "D8761E", at(bowl, rot, (0, 0, 0.08)), 0.24, 0.03, rot=rot, verts=18)
    sph(P, "FFFDF0", at(bowl, rot, (-0.09, 0.02, 0.1)), 1, scale=(0.12, 0.11, 0.07), rot=rot)
    for x, y in ((0.08, 0.05), (0.12, -0.07), (0.02, -0.1)):
        box(P, "FFD890", at(bowl, rot, (x, y, 0.1)), (0.05, 0.05, 0.05), rot=rot, bevel=0.01)
    leaf(P, "3E9B3A", at(bowl, rot, (0.0, 0.08, 0.1)), length=0.12, width=0.05, rot=(math.radians(-60), 0, 0.4))
    for k in range(3):
        sph(P, "F4F4F4", bowl + Vector((-0.08 + k * 0.08, -0.05, 0.3 + k * 0.1 + (k % 2) * 0.05)), 0.05 - k * 0.008, kind="Glass")
    paws(P, c, 0.55, 0.5, spread=0.3, r=0.11)


def calzone_hydra(P):
    dough, crimp = "E8B060", "D0903E"
    sph(P, dough, (0, -0.05, 0.34), 1, scale=(0.66, 0.5, 0.32))
    for i in range(15):
        a = math.radians(i * 180 / 14)
        sph(P, crimp, (math.cos(a) * 0.64, -0.05 + math.sin(a) * 0.48, 0.12), 0.07, scale=(1, 1, 0.7), seg=8, rings=5)
    # Glowing tomato sauce bursting out of the crust, cheese drips and basil
    sph(P, "FF3A1A", surface((0, -0.05, 0.34), (0.66, 0.5, 0.32), 0, 55, 0.98), 1, scale=(0.32, 0.06, 0.035), rot=facing(0, 55), kind="Neon")
    for x in (-0.15, 0.12):
        sph(P, "FF3A1A", (x, 0.42, 0.3), 0.04, scale=(1, 0.6, 1.8), kind="Neon")
    for x in (-0.35, 0.3):
        sph(P, "FFE27A", (x, 0.3, 0.28), 0.045, scale=(1, 0.6, 1.6))
    leaf(P, "3E9B3A", (0.32, 0.05, 0.6), length=0.2, width=0.08, rot=(math.radians(-50), 0, 0.6))
    for x, y in ((-0.38, 0.25), (0.38, 0.25), (-0.38, -0.32), (0.38, -0.32)):
        sph(P, crimp, (x, y, 0.06), 0.11, scale=(1, 1.2, 0.55))
    # Three heads on long necks: tomato, cheese and basil
    heads = [(-0.42, 0.15, 1.12, "E8402E", "FFB0A0"), (0.0, 0.24, 1.4, "FFD24A", "FFF2B0"), (0.42, 0.15, 1.12, "5AB84A", "C8F0A0")]
    for x, y, z, col, snout in heads:
        h = Vector((x, y, z))
        base = Vector((x * 0.35, -0.15, 0.52))
        tip = h - Vector((0, 0.08, 0.18))
        chain(P, [col], [base + (tip - base) * (k / 4) for k in range(5)], [0.13 - k * 0.008 for k in range(5)])
        sph(P, col, h, 0.23)
        sph(P, snout, surface(h, 0.23, 0, -18, 0.85), 0.13, scale=(1, 0.8, 0.7))
        eyes(P, h, 0.23, spread=32, pitch=10, size=0.075)
        cheeks(P, h, 0.23, size=0.045)
        horns(P, "FFF2D0", h, 0.23, spread=30, pitch=58, length=0.14, r=0.04)
    tomato, cheese, basil = [Vector(hh[:3]) for hh in heads]
    for k in range(5):
        leaf(P, "3E9B3A", tomato + Vector((0, -0.05, 0.21)), length=0.13, width=0.04, rot=(math.radians(80), 0, k * 2 * math.pi / 5))
    for yaw, pitch in ((-50, 30), (40, 45), (100, 10)):
        sph(P, "E0A41E", surface(cheese, 0.23, yaw, pitch, 0.97), 0.04, scale=(1, 1, 0.6), seg=8, rings=5)
    leaf(P, "2E8A2E", basil + Vector((0, -0.05, 0.2)), length=0.24, width=0.1, rot=(math.radians(-20), 0, 0))


# ---------------------------------------------------------------- world 6, second egg (Bonbon-Ei)


def donut_dachshund(P):
    c, ear = "A8642E", "7A4420"
    body = Vector((0, -0.1, 0.48))
    R = (0.36, 0.72, 0.34)
    sph(P, c, body, 1, scale=R)
    sph(P, "D8A070", surface(body, R, 0, -40, 0.6), 1, scale=(0.24, 0.5, 0.15))
    for x, y in ((-0.2, 0.35), (0.2, 0.35), (-0.2, -0.5), (0.2, -0.5)):
        cyl(P, c, (x, y, 0.12), 0.08, 0.24, verts=8)
        sph(P, ear, (x, y + 0.03, 0.04), 0.09, scale=(1, 1.3, 0.6))
    head = Vector((0, 0.62, 0.9))
    Rh = 0.38
    sph(P, c, head, Rh)
    snout_long(P, "C88450", head, Rh, length=0.24, r=0.18, pitch=-20)
    eyes(P, head, Rh, spread=34, pitch=12, size=0.12)
    cheeks(P, head, Rh, size=0.07)
    floppy_ears(P, ear, head, Rh, size=0.2, spread=70, pitch=20)
    stick(P, c, (0, -0.76, 0.55), (0, -0.95, 0.82), 0.045, r2=0.02)
    # Pink frosted donut around the middle, with sprinkles
    d = body + Vector((0, -0.05, 0))
    ring = (math.radians(90), 0, 0)
    torus(P, "E0A050", d, 0.4, 0.17, rot=ring, seg=20, mseg=8)
    torus(P, "FF8FC4", d + Vector((0, 0, 0.04)), 0.4, 0.172, rot=ring, seg=20, mseg=8)
    colors = ["FFFFFF", "FFE14A", "4FB8FF", "6FD65A", "B06AF0", "FF4F7A"]
    rnd = random.Random(40)
    for k in range(18):
        a = math.radians(rnd.uniform(20, 160))
        out = Vector((math.cos(a), 0, math.sin(a)))
        p = d + Vector((0, rnd.uniform(-0.1, 0.1), 0.04)) + out * 0.4 + out * 0.17
        box(P, colors[k % len(colors)], p, (0.06, 0.02, 0.02), rot=(rnd.uniform(0, 3), rnd.uniform(0, 3), rnd.uniform(0, 3)))


def pudding_panda(P):
    white, black = "F8F8F5", "2A2A30"
    head, R = critter(P, white, feet_color=black, nose=black, muzzle=WHITE, eye_size=0.13, sclera=WHITE)
    round_ears(P, black, head, R, size=0.16, spread=42, pitch=46)
    for side in (-1, 1):
        sph(P, black, surface(head, R, side * 28, 4, 0.86), 0.18, scale=(0.9, 0.4, 1.25), rot=(0, side * 0.5, -math.radians(side * 28)))
        sph(P, black, (side * 0.4, 0.15, 0.58), 1, scale=(0.14, 0.14, 0.22))
    sph(P, black, (0, -0.1, 0.78), 1, scale=(0.5, 0.42, 0.16))
    # Caramel pudding on a plate on the head
    top = head + Vector((0, -0.02, R * 0.92))
    cyl(P, WHITE, top, 0.3, 0.03, verts=18)
    cone(P, "FFD860", top + Vector((0, 0, 0.16)), 0.27, 0.2, 0.28, verts=16)
    cyl(P, "A0561E", top + Vector((0, 0, 0.3)), 0.2, 0.03, verts=16)
    for k in range(6):
        a = math.radians(k * 60 + 15)
        sph(P, "A0561E", top + Vector((math.cos(a) * 0.21, math.sin(a) * 0.21, 0.26)), 0.035, scale=(1, 1, 1.8))
    sph(P, WHITE, top + Vector((0, 0, 0.37)), 0.08, scale=(1, 1, 0.8))
    sph(P, "E8203A", top + Vector((0, 0, 0.46)), 0.055)
    stick(P, "3E7A2A", top + Vector((0, 0, 0.5)), top + Vector((0.03, -0.03, 0.6)), 0.01, verts=5)
    # Spoon in the paw
    stick(P, "C8D0DA", (0.42, 0.3, 0.45), (0.5, 0.42, 0.85), 0.02, kind="Metal")
    sph(P, "C8D0DA", (0.51, 0.44, 0.9), 0.06, scale=(1, 0.5, 1.3), kind="Metal")


def licorice_panther(P):
    c = "24242C"
    head, R = critter(P, c, belly="34343E", feet_color="18181E", muzzle="3A3A46", nose="E86A9A", eye_size=0.14, sclera="C8E85A")
    pointed_ears(P, c, head, R, size=0.17, height=0.32, inner="E86A9A")
    for side in (-1, 1):
        for k in (-1, 1):
            p = surface(head, R, side * 30, -14, 1.0)
            box(P, "B8B8C8", p + Vector((side * 0.12, 0.02, k * 0.035)), (0.22, 0.012, 0.012), rot=(0, side * k * 0.15, 0))
    # Licorice allsorts as a collar under the chin
    sorts = [("FFE14A", "1A1A20"), ("FF8AC8", "1A1A20"), (WHITE, "1A1A20"), ("6AC8FF", "1A1A20"), ("FF9A3A", "1A1A20")]
    for k, yaw in enumerate((-48, -24, 0, 24, 48)):
        p = surface(head, R, yaw, -52, 0.98)
        light, dark = sorts[k]
        rot = facing(yaw, -52 + 90)
        for j, col in enumerate((light, dark, light)):
            box(P, col, at(p, rot, (0, 0, (j - 1) * 0.045)), (0.13, 0.13, 0.045), rot=rot)
    # Red and black twisted licorice tail ending in a licorice wheel
    pts = []
    for i in range(10):
        t = i / 9
        pts.append((0, -0.5 - t * 0.45, 0.4 + math.sin(t * math.pi * 0.8) * 0.65))
    chain(P, ["E8322E", "1A1A20"], pts, 0.065)
    wheel = Vector(pts[-1]) + Vector((0, -0.05, 0.12))
    for k, rr in enumerate((0.07, 0.12, 0.17)):
        torus(P, "1A1A20", wheel, rr, 0.028, rot=(math.radians(90), 0, 0), seg=16, mseg=5)
    cyl(P, "FF6AB0", wheel, 0.045, 0.08, rot=(math.radians(90), 0, 0), verts=12)


def cake_pegasus(P):
    c = "FFF2F6"
    sph(P, c, (0, -0.1, 0.72), 1, scale=(0.45, 0.6, 0.42))
    legs(P, c, [(-0.24, 0.3), (0.24, 0.3), (-0.24, -0.45), (0.24, -0.45)], height=0.5, r=0.1)
    for x, y in ((-0.24, 0.3), (0.24, 0.3), (-0.24, -0.45), (0.24, -0.45)):
        cyl(P, "FFC83A", (x, y, 0.04), 0.11, 0.08, verts=8, kind="Metal")
    head = Vector((0, 0.42, 1.35))
    R = 0.42
    sph(P, c, head, R)
    snout_long(P, "FFE0EA", head, R, length=0.2, r=0.23, pitch=-25, nose="E87AA0")
    eyes(P, head, R, spread=34, pitch=12, size=0.13)
    cheeks(P, head, R, size=0.07)
    pointed_ears(P, c, head, R, size=0.1, height=0.25, spread=30, pitch=62, inner="FFC2D8")
    # Whipped cream mane and tail
    for i in range(5):
        ico(P, WHITE if i % 2 else "FFC2DC", (0, 0.25 - i * 0.14, 1.78 - i * 0.16), 0.13, subdiv=2, jit=0.02, seed=40 + i)
    for i in range(3):
        ico(P, WHITE if i % 2 else "FFC2DC", (0, -0.72 - i * 0.08, 0.85 - i * 0.14), 0.13 - i * 0.02, subdiv=2, jit=0.02, seed=45 + i)
    # Feathered wings with pink tips
    for side in (-1, 1):
        for k in range(3):
            sph(P, WHITE if k < 2 else "FFD0E2", (side * (0.38 + k * 0.12), -0.22 - k * 0.12, 1.12 + k * 0.1), 1, scale=(0.3, 0.08, 0.12), rot=(0, side * math.radians(-20 - k * 12), side * math.radians(-40)))
    # Slice of layer cake as a hat, with a strawberry and a lit candle
    top = head + Vector((0.04, -0.04, R * 0.9))
    hat = (0, 0, math.radians(-20))
    wedge = [(-0.24, -0.15), (0.24, -0.15), (0.0, 0.26)]
    for j, (col, z, h) in enumerate((("FFB8D0", 0.04, 0.08), (WHITE, 0.1, 0.04), ("FFB8D0", 0.16, 0.08), (WHITE, 0.225, 0.05))):
        grow = 1.0 + 0.03 * (j % 2)
        flat(P, col, [(x * grow, y * grow) for x, y in wedge], h, c=at(top, hat, (0, 0, z)), rot=(math.radians(90), 0, hat[2]))
    for x, y in ((-0.12, -0.13), (0.0, -0.14), (0.12, -0.13)):
        sph(P, WHITE, at(top, hat, (x, y - 0.01, 0.19)), 0.03, scale=(1, 1, 1.8))
    sph(P, "E8203A", at(top, hat, (-0.05, 0.0, 0.3)), 0.06, scale=(1, 1, 1.2))
    leaf(P, "3E9B3A", at(top, hat, (-0.05, 0.0, 0.35)), length=0.07, width=0.04, rot=(0, 0.5, 0))
    cyl(P, "8AD0FF", at(top, hat, (0.07, 0.05, 0.33)), 0.02, 0.16, verts=6)
    sph(P, "FFC23A", at(top, hat, (0.07, 0.05, 0.45)), 0.035, scale=(1, 1, 1.6), kind="Neon")


# ---------------------------------------------------------------- world 7, second egg (Nebula-Ei)


def mooncake_bunny(P):
    fur = "ECE6F8"
    head, R = critter(P, fur, belly=WHITE, feet_color="CFC4E8", muzzle=WHITE, nose="FF9AB8", eye_size=0.15)
    long_ears(P, fur, head, R, inner="FFC8DC")
    flat(P, "FFE66A", crescent_points(0.16), 0.05, c=surface(head, R, 42, 40, 1.0), rot=(math.radians(-40), 0, -math.radians(42)), kind="Neon")
    # Mooncake with a scalloped rim and flower stamp
    mc = Vector((0, 0.62, 0.52))
    face = (math.radians(90), 0, 0)
    cyl(P, "D9963A", mc, 0.24, 0.12, rot=face, verts=20)
    for k in range(14):
        a = k * 2 * math.pi / 14
        sph(P, "C8822A", mc + Vector((math.cos(a) * 0.22, 0.05, math.sin(a) * 0.22)), 0.035, scale=(1, 0.6, 1), seg=8, rings=5)
    flat(P, "B87024", star_points(0.12, 0.07, n=6), 0.02, c=mc + Vector((0, 0.065, 0)))
    sph(P, "E8B050", mc + Vector((0, 0.08, 0)), 0.03, seg=8, rings=5)
    paws(P, fur, 0.56, 0.5, spread=0.29, r=0.11)
    tail_ball(P, WHITE, r=0.15)


def starfruit_jellyfish(P):
    bell = Vector((0, 0, 1.0))
    R = (0.52, 0.5, 0.42)
    sph(P, "EEF07A", bell, 1, scale=R)
    torus(P, "D8E040", bell + Vector((0, 0, -0.17)), 0.47, 0.07, seg=20)
    eyes(P, bell, R, spread=28, pitch=-5, size=0.13)
    cheeks(P, bell, R, spread=48, pitch=-22)
    for yaw in (90, 150, 210, 270):
        sph(P, "FFFFC8", surface(bell, R, yaw, 35, 0.98), 0.06, scale=(1, 0.5, 1), rot=facing(yaw, 35))
    # Glowing tentacles
    for k in range(6):
        a = math.radians(k * 60 + 30)
        for j in range(6):
            t = j / 5
            p = (math.cos(a) * (0.32 - 0.06 * t) + math.sin(t * 6 + k) * 0.05, math.sin(a) * (0.32 - 0.06 * t), 0.78 - t * 0.68)
            sph(P, "FFE85A" if (j + k) % 2 else "B8F05A", p, 0.075 - t * 0.025, kind="Neon", seg=8, rings=6)
    # Starfruit slice standing on top
    top = Vector((0, -0.06, 1.58))
    flat(P, "FFD62A", star_points(0.28, 0.17), 0.12, c=top)
    flat(P, "FFF2A0", star_points(0.2, 0.11), 0.02, c=top + Vector((0, 0.065, 0)))
    for k in range(5):
        a = math.pi / 2 + k * 2 * math.pi / 5
        sph(P, "8A6A2A", top + Vector((math.cos(a) * 0.06, 0.08, math.sin(a) * 0.06)), 0.018, scale=(1, 0.6, 1.5), rot=(0, -a + math.pi / 2, 0), seg=6, rings=4)
    for p in ((0.55, 0.2, 1.35), (-0.58, 0.1, 1.2), (0.5, -0.3, 0.6)):
        sph(P, "E8FFF0", p, 0.05, kind="Glass")


def stardust_lion(P):
    c = "E8B04A"
    head, R = critter(P, c, belly="FFE6A8", feet_color="C8902A", muzzle="FFF0C8", nose="6A3A2A", eye_size=0.14)
    # Starry mane around the face
    for k in range(16):
        deg = k * 22.5
        if 135 < deg < 225:
            continue
        phi = math.radians(deg)
        p = head + Vector((math.sin(phi) * R * 0.98, -0.12, math.cos(phi) * R * 0.98))
        ico(P, "4A3AA8" if k % 2 else "2E3A8A", p, 0.22, subdiv=1, jit=0.03, seed=50 + k)
        if k % 2 == 0:
            flat(P, "FFF2A0", star_points(0.06, 0.025), 0.02, c=p + Vector((0, 0.21, 0.02)), kind="Neon")
    for k in range(6):
        phi = math.radians(k * 60 + 30)
        ico(P, "3A2E8A", head + Vector((math.sin(phi) * R * 0.6, -0.4, math.cos(phi) * R * 0.6)), 0.2, subdiv=1, jit=0.03, seed=70 + k)
    round_ears(P, c, head, R, size=0.14, spread=42, pitch=50, inner="FFE6A8")
    tail_curve(P, c, r=0.06, up=0.6, length=0.8, tip="4A3AA8")
    flat(P, "FFF2A0", star_points(0.09, 0.04), 0.03, c=(0, -1.0, 1.08), kind="Neon")
    for p in ((0.6, 0.3, 0.9), (-0.62, 0.2, 1.3), (0.55, -0.4, 1.4), (-0.5, -0.5, 0.7)):
        sph(P, "FFF2A0", p, 0.035, kind="Neon")


def galaxy_pizza_leviathan(P):
    c, light = "2E2A7A", "7A6AE8"
    # Body humps behind the head, ending in a glassy tail fin
    pts, radii = [], []
    for i in range(7):
        t = i / 6
        pts.append((math.sin(t * math.pi * 1.2) * 0.08, -0.15 - t * 0.85, 0.42 + math.sin(t * math.pi * 1.5) * 0.25))
        radii.append(0.34 - t * 0.22)
    chain(P, [c], pts, radii)
    tx, ty, tz = pts[-1]
    flat(P, "C86AFF", [(-0.35, 0.2), (0, -0.05), (0.35, 0.2), (0.25, -0.1), (0, -0.2), (-0.25, -0.1)], 0.05, c=(tx, ty - 0.12, tz), rot=(math.radians(80), 0, 0), kind="Glass")
    for i in (1, 3):
        x, y, z = pts[i]
        sph(P, "8A6AE8", (x, y, z - radii[i] * 0.7), radii[i] * 0.6, scale=(1, 1, 0.45))
    # Head with an open grin
    head = Vector((0, 0.3, 0.72))
    HR = (0.42, 0.5, 0.36)
    sph(P, c, head, 1, scale=HR)
    sph(P, light, (0, 0.36, 0.38), 1, scale=(0.36, 0.44, 0.15))
    sph(P, "1A0E30", (0, 0.5, 0.5), 1, scale=(0.28, 0.28, 0.08))
    for x in (-0.15, -0.05, 0.05, 0.15):
        cone(P, WHITE, (x, 0.7, 0.53), 0.03, 0.0, 0.07, rot=(math.pi, 0, 0), verts=5)
    eyes(P, head + Vector((0, 0, 0.08)), HR, spread=36, pitch=18, size=0.12, sclera=WHITE)
    cheeks(P, head, HR, spread=55, pitch=-5)
    for side in (-1, 1):
        flat(P, "C86AFF", [(0, 0), (-0.32, 0.12), (-0.3, 0.3), (-0.12, 0.26)], 0.03, c=head + Vector((side * 0.38, -0.1, 0.05)), rot=(0, side * 0.4, math.radians(90)), kind="Glass")
    for yaw, pitch in ((130, 30), (-140, 40), (100, 50), (-90, 20)):
        sph(P, WHITE, surface(head, HR, yaw, pitch, 0.99), 0.03, seg=6, rings=4, kind="Neon")
    # Galaxy pizza rising behind like a planet: crust, cheese, glowing pepperoni planets
    halo = Vector((0, -0.22, 1.32))
    face = (math.radians(90), 0, 0)
    cyl(P, "FFD860", halo, 0.46, 0.06, rot=face, verts=24)
    torus(P, "E8A848", halo, 0.48, 0.07, rot=face, seg=24, mseg=6)
    for x, z, r in ((-0.22, 0.18, 0.08), (0.18, 0.22, 0.07), (0.25, -0.15, 0.09), (-0.15, -0.2, 0.07), (0.0, 0.02, 0.08)):
        cyl(P, "FF4A6A", halo + Vector((x, 0.04, z)), r, 0.02, rot=face, verts=12, kind="Neon")
    torus(P, "FFC8F0", halo + Vector((0.25, 0.05, -0.15)), 0.14, 0.012, rot=(math.radians(70), 0.4, 0), kind="Neon", seg=16, mseg=4)
    for x, z in ((-0.3, -0.02), (0.05, 0.32), (0.32, 0.05), (-0.05, -0.36)):
        flat(P, WHITE, star_points(0.04, 0.016), 0.01, c=halo + Vector((x, 0.04, z)), kind="Neon")
    for x, z in ((0.1, -0.3), (-0.33, 0.12)):
        torus(P, "3A2A6A", halo + Vector((x, 0.04, z)), 0.035, 0.015, rot=face, seg=10, mseg=4)


# ---------------------------------------------------------------- registry

EGGS = {
    "GardenEgg": ["DoughHamster", "BasilBunny", "TomatoCat", "CheeseMouse", "OliveOwl", "PizzaDragon"],
    "FarmEgg": ["FarmChick", "CornPiglet", "PepperGoat", "OnionCow", "HayHorse", "GoldenRooster"],
    "BeachEgg": ["SandCrab", "ShellTurtle", "ShrimpSeal", "PineappleParrot", "TunaDolphin", "CoralKraken"],
    "IceEgg": ["IcePenguin", "SnowFox", "PeaWalrus", "SalmonBear", "LettuceYeti", "FrostPhoenix"],
    "VolcanoEgg": ["LavaLizard", "ChiliSalamander", "MagmaMole", "JalapenoGolem", "FireWolf", "LavaTitan"],
    "CandyEgg": ["GummyWorm", "LollipopPoodle", "MarshmallowSheep", "ChocoBear", "CottonCandyUnicorn", "CaramelGriffin"],
    "SpaceEgg": ["MoonMouse", "StarCat", "AlienFrog", "RocketDog", "CometWhale", "GalaxyDragon"],
    # Second egg per world (#39/#40)
    "StoneOvenEgg": ["RucolaHedgehog", "ParmesanRaccoon", "TruffleFox", "StoneOvenPhoenix"],
    "BarnEgg": ["PumpkinCat", "ButterDonkey", "HoneyBear", "GoldGrainBull"],
    "ShellEgg": ["CoconutMonkey", "ShellSeahorse", "SardineShark", "PearlSeaSerpent"],
    "GlacierEgg": ["MintReindeer", "SundaePolarBear", "VanillaMammoth", "SorbetNarwhal"],
    "MagmaEgg": ["PepperScorpion", "HabaneroRhino", "CurryTiger", "CalzoneHydra"],
    "BonbonEgg": ["DonutDachshund", "PuddingPanda", "LicoricePanther", "CakePegasus"],
    "NebulaEgg": ["MooncakeBunny", "StarfruitJellyfish", "StardustLion", "GalaxyPizzaLeviathan"],
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
SECOND_EGG_WORLD = {"StoneOvenEgg": "GardenEgg", "BarnEgg": "FarmEgg", "ShellEgg": "BeachEgg", "GlacierEgg": "IceEgg", "MagmaEgg": "VolcanoEgg", "BonbonEgg": "CandyEgg", "NebulaEgg": "SpaceEgg"}
for _second, _first in SECOND_EGG_WORLD.items():
    SHEET_COLORS[_second] = SHEET_COLORS[_first]


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
    pets = EGGS[egg]
    for i, name in enumerate(pets):
        # Camera looks from +Y, so +X is on the left: first pet (most common) on the left.
        objs += build(name, offset=(((len(pets) - 1) / 2 - i) * 1.75, 0, 0))
    sky, ground = SHEET_COLORS[egg]
    render(objs, os.path.join(PREVIEW_DIR, f"{egg}.png"), (200 * len(pets), 400), sky, ground=ground, distance=2.95, yaw=0, lift=0.14, samples=48)
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
