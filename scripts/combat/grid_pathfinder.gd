class_name GridPathfinder

var _grid

func _init(grid):
	_grid = grid

func find_path(from_cell: Vector2i, to_cell: Vector2i) -> PackedVector2Array:
	if from_cell == to_cell:
		return PackedVector2Array([_grid.tile_to_world(to_cell)])

	if not _grid.is_walkable(from_cell) or not _grid.is_walkable(to_cell):
		return PackedVector2Array()

	var open: Array[Vector2i] = [from_cell]
	var came_from: Dictionary = {}
	var g_score: Dictionary = {from_cell: 0}
	var f_score: Dictionary = {from_cell: _heuristic(from_cell, to_cell)}

	while not open.is_empty():
		open.sort_custom(func(a, b): return f_score.get(a, INF) < f_score.get(b, INF))
		var current: Vector2i = open[0]
		open.remove_at(0)

		if current == to_cell:
			return _reconstruct_path(came_from, current)

		for neighbor in _neighbors(current):
			if not _grid.is_walkable(neighbor):
				continue
			var tentative = g_score.get(current, INF) + 1
			if tentative >= g_score.get(neighbor, INF):
				continue
			came_from[neighbor] = current
			g_score[neighbor] = tentative
			f_score[neighbor] = tentative + _heuristic(neighbor, to_cell)
			if neighbor not in open:
				open.append(neighbor)

	return PackedVector2Array()

func _neighbors(cell: Vector2i) -> Array[Vector2i]:
	return [
		Vector2i(cell.x + 1, cell.y),
		Vector2i(cell.x - 1, cell.y),
		Vector2i(cell.x, cell.y + 1),
		Vector2i(cell.x, cell.y - 1),
	]

func _heuristic(a: Vector2i, b: Vector2i) -> float:
	return float(absi(a.x - b.x) + absi(a.y - b.y))

func _reconstruct_path(came_from: Dictionary, current: Vector2i) -> PackedVector2Array:
	var cells: Array[Vector2i] = [current]
	while came_from.has(current):
		current = came_from[current]
		cells.push_front(current)

	var waypoints := PackedVector2Array()
	for cell in cells:
		waypoints.append(_grid.tile_to_world(cell))
	return waypoints
