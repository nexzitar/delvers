class_name BattleGrid

var _arena
var _blocked: Dictionary = {}

func _init(arena):
	_arena = arena
	for t in arena.blocked_tiles:
		_blocked[t] = true

func is_walkable(cell: Vector2i) -> bool:
	if cell.x < 0 or cell.y < 0 or cell.x >= _arena.width or cell.y >= _arena.height:
		return false
	return not _blocked.has(cell)

func world_to_tile(p: Vector2) -> Vector2i:
	return Vector2i(
		floori(p.x / _arena.tile_size),
		floori(p.y / _arena.tile_size)
	)

func tile_to_world(cell: Vector2i) -> Vector2:
	var ts = _arena.tile_size
	return Vector2(cell.x * ts + ts * 0.5, cell.y * ts + ts * 0.5)

func has_los(from: Vector2, to: Vector2) -> bool:
	var a = world_to_tile(from)
	var b = world_to_tile(to)
	for cell in _bresenham(a, b):
		if _blocked.has(cell):
			return false
	return true

func _bresenham(a: Vector2i, b: Vector2i) -> Array[Vector2i]:
	var points: Array[Vector2i] = []
	var dx = absi(b.x - a.x)
	var dy = -absi(b.y - a.y)
	var sx = 1 if a.x < b.x else -1
	var sy = 1 if a.y < b.y else -1
	var err = dx + dy
	var x = a.x
	var y = a.y
	while true:
		points.append(Vector2i(x, y))
		if x == b.x and y == b.y:
			break
		var e2 = 2 * err
		if e2 >= dy:
			err += dy
			x += sx
		if e2 <= dx:
			err += dx
			y += sy
	return points
