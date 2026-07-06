## Thunderclap: a stamped shockwave — small damage to everything close,
## their swings dragged slow, and the noise pulls every eye to the
## caster (triple threat). The tank button.

const RADIUS := 90.0
const MIN_TARGETS := 2
const DAZE_FACTOR := 0.7
const DAZE_DURATION := 4.0

static func try_use(state, caster, skill) -> bool:
	var opponents = state.enemies if caster.team == CombatEntity.Team.HERO \
		else state.heroes
	var near := []
	for foe in opponents:
		if foe.alive and caster.position.distance_to(foe.position) <= RADIUS:
			near.append(foe)
	if near.size() < MIN_TARGETS:
		return false

	for foe in near:
		var damage = caster.attack_power / 2 + randi_range(
			skill.base_min_damage, skill.base_max_damage
		)
		caster._strike(state, skill, foe, damage)
		if foe.alive:
			state.apply_status(
				foe, StatusEffect.Kind.SLUGGISH, DAZE_DURATION, DAZE_FACTOR,
				"thunderclap_daze", caster.entity_id
			)
	return true
