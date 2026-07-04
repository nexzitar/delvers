extends Node

const Threat = preload("res://scripts/combat/threat.gd")
const CombatEntity = preload("res://scripts/combat/combat_entity.gd")

func _ready():
	var table = {}
	Threat.add_damage(table, 1, 10.0)
	assert(table[1] == 10.0, "damage threat")

	table = {}
	Threat.add_heal_split(table, 5, 10.0, 5)
	assert(is_equal_approx(table[5], 2.0), "heal split by enemy count")

	var enemy = CombatEntity.new()
	enemy.position = Vector2(200, 0)
	enemy.threat_table = {1: 50.0, 2: 30.0}
	var heroes = {1: Vector2(0, 0), 2: Vector2(150, 0)}
	# Hero 1 has highest threat but is out of range; hero 2 is in range.
	var pick = Threat.pick_target(
		enemy, heroes, 80.0,
		func(_id, pos): return enemy.position.distance_to(pos) <= 80.0
	)
	assert(pick == 2, "falls through to in-range target")

	print("PASS threat")
	get_tree().quit()
