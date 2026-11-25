"""Renders preview images of the flying islands (#27) from the exported island plan.

    lune run export-islands build/islands.json
    python tools/blender/render_islands.py build/islands.json [view ...]

The plan (src/shared/IslandPlan.luau) is the same data the server builds the islands
from, so ground, cliffs, rim, paths, water, bridges and gates look exactly like in the
game. Stations use the Blender models of build_models.py at their in-game size, the way
they look once imported in Studio. Writes assets/previews/islands/<View>.jpg.

Coordinates: Roblox (x, y, z) -> Blender (x, -z, y); a station's front (Roblox -Z at
yaw 0) is Blender +Y, the same front every model in build_models.py is built with.
"""

import json
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import bpy  # noqa: E402,I001
import bmesh  # noqa: E402
from mathutils import Matrix, Vector  # noqa: E402

import build_models as bm_models  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT_DIR = os.path.join(ROOT, "assets", "previews", "islands")


def to_blender(x, y, z):
    return Vector((x, -z, y))


def lin(c):
    c = c / 255
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


_mats = {}


def make_material(color, material="SmoothPlastic", transparency=0.0):
    key = (tuple(color), material, round(transparency or 0.0, 2))
    if key in _mats:
        return _mats[key]
    mat = bpy.data.materials.new(f"{material}_{color[0]}_{color[1]}_{color[2]}")
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    rgba = (lin(color[0]), lin(color[1]), lin(color[2]), 1.0)
    bsdf.inputs["Base Color"].default_value = rgba
    bsdf.inputs["Roughness"].default_value = 0.65
    alpha = 1.0 - (transparency or 0.0)
    if material == "Neon":
        bsdf.inputs["Emission Color"].default_value = rgba
        bsdf.inputs["Emission Strength"].default_value = 3.0
    elif material == "Glass":
        bsdf.inputs["Roughness"].default_value = 0.08
        bsdf.inputs["Emission Color"].default_value = rgba
        bsdf.inputs["Emission Strength"].default_value = 0.25
        alpha = min(alpha, 0.85)
    elif material == "ForceField":
        bsdf.inputs["Emission Color"].default_value = rgba
        bsdf.inputs["Emission Strength"].default_value = 1.2
        alpha = 0.45
    bsdf.inputs["Alpha"].default_value = alpha
    mat.diffuse_color = rgba
    _mats[key] = mat
    return mat


# ---------------------------------------------------------------- part meshes


def part_vertices(shape, size):
    """Local vertices and faces of a Roblox part shape (Roblox local axes)."""
    sx, sy, sz = size[0] / 2, size[1] / 2, size[2] / 2
    if shape == "Block":
        verts = [(x, y, z) for x in (-sx, sx) for y in (-sy, sy) for z in (-sz, sz)]
        faces = [(0, 1, 3, 2), (4, 6, 7, 5), (0, 4, 5, 1), (2, 3, 7, 6), (0, 2, 6, 4), (1, 5, 7, 3)]
        return verts, faces
    if shape == "Wedge":
        # Roblox wedge: full height at the back (+Z), slope down towards the front (-Z).
        verts = [
            (-sx, -sy, -sz), (-sx, -sy, sz), (-sx, sy, sz),
            (sx, -sy, -sz), (sx, -sy, sz), (sx, sy, sz),
        ]
        faces = [(0, 1, 2), (3, 5, 4), (0, 3, 4, 1), (1, 4, 5, 2), (0, 2, 5, 3)]
        return verts, faces
    if shape == "Ball":
        r = min(size) / 2
        verts, faces = [], []
        rings, segs = 8, 14
        verts.append((0, r, 0))
        for i in range(1, rings):
            phi = math.pi * i / rings
            for j in range(segs):
                th = 2 * math.pi * j / segs
                verts.append((r * math.sin(phi) * math.cos(th), r * math.cos(phi), r * math.sin(phi) * math.sin(th)))
        verts.append((0, -r, 0))
        last = len(verts) - 1
        for j in range(segs):
            faces.append((0, 1 + (j + 1) % segs, 1 + j))
        for i in range(rings - 2):
            for j in range(segs):
                a = 1 + i * segs + j
                b = 1 + i * segs + (j + 1) % segs
                faces.append((a, b, b + segs, a + segs))
        base = 1 + (rings - 2) * segs
        for j in range(segs):
            faces.append((last, base + j, base + (j + 1) % segs))
        return verts, faces
    if shape == "Cylinder":
        r = min(size[1], size[2]) / 2
        segs = 28
        verts = []
        for x in (-sx, sx):
            for j in range(segs):
                th = 2 * math.pi * j / segs
                verts.append((x, r * math.cos(th), r * math.sin(th)))
        faces = [tuple(range(segs - 1, -1, -1)), tuple(range(segs, 2 * segs))]
        for j in range(segs):
            k = (j + 1) % segs
            faces.append((j, k, segs + k, segs + j))
        return verts, faces
    raise ValueError(shape)


