extends Node

## The goblin warrior and venomous spider: focused material identities
## (iron/leather and poison), a poisoning bite, and the Leather Hood.

const VenomBite = preload("res://scripts/combat/skills/venom_bite.gd")

func _ready():
	var warrior = load("res://resources/enemies/goblin_warrior.tres")
	var spider = load("res://resources/enemies/venomous_spider.tres")

	# Material identity: every material in their tables exists, and the
	# key craft inputs now have clear owners.
	for template in [warrior, spider]:
		for material_id in template.material_loot:
			assert(RosterSave.MATERIAL_PATHS.has(material_id), "materials exist")
		for recipe_id in template.recipe_loot:
			assert(RosterSave.RECIPE_PATHS.has(recipe_id), "recipes exist")
		for affix_id in template.affix_loot:
			assert(RosterSave.AFFIX_PATHS.has(affix_id), "affixes exist")
	assert(warrior.material_loot.count("iron_scrap") == 3, "warrior owns iron")
	assert(warrior.material_loot.has("leather"), "warrior carries leather")
	assert(spider.material_loot.count("poison_sac") == 2, "spider owns poison")

	# Drops come from their own tables.
	var farmer = warrior.duplicate()
	farmer.material_drop_chance = 1.0
	for i in 8:
		var drops = LootTable.roll_enemy_drops([farmer], 3)
		for material_id in drops.materials:
			assert(farmer.material_loot.has(material_id), "warrior table only")

	# The spider's bite poisons, attributed to the spider.
	var delver = load("res://resources/heroes/default_delver.tres").duplicate(true)
	var combat = CombatState.new()
	combat.setup_combat([delver], [spider])
	var biter = combat.enemies[0]
	var hero = combat.heroes[0]
	assert(biter.skills.size() == 2, "spider carries venom bite")
	biter.position = hero.position + Vector2(40, 0)
	biter.target_id = hero.entity_id
	assert(VenomBite.try_use(combat, biter, biter.skills[1]), "bite lands")
	var poison = null
	for s in hero.statuses:
		if s.kind == StatusEffect.Kind.POISON:
			poison = s
	assert(poison != null, "bite poisons")
	assert(poison.source_id == biter.entity_id, "venom attributed")
	assert(not VenomBite.try_use(combat, biter, biter.skills[1]),
		"no re-bite while envenomed")

	# A full spider pack battle runs to completion (specials in the loop).
	var combat2 = CombatState.new()
	combat2.setup_combat([delver], [spider, spider])
	var steps := 0
	while not combat2.combat_over and steps < 3000:
		combat2.update(0.1)
		steps += 1
	assert(combat2.combat_over, "spider battle completes")

	# Leather Hood: learnable, craftable, properly named.
	var roster = load("res://scripts/game/player_roster.gd").new()
	roster.autosave = false
	roster._build_heroes()
	roster._build_stash()
	roster.known_recipes.append("leather_hood")
	roster.material_stash = {"leather": 3, "bow_string": 1}
	var hood_recipe = load("res://resources/recipes/leather_hood.tres")
	var hood = roster.craft(hood_recipe)
	assert(hood != null and hood.gear_name == "Leather Hood", "hood crafted")
	assert(hood.slot == GearDefinition.Slot.HEAD, "hood goes on the head")
	assert(roster.material_stash.is_empty(), "hides consumed")

	# The factory gives them bodies with the right pose API.
	var spider_rig = ActorFactory3D.build_enemy(spider)
	assert(spider_rig.has_method("pose_attack"), "spider uses the slime pose API")
	var warrior_rig = ActorFactory3D.build_enemy(warrior)
	assert(warrior_rig.has_method("pose_swing"), "warrior swings like a delver")
	spider_rig.free()
	warrior_rig.free()

	roster.free()
	print("PASS new enemies")
	get_tree().quit()
