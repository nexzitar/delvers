extends Node

## Armor types trade in HOW you fight: plate holds and threatens,
## leather moves and strikes, cloth casts. Never a lock, always a
## build.

func _ready():
	var slime = load("res://resources/enemies/green_slime.tres")
	var base = load("res://resources/heroes/default_delver.tres").duplicate(true)
	base.equipped = {
		Equip.Position.MAIN_HAND: LootTable.materialize("starter_sword", 5, 1),
	}
	var plated = base.duplicate(true)
	plated.equipped = {
		Equip.Position.MAIN_HAND: LootTable.materialize("starter_sword", 5, 1),
		Equip.Position.HEAD: LootTable.materialize("starter_helmet", 5, 1),
		Equip.Position.CHEST: LootTable.materialize("chitin_armor", 5, 1),
		Equip.Position.LEGS: LootTable.materialize("iron_greaves", 5, 1),
		Equip.Position.OFF_HAND: LootTable.materialize("chitin_shield", 5, 1),
	}
	var clothed = base.duplicate(true)
	clothed.equipped = {
		Equip.Position.MAIN_HAND: LootTable.materialize("starter_sword", 5, 1),
		Equip.Position.HEAD: LootTable.materialize("silk_hood", 5, 1),
		Equip.Position.WRIST: LootTable.materialize("silk_bracers", 5, 1),
		Equip.Position.BACK: LootTable.materialize("weavers_cloak", 5, 1),
	}

	var combat = CombatState.new()
	combat.setup_combat([base, plated, clothed], [slime])
	var bare = combat.heroes[0]
	var tank = combat.heroes[1]
	var caster = combat.heroes[2]

	# Plate: louder, steadier, slower on its feet.
	assert(tank.threat_mult > 1.2, "plate draws every eye")
	assert(tank.stagger_resist > 0.2, "plate shrugs")
	assert(tank.move_speed < bare.move_speed, "plate is heavy")
	# The stagger resist in action: same gum, shorter stick.
	combat.apply_status(bare, StatusEffect.Kind.SLUGGISH, 6.0, 1.6, "gum_a")
	combat.apply_status(tank, StatusEffect.Kind.SLUGGISH, 6.0, 1.6, "gum_b")
	var bare_gum = bare.statuses[0].remaining
	var tank_gum = tank.statuses[0].remaining
	assert(tank_gum < bare_gum - 1.0, "the plate shrugs off the gum")

	# Cloth: deeper wells, faster casts.
	assert(caster.max_mana >= bare.max_mana + 6, "cloth holds mana")
	assert(caster.cast_speed_mult < 0.9, "cloth casts quicker")
	assert(caster.spell_power >= 3, "cloth channels")
	caster.start_behavior_cast(combat, load("res://resources/skills/heal.tres"), 1.0)
	assert(caster.cast_remaining < 0.9, "the cast runs faster in silk")

	# Leather: quicker hands. (Oiled set: 3 leather pieces.)
	var scout = base.duplicate(true)
	scout.equipped = {
		Equip.Position.MAIN_HAND: LootTable.materialize("starter_sword", 5, 1),
		Equip.Position.CHEST: LootTable.materialize("oiled_leathers", 5, 1),
		Equip.Position.FEET: LootTable.materialize("sprung_boots", 5, 1),
		Equip.Position.WAIST: LootTable.materialize("studded_belt", 5, 1),
	}
	var combat2 = CombatState.new()
	combat2.setup_combat([base, scout], [slime])
	assert(combat2.heroes[1].attack_interval < combat2.heroes[0].attack_interval,
		"leather strikes sooner")
	assert(combat2.heroes[1].crit_chance > combat2.heroes[0].crit_chance,
		"leather finds the gaps")

	# And the philosophy: nothing anywhere REFUSED a piece. Plate on a
	# healer is a choice, not an error.
	print("PASS armor types")
	get_tree().quit()