class MeshBatch:
    """Collects parts into one mesh per look, so thousands of parts stay fast."""

    def __init__(self):
        self.groups = {}

    def add(self, spec):
        if spec.get("role") == "Wall" or (spec.get("transparency") or 0) >= 0.99:
            return
        key = (tuple(spec["color"]), spec.get("material", "SmoothPlastic"), round(spec.get("transparency") or 0, 2))
        group = self.groups.setdefault(key, ([], []))
        verts, faces = part_vertices(spec["shape"], spec["size"])
        c = spec["cframe"]
        pos = (c[0], c[1], c[2])
        rot = ((c[3], c[4], c[5]), (c[6], c[7], c[8]), (c[9], c[10], c[11]))
        offset = len(group[0])
        for lx, ly, lz in verts:
            wx = pos[0] + rot[0][0] * lx + rot[0][1] * ly + rot[0][2] * lz
            wy = pos[1] + rot[1][0] * lx + rot[1][1] * ly + rot[1][2] * lz
            wz = pos[2] + rot[2][0] * lx + rot[2][1] * ly + rot[2][2] * lz
            group[0].append(to_blender(wx, wy, wz))
        for f in faces:
            group[1].append(tuple(offset + i for i in f))

    def build(self):
        for (color, material, transparency), (verts, faces) in self.groups.items():
            mesh = bpy.data.meshes.new("Parts")
            mesh.from_pydata([tuple(v) for v in verts], [], faces)
            mesh.validate()
            # Outward normals (wedge/cylinder winding is not guaranteed).
            bm = bmesh.new()
            bm.from_mesh(mesh)
            bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
            bm.to_mesh(mesh)
            bm.free()
            obj = bpy.data.objects.new("Parts", mesh)
            obj.data.materials.append(make_material(color, material, transparency))
            bpy.context.scene.collection.objects.link(obj)


# ---------------------------------------------------------------- models


def place_model(name, width, position, yaw):
    """Builds a build_models.py model, scaled to `width` (widest horizontal side), its
    bottom center at the Roblox `position`, turned by the Roblox `yaw`."""
    before = set(bpy.context.scene.objects)
    bm_models.MODELS[name]()
    new = [o for o in bpy.context.scene.objects if o not in before and o.type == "MESH"]
    lo, hi = bm_models.scene_bounds(new)
    widest = max(hi.x - lo.x, hi.y - lo.y)
    k = width / widest
    pivot = Vector(((lo.x + hi.x) / 2, (lo.y + hi.y) / 2, lo.z))
    target = to_blender(*position)
    transform = Matrix.Translation(target) @ Matrix.Rotation(yaw, 4, "Z") @ Matrix.Scale(k, 4) @ Matrix.Translation(-pivot)
    for o in new:
        o.matrix_world = transform @ o.matrix_world
    return new


