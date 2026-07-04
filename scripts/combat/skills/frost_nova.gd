## Frost Nova: instant AoE around the caster that roots everything
## hostile caught in the radius for ROOT_DURATION.

const ROOT_DURATION := 3.0
const DEBUFF_THREAT := 10.0

static func try_use(state, caster, skill) -> bool:
	var victims = []
	for foe in state.opponents_of(caster):
		if foe.alive and caster.position.distance_to(foe.position) <= skill.aoe_radius:
			victims.append(foe)
	if victims.is_empty():
		return false

	if skill.telegraph_duration > 0.0:
		state.combat_log.add_event(CombatEvent.create_telegraph(
			caster.entity_id, state.combat_time,
			caster.position, skill.aoe_radius, skill.telegraph_duration
		))

	for victim in victims:
		state.apply_status(
			victim, StatusEffect.Kind.ROOT, ROOT_DURATION, 1.0, "frost_nova_root"
		)
		if victim.team == CombatEntity.Team.ENEMY:
			Threat.add_aoe(
				victim.threat_table, caster.entity_id,
				DEBUFF_THREAT, skill.threat_modifier
			)
	return true
