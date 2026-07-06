## Renew: a mending charm that keeps healing after the cast — cheap,
## instant, and steady where Heal is a big slow burst.

const MIN_MISSING := 8
const HEAL_PER_SECOND := 2.0
const DURATION := 8.0

static func try_use(state, caster, skill) -> bool:
	if caster.current_mana < skill.mana_cost:
		return false
	var allies = state.heroes if caster.team == CombatEntity.Team.HERO \
		else state.enemies
	var best = null
	var best_missing := MIN_MISSING - 1
	for ally in allies:
		if not ally.alive:
			continue
		var already := false
		for status in ally.statuses:
			if status.id == "renew_hot" and status.remaining > 0.0:
				already = true
		if already:
			continue
		var missing = ally.max_health - ally.current_health
		if missing <= best_missing:
			continue
		if caster.position.distance_to(ally.position) > skill.range:
			continue
		if not state.grid.has_los(caster.position, ally.position):
			continue
		best = ally
		best_missing = missing
	if best == null:
		return false

	caster.current_mana -= skill.mana_cost
	state.apply_status(
		best, StatusEffect.Kind.REGEN, DURATION, HEAL_PER_SECOND,
		"renew_hot", caster.entity_id
	)
	var engaged = state.enemies.filter(func(e): return e.alive and e.in_combat)
	for enemy in engaged:
		Threat.add_heal_split(
			enemy.threat_table, caster.entity_id,
			HEAL_PER_SECOND * DURATION * 0.5, engaged.size()
		)
	return true
