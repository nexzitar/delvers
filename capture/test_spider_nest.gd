extends Node

## The Spider Nest: map-gated second dungeon with its own material
## identity, deeper loot band, raised rarity ceiling, and lore series.

func _ready():
	var darkwood = load("res://resources/dungeons/darkwood.tres")
	var nest = load("res://resources/dungeons/spider_nest.tres")
	assert(darkwood.dungeon_id == "darkwood" and nest.dungeon_id == "spider_nest",
		"dungeons load")
	for dungeon in [darkwood, nest]:
		assert(not dungeon.guaranteed.is_empty() and dungeon.boss_pack.size() > 0,
			"dungeon anchored and bossed")
		for lore_id in dungeon.lore_ids:
			assert(RosterSave.LORE_PATHS.has(lore_id), "lore series exists")

	# The King guards the map; it drops once, ever.
	var king = load("res://resources/enemies/slime_king.tres")
	assert(king.map_loot == "spider_nest", "king carries the map")
	var bounty = LootTable.roll_enemy_drops([king], 10, [], [], [], darkwood, ["darkwood"])
	assert(bounty.maps == ["spider_nest"], "map drops from the king")
	var again = LootTable.roll_enemy_drops(
		[king], 10, [], [], [], darkwood, ["darkwood", "spider_nest"])
	assert(again.maps.is_empty(), "held maps never re-drop")

	# Banking the map unlocks the Nest and announces it.
	var roster = load("res://scripts/game/player_roster.gd").new()
	roster.autosave = false
	roster._build_heroes()
	roster._build_stash()
	roster.start_delve()
	roster.delve_maps = ["spider_nest"]
	roster.bank_delve_loot()
	assert(roster.unlocked_dungeons.has("spider_nest"), "nest unlocked")
	assert("Spider Nest" in roster.arrival_message, "the map is announced")
	roster.start_delve("spider_nest")
	assert(roster.current_dungeon == "spider_nest", "delve targets the nest")

	# The loot band: nest drops land ten item levels deeper, and the
	# rarity ceiling rises (rare from normals, epic sliver on the boss).
	var crawler = load("res://resources/enemies/chitin_crawler.tres").duplicate()
	crawler.drop_chance = 1.0
	var deep = LootTable.roll_enemy_drops([crawler], 4, [], [], [], nest, [])
	assert(deep.gear[0].item_level == 14, "nest band = room + 10")
	var rares := 0
	for i in 400:
		var q = LootTable.roll_quality(4, false, nest.rare_chance, nest.boss_epic_chance)
		if q >= ItemQuality.Tier.RARE:
			rares += 1
	assert(rares > 2 and rares < 40, "rares unlocked but precious")

	# Material identity: crawlers own chitin, weavers own silk, the
	# Broodmother drips brood silk.
	assert(LootTable.material_owner("chitin_plate") == "Chitin Crawler", "chitin owner")
	assert(LootTable.material_owner("silk_thread") in ["Web Weaver", "Nest Spiderling"],
		"silk owner")
	assert(LootTable.material_owner("brood_silk") == "The Broodmother", "brood silk owner")

	# The nest's lore series drops in the nest, in order.
	var spiderling = load("res://resources/enemies/nest_spiderling.tres")
	var found := []
	for i in 600:
		var drops = LootTable.roll_enemy_drops([spiderling], 2, [], [], found, nest, [])
		found.append_array(drops.lore)
	assert(found.size() == 4 and found[0] == "expedition_nest_1", "nest lore in order")

	# Encounter rolls never mutate the dungeon resource (Array(typed)
	# shares the buffer; picks must not leak into the .tres and balloon
	# later rooms).
	var controller = TheaterController3D.new()
	var core_before = darkwood.pool_core.size()
	var guaranteed_before = darkwood.guaranteed.size()
	for i in 50:
		controller.roll_encounter(1 + i % 9)
	assert(darkwood.pool_core.size() == core_before, "pool stays pristine")
	assert(darkwood.guaranteed.size() == guaranteed_before, "anchors stay pristine")
	controller.free()

	# The Nest's lesson: the Brood Tender births spiderlings mid-fight
	# (through real SPAWN events), capped so the swarm never runs away.
	var SpawnBrood = load("res://scripts/combat/skills/spawn_brood.gd")
	var tender_template = load("res://resources/enemies/brood_tender.tres")
	var lesson_delver = load("res://resources/heroes/default_delver.tres").duplicate(true)
	var combat_brood = CombatState.new()
	combat_brood.setup_combat([lesson_delver], [tender_template])
	var tender = combat_brood.enemies[0]
	tender.in_combat = true
	var before_spawn = combat_brood.enemies.size()
	assert(SpawnBrood.try_use(combat_brood, tender, tender.skills[1]), "brood spawns")
	assert(combat_brood.enemies.size() == before_spawn + 2, "two spiderlings join")
	var spawn_events = combat_brood.combat_log.events.filter(
		func(e): return e.type == CombatEvent.EventType.SPAWN
	)
	assert(spawn_events.size() == before_spawn + 1 + 2, "late spawns hit the log")
	assert(combat_brood.enemies[-1].spawned_by == tender.entity_id, "brood remembers mother")
	assert(SpawnBrood.try_use(combat_brood, tender, tender.skills[1]), "second wave")
	assert(not SpawnBrood.try_use(combat_brood, tender, tender.skills[1]),
		"the brood is capped")
	assert(nest.guaranteed.any(func(t): return t.enemy_id == "brood_tender"),
		"a tender anchors every nest room")

	# Difficulty tiers: gated, scaling, and never stale.
	var tier_roster = load("res://scripts/game/player_roster.gd").new()
	tier_roster.autosave = false
	tier_roster._build_heroes()
	tier_roster._build_stash()
	tier_roster.start_delve("darkwood", 3)
	assert(tier_roster.current_tier == 1, "uncleaned tiers clamp to one")
	tier_roster.record_clear("darkwood", 1)
	tier_roster.start_delve("darkwood", 2)
	assert(tier_roster.current_tier == 2, "clearing opens the next tier")
	var deep_drops = LootTable.roll_enemy_drops(
		[crawler], 4, [], [], [], nest, [], 3)
	assert(deep_drops.gear[0].item_level == 14, "tiers never inflate item level")
	var pile = LootTable.roll_enemy_drops(
		[load("res://resources/enemies/goblin_warrior.tres")], 2, [], [], [], darkwood, [], 3)
	var total := 0
	for mid in pile.materials:
		total += pile.materials[mid]
	assert(total >= 3, "tier hauls more materials")
	var tier_path := "user://test_tier_save.json"
	RosterSave.save(tier_roster, tier_path)
	var tier_restored = load("res://scripts/game/player_roster.gd").new()
	tier_restored.autosave = false
	assert(RosterSave.load_into(tier_restored, tier_path), "save loads")
	assert(tier_restored.highest_cleared("darkwood") == 1, "progress persists")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(tier_path))
	tier_roster.free()
	tier_restored.free()

	# The Nest's answer: poison resist shaves the DoT that armor can't.
	var armored = load("res://resources/heroes/default_delver.tres").duplicate(true)
	armored.equipped = {
		Equip.Position.HEAD: LootTable.materialize("silk_hood", 14, 1),
		Equip.Position.CHEST: LootTable.materialize("chitin_armor", 14, 1),
		Equip.Position.WRIST: LootTable.materialize("silk_bracers", 14, 1),
		Equip.Position.BACK: LootTable.materialize("weavers_cloak", 14, 1),
	}
	var combat_resist = CombatState.new()
	combat_resist.setup_combat([armored], [spiderling])
	var warded = combat_resist.heroes[0]
	assert(warded.poison_resist > 0.7, "nest set stacks resist")
	combat_resist.apply_status(warded, StatusEffect.Kind.POISON, 10.0, 2.0, "p", -1)
	var hp_start = warded.current_health
	for i in 50:
		warded.tick_statuses(0.1, combat_resist)
	var warded_loss = hp_start - warded.current_health
	assert(warded_loss <= 4, "resist shaves the venom (took %d)" % warded_loss)

	# Tier-gated knowledge: tier 1 never teaches tier-2 recipes.
	var teacher = load("res://resources/enemies/web_weaver.tres").duplicate()
	teacher.recipe_drop_chance = 1.0
	for i in 60:
		var lesson = LootTable.roll_enemy_drops([teacher], 3,
			["silk_hood", "chitin_shield"], [], [], nest, [], 1)
		for rid in lesson.recipes:
			assert(load(RosterSave.RECIPE_PATHS[rid]).min_tier <= 1,
				"tier 1 keeps its secrets")
	var taught := false
	for i in 60:
		var lesson2 = LootTable.roll_enemy_drops([teacher], 3,
			["silk_hood", "chitin_shield"], [], [], nest, [], 2)
		if lesson2.recipes.has("silk_bracers"):
			taught = true
	assert(taught, "tier 2 teaches the bracers")

	# Web Shot roots; the sim runs a nest pack to completion.
	var WebShot = load("res://scripts/combat/skills/web_shot.gd")
	var delver = load("res://resources/heroes/default_delver.tres").duplicate(true)
	var weaver_template = load("res://resources/enemies/web_weaver.tres")
	var combat = CombatState.new()
	combat.setup_combat([delver], [weaver_template])
	var weaver = combat.enemies[0]
	var hero = combat.heroes[0]
	weaver.position = hero.position + Vector2(150, 0)
	weaver.target_id = hero.entity_id
	assert(weaver.skills.size() == 2, "weaver carries web shot")
	assert(WebShot.try_use(combat, weaver, weaver.skills[1]), "web lands")
	assert(hero.is_rooted(), "webbed means rooted")
	assert(not WebShot.try_use(combat, weaver, weaver.skills[1]), "no re-web")

	var brood_template = load("res://resources/enemies/broodmother.tres")
	assert(brood_template.is_boss, "broodmother is a boss")
	var combat2 = CombatState.new()
	var strong = delver.duplicate(true)
	strong.equipped = {
		Equip.Position.MAIN_HAND: LootTable.materialize("starter_sword", 14, 2, "virulent"),
		Equip.Position.OFF_HAND: LootTable.materialize("starter_shield", 14, 2),
		Equip.Position.CHEST: LootTable.materialize("starter_armor", 14, 2),
	}
	var partner = delver.duplicate(true)
	partner.equipped = {
		Equip.Position.MAIN_HAND: LootTable.materialize("starter_bow", 14, 2, "virulent"),
	}
	combat2.setup_combat([strong, partner], [brood_template,
		load("res://resources/enemies/nest_spiderling.tres")])
	var steps := 0
	while not combat2.combat_over and steps < 3000:
		combat2.update(0.1)
		steps += 1
	assert(combat2.combat_over, "broodmother fight completes")

	# Save round trip: unlocked dungeons and choice persist; v6 saves
	# load forward with the Darkwood only.
	var path := "user://test_nest_save.json"
	RosterSave.save(roster, path)
	var restored = load("res://scripts/game/player_roster.gd").new()
	restored.autosave = false
	assert(RosterSave.load_into(restored, path), "save loads")
	assert(restored.unlocked_dungeons.has("spider_nest"), "unlock persists")
	assert(restored.current_dungeon == "spider_nest", "choice persists")
	var old := FileAccess.open(path, FileAccess.WRITE)
	old.store_string(JSON.stringify({
		"version": 6,
		"heroes": [{"template": "default_delver", "name": "Vet",
			"equipped": {}, "bonus_skills": []}],
		"stash": [],
	}))
	old = null
	var veteran = load("res://scripts/game/player_roster.gd").new()
	veteran.autosave = false
	assert(RosterSave.load_into(veteran, path), "v6 loads forward")
	assert(veteran.unlocked_dungeons == ["darkwood"], "old saves know one dungeon")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

	roster.free()
	restored.free()
	veteran.free()
	print("PASS spider nest")
	get_tree().quit()
