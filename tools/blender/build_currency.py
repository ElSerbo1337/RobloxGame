"""Builds the coin and the gem (#49) with preview renders.

Run headless (bpy from pip, Python 3.13):
    python tools/blender/build_currency.py [Coin | Gem | Currency]

Writes assets/models/<Name>.fbx and assets/previews/<Name>.png; "Currency" renders both
side by side (assets/previews/Currency.png).

Same look as the HUD icons (UiKit.coinIcon / UiKit.gemIcon):
- Coin: gold coin with a raised rim and an embossed pizza slice on both sides. Built lying
  flat (face up, 2 units wide) like the toppings: the sell animation dresses a gold disc
  with it (ModelLibrary.dressDisc) and spins it upright.
- Gem: faceted turquoise diamond (table on top, pointed bottom), facets alternate light and
  dark, a small glowing shine on the crown. Stands on its tip, 2 units wide.
Part names are palette entries in ModelLibrary (CoinGold, CoinRim, CoinEmboss, GemLight,
GemMid, GemDark, GemShine), keep COLORS in sync with PALETTE there.
"""

import math
import os
import sys

import bpy  # noqa: I001  (bpy must be imported before bmesh)
from mathutils import Matrix, Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import build_models as base  # noqa: E402  (render setup)
import build_toppings as top  # noqa: E402  (shapes, joining per colour)

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
MODEL_DIR = os.path.join(ROOT, "assets", "models")
PREVIEW_DIR = os.path.join(ROOT, "assets", "previews")

COLORS = {
    "CoinGold": ((255, 200, 40), None),
    "CoinRim": ((222, 146, 18), None),
    "CoinEmboss": ((255, 226, 110), None),
    "GemLight": ((150, 245, 255), None),
    "GemMid": ((60, 230, 255), None),
    "GemDark": ((20, 150, 200), None),
    "GemShine": ((230, 255, 255), "Neon"),
}

_materials = {}


def material(name):
    if name in _materials:
        return _materials[name]
    rgb, kind = COLORS[name]
    color = tuple(top.lin(c) for c in rgb) + (1.0,)
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = color
    bsdf.inputs["Roughness"].default_value = 0.35 if name.startswith("Coin") else 0.2
    if name.startswith("Coin"):
        bsdf.inputs["Metallic"].default_value = 0.6
    if kind == "Neon":
        bsdf.inputs["Emission Color"].default_value = color
        bsdf.inputs["Emission Strength"].default_value = 3.0
    mat.diffuse_color = color
    _materials[name] = mat
    return mat


top.material = material  # top.commit colours the joined parts with our palette names


def put(obj, name, mirror=False):
    """Registers a piece under its palette name; `mirror` adds a copy flipped to the back."""
    top.applied(obj)
    top._groups.setdefault(name, []).append(obj)
    if mirror:
        copy = obj.copy()
        copy.data = obj.data.copy()
        bpy.context.collection.objects.link(copy)
        copy.data.transform(Matrix.Scale(-1, 4, Vector((0, 0, 1))))
        top._groups[name].append(copy)
    return obj


# ---------------------------------------------------------------- coin


def build_coin():
    half = 0.11
    put(top.cylinder(1.0, half * 2, (0, 0, 0), verts=28), "CoinRim")
    # Raised rim and the flat face inside it, on both sides.
    put(top.band(top.outline(0.99, 28), top.outline(0.8, 28), half, 0.05), "CoinGold", mirror=True)
    put(top.slab(top.outline(0.8, 28), half, 0.012), "CoinGold", mirror=True)
    # Embossed pizza slice: tip down, crust on top, three salami dots.
    z = half + 0.012
    slice_pts = [(0.0, -0.56), (0.4, 0.3), (0.0, 0.36), (-0.4, 0.3)]
    put(top.slab(slice_pts, z, 0.03), "CoinEmboss", mirror=True)
    crust = [(math.sin(a) * 0.5, 0.2 + math.cos(a) * 0.22) for a in [-1.2 + 0.3 * k for k in range(9)]]
    put(top.strip(crust, 0.12, z, 0.045), "CoinRim", mirror=True)
    for x, y in ((-0.1, 0.12), (0.12, 0.04), (0.0, -0.18)):
        put(top.cylinder(0.075, 0.02, (x, y, z + 0.04), verts=10), "CoinRim", mirror=True)


# ---------------------------------------------------------------- gem


