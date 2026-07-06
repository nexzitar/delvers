extends Node

## Delve accounting: loot rolls, the pouch banking into the stash, and
## every arena in the pool being sane and fightable.

const ARENAS := [
	"res://resources/arenas/open_arena.tres",
	"res://resources/arenas/pillared_hall.tres",
	"res://resources/arenas/broken_wall.tres",
	"res://resources/arenas/scattered_rocks.tres",
]

func _ready():
	# Per-enemy loot: an always-dropping goblin only ever drops from its
	# own tables (bows and wood, never battle swords or slime gel).
	var goblin = load("res://resources/enemies/goblin_archer.tres").duplicate()
	goblin.drop_chance = 1.0
	goblin.material_drop_chance = 1.0
	for i in 12:
		var drops = LootTable.roll_enemy_drops([goblin], 3)
		assert(drops.gear.size() == 1, "guaranteed gear lands")
		assert(goblin.loot_ids.has(drops.gear[0].gear_id), "gear from own table")
		assert(drops.gear[0].item_level == 3, "item level = room")
		for material_id in drops.materials:
			assert(goblin.material_loot.has(material_id), "materials from own table")

	# Normals drop no finished gear; materials flow steadily.
	var slime = load("res://resources/enemies/green_slime.tres")
	var gear_total := 0
	var material_total := 0
	for i in 40:
		var d = LootTable.roll_enemy_drops([slime], 2)
		gear_total += d.gear.size()
		for material_id in d.materials:
			material_total += d.materials[material_id]
	assert(gear_total == 0, "normals drop no finished gear")
	assert(material_total >= 10, "materials flow")

	# Recipes: known knowledge never re-drops.
	var teacher = load("res://resources/enemies/goblin_archer.tres").duplicate()
	teacher.recipe_drop_chance = 1.0
	var learned = LootTable.roll_enemy_drops([teacher], 3)
	assert(learned.recipes.size() == 1, "recipe drops")
	assert(teacher.recipe_loot.has(learned.recipes[0]), "recipe from own pool")
	var all_known = LootTable.roll_enemy_drops(
		[teacher], 3, teacher.recipe_loot.duplicate()
	)
	assert(all_known.recipes.is_empty(), "known recipes don't re-drop")

	# Rarity: normal rolls stay at rare or below and skew common;
	# bosses roll rare or better.
	var uncommon_or_less := 0
	for i in 200:
		var q = LootTable.roll_quality(5)
		assert(q <= ItemQuality.Tier.RARE, "normal cap is rare")
		if q <= ItemQuality.Tier.UNCOMMON:
			uncommon_or_less += 1
	assert(uncommon_or_less >= 190, "rares are ~1%")
	for i in 40:
		assert(LootTable.roll_quality(10, true) >= ItemQuality.Tier.RARE,
			"bosses drop rare+")

	# Item level scales stats deterministically; rarity adds a premium.
	var base = LootTable.materialize("starter_bow", 1, ItemQuality.Tier.COMMON)
	var leveled = LootTable.materialize("starter_bow", 8, ItemQuality.Tier.COMMON)
	var fancy = LootTable.materialize("starter_bow", 8, ItemQuality.Tier.RARE)
	assert(leveled.damage_max > base.damage_max, "item level scales damage")
	assert(fancy.damage_max > leveled.damage_max, "rarity adds a premium")
	assert(
		fancy.damage_max == LootTable.materialize(
			"starter_bow", 8, ItemQuality.Tier.RARE
		).damage_max,
		"materialize is deterministic"
	)

	# The boss always drops a trophy, teaches something new, and oozes
	# royal materials.
	var king = load("res://resources/enemies/slime_king.tres")
	assert(king.is_boss and king.drop_chance >= 1.0, "boss config")
	var bounty = LootTable.roll_enemy_drops([king], 10)
	assert(bounty.gear.size() == 1, "boss drops a trophy")
	assert(bounty.gear[0].quality >= ItemQuality.Tier.RARE, "trophy is rare+")
	assert(bounty.gear[0].affix_id != "", "trophy carries an enchantment")
	assert(bounty.recipes.size() == 1, "boss teaches a recipe")
	assert(not bounty.materials.is_empty(), "boss drops materials")

	# Banking: pouch empties into the stash, delve state resets.
	var roster = load("res://scripts/game/player_roster.gd").new()
	roster.autosave = false
	roster._build_heroes()
	roster._build_stash()
	var before = roster.gear_stash.size()
	roster.start_delve()
	assert(
		roster.delve_room == 1 and roster.delve_loot.is_empty()
		and roster.delve_health.is_empty(),
		"delve starts clean"
	)
	roster.delve_loot = [
		LootTable.materialize("starter_sword", 2, ItemQuality.Tier.COMMON),
		LootTable.materialize("starter_bow", 4, ItemQuality.Tier.UNCOMMON),
	]
	var pouch = roster.delve_loot.size()
	roster.bank_delve_loot()
	assert(roster.gear_stash.size() == before + pouch, "loot banked to stash")
	assert(roster.delve_room == 0 and roster.delve_loot.is_empty(), "delve state reset")
	roster.free()

	# Arena pool: blocked tiles in bounds and clear of both spawns.
	for path in ARENAS:
		var arena = load(path)
		for tile in arena.blocked_tiles:
			assert(
				tile.x >= 0 and tile.y >= 0
				and tile.x < arena.width and tile.y < arena.height,
				"blocked tile in bounds: " + arena.arena_id
			)
			assert(
				tile.distance_to(arena.hero_spawn_center) > 2.5
				and tile.distance_to(arena.enemy_spawn_center) > 2.5,
				"spawns unblocked: " + arena.arena_id
			)

	# A full sim on the choke-point arena completes: melee paths through
	# the wall gaps, archers hold fire without line of sight.
	var delver = load("res://resources/heroes/default_delver.tres").duplicate(true)
	delver.equipped = {
		Equip.Position.MAIN_HAND: load("res://resources/gear/starter_sword.tres")
	}
	var skills: Array[SkillDefinition] = [
		load("res://resources/skills/auto_attack.tres")
	]
	delver.starting_skills = skills
	var combat = CombatState.new()
	combat.setup_combat(
		[delver],
		[load("res://resources/enemies/green_slime.tres"),
			load("res://resources/enemies/goblin_archer.tres")],
		load("res://resources/arenas/broken_wall.tres")
	)
	var steps := 0
	while not combat.combat_over and steps < 3000:
		combat.update(0.1)
		steps += 1
	assert(steps < 3000, "broken wall battle completes")

	# Deeper rooms field higher-level enemies.
	var deep = CombatState.new()
	deep.enemy_level_bonus = 2
	deep.setup_combat(
		[delver], [load("res://resources/enemies/green_slime.tres")]
	)
	assert(deep.enemies[0].level >= 3, "level bonus applied")

	# Attrition: entry health carries into the fight (and shows on the
	# SPAWN event the sidebar reads).
	var worn = CombatState.new()
	worn.setup_combat(
		[delver], [load("res://resources/enemies/green_slime.tres")],
		null, {0: 33}
	)
	assert(worn.heroes[0].current_health == 33, "entry health applied")
	var spawn = worn.combat_log.events[0]
	assert(
		spawn.type == CombatEvent.EventType.SPAWN and spawn.current_health == 33,
		"spawn event carries worn health"
	)

	print("PASS delve")
	get_tree().quit()
