extends Node

## Simulates real delves end-to-end (encounter roll -> battle -> drop
## roll) and checks the iron economy: a failed run must still bring
## home iron.

func _ready():
	var controller = TheaterController3D.new()
	var delver = load("res://resources/heroes/default_delver.tres").duplicate(true)
	delver.equipped = {
		Equip.Position.MAIN_HAND: LootTable.materialize("starter_sword", 1, 0),
		Equip.Position.OFF_HAND: LootTable.materialize("starter_shield", 1, 0),
		Equip.Position.HEAD: LootTable.materialize("starter_helmet", 1, 0),
		Equip.Position.CHEST: LootTable.materialize("starter_armor", 1, 0),
	}

	var warrior_seen := 0
	var iron_total := 0
	var runs := 60
	for run in runs:
		var health := -1
		for room in range(1, 11):
			var encounter = controller.roll_encounter(room)
			for template in encounter:
				if template.enemy_id == "goblin_warrior":
					warrior_seen += 1
			var combat = CombatState.new()
			combat.enemy_level_bonus = (room - 1) / 4
			var entry = {} if health < 0 else {0: health}
			combat.setup_combat([delver], encounter, null, entry)
			var steps := 0
			while not combat.combat_over and steps < 3000:
				combat.update(0.1)
				steps += 1
			if not combat.heroes[0].alive:
				break
			health = combat.heroes[0].current_health
			var slain = combat.enemies.map(func(e): return e.template)
			var drops = LootTable.roll_enemy_drops(slain, room)
			iron_total += drops.materials.get("iron_scrap", 0)

	assert(warrior_seen > 0, "warriors appear in encounters")
	var iron_per_run := float(iron_total) / runs
	print("warriors seen: %d, iron per run: %.1f" % [warrior_seen, iron_per_run])
	assert(iron_per_run >= 1.5, "a run brings home iron (shield within two runs)")

	print("PASS iron economy")
	get_tree().quit()
