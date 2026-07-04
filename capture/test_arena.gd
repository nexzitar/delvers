extends Node

func _ready():
	var arena = load("res://resources/arenas/open_arena.tres")
	assert(arena.width == 30 and arena.height == 20, "arena size")
	assert(arena.blocked_tiles.is_empty(), "MVP open")
	print("PASS arena loads")
	get_tree().quit()
