"""Builds the egg models (one per egg in GameConfig) and the egg stand, with preview renders.

Run headless (bpy from pip, Python 3.13):
    python tools/blender/build_eggs.py [EggId ... | EggStand | Overview | FancyDemo]

Writes assets/models/eggs/<EggId>.fbx, assets/models/eggs/EggStand.fbx and
assets/previews/eggs/<Name>.png (plus Overview.png with all eggs on their stands, first
eggs in front and the fancy second eggs per world (#39) behind them, and FancyDemo.png,
a normal and a fancy version of two eggs side by side).

The egg looks (base colour, accent colour, pattern, glow, fancy) are read from
src/shared/GameConfig.luau (`look = { ... }` of every egg), so the config stays the only
place for them; the placeholder eggs in Studio use the same values.

Egg parts carry their colour in the name like pets: "Egg_FFF3DC", "Egg_FF7A1A_Neon",
"Egg_FFC83A_Metal". Stand parts use palette names (StandBody, StandTrim, StandGold,
EggSign, Stone) – keep them in sync with PALETTE in src/shared/ModelLibrary.luau.
StandTrim is tinted in the egg's accent colour by the game.

Everything faces Blender +Y (the sign of the stand), like the oven and the pets.
Patterns are built by pattern functions on the egg surface, so a new egg is only a new
config entry; `fancy` adds a gold band, gold beads and (only with `glow`) glowing accents on top of any pattern.
"""

import math
import os
import re
import sys

import bpy  # noqa: I001  (bpy must be imported before bmesh)
import bmesh
from mathutils import Vector

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
CONFIG = os.path.join(ROOT, "src", "shared", "GameConfig.luau")
MODEL_DIR = os.path.join(ROOT, "assets", "models", "eggs")
PREVIEW_DIR = os.path.join(ROOT, "assets", "previews", "eggs")

# Egg size in Blender units: 2 wide, 2.6 tall, bottom at z = 0.
EGG_RADIUS = 1.0
EGG_STRETCH = 1.3
# Top narrower than the bottom (factor per unit of height above the middle).
EGG_TAPER = 0.12
GOLD = "FFC83A"

# Stand palette (same values as ModelLibrary.PALETTE).
STAND_COLORS = {
    "Stone": (186, 176, 166),
    "StandBody": (255, 244, 222),
    "StandTrim": (240, 130, 60),
    "StandGold": (255, 200, 40),
    "EggSign": (255, 248, 230),
}

# ---------------------------------------------------------------- config


def read_looks():
    """Egg id -> look dict, parsed from the `look = { ... }` lines in GameConfig.luau."""
    text = open(CONFIG, encoding="utf-8").read()
    looks = {}
    pattern = r"\n\t\t(\w+Egg) = \{\n\t\t\tdisplayName = \"[^\"]+\",\n(?:\t\t\tdisplayNameEn = \"[^\"]+\",\n)?\t\t\tlook = \{([^}]*)\}"
    for egg_id, body in re.findall(pattern, text):
        look = {}
        for key, value in re.findall(r"(\w+) = (\"[^\"]*\"|true|false)", body):
            look[key] = value.strip('"') if value.startswith('"') else value == "true"
        looks[egg_id] = look
    if not looks:
        raise SystemExit("no egg looks found in GameConfig.luau")
    return looks


# ---------------------------------------------------------------- materials


def lin(c):
    c = c / 255
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def rgba(rgb):
    return (lin(rgb[0]), lin(rgb[1]), lin(rgb[2]), 1.0)


def hex_rgb(h):
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16))


_materials = {}


def material(key, rgb, kind=None):
    if key in _materials:
        return _materials[key]
    mat = bpy.data.materials.new(key)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = rgba(rgb)
    bsdf.inputs["Roughness"].default_value = 0.5
    if kind == "Neon":
        bsdf.inputs["Emission Color"].default_value = rgba(rgb)
        bsdf.inputs["Emission Strength"].default_value = 3.0
    elif kind == "Metal":
        bsdf.inputs["Metallic"].default_value = 0.85
        bsdf.inputs["Roughness"].default_value = 0.3
    mat.diffuse_color = rgba(rgb)
    _materials[key] = mat
    return mat


