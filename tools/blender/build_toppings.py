"""Builds the topping models of worlds 2-7 (#18) with preview renders.

Run headless (bpy from pip, Python 3.13):
    python tools/blender/build_toppings.py [ToppingId ... | World2 ... World7 | Overview]

Writes assets/models/toppings/<ToppingId>.fbx, assets/previews/toppings/<ToppingId>.png,
assets/previews/toppings/World<N>.png (the world's toppings lying on its topping field and
on the pizza in the hand, true to scale) and Overview.png (all toppings side by side).

Style like the salami of #24: flat, low-poly, saturated colours, a slightly darker rim or
underside so every topping reads from above on any ground and on the pizza. Toppings are
flat enough to lie on the pizza (Roblox scales them to the topping width, see
ModelLibrary.dressDisc). World effects: frosty (world 4, glass ice bits), hot (world 5,
glowing grease and flames), sweet glass gummies (world 6), neon space (world 7).

Topping parts carry their colour in the name like pets and eggs: "Top_F59AAA",
"Top_785AFF_Neon", "Top_A8DCFF_Glass" (ModelLibrary reads them, no palette entry needed).
Every model is centered, its bottom at z = 0 and 2 units wide (X/Y).
"""

import math
import os
import random
import sys

import bpy  # noqa: I001  (bpy must be imported before bmesh)
import bmesh
from mathutils import Matrix, Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import build_models as base  # noqa: E402  (pizza, render setup)

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
MODEL_DIR = os.path.join(ROOT, "assets", "models", "toppings")
PREVIEW_DIR = os.path.join(ROOT, "assets", "previews", "toppings")

# ---------------------------------------------------------------- parts and materials

_groups = {}  # part name -> objects, joined into one mesh per colour at the end
_materials = {}


def lin(c):
    c = c / 255
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def hex_rgb(h):
    return tuple(int(h[i : i + 2], 16) for i in (0, 2, 4))


def material(name):
    if name in _materials:
        return _materials[name]
    parts = name.split("_")
    color = tuple(lin(c) for c in hex_rgb(parts[1])) + (1.0,)
    kind = parts[2] if len(parts) > 2 else None
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = color
    bsdf.inputs["Roughness"].default_value = 0.6
    if kind == "Glass":
        bsdf.inputs["Roughness"].default_value = 0.1
        bsdf.inputs["Alpha"].default_value = 0.65
    if kind == "Neon":
        bsdf.inputs["Emission Color"].default_value = color
        bsdf.inputs["Emission Strength"].default_value = 3.0
    mat.diffuse_color = color
    _materials[name] = mat
    return mat


def part(obj, hex_color, kind=None):
    """Registers a finished piece under its colour name (Top_RRGGBB[_Neon|_Glass])."""
    name = f"Top_{hex_color.upper()}" + (f"_{kind}" if kind else "")
    applied(obj)
    _groups.setdefault(name, []).append(obj)
    return obj


def applied(obj):
    for o in bpy.context.selected_objects:
        o.select_set(False)
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    return obj


def commit():
    """Joins the pieces per colour, names them, flat shading, triangulated."""
    result = []
    for name, objs in _groups.items():
        for o in bpy.context.selected_objects:
            o.select_set(False)
        for o in objs:
            o.select_set(True)
        bpy.context.view_layer.objects.active = objs[0]
        if len(objs) > 1:
            bpy.ops.object.join()
        obj = bpy.context.view_layer.objects.active
        obj.name = name
        obj.data.name = name
        bm = bmesh.new()
        bm.from_mesh(obj.data)
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
        bmesh.ops.triangulate(bm, faces=bm.faces[:], quad_method="BEAUTY", ngon_method="EAR_CLIP")
        bm.to_mesh(obj.data)
        bm.free()
        for poly in obj.data.polygons:
            poly.use_smooth = False
        obj.data.materials.clear()
        obj.data.materials.append(material(name))
        result.append(obj)
    _groups.clear()
    return result


def reset_scene():
    base.reset_scene()
    _groups.clear()
    _materials.clear()


# ---------------------------------------------------------------- shapes


def mesh_obj(verts, faces):
    me = bpy.data.meshes.new("piece")
    me.from_pydata([tuple(v) for v in verts], [], faces)
    me.update()
    obj = bpy.data.objects.new("piece", me)
    bpy.context.collection.objects.link(obj)
    return obj


