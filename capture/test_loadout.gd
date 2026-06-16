extends Node

func _ok(label, cond):
	print(("PASS " if cond else "FAIL ") + label)

func _ready():
	var roster = preload("res://scripts/game/player_roster.gd").new()
	add_child(roster)  # triggers _ready -> _build_heroes/_build_stash

	# Two independent heroes from the same base.
	_ok("two heroes", roster.heroes.size() == 2)
	_ok("hero loadouts independent",
		roster.heroes[0].equipped != roster.heroes[1].equipped)

	# Hero 0 is melee with a sword in the main hand; hero 1 ranged (bow).
	var h0_main = roster.equipped_item(0, Equip.Position.MAIN_HAND)
	_ok("hero0 has main-hand weapon", h0_main != null)
	_ok("hero0 melee", not roster.is_ranged(0))
	_ok("hero1 ranged", roster.is_ranged(1))

	# Equip a stash sword into hero0's OFF hand (dual wield).
	var spare_sword = null
	for g in roster.gear_stash:
		if g.slot == GearDefinition.Slot.MAIN_HAND \
				and g.weapon_type == GearDefinition.WeaponType.ONE_HANDED:
			spare_sword = g
			break
	_ok("found spare 1H sword", spare_sword != null)
	var ok = roster.equip_gear(0, spare_sword, Equip.Position.OFF_HAND)
	_ok("equipped 1H in off hand", ok)
	_ok("off hand holds the sword",
		roster.equipped_item(0, Equip.Position.OFF_HAND) == spare_sword)

	# A bow in the main hand should clear the off hand.
	var bow = null
	for g in roster.gear_stash:
		if g.weapon_type == GearDefinition.WeaponType.BOW:
			bow = g
			break
	roster.equip_gear(0, bow, Equip.Position.MAIN_HAND)
	_ok("bow cleared off hand",
		roster.equipped_item(0, Equip.Position.OFF_HAND) == null)
	_ok("bow flips hero0 to ranged", roster.is_ranged(0))

	get_tree().quit()