def egg_part_name(h, kind=None):
    return f"Egg_{h}" + (f"_{kind}" if kind else "")


def finish(obj, name, mat, smooth=False):
    obj.name = name
    obj.data.name = name
    for o in bpy.context.selected_objects:
        o.select_set(False)
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    for poly in obj.data.polygons:
        poly.use_smooth = smooth
    obj.data.materials.clear()
    obj.data.materials.append(mat)
    return obj


def join(objs):
    for o in bpy.context.selected_objects:
        o.select_set(False)
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    if len(objs) > 1:
        bpy.ops.object.join()
    return bpy.context.view_layer.objects.active


def egg_mat(h, kind=None):
    return material(egg_part_name(h, kind), hex_rgb(h), kind)


def stand_mat(name):
    return material(name, STAND_COLORS[name])


def reset_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    _materials.clear()


# ---------------------------------------------------------------- egg surface


def egg_point(theta, u, lift=0.0):
    """Point on the egg surface: theta = angle around the up axis (0 = +Y, the front),
    u = -1 (bottom) .. 1 (top). `lift` pushes it outward along the normal."""
    rho = math.sqrt(max(0.0, 1 - u * u)) * EGG_RADIUS
    f = 1 - EGG_TAPER * u
    p = Vector((rho * math.sin(theta) * f, rho * math.cos(theta) * f, EGG_STRETCH * (u + 1)))
    if lift:
        p += egg_normal(theta, u) * lift
    return p


def egg_normal(theta, u):
    e = 1e-3
    u = max(-0.999, min(0.999, u))
    du = egg_point(theta, u + e) - egg_point(theta, u - e)
    dt = egg_point(theta + e, u) - egg_point(theta - e, u)
    n = dt.cross(du)
    n.normalize()
    return n


def shape_vertex(co):
    """Turns a unit-sphere vertex into the egg shape (same mapping as egg_point)."""
    u = co.z
    f = 1 - EGG_TAPER * u
    return Vector((co.x * EGG_RADIUS * f, co.y * EGG_RADIUS * f, EGG_STRETCH * (u + 1)))


def egg_mesh(name, segments=28, rings=18):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments, ring_count=rings, radius=1.0)
    obj = bpy.context.active_object
    for v in obj.data.vertices:
        v.co = shape_vertex(v.co)
    obj.name = name
    return obj


def shell_region(keep, thickness=0.035, cuts=3):
    """Pattern patch lying on the egg shell: the egg surface (same facets as the shell,
    subdivided) keeping only the faces whose centre (theta, u) passes `keep`, thickened
    outward. Returns None if nothing is kept."""
    obj = egg_mesh("Region")
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bmesh.ops.subdivide_edges(bm, edges=bm.edges[:], cuts=cuts, use_grid_fill=True)
    drop = []
    for face in bm.faces:
        c = face.calc_center_median()
        u = max(-1.0, min(1.0, c.z / EGG_STRETCH - 1))
        theta = math.atan2(c.x, c.y)
        if not keep(theta, u):
            drop.append(face)
    bmesh.ops.delete(bm, geom=drop, context="FACES")
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
    empty = len(bm.faces) == 0
    bm.to_mesh(obj.data)
    bm.free()
    if empty:
        bpy.data.objects.remove(obj)
        return None
    mod = obj.modifiers.new("Thick", "SOLIDIFY")
    mod.thickness = thickness
    mod.offset = 1.0
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.modifier_apply(modifier=mod.name)
    return obj


def on_surface(obj, theta, u, lift=0.0, spin=0.0):
    """Moves a small object (built around the origin, flat side down its local Z) onto the
    egg surface at (theta, u), its local Z along the surface normal."""
    n = egg_normal(theta, u)
    obj.rotation_mode = "QUATERNION"
    q = n.to_track_quat("Z", "Y")
    from mathutils import Quaternion

    obj.rotation_quaternion = q @ Quaternion((0, 0, 1), spin)
    obj.location = egg_point(theta, u, lift)
    return obj


