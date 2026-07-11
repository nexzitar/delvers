@tool
class_name AnimatedActor
extends Node3D

const DelverBuilder = preload("res://scripts/theater3d/delver_builder.gd")
const SpringTailScene = preload("res://scripts/theater3d/spring_tail.gd")

## Wraps an imported character (glTF/GLB, e.g. TripoAI) so the theater
## drives it exactly like a procedural rig: the pose functions SEEK
## named clips rather than playing them - deterministic, replay-
## friendly scrubbing, the same shape as pose_walk(t) on DelverRig.
## Missing clips degrade gracefully (fall back role, then stillness).

## Sculpted gear (TripoAI): fits are per-sculpt transforms, WORN_MODELS
## maps gear ids onto a fit plus an optional recolor palette (the
## gear_recolor shader swaps primary/secondary/trim, keeping the baked
## shading). Unlisted gear falls back to the procedural boxes.
const GEAR_FITS := {
	"helm": {"hides": "Hair",
		"path": "res://resources/models/starter_helm.glb",
		"bone": "Head", "position": Vector3(0, 0.078, -0.012),
		"rotation": Vector3(0, 180, 0), "scale": 0.27},
	"chest": {"path": "res://resources/models/starter_chest.glb",
		"bone": "Spine01", "position": Vector3(0, -0.06, 0),
		"rotation": Vector3(0, 180, 0), "scale": 0.42},
	"belt": {"path": "res://resources/models/leather_belt.glb",
		"bone": "Waist", "position": Vector3(0, -0.04, 0),
		"rotation": Vector3(0, 180, 0), "scale": 0.21},
	"pauldron": {"path": "res://resources/models/iron_pauldron.glb",
		"pair_bones": ["L_Upperarm", "R_Upperarm"],
		"position": Vector3(0, 0.055, 0),
		"rotation": Vector3(0, 90, 0), "scale": 0.24},
	"boot": {"hides": "Feet",
		"path": "res://resources/models/gear_boot.glb",
		"pair_bones": ["L_Foot", "R_Foot"], "mirror": "none",
		"position": Vector3(0, 0.04, -0.02),
		"rotation": Vector3(0, 180, 0), "scale": 0.2},
	"greave": {"path": "res://resources/models/gear_greave.glb",
		"pair_bones": ["L_Calf", "R_Calf"], "mirror": "none",
		"position": Vector3(0, 0.12, -0.02),
		"rotation": Vector3(0, 180, 0), "scale": 0.3},
	"bracer": {"path": "res://resources/models/gear_bracer.glb",
		"pair_bones": ["L_Forearm", "R_Forearm"],
		"position": Vector3(0, 0.12, 0),
		"rotation": Vector3(0, 0, 0), "scale": 0.12},
	"gauntlet": {"hides": "Hands",
		"path": "res://resources/models/gear_gauntlet.glb",
		"pair_bones": ["L_Hand", "R_Hand"],
		"position": Vector3(0, 0.04, 0),
		"rotation": Vector3(0, 0, 0), "scale": 0.15},
	"headband": {"path": "res://resources/models/gear_headband.glb",
		"bone": "Head", "position": Vector3.ZERO,
		"rotation": Vector3.ZERO, "scale": 1.0, "world_rest": true},
	"jacket": {"path": "res://resources/models/derived_jacket.glb",
		"skinned": true, "hides": ["Torso", "RForearm"]},
	"jacket_plain": {"path": "res://resources/models/derived_jacket_plain.glb",
		"skinned": true, "hides": ["Torso", "RForearm", "LForearm"]},
	"pants": {"path": "res://resources/models/derived_pants.glb",
		"skinned": true, "hides": ["Legs"]},
	"shield_m": {"path": "res://resources/models/gear_shield.glb",
		"bone": "L_Forearm", "position": Vector3(0, 0.12, -0.06),
		"rotation": Vector3(0, 0, 0), "scale": 0.4},
	"sword_m": {"path": "res://resources/models/gear_sword.glb",
		"bone": "R_Hand", "position": Vector3(0, 0.05, 0),
		"rotation": Vector3(-45, 0, 0), "scale": 0.5},
}
const WORN_MODELS := {
	"starter_helmet": {"fit": "helm"},
	"starter_headband": {"fit": "headband"},
	"chitin_armor": {"fit": "chest", "palette": {
		"primary": Color(0.32, 0.23, 0.13), "secondary": Color(0.14, 0.1, 0.07),
		"trim": Color(0.78, 0.73, 0.58)}},
	"studded_belt": {"fit": "belt"},
	"wardens_pauldrons": {"fit": "pauldron"},
	"iron_shod_boots": {"fit": "boot"},
	"sprung_boots": {"fit": "boot", "palette": {
		"primary": Color(0.22, 0.16, 0.1), "secondary": Color(0.45, 0.42, 0.38),
		"trim": Color(0.6, 0.5, 0.3)}},
	"iron_greaves": {"fit": "greave"},
	"silk_bracers": {"fit": "bracer", "palette": {
		"primary": Color(0.85, 0.82, 0.72), "secondary": Color(0.6, 0.55, 0.45),
		"trim": Color(0.5, 0.42, 0.3)}},
	"goblin_work_gauntlets": {"fit": "gauntlet"},
	"starter_armor": {"fit": "jacket_plain", "palette": {
		"primary": Color(0.34, 0.24, 0.14), "secondary": Color(0.26, 0.18, 0.11),
		"trim": Color(0.42, 0.32, 0.2), "flatten": 0.9}},
	"oiled_leathers": {"fit": "jacket", "palette": {
		"primary": Color(0.13, 0.1, 0.08), "secondary": Color(0.1, 0.08, 0.06),
		"trim": Color(0.24, 0.19, 0.13), "flatten": 0.9}},
	"leather_trousers": {"fit": "pants", "palette": {
		"primary": Color(0.27, 0.19, 0.12), "secondary": Color(0.2, 0.14, 0.09),
		"trim": Color(0.36, 0.28, 0.18), "flatten": 0.9}},
	"starter_trousers": {"fit": "pants", "palette": {
		"primary": Color(0.35, 0.28, 0.19), "secondary": Color(0.28, 0.22, 0.15),
		"trim": Color(0.4, 0.33, 0.24), "flatten": 0.9}},
	"starter_boots": {"fit": "boot", "palette": {
		"primary": Color(0.3, 0.22, 0.14), "secondary": Color(0.38, 0.34, 0.28),
		"trim": Color(0.42, 0.33, 0.22), "flatten": 0.9}},
	"starter_gloves": {"fit": "gauntlet", "palette": {
		"primary": Color(0.34, 0.26, 0.17), "secondary": Color(0.27, 0.2, 0.13),
		"trim": Color(0.42, 0.34, 0.23), "flatten": 0.9}},
	"starter_belt": {"fit": "belt", "palette": {
		"primary": Color(0.3, 0.22, 0.14), "secondary": Color(0.24, 0.18, 0.11),
		"trim": Color(0.45, 0.38, 0.26), "flatten": 0.9}},
	"starter_shield": {"fit": "shield_m"},
	"chitin_shield": {"fit": "shield_m", "palette": {
		"primary": Color(0.3, 0.22, 0.13), "secondary": Color(0.16, 0.11, 0.07),
		"trim": Color(0.75, 0.7, 0.55)}},
	"starter_sword": {"fit": "sword_m"},
}
const RECOLOR_SHADER := "res://art/shaders/gear_recolor.gdshader"