def egg(batch, top, with_egg):
    """Egg stand (and the placeholder egg) as EggService builds them."""
    x, y, z = top
    batch.add({"shape": "Cylinder", "size": [1.5, 10, 10], "cframe": [x, y + 0.75, z, 0, -1, 0, 1, 0, 0, 0, 0, 1],
               "color": [240, 200, 120], "material": "SmoothPlastic"})
    if not with_egg:
        return
    bpy.ops.mesh.primitive_uv_sphere_add(segments=24, ring_count=14, radius=2.75, location=to_blender(x, y + 1.5 + 3.6, z))
    body = bpy.context.active_object
    body.scale = (1, 1, 1.3)
    body.data.materials.append(make_material([255, 245, 220]))
    for dx, dy, dz in ((1.6, 1, 2), (-2.2, -0.6, 1.2), (0.4, 2.4, -2.2)):
        bpy.ops.mesh.primitive_uv_sphere_add(segments=12, ring_count=8, radius=0.7,
                                             location=to_blender(x + dx * 0.95, y + 1.5 + 3.6 + dy * 0.95, z + dz * 0.95))
        bpy.context.active_object.data.materials.append(make_material([245, 140, 50]))


def avatar(position, yaw):
    """Blocky player figure (about 5 studs) for scale."""
    batch = MeshBatch()
    x, y, z = position
    c, s = math.cos(yaw), math.sin(yaw)

    def box(size, offset, color):
        ox, oy, oz = offset
        wx, wz = x + c * ox + s * oz, z - s * ox + c * oz
        batch.add({"shape": "Block", "size": size, "cframe": [wx, y + oy, wz, c, 0, s, 0, 1, 0, -s, 0, c], "color": color})

    box([2, 2, 1], [0, 3, 0], [240, 130, 60])
    box([1.2, 1.2, 1.2], [0, 4.6, 0], [255, 220, 170])
    box([0.9, 2, 0.9], [-0.5, 1, 0], [60, 90, 160])
    box([0.9, 2, 0.9], [0.5, 1, 0], [60, 90, 160])
    box([0.8, 1.9, 0.8], [-1.45, 3, 0], [255, 220, 170])
    box([0.8, 1.9, 0.8], [1.45, 3, 0], [255, 220, 170])
    batch.build()


def build_scene(data, avatars):
    bm_models.reset_scene()
    _mats.clear()
    batch = MeshBatch()
    cfg = data["config"]
    gy = cfg["groundY"]
    for island in data["islands"]:
        for spec in island["parts"]:
            batch.add(spec)
        for model in island["models"]:
            place_model(model["model"], model["width"], model["position"], model["yaw"])
        st = island["stations"]
        if island["kind"] == "spawn":
            sp = st["Spawn"]["position"]
            batch.add({"shape": "Block", "size": [12, 1, 12], "cframe": [sp[0], gy + 0.5, sp[2], 1, 0, 0, 0, 1, 0, 0, 0, 1],
                       "color": [255, 200, 80]})
            p = st["Portal"]
            place_model("PortalArch", 16, p["position"], p["yaw"])
            continue
        # World island stations at their in-game sizes.
        place_model("PizzaOven", 12, st["Oven"]["position"], st["Oven"]["yaw"])
        o = st["Oven"]
        fx, fz = -math.sin(o["yaw"]), -math.cos(o["yaw"])
        zx, zz = o["position"][0] + fx * 9.5, o["position"][2] + fz * 9.5
        batch.add({"shape": "Block", "size": [14, 6, 10],
                   "cframe": [zx, gy + 3, zz, math.cos(o["yaw"]), 0, math.sin(o["yaw"]), 0, 1, 0, -math.sin(o["yaw"]), 0, math.cos(o["yaw"])],
                   "color": [255, 150, 40], "material": "ForceField", "transparency": 0.3})
        place_model("PizzaStand", 13, st["Shop"]["position"], st["Shop"]["yaw"])
        place_model("PortalArch", 16, st["Portal"]["position"], st["Portal"]["yaw"])
        place_model("Telephone", 2.2, st["Phone"]["position"], st["Phone"]["yaw"])
        # The van's own default front (cab) is -Z with the hand-over side at -X.
        place_model("DeliveryVan", 13.2, st["Van"]["position"], st["Van"]["yaw"] - math.pi / 2)
        egg(batch, st["Egg1"]["position"], True)
        egg(batch, st["Egg2"]["position"], False)
    for bridge in data["bridges"]:
        for spec in bridge["parts"]:
            batch.add(spec)
    for gate in data["gates"]:
        for spec in gate["parts"]:
            batch.add(spec)
        batch.add(gate["barrier"])
    batch.build()
    for island in data["islands"]:
        if island["kind"] == "spawn" and "spawn" in avatars:
            sp = island["stations"]["Spawn"]["position"]
            avatar((sp[0], gy + 1, sp[2] - 8), 0)
        elif island.get("worldIndex") == 1:
            if "oven" in avatars:
                o = island["stations"]["Oven"]
                avatar((o["position"][0] - 11, gy, o["position"][2]), -math.pi / 2)
            if "path" in avatars:
                avatar((0, gy, island["center"][2] + 96), 0)


