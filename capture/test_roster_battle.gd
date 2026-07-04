extends Node

## Stress: the real PlayerRoster party against many random encounter
## rolls — every battle must terminate.

const GREEN_SLIME = preload("res://resources/enemies/green_slime.tres")
const GOBLIN_ARCHER = preload("res://resources/enemies/goblin_archer.tres")

func _ready():
	var roster = load("res://scripts/game/player_roster.gd").new()
	add_child(roster)

	for trial in 12:
		var encounter = []
		for i in randi_range(2, 4):
			encounter.append([GREEN_SLIME, GREEN_SLIME, GOBLIN_ARCHER].pick_random())

		var combat = CombatState.new()
		combat.setup_combat(roster.heroes, encounter)
		var steps := 0
		while not combat.combat_over and steps < 3000:
			combat.update(0.1)
			steps += 1
		if steps >= 3000:
			var names = encounter.map(func(t): return t.enemy_id)
			print("FAIL stalled on trial %d vs %s" % [trial, names])
			get_tree().quit()
			return

	# A slime dying at the hero's feet must not block the way to the
	# goblin archer standing behind it.
	var delver = load("res://resources/heroes/default_delver.tres").duplicate(true)
	delver.equipped = {
		Equip.Position.MAIN_HAND: load("res://resources/gear/starter_sword.tres")
	}
	var skills: Array[SkillDefinition] = [
		load("res://resources/skills/auto_attack.tres")
	]
	delver.starting_skills = skills
	var combat2 = CombatState.new()
	combat2.setup_combat([delver], [GREEN_SLIME, GOBLIN_ARCHER])
	var hero = combat2.heroes[0]
	combat2.enemies[0].position = hero.position + Vector2(40, 0)
	combat2.enemies[1].position = hero.position + Vector2(300, 0)
	var steps2 := 0
	while not combat2.combat_over and steps2 < 3000:
		combat2.update(0.1)
		steps2 += 1
	assert(steps2 < 3000, "corpse fight finishes")
	var goblin_id = combat2.enemies[1].entity_id
	assert(
		combat2.combat_log.events.any(
			func(e): return e.type == CombatEvent.EventType.DAMAGE \
				and e.target_id == goblin_id and e.source_id == hero.entity_id
		),
		"hero reached the goblin past the corpse"
	)

	print("PASS roster battles all finished")
	get_tree().quit()