GEM_CENTER = Vector((0, 0, 0.9))


def facet(pts):
    """One gem facet as a thin closed plate (facing away from the gem's middle), so the
    normals come out right after joining and nothing vanishes to backface culling."""
    n = len(pts)
    normal = (pts[1] - pts[0]).cross(pts[2] - pts[0]).normalized()
    centroid = sum(pts, Vector()) / n
    if normal.dot(centroid - GEM_CENTER) < 0:
        pts = list(reversed(pts))
        normal = -normal
    inner = [p - normal * 0.02 for p in pts]
    faces = [list(range(n)), list(reversed(range(n, 2 * n)))]
    for i in range(n):
        j = (i + 1) % n
        faces.append([j, i, n + i, n + j])
    return top.mesh_obj(pts + inner, faces)


def build_gem():
    sides = 8
    girdle_z, table_z = 1.05, 1.5
    r_girdle, r_table = 1.0, 0.56
    turn = math.pi / sides

    def ring(r, z, offset=0.0):
        return [Vector((math.cos(2 * math.pi * i / sides + offset) * r, math.sin(2 * math.pi * i / sides + offset) * r, z)) for i in range(sides)]

    girdle = ring(r_girdle, girdle_z)
    girdle_top = ring(r_girdle, girdle_z + 0.08)
    table = ring(r_table, table_z, turn)
    tip = Vector((0, 0, 0))
    for i in range(sides):
        j = (i + 1) % sides
        # Pavilion (pointed bottom): two facets per side, alternating dark and mid.
        mid = (girdle[i] + girdle[j]) / 2 * 0.98
        put(facet([tip, girdle[i], mid]), "GemDark")
        put(facet([tip, mid, girdle[j]]), "GemMid")
        # Thin girdle band.
        put(facet([girdle[i], girdle[j], girdle_top[j], girdle_top[i]]), "GemMid")
        # Crown: a star facet up to the table and two side facets.
        put(facet([girdle_top[i], girdle_top[j], table[i]]), "GemLight" if i % 2 == 0 else "GemMid")
        put(facet([girdle_top[j], table[j], table[i]]), "GemMid" if i % 2 == 0 else "GemLight")
    put(facet(table), "GemLight")
    # Shine: a small glowing sliver on the crown, on the side the preview camera sees.
    a = math.radians(70)
    c = Vector((math.cos(a) * 0.72, math.sin(a) * 0.72, (girdle_z + table_z) / 2 + 0.06))
    put(top.ico(0.1, tuple(c), scale=(2.4, 1.0, 0.6), subdiv=1), "GemShine")


MODELS = {"Coin": build_coin, "Gem": build_gem}


def build(name, width=2.0, offset=(0, 0, 0)):
    MODELS[name]()
    objs = top.commit()
    lo, hi = base.scene_bounds(objs)
    scale = width / max(hi.x - lo.x, hi.y - lo.y)
    center = Vector(((lo.x + hi.x) / 2, (lo.y + hi.y) / 2, lo.z))
    m = Matrix.Translation(Vector(offset)) @ Matrix.Scale(scale, 4) @ Matrix.Translation(-center)
    for o in objs:
        o.data.transform(m)
        o.data.update()
    return objs


def reset_scene():
    top.reset_scene()
    _materials.clear()


def export(name):
    reset_scene()
    objs = build(name)
    for o in bpy.context.scene.objects:
        o.select_set(o in objs)
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
    base.setup_render(objs, os.path.join(PREVIEW_DIR, f"{name}.png"), size=512, distance=2.4)
    print(f"built {name}: {sorted(o.name for o in objs)}")


def overview():
    """Coin standing up next to the gem, like in the game."""
    reset_scene()
    coin = build("Coin")
    for o in coin:
        o.name = f"c_{o.name}"
        o.data.transform(Matrix.Translation((1.4, 0, 1.0)) @ Matrix.Rotation(math.radians(90), 4, "X"))
    gem = build("Gem", 1.8, (-1.4, 0, 0.1))
    for o in gem:
        o.name = f"g_{o.name}"
    base.setup_render(base.model_objects(), os.path.join(PREVIEW_DIR, "Currency.png"), size=640, distance=3.2)


if __name__ == "__main__":
    names = [a for a in sys.argv[1:] if a in MODELS or a == "Currency"] or [*MODELS, "Currency"]
    for n in names:
        if n == "Currency":
            overview()
        else:
            export(n)