def setup(resolution):
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = 40
    scene.cycles.use_denoising = True
    scene.render.resolution_x, scene.render.resolution_y = resolution
    scene.view_settings.view_transform = "Standard"
    world = bpy.data.worlds.new("Sky")
    scene.world = world
    world.use_nodes = True
    nodes = world.node_tree.nodes
    links = world.node_tree.links
    bg = nodes["Background"]
    # Sky gradient: light at the horizon, deeper blue above (like Roblox's default sky).
    coord = nodes.new("ShaderNodeTexCoord")
    sep = nodes.new("ShaderNodeSeparateXYZ")
    ramp = nodes.new("ShaderNodeValToRGB")
    links.new(coord.outputs["Generated"], sep.inputs[0])
    links.new(sep.outputs["Z"], ramp.inputs["Fac"])
    ramp.color_ramp.elements[0].position = 0.45
    ramp.color_ramp.elements[0].color = (lin(205), lin(232), lin(255), 1)
    ramp.color_ramp.elements[1].position = 0.75
    ramp.color_ramp.elements[1].color = (lin(110), lin(175), lin(245), 1)
    links.new(ramp.outputs["Color"], bg.inputs["Color"])
    bg.inputs["Strength"].default_value = 1.0
    bpy.ops.object.light_add(type="SUN", rotation=(math.radians(42), math.radians(8), math.radians(-30)))
    sun = bpy.context.active_object
    # One shared day look for all worlds (WorldLooks, #45).
    sun.data.energy = 3.6
    sun.data.angle = math.radians(6)


def camera(name, eye, target, lens):
    bpy.ops.object.camera_add(location=to_blender(*eye))
    cam = bpy.context.active_object
    cam.name = name
    cam.data.lens = lens
    cam.data.clip_end = 5000
    look = to_blender(*target) - cam.location
    cam.rotation_euler = look.to_track_quat("-Z", "Y").to_euler()
    bpy.context.scene.camera = cam