def angle_diff(a, b):
    return (a - b + math.pi) % (2 * math.pi) - math.pi


# ---------------------------------------------------------------- patterns
# Each returns a list of accent objects (not yet finished).


def pattern_spots(look):
    objs = []
    spots = [(0.0, 0.15, 0.36), (1.4, -0.35, 0.3), (2.6, 0.3, 0.34), (-1.3, 0.4, 0.28), (-2.5, -0.25, 0.33),
             (0.7, 0.7, 0.22), (-0.6, -0.6, 0.26), (3.1, -0.7, 0.22), (2.0, 0.85, 0.16), (-2.1, 0.8, 0.18)]
    for i, (theta, u, r) in enumerate(spots):
        bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2, radius=r)
        o = bpy.context.active_object
        o.scale = (1, 1, 0.28)
        bpy.ops.object.transform_apply(scale=True)
        objs.append(on_surface(o, theta, u, lift=0.0, spin=i))
    return objs


def pattern_stripes(look):
    bands = [(-0.42, -0.26), (0.02, 0.2), (0.46, 0.6)]
    region = shell_region(lambda t, u: any(lo <= u <= hi for lo, hi in bands))
    return [region] if region else []


def pattern_waves(look):
    def keep(t, u):
        for base in (-0.35, 0.3):
            if abs(u - (base + 0.12 * math.sin(4 * t))) < 0.09:
                return True
        return False

    return [shell_region(keep, cuts=4)]


def pattern_diamonds(look):
    objs = []
    for row, (u, count, size) in enumerate([(-0.2, 7, 0.24), (0.35, 6, 0.2), (0.78, 4, 0.13)]):
        for i in range(count):
            theta = (i + 0.5 * row) / count * 2 * math.pi
            bpy.ops.mesh.primitive_cone_add(vertices=4, radius1=size, radius2=0, depth=size * 0.7)
            o = bpy.context.active_object
            o.scale = (0.75, 1.25, 1)
            bpy.ops.object.transform_apply(scale=True)
            # Cone points up its local Z: sits as a little gem on the shell.
            objs.append(on_surface(o, theta, u, lift=size * 0.1, spin=0))
    return objs


def pattern_cracks(look):
    def zigzag(t, base, amp, teeth):
        # Triangle wave around the egg.
        x = (t / (2 * math.pi) * teeth) % 1
        return base + amp * (4 * abs(x - 0.5) - 1)

    def keep(t, u):
        if abs(u - zigzag(t, 0.1, 0.14, 7)) < 0.06:
            return True
        if abs(u - zigzag(t + 0.4, -0.45, 0.1, 9)) < 0.05:
            return True
        # Short cracks running up from the top line.
        for c in (0.3, 2.2, 4.1):
            if abs(angle_diff(t, c + 0.25 * u)) < 0.07 and 0.15 < u < 0.7:
                return True
        return False

    return [shell_region(keep, cuts=5, thickness=0.04)]


def pattern_swirl(look):
    def keep(t, u):
        return ((t / (2 * math.pi)) * 3 + u * 1.1) % 1 < 0.42 and -0.92 < u < 0.92

    return [shell_region(keep, cuts=4)]


def star_mesh(r_out, r_in, depth):
    verts = []
    for i in range(10):
        a = math.pi / 2 + i * math.pi / 5
        r = r_out if i % 2 == 0 else r_in
        verts.append((r * math.cos(a), r * math.sin(a)))
    mesh = bpy.data.meshes.new("Star")
    bm = bmesh.new()
    bottom = [bm.verts.new((x, y, 0)) for x, y in verts]
    top = [bm.verts.new((x, y, depth)) for x, y in verts]
    cb = bm.verts.new((0, 0, 0))
    ct = bm.verts.new((0, 0, depth * 1.6))
    for i in range(10):
        j = (i + 1) % 10
        bm.faces.new((bottom[i], bottom[j], top[j], top[i]))
        bm.faces.new((cb, bottom[j], bottom[i]))
        bm.faces.new((ct, top[i], top[j]))
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new("Star", mesh)
    bpy.context.collection.objects.link(obj)
    return obj