def outline(r, n=24, wobble=0.0, seed=0, fn=None, center=(0, 0), stretch=(1, 1), rot=0.0):
    """Closed 2D outline: radius r (times fn(angle)), stretched, turned and moved.
    The same seed gives the same wobble, so outlines of different radius stay parallel."""
    rnd = random.Random(seed)
    pts = []
    for i in range(n):
        a = 2 * math.pi * i / n
        rr = r * (fn(a) if fn else 1.0) * (1 + rnd.uniform(-wobble, wobble))
        x, y = math.cos(a) * rr * stretch[0], math.sin(a) * rr * stretch[1]
        x, y = x * math.cos(rot) - y * math.sin(rot), x * math.sin(rot) + y * math.cos(rot)
        pts.append((center[0] + x, center[1] + y))
    return pts


def star(r_out, r_in, points=5, center=(0, 0), rot=0.0):
    pts = []
    for i in range(points * 2):
        a = math.pi / 2 + rot + math.pi * i / points
        r = r_out if i % 2 == 0 else r_in
        pts.append((center[0] + math.cos(a) * r, center[1] + math.sin(a) * r))
    return pts


def slab(pts, z0, depth):
    """A flat piece: the outline extruded upwards from z0."""
    n = len(pts)
    verts = [(x, y, z0) for x, y in pts] + [(x, y, z0 + depth) for x, y in pts]
    faces = [list(reversed(range(n))), list(range(n, 2 * n))]
    for i in range(n):
        j = (i + 1) % n
        faces.append([i, j, n + j, n + i])
    return mesh_obj(verts, faces)


def band(outer, inner, z0, depth):
    """A ring between two outlines with the same number of points (hole in the middle)."""
    n = len(outer)
    verts = []
    for pts, z in ((outer, z0), (outer, z0 + depth), (inner, z0), (inner, z0 + depth)):
        verts += [(x, y, z) for x, y in pts]
    ob, ot, ib, it = 0, n, 2 * n, 3 * n
    faces = []
    for i in range(n):
        j = (i + 1) % n
        faces.append([ob + i, ob + j, ot + j, ot + i])  # outer wall
        faces.append([ib + j, ib + i, it + i, it + j])  # inner wall
        faces.append([ot + i, ot + j, it + j, it + i])  # top
        faces.append([ob + j, ob + i, ib + i, ib + j])  # bottom
    return mesh_obj(verts, faces)


def strip(path, width, z0, depth):
    """A flat stripe of constant width along a 2D polyline."""
    left, right = [], []
    for i, (x, y) in enumerate(path):
        ax, ay = path[max(i - 1, 0)]
        bx, by = path[min(i + 1, len(path) - 1)]
        dx, dy = bx - ax, by - ay
        length = math.hypot(dx, dy) or 1
        nx, ny = -dy / length * width / 2, dx / length * width / 2
        left.append((x + nx, y + ny))
        right.append((x - nx, y - ny))
    return slab(left + list(reversed(right)), z0, depth)


def tube(path, radii, segs=8, flat=1.0):
    """A closed tube along a 3D path (mostly in the XY plane), radius per point.
    `flat` < 1 squashes it vertically."""
    verts, faces = [], []
    n = len(path)
    for i, p in enumerate(path):
        p = Vector(p)
        a = Vector(path[max(i - 1, 0)])
        b = Vector(path[min(i + 1, n - 1)])
        t = (b - a).normalized()
        side = t.cross(Vector((0, 0, 1))).normalized()
        up = side.cross(t).normalized()
        for k in range(segs):
            phi = 2 * math.pi * k / segs
            offset = side * math.cos(phi) * radii[i] + up * math.sin(phi) * radii[i] * flat
            verts.append(p + offset)
    for i in range(n - 1):
        for k in range(segs):
            m = (k + 1) % segs
            faces.append([i * segs + k, i * segs + m, (i + 1) * segs + m, (i + 1) * segs + k])
    start = len(verts)
    verts.append(Vector(path[0]))
    verts.append(Vector(path[-1]))
    last = (n - 1) * segs
    for k in range(segs):
        m = (k + 1) % segs
        faces.append([start, m, k])
        faces.append([start + 1, last + k, last + m])
    obj = mesh_obj(verts, faces)
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    bm.to_mesh(obj.data)
    bm.free()
    return obj


def sphere(r, loc, scale=(1, 1, 1), segments=10, rings=7):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments, ring_count=rings, radius=r, location=loc)
    obj = bpy.context.active_object
    obj.scale = scale
    return applied(obj)


def ico(r, loc, scale=(1, 1, 1), subdiv=1):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=subdiv, radius=r, location=loc)
    obj = bpy.context.active_object
    obj.scale = scale
    return applied(obj)


def cylinder(r, depth, loc, verts=12, rot=(0, 0, 0), scale=(1, 1, 1)):
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=r, depth=depth, location=loc, rotation=rot)
    obj = bpy.context.active_object
    obj.scale = scale
    return applied(obj)


def cone(r1, r2, depth, loc, verts=10, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=r1, radius2=r2, depth=depth, location=loc, rotation=rot)
    return applied(bpy.context.active_object)


