extends Node

## Battlefield doctrines: tactics are recovered knowledge. Fresh
## guilds know only the nearest foe; the rest is taught by those who
## practice it.

func _ready():
	var roster = load("res://scripts/game/player_roster.gd").new()
	roster.autosave = false
	roster._build_heroes()
	roster._build_stash()

	# A fresh guild knows one way to fight.
	assert(roster.known_tactics == ["nearest"], "survival first")
	roster.set_tactic(0, "guard")
	assert(roster.heroes[0].tactic == "nearest", "unrecovered doctrine refused")

	# Warriors teach the shield-line; known doctrine never re-drops.
	var warrior = load("res://resources/enemies/goblin_warrior.tres").duplicate()
	warrior.doctrine_drop_chance = 1.0
	# Alone, the Shield-Line means nothing: the tome waits.
	var alone = LootTable.roll_enemy_drops([warrior], 3,
		[], [], [], null, [], 1, roster.known_tactics, 1)
	assert(alone.doctrines.is_empty(), "no ally, no shield-line")
	var lesson = LootTable.roll_enemy_drops([warrior], 3,
		[], [], [], null, [], 1, roster.known_tactics, 2)
	assert(lesson.doctrines == ["guard"], "the warrior teaches guarding")
	var known_all = LootTable.roll_enemy_drops([warrior], 3,
		[], [], [], null, [], 1, ["nearest", "guard"])
	assert(known_all.doctrines.is_empty(), "doctrine taught once")

	# Banking recovers the doctrine; the tactic unlocks.
	roster.start_delve()
	roster.delve_doctrines = ["guard", "guard"]
	roster.bank_delve_loot()
	assert(roster.known_tactics.count("guard") == 1, "recovered once")
	roster.set_tactic(0, "guard")
	assert(roster.heroes[0].tactic == "guard", "recovered doctrine usable")

	# Bosses always teach doctrine while any remains.
	var king = load("res://resources/enemies/slime_king.tres")
	var royal = LootTable.roll_enemy_drops([king], 10,
		[], [], [], null, [], 1, roster.known_tactics)
	assert(royal.doctrines.size() == 1, "the king lectures")

	# Persistence + veteran backfill.
	var path := "user://test_doctrine_save.json"
	RosterSave.save(roster, path)
	var restored = load("res://scripts/game/player_roster.gd").new()
	restored.autosave = false
	assert(RosterSave.load_into(restored, path), "save loads")
	assert(restored.known_tactics.has("guard"), "doctrine persists")
	assert(not restored.known_tactics.has("spread"), "unrecovered stays buried")
	var old := FileAccess.open(path, FileAccess.WRITE)
	old.store_string(JSON.stringify({
		"version": 7, "battles_fought": 30,
		"heroes": [{"template": "default_delver", "name": "Vet",
			"equipped": {}, "bonus_skills": []}],
		"stash": [],
	}))
	old = null
	var vet = load("res://scripts/game/player_roster.gd").new()
	vet.autosave = false
	assert(RosterSave.load_into(vet, path), "old save loads")
	assert(vet.known_tactics.size() == 7, "veterans keep their doctrine")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

	roster.free()
	restored.free()
	vet.free()
	print("PASS doctrines")
	get_tree().quit()