def pattern_stars(look):
    objs = []
    stars = [(0.0, 0.1, 0.36), (1.6, -0.3, 0.28), (3.0, 0.25, 0.32), (-1.5, 0.45, 0.26), (-2.6, -0.4, 0.3),
             (0.9, 0.7, 0.18), (-0.8, -0.55, 0.2), (2.2, 0.8, 0.14), (-2.2, 0.85, 0.13)]
    for i, (theta, u, r) in enumerate(stars):
        o = star_mesh(r, r * 0.45, 0.05)
        objs.append(on_surface(o, theta, u, lift=-0.02, spin=0.4 * i))
    return objs


def pattern_bubbles(look):
    """Atlantis (#82): rising bubbles - rings of different sizes with a small dot inside."""
    objs = []
    bubbles = [(0.0, -0.3, 0.3), (1.2, 0.05, 0.24), (2.5, -0.45, 0.28), (-1.3, 0.2, 0.26), (-2.6, -0.1, 0.22),
               (0.6, 0.45, 0.18), (-0.5, 0.6, 0.15), (1.9, 0.62, 0.13), (3.0, 0.3, 0.17), (-2.0, 0.55, 0.12),
               (0.3, -0.75, 0.2), (-1.0, -0.65, 0.17)]
    for i, (theta, u, r) in enumerate(bubbles):
        bpy.ops.mesh.primitive_torus_add(major_radius=r, minor_radius=r * 0.18, major_segments=16, minor_segments=5)
        o = bpy.context.active_object
        objs.append(on_surface(o, theta, u, lift=0.0, spin=i))
        bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=r * 0.22)
        dot = bpy.context.active_object
        dot.scale = (1, 1, 0.4)
        bpy.ops.object.transform_apply(scale=True)
        objs.append(on_surface(dot, theta + r * 0.25, u + r * 0.2, lift=0.0, spin=0))
    return objs


def pattern_vines(look):
    """Jungle temple (#83): two lianas winding up around the egg with small leaves on them."""
    def keep(t, u):
        for phase in (0.0, math.pi):
            # The vine climbs: one full turn from the bottom to the top.
            if abs(angle_diff(t, phase + (u + 1) * math.pi)) < 0.16:
                return True
        return False

    objs = [shell_region(keep, cuts=4)]
    for phase in (0.0, math.pi):
        for i, u in enumerate((-0.6, -0.3, 0.0, 0.3, 0.6)):
            theta = phase + (u + 1) * math.pi + (0.28 if i % 2 else -0.28)
            bpy.ops.mesh.primitive_uv_sphere_add(segments=8, ring_count=5, radius=0.2)
            o = bpy.context.active_object
            o.scale = (1, 0.45, 0.18)
            bpy.ops.object.transform_apply(scale=True)
            objs.append(on_surface(o, theta, u, lift=0.0, spin=0.8 if i % 2 else -0.8))
    return [o for o in objs if o]


PATTERNS = {
    "Spots": pattern_spots,
    "Stripes": pattern_stripes,
    "Waves": pattern_waves,
    "Diamonds": pattern_diamonds,
    "Cracks": pattern_cracks,
    "Swirl": pattern_swirl,
    "Stars": pattern_stars,
    "Bubbles": pattern_bubbles,
    "Vines": pattern_vines,
}


def fancy_parts():
    """Showier variant: gold band around the middle and a ring of gold beads on top."""
    band = shell_region(lambda t, u: -0.1 <= u <= 0.08, thickness=0.06)
    spikes = []
    for i in range(6):
        theta = i / 6 * 2 * math.pi
        bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=0.11)
        o = bpy.context.active_object
        spikes.append(on_surface(o, theta, 0.78, lift=0.04))
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2, radius=0.12, location=egg_point(0, 1, 0.08))
    spikes.append(bpy.context.active_object)
    return [band] + spikes


