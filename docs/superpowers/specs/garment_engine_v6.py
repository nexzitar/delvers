"""THE GARMENT CONSTRUCTION ENGINE (v6.1).
Input: a body GLB + a garment spec. Output: an ASSEMBLED garment.
v6 grammar (converging on believable low-poly equipment):
  1. BASE SHELL first - one watertight draped surface per garment.
     Seams can never gap, skin can never peek through.
  2. OVERLAYS on top - the face partition now yields raised panels
     sitting proud of the base at defined altitudes.
  3. LAYER LADDER - base < panels < straps < pads: each construction
     layer reads at its own height.
  4. CHUNKY FACETS - limited-dissolve collapses body triangulation
     into deliberate low-poly planes; wide bevels everywhere.
  5. TERMINATION BANDS - sleeves, hems and waists end in thick cuff
     rings; that is what makes fabric read as clothing.
  6. FEW, BOLD HARDWARE - a baldric with studs, one buckle, pillowed
     shoulder pads - not confetti.
Items store the spec; the engine compiles the mesh."""
import bpy, sys, os, math

def log(*a): print("[ENGINE]", *a, flush=True)

path = sys.argv[sys.argv.index("--") + 1]
out = sys.argv[sys.argv.index("--") + 2]
spec = {
    "garment": "jacket",
    "volume": 0.030, "collar": "tall", "shoulder_layers": 2,
    "buckles": 14, "sleeve_left": "rolled", "sleeve_right": "full",
    "belt": True, "hem_flaps": 5, "baldric": True,
}
if len(sys.argv) > sys.argv.index("--") + 3:
    import json
    spec.update(json.loads(sys.argv[sys.argv.index("--") + 3]))
log("spec:", spec)

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=path)
armature = next(o for o in bpy.data.objects if o.type == "ARMATURE")
def bone_head(name):
    return armature.data.bones[name].head_local

# --- Source: the parts this garment covers ---
SOURCE_PARTS = {"jacket": ("Torso", "LForearm", "RForearm"),
    "pants": ("Legs",)}
sources = [o for o in bpy.data.objects if o.type == "MESH"
    and o.name in SOURCE_PARTS[spec["garment"]]]
bpy.ops.object.select_all(action="DESELECT")
copies = []
for src in sources:
    bpy.context.view_layer.objects.active = src
    src.select_set(True)
    bpy.ops.object.duplicate()
    copies.append(bpy.context.active_object)
    src.select_set(False)
for c in copies:
    c.select_set(True)
bpy.context.view_layer.objects.active = copies[0]
bpy.ops.object.join()
source = bpy.context.active_object
source.name = "GarmentSource"

# --- Shared drape (one inflation, so every piece's seams align) ---
# Waist compression: cinched at the belt, FLARED below it.
REGION_W = {"L_Clavicle": 1.0, "R_Clavicle": 1.0,
    "L_Upperarm": 0.9, "R_Upperarm": 0.9,
    "L_UpperarmTwist01": 0.8, "R_UpperarmTwist01": 0.8,
    "L_UpperarmTwist02": 0.7, "R_UpperarmTwist02": 0.7,
    "Spine02": 0.9, "NeckTwist01": 0.7, "NeckTwist02": 0.7,
    "Spine01": 0.55, "R_Forearm": 0.45, "R_ForearmTwist01": 0.4,
    "R_ForearmTwist02": 0.4, "L_Forearm": 0.45, "L_ForearmTwist01": 0.4,
    "L_ForearmTwist02": 0.4, "Waist": 0.2, "Pelvis": 0.65,
    "L_Thigh": 0.6, "R_Thigh": 0.6, "L_ThighTwist01": 0.55,
    "R_ThighTwist01": 0.55, "L_ThighTwist02": 0.5, "R_ThighTwist02": 0.5,
    "L_Calf": 0.4, "R_Calf": 0.4, "L_CalfTwist01": 0.35,
    "R_CalfTwist01": 0.35, "L_CalfTwist02": 0.3, "R_CalfTwist02": 0.3}
