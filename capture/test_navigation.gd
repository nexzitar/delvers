extends Node

## Crowd navigation: attackers fan around a queue instead of forming
## one, and a blocker between you and your target gets flanked, not
## bulldozed.

func _ready():
	var delver = load("res://resources/heroes/default_delver.tres").duplicate(true)
	delver.equipped = {
		Equip.Position.MAIN_HAND: LootTable.materialize("starter_sword", 5, 1),
	}
	var slime = load("res://resources/enemies/green_slime.tres")

	# The swarm test: six melee foes on one hero. Without side-stepping
	# they queue in a line; with crowd-aware paths most reach the fight.
	var combat = CombatState.new()
	combat.setup_combat([delver], [slime, slime, slime, slime, slime, slime])
	var hero = combat.heroes[0]
	hero.current_health = 100000
	hero.max_health = 100000
	# Line them up single file behind each other, all hunting the hero.
	for i in combat.enemies.size():
		combat.enemies[i].position = hero.position + Vector2(120 + i * 40, 0)
		combat.enemies[i].current_health = 100000
		combat.enemies[i].max_health = 100000
	var steps := 0
	while steps < 120:
		combat.update(0.1)
		steps += 1
	var engaged := 0
	for foe in combat.enemies:
		if combat.in_attack_range(foe, hero):
			engaged += 1
	print("engaged after 12s: ", engaged, "/6")
	assert(engaged >= 4, "the swarm fans out around the queue")

	# The bulldozer test: a blocker stands between the hero and its
	# mark. The hero must flank, not push the blocker into the target.
	var combat2 = CombatState.new()
	combat2.setup_combat([delver], [slime, slime])
	var pusher = combat2.heroes[0]
	pusher.current_health = 100000
	pusher.max_health = 100000
	var blocker = combat2.enemies[0]
	var mark = combat2.enemies[1]
	blocker.position = pusher.position + Vector2(80, 0)
	mark.position = pusher.position + Vector2(200, 0)
	for foe in combat2.enemies:
		foe.current_health = 100000
		foe.max_health = 100000
	# Force the hero onto the far mark; root the blocker's aggression.
	pusher.tactic = "priority"
	combat2.enemy_priority = [mark.template.enemy_id]
	pusher.behavior_tree = [{"when": [], "target": "lowest"}]
	mark.current_health = 50000
	var blocker_start = blocker.position
	steps = 0
	while steps < 100 and not combat2.in_attack_range(pusher, mark):
		combat2.update(0.1)
		steps += 1
	print("blocker displaced: %.0f px; reached mark: %s" % [
		blocker.position.distance_to(blocker_start),
		combat2.in_attack_range(pusher, mark)])
	assert(combat2.in_attack_range(pusher, mark), "the mark is reached")
	assert(blocker.position.distance_to(blocker_start) < 40.0,
		"the blocker is flanked, not bulldozed")

	print("PASS navigation")
	get_tree().quit()
