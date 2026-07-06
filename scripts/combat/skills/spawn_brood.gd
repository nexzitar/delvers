## Spawn Brood: the tender births spiderlings into the fight. Kill the
## tender first, or drown — the Nest's lesson.

const SPAWN_COUNT := 2
const MAX_BROOD := 4

static func try_use(state, caster, skill) -> bool:
	if not caster.in_combat:
		return false
	var live := 0
	for enemy in state.enemies:
		if enemy.alive and enemy.spawned_by == caster.entity_id:
			live += 1
	if live >= MAX_BROOD:
		return false

	var spiderling = load("res://resources/enemies/nest_spiderling.tres")
	for i in SPAWN_COUNT:
		state.spawn_reinforcement(
			spiderling, maxi(1, caster.level - 1),
			caster.position, caster.entity_id
		)
	return true