## Clip discovery: first animation whose name contains a keyword wins
## the role. Tripo/Mixamo-style names all land.
const ROLES := {
	"idle": ["idle", "stand", "breath"],
	"walk": ["walk", "run", "move", "jog"],
	"swing": ["attack", "swing", "slash", "melee", "punch", "chop"],
	"shoot": ["shoot", "bow", "draw", "fire", "aim"],
	"death": ["death", "die", "fall", "defeat"],
	"cast": ["cast", "spell", "magic"],
	"spin": ["spin", "whirl", "turn"],
}
## When a role has no clip of its own, borrow this one.
const FALLBACKS := {"cast": "swing", "spin": "swing", "shoot": "swing"}

## Most exports face -Z; our rigs face +Z. Override per model if needed.
var facing_fix := PI

## Long captured clips often hold one good stretch: per-role [from, to]
## seconds, scrubbed within that window only (kills idle foot-slides).
var clip_ranges := {}
## The theater's walk phase is radians (sin-based rigs); one clip
## cycle spans TAU * this. Bigger = slower stride.
var walk_cycle_scale := 1.0
## "" = garments as authored (male body); "_f" = female-compiled GLBs.
var garment_suffix := ""

var _player: AnimationPlayer
var _skeleton: Skeleton3D
var _model: Node3D
var _clips := {}
var _bones := {}
var _has_sword := false
## Owner-tuned pose parameters (see the Guild Animator's save button).
var tuning := {}

const TUNING_PATH := "res://resources/tuning/pose_tuning.json"
static var _tuning_cache = null

static func _load_tuning() -> Dictionary:
	if _tuning_cache == null:
		_tuning_cache = {}
		if FileAccess.file_exists(TUNING_PATH):
			var parsed = JSON.parse_string(FileAccess.get_file_as_string(TUNING_PATH))
			if parsed is Dictionary:
				_tuning_cache = parsed
	return _tuning_cache
