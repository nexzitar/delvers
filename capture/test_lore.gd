extends Node

## Archaeology: lore fragments recover in order, persist as permanent
## memory, and every tome carries a piece of the world.

func _ready():
	# Every tome tells a story; every log loads and is ordered.
	for recipe_id in RosterSave.RECIPE_PATHS:
		assert(load(RosterSave.RECIPE_PATHS[recipe_id]).tome_lore != "",
			"recipe tome carries lore")
	for affix_id in RosterSave.AFFIX_PATHS:
		assert(load(RosterSave.AFFIX_PATHS[affix_id]).tome_lore != "",
			"affix tome carries lore")
	var last_order := 0
	for lore_id in RosterSave.LORE_PATHS:
		var fragment = load(RosterSave.LORE_PATHS[lore_id])
		assert(fragment.lore_id == lore_id, "lore id matches")
		assert(fragment.body != "", "log has a body")
		assert(fragment.order > last_order, "registry is in story order")
		last_order = fragment.order

	# Fragments drop lowest-first: the story assembles like evidence.
	var slime = load("res://resources/enemies/green_slime.tres")
	var found := []
	for i in 600:
		var drops = LootTable.roll_enemy_drops([slime], 2, [], [], found)
		for lore_id in drops.lore:
			assert(not found.has(lore_id), "no duplicate fragments")
			found.append(lore_id)
	assert(found.size() == 4, "all fragments eventually recovered")
	assert(found == ["expedition_log_1", "expedition_log_2",
		"expedition_log_3", "expedition_log_4"], "recovered in order")

	# Known fragments never re-drop.
	for i in 100:
		assert(LootTable.roll_enemy_drops([slime], 2, [], [], found).lore.is_empty(),
			"complete history stays complete")

	# Banking learns history exactly once; the save remembers it.
	var roster = load("res://scripts/game/player_roster.gd").new()
	roster.autosave = false
	roster._build_heroes()
	roster._build_stash()
	roster.start_delve()
	roster.delve_lore = ["expedition_log_1", "expedition_log_1"]
	roster.bank_delve_loot()
	assert(roster.known_lore.count("expedition_log_1") == 1, "learned once")
	var path := "user://test_lore_save.json"
	RosterSave.save(roster, path)
	var restored = load("res://scripts/game/player_roster.gd").new()
	assert(RosterSave.load_into(restored, path), "save loads")
	assert(restored.known_lore == ["expedition_log_1"], "history persists")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

	roster.free()
	restored.free()
	print("PASS lore")
	get_tree().quit()
