## Web Shot: the weaver hurls silk that roots the target in place.
## Skipped while the target is already webbed.

const ROOT_DURATION := 1.4

static func try_use(state, caster, skill) -> bool:
	var target = state.entity_by_id(caster.target_id)
	if target == null or not target.alive:
		return false
	if not state.can_use_skill_on(caster, skill, target):
		return false
	for status in target.statuses:
		if status.id == "web_root" and status.remaining > 0.0:
			return false

	var damage = caster.attack_power + randi_range(
		skill.base_min_damage, skill.base_max_damage
	)
	caster._strike(state, skill, target, damage)
	if target.alive:
		state.apply_status(
			target, StatusEffect.Kind.ROOT, ROOT_DURATION, 1.0,
			"web_root", caster.entity_id
		)
	return true
