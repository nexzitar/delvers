extends Node

## Simulates real delves end-to-end (encounter roll -> battle -> drop
## roll) and checks the iron economy: a failed run must still bring
## home iron.

func _ready():
	var controller = TheaterController3D.new()
	var delver = load("res://resources/heroes/default_delver.tres").duplicate(true)
	# A representative delver (a few runs in, heal slotted), not a
	# worst-case scrub: this measures the economy, not the difficulty
	# cliff at room one.
	var heal_kit: Array[SkillDefinition] = [load("res://resources/skills/heal.tres")]
	delver.bonus_skills = heal_kit
	delver.equipped = {
		Equip.Position.MAIN_HAND: LootTable.materialize("starter_sword", 3, 1),
		Equip.Position.OFF_HAND: LootTable.materialize("starter_shield", 3, 1),
		Equip.Position.HEAD: LootTable.materialize("starter_helmet", 3, 1),
		Equip.Position.CHEST: LootTable.materialize("starter_armor", 3, 1),
	}

	var warrior_seen := 0
	var iron_total := 0
	var gel_total := 0
	var slimes_slain := 0
	var rooms_cleared := 0
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
			rooms_cleared += 1
			for t in slain:
				if t.enemy_id == "green_slime":
					slimes_slain += 1
			var drops = LootTable.roll_enemy_drops(slain, room)
			iron_total += drops.materials.get("iron_scrap", 0)
			gel_total += drops.materials.get("gel", 0)

	assert(warrior_seen > 0, "warriors appear in encounters")
	var iron_per_run := float(iron_total) / runs
	var gel_per_run := float(gel_total) / runs
	print("warriors seen: %d, iron per run: %.1f, gel per run: %.1f" % [
		warrior_seen, iron_per_run, gel_per_run])
	print("rooms cleared: %d, slimes slain: %d" % [rooms_cleared, slimes_slain])
	assert(iron_per_run >= 0.8, "a run brings home iron")
	assert(gel_per_run >= 0.5, "the binder flows too")
	assert(iron_per_run / maxf(gel_per_run, 0.01) <= 3.0,
		"iron never drowns the binder (supply tracks demand)")

	print("PASS iron economy")
	get_tree().quit()