def cut_below(obj, z):
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


def deform(obj, fn):
    """Moves every vertex: fn(Vector) -> Vector."""
    for v in obj.data.vertices:
        v.co = fn(v.co.copy())
    obj.data.update()
    return obj


def cup(k, center=(0, 0)):
    """Edges curl up (pepperoni, lettuce): z grows with the squared distance."""

    def fn(co):
        d2 = (co.x - center[0]) ** 2 + (co.y - center[1]) ** 2
        co.z += k * d2
        return co

    return fn


def jitter(obj, amount, seed):
    rnd = random.Random(seed)
    return deform(obj, lambda co: co + Vector([rnd.uniform(-amount, amount) for _ in range(3)]))


def rimmed(pts_fn, rim, top, z0=0.0, depth=0.1, inset=0.07, lift=0.012):
    """Salami-style slice: darker rim part with the main colour slightly on top of it, so
    the rim shows as a thin outline from above. pts_fn(radius_offset) -> outline."""
    part(slab(pts_fn(0.0), z0, depth), rim)
    part(slab(pts_fn(-inset), z0 + lift, depth), top)


# ---------------------------------------------------------------- world 2: Bauernhof


def build_onion():
    # A red onion slice: dark purple skin, pale layers each with a thin purple edge.
    rings = [(1.00, "6E2662"), (0.94, "F6E6F2")]
    for r in (0.76, 0.56, 0.36, 0.17):
        rings += [(r + 0.05, "B0509E"), (r, "F6E6F2")]
    for i, (r, color) in enumerate(rings):
        part(slab(outline(r, 28, 0.03, 18), 0, 0.14 + 0.012 * i), color)


def pepper_ring(center, r, rot, skin, flesh, seed, z0=0.0):
    lobes = lambda a: 1 + 0.1 * math.cos(4 * (a + rot))  # noqa: E731
    o = lambda off: outline(r + off, 32, 0.02, seed, lobes, center)  # noqa: E731
    part(band(o(0), o(-0.2), z0, 0.16), skin)
    part(band(o(-0.04), o(-0.17), z0 + 0.02, 0.16), flesh)


def build_bell_pepper():
    # Two lobed pepper rings, green and red, the ground shows through the middle.
    pepper_ring((-0.3, 0.12), 0.68, 0.0, "1E7A2A", "5CBF42", 1)
    pepper_ring((0.42, -0.22), 0.55, 0.4, "A4201C", "E8402E", 2, 0.19)


def build_corn():
    # A small heap of corn kernels on a green husk leaf.
    for i, rot in enumerate((0.35, -0.5)):
        leaf = outline(1.0, 16, 0.0, 0, lambda a: 1 - 0.55 * abs(math.sin(a)) ** 0.6, stretch=(1.0, 0.36), rot=rot)
        part(deform(slab(leaf, 0.0 + 0.02 * i, 0.06), cup(0.06)), "6CB83C" if i == 0 else "8ED458")
    rnd = random.Random(12)
    spots = [(0, 0, 0.22)]
    for ring, count in ((0.34, 6), (0.64, 9)):
        for k in range(count):
            a = 2 * math.pi * k / count + ring
            spots.append((math.cos(a) * ring, math.sin(a) * ring, 0.16 - 0.08 * ring))
    for i, (x, y, z) in enumerate(spots):
        color = "F2A81E" if i % 4 == 1 else "FFD23A"
        kernel = ico(0.19, (x, y, z + 0.1), scale=(1, 0.85, 0.75))
        kernel.rotation_euler = (0, 0, rnd.uniform(0, math.pi))
        part(jitter(kernel, 0.015, 30 + i), color)


def build_ham():
    # A rounded square ham slice with a white fat edge on one side and light marbling.
    square = lambda a: 1 / (abs(math.cos(a)) ** 3 + abs(math.sin(a)) ** 3) ** (1 / 3)  # noqa: E731
    o = lambda off: outline(0.95 + off, 32, 0.03, 7, square, rot=0.15)  # noqa: E731
    rimmed(o, "C8566C", "F59AAA", depth=0.1, inset=0.06)
    fat_outer = [p for i, p in enumerate(o(-0.02)) if 3 <= i <= 13]
    fat_inner = [p for i, p in enumerate(o(-0.2)) if 3 <= i <= 13]
    part(slab(fat_outer + list(reversed(fat_inner)), 0.015, 0.105), "FFF2EC")
    for i, path in enumerate(([(-0.5, -0.3), (-0.15, -0.45), (0.25, -0.35)], [(-0.45, 0.05), (-0.1, -0.08), (0.35, 0.02)])):
        part(strip(path, 0.06, 0.02, 0.1), "FFC2CC")