name_by_idx = {g.index: g.name for g in source.vertex_groups}
# Cloth rounds the torso: fabric spans the belly instead of shrink-
# wrapping every ab. CAST-to-cylinder, scoped to this group.
TORSO_ROUND = {"Spine01", "Spine02", "Waist"}
rounder = source.vertex_groups.new(name="torso_round")
for v in source.data.vertices:
    w = 0.0
    for g in v.groups:
        if name_by_idx.get(g.group, "") in TORSO_ROUND:
            w = max(w, g.weight)
    if w > 0.0:
        rounder.add([v.index], min(w, 1.0), "REPLACE")
# The cylinder cloth drapes toward: the torso's own mean radius, so
# rounding never balloons the silhouette.
_tr = [(v.co.x ** 2 + v.co.y ** 2) ** 0.5 for v in source.data.vertices
    if any(name_by_idx.get(g.group, "") in TORSO_ROUND and g.weight > 0.5
        for g in v.groups)]
torso_radius = sum(_tr) / max(len(_tr), 1)
log("torso radius", round(torso_radius, 4))
inflate = source.vertex_groups.new(name="inflate_w")
for v in source.data.vertices:
    w = 0.15
    for g in v.groups:
        w = max(w, REGION_W.get(name_by_idx.get(g.group, ""), 0.0) * g.weight)
    inflate.add([v.index], min(w, 1.0), "REPLACE")

# --- Regions: weight-voted face partition (now used for overlays) ---
GSETS = {
    "thigh_l": {"L_Thigh", "L_ThighTwist01", "L_ThighTwist02"},
    "thigh_r": {"R_Thigh", "R_ThighTwist01", "R_ThighTwist02"},
    "calf_l": {"L_Calf", "L_CalfTwist01", "L_CalfTwist02"},
    "calf_r": {"R_Calf", "R_CalfTwist01", "R_CalfTwist02"},
    "torso": {"Spine01", "Spine02", "Waist", "Pelvis"},
    "yoke": {"L_Clavicle", "R_Clavicle", "NeckTwist01", "NeckTwist02"},
    "arm_l_up": {"L_Upperarm", "L_UpperarmTwist01", "L_UpperarmTwist02"},
    "arm_r_up": {"R_Upperarm", "R_UpperarmTwist01", "R_UpperarmTwist02"},
    "arm_l_lo": {"L_Forearm", "L_ForearmTwist01", "L_ForearmTwist02"},
    "arm_r_lo": {"R_Forearm", "R_ForearmTwist01", "R_ForearmTwist02"},
}
gidx = {k: {g.index for g in source.vertex_groups if g.name in names}
        for k, names in GSETS.items()}
def wsum(v, key):
    return sum(g.weight for g in v.groups if g.group in gidx[key])

mesh = source.data
face_piece = {}
for poly in mesh.polygons:
    scores = {k: 0.0 for k in gidx}
    cx = cy = 0.0
    for vi in poly.vertices:
        v = mesh.vertices[vi]
        cx += v.co.x
        cy += v.co.y
        for k in gidx:
            scores[k] += wsum(v, k)
    cx /= len(poly.vertices)
    cy /= len(poly.vertices)
    key = max(scores, key=lambda k: scores[k])
    if key == "torso":
        if cy <= 0:
            key = "torso_back"
        elif cx < 0:
            key = "torso_fl"
        else:
            key = "torso_fr"
    face_piece[poly.index] = key

