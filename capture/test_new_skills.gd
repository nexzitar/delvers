extends Node

## The multi-enemy toolkit: Cleave, Whirlwind, Renew, Shield Wall,
## Thunderclap — and the new gear slots (boots, gauntlets, belt).

const Cleave = preload("res://scripts/combat/skills/cleave.gd")
const Whirlwind = preload("res://scripts/combat/skills/whirlwind.gd")
const Renew = preload("res://scripts/combat/skills/renew.gd")
const ShieldWall = preload("res://scripts/combat/skills/shield_wall.gd")
const Thunderclap = preload("res://scripts/combat/skills/thunderclap.gd")

func _ready():
	assert(PlayerRoster.skill_catalog.size() == 11, "catalog grew to 11")

	var delver = load("res://resources/heroes/default_delver.tres").duplicate(true)
	var slime = load("res://resources/enemies/green_slime.tres")
	var combat = CombatState.new()
	combat.setup_combat([delver], [slime, slime, slime])
	var hero = combat.heroes[0]
	var a = combat.enemies[0]
	var b = combat.enemies[1]
	var c = combat.enemies[2]
	for foe in [a, b, c]:
		foe.current_health = 200
		foe.max_health = 200
	a.position = hero.position + Vector2(40, 0)
	b.position = a.position + Vector2(30, 20)
	c.position = hero.position + Vector2(400, 0)
	hero.target_id = a.entity_id

	# Cleave: primary plus the neighbour, never the distant one.
	var cleave = load("res://resources/skills/cleave.tres")
	assert(Cleave.try_use(combat, hero, cleave), "cleave fires")
	assert(a.current_health < 200 and b.current_health < 200, "cleave splashes")
	assert(c.current_health == 200, "cleave respects its radius")

	# Whirlwind: needs company, then hits everyone close.
	var whirlwind = load("res://resources/skills/whirlwind.tres")
	var before_b = b.current_health
	b.position = hero.position + Vector2(600, 0)
	assert(not Whirlwind.try_use(combat, hero, whirlwind), "whirlwind waits for a crowd")
	b.position = hero.position + Vector2(-50, 10)
	assert(Whirlwind.try_use(combat, hero, whirlwind), "whirlwind fires")
	assert(b.current_health < before_b, "whirlwind hits behind too")

	# Renew: instant HoT that ticks, refuses to double-stack.
	var renew = load("res://resources/skills/renew.tres")
	hero.current_health = hero.max_health - 30
	hero.current_mana = 10
	assert(Renew.try_use(combat, hero, renew), "renew casts")
	assert(hero.current_mana == 7, "renew costs mana")
	assert(not Renew.try_use(combat, hero, renew), "no double renew")
	var hurt = hero.current_health
	for i in 30:
		hero.tick_statuses(0.1, combat)
	assert(hero.current_health >= hurt + 5, "renew ticks healing")

	# Shield Wall: raised when hurt and pressed, damage nearly halves.
	var wall = load("res://resources/skills/shield_wall.tres")
	hero.current_health = int(hero.max_health * 0.5)
	assert(ShieldWall.try_use(combat, hero, wall), "shield wall raises")
	assert(hero.damage_taken_multiplier() < 0.6, "wall shaves damage")
	hero.armor = 0
	hero.dodge_chance = 0.0
	hero.block_chance = 0.0
	var hp0 = hero.current_health
	a.crit_chance = 0.0
	a._strike(combat, a.skills[0], hero, 20)
	assert(hp0 - hero.current_health <= 12, "incoming damage reduced")

	# Thunderclap: crowd damage, dazed swings, triple threat.
	var clap = load("res://resources/skills/thunderclap.tres")
	var a_hp = a.current_health
	assert(Thunderclap.try_use(combat, hero, clap), "thunderclap fires")
	assert(a.current_health < a_hp, "clap damages")
	assert(a.attack_speed_multiplier() < 1.0, "clap dazes swings")
	assert(a.threat_table.get(hero.entity_id, 0.0) > 0.0, "clap generates threat")

	# A dazed timer drags: the enemy swings later than an undazed twin.
	a.attack_timer = 1.0
	var undazed := 1.0
	for i in 5:
		a.attack_timer -= 0.1 * a.attack_speed_multiplier()
		undazed -= 0.1
	assert(a.attack_timer > undazed, "daze slows the swing timer")

	# New gear slots: craft and equip boots, gauntlets, belt.
	var roster = load("res://scripts/game/player_roster.gd").new()
	roster.autosave = false
	roster._build_heroes()
	roster._build_stash()
	roster.known_recipes = ["iron_shod_boots", "goblin_work_gauntlets", "studded_belt"]
	roster.material_stash = {"leather": 10, "iron_scrap": 10, "gel": 4}
	for recipe_id in roster.known_recipes:
		var recipe = load(RosterSave.RECIPE_PATHS[recipe_id])
		var forged = roster.craft(recipe)
		assert(forged != null, "crafts " + recipe_id)
		var positions = Equip.accepted_positions(forged)
		assert(positions.size() == 1, "one home slot for " + recipe_id)
		assert(roster.equip_gear(0, forged, positions[0]), "equips " + recipe_id)
	var combat2 = CombatState.new()
	combat2.setup_combat([roster.heroes[0]], [slime])
	assert(combat2.heroes[0].armor >= 2, "boots and belt armor aggregate")
	assert(combat2.heroes[0].crit_chance > 0.0, "gauntlet crit aggregates")

	roster.free()
	print("PASS new skills")
	get_tree().quit()
