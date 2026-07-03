extends Node

const GridPathfinder = preload("res://scripts/combat/grid_pathfinder.gd")
const BattleGrid = preload("res://scripts/combat/battle_grid.gd")

func _ready():
	var arena = load("res://resources/arenas/open_arena.tres").duplicate()
	var blocked: Array[Vector2i] = [
		Vector2i(10, 10), Vector2i(10, 11), Vector2i(10, 12),
	]
	arena.blocked_tiles = blocked
	var grid = BattleGrid.new(arena)
	var pf = GridPathfinder.new(grid)
	var path = pf.find_path(Vector2i(8, 11), Vector2i(12, 11))
	assert(not path.is_empty(), "path exists")
	for wp in path:
		var cell = grid.world_to_tile(wp)
		assert(cell != Vector2i(10, 11), "avoids pillar")
	print("PASS pathfinder")
	get_tree().quit()
