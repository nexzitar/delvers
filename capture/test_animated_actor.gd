extends Node

## The imported-model landing zone: an AnimationPlayer scene speaks
## the same pose contract as the procedural rigs, deterministically.

func _build_model() -> PackedScene:
	var root := Node3D.new()
	root.name = "TripoDelver"
	var cube := MeshInstance3D.new()
	cube.name = "Body"
	cube.mesh = BoxMesh.new()
	root.add_child(cube)
	cube.owner = root
	var player := AnimationPlayer.new()
	player.name = "AnimationPlayer"
	root.add_child(player)
	player.owner = root
	var lib := AnimationLibrary.new()
	for clip in [["Walking_loop", 1.0], ["Sword_Attack", 0.8], ["Idle_breathing", 2.0], ["Death_backward", 1.2]]:
		var anim := Animation.new()
		anim.length = clip[1]
		var track = anim.add_track(Animation.TYPE_POSITION_3D)
		anim.track_set_path(track, "Body")
		anim.position_track_insert_key(track, 0.0, Vector3.ZERO)
		anim.position_track_insert_key(track, clip[1], Vector3(0, clip[1], 0))
		lib.add_animation(clip[0], anim)
	player.add_animation_library("", lib)
	var packed := PackedScene.new()
	packed.pack(root)
	return packed

func _ready():
	await _run_all()

