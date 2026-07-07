extends Node

## The Sunken Workshop: machines punish trading blows; evasion is the
## answer found inside. The Foreman teaches the Engineer's Slate.

func _ready():
	PlayerRoster.autosave = false

	# The Broodmother guards the way down.
	var broodmother = load("res://resources/enemies/broodmother.tres")
	assert(broodmother.map_loot == "sunken_workshop", "the mother guards the map")

	# The lesson, measured: against sentinel pistons, the dodge set
	# beats the block-and-armor set it replaces.
	var sentinel = load("res://resources/enemies/scrap_sentinel.tres")
	var plated = load("res://resources/heroes/default_delver.tres").duplicate(true)
	plated.equipped = {
		Equip.Position.MAIN_HAND: LootTable.materialize("starter_sword", 24, 1),
		Equip.Position.OFF_HAND: LootTable.materialize("chitin_shield", 14, 1),
		Equip.Position.CHEST: LootTable.materialize("chitin_armor", 14, 1),
	}
	var oiled = load("res://resources/heroes/default_delver.tres").duplicate(true)
	oiled.equipped = {
		Equip.Position.MAIN_HAND: LootTable.materialize("starter_sword", 24, 1),
		Equip.Position.CHEST: LootTable.materialize("oiled_leathers", 24, 1),
		Equip.Position.FEET: LootTable.materialize("sprung_boots", 24, 1),
		Equip.Position.HEAD: LootTable.materialize("engineers_goggles", 24, 1),
	}
	# Overwhelmed on purpose (two sentinels): the set that keeps you
	# alive longest under the pistons is the dungeon's answer.
	var trials := 40
	var plated_steps := 0.0
	var oiled_steps := 0.0
	for k in trials:
		for pair in [[plated, true], [oiled, false]]:
			var combat = CombatState.new()
			combat.setup_combat([pair[0]], [sentinel, sentinel])
			var steps := 0
			while not combat.combat_over and steps < 2500:
				combat.update(0.1)
				steps += 1
			if pair[1]:
				plated_steps += steps
			else:
				oiled_steps += steps
	plated_steps /= trials
	oiled_steps /= trials
	print("piston trial - plated survives %.0f steps, oiled %.0f" % [plated_steps, oiled_steps])
	assert(oiled_steps > plated_steps * 1.15, "evasion outlives plate under the pistons")

	# The Oil Slick gums swings.
	var slick = load("res://resources/enemies/oil_slick.tres")
	var combat_gum = CombatState.new()
	combat_gum.setup_combat([plated], [slick])
	var gummed := false
	var steps := 0
	while not combat_gum.combat_over and steps < 1200:
		combat_gum.update(0.1)
		steps += 1
		for status in combat_gum.heroes[0].statuses:
			if status.id == "gum_strike":
				gummed = true
	assert(gummed, "the oil gums your arms")

	# The Foreman lectures: the Slate and Doctrine III, always.
	var foreman = load("res://resources/enemies/foreman.tres")
	var spoils = LootTable.roll_enemy_drops([foreman], 10,
		[], [], [], load("res://resources/dungeons/sunken_workshop.tres"),
		["darkwood", "spider_nest", "sunken_workshop"], 1, ["nearest"])
	assert(spoils.doctrines.size() >= 1, "the Foreman lectures")
	for doctrine_id in spoils.doctrines:
		assert(doctrine_id in ["engineers_slate", "doctrine_capacity_3"],
			"engineering lessons only")

	# Goggles are tier-gated knowledge; workshop ilvl band holds.
	var goggles = load("res://resources/recipes/engineers_goggles.tres")
	assert(goggles.min_tier == 3, "sight comes at tier three")
	var dungeon = load("res://resources/dungeons/sunken_workshop.tres")
	assert(dungeon.level_offset == 20, "the band sits above the nest")
	assert(dungeon.lore_ids.size() == 4, "four fragments below")

	print("PASS workshop")
	get_tree().quit()
