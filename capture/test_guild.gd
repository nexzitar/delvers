extends Node

## The Restoration of the Guild: the first victory grants the first
## companion automatically; further growth is bought with materials.

func _ready():
	var roster = load("res://scripts/game/player_roster.gd").new()
	roster.autosave = false
	roster._build_heroes()
	roster._build_stash()

	# Before the banner rises: locked, no purchases possible.
	assert(not GuildUnlocks.unlocked(roster), "guild locked pre-victory")
	roster.material_stash = {"gel": 99, "ash_wood": 99, "corrosion_core": 99}
	assert(not GuildUnlocks.purchase(roster, "second_skill_slot"),
		"no purchases before the banner")
	roster.check_milestones()
	assert(roster.heroes.size() == 1, "no companion before victory")

	# The banner rises: the first companion arrives, free, exactly once.
	roster.adventures_completed = 1
	roster.check_milestones()
	assert(roster.heroes.size() == 2, "restoration grants a companion")
	assert(roster.heroes[1].hero_name == "Wren", "the companion has a name")
	assert(roster.is_ranged(1), "Wren arrives as an archer")
	assert(roster.arrival_message == "You're not alone anymore.", "the camp announces the arrival")
	assert(roster.purchased_unlocks.has("restoration"), "milestone recorded")
	roster.check_milestones()
	assert(roster.heroes.size() == 2, "restoration fires once")

	# Training Grounds: materials buy the second skill slot.
	assert(GuildUnlocks.purchase(roster, "second_skill_slot"), "slot purchase")
	assert(roster.bonus_skill_slots == 2, "second slot open")
	assert(roster.material_stash["gel"] == 93, "materials spent")
	assert(not GuildUnlocks.purchase(roster, "second_skill_slot"),
		"no double purchase")

	# The third delver demands royal jelly (a boss kill each).
	assert(not GuildUnlocks.purchase(roster, "third_delver"), "jelly gates")
	roster.material_stash["iron_scrap"] = 6
	roster.material_stash["leather"] = 4
	roster.material_stash["royal_jelly"] = 1
	assert(GuildUnlocks.purchase(roster, "third_delver"), "third recruited")
	assert(roster.heroes.size() == 3, "three at the fire")
	assert(roster.heroes[2].hero_name == "Bram", "names don't repeat")
	assert(not roster.material_stash.has("royal_jelly"), "jelly consumed")

	# Everything survives a save round trip.
	var path := "user://test_guild_save.json"
	RosterSave.save(roster, path)
	var restored = load("res://scripts/game/player_roster.gd").new()
	assert(RosterSave.load_into(restored, path), "save loads")
	assert(restored.heroes.size() == 3, "party persists")
	assert(restored.bonus_skill_slots == 2, "slots persist")
	assert(restored.purchased_unlocks.has("third_delver"), "purchases persist")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

	# A v5 save (pre-guild) loads forward — and a stored victory means
	# the companion arrives the moment it loads.
	var old := FileAccess.open(path, FileAccess.WRITE)
	old.store_string(JSON.stringify({
		"version": 5, "adventures_completed": 3,
		"heroes": [{"template": "default_delver", "name": "Vet",
			"equipped": {}, "bonus_skills": []}],
		"stash": [],
	}))
	old = null
	var veteran = load("res://scripts/game/player_roster.gd").new()
	veteran.autosave = false
	assert(RosterSave.load_into(veteran, path), "v5 save loads forward")
	assert(veteran.heroes.size() == 2, "stored victory grants the companion")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

	# A two-delver party fights and finishes.
	var combat = CombatState.new()
	combat.setup_combat(roster.heroes.slice(0, 2).map(func(h): return h),
		[load("res://resources/enemies/green_slime.tres"),
		 load("res://resources/enemies/goblin_archer.tres")])
	var steps := 0
	while not combat.combat_over and steps < 3000:
		combat.update(0.1)
		steps += 1
	assert(combat.combat_over, "two-delver battle completes")

	roster.free()
	restored.free()
	veteran.free()
	print("PASS guild")
	get_tree().quit()