# View name -> (eye, target, lens, resolution), Roblox coordinates. Spawn island at
# z = +202, world 1 at the origin, world 2 at z = -240.
VIEWS = {
    "Islands_Overview": ((230, 170, 330), (0, -20, 60), 30, (1600, 900)),
    "World1_Overview": ((150, 150, 175), (0, -6, -5), 32, (1600, 900)),
    "Spawn_Overview": ((95, 75, 280), (0, -4, 196), 32, (1600, 900)),
    "Spawn_Player": ((0, 9, 242), (0, 2, 168), 26, (1600, 900)),
    "World1_Player": ((0, 12, 122), (0, 2, 40), 26, (1600, 900)),
    "World1_Stations": ((-6, 7, 70), (24, 3, 86), 22, (1600, 900)),
    "Islands_Side": ((300, 10, 140), (0, -14, 110), 30, (1600, 900)),
    # Worlds 2-4 (#31): world 2 at z = -240, world 3 at -480, world 4 at -720.
    "Islands_Chain": ((430, 300, 60), (0, -30, -380), 30, (1600, 900)),
    "World2_Overview": ((150, 150, -65), (0, -6, -245), 32, (1600, 900)),
    "World3_Overview": ((150, 150, -305), (0, -6, -485), 32, (1600, 900)),
    "World4_Overview": ((150, 150, -545), (0, -6, -725), 32, (1600, 900)),
    "World2_Landmark": ((10, 22, -270), (-40, 8, -326), 30, (1600, 900)),
    "World3_Landmark": ((10, 22, -510), (-40, 10, -566), 30, (1600, 900)),
    "World4_Landmark": ((10, 22, -750), (-40, 10, -806), 30, (1600, 900)),
    "Bridge_Beach": ((40, 14, -330), (0, -2, -360), 28, (1600, 900)),
    "Bridge_Ice": ((40, 14, -570), (0, -2, -600), 28, (1600, 900)),
    # Worlds 5-7 (#32): world 5 at z = -960, world 6 at -1200, world 7 at -1440.
    "World5_Overview": ((150, 150, -785), (0, -6, -965), 32, (1600, 900)),
    "World6_Overview": ((150, 150, -1025), (0, -6, -1205), 32, (1600, 900)),
    "World7_Overview": ((150, 150, -1265), (0, -6, -1445), 32, (1600, 900)),
    "World5_Landmark": ((10, 22, -990), (-40, 10, -1046), 30, (1600, 900)),
    "World6_Landmark": ((10, 22, -1230), (-40, 10, -1286), 30, (1600, 900)),
    "World7_Landmark": ((10, 22, -1470), (-40, 12, -1526), 30, (1600, 900)),
    "Bridge_Basalt": ((40, 14, -810), (0, -2, -840), 28, (1600, 900)),
    "Bridge_Candy": ((40, 14, -1050), (0, -2, -1080), 28, (1600, 900)),
    "Bridge_Light": ((40, 14, -1290), (0, -2, -1320), 28, (1600, 900)),
    # World 8 Atlantis (#82) at z = -1680: overview, temple and the deco from the main path.
    "World8_Overview": ((150, 150, -1505), (0, -6, -1685), 32, (1600, 900)),
    "World8_Landmark": ((10, 22, -1710), (-40, 12, -1766), 30, (1600, 900)),
    "World8_Player": ((0, 14, -1560), (0, 2, -1660), 30, (1600, 900)),
    # World 9 Jungle Temple (#83) at z = -1920: overview, stepped temple (with the chest
    # spot behind it) and the deco from the main path.
    "World9_Overview": ((150, 150, -1745), (0, -6, -1925), 32, (1600, 900)),
    "World9_Landmark": ((10, 22, -1950), (-40, 12, -2006), 30, (1600, 900)),
    "World9_Player": ((0, 14, -1800), (0, 2, -1900), 30, (1600, 900)),
    # The whole chain, spawn island (z = +202) to world 7 (z = -1440).
    "Islands_FullChain": ((980, 640, 420), (0, -20, -600), 27, (1920, 820)),
}


# Player figures for scale in the player-perspective views.
AVATARS = {"Spawn_Player": ("spawn",), "World1_Player": ("path",), "World1_Stations": ("oven",)}


def render(data, view):
    eye, target, lens, resolution = VIEWS[view]
    build_scene(data, AVATARS.get(view, ()))
    setup(resolution)
    camera(view, eye, target, lens)
    os.makedirs(OUT_DIR, exist_ok=True)
    # JPEG keeps the big previews small in the repo.
    bpy.context.scene.render.image_settings.file_format = "JPEG"
    bpy.context.scene.render.image_settings.quality = 90
    bpy.context.scene.render.filepath = os.path.join(OUT_DIR, f"{view}.jpg")
    bpy.ops.render.render(write_still=True)
    print(f"rendered {view}")


if __name__ == "__main__":
    path = sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, "build", "islands.json")
    with open(path) as f:
        plan = json.load(f)
    views = [a for a in sys.argv[2:] if a in VIEWS] or list(VIEWS)
    for v in views:
        render(plan, v)