var _shield_arm: BoneAttachment3D
var _shield_prop: Node3D
var _sword_node: Node3D
## fit_key -> [mounted piece nodes], for live fitting in the Animator.
var worn_mounts := {}
## grip_key -> prop node, for socket-mounted built weapons (sword_p,
## shield_p, bow_p) - the Socket Workshop edits these live.
var prop_mounts := {}
## Named body parts (Hair/Feet/Hands), hidden by the gear that covers
## them - the surgery lives in the GLBs, split via Blender.
var _body_parts := {}
## Derived gear (built FROM the body in Blender) ships in body
## coordinates: align it to the skeleton at rest, then the mount
## bone carries it. Fit by construction, no numbers.
var _world_rest_pending := []

func _ready():
	for fit_key in _world_rest_pending:
		_align_world_rest(fit_key)
	_world_rest_pending.clear()

func _hide_covered(fit: Dictionary):
	if not fit.has("hides"):
		return
	var names = fit.hides if fit.hides is Array else [fit.hides]
	for part_name in names:
		if _body_parts.has(part_name):
			_body_parts[part_name].visible = false

func _align_world_rest(fit_key: String):
	for piece in worn_mounts.get(fit_key, []):
		var mount = piece.get_parent()
		piece.transform = mount.global_transform.affine_inverse() \
			* _skeleton.global_transform

func _init(scene: PackedScene, opts := {}):
	var model = scene.instantiate()
	model.rotation.y = opts.get("facing_fix", facing_fix)
	if opts.has("model_scale"):
		model.scale = Vector3.ONE * opts.model_scale
	add_child(model)
	_model = model
	clip_ranges = opts.get("clip_ranges", {})
	walk_cycle_scale = opts.get("walk_cycle_scale", 1.0)
	garment_suffix = opts.get("garment_suffix", "")
	_has_sword = opts.get("sword", false)
	tuning = _load_tuning().duplicate(true)
	_player = _find_player(model)
	_skeleton = _find_skeleton(model)
	if _skeleton:
		for i in _skeleton.get_bone_count():
			_bones[_skeleton.get_bone_name(i)] = i
		for child in _skeleton.get_children():
			if child is MeshInstance3D and child.name in ["Hair", "Feet", "Hands", "Torso", "LForearm", "RForearm", "Legs"]:
				_body_parts[String(child.name)] = child
	# Animation donor: a bare rigged export borrows a sibling's clips -
	# same skeleton, retargeted by bone name. One animation set can
	# drive the whole cast.
	if _player == null and _skeleton and opts.has("animation_donor"):
		_player = _borrow_animations(load(opts.animation_donor))
	if _skeleton:
		_dress(opts)
	if _player == null:
		return
	_player.playback_default_blend_time = 0.0
	# Explicit role -> clip mapping wins (Tripo exports lose clip
	# names to NlaTrack_*); keyword discovery covers the rest.
	for role in opts.get("clip_map", {}):
		if _player.has_animation(opts.clip_map[role]):
			_clips[role] = opts.clip_map[role]
	for clip_name in _player.get_animation_list():
		var lower = String(clip_name).to_lower()
		for role in ROLES:
			if _clips.has(role):
				continue
			for keyword in ROLES[role]:
				if lower.contains(keyword):
					_clips[role] = clip_name
					break

## Copy the donor's animations, rewriting every track's node path to
## our skeleton (bone names carry over unchanged).
func _borrow_animations(donor_scene: PackedScene) -> AnimationPlayer:
	var donor = donor_scene.instantiate()
	var donor_player = _find_player(donor)
	if donor_player == null:
		donor.free()
		return null
	var player := AnimationPlayer.new()
	_skeleton.add_child(player)
	player.root_node = player.get_path_to(_skeleton)
	var lib := AnimationLibrary.new()
	for clip_name in donor_player.get_animation_list():
		var clip: Animation = donor_player.get_animation(clip_name).duplicate(true)
		for track in clip.get_track_count():
			var path := String(clip.track_get_path(track))
			var bone = path.get_slice(":", 1)
			if bone != "":
				clip.track_set_path(track, NodePath(".:" + bone))
		lib.add_animation(clip_name, clip)
	player.add_animation_library("", lib)
	donor.free()
	return player

func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node
	for child in node.get_children():
		var found = _find_skeleton(child)
		if found:
			return found
	return null

func _attach(bone: String) -> BoneAttachment3D:
	var mount := BoneAttachment3D.new()
	_skeleton.add_child(mount)
	mount.bone_name = bone
	return mount

