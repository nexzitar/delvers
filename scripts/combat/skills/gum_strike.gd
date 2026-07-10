## Gum Strike: the oil slick smears the target's arms - swings come
## slow and heavy until it wears off. Skipped while already gummed.

const DURATION := 6.0
const SLOW_MULT := 1.6

static func try_use(state, caster, skill) -> bool:
	var target = state.entity_by_id(caster.target_id)
	if target == null or not target.alive:
		return false
	if not state.can_use_skill_on(caster, skill, target):
		return false
	for status in target.statuses:
		if status.id == "gum_strike" and status.remaining > 0.0:
			return false

	var damage = caster.attack_power + randi_range(
		skill.base_min_damage, skill.base_max_damage
	)
	caster._strike(state, skill, target, damage)
	if target.alive:
		state.apply_status(
			target, StatusEffect.Kind.SLUGGISH, DURATION, SLOW_MULT,
			"gum_strike", caster.entity_id
		)
	return true
