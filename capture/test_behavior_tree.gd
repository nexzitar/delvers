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

	# Doctrine complexity: nodes are counted, capacity is knowledge,
	# and an over-budget doctrine falls back to the tactic.
	var small_tree = [
		{"when": [{"cond": "healer_threatened"}], "target": "healer_attacker"},
		{"when": [], "target": "nearest"},
	]
	assert(BehaviorTree.node_count(small_tree) == 3, "rules + conditions count")
	var big_tree = []
	for i in 6:
		big_tree.append({"when": [{"cond": "enemy_count_gte", "n": i}],
			"target": "nearest"})
	assert(BehaviorTree.node_count(big_tree) == 12, "monster scripts measured")

	var roster = load("res://scripts/game/player_roster.gd").new()
	roster.autosave = false
	roster._build_heroes()
	roster._build_stash()
	assert(roster.doctrine_capacity() == 0, "a fresh guild plans nothing custom")
	roster.start_delve()
	roster.delve_doctrines = ["doctrine_capacity_2", "guard"]
	roster.bank_delve_loot()
	assert(roster.doctrine_capacity() == 0, "capacity waits for the Slate")
	assert(roster.known_tactics.has("guard"), "tactics route to tactics")
	roster.known_engineering.append("engineers_slate")
	assert(roster.doctrine_capacity() == 8, "the Slate opens; Doctrine II extends")
	roster.known_engineering = ["engineers_slate"]
	assert(roster.doctrine_capacity() == 4, "the Slate alone holds four marks")

	# Setup enforces the budget: within it, the custom tree fights;
	# over it, the pre-authored tactic holds the line.
	PlayerRoster.autosave = false
	PlayerRoster._build_heroes()
	PlayerRoster._build_stash()
	PlayerRoster.known_engineering = ["engineers_slate"]
	var scripted = load("res://resources/heroes/default_delver.tres").duplicate(true)
	scripted.custom_tree = small_tree
	var combat_ok = CombatState.new()
	combat_ok.setup_combat([scripted], [slime])
	assert(not combat_ok.heroes[0].behavior_tree.is_empty(),
		"three nodes fit in four")
	scripted.custom_tree = big_tree
	var combat_over = CombatState.new()
	combat_over.setup_combat([scripted], [slime])
	assert(combat_over.heroes[0].behavior_tree.is_empty(),
		"twelve nodes exceed four: the tactic holds")

	# Custom doctrine survives the save.
	roster.known_engineering = ["engineers_slate", "doctrine_capacity_2"]
	roster.heroes[0].custom_tree = small_tree
	var path := "user://test_doctrine_tree_save.json"
	RosterSave.save(roster, path)
	var restored = load("res://scripts/game/player_roster.gd").new()
	restored.autosave = false
	assert(RosterSave.load_into(restored, path), "save loads")
	assert(restored.doctrine_capacity() == 8, "capacity persists")
	assert(restored.has_tool("engineers_slate"), "the slate persists")
	assert(BehaviorTree.node_count(restored.heroes[0].custom_tree) == 3,
		"the doctrine survives written down")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	roster.free()
	restored.free()

	# Skirmisher's Step: the archer gives ground while melee closes.
	var kite_combat = CombatState.new()
	var archer_template = load("res://resources/heroes/default_delver.tres").duplicate(true)
	archer_template.equipped = {
		Equip.Position.MAIN_HAND: LootTable.materialize("starter_bow", 5, 1),
	}
	kite_combat.setup_combat([archer_template], [slime])
	var skirmisher = kite_combat.heroes[0]
	skirmisher.tactic = "skirmish"
	var wolf = kite_combat.enemies[0]
	wolf.position = skirmisher.position + Vector2(70, 0)
	wolf.target_id = skirmisher.entity_id
	assert(BehaviorTree.move_directive(kite_combat, skirmisher) == "kite",
		"the step is called")
	var gap_before = skirmisher.position.distance_to(wolf.position)
	for k in 8:
		kite_combat.tick_kite(skirmisher, 0.1)
	assert(skirmisher.position.distance_to(wolf.position) > gap_before,
		"ground given, range gained")
	assert(BehaviorTree.to_code(BehaviorTree.TACTIC_TREES.skirmish).contains("keep_distance()"),
		"movement reads as code")

	# The Annotations: blocks were always words.
	var code = BehaviorTree.to_code([
		{"when": [{"cond": "healer_threatened"}], "target": "healer_attacker"},
		{"when": [{"cond": "enemy_count_gte", "n": 4}], "cast": "thunderclap"},
		{"when": [], "target": "least_threat"},
	])
	assert("def doctrine(self):" in code, "it reads as a function")
	assert("if healer_threatened():" in code, "conditions read")
	assert("enemy_count() >= 4" in code, "parameters carry through")
	assert("cast(\"thunderclap\")" in code, "casts read")
	assert("return target(least_threat_enemy())" in code, "selectors read")
	assert("pass" in BehaviorTree.to_code([]), "empty doctrine reads too")

	# Engineering tools route to engineering knowledge on banking.
	var tool_roster = load("res://scripts/game/player_roster.gd").new()
	tool_roster.autosave = false
	tool_roster._build_heroes()
	tool_roster._build_stash()
	tool_roster.start_delve()
	tool_roster.delve_doctrines = ["engineers_slate"]
	tool_roster.bank_delve_loot()
	assert(tool_roster.has_tool("engineers_slate"), "the slate is kept")
	assert(not tool_roster.known_tactics.has("engineers_slate"),
		"tools are not tactics")
	tool_roster.free()

	print("PASS behavior tree")
	get_tree().quit()