## Eyes and weapons ride the bones. The generated texture's eyes are
## faint smudges; two dark studs on the head bone read at any size,
## exactly like the procedural rigs' quads.
func _dress(opts: Dictionary):
	# Head bone: origin at eye height, +Y up, face along -Z.
	var eye_specs = opts.get("eyes_spec", {
		"offset": Vector3(0.05, 0.1, -0.115), "size": 0.024,
		"color": Color(0.13, 0.11, 0.1),
	})
	var head = _attach("Head")
	for side in [-1.0, 1.0]:
		var eye := MeshInstance3D.new()
		var ball := BoxMesh.new()
		ball.size = Vector3.ONE * eye_specs.size
		eye.mesh = ball
		var mat := StandardMaterial3D.new()
		mat.albedo_color = eye_specs.color
		mat.roughness = 0.4
		eye.material_override = mat
		eye.position = Vector3(eye_specs.offset.x * side,
			eye_specs.offset.y, eye_specs.offset.z)
		eye.scale = Vector3(1.0, 1.3, 0.5)
		head.add_child(eye)

	# Long hair swings free: a spring chain from the back of the head.
	if opts.has("hair_tail"):
		var tail = SpringTailScene.new()
		var spec = opts.hair_tail
		tail.tail_color = spec.get("color", tail.tail_color)
		tail.segment_length = spec.get("segment_length", tail.segment_length)
		tail.position = spec.get("offset", Vector3(0, 0.14, 0.09))
		head.add_child(tail)

	# Worn gear: the same opt keys the procedural rigs dress with,
	# mounted on bones. Boxes for now; sculpted pieces come later.
	if opts.get("helmet", false):
		if not _mount_worn_model(opts.get("helmet_gear", "")):
			var helm_mount = _attach("Head")
			var helm = DelverBuilder.build_helmet()
			helm.position = Vector3(0, 0.13, -0.01)
			helm.rotation_degrees = Vector3(0, 180, 0)
			helm.scale = Vector3.ONE * 0.78
			helm_mount.add_child(helm)
	if opts.has("shoulders") and not _mount_worn_model(opts.get("shoulder_gear", "")):
		for side in ["L", "R"]:
			var pad_mount = _attach(side + "_Upperarm")
			for tier in [[0.0, 0.115, 0.05], [0.045, 0.095, 0.04]]:
				var pad := MeshInstance3D.new()
				var pad_mesh := BoxMesh.new()
				pad_mesh.size = Vector3(tier[1], tier[2], tier[1])
				pad.mesh = pad_mesh
				pad.material_override = _flat(opts.shoulders)
				pad.position = Vector3(0, -0.01 - tier[0], 0)
				pad_mount.add_child(pad)
	if opts.has("chest_plate"):
		if not _mount_worn_model(opts.get("chest_gear", "")):
			var chest_mount = _attach("Spine02")
			var plate := MeshInstance3D.new()
			var plate_mesh := BoxMesh.new()
			plate_mesh.size = Vector3(0.21, 0.17, 0.045)
			plate.mesh = plate_mesh
			plate.material_override = _flat(opts.chest_plate)
			plate.position = Vector3(0, 0.05, -0.075)
			chest_mount.add_child(plate)
	if opts.has("cloak"):
		var cloak_mount = _attach("Spine02")
		var cloak = SpringTailScene.new()
		cloak.tail_color = opts.cloak
		cloak.width = 0.3
		cloak.depth = 0.022
		cloak.segment_length = 0.15
		cloak.stiffness = 0.5
		cloak.rest_local = Vector3(0, -0.9, 0.35)
		cloak.position = Vector3(0, 0.1, 0.075)
		cloak_mount.add_child(cloak)
	if opts.has("belt_trim") and not _mount_worn_model(opts.get("belt_gear", "")):
		var belt_mount = _attach("Waist")
		var belt := MeshInstance3D.new()
		var belt_mesh := BoxMesh.new()
		belt_mesh.size = Vector3(0.2, 0.05, 0.14)
		belt.mesh = belt_mesh
		belt.material_override = _flat(opts.belt_trim)
		belt.position = Vector3(0, 0.03, 0)
		belt_mount.add_child(belt)
		var buckle := MeshInstance3D.new()
		var buckle_mesh := BoxMesh.new()
		buckle_mesh.size = Vector3(0.04, 0.04, 0.015)
		buckle.mesh = buckle_mesh
		buckle.material_override = _flat(Color(0.75, 0.62, 0.3))
		buckle.position = Vector3(0, 0.03, -0.072)
		belt_mount.add_child(buckle)
	# Any remaining worn gear with a fitted model mounts by id; fits
	# already claimed above (helm, chest, belt, shoulders) skip through.
	for gear_id in opts.get("gear_ids", []):
		if WORN_MODELS.has(gear_id) and not worn_mounts.has(WORN_MODELS[gear_id].fit):
			_mount_worn_model(gear_id)
	var region_fits := {"gauntlets": ["gauntlet"], "bracers": ["bracer"],
		"greaves": ["greave", "pants"], "boots_gear": ["boot"]}
	for pair in [["gauntlets", "Hand", Vector3(0, 0.02, 0), Vector3(0.075, 0.08, 0.09)],
			["bracers", "Forearm", Vector3(0, 0.1, 0), Vector3(0.07, 0.09, 0.075)],
			["greaves", "Calf", Vector3(0, 0.12, 0), Vector3(0.085, 0.13, 0.095)],
			["boots_gear", "Foot", Vector3(0, 0.03, -0.02), Vector3(0.085, 0.07, 0.16)]]:
		if not opts.has(pair[0]):
			continue
		# A fitted model already covers this region - no box fallback.
		if region_fits[pair[0]].any(func(f): return worn_mounts.has(f)):
			continue
		for side in ["L", "R"]:
			var mount = _attach(side + "_" + pair[1])
			var piece := MeshInstance3D.new()
			var piece_mesh := BoxMesh.new()
			piece_mesh.size = pair[3]
			piece.mesh = piece_mesh
			piece.material_override = _flat(opts[pair[0]])
			piece.position = pair[2]
			mount.add_child(piece)
	if opts.get("bow", false):
		var bow = DelverBuilder.build_bow()
		if not _socket_mount_node(bow, "bow_p", 0.9):
			var bow_mount = _attach("L_Hand")
			bow.position = Vector3(0, 0.05, 0)
			bow.scale = Vector3.ONE * 0.9
			bow_mount.add_child(bow)

	# Weapons: the same meshes the procedural rigs carry, gripped by
	# the hand bones. Blade along the hand's local axis, tuned by eye.
	var main_model := false
	if opts.get("sword", false):
		main_model = _mount_worn_model(opts.get("main_gear", ""))
		if main_model:
			var main_fit = WORN_MODELS[opts.main_gear].fit
			_sword_node = worn_mounts[main_fit].back()
	if not main_model and (opts.get("sword", false) or opts.get("axe", false) or opts.get("dagger", false)):
		var weapon = DelverBuilder.build_axe() if opts.get("axe", false) \
			else DelverBuilder.build_dagger() if opts.get("dagger", false) \
			else DelverBuilder.build_sword()
		if not _socket_mount_node(weapon, "sword_p", 0.8):
			var hand = _attach("R_Hand")
			# Hand bone: +Y runs along the fingers; the grip tilts the
			# blade forward and slightly up from the fist.
			weapon.position = Vector3(0.0, 0.05, 0.0)
			weapon.rotation_degrees = Vector3(-115, 0, 0)
			weapon.scale = Vector3.ONE * 0.8
			hand.add_child(weapon)
		_sword_node = weapon
	if opts.get("shield", false) and _mount_worn_model(opts.get("off_gear", "")):
		var off_fit = WORN_MODELS[opts.off_gear].fit
		_shield_arm = worn_mounts[off_fit].back().get_parent()
		_shield_prop = load(GEAR_FITS.shield_m.path).instantiate()
		_shield_prop.position = Vector3(0.42, 0.15, 0.24)
		_shield_prop.rotation_degrees = Vector3(0, 15, 75)
		_shield_prop.scale = Vector3.ONE * 0.36
		_shield_prop.visible = false
		add_child(_shield_prop)
		if WORN_MODELS.get(opts.get("off_gear", ""), {}).has("palette"):
			_recolor(_shield_prop, WORN_MODELS[opts.off_gear].palette)
	elif opts.get("shield", false):
		_shield_arm = _attach("L_Forearm")
		var shield = DelverBuilder.build_shield()
		shield.position = Vector3(0.0, 0.12, -0.05)
		shield.rotation_degrees = Vector3(90, -35, 0)
		shield.scale = Vector3.ONE * 0.8
		_shield_arm.add_child(shield)
		# At rest the shield comes off the arm and leans beside him.
		_shield_prop = DelverBuilder.build_shield()
		_shield_prop.position = Vector3(0.4, 0.0, 0.2)
		_shield_prop.rotation_degrees = Vector3(32, 60, 60)
		_shield_prop.scale = Vector3.ONE * 0.9
		_shield_prop.visible = false
		add_child(_shield_prop)

