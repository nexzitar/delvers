## Heal: restores the most-injured living ally in range and sight.
## Threat lands on the healer, split across all enemies in combat.

const MIN_MISSING := 5

static func try_use(state, caster, skill) -> bool:
	var allies = (
		state.heroes if caster.team == CombatEntity.Team.HERO
		else state.enemies
	)
	var best = null
	var best_missing := MIN_MISSING - 1
	for ally in allies:
		if not ally.alive:
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

	var amount = randi_range(skill.base_min_damage, skill.base_max_damage)
	amount = mini(amount, best_missing)
	best.current_health += amount
	state.log_heal(caster, best, skill, amount)

	var engaged = state.enemies.filter(func(e): return e.alive and e.in_combat)
	for enemy in engaged:
		Threat.add_heal_split(
			enemy.threat_table, caster.entity_id,
			amount * skill.threat_modifier, engaged.size()
		)
	return true
