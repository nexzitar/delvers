class_name DungeonLayout

## Compiles a DungeonDefinition into one continuous place: rooms
## carved along a winding spine, corridors between them, and enemy
## packs placed dormant where they live. The sim walks the party
## through it; nothing teleports.

const ROOM_MIN := 9
const ROOM_MAX := 13
const CORRIDOR_HALF := 1
const TILE := 32

var arena: BattleArena
## Room centers in walk order (world px). The party's travel spine.
var waypoints: Array[Vector2] = []
## Which room each waypoint index belongs to (1-based room numbers).
var waypoint_rooms: Array[int] = []
## Packs: {room:int, center:Vector2, templates:Array, elite:bool,
##         link:int} - link >= 0 groups packs that pull together.
var packs: Array[Dictionary] = []
## Room rects (tiles) and doorways ({center:Vector2 world px,
## horizontal:bool}) - the theater dresses both.
var rooms: Array[Rect2i] = []
var doors: Array[Dictionary] = []

## Deterministic for a given rng: the layout IS the dungeon instance.
static func generate(dungeon: DungeonDefinition, rng: RandomNumberGenerator) -> DungeonLayout:
	var layout = DungeonLayout.new()
	var rooms: Array[Rect2i] = []

	# March the spine: rooms step east with a wandering north/south
	# drift, so the dungeon reads as one winding place.
	var cursor := Vector2i(6, 20)
	for i in dungeon.length:
		var w = rng.randi_range(ROOM_MIN, ROOM_MAX)
		var h = rng.randi_range(ROOM_MIN, ROOM_MAX)
		if i == dungeon.length - 1:
			w += 3
			h += 2
		var room = Rect2i(cursor - Vector2i(w / 2, h / 2), Vector2i(w, h))
		rooms.append(room)
		var step_x = rng.randi_range(9, 12) + w / 2
		var drift = rng.randi_range(-6, 6)
		cursor += Vector2i(step_x, drift)

	# Normalize into a padded bounding box.
	var bounds: Rect2i = rooms[0]
	for room in rooms:
		bounds = bounds.merge(room)
	bounds = bounds.grow(3)
	var shift = -bounds.position
	for i in rooms.size():
		rooms[i].position += shift

	# Carve rooms and L-corridors into a walkable set.
	var walkable := {}
	for room in rooms:
		for x in range(room.position.x, room.end.x):
			for y in range(room.position.y, room.end.y):
				walkable[Vector2i(x, y)] = true
	for i in rooms.size() - 1:
		var a = rooms[i].get_center()
		var b = rooms[i + 1].get_center()
		for x in range(mini(a.x, b.x), maxi(a.x, b.x) + 1):
			for dy in range(-CORRIDOR_HALF, CORRIDOR_HALF + 1):
				walkable[Vector2i(x, a.y + dy)] = true
		for y in range(mini(a.y, b.y), maxi(a.y, b.y) + 1):
			for dx in range(-CORRIDOR_HALF, CORRIDOR_HALF + 1):
				walkable[Vector2i(b.x + dx, y)] = true

	# A few pillars inside larger rooms (never on the spine row).
	for i in range(1, rooms.size() - 1):
		var room = rooms[i]
		if room.size.x < 11 or rng.randf() < 0.4:
			continue
		for p in rng.randi_range(1, 3):
			var px = rng.randi_range(room.position.x + 2, room.end.x - 3)
			var py = rng.randi_range(room.position.y + 2, room.end.y - 3)
			if absi(py - room.get_center().y) <= 1:
				continue
			walkable.erase(Vector2i(px, py))

	# Blocked = everything in bounds that was not carved.
	var size = bounds.size + Vector2i.ONE
	layout.arena = BattleArena.new()
	layout.arena.arena_id = "dungeon_%s" % dungeon.dungeon_id
	layout.arena.width = size.x
	layout.arena.height = size.y
	layout.arena.tile_size = TILE
	var blocked: Array[Vector2i] = []
	for x in size.x:
		for y in size.y:
			if not walkable.has(Vector2i(x, y)):
				blocked.append(Vector2i(x, y))
	layout.arena.blocked_tiles = blocked
	layout.arena.hero_spawn_center = rooms[0].get_center()
	layout.arena.enemy_spawn_center = rooms[rooms.size() - 1].get_center()

	for i in rooms.size():
		var c = rooms[i].get_center()
		layout.waypoints.append(Vector2(c.x + 0.5, c.y + 0.5) * TILE)
		layout.waypoint_rooms.append(i + 1)

	layout.rooms = rooms.duplicate()
	_find_doors(layout, rooms, walkable)
	_place_packs(layout, dungeon, rooms, rng)
	return layout

