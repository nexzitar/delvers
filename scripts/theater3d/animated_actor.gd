class_name AnimatedActor
extends Node3D

const DelverBuilder = preload("res://scripts/theater3d/delver_builder.gd")

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

func _init(scene: PackedScene, opts := {}):
	var model = scene.instantiate()
	model.rotation.y = opts.get("facing_fix", facing_fix)
	if opts.has("model_scale"):
		model.scale = Vector3.ONE * opts.model_scale
	add_child(model)
	_model = model
	clip_ranges = opts.get("clip_ranges", {})
	walk_cycle_scale = opts.get("walk_cycle_scale", 1.0)
	_player = _find_player(model)
	_skeleton = _find_skeleton(model)
	if _skeleton:
		for i in _skeleton.get_bone_count():
			_bones[_skeleton.get_bone_name(i)] = i
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

	# Weapons: the same meshes the procedural rigs carry, gripped by
	# the hand bones. Blade along the hand's local axis, tuned by eye.
	if opts.get("sword", false) or opts.get("axe", false) or opts.get("dagger", false):
		var hand = _attach("R_Hand")
		var weapon = DelverBuilder.build_axe() if opts.get("axe", false) \
			else DelverBuilder.build_dagger() if opts.get("dagger", false) \
			else DelverBuilder.build_sword()
		# Hand bone: +Y runs along the fingers; the blade continues
		# past the fist.
		weapon.position = Vector3(0.0, 0.05, 0.0)
		weapon.scale = Vector3.ONE * 0.8
		hand.add_child(weapon)
	if opts.get("shield", false):
		var arm = _attach("L_Forearm")
		var shield = DelverBuilder.build_shield()
		shield.position = Vector3(0.0, 0.12, -0.05)
		shield.rotation_degrees = Vector3(90, 0, 0)
		shield.scale = Vector3.ONE * 0.8
		arm.add_child(shield)

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
	_model.position.y = 0.0

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
	var lift = (2.5 * wind - 2.1 * cut) * (1.0 - settle)
	var elbow = (0.9 * wind - 0.85 * cut) * (1.0 - settle)
	var twist = (0.35 * wind - 0.65 * cut) * (1.0 - settle)
	_rotate_bone("R_Upperarm", Vector3.RIGHT, lift)
	_rotate_bone("R_Upperarm", Vector3.BACK, -0.25 * cut * (1.0 - settle))
	_rotate_bone("R_Forearm", Vector3.RIGHT, elbow)
	_rotate_bone("Spine01", Vector3.UP, twist)
	_rotate_bone("Spine02", Vector3.UP, twist * 0.6)
	_rotate_bone("Head", Vector3.UP, -twist * 0.8)

func pose_swing_off(t: float):
	pose_swing(t)

## Sitting at the fire: hips folded, calves tucked, hands on knees.
func pose_sit(t: float):
	if _skeleton == null:
		_pose("idle", t, true)
		return
	_bone_pose_base()
	var sway = 0.03 * sin(t * 0.9)
	for side in ["L", "R"]:
		_rotate_bone(side + "_Thigh", Vector3.RIGHT, -1.5)
		_rotate_bone(side + "_Calf", Vector3.RIGHT, 1.35)
		_rotate_bone(side + "_Upperarm", Vector3.RIGHT, -0.5)
		_rotate_bone(side + "_Forearm", Vector3.RIGHT, -0.5)
	_rotate_bone("Spine01", Vector3.RIGHT, 0.12 + sway)
	_rotate_bone("Head", Vector3.RIGHT, -0.08 - sway)
	_model.position.y = -0.31

func pose_shoot(t: float, _target_dist := 2.2):
	_pose("shoot", t)

func pose_death(t: float):
	_pose("death", t)

func pose_spellcast(t: float):
	_pose("cast", t)

func pose_spin(t: float):
	_pose("spin", t, true)
