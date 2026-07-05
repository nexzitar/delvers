extends Node

## Affix recipes: learnable enchantments applied at craft time, with
## real on-hit effects in the sim.

func _ready():
	# Registry sanity: ids match, costs and icons exist.
	for affix_id in RosterSave.AFFIX_PATHS:
		var affix = load(RosterSave.AFFIX_PATHS[affix_id])
		assert(affix.affix_id == affix_id, "affix id matches")
		assert(affix.icon != null, "affix has an icon")
		for material_id in affix.costs:
			assert(RosterSave.MATERIAL_PATHS.has(material_id), "affix costs exist")

	# Materialize: prefix, stat shaping, determinism.
	var plain = LootTable.materialize("starter_sword", 4, ItemQuality.Tier.UNCOMMON)
	var flaming = LootTable.materialize(
		"starter_sword", 4, ItemQuality.Tier.UNCOMMON, "flaming"
	)
	assert(flaming.gear_name.begins_with("Flaming "), "affix prefixes the name")
	assert(flaming.affix_id == "flaming", "affix baked in")
	assert(flaming.damage_max > plain.damage_max, "flaming boosts damage")
	var quick = LootTable.materialize("starter_bow", 4, ItemQuality.Tier.COMMON, "quick")
	assert(quick.attack_speed < 2.8, "quick speeds the swing")
	var guarding = LootTable.materialize(
		"starter_shield", 4, ItemQuality.Tier.COMMON, "guarding"
	)
	assert(guarding.health_bonus > 12, "guarding adds health")

	# Crafting with affixes: knowledge and combined costs both gate.
	var roster = load("res://scripts/game/player_roster.gd").new()
	roster.autosave = false
	roster._build_heroes()
	roster._build_stash()
	var sword_recipe = load("res://resources/recipes/iron_sword.tres")
	roster.material_stash = {"iron_scrap": 9, "gel": 9, "poison_sac": 2}
	assert(not roster.can_craft(sword_recipe, "virulent"), "unknown affix rejected")
	roster.known_affixes = ["virulent", "guarding"]
	assert(roster.compatible_affixes(sword_recipe) == ["virulent"],
		"guarding doesn't fit a sword")
	assert(roster.can_craft(sword_recipe, "virulent"), "known affix crafts")
	var venom_blade = roster.craft(sword_recipe, "virulent")
	assert(venom_blade != null, "craft succeeds")
	assert(venom_blade.gear_name == "Virulent Iron Sword", "named for the craft")
	assert(venom_blade.affix_id == "virulent", "affix on the blade")
	assert(not roster.material_stash.has("poison_sac"), "affix costs consumed")

	# Save round trip: affix, name, and knowledge all survive.
	var path := "user://test_affix_save.json"
	assert(roster.equip_gear(0, venom_blade, Equip.Position.MAIN_HAND) \
		or roster.gear_stash.has(venom_blade), "blade somewhere")
	RosterSave.save(roster, path)
	var restored = load("res://scripts/game/player_roster.gd").new()
	assert(RosterSave.load_into(restored, path), "save loads")
	assert(restored.known_affixes.has("virulent"), "affix knowledge persists")
	var found = null
	for hero in restored.heroes:
		for pos in hero.equipped:
			if hero.equipped[pos].affix_id == "virulent":
				found = hero.equipped[pos]
	for gear in restored.gear_stash:
		if gear.affix_id == "virulent":
			found = gear
	assert(found != null, "affixed blade persists")
	assert(found.gear_name == "Virulent Iron Sword", "crafted name persists")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

	# Sim: a virulent blade poisons on hit, the poison ticks damage
	# attributed to the attacker, and frostforged chills.
	var delver = load("res://resources/heroes/default_delver.tres").duplicate(true)
	delver.equipped = {Equip.Position.MAIN_HAND: LootTable.materialize(
		"starter_sword", 4, ItemQuality.Tier.COMMON, "virulent"
	)}
	var skills: Array[SkillDefinition] = [
		load("res://resources/skills/auto_attack.tres")
	]
	delver.starting_skills = skills
	var combat = CombatState.new()
	combat.setup_combat([delver], [load("res://resources/enemies/green_slime.tres")])
	var hero = combat.heroes[0]
	var slime = combat.enemies[0]
	slime.position = hero.position + Vector2(40, 0)
	hero.perform_auto_attack(combat, slime)
	assert(
		slime.statuses.any(func(s): return s.kind == StatusEffect.Kind.POISON),
		"hit poisons"
	)
	var hp_after_hit = slime.current_health
	for i in 30:
		slime.tick_statuses(0.1, combat)
	assert(slime.current_health < hp_after_hit, "poison ticks damage")
	var dot_events = combat.combat_log.events.filter(
		func(e): return e.type == CombatEvent.EventType.DAMAGE and e.dot
	)
	assert(not dot_events.is_empty(), "dot damage logged")
	assert(dot_events[0].source_id == hero.entity_id, "poison attributed")

	# Re-hitting refreshes rather than stacks.
	hero.perform_auto_attack(combat, slime)
	hero.perform_auto_attack(combat, slime)
	var poison_count = slime.statuses.filter(
		func(s): return s.kind == StatusEffect.Kind.POISON
	).size()
	assert(poison_count == 1, "poison refreshes, not stacks")

	# Frostforged chills.
	hero.main_weapon = LootTable.materialize(
		"starter_sword", 4, ItemQuality.Tier.COMMON, "frostforged"
	)
	var slime2 = CombatEntity.new()
	slime2.entity_id = 99
	slime2.team = CombatEntity.Team.ENEMY
	slime2.current_health = 30
	slime2.max_health = 30
	combat.entities_by_id[99] = slime2
	combat.apply_on_hit(hero, hero.main_weapon, slime2)
	assert(slime2.move_speed_multiplier() < 1.0, "frostforged chills")

	# Drops: goblins teach virulent/quick; known affixes never re-drop.
	var teacher = load("res://resources/enemies/goblin_archer.tres").duplicate()
	teacher.affix_drop_chance = 1.0
	var learned = LootTable.roll_enemy_drops([teacher], 3)
	assert(learned.affixes.size() == 1, "affix drops")
	assert(teacher.affix_loot.has(learned.affixes[0]), "affix from own pool")
	var all_known = LootTable.roll_enemy_drops(
		[teacher], 3, [], teacher.affix_loot.duplicate()
	)
	assert(all_known.affixes.is_empty(), "known affixes don't re-drop")

	roster.free()
	restored.free()
	print("PASS affixes")
	get_tree().quit()
