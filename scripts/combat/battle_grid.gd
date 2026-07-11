class_name BattleGrid

var _arena
var _blocked: Dictionary = {}

func _init(arena):
	_arena = arena
	for t in arena.blocked_tiles:
		_blocked[t] = true

const MAX_STEP := 0.34
## Head height for sightlines: a ridge must rise this far above both
## ends to hide one from the other.
const EYE_LEVEL := 0.6

func height_of(cell: Vector2i) -> float:
	return _arena.heights.get(cell, 0.0)

func height_at_world(p: Vector2) -> float:
	return height_of(world_to_tile(p))

## A step is walkable only if it is gentle: ramps yes, ledges no.
func step_ok(from_cell: Vector2i, to_cell: Vector2i) -> bool:
	return absf(height_of(from_cell) - height_of(to_cell)) <= MAX_STEP

func is_walkable(cell: Vector2i) -> bool:
	if cell.x < 0 or cell.y < 0 or cell.x >= _arena.width or cell.y >= _arena.height:
		return false
	return not _blocked.has(cell)

func clamp_cell(cell: Vector2i) -> Vector2i:
	return Vector2i(
		clampi(cell.x, 0, _arena.width - 1),
		clampi(cell.y, 0, _arena.height - 1)
	)

## World-space arena bounds with a half-tile margin, for keeping unit
## positions on the field no matter what pushed them.
func clamp_world(p: Vector2) -> Vector2:
	var ts = _arena.tile_size
	return Vector2(
		clampf(p.x, ts * 0.5, _arena.width * ts - ts * 0.5),
		clampf(p.y, ts * 0.5, _arena.height * ts - ts * 0.5)
	)

## Nearest walkable cell, searching outward in rings. Falls back to the
## (clamped) input if a 3-ring search finds nothing.
func nearest_walkable(cell: Vector2i) -> Vector2i:
	cell = clamp_cell(cell)
	if is_walkable(cell):
		return cell
	for ring in range(1, 4):
		for dy in range(-ring, ring + 1):
			for dx in range(-ring, ring + 1):
				if maxi(absi(dx), absi(dy)) != ring:
					continue
				var candidate = clamp_cell(cell + Vector2i(dx, dy))
				if is_walkable(candidate):
					return candidate
	return cell

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
	var eye = maxf(height_of(a), height_of(b)) + EYE_LEVEL
	for cell in _bresenham(a, b):
		if _blocked.has(cell):
			return false
		# Terrain occludes: ground higher than both heads is a wall.
		if height_of(cell) > eye:
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
