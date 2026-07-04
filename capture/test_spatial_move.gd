extends Node

## Melee combatants spawn apart, walk toward each other, and only then
## trade blows — with throttled MOVE events landing in the log.

func _ready():
	var delver = load("res://resources/heroes/default_delver.tres")
	var slime = load("res://resources/enemies/green_slime.tres")

	var combat = CombatState.new()
	combat.setup_combat([delver], [slime])

	var hero = combat.heroes[0]
	var enemy = combat.enemies[0]
	var start_dist = hero.position.distance_to(enemy.position)
	assert(start_dist > 200.0, "spawns apart")

	var steps := 0
	while combat.combat_log.events.all(
		func(e): return e.type != CombatEvent.EventType.DAMAGE
	):
		combat.update(0.1)
		steps += 1
		assert(steps < 600, "combat progresses")

	var dist_at_first_hit = hero.position.distance_to(enemy.position)
	assert(dist_at_first_hit < start_dist, "closed distance before striking")
	assert(dist_at_first_hit < 80.0, "struck at melee range")

	var moves = combat.combat_log.events.filter(
		func(e): return e.type == CombatEvent.EventType.MOVE
	)
	assert(moves.size() >= 3, "MOVE events logged")

	# A stationary attacker turns to face its target: put the enemy
	# BEHIND the hero within reach and tick once.
	var combat2 = CombatState.new()
	combat2.setup_combat([delver], [slime])
	var h = combat2.heroes[0]
	var e = combat2.enemies[0]
	e.position = h.position + Vector2(-40, 0)
	h.facing = Vector2.RIGHT
	h.last_logged_facing = Vector2.RIGHT
	combat2.update(0.1)
	assert(
		h.facing.dot((e.position - h.position).normalized()) > 0.95,
		"stationary hero turns toward target"
	)
	assert(
		combat2.combat_log.events.any(
			func(ev): return ev.type == CombatEvent.EventType.FACE \
				and ev.entity_id == h.entity_id
		),
		"turn logged as FACE event"
	)

	print("PASS spatial move")
	get_tree().quit()
