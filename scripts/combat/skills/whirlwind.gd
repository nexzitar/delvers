## Whirlwind: strike everything around the caster. Held back until at
## least two foes stand close, so the beat is never wasted.

const RADIUS := 90.0
const MIN_TARGETS := 2

static func try_use(state, caster, skill) -> bool:
	var opponents = state.enemies if caster.team == CombatEntity.Team.HERO \
		else state.heroes
	var near := []
	for foe in opponents:
		if foe.alive and caster.position.distance_to(foe.position) <= RADIUS:
			near.append(foe)
	if near.size() < MIN_TARGETS:
		return false

	for foe in near:
		var damage = caster.attack_power + randi_range(
			skill.base_min_damage, skill.base_max_damage
		)
		caster._strike(state, skill, foe, damage)
	return true