## Mounts a sculpted gear model on its bone, recolored by its palette.
## False = no model for this gear id (caller falls back to boxes).
func _mount_worn_model(gear_id: String) -> bool:
	if not WORN_MODELS.has(gear_id):
		return false
	var entry = WORN_MODELS[gear_id]
	var fit = fit_for(entry.fit)
	if not ResourceLoader.exists(fit.path):
		return false
	# Skinned garments wear the body's own skeleton: reparent their
	# meshes under it and they deform with him - sleeves follow arms.
	if fit.get("skinned", false):
		var garment = load(fit.path).instantiate()
		var found := []
		var stack := [garment]
		while not stack.is_empty():
			var node = stack.pop_back()
			if node is MeshInstance3D:
				found.append(node)
			stack.append_array(node.get_children())
		for mesh_inst in found:
			mesh_inst.get_parent().remove_child(mesh_inst)
			_skeleton.add_child(mesh_inst)
			mesh_inst.skeleton = NodePath("..")
			if not worn_mounts.has(entry.fit):
				worn_mounts[entry.fit] = []
			worn_mounts[entry.fit].append(mesh_inst)
			if entry.has("palette"):
				_recolor(mesh_inst, entry.palette)
		garment.queue_free()
		_hide_covered(fit)
		return not found.is_empty()

	# Socket mounting: the item's grip marker lands exactly on the
	# body's socket, so weapons pivot around the palm, not the wrist.
	# Sockets live on bones (grip_main, grip_off, back, hip_l...);
	# grips live on items - both placed visually in the Socket
	# Workshop (capture/socket_workshop.tscn) and saved to tuning.
	if tuning.get("grips", {}).has(entry.fit):
		var piece = load(fit.path).instantiate()
		if _socket_mount_node(piece, entry.fit, fit.get("scale", 1.0)):
			if not worn_mounts.has(entry.fit):
				worn_mounts[entry.fit] = []
			worn_mounts[entry.fit].append(piece)
			if entry.has("palette"):
				_recolor(piece, entry.palette)
			_hide_covered(fit)
			return true
		piece.queue_free()

	var bones = fit.get("pair_bones", [fit.get("bone", "")])
	var saved_pieces: Array = tuning.get("fits", {}).get(entry.fit, {}).get("pieces", [])
	for i in bones.size():
		var mount = _attach(bones[i])
		var piece = load(fit.path).instantiate()
		if i < saved_pieces.size():
			# Owner-fitted in the Fitting Room: applied verbatim, both
			# sides independent, negative/non-uniform scale preserved.
			var saved = saved_pieces[i]
			piece.position = _vec(saved.position)
			piece.rotation_degrees = _vec(saved.rotation)
			piece.scale = _vec(saved.scale)
		else:
			piece.position = fit.position
			piece.rotation_degrees = fit.rotation
			piece.scale = Vector3.ONE * fit.scale
			if i == 1 and fit.get("mirror", "reflect") == "reflect":
				# Chiral default: a right glove becomes a left one.
				piece.scale.x = -piece.scale.x
				piece.rotation_degrees.y = -piece.rotation_degrees.y
				piece.rotation_degrees.z = -piece.rotation_degrees.z
				piece.position.x = -piece.position.x
		if piece.scale.x < 0.0:
			_disable_cull(piece)
		piece.set_meta("mount_transform", piece.transform)
		mount.add_child(piece)
		if not worn_mounts.has(entry.fit):
			worn_mounts[entry.fit] = []
		worn_mounts[entry.fit].append(piece)
		if entry.has("palette"):
			_recolor(piece, entry.palette)
	_hide_covered(fit)
	if fit.get("world_rest", false):
		if is_inside_tree():
			_align_world_rest(entry.fit)
		else:
			_world_rest_pending.append(entry.fit)
	return true

