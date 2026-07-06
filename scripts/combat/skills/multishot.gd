## Multishot: a fan of arrows into the nearest foes. The archer's
## answer to the swarm — held until at least two stand in range.

const MAX_TARGETS := 3
const MIN_TARGETS := 2

static func try_use(state, caster, skill) -> bool:
	if caster.main_weapon == null \
			or caster.main_weapon.weapon_type != GearDefinition.WeaponType.BOW:
		return false
	var opponents = state.enemies if caster.team == CombatEntity.Team.HERO \
		else state.heroes
	var in_reach := []
	for foe in opponents:
		if not foe.alive:
			continue
		if not state.can_use_skill_on(caster, skill, foe):
			continue
		in_reach.append(foe)
	if in_reach.size() < MIN_TARGETS:
		return false
	in_reach.sort_custom(func(a, b):
		return caster.position.distance_to(a.position) \
			< caster.position.distance_to(b.position))

	for i in mini(MAX_TARGETS, in_reach.size()):
		var damage = caster.attack_power \
			+ caster.main_weapon.roll_weapon_damage()
		caster._strike(state, skill, in_reach[i], damage)
	return true
