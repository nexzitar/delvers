extends Node

## Theater feedback: status badges ride above heads while a status
## runs, and the new skill cues exist.

func _ready():
	PlayerRoster.autosave = false
	PlayerRoster._build_heroes()
	PlayerRoster._build_stash()
	PlayerRoster.start_delve()
	var theater = load("res://scenes/theater/battle_theater_3d.tscn").instantiate()
	add_child(theater)
	await get_tree().process_frame
	await get_tree().process_frame

	assert(theater.actors.size() > 0, "actors spawned")
	var actor_id = theater.actors.keys()[0]
	var state = theater.actors[actor_id]

	var buff = CombatEvent.new()
	buff.type = CombatEvent.EventType.BUFF_APPLIED
	buff.target_id = actor_id
	buff.status_id = "thunderclap_daze"
	theater._play_buff(buff)
	assert(state.badges.size() == 1, "daze badge appears")

	var poison = CombatEvent.new()
	poison.type = CombatEvent.EventType.BUFF_APPLIED
	poison.target_id = actor_id
	poison.status_id = "poison_virulent"
	theater._play_buff(poison)
	assert(state.badges.size() == 2, "badges stack side by side")

	var expired = CombatEvent.new()
	expired.type = CombatEvent.EventType.BUFF_EXPIRED
	expired.target_id = actor_id
	expired.status_id = "thunderclap_daze"
	theater._play_buff_expired(expired)
	assert(state.badges.size() == 1, "expired badge leaves")

	# Death sweeps the rest.
	var death = CombatEvent.new()
	death.type = CombatEvent.EventType.DEATH
	death.target_id = actor_id
	theater._play_death(death)
	assert(state.badges.is_empty(), "death clears badges")

	# New skill cues: spin pose on delver rigs, shockwave spawns clean.
	var rig = load("res://scripts/theater3d/delver_rig.gd").new({"sword": true})
	assert(rig.has_method("pose_spin"), "spin pose exists")
	rig.pose_spin(0.3)
	rig.free()
	theater._spawn_shockwave(Vector3.ZERO)

	print("PASS theater fx")
	get_tree().quit()
