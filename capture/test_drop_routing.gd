extends Node

func _ok(label, cond):
	print(("PASS " if cond else "FAIL ") + label)

func _ready():
	# The camp uses the PlayerRoster autoload; reset it to defaults with
	# autosave off so this test is deterministic and save-neutral.
	PlayerRoster.autosave = false
	PlayerRoster._build_heroes()
	PlayerRoster._build_stash()

	var camp = load("res://scenes/camp/camp.tscn").instantiate()
	add_child(camp)
	await get_tree().process_frame
	await get_tree().process_frame
	var loadout = camp.loadout
	loadout.open(0)
	await get_tree().process_frame

	var bow = LootTable.materialize("starter_bow", 1, ItemQuality.Tier.COMMON)
	PlayerRoster.gear_stash.append(bow)
	var bdata = {"kind": "gear", "res": bow, "origin": "stash"}
	_ok("auto accepts bow", loadout.can_accept("auto", bdata))
	loadout.accept_drop("auto", bdata)
	await get_tree().process_frame
	_ok("bow equipped -> ranged", PlayerRoster.is_ranged(0))

	var any_skill = PlayerRoster.skill_catalog[0]
	_ok("skill slot read-only",
		not loadout.can_accept("skill_view",
			{"kind": "skill", "res": any_skill, "origin": "catalog"}))

	get_tree().quit()
