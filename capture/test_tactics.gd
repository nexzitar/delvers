extends Node

## Tactics v1: per-hero targeting directives, the party focus order,
## and knowledge pity. The data layer the future block/script AI
## interfaces will compile down to.

func _ready():
	var delver = load("res://resources/heroes/default_delver.tres").duplicate(true)
	var spider = load("res://resources/enemies/venomous_spider.tres")
	var warrior = load("res://resources/enemies/goblin_warrior.tres")

	# Focus order: spiders die first even when the warrior stands closer.
	var combat = CombatState.new()
	combat.enemy_priority = ["venomous_spider", "goblin_warrior"]
	combat.setup_combat([delver], [warrior, spider])
	var hero = combat.heroes[0]
	var near_warrior = combat.enemies[0]
	var far_spider = combat.enemies[1]
	near_warrior.position = hero.position + Vector2(60, 0)
	far_spider.position = hero.position + Vector2(300, 0)

	hero.tactic = "priority"
	combat.validate_target(hero)
	assert(hero.target_id == far_spider.entity_id, "focus order beats distance")

	# Lowest health: swaps to the wounded on the retarget cadence.
	hero.tactic = "lowest"
	near_warrior.current_health = 5
	combat.combat_time += 1.0
	combat.validate_target(hero)
	assert(hero.target_id == near_warrior.entity_id, "finishes the wounded")

	# Nearest stays sticky: no swap while the target lives.
	hero.tactic = "nearest"
	combat.combat_time += 1.0
	combat.validate_target(hero)
	assert(hero.target_id == near_warrior.entity_id, "nearest is sticky")

	# Spread: once the current target carries this hero's poison, move on.
	hero.tactic = "spread"
	combat.apply_status(far_spider, StatusEffect.Kind.POISON, 6.0, 1.5,
		"poison_virulent", hero.entity_id)
	combat.combat_time += 1.0
	combat.validate_target(hero)
	assert(hero.target_id == near_warrior.entity_id, "venom spreads to the uncovered")
	combat.apply_status(near_warrior, StatusEffect.Kind.POISON, 6.0, 1.5,
		"poison_virulent", hero.entity_id)
	combat.combat_time += 1.0
	combat.validate_target(hero)
	assert(combat.enemy_priority[0] == "venomous_spider", "sanity")
	assert(hero.target_id == far_spider.entity_id,
		"all covered: falls back to focus order")

	# Tactic and focus order survive a save round trip.
	var roster = load("res://scripts/game/player_roster.gd").new()
	roster.autosave = false
	roster._build_heroes()
	roster._build_stash()
	roster.set_tactic(0, "spread")
	roster.enemy_priority = ["venomous_spider", "goblin_archer"]
	roster.rooms_since_knowledge = 2
	var path := "user://test_tactics_save.json"
	RosterSave.save(roster, path)
	var restored = load("res://scripts/game/player_roster.gd").new()
	restored.autosave = false
	assert(RosterSave.load_into(restored, path), "save loads")
	assert(restored.heroes[0].tactic == "spread", "tactic persists")
	assert(restored.enemy_priority == ["venomous_spider", "goblin_archer"],
		"focus order persists")
	assert(restored.rooms_since_knowledge == 2, "pity counter persists")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

	# Tactics feed combat setup from the template.
	var combat2 = CombatState.new()
	combat2.setup_combat([restored.heroes[0]], [spider])
	assert(combat2.heroes[0].tactic == "spread", "tactic reaches the sim")

	# A tactic-driven battle still completes.
	var combat3 = CombatState.new()
	combat3.enemy_priority = ["venomous_spider"]
	var fighter = delver.duplicate(true)
	fighter.tactic = "priority"
	combat3.setup_combat([fighter], [warrior, spider, spider])
	var steps := 0
	while not combat3.combat_over and steps < 3000:
		combat3.update(0.1)
		steps += 1
	assert(combat3.combat_over, "priority battle completes")

	roster.free()
	restored.free()
	print("PASS tactics")
	get_tree().quit()
