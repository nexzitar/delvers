extends Node

## Headless check for the two new loadout behaviours:
##   1. Dropping gear/skills anywhere on the hero panel ("auto") equips it.
##   2. A two-handed weapon ghosts into the off-hand slot.

func _ready():
	_run()

func _ok(label, cond):
	print(("PASS " if cond else "FAIL ") + label)

func _run():
	var camp = load("res://scenes/camp/camp.tscn").instantiate()
	add_child(camp)
	await get_tree().process_frame
	await get_tree().process_frame

	var loadout = camp.loadout
	loadout.open(0)
	await get_tree().process_frame

	# Find a stash bow and a stash one-handed sword.
	var bow = null
	var sword = null
	for g in PlayerRoster.gear_stash:
		if g.weapon_type == GearDefinition.WeaponType.BOW:
			bow = g
		elif g.slot == GearDefinition.Slot.MAIN_HAND \
				and g.weapon_type == GearDefinition.WeaponType.ONE_HANDED:
			sword = g

	# Auto-equip the bow by dropping "anywhere" on the panel.
	var bdata = {"kind": "gear", "res": bow, "origin": "stash"}
	_ok("auto can_accept bow", loadout.can_accept("auto", bdata))
	loadout.accept_drop("auto", bdata)
	await get_tree().process_frame
	_ok("bow auto-equip flips to ranged", PlayerRoster.is_ranged(0))

	# Off-hand should now hold a dimmed ghost icon, not a real item.
	var off = loadout._equip_slots[GearDefinition.Slot.OFF_HAND]
	var ghost = off.get_child(0) if off.get_child_count() > 0 else null
	_ok("offhand ghost present", ghost != null)
	_ok("offhand ghost dimmed", ghost != null and ghost.modulate.a < 0.5)
	_ok("offhand has no real item",
		PlayerRoster.equipped_item(0, GearDefinition.Slot.OFF_HAND) == null)

	# A shield must be refused while the bow occupies both hands.
	var shield = null
	for g in PlayerRoster.gear_stash:
		if g.slot == GearDefinition.Slot.OFF_HAND:
			shield = g
			break
	if shield:
		var shdata = {"kind": "gear", "res": shield, "origin": "stash"}
		_ok("auto refuses off-hand while bow held",
			not loadout.can_accept("auto", shdata))

	# Auto-equip the sword: should flip back to melee and clear the ghost.
	var sdata = {"kind": "gear", "res": sword, "origin": "stash"}
	_ok("auto can_accept sword", loadout.can_accept("auto", sdata))
	loadout.accept_drop("auto", sdata)
	await get_tree().process_frame
	_ok("sword auto-equip flips to melee", not PlayerRoster.is_ranged(0))
	off = loadout._equip_slots[GearDefinition.Slot.OFF_HAND]
	_ok("offhand ghost gone after sword", off.get_child_count() == 0)

	# Now a shield should be accepted again.
	if shield:
		var shdata2 = {"kind": "gear", "res": shield, "origin": "stash"}
		_ok("off-hand accepted once one-handed", loadout.can_accept("auto", shdata2))

	get_tree().quit()
