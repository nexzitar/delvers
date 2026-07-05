## Venom Bite: the spider sinks its fangs in and leaves poison ticking
## in the wound. Skipped while the target is already envenomed, so the
## beat isn't wasted.

const POISON_DURATION := 6.0
const POISON_DPS := 1.2

static func try_use(state, caster, skill) -> bool:
	var target = state.entity_by_id(caster.target_id)
	if target == null or not target.alive:
		return false
	if not state.can_use_skill_on(caster, skill, target):
		return false
	for status in target.statuses:
		if status.id == "venom_bite_poison" and status.remaining > 0.0:
			return false

	var damage = caster.attack_power + randi_range(
		skill.base_min_damage, skill.base_max_damage
	)
	caster._strike(state, skill, target, damage)
	if target.alive:
		state.apply_status(
			target, StatusEffect.Kind.POISON, POISON_DURATION, POISON_DPS,
			"venom_bite_poison", caster.entity_id
		)
	return true