# ---------------------------------------------------------------- world 3: Strand


def build_tuna():
    # Four chunky tuna flakes, each with a darker underside, light flake lines on top.
    chunks = [((-0.45, 0.3), 0.48, 0.2), ((0.42, 0.35), 0.42, 1.1), ((-0.25, -0.42), 0.44, 2.0), ((0.45, -0.38), 0.36, 2.9)]
    for i, (center, r, rot) in enumerate(chunks):
        o = lambda off, c=center, r=r, rot=rot, i=i: outline(r + off, 11, 0.16, 40 + i, center=c, stretch=(1.0, 0.75), rot=rot)  # noqa: E731
        part(jitter(slab(o(0), 0, 0.1), 0.012, 50 + i), "9E5A5E")
        part(jitter(slab(o(-0.05), 0.012, 0.1), 0.01, 60 + i), "D88C88")
        # A smaller flake lying on top, shifted, so the chunk looks flaky.
        cx, cy = center
        top = outline(r * 0.62, 9, 0.18, 70 + i, center=(cx + 0.08, cy + 0.05), stretch=(1.0, 0.75), rot=rot + 0.6)
        part(jitter(slab(top, 0.09, 0.08), 0.01, 80 + i), "F0B4AA")


def arc_path(radius, a0, a1, steps, z):
    return [(math.cos(a0 + (a1 - a0) * t / steps) * radius, math.sin(a0 + (a1 - a0) * t / steps) * radius, z) for t in range(steps + 1)]


def build_shrimp():
    # A curled shrimp: striped segments along a C, red tail fan at the end.
    path = arc_path(0.55, math.radians(210), math.radians(-60), 18, 0.3)
    radii = [0.36 - 0.2 * (i / 18) for i in range(19)]
    for k in range(6):
        lo, hi = k * 3, min(k * 3 + 3, 18)
        part(tube(path[lo : hi + 1], radii[lo : hi + 1], 10, 0.75), "FF8460" if k % 2 == 0 else "FFB894")
    end = Vector(path[-1])
    tangent = (end - Vector(path[-2])).normalized()
    for side in (-1, 1):
        direction = tangent.copy()
        direction.rotate(__import__("mathutils").Euler((0, 0, side * 0.5)))
        tip = end + direction * 0.42
        normal = Vector((-direction.y, direction.x, 0)) * 0.13
        fan = [(end.x, end.y), (tip.x + normal.x, tip.y + normal.y), (tip.x - normal.x, tip.y - normal.y)]
        part(slab(fan, 0.2, 0.08), "E8503A")


def build_pineapple():
    # A pineapple ring: brownish rind, yellow flesh with radial fibres, pale core ring.
    o = lambda r: outline(r, 28, 0.015, 3)  # noqa: E731
    part(band(o(1.0), o(0.3), 0, 0.15), "C88A1E")
    part(band(o(0.93), o(0.36), 0.012, 0.16), "FFE15A")
    part(band(o(0.38), o(0.24), 0.0, 0.17), "FFF4B0")
    for k in range(12):
        a = 2 * math.pi * k / 12 + 0.13
        path = [(math.cos(a) * 0.48, math.sin(a) * 0.48), (math.cos(a) * 0.84, math.sin(a) * 0.84)]
        part(strip(path, 0.05, 0.03, 0.15), "F2B92C")


# ---------------------------------------------------------------- world 4: Eisberge (frosty)


def ice_bits(spots, seed):
    rnd = random.Random(seed)
    for i, (x, y, z, r) in enumerate(spots):
        bit = ico(r, (x, y, z), scale=(1, 1, 1.4), subdiv=0)
        bit.rotation_euler = (rnd.uniform(0, 0.5), rnd.uniform(0, 0.5), rnd.uniform(0, math.pi))
        part(bit, "A8DCFF", "Glass")


def build_frozen_peas():
    # A little heap of peas with frost caps and glassy ice crystals between them.
    peas = [(0, 0, 0.42), (0.58, 0.1, 0.3), (-0.55, 0.2, 0.3), (0.2, 0.58, 0.3), (-0.2, -0.56, 0.3), (0.5, -0.45, 0.3), (-0.42, 0.62, 0.28), (-0.68, -0.38, 0.28)]
    for i, (x, y, z) in enumerate(peas):
        part(jitter(sphere(0.3, (x, y, z), segments=10, rings=7), 0.012, 70 + i), "5CB848" if i % 3 else "78CC5C")
        if i % 2 == 0:
            frost = sphere(0.27, (x, y, z + 0.2), scale=(1, 1, 0.45), segments=10, rings=6)
            part(cut_below(frost, z + 0.21), "F0FAFF")
    ice_bits([(0.3, 0.3, 0.2, 0.13), (-0.3, -0.15, 0.2, 0.11), (0.62, 0.58, 0.12, 0.12), (-0.05, -0.85, 0.12, 0.1)], 5)


