## Shield Wall: plant and endure — incoming damage nearly halves for a
## few seconds. Raised when hurt with enemies at the gate.

const TRIGGER_HEALTH := 0.7
const NEARBY := 90.0
const FACTOR := 0.55
const DURATION := 4.0

static func try_use(state, caster, skill) -> bool:
	if caster.current_health >= caster.max_health * TRIGGER_HEALTH:
		return false
	var opponents = state.enemies if caster.team == CombatEntity.Team.HERO \
		else state.heroes
	var threatened := false
	for foe in opponents:
		if foe.alive and caster.position.distance_to(foe.position) <= NEARBY:
			threatened = true
	if not threatened:
		return false
	for status in caster.statuses:
		if status.id == "shield_wall" and status.remaining > 0.0:
			return false

	state.apply_status(
		caster, StatusEffect.Kind.FORTIFY, DURATION, FACTOR,
		"shield_wall", caster.entity_id
	)
	return true
