extends Node

func _ok(label, cond):
	print(("PASS " if cond else "FAIL ") + label)

func _ready():
	# Built by hand with autosave off, so the test neither reads nor
	# writes the player's real save.
	var roster = preload("res://scripts/game/player_roster.gd").new()
	roster.autosave = false
	roster._build_heroes()
	roster._build_stash()

	# Two independent heroes from the same base.
	_ok("two heroes", roster.heroes.size() == 2)

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

	# Displacing hero0's main-hand weapon returns it to the stash.
	_ok("displaced main-hand weapon returned to stash",
		roster.gear_stash.has(h0_main))

	# Hero 1's loadout is untouched by edits to hero 0.
	_ok("hero1 loadout untouched by hero0 edits",
		roster.equipped_item(1, Equip.Position.MAIN_HAND) != null \
		and roster.equipped_item(1, Equip.Position.MAIN_HAND) \
			!= roster.equipped_item(0, Equip.Position.MAIN_HAND))

	# A fresh HEAD-category stash item resolves to the HEAD position.
	var spare_head = null
	for g in roster.gear_stash:
		if g.slot == GearDefinition.Slot.HEAD:
			spare_head = g
			break
	_ok("found spare HEAD item", spare_head != null)
	_ok("default_position routes HEAD item to HEAD",
		roster.default_position(1, spare_head) == Equip.Position.HEAD)

	# The full MVP skill set is in the catalog, iconed and equippable.
	_ok("six skills known", roster.skill_catalog.size() == 6)
	_ok("all catalog skills have icons",
		roster.skill_catalog.all(func(s): return s.icon != null))
	var charge = roster.skill_catalog.filter(
		func(s): return s.skill_id == "charge"
	)
	_ok("charge in catalog", charge.size() == 1)
	_ok("charge equips into slot 2", roster.equip_bonus_skill(0, charge[0], 2))
	_ok("charge sits in loadout", roster.heroes[0].bonus_skills[1] == charge[0])

	get_tree().quit()
