extends Node

const BattleGrid = preload("res://scripts/combat/battle_grid.gd")

func _arena(blocked: Array[Vector2i] = []):
	var arena = load("res://resources/arenas/open_arena.tres").duplicate()
	arena.blocked_tiles = blocked
	return arena

func _ready():
	var grid = BattleGrid.new(_arena())
	assert(grid.is_walkable(Vector2i(5, 5)), "open cell")

	grid = BattleGrid.new(_arena([Vector2i(5, 5)]))
	assert(not grid.is_walkable(Vector2i(5, 5)), "blocked")

	grid = BattleGrid.new(_arena([Vector2i(10, 5), Vector2i(10, 6)]))
	assert(
		not grid.has_los(Vector2(9 * 32, 5 * 32), Vector2(11 * 32, 5 * 32)),
		"pillar blocks"
	)
	assert(
		grid.has_los(Vector2(9 * 32, 4 * 32), Vector2(11 * 32, 4 * 32)),
		"clear row"
	)
	print("PASS grid los")
	get_tree().quit()
