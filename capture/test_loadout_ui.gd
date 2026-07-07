extends Node

func _ok(label, cond):
	print(("PASS " if cond else "FAIL ") + label)

func _doctrine_checks(camp):
	var loadout = camp.loadout
	# No capacity: the editor does not exist (steady discovery).
	loadout._fill_tactics()
	var texts := []
	for child in loadout._tactics_box.get_children():
		if child is Label:
			texts.append(child.text)
	_ok("editor hidden without capacity",
		not texts.any(func(t): return "nodes" in t))
	# Capacity + a written doctrine: rows and an honest counter.
	PlayerRoster.known_engineering = ["doctrine_capacity_1"]
	PlayerRoster.known_tactics = ["nearest", "guard", "protect"]
	PlayerRoster.heroes[0].custom_tree = [
		{"when": [{"cond": "healer_threatened"}], "target": "healer_attacker"},
		{"when": [], "target": "nearest"},
	]
	loadout._fill_tactics()
	var counter := ""
	for child in loadout._tactics_box.get_children():
		if child is Label and "nodes" in child.text:
			counter = child.text
	_ok("node counter reads 3/4", counter.begins_with("3/4"))
	# With the Slate and Annotations recovered: blocks + View Code.
	PlayerRoster.known_engineering = ["doctrine_capacity_1",
		"engineers_slate", "engineers_annotations"]
	loadout._fill_tactics()
	var has_view_code := false
	for child in loadout._tactics_box.get_children():
		for sub in child.get_children() if child is HBoxContainer else []:
			if sub is Button and sub.text == "View Code":
				has_view_code = true
	_ok("View Code appears with the Annotations", has_view_code)

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
	_doctrine_checks(camp)
	get_tree().quit()
