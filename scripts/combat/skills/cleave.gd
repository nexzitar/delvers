## Cleave: the swing carries through the target into up to two foes
## beside it, at reduced force.

const SPLASH_RADIUS := 70.0
const SPLASH_FACTOR := 0.7
const MAX_SPLASH := 2

static func try_use(state, caster, skill) -> bool:
	var target = state.entity_by_id(caster.target_id)
	if target == null or not target.alive:
		return false
	if not state.can_use_skill_on(caster, skill, target):
		return false

	var damage = caster.attack_power + randi_range(
		skill.base_min_damage, skill.base_max_damage
	)
	caster._strike(state, skill, target, damage)

	var opponents = state.enemies if caster.team == CombatEntity.Team.HERO \
		else state.heroes
	var splashed := 0
	for foe in opponents:
		if splashed >= MAX_SPLASH:
			break
		if foe == target or not foe.alive:
			continue
		if foe.position.distance_to(target.position) > SPLASH_RADIUS:
			continue
		caster._strike(state, skill, foe, maxi(1, roundi(damage * SPLASH_FACTOR)))
		splashed += 1
	return true
