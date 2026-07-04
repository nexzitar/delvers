extends Node

## Stress: the real PlayerRoster party against many random encounter
## rolls — every battle must terminate.

const GREEN_SLIME = preload("res://resources/enemies/green_slime.tres")
const GOBLIN_ARCHER = preload("res://resources/enemies/goblin_archer.tres")

func _ready():
	var roster = load("res://scripts/game/player_roster.gd").new()
	add_child(roster)

	for trial in 12:
		var encounter = []
		for i in randi_range(2, 4):
			encounter.append([GREEN_SLIME, GREEN_SLIME, GOBLIN_ARCHER].pick_random())

		var combat = CombatState.new()
		combat.setup_combat(roster.heroes, encounter)
		var steps := 0
		while not combat.combat_over and steps < 3000:
			combat.update(0.1)
			steps += 1
		if steps >= 3000:
			var names = encounter.map(func(t): return t.enemy_id)
			print("FAIL stalled on trial %d vs %s" % [trial, names])
			get_tree().quit()
			return

	print("PASS roster battles all finished")
	get_tree().quit()
