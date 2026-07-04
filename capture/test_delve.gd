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
	# Loot rolls: always at least one item, gear instances are fresh.
	for room in [1, 5, 10]:
		var drops = LootTable.roll_room_loot(room)
		assert(drops.size() >= 1 and drops.size() <= 2, "1-2 drops")
		for gear in drops:
			assert(gear is GearDefinition, "drops are gear")
			assert(RosterSave.GEAR_PATHS.has(gear.gear_id), "drops persistable")

	# Banking: pouch empties into the stash, delve state resets.
	var roster = load("res://scripts/game/player_roster.gd").new()
	roster.autosave = false
	roster._build_heroes()
	roster._build_stash()
	var before = roster.gear_stash.size()
	roster.start_delve()
	assert(roster.delve_room == 1 and roster.delve_loot.is_empty(), "delve starts clean")
	roster.delve_loot = LootTable.roll_room_loot(1) + LootTable.roll_room_loot(2)
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

	print("PASS delve")
	get_tree().quit()