func _run_all():
	var model = _build_model()

	# Clip discovery by name fragments.
	var actor = AnimatedActor.new(model)
	add_child(actor)
	assert(actor.clip_for("walk") == "Walking_loop", "walk found")
	assert(actor.clip_for("swing") == "Sword_Attack", "attack found")
	assert(actor.clip_for("death") == "Death_backward", "death found")
	assert(actor.clip_for("shoot") == "Sword_Attack", "missing roles borrow")

	# Deterministic scrubbing: same t, same transform - replay-safe.
	# The theater's walk phase is radians: TAU spans one clip cycle.
	var body = actor.get_child(0).get_node("Body")
	actor.pose_walk(TAU * 0.5)
	var at_half = body.position
	actor.pose_walk(TAU * 0.9)
	actor.pose_walk(TAU * 0.5)
	assert(body.position.is_equal_approx(at_half), "the scrub is deterministic")
	assert(absf(at_half.y - 0.5) < 0.01, "half a cycle is half the clip")
	actor.pose_walk(TAU * 1.25)
	assert(absf(body.position.y - 0.25) < 0.01, "cycles wrap")
	actor.pose_death(5.0)
	assert(absf(body.position.y - 1.2) < 0.05, "one-shots clamp at the end")

	# The sim carries the model path through the event log.
	var template = load("res://resources/heroes/default_delver.tres").duplicate(true)
	template.model_scene = model
	var combat = CombatState.new()
	combat.setup_combat([template], [load("res://resources/enemies/green_slime.tres")])
	var spawn_path := ""
	for event in combat.combat_log.events:
		if event.type == CombatEvent.EventType.SPAWN and event.team == CombatEntity.Team.HERO:
			spawn_path = event.model_path
	assert(spawn_path == "", "unsaved scene carries no path (procedural fallback)")

	# The factory: no model -> procedural rig, as ever.
	var spawn = combat.combat_log.events.filter(func(e):
		return e.type == CombatEvent.EventType.SPAWN and e.team == CombatEntity.Team.HERO)[0]
	var rig = ActorFactory3D.build_from_spawn(spawn)
	assert(rig.has_method("pose_walk") and not (rig is AnimatedActor), "procedural fallback holds")
	rig.free()

	# Explicit clip maps override discovery (Tripo loses clip names).
	var mapped = AnimatedActor.new(model, {"clip_map": {"death": "Walking_loop"}})
	add_child(mapped)
	assert(mapped.clip_for("death") == "Walking_loop", "the map outranks the name")
	# The real GLB: config resolves, clips land, eyes and sword mount.
	var config = ActorFactory3D.MODEL_CONFIGS["res://resources/models/delver_male.glb"].duplicate(true)
	config.merge({"sword": true, "shield": true}, true)
	var tripo = AnimatedActor.new(load("res://resources/models/delver_male.glb"), config)
	add_child(tripo)
	assert(tripo.clip_for("walk") == "NlaTrack_004", "the walk is found")
	assert(tripo.clip_for("swing") == "NlaTrack_003", "the chop swings")
	assert(tripo._skeleton != null, "the skeleton is found")
	var mounts := 0
	for child in tripo._skeleton.get_children():
		if child is BoneAttachment3D:
			mounts += 1
	assert(mounts == 3, "eyes, sword, shield ride the bones")
	tripo.pose_walk(0.5)
	tripo.pose_swing(0.3)
	tripo.pose_sit(1.0)
	tripo.pose_swing(0.5)
	# Clip ranges: the idle scrubs inside its calm window only.
	assert(tripo.clip_ranges.has("idle"), "the idle is sliced")

	# The animation donor: a bare rigged export borrows the male's
	# clips, retargeted by bone name.
	var config_f = ActorFactory3D.MODEL_CONFIGS["res://resources/models/delver_female.glb"].duplicate(true)
	var wren = AnimatedActor.new(load("res://resources/models/delver_female.glb"), config_f)
	add_child(wren)
	assert(wren._player != null, "the donor's clips arrive")
	assert(wren.clip_for("walk") == "NlaTrack_004", "the borrowed walk is found")
	wren.pose_walk(1.0)
	wren.pose_sit(1.0)
	wren.pose_swing(0.5)

	# Companions carry their bodies, and the body survives the save.
	var roster = load("res://scripts/game/player_roster.gd").new()
	roster.autosave = false
	roster._build_heroes()
	roster._build_stash()
	roster.purchased_unlocks = []
	roster.adventures_completed = 1
	roster.check_milestones()
	assert(roster.heroes.size() == 2, "Wren arrives")
	assert(roster.heroes[1].model_scene != null
		and roster.heroes[1].model_scene.resource_path.contains("female"),
		"Wren wears her own body")
	var path := "user://test_model_save.json"
	RosterSave.save(roster, path)
	var restored = load("res://scripts/game/player_roster.gd").new()
	restored.autosave = false
	assert(RosterSave.load_into(restored, path), "save loads")
	assert(restored.heroes[1].model_scene.resource_path.contains("female"),
		"the body persists")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	roster.free()
	restored.free()

	# Spring hair: the tail trails the moving head and settles under
	# gravity - never glued to the skull.
	var tail = load("res://scripts/theater3d/spring_tail.gd").new()
	add_child(tail)
	await get_tree().process_frame
	tail.global_position = Vector3.ZERO
	tail.simulate(0.016)
	for k in 20:
		tail.global_position.x += 0.05
		tail.simulate(0.016)
	var tip = tail._points[tail._points.size() - 1]
	assert(tip.x < tail.global_position.x - 0.05, "the tail trails the motion")
	for k in 120:
		tail.simulate(0.016)
	tip = tail._points[tail._points.size() - 1]
	assert(tip.y < tail.global_position.y, "gravity wins at rest")
	assert(absf(tip.x - tail.global_position.x) < 0.2, "the swing settles")
	tail.free()

	# The Fitting Room round trip: a saved fit survives a rebuild
	# exactly - position, rotation, scale, even on the sword (whose
	# grip every pose restores).
	var room_config = ActorFactory3D.MODEL_CONFIGS["res://resources/models/delver_male.glb"].duplicate(true)
	room_config.merge({"sword": true, "main_gear": "starter_sword",
		"helmet": true, "helmet_gear": "starter_helmet"}, true)
	var fitted = AnimatedActor.new(load("res://resources/models/delver_male.glb"), room_config)
	add_child(fitted)
	fitted.tuning["fits"] = {
		"sword_m": {"position": [0.01, 0.07, -0.02], "rotation": [-70, 12, -5], "scale": 0.44},
		"helm": {"position": [0, 0.09, -0.02], "rotation": [3, 180, 0], "scale": 0.26},
	}
	# Re-dress from tuning (what rebuild does) and pose (what reverted the sword).
	var fresh = AnimatedActor.new(load("res://resources/models/delver_male.glb"), room_config)
	fresh.tuning = fitted.tuning.duplicate(true)
	add_child(fresh)
	fresh.worn_mounts.clear()
	fresh._mount_worn_model("starter_sword")
	fresh.pose_idle(0.0)
	var sword_piece = fresh.worn_mounts["sword_m"][0]
	assert(sword_piece.rotation_degrees.is_equal_approx(Vector3(-70, 12, -5)),
		"the sword keeps the owner's grip through a pose")
	assert(absf(sword_piece.scale.x - 0.44) < 0.001, "the scale holds")

	print("PASS animated actor")
	get_tree().quit()
