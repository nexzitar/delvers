## Rally: a heartening cry that mends the whole party a little.
## A guild technique for anyone with breath to spare.

const MIN_TOTAL_MISSING := 12

static func try_use(state, caster, skill) -> bool:
	if caster.current_mana < skill.mana_cost:
		return false
	var allies = state.heroes if caster.team == CombatEntity.Team.HERO \
		else state.enemies
	var missing := 0
	for ally in allies:
		if ally.alive:
			missing += ally.max_health - ally.current_health
	if missing < MIN_TOTAL_MISSING:
		return false

	caster.current_mana -= skill.mana_cost
	var engaged = state.enemies.filter(func(e): return e.alive and e.in_combat)
	for ally in allies:
		if not ally.alive:
			continue
		var amount = mini(
			randi_range(skill.base_min_damage, skill.base_max_damage)
				+ caster.spell_power / 2,
			ally.max_health - ally.current_health
		)
		if amount <= 0:
			continue
		ally.current_health += amount
		state.log_heal(caster, ally, skill, amount)
		for enemy in engaged:
			Threat.add_heal_split(
				enemy.threat_table, caster.entity_id,
				amount * 0.5, engaged.size()
			)
	return true