## A door is where a corridor crosses a room boundary: runs of
## walkable cells just outside an edge that connect to walkable
## cells inside. One arch per run, spanning the corridor.
static func _find_doors(layout: DungeonLayout, rooms: Array[Rect2i],
		walkable: Dictionary):
	for room in rooms:
		for side in 4:
			var runs: Array = []
			var run: Array = []
			var span = room.size.y if side < 2 else room.size.x
			for k in span:
				var outside: Vector2i
				var inside: Vector2i
				match side:
					0:
						outside = Vector2i(room.position.x - 1, room.position.y + k)
						inside = outside + Vector2i(1, 0)
					1:
						outside = Vector2i(room.end.x, room.position.y + k)
						inside = outside + Vector2i(-1, 0)
					2:
						outside = Vector2i(room.position.x + k, room.position.y - 1)
						inside = outside + Vector2i(0, 1)
					_:
						outside = Vector2i(room.position.x + k, room.end.y)
						inside = outside + Vector2i(0, -1)
				if walkable.has(outside) and walkable.has(inside):
					run.append(outside)
				elif not run.is_empty():
					runs.append(run)
					run = []
			if not run.is_empty():
				runs.append(run)
			for r in runs:
				var mid: Vector2i = r[r.size() / 2]
				layout.doors.append({
					"center": Vector2(mid.x + 0.5, mid.y + 0.5) * TILE,
					"horizontal": side >= 2,
				})

## Encounter composition per room, continuous-dungeon rules: the
## entrance is empty, some rooms hold two packs (occasionally linked
## - they pull together), the middle room houses an elite mid-boss
## pack, and the last room is the boss lair.
static func _place_packs(layout: DungeonLayout, dungeon: DungeonDefinition,
		rooms: Array[Rect2i], rng: RandomNumberGenerator):
	var next_link := 0
	var mid = rooms.size() / 2
	for i in range(1, rooms.size()):
		var room_no = i + 1
		var center = Vector2(rooms[i].get_center().x + 0.5,
			rooms[i].get_center().y + 0.5) * TILE
		if i == rooms.size() - 1:
			layout.packs.append({"room": room_no, "center": center,
				"templates": dungeon.boss_pack.duplicate(), "elite": false,
				"link": -1})
			continue
		if i == mid:
			# The mid-boss: the dungeon's farmable identity, grown up.
			var elite_pack = dungeon.guaranteed.duplicate()
			elite_pack.append_array(_roll(dungeon, room_no, rng, 2))
			layout.packs.append({"room": room_no, "center": center,
				"templates": elite_pack, "elite": true, "link": -1})
			continue
		var two = rooms[i].size.x >= 11 and rng.randf() < 0.45
		var linked = two and rng.randf() < 0.5
		var link_id = -1
		if linked:
			link_id = next_link
			next_link += 1
		if two:
			var off = Vector2(rooms[i].size.x * 0.28, 0.0) * TILE
			layout.packs.append({"room": room_no, "center": center - off,
				"templates": _roll(dungeon, room_no, rng, 0),
				"elite": false, "link": link_id})
			layout.packs.append({"room": room_no, "center": center + off,
				"templates": _roll(dungeon, room_no, rng, -1),
				"elite": false, "link": link_id})
		else:
			layout.packs.append({"room": room_no, "center": center,
				"templates": _roll(dungeon, room_no, rng, 0),
				"elite": false, "link": -1})

## One pack's composition (the old per-room roll, sized by depth;
## size_adjust trims the second pack of a double room).
static func _roll(dungeon: DungeonDefinition, room: int,
		rng: RandomNumberGenerator, size_adjust: int) -> Array:
	var pool = dungeon.pool_core.duplicate()
	if room >= dungeon.deep_from:
		pool.append_array(dungeon.pool_deep)
	var low = clampi(2 + (room - 1) / 4, 2, 4) + dungeon.pack_bonus
	var high = clampi(3 + (room - 1) / 2, 3, 6) + dungeon.pack_bonus
	var encounter = dungeon.guaranteed.duplicate()
	var size = maxi(rng.randi_range(low, high) + size_adjust, 2)
	size = maxi(size, encounter.size())
	for i in range(size - encounter.size()):
		encounter.append(pool[rng.randi_range(0, pool.size() - 1)])
	return encounter
