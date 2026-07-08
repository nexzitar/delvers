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

var _player: AnimationPlayer
var _skeleton: Skeleton3D
var _clips := {}

func _init(scene: PackedScene, opts := {}):
	var model = scene.instantiate()
	model.rotation.y = opts.get("facing_fix", facing_fix)
	if opts.has("model_scale"):
		model.scale = Vector3.ONE * opts.model_scale
	add_child(model)
	_player = _find_player(model)
	_skeleton = _find_skeleton(model)
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
	if _player.current_animation != clip_name:
		_player.play(clip_name)
	_player.seek(fraction * _player.get_animation(clip_name).length, true)
	_player.pause()

# --- The rig contract ------------------------------------------------------

func pose_idle(t: float):
	var clip_name = clip_for("idle")
	if _player == null or clip_name == "":
		return
	_pose("idle", t / maxf(_player.get_animation(clip_name).length, 0.1), true)

func pose_walk(phase: float):
	_pose("walk", phase, true)

func pose_swing(t: float):
	_pose("swing", t)

func pose_swing_off(t: float):
	_pose("swing", t)

func pose_shoot(t: float, _target_dist := 2.2):
	_pose("shoot", t)

func pose_death(t: float):
	_pose("death", t)

func pose_spellcast(t: float):
	_pose("cast", t)

func pose_spin(t: float):
	_pose("spin", t, true)
