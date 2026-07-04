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
	roster.rename_hero(1, "Legolas")
	roster.battles_fought = 7
	roster.adventures_completed = 3
	roster.last_battle_won = true
	RosterSave.save(roster, TEST_PATH)

	var restored = load("res://scripts/game/player_roster.gd").new()
	assert(RosterSave.load_into(restored, TEST_PATH), "save loads")

	assert(restored.heroes.size() == roster.heroes.size(), "hero count")
	assert(restored.heroes[1].hero_name == "Legolas", "rename persisted")
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

	# Unknown ids in a save drop gracefully instead of crashing.
	var file = FileAccess.open(TEST_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify({
		"version": 1, "heroes": [{"template": "default_delver",
		"name": "X", "equipped": {"14": "future_relic"}, "bonus_skills": []}],
		"stash": ["future_relic", "starter_bow"],
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
