## Charge: gap-closer. The caster rushes its target in a straight line,
## stops at melee contact, and stuns it briefly. Only worth the beat
## when the target is genuinely far away.

const MIN_DISTANCE := 120.0
const CONTACT_DISTANCE := 40.0
const STUN_DURATION := 1.5
const DEBUFF_THREAT := 10.0

static func try_use(state, caster, skill) -> bool:
	var target = state.entity_by_id(caster.target_id)
	if target == null or not target.alive:
		return false
	if caster.is_rooted():
		return false
	var dist = caster.position.distance_to(target.position)
	if dist < MIN_DISTANCE or dist > skill.range:
		return false
	if not state.grid.has_los(caster.position, target.position):
		return false

	var direction = (target.position - caster.position).normalized()
	caster.position = state.grid.clamp_world(
		target.position - direction * CONTACT_DISTANCE
	)
	caster.facing = direction
	state.stop_movement(caster)
	state.log_forced_move(caster)

	state.apply_status(
		target, StatusEffect.Kind.STUN, STUN_DURATION, 1.0, "charge_stun"
	)
	if target.team == CombatEntity.Team.ENEMY:
		Threat.add_aoe(
			target.threat_table, caster.entity_id,
			DEBUFF_THREAT, skill.threat_modifier
		)
	return true