def build_egg(look, fancy=None):
    """One egg: shell in the base colour, pattern in the accent colour, optional fancy extras."""
    fancy = look.get("fancy", False) if fancy is None else fancy
    shell = egg_mesh("Shell")
    finish(shell, egg_part_name(look["color"]), egg_mat(look["color"]))
    kind = "Neon" if look.get("glow") else None
    accent = [o for o in PATTERNS[look["pattern"]](look) if o is not None]
    if accent:
        finish(join(accent), egg_part_name(look["accent"], kind), egg_mat(look["accent"], kind))
    if fancy:
        finish(join(fancy_parts()), egg_part_name(GOLD, "Metal"), egg_mat(GOLD, "Metal"))


# ---------------------------------------------------------------- stand
# Footprint 2 x 2 units (the game scales it to the stand width), top plate at 0.44.
# The sign board sits on the front of the drum; the game puts the text over it
# (EggService: SIGN_* constants). Change both together.


def cylinder(radius, depth, verts, z0):
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=radius, depth=depth, location=(0, 0, z0 + depth / 2))
    return bpy.context.active_object


def build_stand():
    finish(join([cylinder(1.0, 0.12, 20, 0.0)]), "Stone", stand_mat("Stone"))
    finish(join([cylinder(0.84, 0.28, 20, 0.12)]), "StandBody", stand_mat("StandBody"))
    trim = [cylinder(0.88, 0.05, 20, 0.12), cylinder(0.9, 0.06, 20, 0.38)]
    # Sign frame on the front.
    bpy.ops.mesh.primitive_cube_add(size=1, location=(0, 0.84, 0.26))
    frame = bpy.context.active_object
    frame.scale = (0.86, 0.06, 0.22)
    trim.append(frame)
    finish(join(trim), "StandTrim", stand_mat("StandTrim"))
    bpy.ops.mesh.primitive_cube_add(size=1, location=(0, 0.87, 0.26))
    board = bpy.context.active_object
    board.scale = (0.78, 0.02, 0.17)
    finish(board, "EggSign", stand_mat("EggSign"))
    bulbs = []
    for i in range(10):
        a = i / 10 * 2 * math.pi + math.pi / 10
        bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=0.06, location=(0.78 * math.sin(a), 0.78 * math.cos(a), 0.46))
        bulbs.append(bpy.context.active_object)
    finish(join(bulbs), "StandGold", stand_mat("StandGold"))


# ---------------------------------------------------------------- export and render


def scene_bounds(objs):
    lo = Vector((1e9, 1e9, 1e9))
    hi = Vector((-1e9, -1e9, -1e9))
    for o in objs:
        for corner in o.bound_box:
            w = o.matrix_world @ Vector(corner)
            lo = Vector(map(min, lo, w))
            hi = Vector(map(max, hi, w))
    return lo, hi


def mesh_objects():
    return [o for o in bpy.context.scene.objects if o.type == "MESH"]


def render(objs, path, size=512, width=None, distance=2.4, sky=(255, 236, 200), ground_color=(150, 215, 120), yaw=-25, height=0.45):
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = 48
    scene.cycles.use_denoising = True
    scene.render.resolution_x = width or size
    scene.render.resolution_y = size
    scene.view_settings.view_transform = "Standard"

    world = bpy.data.worlds.new("World")
    scene.world = world
    world.use_nodes = True
    bg = world.node_tree.nodes["Background"]
    bg.inputs["Color"].default_value = rgba(sky)
    bg.inputs["Strength"].default_value = 0.9

    bpy.context.view_layer.update()
    lo, hi = scene_bounds(objs)
    center = (lo + hi) / 2
    radius = max((hi - lo).length / 2, 0.5)

    bpy.ops.mesh.primitive_plane_add(size=radius * 14, location=(center.x, center.y, lo.z))
    ground = bpy.context.active_object
    gmat = bpy.data.materials.new("PreviewGround")
    gmat.use_nodes = True
    gmat.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = rgba(ground_color)
    ground.data.materials.append(gmat)

    bpy.ops.object.light_add(type="SUN", rotation=(math.radians(50), math.radians(10), math.radians(-35)))
    sun = bpy.context.active_object
    sun.data.energy = 3.5
    sun.data.angle = math.radians(8)

    direction = Vector((0.0, 1.0, 0.0))  # camera looks at the +Y side (the front)
    direction.rotate(__import__("mathutils").Euler((0, 0, math.radians(yaw))))
    cam_pos = center + direction * radius * distance + Vector((0, 0, radius * distance * height))
    bpy.ops.object.camera_add(location=cam_pos)
    cam = bpy.context.active_object
    cam.data.lens = 50
    cam.rotation_euler = (center - cam_pos).to_track_quat("-Z", "Y").to_euler()
    scene.camera = cam

    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)


