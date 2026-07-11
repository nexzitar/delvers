"""THE ARCHITECTURE KIT COMPILER (v1).
The garment engine pattern at room scale: a small construction
grammar - stone courses, posts and lintels, bases and capitals -
compiles a modular dungeon kit. Solid two-tone materials
(ArchPrimary/ArchSecondary/ArchTrim) dye per theme at runtime,
exactly like garments.

Pieces (1 tile = 1 unit):
  Wall0/Wall1/Wall2  - tile wall, three coursed variants
  Pillar             - freestanding column, base + capital
  Arch               - a doorway spanning a 3-tile corridor mouth
  Rubble0/Rubble1    - collapsed masonry piles

Usage: blender -b -P arch_kit.py -- <out.glb> [seed]
"""
import bpy, sys, math, random

def log(*a): print("[ARCH]", *a, flush=True)

out = sys.argv[sys.argv.index("--") + 1]
seed = int(sys.argv[sys.argv.index("--") + 2]) if \
    len(sys.argv) > sys.argv.index("--") + 2 else 7

bpy.ops.wm.read_factory_settings(use_empty=True)

def material(name, rgb, rough=0.92):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = m.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = (rgb[0], rgb[1], rgb[2], 1.0)
    bsdf.inputs["Roughness"].default_value = rough
    return m

primary = material("ArchPrimary", (0.33, 0.34, 0.31))
secondary = material("ArchSecondary", (0.24, 0.26, 0.23))
trim = material("ArchTrim", (0.4, 0.44, 0.33))

def block(name, loc, size, mat, bevel=0.045, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc)
    o = bpy.context.active_object
    o.name = name
    o.scale = size
    o.rotation_euler = rot
    o.data.materials.append(mat)
    bpy.ops.object.transform_apply(scale=True, rotation=True)
    b = o.modifiers.new("bev", "BEVEL")
    b.width = bevel
    b.segments = 2
    bpy.ops.object.modifier_apply(modifier="bev")
    return o

def join(name, parts):
    bpy.ops.object.select_all(action="DESELECT")
    for p in parts:
        p.select_set(True)
    bpy.context.view_layer.objects.active = parts[0]
    bpy.ops.object.join()
    parts[0].name = name
    return parts[0]

pieces = []

# --- Walls: coursed masonry, three variants -------------------------
for v in range(3):
    rng = random.Random(seed * 31 + v)
    parts = []
    z = 0.0
    course = 0
    while z < 1.75:
        h = rng.uniform(0.36, 0.5)
        # A course is one or two stones; joints wander per variant.
        stones = 2 if rng.random() < 0.45 else 1
        mat = primary if course % 2 == 0 else secondary
        if stones == 1:
            parts.append(block("c", (rng.uniform(-0.02, 0.02), 0, z + h / 2),
                (1.04, rng.uniform(0.88, 1.0), h), mat))
        else:
            split = rng.uniform(0.3, 0.7)
            parts.append(block("c", (-0.5 + split / 2, 0, z + h / 2),
                (split - 0.03, rng.uniform(0.86, 0.98), h), mat))
            parts.append(block("c", (0.5 - (1 - split) / 2, 0, z + h / 2),
                (1 - split - 0.03, rng.uniform(0.86, 0.98), h),
                secondary if mat == primary else primary))
        z += h - 0.02
        course += 1
    # A proud capstone crowns the wall.
    parts.append(block("cap", (0, 0, z + 0.09), (1.1, 1.06, 0.2), trim,
        bevel=0.05))
    # One jutting stone keeps it hand-laid, never flush.
    parts.append(block("jut", (rng.uniform(-0.3, 0.3), 0.5, rng.uniform(0.4, 1.2)),
        (0.28, 0.14, 0.22), secondary, bevel=0.03))
    pieces.append(join("Wall%d" % v, parts))
    log("Wall%d" % v, "courses", course)

# --- Pillar: base, faceted shaft, capital ---------------------------
parts = []
parts.append(block("base", (0, 0, 0.16), (0.92, 0.92, 0.32), secondary))
bpy.ops.mesh.primitive_cylinder_add(vertices=8, radius=0.3, depth=1.55,
    location=(0, 0, 1.05))
shaft = bpy.context.active_object
shaft.name = "shaft"
shaft.data.materials.append(primary)
b = shaft.modifiers.new("bev", "BEVEL")
b.width = 0.03
b.segments = 2
bpy.ops.object.modifier_apply(modifier="bev")
parts.append(shaft)
parts.append(block("capital", (0, 0, 1.95), (0.8, 0.8, 0.24), trim))
pieces.append(join("Pillar", parts))
log("Pillar")

# --- Arch: posts, corbels, lintel over a 3-tile mouth ----------------
parts = []
for side in (-1, 1):
    parts.append(block("post", (side * 1.42, 0, 0.9), (0.5, 0.55, 1.8),
        primary))
    parts.append(block("corbel", (side * 1.28, 0, 1.86), (0.34, 0.44, 0.3),
        secondary))
parts.append(block("lintel", (0, 0, 2.12), (3.5, 0.5, 0.42), trim,
    bevel=0.06))
parts.append(block("key", (0, 0, 2.4), (0.5, 0.4, 0.24), secondary))
pieces.append(join("Arch", parts))
log("Arch")

# --- Rubble: collapsed masonry, two piles ----------------------------
for v in range(2):
    rng = random.Random(seed * 57 + v)
    parts = []
    for i in range(rng.randint(4, 6)):
        a = rng.uniform(0, math.tau)
        r = rng.uniform(0.0, 0.32)
        s = rng.uniform(0.12, 0.3)
        parts.append(block("r", (math.cos(a) * r, math.sin(a) * r, s * 0.4),
            (s, s * rng.uniform(0.7, 1.2), s * 0.8),
            primary if i % 2 else secondary, bevel=0.03,
            rot=(0, 0, rng.uniform(0, math.tau))))
    pieces.append(join("Rubble%d" % v, parts))
    log("Rubble%d" % v)

# --- Export: everything at the origin, one kit -----------------------
for o in list(bpy.data.objects):
    if o not in pieces:
        bpy.data.objects.remove(o, do_unlink=True)
for o in pieces:
    for c in list(o.users_collection):
        c.objects.unlink(o)
    bpy.context.scene.collection.objects.link(o)
bpy.ops.object.select_all(action="SELECT")
bpy.ops.export_scene.gltf(filepath=out, export_format="GLB")
import os
log("EXPORTED", out, os.path.getsize(out))
