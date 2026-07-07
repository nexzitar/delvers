extends Node

## Reset save: the guild returns to its founding day, on disk and in
## memory.

func _ready():
	# Never touch the player's real save in this test.
	var real := "user://delvers_save.json"
	var backup := ""
	if FileAccess.file_exists(real):
		backup = FileAccess.get_file_as_string(real)

	PlayerRoster.autosave = false
	PlayerRoster._build_heroes()
	PlayerRoster._build_stash()
	# A storied guild...
	PlayerRoster.battles_fought = 40
	PlayerRoster.adventures_completed = 3
	PlayerRoster.known_recipes = ["iron_sword", "hunter_bow", "chitin_armor"]
	PlayerRoster.known_affixes = ["virulent"]
	PlayerRoster.known_tactics = ["nearest", "guard", "protect"]
	PlayerRoster.known_engineering = ["doctrine_capacity_2"]
	PlayerRoster.unlocked_dungeons = ["darkwood", "spider_nest"]
	PlayerRoster.dungeon_progress = {"darkwood": 3}
	PlayerRoster.material_stash = {"iron_scrap": 50}
	PlayerRoster.purchased_unlocks = []
	PlayerRoster.check_milestones()
	assert(PlayerRoster.heroes.size() == 2, "storied guild has company")
	RosterSave.save(PlayerRoster)
	assert(FileAccess.file_exists(real), "ledger written")

	# ...burns the ledger.
	PlayerRoster.reset_save()
	assert(not FileAccess.file_exists(real), "the ledger is ash")
	assert(PlayerRoster.heroes.size() == 1, "one delver at the fire")
	assert(PlayerRoster.known_recipes == ["iron_sword"], "founding knowledge only")
	assert(PlayerRoster.known_tactics == ["nearest"], "survival tactics only")
	assert(PlayerRoster.doctrine_capacity() == 0, "no doctrine capacity")
	assert(PlayerRoster.unlocked_dungeons == ["darkwood"], "one map")
	assert(PlayerRoster.material_stash.is_empty(), "bare shelves")
	assert(PlayerRoster.gear_stash.is_empty(), "empty stash")
	assert(PlayerRoster.heroes[0].mastery.is_empty(), "novice hands")

	# Restore whatever the player really had.
	if backup != "":
		var f := FileAccess.open(real, FileAccess.WRITE)
		f.store_string(backup)

	print("PASS reset")
	get_tree().quit()