def build_salmon():
    # A salmon slice: orange with white fat stripes, darker rim, dusted with frost.
    soft = lambda a: 1 / (abs(math.cos(a)) ** 2.6 + abs(math.sin(a)) ** 2.6) ** (1 / 2.6)  # noqa: E731
    o = lambda off: outline(1.0 + off, 32, 0.02, 9, soft, stretch=(1.0, 0.68), rot=0.35)  # noqa: E731
    rimmed(o, "D25A34", "FA825A", depth=0.14, inset=0.07)
    for k in range(4):
        x0 = -0.55 + 0.36 * k
        path = [(x0 - 0.18 + 0.3 * t / 6 + 0.06 * math.sin(t), -0.45 + 0.9 * t / 6) for t in range(7)]
        path = [(x * math.cos(0.35) - y * math.sin(0.35) * 0.7, x * math.sin(0.35) + y * math.cos(0.35) * 0.7) for x, y in path]
        part(strip(path, 0.055, 0.03, 0.135), "FFF0E6")
    for i, (x, y) in enumerate(((-0.35, 0.25), (0.4, -0.1), (0.05, 0.42), (-0.1, -0.35))):
        part(ico(0.06, (x, y, 0.16), scale=(1, 1, 0.6), subdiv=0), "F4FBFF")
    ice_bits([(0.55, 0.35, 0.18, 0.1)], 6)


def build_iceberg_lettuce():
    # Three crinkly lettuce leaves, cupped, with glassy ice shards.
    wavy = lambda a: 1 + 0.12 * math.sin(7 * a) + 0.05 * math.sin(13 * a + 1)  # noqa: E731
    leaves = [((-0.25, 0.1), 0.85, 0.3, "6EBE4E"), ((0.3, -0.12), 0.72, 1.5, "A6E07E"), ((0.0, 0.05), 0.5, 2.6, "D6F5BC")]
    for i, (center, r, rot, color) in enumerate(leaves):
        leaf = slab(outline(r, 36, 0.03, 80 + i, wavy, center, (1.0, 0.75), rot), 0.03 * i, 0.07)
        part(deform(leaf, cup(0.22, center)), color)
        vein = [(center[0] + math.cos(rot) * r * t, center[1] + math.sin(rot) * r * 0.75 * t) for t in (-0.6, 0.0, 0.6)]
        part(deform(strip(vein, 0.05, 0.03 * i + 0.05, 0.05), cup(0.22, center)), "F2FFE6")
    ice_bits([(0.62, 0.48, 0.25, 0.14), (-0.7, -0.4, 0.25, 0.12), (0.1, -0.6, 0.2, 0.1)], 7)


# ---------------------------------------------------------------- world 5: Vulkan (hot)


def build_chili():
    # A curved red chili with a green stem and a glowing hot tip.
    steps = 16
    path = []
    radii = []
    for i in range(steps + 1):
        t = i / steps
        path.append((-0.85 + 1.75 * t, 0.35 * math.sin(math.pi * t * 0.9) - 0.15, 0.28 - 0.12 * t))
        radii.append(0.06 + 0.24 * (1 - t) ** 0.7 if t > 0.05 else 0.22)
    part(tube(path, radii, 10, 0.85), "E01E1E")
    highlight = [(x, y + 0.06, z + 0.17) for x, y, z in path[2:10]]
    part(tube(highlight, [0.04] * len(highlight), 6, 0.5), "FF6A5A")
    part(cone(0.24, 0.1, 0.16, (-0.9, -0.15, 0.3), 8, rot=(0, math.radians(-90), 0)), "3C8C28")
    stem = [(-0.95, -0.15, 0.3), (-1.1, -0.12, 0.36), (-1.18, -0.02, 0.48)]
    part(tube(stem, [0.07, 0.06, 0.05], 6), "2E7A1E")
    tip = path[-3:]
    part(tube(tip, [radii[-3] * 1.05, radii[-2] * 1.08, radii[-1] * 1.1], 10, 0.85), "FF8A1A", "Neon")


