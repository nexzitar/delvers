## Heal: a real cast — mana cost and a wind-up instead of a cooldown.
## Used whenever an ally needs it and the mana is there; the cast time
## and the mana pool are what keep it from being spam.
## Threat lands on the healer, split across all enemies in combat.

const MIN_MISSING := 5
const CAST_TIME := 1.4

static func _most_injured(state, caster, skill):
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
	return best

static func try_use(state, caster, skill) -> bool:
	if caster.current_mana < skill.mana_cost:
		return false
	if _most_injured(state, caster, skill) == null:
		return false
	caster.start_behavior_cast(state, skill, CAST_TIME)
	return true

## Cast complete: re-pick the most injured ally (the fight moved on
## during the wind-up). A fizzle costs no mana.
static func finish(state, caster, skill):
	var best = _most_injured(state, caster, skill)
	if best == null:
		return
	caster.current_mana -= skill.mana_cost

	var amount = randi_range(skill.base_min_damage, skill.base_max_damage)
	amount += caster.spell_power
	amount = mini(amount, best.max_health - best.current_health)
	best.current_health += amount
	state.log_heal(caster, best, skill, amount)

	var engaged = state.enemies.filter(func(e): return e.alive and e.in_combat)
	for enemy in engaged:
		Threat.add_heal_split(
			enemy.threat_table, caster.entity_id,
			amount * skill.threat_modifier, engaged.size()
		)
