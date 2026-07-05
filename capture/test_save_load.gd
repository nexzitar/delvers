extends Node

## Roster persistence round-trip: loadout edits, skill slots, renames,
## and progress survive a save and restore into a fresh roster.

const TEST_PATH := "user://test_delvers_save.json"

func _ready():
	# Built by hand (not the autoload) so this test owns its state, and
	# with autosave off so it never touches the player's real save.
	var roster = load("res://scripts/game/player_roster.gd").new()
	roster.autosave = false
	roster._build_heroes()
	roster._build_stash()

	# Mutate: dagger to the melee hero's off hand, a bonus skill, a
	# rename, and some progress, then snapshot to the test path.
	var dagger = null
	for gear in roster.gear_stash:
		if gear.gear_id == "fast_dagger":
			dagger = gear
	assert(dagger != null, "dagger seeded in stash")
	assert(roster.equip_gear(0, dagger, Equip.Position.OFF_HAND), "dagger equipped")
	roster.equip_bonus_skill(0, load("res://resources/skills/charge.tres"), 1)
	roster.rename_hero(0, "Aragorn")
	roster.battles_fought = 7
	roster.adventures_completed = 3
	roster.last_battle_won = true
	# A leveled uncommon drop must survive the round trip with its
	# scaled stats intact.
	var fancy_bow = LootTable.materialize(
		"starter_bow", 6, ItemQuality.Tier.UNCOMMON
	)
	roster.gear_stash.append(fancy_bow)
	RosterSave.save(roster, TEST_PATH)

	var restored = load("res://scripts/game/player_roster.gd").new()
	assert(RosterSave.load_into(restored, TEST_PATH), "save loads")

	assert(restored.heroes.size() == roster.heroes.size(), "hero count")
	assert(restored.heroes[0].hero_name == "Aragorn", "rename persisted")
	var off = restored.heroes[0].equipped.get(Equip.Position.OFF_HAND)
	assert(off != null and off.gear_id == "fast_dagger", "off-hand dagger persisted")
	var main = restored.heroes[0].equipped.get(Equip.Position.MAIN_HAND)
	assert(main != null and main.gear_id == "starter_sword", "main hand persisted")
	assert(
		restored.heroes[0].bonus_skills[0] != null
		and restored.heroes[0].bonus_skills[0].skill_id == "charge",
		"bonus skill persisted"
	)
	assert(restored.heroes[0].starting_skills[0].skill_id == "auto_attack",
		"role re-synced on load")
	assert(restored.gear_stash.size() == roster.gear_stash.size(), "stash size")
	assert(restored.battles_fought == 7, "battles persisted")
	assert(restored.adventures_completed == 3, "adventures persisted")
	assert(restored.last_battle_won, "result persisted")

	# Restored items are their own physical objects, not shared refs.
	assert(off != roster.heroes[0].equipped.get(Equip.Position.OFF_HAND),
		"restored gear is a fresh instance")

	# Item level and quality survive, with identically re-scaled stats.
	var restored_bow = null
	for gear in restored.gear_stash:
		if gear.gear_id == "starter_bow" and gear.item_level == 6:
			restored_bow = gear
	assert(restored_bow != null, "leveled bow persisted")
	assert(restored_bow.quality == ItemQuality.Tier.UNCOMMON, "quality persisted")
	assert(restored_bow.damage_max == fancy_bow.damage_max, "scaled stats rebuilt")

	# Unknown ids in a save drop gracefully instead of crashing.
	var file = FileAccess.open(TEST_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify({
		"version": 4, "heroes": [{"template": "default_delver",
		"name": "X",
		"equipped": {"14": {"id": "future_relic", "level": 3, "quality": 0}},
		"bonus_skills": []}],
		"stash": [
			{"id": "future_relic", "level": 1, "quality": 0},
			{"id": "starter_bow", "level": 1, "quality": 0},
		],
	}))
	file = null
	var sparse = load("res://scripts/game/player_roster.gd").new()
	assert(RosterSave.load_into(sparse, TEST_PATH), "sparse save loads")
	assert(sparse.gear_stash.size() == 1, "unknown gear dropped")
	assert(sparse.heroes[0].equipped.is_empty(), "unknown equip dropped")

	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))
	roster.free()
	restored.free()
	sparse.free()

	print("PASS save load")
	get_tree().quit()
