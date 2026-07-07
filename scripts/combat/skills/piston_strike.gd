## Piston Strike: the machine's full weight, delivered through
## whatever you are holding up. Armor is not the answer. Not being
## there is.

const MULT := 2.5

static func try_use(state, caster, skill) -> bool:
	var target = state.entity_by_id(caster.target_id)
	if target == null or not target.alive:
		return false
	if not state.can_use_skill_on(caster, skill, target):
		return false

	var damage = int(caster.attack_power * MULT) + randi_range(
		skill.base_min_damage, skill.base_max_damage
	)
	caster._strike(state, skill, target, damage, false, true)
	return true
