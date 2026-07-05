extends Node

## The Spider Nest: map-gated second dungeon with its own material
## identity, deeper loot band, raised rarity ceiling, and lore series.

func _ready():
	var darkwood = load("res://resources/dungeons/darkwood.tres")
	var nest = load("res://resources/dungeons/spider_nest.tres")
	assert(darkwood.dungeon_id == "darkwood" and nest.dungeon_id == "spider_nest",
		"dungeons load")
	for dungeon in [darkwood, nest]:
		assert(dungeon.guaranteed != null and dungeon.boss_pack.size() > 0,
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
		Equip.Position.MAIN_HAND: LootTable.materialize("starter_sword", 14, 2),
		Equip.Position.OFF_HAND: LootTable.materialize("starter_shield", 14, 2),
	}
	combat2.setup_combat([strong], [brood_template,
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