# --- Piece derivation ---
# altitude lifts a piece off the shared drape (the layer ladder);
# chunk is the limited-dissolve angle that turns body triangulation
# into deliberate low-poly facets.
pieces = []
def derive_piece(name, keys, thickness, altitude=0.0, chunk=15.0,
        bevel=0.005):
    bpy.context.view_layer.objects.active = source
    for o in bpy.data.objects:
        o.select_set(o == source)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_mode(type="FACE")
    bpy.ops.mesh.select_all(action="DESELECT")
    bpy.ops.object.mode_set(mode="OBJECT")
    n = 0
    for poly in source.data.polygons:
        if face_piece.get(poly.index) in keys:
            poly.select = True
            n += 1
    if n < 1:
        log("piece", name, "EMPTY")
        return None
    before = set(o.name for o in bpy.data.objects)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.duplicate()
    bpy.ops.mesh.separate(type="SELECTED")
    bpy.ops.object.mode_set(mode="OBJECT")
    piece = next(o for o in bpy.data.objects if o.name not in before)
    piece.name = name
    bpy.context.view_layer.objects.active = piece
    for o in bpy.data.objects:
        o.select_set(o == piece)
    d = piece.modifiers.new("drape", "DISPLACE")
    d.strength = spec["volume"]; d.mid_level = 0.0; d.vertex_group = "inflate_w"
    bpy.ops.object.modifier_apply(modifier="drape")
    if any(k in keys for k in ("torso_fl", "torso_fr", "torso_back")):
        c_ = piece.modifiers.new("round", "CAST")
        c_.cast_type = "CYLINDER"; c_.factor = 0.8
        c_.size = torso_radius; c_.use_radius_as_size = False
        c_.vertex_group = "torso_round"
        bpy.ops.object.modifier_apply(modifier="round")
    if altitude > 0.0:
        a_ = piece.modifiers.new("alt", "DISPLACE")
        a_.strength = altitude; a_.mid_level = 0.0
        bpy.ops.object.modifier_apply(modifier="alt")
    if chunk > 0.0:
        bpy.ops.object.mode_set(mode="EDIT")
        bpy.ops.mesh.select_all(action="SELECT")
        bpy.ops.mesh.dissolve_limited(angle_limit=math.radians(chunk))
        bpy.ops.object.mode_set(mode="OBJECT")
    s_ = piece.modifiers.new("thick", "SOLIDIFY")
    s_.thickness = thickness; s_.offset = 1.0
    b = piece.modifiers.new("bev", "BEVEL")
    b.width = bevel; b.segments = 1; b.angle_limit = math.radians(40)
    for m in ["thick", "bev"]:
        bpy.ops.object.modifier_apply(modifier=m)
    piece.data.materials.clear()
    piece.data.materials.append(gar_primary if altitude == 0.0 else gar_secondary)
    pieces.append(piece)
    log("piece", name, n, "faces")
    return piece

# --- Garment materials: solid two-tone, dyed at runtime ---
gar_primary = bpy.data.materials.new("GarmentPrimary")
gar_primary.use_nodes = True
gar_primary.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.36, 0.26, 0.16, 1)
gar_primary.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value = 0.88
gar_secondary = bpy.data.materials.new("GarmentSecondary")
gar_secondary.use_nodes = True
gar_secondary.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.3, 0.21, 0.13, 1)
gar_secondary.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value = 0.88

rolled = spec["sleeve_left"] == "rolled"

# --- The garment: watertight base shell, then raised overlays ---
if spec["garment"] == "pants":
    derive_piece("Base", {"thigh_l", "thigh_r", "calf_l", "calf_r"},
        0.011, chunk=15.0)
    derive_piece("ThighL", {"thigh_l"}, 0.007, altitude=0.005, chunk=18.0,
        bevel=0.006)
    derive_piece("ThighR", {"thigh_r"}, 0.007, altitude=0.005, chunk=18.0,
        bevel=0.006)
else:
    base_keys = {"torso_fl", "torso_fr", "torso_back", "yoke",
        "arm_l_up", "arm_r_up"}
    if spec["sleeve_right"] == "full":
        base_keys.add("arm_r_lo")
    if not rolled:
        base_keys.add("arm_l_lo")
    derive_piece("Base", base_keys, 0.012, chunk=15.0)
    derive_piece("Yoke", {"yoke"}, 0.010, altitude=0.009, chunk=18.0,
        bevel=0.006)
    derive_piece("FrontLeft", {"torso_fl"}, 0.007, altitude=0.005,
        chunk=18.0, bevel=0.006)
    derive_piece("FrontRight", {"torso_fr"}, 0.007, altitude=0.005,
        chunk=18.0, bevel=0.006)
    derive_piece("Back", {"torso_back"}, 0.007, altitude=0.005,
        chunk=18.0, bevel=0.006)
    derive_piece("SleevePadL", {"arm_l_up"}, 0.008, altitude=0.007,
        chunk=18.0, bevel=0.006)
    derive_piece("SleevePadR", {"arm_r_up"}, 0.008, altitude=0.007,
        chunk=18.0, bevel=0.006)

# --- Hardware: leather and steel, few and bold ---
leather = bpy.data.materials.new("StrapLeather")
leather.use_nodes = True
leather.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.1, 0.065, 0.04, 1)
steel = bpy.data.materials.new("ClaspSteel")
steel.use_nodes = True
steel.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.34, 0.32, 0.3, 1)

