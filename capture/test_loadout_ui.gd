extends Node

func _ok(label, cond):
	print(("PASS " if cond else "FAIL ") + label)

func _ready():
	# Own state: never depend on whatever save the machine carries.
	PlayerRoster.autosave = false
	PlayerRoster._build_heroes()
	PlayerRoster._build_stash()
	PlayerRoster.bonus_skill_slots = 1
	var camp = load("res://scenes/camp/camp.tscn").instantiate()
	add_child(camp)
	await get_tree().process_frame
	await get_tree().process_frame
	var loadout = camp.loadout
	loadout.open(0)
	await get_tree().process_frame
	_ok("16 equip slots built", loadout._equip_slots.size() == 16)
	_ok("2 skill slots built (attack + 1 unlocked)", loadout._skill_slots.size() == 2)
	_ok("main hand slot exists",
		loadout._equip_slots.has(Equip.Position.MAIN_HAND))
	_ok("hero name shown", loadout._name_edit.text != "")
	get_tree().quit()
