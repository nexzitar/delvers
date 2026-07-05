extends Node

## Secondary stats (armor/block/dodge/crit/spell power), the reworked
## mana-cast Heal, and knowledge provenance.

const Heal = preload("res://scripts/combat/skills/heal.gd")

func _ready():
	# Every piece of knowledge has provenance.
	for recipe_id in RosterSave.RECIPE_PATHS:
		assert(load(RosterSave.RECIPE_PATHS[recipe_id]).tome_name != "",
			"recipe has a tome")
	for affix_id in RosterSave.AFFIX_PATHS:
		assert(load(RosterSave.AFFIX_PATHS[affix_id]).tome_name != "",
			"affix has a tome")

	# Material owners point at the right hunt.
	assert(LootTable.material_owner("iron_scrap") == "Goblin Warrior", "iron owner")
	assert(LootTable.material_owner("poison_sac") == "Venomous Spider", "poison owner")
	assert(LootTable.material_owner("gel") == "Green Slime", "gel owner")
	assert(LootTable.material_owner("royal_jelly") == "Slime King", "jelly owner")

	# Hero stats aggregate from the loadout; shield makes a tank.
	var delver = load("res://resources/heroes/default_delver.tres").duplicate(true)
	delver.equipped = {
		Equip.Position.MAIN_HAND: LootTable.materialize("starter_sword", 1, 0),
		Equip.Position.OFF_HAND: LootTable.materialize("starter_shield", 1, 0),
		Equip.Position.HEAD: LootTable.materialize("starter_helmet", 1, 0),
	}
	var combat = CombatState.new()
	combat.setup_combat([delver], [load("res://resources/enemies/green_slime.tres")])
	var hero = combat.heroes[0]
	var slime = combat.enemies[0]
	assert(hero.armor == 3, "armor sums (shield 2 + helm 1)")
	assert(hero.block_chance > 0.1, "shield grants block")
	assert(hero.max_mana == 10, "max mana set")

	# Armor shaves flat damage: a 5-damage strike lands as 2.
	slime.position = hero.position + Vector2(40, 0)
	hero.crit_chance = 0.0
	slime.attack_power = 5
	var hp_before = hero.current_health
	slime.skills[0] = slime.skills[0].duplicate()
	slime.skills[0].base_min_damage = 0
	slime.skills[0].base_max_damage = 0
	hero.block_chance = 0.0
	hero.dodge_chance = 0.0
	slime._strike(combat, slime.skills[0], hero, 5)
	assert(hp_before - hero.current_health == 2, "armor shaves 3")

	# Guaranteed dodge: no damage, flagged event, no poison rider.
	hero.dodge_chance = 1.0
	hp_before = hero.current_health
	slime._strike(combat, slime.skills[0], hero, 5)
	assert(hero.current_health == hp_before, "dodge avoids all damage")
	var last = combat.combat_log.events[-1]
	assert(last.dodged and last.amount == 0, "dodge flagged")

	# Guaranteed block: half then armor.
	hero.dodge_chance = 0.0
	hero.block_chance = 1.0
	hp_before = hero.current_health
	slime._strike(combat, slime.skills[0], hero, 8)
	assert(hp_before - hero.current_health == 1, "block halves (4) then armor (-3)")
	assert(combat.combat_log.events[-1].blocked, "block flagged")

	# Guaranteed crit: 150%, flagged.
	hero.block_chance = 0.0
	hero.armor = 0
	slime.crit_chance = 1.0
	hp_before = hero.current_health
	slime._strike(combat, slime.skills[0], hero, 10)
	assert(hp_before - hero.current_health == 15, "crit multiplies 1.5x")
	assert(combat.combat_log.events[-1].crit, "crit flagged")

	# Poison ignores armor entirely.
	hero.armor = 99
	combat.apply_status(hero, StatusEffect.Kind.POISON, 3.0, 2.0, "test_poison", slime.entity_id)
	hp_before = hero.current_health
	for i in 15:
		hero.tick_statuses(0.1, combat)
	assert(hp_before - hero.current_health >= 2, "poison bypasses armor")
	hero.statuses = []
	hero.armor = 0

	# Heal: a mana-gated cast, not a cooldown.
	var healskill = load("res://resources/skills/heal.tres")
	assert(healskill.cooldown == 0.0 and healskill.mana_cost == 4, "heal config")
	hero.current_health = hero.max_health - 20
	hero.current_mana = 3
	assert(not Heal.try_use(combat, hero, healskill), "too poor to cast")
	hero.current_mana = 10
	assert(Heal.try_use(combat, hero, healskill), "cast starts")
	assert(hero.is_casting, "healer winds up")
	assert(hero.current_mana == 10, "mana paid at finish, not start")
	var hurt = hero.current_health
	for i in 20:
		hero.update(0.1, combat)
	assert(hero.current_health > hurt, "cast completes and heals")
	assert(hero.current_mana <= 6, "mana spent")

	# Spell power boosts the heal.
	hero.spell_power = 50
	hero.current_health = 1
	hero.current_mana = 10
	Heal.try_use(combat, hero, healskill)
	Heal.finish(combat, hero, healskill)
	assert(hero.current_health >= 59, "spell power pumps the heal")

	# Fizzled casts refund: full-health party costs nothing.
	hero.current_health = hero.max_health
	hero.current_mana = 6
	Heal.finish(combat, hero, healskill)
	assert(hero.current_mana == 6, "fizzle costs no mana")

	# Mana regenerates slowly over time.
	hero.current_mana = 0
	hero.is_casting = false
	for i in 60:
		hero.update(0.1, combat)
	assert(hero.current_mana >= 2, "mana regen ticks")

	# A spider-heavy brawl with all systems still completes.
	var spider = load("res://resources/enemies/venomous_spider.tres")
	var warrior = load("res://resources/enemies/goblin_warrior.tres")
	var heal_bonus: Array[SkillDefinition] = [healskill]
	delver.bonus_skills = heal_bonus
	var combat2 = CombatState.new()
	combat2.setup_combat([delver], [spider, warrior])
	var steps := 0
	while not combat2.combat_over and steps < 3000:
		combat2.update(0.1)
		steps += 1
	assert(combat2.combat_over, "full-system battle completes")

	print("PASS combat stats")
	get_tree().quit()
