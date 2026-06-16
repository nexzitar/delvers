extends Node

func _ok(label, cond):
	print(("PASS " if cond else "FAIL ") + label)

func _ready():
	# Frozen category indices.
	_ok("HEAD=0", GearDefinition.Slot.HEAD == 0)
	_ok("MAIN_HAND=2", GearDefinition.Slot.MAIN_HAND == 2)
	_ok("OFF_HAND=3", GearDefinition.Slot.OFF_HAND == 3)

	# Rings map to two positions; head to one.
	_ok("ring -> 2 positions",
		Equip.positions_for(GearDefinition.Slot.RING).size() == 2)
	_ok("head -> 1 position",
		Equip.positions_for(GearDefinition.Slot.HEAD).size() == 1)
	_ok("ring_2 category is RING",
		Equip.category_of(Equip.Position.RING_2) == GearDefinition.Slot.RING)

	# One-handed weapon accepts main and off hand; a bow does not.
	var sword = GearDefinition.new()
	sword.slot = GearDefinition.Slot.MAIN_HAND
	sword.weapon_type = GearDefinition.WeaponType.ONE_HANDED
	_ok("1H accepts main+off", Equip.accepted_positions(sword).size() == 2)

	var bow = GearDefinition.new()
	bow.slot = GearDefinition.Slot.MAIN_HAND
	bow.weapon_type = GearDefinition.WeaponType.BOW
	_ok("bow accepts only main", Equip.accepted_positions(bow).size() == 1)

	_ok("16 positions total", Equip.ALL.size() == 16)
	get_tree().quit()