def build_pepperoni():
    # Three small cupped pepperoni slices (not the flat salami): a raised dark rim, darker
    # spots and glowing grease in the middle of each cup.
    slices = [((-0.38, 0.28), 0.52), ((0.42, 0.22), 0.46), ((0.0, -0.42), 0.5)]
    for i, (c, r) in enumerate(slices):
        o = lambda off, c=c, r=r, i=i: outline(r + off, 20, 0.03, 90 + i, center=c)  # noqa: E731
        z0 = 0.05 * i
        part(slab(o(-0.04), z0, 0.08), "E0502E")
        part(band(o(0), o(-0.07), z0, 0.13), "A82E1C")
        part(slab(outline(0.13, 10, 0.1, i, center=c), z0 + 0.06, 0.04), "FFA040", "Neon")
        rnd = random.Random(100 + i)
        for k in range(3):
            a = rnd.uniform(0, 2 * math.pi)
            d = rnd.uniform(0.22, 0.32) * r / 0.5
            spot = (c[0] + math.cos(a) * d, c[1] + math.sin(a) * d)
            part(slab(outline(0.05, 6, 0.2, k, center=spot), z0 + 0.06, 0.03), "A42A18")


def jalapeno_slice(c, r, seed, z0):
    o = lambda rr: outline(rr, 20, 0.04, seed, center=c)  # noqa: E731
    part(slab(o(r), z0, 0.12), "2E7A1E")
    part(band(o(r - 0.07), o(r * 0.55), z0 + 0.012, 0.12), "78C84A")
    part(slab(o(r * 0.57), z0 + 0.006, 0.12), "DCEFA8")
    rnd = random.Random(seed)
    for k in range(5):
        a = 2 * math.pi * k / 5 + rnd.uniform(-0.2, 0.2)
        d = r * 0.3
        part(slab(outline(0.055, 8, 0.0, 0, center=(c[0] + math.cos(a) * d, c[1] + math.sin(a) * d), stretch=(1.4, 0.8), rot=a), z0 + 0.03, 0.11), "FFF6D2")


def build_jalapeno():
    # Two jalapeño slices: dark green skin, light flesh, pale core with seeds; a glowing ember.
    jalapeno_slice((-0.35, 0.2), 0.62, 11, 0.0)
    jalapeno_slice((0.45, -0.25), 0.52, 12, 0.05)
    part(ico(0.08, (0.05, -0.62, 0.08), subdiv=0), "FF8A1A", "Neon")


# ---------------------------------------------------------------- world 6: Süßigkeitenland


def build_chocolate_chips():
    # Four chocolate drops with a twisted tip, dark and milk chocolate.
    chips = [((-0.45, 0.3), 0.42, "5A2E16"), ((0.45, 0.35), 0.38, "8C5030"), ((-0.3, -0.45), 0.36, "8C5030"), ((0.42, -0.38), 0.4, "5A2E16")]
    for i, ((x, y), r, color) in enumerate(chips):
        drop = cone(r, 0.02, r * 1.15, (x, y, r * 0.575), 12)
        twist = lambda co, x=x, y=y, r=r: Vector((co.x + 0.12 * r * (co.z / r) ** 2, co.y, co.z))  # noqa: E731
        part(jitter(deform(drop, twist), 0.012, 110 + i), color)
        part(slab(outline(r * 1.04, 12, 0.0, 0, center=(x, y)), 0, 0.05), "3C1E0E")


def gummy_bear(c, color, rot, seed):
    def at(dx, dy, dz):
        x = dx * math.cos(rot) - dy * math.sin(rot)
        y = dx * math.sin(rot) + dy * math.cos(rot)
        return (c[0] + x, c[1] + y, dz)

    pieces = [
        sphere(0.36, at(0, 0, 0.36), (1, 0.85, 1.05)),  # body
        sphere(0.27, at(0, 0.05, 0.86), (1, 0.9, 0.9)),  # head
        sphere(0.1, at(-0.2, 0.05, 1.08)),  # ears
        sphere(0.1, at(0.2, 0.05, 1.08)),
        sphere(0.12, at(-0.32, 0.12, 0.5)),  # arms
        sphere(0.12, at(0.32, 0.12, 0.5)),
        sphere(0.14, at(-0.2, 0.18, 0.12), (1, 1.2, 0.8)),  # feet
        sphere(0.14, at(0.2, 0.18, 0.12), (1, 1.2, 0.8)),
    ]
    for p in pieces:
        part(p, color, "Glass")
    for dx in (-0.1, 0.1):
        part(sphere(0.04, at(dx, 0.27, 0.9), segments=6, rings=4), "3C2314")


def build_gummy_bears():
    # Two glassy gummy bears, pink and green, with little eyes (they face +Y like pets).
    gummy_bear((-0.42, 0.0), "FF5096", 0.25, 1)
    gummy_bear((0.45, -0.05), "5AD25A", -0.3, 2)


