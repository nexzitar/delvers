extends Node

## Ranged attacks respect line of sight and fire from range: an archer
## can't shoot through a wall, and in the open it looses arrows long
## before reaching melee.

func _ready():
	var bow = load("res://resources/gear/starter_bow.tres")
	var arrow_shot = load("res://resources/skills/arrow_shot.tres")

	var archer_t = load("res://resources/heroes/default_delver.tres").duplicate(true)
	archer_t.equipped = {Equip.Position.MAIN_HAND: bow}
	var skills_arr: Array[SkillDefinition] = [arrow_shot]
	archer_t.starting_skills = skills_arr

	var slime_t = load("res://resources/enemies/green_slime.tres")

	# A full wall splits the arena: in bow range, but no LoS and no path.
	var walled = load("res://resources/arenas/open_arena.tres").duplicate()
	var wall: Array[Vector2i] = []
	for y in 20:
		wall.append(Vector2i(15, y))
	walled.blocked_tiles = wall

	var combat = CombatState.new()
	combat.setup_combat([archer_t], [slime_t], walled)
	combat.heroes[0].position = combat.grid.tile_to_world(Vector2i(13, 10))
	combat.enemies[0].position = combat.grid.tile_to_world(Vector2i(17, 10))
	assert(combat.heroes[0].weapon_reach > 300.0, "bow reach applied")
	for i in 100:
		combat.update(0.1)
	var hits = combat.combat_log.events.filter(
		func(e): return e.type == CombatEvent.EventType.DAMAGE
	)
	assert(hits.is_empty(), "no shooting through walls")

	# Open field: first blood is an arrow loosed from range, not melee.
	var combat2 = CombatState.new()
	combat2.setup_combat([archer_t], [slime_t])
	var steps := 0
	while combat2.combat_log.events.all(
		func(e): return e.type != CombatEvent.EventType.DAMAGE
	):
		combat2.update(0.1)
		steps += 1
		assert(steps < 600, "combat progresses")
	var dist = combat2.heroes[0].position.distance_to(combat2.enemies[0].position)
	assert(dist > 100.0, "fired from range, not melee")

	print("PASS range los")
	get_tree().quit()