## The registry fit, with any owner-saved override from the tuning
## file laid over it (the Guild Animator's Gear Fitter writes these).
## Mounts any prop by grip data: the prop's grip point lands on its
## body socket, oriented grip-to-socket - one math for worn models
## and built weapons alike. The basis carries the scale, so grip
## offsets stay in the prop's own coordinates.
func _socket_mount_node(node: Node3D, grip_key: String, default_scale := 1.0) -> bool:
	var grip = tuning.get("grips", {}).get(grip_key)
	if grip == null:
		return false
	var socket = tuning.get("sockets", {}).get(grip.socket)
	if socket == null:
		return false
	var mount = _attach(socket.bone)
	var socket_rot := Basis.from_euler(_vec(socket.rotation) * PI / 180.0)
	var grip_rot := Basis.from_euler(_vec(grip.rotation) * PI / 180.0)
	node.quaternion = (socket_rot * grip_rot.inverse()).get_rotation_quaternion()
	node.scale = Vector3.ONE * float(grip.get("scale", default_scale))
	node.position = _vec(socket.position) - node.basis * _vec(grip.position)
	node.set_meta("mount_transform", node.transform)
	mount.add_child(node)
	prop_mounts[grip_key] = node
	return true

func fit_for(fit_key: String) -> Dictionary:
	var fit = GEAR_FITS[fit_key].duplicate()
	# Garments are compiled per body: a "_f" sibling GLB (same spec,
	# female body) wins when this actor declared the variant.
	if garment_suffix != "":
		var variant_path: String = fit.path.replace(".glb", garment_suffix + ".glb")
		if ResourceLoader.exists(variant_path):
			fit.path = variant_path
	var saved = tuning.get("fits", {}).get(fit_key, {})
	if saved.has("position"):
		fit.position = _vec(saved.position)
	if saved.has("rotation"):
		fit.rotation = _vec(saved.rotation)
	if saved.has("scale"):
		fit.scale = float(saved.scale)
	return fit