def prim(name, loc, scale, rot, bone, mat=leather, bev=0.006, segs=2):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc)
    o = bpy.context.active_object
    o.name = name
    o.scale = scale
    o.rotation_euler = rot
    o.data.materials.append(mat)
    bpy.ops.object.transform_apply(scale=True, rotation=True)
    if bev > 0.0:
        b = o.modifiers.new("bev", "BEVEL")
        b.width = bev; b.segments = segs
        bpy.ops.object.modifier_apply(modifier="bev")
    vg = o.vertex_groups.new(name=bone)
    vg.add(list(range(len(o.data.vertices))), 1.0, "REPLACE")
    pieces.append(o)
    return o

neck = bone_head("NeckTwist01")
waist = bone_head("Waist")
if spec["garment"] == "pants":
    # Waistband with a real buckle, knee pads, one thigh pouch.
    hip = bone_head("Pelvis")
    for i in range(10):
        a = math.tau * i / 10.0
        prim("band%d" % i,
            (0.108 * math.sin(a), 0.108 * math.cos(a), hip.z + 0.015),
            (0.055, 0.022, 0.034), (0, 0, -a), "Pelvis")
    prim("beltbuckle", (0, 0.135, hip.z + 0.015), (0.034, 0.016, 0.028),
        (0, 0, 0), "Pelvis", mat=steel, bev=0.004)
    for side in ("L", "R"):
        knee = bone_head(side + "_Calf")
        prim("knee" + side, (knee.x, knee.y + 0.058, knee.z + 0.01),
            (0.068, 0.028, 0.082), (math.radians(-10), 0, 0),
            side + "_Calf", bev=0.012)
        prim("kneestrap" + side, (knee.x, knee.y, knee.z + 0.055),
            (0.078, 0.078, 0.016), (0, 0, 0), side + "_Thigh")
    thigh = bone_head("R_Thigh")
    prim("pouch", (thigh.x + 0.058, thigh.y + 0.03, thigh.z - 0.09),
        (0.052, 0.038, 0.062), (0, math.radians(15), 0), "R_Thigh",
        bev=0.01)
    prim("pouchflap", (thigh.x + 0.058, thigh.y + 0.05, thigh.z - 0.06),
        (0.054, 0.018, 0.026), (math.radians(-15), 0, 0), "R_Thigh",
        mat=steel, bev=0.004)
    # Trouser cuffs: the hem folds over above the boot.
    for side in ("L", "R"):
        calf = bone_head(side + "_Calf")
        for i in range(6):
            a = math.tau * i / 6.0
            prim("cuff%s%d" % (side, i),
                (calf.x + 0.052 * math.sin(a), calf.y + 0.052 * math.cos(a),
                 calf.z - 0.155), (0.042, 0.02, 0.045), (0, 0, -a),
                side + "_Calf")
l_elbow = bone_head("L_Forearm")
l_wrist = bone_head("L_Hand")
r_wrist = bone_head("R_Hand")
l_sh = bone_head("L_Upperarm")
r_sh = bone_head("R_Upperarm")

# Collar (tall = bigger, prouder).
jacket_hw = spec["garment"] == "jacket"
collar_h = 0.08 if spec["collar"] == "tall" else 0.05
for i in (range(8) if jacket_hw else []):
    a = math.tau * i / 8.0
    if math.cos(a) > 0.8:
        continue
    prim("collar%d" % i,
        (0.082 * math.sin(a), 0.082 * math.cos(a), neck.z + 0.02),
        (0.075, 0.022, collar_h), (math.radians(-16) * math.cos(a), 0, -a),
        "NeckTwist01")
# Hardware rhythm: the clasp ladder down the placket, bolder now.
n_clasps = spec["buckles"] if jacket_hw else 0
span = neck.z - 0.02 - (waist.z + 0.02)
for i in range(n_clasps):
    z = neck.z - 0.02 - span * i / max(n_clasps - 1, 1)
    prim("clasp%d" % i, (-0.01, 0.178, z), (0.055, 0.016, 0.016), (0, 0, 0),
        "Spine02" if z > (neck.z + waist.z) / 2 else "Spine01", mat=steel,
        bev=0.004)
