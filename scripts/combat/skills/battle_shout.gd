## Battle Shout: the whole party fights harder for a while. A guild
## technique — anyone can carry a voice.

const ATTACK_BONUS := 2.0
const DURATION := 8.0
## The shout is LOUD: threat per ally emboldened, split across the
## pack — the tank's opener.
const THREAT_PER_ALLY := 10.0

static func try_use(state, caster, skill) -> bool:
	var enemies_up := false
	for enemy in state.enemies:
		if enemy.alive and enemy.in_combat:
			enemies_up = true
	if not enemies_up:
		return false
	var allies = state.heroes if caster.team == CombatEntity.Team.HERO \
		else state.enemies
	for ally in allies:
		if ally.alive:
			for status in ally.statuses:
				if status.id == "battle_shout" and status.remaining > 0.0:
					return false
	var emboldened := 0
	for ally in allies:
		if ally.alive:
			emboldened += 1
			state.apply_status(
				ally, StatusEffect.Kind.EMPOWER, DURATION, ATTACK_BONUS,
				"battle_shout", caster.entity_id
			)
	var engaged = state.enemies.filter(func(e): return e.alive and e.in_combat)
	for enemy in engaged:
		Threat.add_heal_split(
			enemy.threat_table, caster.entity_id,
			THREAT_PER_ALLY * emboldened, engaged.size()
		)
	return true
