extends Node

## Discipline mastery: practice trains, rust fades but never erases,
## relearning is fast, and stars grant real techniques in combat.

func _ready():
	var roster = load("res://scripts/game/player_roster.gd").new()
	roster.autosave = false
	roster._build_heroes()
	roster._build_stash()
	var garrick = roster.heroes[0]

	# Sword-and-board trains sword and shield; a slotted heal trains
	# restoration too.
	var active = Mastery.active_disciplines(garrick)
	assert(active.has("sword") and active.has("shield"), "loadout decides training")
	assert(not active.has("restoration"), "no healing slotted yet")
	roster.equip_bonus_skill(0, load("res://resources/skills/heal.tres"), 1)
	assert(Mastery.active_disciplines(garrick).has("restoration"),
		"healing practice counts")

	# Stars climb thresholds; star-ups name their unlocks.
	assert(Mastery.stars(garrick, "sword") == 0, "novice at dawn")
	var ups = Mastery.train(garrick, "sword", 8)
	assert(Mastery.stars(garrick, "sword") == 1, "first star at 8")
	ups = Mastery.train(garrick, "sword", 16)
	assert(Mastery.stars(garrick, "sword") == 2, "second star at 24")
	assert(ups.size() == 1 and ups[0].label == "Cleave", "the star names its gift")

	# The mastery kit reaches combat: auto techniques and passives.
	Mastery.train(garrick, "sword", 116)
	assert(Mastery.stars(garrick, "sword") == 5, "legend at 140")
	Mastery.train(garrick, "shield", 24)
	var combat = CombatState.new()
	combat.setup_combat([garrick], [load("res://resources/enemies/green_slime.tres")])
	var fighter = combat.heroes[0]
	var ids = fighter.skills.map(func(s): return s.skill_id if s else "")
	for expected in ["cleave", "hamstring", "whirlwind", "shield_wall"]:
		assert(ids.has(expected), "mastery grants " + expected)
	assert(ids.count("cleave") == 1, "no duplicates with slots")
	assert(fighter.attack_interval < 2.6, "weapon familiarity quickens the blade")

	# Rust: an unpracticed delve fades current XP, never the best mark.
	roster.start_delve()
	roster.delve_trained = {"bow": true}
	var sword_xp = int(garrick.mastery.sword.xp)
	roster.bank_delve_loot()
	assert(int(garrick.mastery.sword.xp) == sword_xp - 2, "rust bites gently")
	assert(int(garrick.mastery.sword.best_xp) == sword_xp, "the best mark holds")

	# Relearning below the best mark is triple speed.
	garrick.mastery.sword.xp = 0
	Mastery.train(garrick, "sword", 8)
	assert(int(garrick.mastery.sword.xp) == 24, "rusty hands remember")

	# Party training routes through the roster and reports star-ups.
	roster.start_delve()
	garrick.mastery.erase("bow")
	var reports = roster.train_party([0], 24)
	assert(roster.delve_trained.has("sword"), "the delve remembers its practice")
	for report in reports:
		assert(report.has("hero"), "reports carry the name")

	# Mastery OWNS the core techniques: slots refuse them, and old
	# saves that slotted them come back clean.
	assert(not roster.equip_bonus_skill(0,
		load("res://resources/skills/whirlwind.tres"), 1),
		"a whirlwind needs a sword, not a slot")
	assert(roster.equip_bonus_skill(0,
		load("res://resources/skills/charge.tres"), 1),
		"guild techniques still slot freely")
	assert(RosterSave._skill_from_id("cleave") == null, "stale core slots strip")
	assert(RosterSave._skill_from_id("heal") != null, "guild skills load")

	# Everything survives a save round trip.
	var path := "user://test_mastery_save.json"
	RosterSave.save(roster, path)
	var restored = load("res://scripts/game/player_roster.gd").new()
	restored.autosave = false
	assert(RosterSave.load_into(restored, path), "save loads")
	assert(Mastery.stars(restored.heroes[0], "sword") >= 1, "mastery persists")
	assert(Mastery.best_stars(restored.heroes[0], "sword") == 5, "history persists")

	# Veterans predate mastery: seeded two stars deep in their kit.
	var old := FileAccess.open(path, FileAccess.WRITE)
	old.store_string(JSON.stringify({
		"version": 7, "battles_fought": 20,
		"heroes": [{"template": "default_delver", "name": "Vet",
			"equipped": {str(int(Equip.Position.MAIN_HAND)):
				{"id": "starter_sword", "level": 1, "quality": 0}},
			"bonus_skills": []}],
		"stash": [],
	}))
	old = null
	var vet = load("res://scripts/game/player_roster.gd").new()
	vet.autosave = false
	assert(RosterSave.load_into(vet, path), "old save loads")
	assert(Mastery.stars(vet.heroes[0], "sword") == 2, "veterans start seasoned")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

	roster.free()
	restored.free()
	vet.free()
	print("PASS mastery")
	get_tree().quit()
