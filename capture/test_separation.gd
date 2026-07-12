extends Node

const Separation = preload("res://scripts/combat/separation.gd")

func _ready():
	var a = Vector2(100, 100)
	var b = Vector2(110, 100)
	var offset = Separation.compute_offset(a, [b], 24.0, 1.0)
	assert(offset.length() > 0.1, "pushes apart")

	# The push respects architecture: a body crowded against a pillar
	# slides along it instead of being shoved inside.
	var arena := BattleArena.new()
	arena.width = 8
	arena.height = 8
	arena.tile_size = 32
	arena.blocked_tiles = [Vector2i(4, 3)] as Array[Vector2i]
	var delver = load("res://resources/heroes/default_delver.tres")
	var combat := CombatState.new()
	combat.setup_combat([delver, delver], [], arena)
	var crowded = combat.heroes[0]
	var pusher = combat.heroes[1]
	# Pillar tile (4,3) spans x 128-160; stand just west of it with the
	# pusher directly behind so the raw push points into the stone.
	crowded.position = Vector2(120, 112)
	pusher.position = Vector2(112, 112)
	combat.nudge_separation(crowded)
	assert(combat.grid.world_to_tile(crowded.position) != Vector2i(4, 3),
		"separation must not push a body into a pillar")

	print("PASS separation")
	get_tree().quit()