def build_marshmallow():
    # Three soft marshmallows, white and pink, one lying on its side.
    for i, (loc, rot, color) in enumerate(
        (
            ((-0.45, 0.3, 0.25), (0, 0, 0), "FFF6F8"),
            ((0.42, 0.25, 0.25), (0, 0, 0), "FFC8DC"),
            ((0.0, -0.42, 0.3), (math.radians(90), 0, 0.5), "FFF6F8"),
        )
    ):
        mallow = cylinder(0.32, 0.5, loc, 14, rot)
        bm = bmesh.new()
        bm.from_mesh(mallow.data)
        bmesh.ops.bevel(bm, geom=[e for e in bm.edges if not e.is_wire], offset=0.08, segments=2, affect="EDGES")
        bm.to_mesh(mallow.data)
        bm.free()
        part(mallow, color)
    part(slab(outline(0.2, 12, 0.08, 3, center=(-0.45, 0.3)), 0.49, 0.025), "F5D8A0")


# ---------------------------------------------------------------- world 7: Weltraum (neon)


def build_moon_cheese():
    # A wedge of pale moon cheese with craters on top and on the front.
    tri = [(-0.95, 0.0), (0.95, -0.72), (0.95, 0.72)]
    part(slab(tri, 0, 0.62), "F0E696")
    part(slab([(0.95, -0.72), (1.02, -0.72), (1.02, 0.72), (0.95, 0.72)], 0, 0.62), "D2B44A")
    for i, (x, y, r) in enumerate(((0.35, 0.05, 0.2), (-0.25, -0.02, 0.12), (0.7, -0.38, 0.12), (0.62, 0.42, 0.1))):
        part(slab(outline(r, 12, 0.08, i, center=(x, y)), 0.6, 0.04), "C8BE64")
        part(band(outline(r + 0.04, 12, 0.08, i, center=(x, y)), outline(r, 12, 0.08, i, center=(x, y)), 0.6, 0.06), "FFF8C0")
    for i, (x, z, r) in enumerate(((0.15, 0.3, 0.12), (-0.45, 0.22, 0.09))):
        y = -0.72 * (x + 0.95) / 1.9 - 0.015
        crater = cylinder(r, 0.04, (x, y, z), 12, rot=(math.radians(90), 0, math.atan2(0.72, 1.9)))
        part(crater, "C8BE64")


def build_star_olives():
    # Three star-shaped olive slices: dark rim, glowing violet body, a little yellow star inside.
    for i, (c, r, rot) in enumerate((((-0.4, 0.3), 0.55, 0.1), ((0.45, 0.25), 0.5, 0.5), ((0.0, -0.42), 0.52, -0.3))):
        z0 = 0.025 * i
        part(slab(star(r, r * 0.55, 5, c, rot), z0, 0.12), "3A2480")
        part(slab(star(r - 0.08, r * 0.55 - 0.05, 5, c, rot), z0 + 0.012, 0.12), "785AFF", "Neon")
        part(slab(star(r * 0.3, r * 0.15, 5, c, rot), z0 + 0.02, 0.12), "FFE66E", "Neon")


def alien_mushroom(c, size, seed):
    cap = sphere(0.62 * size, (c[0], c[1], 0.62 * size), (1, 1, 0.72), segments=14, rings=8)
    part(jitter(cut_below(cap, 0.66 * size), 0.012 * size, seed), "3CC864")  # matte cap (#48)
    part(cylinder(0.24 * size, 0.7 * size, (c[0], c[1], 0.35 * size), 10, scale=(1, 1, 1)), "E6DCFF")
    rnd = random.Random(seed)
    for k in range(5):
        a = 2 * math.pi * k / 5 + rnd.uniform(-0.3, 0.3)
        d = 0.36 * size
        z = 0.66 * size + 0.4 * size * math.sqrt(max(0.0, 1 - (d / (0.62 * size)) ** 2)) * 0.72
        part(sphere(0.09 * size, (c[0] + math.cos(a) * d, c[1] + math.sin(a) * d, z), (1, 1, 0.5), 8, 5), "B45AFF", "Neon")
    part(sphere(0.1 * size, (c[0], c[1], 0.66 * size + 0.44 * size), (1, 1, 0.5), 8, 5), "B45AFF", "Neon")


def build_alien_mushroom():
    # A big and a small alien mushroom: matte green caps with small glowing violet spots.
    alien_mushroom((-0.3, 0.05), 1.0, 1)
    alien_mushroom((0.62, -0.3), 0.62, 2)


# ---------------------------------------------------------------- registry

MODELS = {
    "Onion": build_onion,
    "BellPepper": build_bell_pepper,
    "Corn": build_corn,
    "Ham": build_ham,
    "Tuna": build_tuna,
    "Shrimp": build_shrimp,
    "Pineapple": build_pineapple,
    "FrozenPeas": build_frozen_peas,
    "Salmon": build_salmon,
    "IcebergLettuce": build_iceberg_lettuce,
    "Chili": build_chili,
    "Pepperoni": build_pepperoni,
    "Jalapeno": build_jalapeno,
    "ChocolateChips": build_chocolate_chips,
    "GummyBears": build_gummy_bears,
    "Marshmallow": build_marshmallow,
    "MoonCheese": build_moon_cheese,
    "StarOlives": build_star_olives,
    "AlienMushroom": build_alien_mushroom,
}

