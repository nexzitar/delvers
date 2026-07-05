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
	# own table (bows and daggers, never battle swords).
	var goblin = load("res://resources/enemies/goblin_archer.tres").duplicate()
	goblin.drop_chance = 1.0
	for i in 12:
		var drops = LootTable.roll_enemy_drops([goblin], 3)
		assert(drops.size() == 1, "guaranteed drop lands")
		assert(goblin.loot_ids.has(drops[0].gear_id), "drop from own table")
		assert(drops[0].item_level == 3, "item level = room")

	# Normal enemies mostly drop nothing (10% chance): 40 slain slimes
	# essentially never yield 40 items.
	var slime = load("res://resources/enemies/green_slime.tres")
	var total := 0
	for i in 40:
		total += LootTable.roll_enemy_drops([slime], 2).size()
	assert(total < 20, "drops are scarce")

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

	# The boss exists, always drops, and is flagged for the rare table.
	var king = load("res://resources/enemies/slime_king.tres")
	assert(king.is_boss and king.drop_chance >= 1.0, "boss config")
	assert(LootTable.roll_enemy_drops([king], 10).size() == 1, "boss drops")

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