def export_fbx(name):
    objs = mesh_objects()
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
    print(f"built {name}: {sorted(o.name for o in objs)}")
    return objs


def export_egg(egg_id, look):
    reset_scene()
    build_egg(look)
    objs = export_fbx(egg_id)
    os.makedirs(PREVIEW_DIR, exist_ok=True)
    render(objs, os.path.join(PREVIEW_DIR, f"{egg_id}.png"))


def export_stand():
    reset_scene()
    build_stand()
    objs = export_fbx("EggStand")
    render(objs, os.path.join(PREVIEW_DIR, "EggStand.png"))


def add_at(builder, offset, scale=1.0):
    before = set(bpy.context.scene.objects)
    builder()
    for o in set(bpy.context.scene.objects) - before:
        o.scale = (scale, scale, scale)
        o.location = Vector(offset) + o.location * scale


def overview(looks):
    """All eggs on their stands, trim tinted like in the game: the first egg of every world
    in the front row (world 1 left), the fancy second eggs (#39) in the row behind."""
    reset_scene()
    # Egg is 5.5 studs wide on a 10 studs stand: scale 0.55 relative to the 2-unit stand.
    stand_top = 0.44
    rows = [
        [(egg_id, look) for egg_id, look in looks.items() if not look.get("fancy")],
        [(egg_id, look) for egg_id, look in looks.items() if look.get("fancy")],
    ]
    spots = []
    for row, entries in enumerate(rows):
        for i, entry in enumerate(entries):
            # The camera looks at the front (+Y), so world 1 (left in the picture) goes to +X.
            spots.append((entry, ((len(rows[0]) - 1) / 2 - i) * 2.4, -row * 2.6))
    for (egg_id, look), x, y in spots:
        before = set(bpy.context.scene.objects)
        build_stand()
        for o in set(bpy.context.scene.objects) - before:
            o.location = Vector((x, y, 0)) + o.location
            if o.name.startswith("StandTrim"):
                o.data.materials.clear()
                o.data.materials.append(material(f"Trim_{egg_id}", hex_rgb(look["accent"]) if look["accent"] != "FFFFFF" else hex_rgb(look["color"])))
        add_at(lambda look=look: build_egg(look), (x, y, stand_top), 0.55)
    render(mesh_objects(), os.path.join(PREVIEW_DIR, "Overview.png"), size=900, width=1920, distance=2.9, yaw=0, height=0.45)


def fancy_demo(looks):
    """Normal and fancy version of two eggs next to each other (for the second egg per world)."""
    reset_scene()
    picks = [looks["GardenEgg"], looks["SpaceEgg"]] if "GardenEgg" in looks and "SpaceEgg" in looks else list(looks.values())[:2]
    x = -3.3
    for look in picks:
        for fancy in (False, True):
            add_at(lambda look=look, fancy=fancy: build_egg(look, fancy), (x, 0, 0))
            x += 2.2
    render(mesh_objects(), os.path.join(PREVIEW_DIR, "FancyDemo.png"), size=640, width=1280, distance=3.6, yaw=0, height=0.3)


if __name__ == "__main__":
    looks = read_looks()
    args = sys.argv[1:] or list(looks) + ["EggStand", "Overview", "FancyDemo"]
    for name in args:
        if name in looks:
            export_egg(name, looks[name])
        elif name == "EggStand":
            export_stand()
        elif name == "Overview":
            overview(looks)
        elif name == "FancyDemo":
            fancy_demo(looks)
        else:
            raise SystemExit(f"unknown asset {name}")