# World index -> (toppings, sky, topping field colour) - field colours from WorldMap THEMES.
WORLDS = {
    2: (["Onion", "BellPepper", "Corn", "Ham"], (255, 232, 190), (150, 120, 70)),
    3: (["Tuna", "Shrimp", "Pineapple"], (190, 236, 255), (225, 200, 135)),
    4: (["FrozenPeas", "Salmon", "IcebergLettuce"], (214, 236, 255), (180, 215, 240)),
    5: (["Chili", "Pepperoni", "Jalapeno"], (255, 170, 120), (150, 86, 62)),
    6: (["ChocolateChips", "GummyBears", "Marshmallow"], (255, 224, 240), (255, 230, 245)),
    7: (["MoonCheese", "StarOlives", "AlienMushroom"], (60, 50, 110), (110, 105, 140)),
}


def world_of(name):
    for index, (names, sky, ground) in WORLDS.items():
        if name in names:
            return sky, ground
    return (255, 236, 200), (150, 215, 120)


def build(name, width=2.0, offset=(0, 0, 0), spin=0.0):
    """Builds a topping, scaled to `width` (X/Y), bottom center at `offset`."""
    MODELS[name]()
    objs = commit()
    lo, hi = base.scene_bounds(objs)
    scale = width / max(hi.x - lo.x, hi.y - lo.y)
    center = Vector(((lo.x + hi.x) / 2, (lo.y + hi.y) / 2, lo.z))
    m = Matrix.Translation(Vector(offset)) @ Matrix.Rotation(spin, 4, "Z") @ Matrix.Scale(scale, 4) @ Matrix.Translation(-center)
    for o in objs:
        o.data.transform(m)
        o.data.update()
        o.name = f"{o.name}"
    return objs


def export(name):
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
    sky, ground = world_of(name)
    base.setup_render(objs, os.path.join(PREVIEW_DIR, f"{name}.png"), size=512, distance=2.2, sky=sky, ground_color=ground)
    print(f"built {name}: {sorted(o.name for o in objs)}")


def rename_unique(objs, tag):
    # Several copies of a topping in one scene: names only matter for the FBX files.
    for o in objs:
        o.name = f"{tag}_{o.name}"


def world_check(index):
    """The world's toppings on the pizza in the hand and on the field, true to scale:
    pizza 3.4 studs with 0.9-stud toppings (PizzaVisual), field toppings 3.5 studs
    (ToppingService) - here 1 unit = 1.7 studs."""
    reset_scene()
    names, sky, ground = WORLDS[index]
    base.build_pizza()  # 2 units = 3.4 studs
    on_pizza = 0.9 / 1.7
    count = 5
    for k in range(count):
        a = 2 * math.pi * k / count
        name = names[k % len(names)]
        objs = build(name, on_pizza, (math.cos(a) * 0.55, math.sin(a) * 0.55, 0.21), spin=a)
        rename_unique(objs, f"p{k}")
    on_ground = 3.5 / 1.7
    for k, name in enumerate(names):
        x = (k - (len(names) - 1) / 2) * (on_ground + 0.4)
        objs = build(name, on_ground, (x, -2.6, 0.0), spin=0.2 * k)
        rename_unique(objs, f"g{k}")
    objs = base.model_objects()
    base.setup_render(objs, os.path.join(PREVIEW_DIR, f"World{index}.png"), size=960, distance=1.9, sky=sky, ground_color=ground)


def overview():
    """All toppings of worlds 2-7, one row per world (world 2 in front)."""
    reset_scene()
    for row, (index, (names, _, _)) in enumerate(sorted(WORLDS.items())):
        for k, name in enumerate(names):
            x = (k - (len(names) - 1) / 2) * 2.5
            objs = build(name, 2.0, (x, -row * 2.5, 0.0))
            rename_unique(objs, f"w{index}_{k}")
    objs = base.model_objects()
    base.setup_render(objs, os.path.join(PREVIEW_DIR, "Overview.png"), size=1200, distance=1.6, sky=(255, 236, 200), ground_color=(132, 214, 88))


if __name__ == "__main__":
    args = sys.argv[1:]
    worlds = {f"World{i}": i for i in WORLDS}
    names = [a for a in args if a in MODELS or a in worlds or a == "Overview"]
    if not names:
        names = list(MODELS) + list(worlds) + ["Overview"]
    for n in names:
        if n in worlds:
            world_check(worlds[n])
        elif n == "Overview":
            overview()
        else:
            export(n)
