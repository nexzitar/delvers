extends Node

## The heightfield contracts: the delve descends, ramps carry the
## spine, cliffs stop paths, and ridges block sightlines.

func _ready():
	# --- Cliffs are not neighbors; ramps are ---------------------------
	var arena = BattleArena.new()
	arena.width = 10
	arena.height = 3
	arena.tile_size = 32
	var heights := {}
	for y in 3:
		for x in 10:
			heights[Vector2i(x, y)] = 1.0 if x >= 5 else 0.0
	arena.heights = heights
	var grid = BattleGrid.new(arena)
	assert(not grid.step_ok(Vector2i(4, 1), Vector2i(5, 1)), "a ledge is a wall")
	var pathfinder = GridPathfinder.new(grid)
	var blocked_path = pathfinder.find_path(Vector2i(1, 1), Vector2i(8, 1), {})
	assert(blocked_path.is_empty(), "no path up a cliff")
	# Cut a ramp through the middle row.
	for x in range(3, 8):
		arena.heights[Vector2i(x, 1)] = lerpf(0.0, 1.0, float(x - 3) / 4.0)
	grid = BattleGrid.new(arena)
	pathfinder = GridPathfinder.new(grid)
	var ramp_path = pathfinder.find_path(Vector2i(1, 1), Vector2i(8, 1), {})
	assert(not ramp_path.is_empty(), "the ramp carries the path")

	# --- Ridges block sightlines ---------------------------------------
	var ridge = BattleArena.new()
	ridge.width = 9
	ridge.height = 1
	ridge.tile_size = 32
	ridge.heights = {Vector2i(4, 0): 2.0}
	var ridge_grid = BattleGrid.new(ridge)
	assert(not ridge_grid.has_los(Vector2(48, 16), Vector2(240, 16)),
		"a ridge hides the far side")
	assert(ridge_grid.has_los(Vector2(48, 16), Vector2(112, 16)),
		"same shelf still sees")

	# --- The compiled dungeon descends and stays walkable ---------------
	var rng = RandomNumberGenerator.new()
	rng.seed = 11
	var darkwood = load("res://resources/dungeons/darkwood.tres")
	var layout = DungeonLayout.generate(darkwood, rng)
	assert(not layout.arena.heights.is_empty(), "the dungeon has ground")
	var first = layout.arena.heights.get(
		Vector2i(layout.waypoints[0] / 32.0), 0.0)
	var last = layout.arena.heights.get(
		Vector2i(layout.waypoints[layout.waypoints.size() - 1] / 32.0), 0.0)
	assert(first > last, "the delve descends toward the boss")
	var wgrid = BattleGrid.new(layout.arena)
	var wpath = GridPathfinder.new(wgrid)
	var spine = wpath.find_path(
		wgrid.world_to_tile(layout.waypoints[0]),
		wgrid.world_to_tile(layout.waypoints[layout.waypoints.size() - 1]), {})
	assert(not spine.is_empty(), "the descent is walkable end to end")

	# --- And a full delve still terminates ------------------------------
	seed(20260712)
	var delver = preload("res://resources/heroes/default_delver.tres")
	var combat = CombatState.new()
	combat.setup_delve([delver, delver], layout)
	var guard := 30000
	while not combat.combat_over and guard > 0:
		combat.update(0.1)
		guard -= 1
	assert(combat.combat_over, "an elevated Darkwood terminates")

	print("PASS test_elevation")
	get_tree().quit()
