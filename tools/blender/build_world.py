"""Builds the model pack of one new world of the MEGA UPDATE (#82 on) and its preview.

Run headless (bpy from pip, Python 3.13):
    python tools/blender/build_world.py Atlantis [--no-render]

Pattern for every new world (#82-#89): one FBX per world with all its toppings, pets
(the Secret pet included) and its egg, so Studio needs one import per world instead of
eleven. Steps for a new world:
  1. GameConfig: toppings, pets, egg (with `look`), world entry (`toppingSpawns`, `eggs`,
     `secretPet`). The ids are read from there.
  2. tools/blender/worlds/<worldid lower>.py with `TOPPINGS = { id: builder }` (pieces via
     build_toppings.part, like build_toppings.py), `PETS = { id: builder(P) }` (building
     blocks of build_pets.py / build_secret_pets.py) and the picture colours SKY, GROUND.
     The egg needs no code: build_eggs.py builds it from its `look`.
  3. Run this script; it writes assets/models/worlds/<WorldId>.fbx and
     assets/previews/worlds/<WorldId>.png. tests/WorldModels.spec.luau checks both.

In the FBX every asset is an empty named after its id (Studio: a Model of that name)
holding mesh parts named after their colour ("Top_2F7A3A", "Pet_FFC857", "Egg_1E8FB8",
optional "_Neon" / "_Glass" / "_Metal") - the same part names as the single-model files,
so ModelLibrary recolours them. In Studio the imported world model goes into
ReplicatedStorage.GameAssets.Models.Worlds (docs/pc-todo.md).
"""

import importlib
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import bpy  # noqa: E402,I001
from mathutils import Vector  # noqa: E402

import build_eggs as be  # noqa: E402
import build_pets as bp  # noqa: E402
import build_toppings as bt  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
CONFIG = os.path.join(ROOT, "src", "shared", "GameConfig.luau")
MODEL_DIR = os.path.join(ROOT, "assets", "models", "worlds")
PREVIEW_DIR = os.path.join(ROOT, "assets", "previews", "worlds")

PET_SPACING = 1.9
EGG_SCALE = 0.6


def read_world(world_id):
    """Topping, egg and pet ids of a world, read from GameConfig.luau."""
    text = open(CONFIG, encoding="utf-8").read()
    match = re.search(r'\n\t\t\{\n\t\t\tid = "' + world_id + r'",(.*?)\n\t\t\},', text, re.S)
    if not match:
        raise SystemExit(f"world {world_id} not found in GameConfig.luau")
    body = match.group(1)
    toppings = re.findall(r'topping = "(\w+)"', body)
    eggs = re.findall(r'"(\w+)"', re.search(r"eggs = \{([^}]*)\}", body).group(1))
    pets = []
    for egg in eggs:
        egg_body = re.search(r"\n\t\t" + egg + r" = \{(.*?)\n\t\t\},", text, re.S).group(1)
        pets += re.findall(r'pet = "(\w+)"', egg_body)
    secret = re.search(r'secretPet = "(\w+)"', body)
    if secret:
        pets.append(secret.group(1))
    return toppings, pets, eggs


def new_meshes(before):
    return [o for o in set(bpy.context.scene.objects) - before if o.type == "MESH"]


def group(name, objs, offset):
    """Parents the asset's parts to an empty named after the asset (one Model in Studio)."""
    empty = bpy.data.objects.new(name, None)
    bpy.context.collection.objects.link(empty)
    empty.location = Vector(offset)
    bpy.context.view_layer.update()
    inverse = empty.matrix_world.inverted()
    for o in objs:
        o.parent = empty
        o.matrix_parent_inverse = inverse
    return empty


def build_pack(world_id):
    module = importlib.import_module(f"worlds.{world_id.lower()}")
    toppings, pets, eggs = read_world(world_id)
    missing = [i for i in toppings if i not in module.TOPPINGS] + [i for i in pets if i not in module.PETS]
    if missing:
        raise SystemExit(f"no builder for {', '.join(missing)} in worlds/{world_id.lower()}.py")
    bt.MODELS.update(module.TOPPINGS)
    bp.PETS.update(module.PETS)
    looks = be.read_looks()

    bp.reset_scene()
    bt._groups.clear()
    bt._materials.clear()
    be._materials.clear()

    # Pets and egg in two rows (camera looks from +Y, so the first pet is on the left at
    # +X; the rarer half and the egg stand in the back row), the toppings in front.
    spots = []
    items = pets + eggs
    front = (len(items) + 1) // 2
    for i, name in enumerate(items):
        row, slot, size = (0, i, front) if i < front else (1, i - front, len(items) - front)
        x = ((size - 1) / 2 - slot) * PET_SPACING + row * PET_SPACING * 0.5
        spots.append((name, (x, -row * 1.8, 0)))
    for name, offset in spots:
        if name in eggs:
            before = set(bpy.context.scene.objects)
            be.build_egg(looks[name])
            objs = new_meshes(before)
            for o in objs:
                o.scale = (EGG_SCALE, EGG_SCALE, EGG_SCALE)
                o.location = Vector(offset) + o.location * EGG_SCALE
        else:
            objs = bp.build(name, offset=offset)
        group(name, objs, offset)
    for k, topping in enumerate(toppings):
        x = ((len(toppings) - 1) / 2 - k) * 1.6
        group(topping, bt.build(topping, 1.3, (x, 2.4, 0)), (x, 2.4, 0))

    os.makedirs(MODEL_DIR, exist_ok=True)
    for o in bpy.context.scene.objects:
        o.select_set(o.type in ("MESH", "EMPTY"))
    bpy.ops.export_scene.fbx(
        filepath=os.path.join(MODEL_DIR, f"{world_id}.fbx"),
        use_selection=True,
        object_types={"MESH", "EMPTY"},
        mesh_smooth_type="FACE",
        apply_scale_options="FBX_SCALE_ALL",
        axis_forward="-Z",
        axis_up="Y",
        bake_space_transform=True,
    )
    print(f"built {world_id}: {len(pets)} pets, {len(eggs)} egg(s), {len(toppings)} toppings")
    return module


def preview(world_id, module):
    """Everything of the world side by side: pets, egg, toppings on the ground and on a pizza."""
    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    before = set(bpy.context.scene.objects)
    bt.base.build_pizza()
    for o in new_meshes(before):
        o.scale = (0.7, 0.7, 0.7)
        o.location = Vector((0, 3.9, 0)) + o.location * 0.7
    toppings = [name for name in module.TOPPINGS]
    for k in range(5):
        a = 6.283 * k / 5
        name = toppings[k % len(toppings)]
        objs = bt.build(name, 0.42, (0.4 * __import__("math").cos(a), 3.9 + 0.4 * __import__("math").sin(a), 0.15), spin=a)
        bt.rename_unique(objs, f"pizza{k}")
    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    os.makedirs(PREVIEW_DIR, exist_ok=True)
    bp.render(
        meshes,
        os.path.join(PREVIEW_DIR, f"{world_id}.png"),
        (1600, 900),
        module.SKY,
        ground=module.GROUND,
        distance=1.7,
        yaw=0,
        lift=0.35,
        samples=48,
    )
    print(f"preview {world_id}")


if __name__ == "__main__":
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    if not args:
        raise SystemExit("usage: python tools/blender/build_world.py <WorldId> [--no-render]")
    for world in args:
        pack = build_pack(world)
        if "--no-render" not in sys.argv:
            preview(world, pack)
