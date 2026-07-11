extends Node

## The continuous-dungeon contracts: packs sleep until noticed, the
## party walks between fights, fleeing neighbors chain, linked packs
## pull together, and a full Darkwood delve terminates.

const STEP := 0.1
var delver = preload("res://resources/heroes/default_delver.tres")
var slime = preload("res://resources/enemies/green_slime.tres")

func _tiny_layout(pack_specs: Array) -> DungeonLayout:
	var layout = DungeonLayout.new()
	layout.arena = BattleArena.new()
	layout.arena.width = 60
	layout.arena.height = 15
	layout.arena.tile_size = 32
	layout.arena.hero_spawn_center = Vector2i(4, 7)
	for wp in [Vector2(4.5, 7.5) * 32.0, Vector2(25.5, 7.5) * 32.0,
			Vector2(50.5, 7.5) * 32.0]:
		layout.waypoints.append(wp)
	for r in [1, 2, 3]:
		layout.waypoint_rooms.append(r)
	for spec in pack_specs:
		layout.packs.append(spec)
	return layout

func _run(combat: CombatState, ticks: int):
	for i in ticks:
		if combat.combat_over:
			return
		combat.update(STEP)

func _ready():
	# Deterministic: the sim rolls off the global RNG.
	seed(20260711)
	# --- 1. Sleep, travel, pull, clear, finish -------------------------
	var layout = _tiny_layout([
		{"room": 2, "center": Vector2(25.5, 7.5) * 32.0,
			"templates": [slime, slime], "elite": false, "link": -1},
		{"room": 3, "center": Vector2(50.5, 7.5) * 32.0,
			"templates": [slime], "elite": false, "link": -1},
	])
	var combat = CombatState.new()
	combat.setup_delve([delver, delver], layout)
	assert(combat.enemies.size() == 3, "packs spawned")
	assert(combat.heroes.size() == 2, "party fielded")
	assert(combat.enemies.all(func(e): return e.dormant), "all packs sleep")

	var start_x = combat.heroes[0].position.x
	_run(combat, 30)
	assert(combat.heroes[0].position.x > start_x + 20.0,
		"the party walks the spine while all is quiet")
	assert(combat.enemies.all(func(e): return e.dormant),
		"distance keeps the packs asleep")

	_run(combat, 3000)
	assert(combat.combat_over, "the delve terminates")
	var types = combat.combat_log.events.map(func(e): return e.type)
	assert(types.has(CombatEvent.EventType.PACK_PULLED), "pulls are logged")
	assert(types.has(CombatEvent.EventType.PACK_DEFEATED),
		"cleared packs are logged")
	assert(types.count(CombatEvent.EventType.ROOM_ENTERED) >= 2,
		"room progress is logged")
	if combat.heroes.any(func(h): return h.alive):
		assert(combat.enemies.all(func(e): return not e.alive),
			"victory means every pack died")
		assert(types.count(CombatEvent.EventType.PACK_DEFEATED) == 2,
			"both packs reported")

	# --- 2. Chain aggro: a woken neighbor drags the sleepers in --------
	# Close enough to the party that the leash stays out of it.
	var chain_layout = _tiny_layout([
		{"room": 2, "center": Vector2(12.5, 7.5) * 32.0,
			"templates": [slime], "elite": false, "link": -1},
		{"room": 2, "center": Vector2(14.5, 7.5) * 32.0,
			"templates": [slime], "elite": false, "link": -1},
	])
	var chain = CombatState.new()
	chain.setup_delve([delver], chain_layout)
	chain._activate_pack(0)
	assert(chain.enemies[0].dormant == false, "pack 0 woke")
	assert(chain.enemies[1].dormant == true, "pack 1 still asleep")
	chain.update(STEP)
	assert(chain.enemies[1].dormant == false,
		"an active enemy near sleepers chains the pull")

	# --- 3. Linked packs pull together ---------------------------------
	var linked_layout = _tiny_layout([
		{"room": 2, "center": Vector2(25.5, 7.5) * 32.0,
			"templates": [slime], "elite": false, "link": 7},
		{"room": 3, "center": Vector2(50.5, 7.5) * 32.0,
			"templates": [slime], "elite": false, "link": 7},
	])
	var linked = CombatState.new()
	linked.setup_delve([delver], linked_layout)
	linked._activate_pack(0)
	assert(linked.enemies.all(func(e): return not e.dormant),
		"linked packs wake as one")

	# --- 4. The real thing: Darkwood compiles and terminates -----------
	var rng = RandomNumberGenerator.new()
	rng.seed = 7
	var darkwood = load("res://resources/dungeons/darkwood.tres")
	var real = DungeonLayout.generate(darkwood, rng)
	assert(real.waypoints.size() == darkwood.length, "one waypoint per room")
	assert(real.packs.size() >= darkwood.length - 1, "packs fill the rooms")
	assert(real.packs.back().room == darkwood.length, "the boss waits at the end")
	assert(real.packs.any(func(p): return p.elite), "a mid-boss stands the middle")
	var grid = BattleGrid.new(real.arena)
	var pathfinder = GridPathfinder.new(grid)
	var walk = pathfinder.find_path(
		grid.world_to_tile(real.waypoints[0]),
		grid.world_to_tile(real.waypoints[real.waypoints.size() - 1]), {})
	assert(not walk.is_empty(), "the spine is walkable end to end")

	var full = CombatState.new()
	full.setup_delve([delver, delver], real, {}, 0)
	_run(full, 30000)
	assert(full.combat_over, "a full Darkwood delve terminates")

	# --- 4b. The leash: abandoned pulls walk home and sleep ------------
	var leash_layout = _tiny_layout([
		{"room": 2, "center": Vector2(50.5, 7.5) * 32.0,
			"templates": [slime], "elite": false, "link": -1}])
	var leashed = CombatState.new()
	leashed.setup_delve([delver], leash_layout)
	leashed._activate_pack(0)
	leashed.enemies[0].current_health = 5
	leashed.update(STEP)
	assert(leashed.enemies[0].dormant, "far pull re-sleeps")
	assert(leashed.enemies[0].current_health == leashed.enemies[0].max_health,
		"the leash mends")
	assert(leashed.combat_log.events.any(func(e):
		return e.type == CombatEvent.EventType.PACK_RESET), "reset logged")

	# --- 5. The shaman keeps its pack standing -------------------------
	seed(11)
	var shaman = load("res://resources/enemies/goblin_shaman.tres")
	var warrior = load("res://resources/enemies/goblin_warrior.tres")
	var heal_layout = _tiny_layout([
		{"room": 2, "center": Vector2(20.5, 7.5) * 32.0,
			"templates": [warrior, warrior, shaman], "elite": false,
			"link": -1}])
	var hcombat = CombatState.new()
	hcombat.setup_delve([delver, delver], heal_layout)
	_run(hcombat, 4000)
	var enemy_heals = hcombat.combat_log.events.filter(func(e):
		if e.type != CombatEvent.EventType.HEAL:
			return false
		var src = hcombat.entity_by_id(e.source_id)
		return src != null and src.team == CombatEntity.Team.ENEMY)
	assert(not enemy_heals.is_empty(), "the shaman heals its pack")

	# --- 6. Broodlings belong to the brood ------------------------------
	var brood_layout = _tiny_layout([
		{"room": 2, "center": Vector2(12.5, 7.5) * 32.0,
			"templates": [slime, slime], "elite": false, "link": -1}])
	var brood = CombatState.new()
	brood.setup_delve([delver], brood_layout)
	brood._activate_pack(0)
	var mother = brood.enemies[0]
	var child = brood.spawn_reinforcement(slime, 1, mother.position,
		mother.entity_id)
	assert(child.pack_id == mother.pack_id, "spawn inherits the pack")
	assert(child.home_position == mother.home_position,
		"spawn leashes home with the family")

	print("PASS test_pulls")
	get_tree().quit()