func _disable_cull(piece: Node):
	var stack = [piece]
	while not stack.is_empty():
		var node = stack.pop_back()
		if node is MeshInstance3D:
			var base = node.get_active_material(0)
			if base is BaseMaterial3D:
				var mat = base.duplicate()
				mat.cull_mode = BaseMaterial3D.CULL_DISABLED
				node.material_override = mat
		stack.append_array(node.get_children())

## Swap the sculpt's palette: same model, different armor.
func _recolor(piece: Node, palette: Dictionary):
	var stack = [piece]
	while not stack.is_empty():
		var node = stack.pop_back()
		if node is MeshInstance3D and node.mesh:
			for si in node.mesh.get_surface_count():
				_recolor_surface(node, si, palette)
		stack.append_array(node.get_children())

## Per-surface dyeing. Engine-compiled garments carry solid two-tone
## materials (GarmentPrimary/GarmentSecondary) tinted directly - no
## texture, no classification noise. Textured sculpts keep the
## chroma-classifying recolor shader. Hardware (straps, clasps) keeps
## its leather and steel.
func _recolor_surface(node: MeshInstance3D, si: int, palette: Dictionary):
	var base = node.get_surface_override_material(si)
	if base == null:
		base = node.material_override
	if base == null:
		base = node.mesh.surface_get_material(si)
	if base is ShaderMaterial:
		base.set_shader_parameter("col_primary", palette.primary)
		base.set_shader_parameter("col_secondary", palette.secondary)
		base.set_shader_parameter("col_trim", palette.trim)
		base.set_shader_parameter("luma_flatten", palette.get("flatten", 0.0))
		return
	if not (base is StandardMaterial3D):
		return
	var mat_name := String(base.resource_name)
	if mat_name.begins_with("Garment"):
		var tinted: StandardMaterial3D = base.duplicate()
		tinted.albedo_color = palette.secondary \
			if mat_name.contains("Secondary") else palette.primary
		node.set_surface_override_material(si, tinted)
	elif base.albedo_texture:
		var mat := ShaderMaterial.new()
		mat.shader = load(RECOLOR_SHADER)
		mat.set_shader_parameter("base_tex", base.albedo_texture)
		mat.set_shader_parameter("col_primary", palette.primary)
		mat.set_shader_parameter("col_secondary", palette.secondary)
		mat.set_shader_parameter("col_trim", palette.trim)
		mat.set_shader_parameter("luma_flatten", palette.get("flatten", 0.0))
		node.set_surface_override_material(si, mat)

static func _vec(arr) -> Vector3:
	return Vector3(arr[0], arr[1], arr[2]) if arr is Array and arr.size() == 3 else Vector3.ZERO

