extends SceneTree

## Headless checks for the loadout data layer: equipping a bow should
## flip a melee hero to a ranged back-row archer, swap its skill, and
## bench the shield; unequipping reverts the role.

func _init():
	# Autoloads aren't active in a bare SceneTree script, so build the
	# roster by hand to exercise its loadout logic in isolation.
	var roster = load("res://scripts/game/player_roster.gd").new()
	get_root().add_child(roster)
	roster._build_stash()

	var hero = roster.heroes[0]
	_p("start: %s, ranged=%s, row=%d, skill=%s, gear=%s" % [
		hero.hero_name, roster.is_ranged(0), hero.preferred_row,
		roster.attack_skill(0).skill_id, _gear_ids(hero)])

	# Find a bow in the stash and equip it on the melee hero.
	var bow = null
	for g in roster.gear_stash:
		if g.weapon_type == GearDefinition.WeaponType.BOW:
			bow = g
			break
	_assert(bow != null, "bow present in stash")

	var ok = roster.equip_gear(0, bow)
	_assert(ok, "equip bow returned true")
	_assert(roster.is_ranged(0), "hero is now ranged")
	_assert(hero.preferred_row == Formation.Row.BACK, "hero moved to back row")
	_assert(roster.attack_skill(0).skill_id == "arrow_shot", "skill is arrow_shot")
	_assert(roster.equipped_item(0, GearDefinition.Slot.OFF_HAND) == null,
		"shield benched when bow equipped")
	_p("after bow: ranged=%s, row=%d, skill=%s, gear=%s" % [
		roster.is_ranged(0), hero.preferred_row,
		roster.attack_skill(0).skill_id, _gear_ids(hero)])

	# Equip a sword back -> melee front again.
	var sword = null
	for g in roster.gear_stash:
		if g.weapon_type == GearDefinition.WeaponType.ONE_HANDED:
			sword = g
			break
	_assert(sword != null, "sword present in stash")
	roster.equip_gear(0, sword)
	_assert(not roster.is_ranged(0), "hero melee again")
	_assert(hero.preferred_row == Formation.Row.FRONT, "hero back to front row")
	_p("after sword: ranged=%s, row=%d, skill=%s, gear=%s" % [
		roster.is_ranged(0), hero.preferred_row,
		roster.attack_skill(0).skill_id, _gear_ids(hero)])

	# Rename.
	roster.rename_hero(0, "Sir Test")
	_assert(hero.hero_name == "Sir Test", "rename applied")

	_p("ALL CHECKS PASSED" if _failures == 0 else "FAILURES: %d" % _failures)
	quit()

var _failures := 0

func _gear_ids(hero) -> String:
	var ids = []
	for item in hero.starting_gear:
		ids.append(item.gear_id)
	return str(ids)

func _assert(cond, label):
	if cond:
		_p("  ok  - %s" % label)
	else:
		_failures += 1
		_p("  FAIL - %s" % label)

func _p(s):
	print(s)