# The baldric: a studded strap from the right shoulder to the left
# hip, riding proud of every panel it crosses.
if jacket_hw and spec.get("baldric", True):
    start = (r_sh.x * 0.55, 0.16, r_sh.z + 0.02)
    end = (-0.085, 0.148, waist.z - 0.005)
    n_seg = 7
    for i in range(n_seg):
        t = i / (n_seg - 1.0)
        p = tuple(start[j] + (end[j] - start[j]) * t for j in range(3))
        bone = "Spine02" if p[2] > (neck.z + waist.z) / 2 else "Spine01"
        prim("baldric%d" % i, p, (0.05, 0.018, 0.058), (0, 0, 0), bone)
        if i % 2 == 1:
            prim("stud%d" % i, (p[0], p[1] + 0.014, p[2]),
                (0.016, 0.01, 0.016), (0, 0, 0), bone, mat=steel,
                bev=0.003)
# Pillowed shoulder pads: two big rounded slabs stepping down the arm.
layers = spec["shoulder_layers"] if jacket_hw else 0
for side, sh in ((-1, l_sh), (1, r_sh)) if jacket_hw else []:
    bone = ("L" if side < 0 else "R") + "_Upperarm"
    for t in range(layers):
        prim("pad%d_%d" % (side, t),
            (sh.x + side * (0.02 + t * 0.026), sh.y,
             sh.z + 0.062 - t * 0.03),
            (0.1 - t * 0.012, 0.14 - t * 0.012, 0.038),
            (0, math.radians(side * (12 + t * 12)), 0), bone, bev=0.014)
# Cuffs: every sleeve ends in a band - rolled at the elbow, full at
# the wrist. Terminations are what make fabric read as clothing.
if rolled and jacket_hw:
    for i in range(6):
        a = math.tau * i / 6.0
        prim("rollcuff%d" % i,
            (l_elbow.x + 0.05 * math.sin(a), l_elbow.y + 0.05 * math.cos(a),
             l_elbow.z + 0.02), (0.036, 0.022, 0.052), (0, 0, -a),
            "L_Upperarm")
elif jacket_hw:
    for i in range(6):
        a = math.tau * i / 6.0
        prim("cuffL%d" % i,
            (l_wrist.x + 0.034 * math.sin(a), l_wrist.y + 0.034 * math.cos(a),
             l_wrist.z + 0.03), (0.03, 0.019, 0.042), (0, 0, -a),
            "L_Forearm")
for i in (range(6) if jacket_hw else []):
    a = math.tau * i / 6.0
    prim("cuffR%d" % i,
        (r_wrist.x + 0.034 * math.sin(a), r_wrist.y + 0.034 * math.cos(a),
         r_wrist.z + 0.03), (0.03, 0.019, 0.042), (0, 0, -a), "R_Forearm")
# Belt (compressing the cinch) + buckle + hem flaps.
if spec["belt"] and jacket_hw:
    for i in range(10):
        a = math.tau * i / 10.0
        prim("belt%d" % i,
            (0.12 * math.sin(a), 0.12 * math.cos(a), waist.z),
            (0.058, 0.022, 0.038), (0, 0, -a), "Waist")
    prim("buckle", (0, 0.148, waist.z), (0.038, 0.016, 0.032), (0, 0, 0),
        "Waist", mat=steel, bev=0.004)
for i in (range(spec["hem_flaps"]) if jacket_hw else []):
    a = [0.45, 1.5, math.pi - 0.45, math.pi + 0.8, -0.8][i % 5]
    length = 0.10 if i == 4 else 0.062
    prim("hem%d" % i,
        (0.124 * math.sin(a), 0.124 * math.cos(a),
         waist.z - 0.022 - length * 0.5),
        (0.068, 0.016, length), (0, 0, -a), "Pelvis")

# --- Assemble, escape the cursed collection, export skinned ---
target = pieces[0]
for o in bpy.data.objects:
    o.select_set(o in pieces)
bpy.context.view_layer.objects.active = target
bpy.ops.object.join()
target.name = "Garment"
for o in list(bpy.data.objects):
    if o not in (target, armature):
        bpy.data.objects.remove(o, do_unlink=True)
for obj in (target, armature):
    for c in list(obj.users_collection):
        c.objects.unlink(obj)
    bpy.context.scene.collection.objects.link(obj)
bpy.ops.object.select_all(action="SELECT")
bpy.ops.export_scene.gltf(filepath=out, export_format="GLB",
    export_animations=False, export_skins=True)
log("EXPORTED size", os.path.getsize(out))