func _flat(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.9
	return mat

func _find_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var found = _find_player(child)
		if found:
			return found
	return null

func clip_for(role: String) -> String:
	if _clips.has(role):
		return _clips[role]
	var fallback = FALLBACKS.get(role, "idle")
	return _clips.get(fallback, "")

## The deterministic heart: scrub the role's clip to a fraction of its
## length. Looping roles wrap; one-shots clamp just short of the end.
func _pose(role: String, fraction: float, looped := false):
	var clip_name = clip_for(role)
	if _player == null or clip_name == "":
		return
	if looped:
		fraction = fposmod(fraction, 1.0)
	else:
		fraction = clampf(fraction, 0.0, 0.999)
	var length: float = _player.get_animation(clip_name).length
	var from := 0.0
	var to: float = length
	if clip_ranges.has(role):
		from = clip_ranges[role][0]
		to = minf(clip_ranges[role][1], length)
	if _player.current_animation != clip_name:
		_player.play(clip_name)
	_player.seek(from + fraction * (to - from), true)
	_player.pause()
	_model.position = Vector3.ZERO
	_set_shield_grounded(false)
	if _sword_node:
		# Undo the campfire sit-grip override: back to how it mounted.
		_sword_node.transform = _sword_node.get_meta(
			"mount_transform", _sword_node.transform)
	# The captures carry the chin low; lift the gaze off the ground.
	_rotate_bone("Head", Vector3.RIGHT, 0.25)

# --- The rig contract ------------------------------------------------------

func pose_idle(t: float):
	var clip_name = clip_for("idle")
	if _player == null or clip_name == "":
		return
	_pose("idle", t / maxf(_player.get_animation(clip_name).length, 0.1), true)

func pose_walk(phase: float):
	_pose("walk", phase / (TAU * walk_cycle_scale), true)

## --- Authored bone poses ---------------------------------------------
## Baked clips cover locomotion; combat reads better authored. Base
## frame first (calm idle), then local-axis rotations on named bones -
## deterministic in t, contact exactly where the theater expects it.

func _set_shield_grounded(grounded: bool):
	if _shield_arm:
		_shield_arm.visible = not grounded
	if _shield_prop:
		_shield_prop.visible = grounded

func _bone_pose_base():
	_pose("idle", 0.0)

func _rotate_bone(bone: String, axis: Vector3, angle: float):
	if not _bones.has(bone):
		return
	var idx = _bones[bone]
	_skeleton.set_bone_pose_rotation(idx,
		_skeleton.get_bone_pose_rotation(idx) * Quaternion(axis.normalized(), angle))

## One-handed swing: raise overhead, cut down to a forward strike.
## Upper-arm local +X pitches the arm forward-up (probe-verified);
## contact lands at t=0.5, horizontal, matching the theater's beat.
func pose_swing(t: float):
	if _skeleton == null:
		_pose("swing", t)
		return
	_bone_pose_base()
	var wind = smoothstep(0.0, 0.4, t)
	var cut = smoothstep(0.4, 0.62, t)
	var settle = smoothstep(0.72, 1.0, t)
	var lift = (1.9 * wind - 1.6 * cut) * (1.0 - settle)
	var elbow = (0.9 * wind - 0.85 * cut) * (1.0 - settle)
	var twist = (0.35 * wind - 0.65 * cut) * (1.0 - settle)
	_rotate_bone("R_Upperarm", Vector3.RIGHT, lift)
	_rotate_bone("R_Upperarm", Vector3.BACK, (-0.4 * wind - 0.2 * cut) * (1.0 - settle))
	_rotate_bone("R_Forearm", Vector3.RIGHT, elbow)
	_rotate_bone("Spine01", Vector3.UP, twist)
	_rotate_bone("Spine02", Vector3.UP, twist * 0.6)
	_rotate_bone("Head", Vector3.UP, -twist * 0.8)

func pose_swing_off(t: float):
	pose_swing(t)

## Sitting at the fire: hips folded, calves tucked, hands on knees.
func pose_sit(t: float, stroke_scale := 1.0):
	if _skeleton == null:
		_pose("idle", t, true)
		return
	_bone_pose_base()
	var sway = 0.03 * sin(t * 0.9)
	for side in ["L", "R"]:
		_rotate_bone(side + "_Thigh", Vector3.RIGHT, 1.5)
		_rotate_bone(side + "_Calf", Vector3.RIGHT, -1.35)
		_rotate_bone(side + "_Upperarm", Vector3.RIGHT, 0.5)
		_rotate_bone(side + "_Forearm", Vector3.RIGHT, 0.4)
	_rotate_bone("Spine01", Vector3.RIGHT, 0.12 + sway)
	_rotate_bone("Head", Vector3.RIGHT, -0.08 - sway)
	var sit = tuning.get("sit", {})
	if _has_sword:
		# The blade rests across the lap; every number here is
		# owner-tuned in the Guild Animator and saved to the tuning
		# file. The off hand polishes in slow strokes.
		_rotate_bone("R_Forearm", Vector3.RIGHT, 0.55)
		_rotate_bone("R_Hand", Vector3.UP, -0.4)
		_rotate_bone("R_Hand", Vector3.RIGHT, -2.55)
		for bone in sit.get("joints", {}):
			var deg = sit.joints[bone]
			for axis in 3:
				if deg[axis] != 0:
					_rotate_bone(bone,
						[Vector3.RIGHT, Vector3.UP, Vector3.BACK][axis],
						deg_to_rad(deg[axis]))
		var stroke = sin(t * 2.6 * sit.get("stroke_speed", 1.0)) \
			* stroke_scale * sit.get("stroke_scale", 1.0)
		_rotate_bone("L_Upperarm", Vector3.RIGHT, 0.45 + 0.12 * stroke)
		_rotate_bone("L_Upperarm", Vector3.BACK, 0.35)
		_rotate_bone("L_Forearm", Vector3.RIGHT, 0.55 + 0.18 * stroke)
		if _sword_node:
			_sword_node.position = _vec(sit.get("grip_position", [0, 0.05, 0]))
			_sword_node.rotation_degrees = _vec(sit.get("grip_rotation", [-50, 0, -40]))
	if _shield_prop:
		_shield_prop.position = _vec(sit.get("shield_position", [0.4, 0, 0.2]))
		_shield_prop.rotation_degrees = _vec(sit.get("shield_tilt", [32, 70, 60]))
	_set_shield_grounded(true)
	_model.position = _vec(sit.get("seat_offset", [0, 0, 0])) + Vector3(0, -0.31, 0)

func pose_shoot(t: float, _target_dist := 2.2):
	_pose("shoot", t)

func pose_death(t: float):
	_pose("death", t)

func pose_spellcast(t: float):
	_pose("cast", t)

func pose_spin(t: float):
	_pose("spin", t, true)
