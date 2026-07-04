extends Node

const StatusEffect = preload("res://scripts/combat/status_effect.gd")

## Damage pulls the pack into combat and accrues threat; enemies chase
## top threat when free but fall through to in-range heroes when rooted.

func _ready():
	var delver = load("res://resources/heroes/default_delver.tres")
	var slime_t = load("res://resources/enemies/green_slime.tres")

	var combat = CombatState.new()
	combat.setup_combat([delver, delver], [slime_t])
	var h1 = combat.heroes[0]
	var h2 = combat.heroes[1]
	var enemy = combat.enemies[0]

	h1.perform_auto_attack(combat, enemy)
	assert(enemy.threat_table.get(h1.entity_id, 0.0) > 0.0, "damage adds threat")
	assert(
		combat.enemies.all(func(e): return e.in_combat),
		"first blood aggros the pack"
	)

	# Rooted with the top threat out of reach: switch to the near hero.
	enemy.threat_table = {h1.entity_id: 100.0, h2.entity_id: 1.0}
	h1.position = enemy.position + Vector2(500, 0)
	h2.position = enemy.position + Vector2(40, 0)
	var root = StatusEffect.new()
	root.kind = StatusEffect.Kind.ROOT
	root.remaining = 5.0
	enemy.statuses = [root]
	enemy.target_id = -1
	combat.validate_target(enemy)
	assert(enemy.target_id == h2.entity_id, "rooted enemy picks reachable hero")

	# Freed, it goes back to chasing the top threat.
	enemy.statuses = []
	enemy.target_id = -1
	combat.validate_target(enemy)
	assert(enemy.target_id == h1.entity_id, "top threat wins when free to chase")

	var target_events = combat.combat_log.events.filter(
		func(e): return e.type == CombatEvent.EventType.TARGET
	)
	assert(target_events.size() >= 2, "TARGET events logged")

	print("PASS threat targeting")
	get_tree().quit()
