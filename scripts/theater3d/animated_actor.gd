class_name AnimatedActor
extends Node3D

const DelverBuilder = preload("res://scripts/theater3d/delver_builder.gd")
const SpringTailScene = preload("res://scripts/theater3d/spring_tail.gd")

## Wraps an imported character (glTF/GLB, e.g. TripoAI) so the theater
## drives it exactly like a procedural rig: the pose functions SEEK
## named clips rather than playing them - deterministic, replay-
## friendly scrubbing, the same shape as pose_walk(t) on DelverRig.
## Missing clips degrade gracefully (fall back role, then stillness).

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

func _init(scene: PackedScene, opts := {}):
	var model = scene.instantiate()
	model.rotation.y = opts.get("facing_fix", facing_fix)
	if opts.has("model_scale"):
		model.scale = Vector3.ONE * opts.model_scale
	add_child(model)
	_model = model
	clip_ranges = opts.get("clip_ranges", {})
	walk_cycle_scale = opts.get("walk_cycle_scale", 1.0)
	_has_sword = opts.get("sword", false)
	tuning = _load_tuning().duplicate(true)
	_player = _find_player(model)
	_skeleton = _find_skeleton(model)
	if _skeleton:
		for i in _skeleton.get_bone_count():
			_bones[_skeleton.get_bone_name(i)] = i
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
		var helm_mount = _attach("Head")
		var helm = DelverBuilder.build_helmet()
		helm.position = Vector3(0, 0.13, -0.01)
		helm.rotation_degrees = Vector3(0, 180, 0)
		helm.scale = Vector3.ONE * 0.78
		helm_mount.add_child(helm)
	if opts.has("shoulders"):
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
	if opts.has("belt_trim"):
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
	for pair in [["gauntlets", "Hand", Vector3(0, 0.02, 0), Vector3(0.075, 0.08, 0.09)],
			["bracers", "Forearm", Vector3(0, 0.1, 0), Vector3(0.07, 0.09, 0.075)],
			["greaves", "Calf", Vector3(0, 0.12, 0), Vector3(0.085, 0.13, 0.095)],
			["boots_gear", "Foot", Vector3(0, 0.03, -0.02), Vector3(0.085, 0.07, 0.16)]]:
		if not opts.has(pair[0]):
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
		var bow_mount = _attach("L_Hand")
		var bow = DelverBuilder.build_bow()
		bow.position = Vector3(0, 0.05, 0)
		bow.scale = Vector3.ONE * 0.9
		bow_mount.add_child(bow)

	# Weapons: the same meshes the procedural rigs carry, gripped by
	# the hand bones. Blade along the hand's local axis, tuned by eye.
	if opts.get("sword", false) or opts.get("axe", false) or opts.get("dagger", false):
		var hand = _attach("R_Hand")
		var weapon = DelverBuilder.build_axe() if opts.get("axe", false) \
			else DelverBuilder.build_dagger() if opts.get("dagger", false) \
			else DelverBuilder.build_sword()
		# Hand bone: +Y runs along the fingers; the grip tilts the
		# blade forward and slightly up from the fist.
		weapon.position = Vector3(0.0, 0.05, 0.0)
		weapon.rotation_degrees = Vector3(-115, 0, 0)
		weapon.scale = Vector3.ONE * 0.8
		hand.add_child(weapon)
		_sword_node = weapon
	if opts.get("shield", false):
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
		_sword_node.position = Vector3(0.0, 0.05, 0.0)
		_sword_node.rotation_degrees = Vector3(-115, 0, 0)
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
