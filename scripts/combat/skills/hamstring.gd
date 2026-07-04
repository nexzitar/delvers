## Hamstring: melee strike that slows the target's movement. Skipped
## while the target is already hamstrung, so it doesn't burn the beat.

const SLOW_DURATION := 6.0
const SLOW_FACTOR := 0.5

static func try_use(state, caster, skill) -> bool:
	var target = state.entity_by_id(caster.target_id)
	if target == null or not target.alive:
		return false
	if not state.can_use_skill_on(caster, skill, target):
		return false
	for status in target.statuses:
		if status.id == "hamstring_slow" and status.remaining > 0.0:
			return false

	var damage = caster.attack_power + randi_range(
		skill.base_min_damage, skill.base_max_damage
	)
	caster._strike(state, skill, target, damage)
	if target.alive:
		state.apply_status(
			target, StatusEffect.Kind.SLOW, SLOW_DURATION, SLOW_FACTOR,
			"hamstring_slow"
		)
	return true
