extends Node

## The shared behaviour engine: built-in tactics are pre-authored
## trees, custom trees gate skills and compose conditions - the shape
## Scratch and the Engineer's Python will write.

func _ready():
	var delver = load("res://resources/heroes/default_delver.tres").duplicate(true)
	var healer_template = load("res://resources/heroes/default_delver.tres").duplicate(true)
	var heal_kit: Array[SkillDefinition] = [load("res://resources/skills/heal.tres")]
	healer_template.bonus_skills = heal_kit
	var slime = load("res://resources/enemies/green_slime.tres")

	var combat = CombatState.new()
	combat.setup_combat([delver, healer_template], [slime, slime])
	var tank = combat.heroes[0]
	var healer = combat.heroes[1]
	var near_foe = combat.enemies[0]
	var far_foe = combat.enemies[1]
	near_foe.position = tank.position + Vector2(40, 0)
	far_foe.position = tank.position + Vector2(300, 40)

	# Protect the Healer: idle foes -> nearest; the moment one hunts
	# the mender, it becomes the mark.
	tank.tactic = "protect"
	assert(BehaviorTree.pick_target(combat, tank) == near_foe.entity_id,
		"quiet field: nearest")
	far_foe.target_id = healer.entity_id
	assert(BehaviorTree.pick_target(combat, tank) == far_foe.entity_id,
		"the hunt is hunted")

	# Custom tree: casting gated on crowd size ("IF enemy count >= 4
	# THEN Thunderclap"), targeting untouched.
	tank.behavior_tree = [
		{"when": [{"cond": "enemy_count_gte", "n": 4}], "cast": "thunderclap"},
		{"when": [], "target": "nearest"},
	]
	assert(not BehaviorTree.allows_cast(combat, tank, "thunderclap"),
		"two foes: the clap waits")
	assert(BehaviorTree.allows_cast(combat, tank, "shield_wall"),
		"unreferenced skills keep their own triggers")
	var combat_crowd = CombatState.new()
	combat_crowd.setup_combat([delver], [slime, slime, slime, slime])
	var crowded = combat_crowd.heroes[0]
	crowded.behavior_tree = tank.behavior_tree
	assert(BehaviorTree.allows_cast(combat_crowd, crowded, "thunderclap"),
		"four foes: the clap is allowed")

	# Conditions compose and serialize: a tree survives JSON.
	assert(BehaviorTree.check(combat, tank, {"cond": "health_below", "pct": 1.1}),
		"health condition reads")
	assert(BehaviorTree.check(combat, tank, {"cond": "enemies_within", "range": 90.0, "n": 1}),
		"proximity condition reads")
	var json = JSON.stringify(tank.behavior_tree)
	var back = JSON.parse_string(json)
	assert(back is Array and back[0].cast == "thunderclap", "trees are data")

	# Every built-in tactic resolves through the engine.
	for tactic in ["nearest", "lowest", "priority", "spread", "guard", "protect"]:
		tank.behavior_tree = []
		tank.tactic = tactic
		assert(BehaviorTree.pick_target(combat, tank) != -1,
			tactic + " resolves")

	print("PASS behavior tree")
	get_tree().quit()
