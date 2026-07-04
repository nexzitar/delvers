extends Node

## Ranged attacks wind up standing still: CAST_START precedes the
## arrow's DAMAGE by the wind-up, with no archer movement in between.

func _ready():
	var bow = load("res://resources/gear/starter_bow.tres")
	var arrow_shot = load("res://resources/skills/arrow_shot.tres")

	var archer_t = load("res://resources/heroes/default_delver.tres").duplicate(true)
	archer_t.equipped = {Equip.Position.MAIN_HAND: bow}
	var skills_arr: Array[SkillDefinition] = [arrow_shot]
	archer_t.starting_skills = skills_arr

	var slime_t = load("res://resources/enemies/green_slime.tres")

	var combat = CombatState.new()
	combat.setup_combat([archer_t], [slime_t])
	var archer_id = combat.heroes[0].entity_id

	var steps := 0
	while combat.combat_log.events.all(
		func(e): return (
			e.type != CombatEvent.EventType.DAMAGE
			or e.source_id != archer_id
		)
	):
		combat.update(0.1)
		steps += 1
		assert(steps < 600, "combat progresses")

	var cast_start_t := -1.0
	var damage_t := -1.0
	var has_finish := false
	for e in combat.combat_log.events:
		if e.type == CombatEvent.EventType.CAST_START \
				and e.source_id == archer_id and cast_start_t < 0.0:
			cast_start_t = e.time
		if e.type == CombatEvent.EventType.CAST_FINISH and e.source_id == archer_id:
			has_finish = true
		if e.type == CombatEvent.EventType.DAMAGE \
				and e.source_id == archer_id and damage_t < 0.0:
			damage_t = e.time

	assert(cast_start_t >= 0.0, "cast started")
	assert(has_finish, "cast finished")
	assert(damage_t >= cast_start_t + 0.29, "wind-up before the arrow")

	for e in combat.combat_log.events:
		if e.type == CombatEvent.EventType.MOVE and e.entity_id == archer_id:
			assert(
				e.time <= cast_start_t + 0.001 or e.time >= damage_t,
				"stationary while casting"
			)

	print("PASS stationary cast")
	get_tree().quit()
