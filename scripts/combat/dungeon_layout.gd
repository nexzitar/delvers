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
## Places with purpose: a role id and display name per room (1-based
## room order), and which room holds the dungeon's landmark.
var room_roles: Array[String] = []
var room_names: Array[String] = []
var landmark_room := -1

## Per-theme naming: what each role is CALLED here. Rooms are never
## "Room 2"; they are places.
const ROLE_NAMES := {
	"forest": {
		"entrance": "The Broken Gate", "guard_post": "The Collapsed Guard Post",
		"hall": "The Fallen Hall", "storeroom": "The Looted Storeroom",
		"shrine": "The Mossy Shrine", "warren": "The Warren",
		"landmark": "The Warden's Rest", "mid_boss": "The Chieftain's Hold",
		"boss": "The Slime King's Court",
	},
	"nest": {
		"entrance": "The Silk Mouth", "guard_post": "The Watcher's Web",
		"hall": "The Husk Gallery", "storeroom": "The Wrapped Larder",
		"shrine": "The Moulting Ground", "warren": "The Brood Tunnels",
		"landmark": "The Idol Cavern", "mid_boss": "The Weaver's Den",
		"boss": "The Broodmother's Deep",
	},
	"workshop": {
		"entrance": "The Flooded Dock", "guard_post": "The Rusted Checkpoint",
		"hall": "The Assembly Hall", "storeroom": "The Parts Crib",
		"shrine": "The Oil Chapel", "warren": "The Scrap Heaps",
		"landmark": "The Dead Colossus", "mid_boss": "The Foreman's Floor",
		"boss": "The Engine Heart",
	},
}

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

	# The delve DESCENDS: the entrance stands highest, the boss lair
	# at the bottom. Each room owns a level; corridors ramp between.
	var levels: Array[float] = []
	var level := float((rooms.size() - 1) / 3)
	for i in rooms.size():
		levels.append(level)
		if i % 3 == 2:
			level = maxf(level - 1.0, 0.0)
	var heights := {}

	# Carve rooms and L-corridors into a walkable set.
	var walkable := {}
	for i in rooms.size():
		var room = rooms[i]
		for x in range(room.position.x, room.end.x):
			for y in range(room.position.y, room.end.y):
				walkable[Vector2i(x, y)] = true
				heights[Vector2i(x, y)] = levels[i]
	for i in rooms.size() - 1:
		var a = rooms[i].get_center()
		var b = rooms[i + 1].get_center()
		# The corridor's tiles ramp smoothly from level to level.
		var route: Array[Vector2i] = []
		for x in range(mini(a.x, b.x), maxi(a.x, b.x) + 1):
			route.append(Vector2i(x, a.y))
		if a.x > b.x:
			route.reverse()
		var leg2: Array[Vector2i] = []
		for y in range(mini(a.y, b.y), maxi(a.y, b.y) + 1):
			leg2.append(Vector2i(b.x, y))
		if a.y > b.y:
			leg2.reverse()
		route.append_array(leg2)
		# The ramp spans only the fresh ground BETWEEN the rooms -
		# lerping across the full center-to-center route would leave a
		# cliff at the room mouth where in-room tiles keep their level.
		var fresh_spine := 0
		for k in route.size():
			if not heights.has(route[k]):
				fresh_spine += 1
		var fresh_seen := 0
		for k in route.size():
			var spine = route[k]
			var h: float
			if heights.has(spine):
				h = heights[spine]
			else:
				fresh_seen += 1
				h = lerpf(levels[i], levels[i + 1],
					float(fresh_seen) / float(fresh_spine + 1))
			var across = Vector2i(0, 1) if k < route.size() - leg2.size() \
				else Vector2i(1, 0)
			for w in range(-CORRIDOR_HALF, CORRIDOR_HALF + 1):
				var cell = spine + across * w
				walkable[cell] = true
				if not heights.has(cell):
					heights[cell] = h

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
	# Walls stand on the ground beside them.
	for tile in blocked:
		var best := 0.0
		var found := false
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			if heights.has(tile + d):
				best = maxf(best, heights[tile + d]) if found else heights[tile + d]
				found = true
		if found:
			heights[tile] = best
	layout.arena.heights = heights
	layout.arena.hero_spawn_center = rooms[0].get_center()
	layout.arena.enemy_spawn_center = rooms[rooms.size() - 1].get_center()

	for i in rooms.size():
		var c = rooms[i].get_center()
		layout.waypoints.append(Vector2(c.x + 0.5, c.y + 0.5) * TILE)
		layout.waypoint_rooms.append(i + 1)

	layout.rooms = rooms.duplicate()
	_assign_roles(layout, dungeon, rng)
	_find_doors(layout, rooms, walkable)
	_place_packs(layout, dungeon, rooms, rng)
	return layout

## Every room draws a purpose. The entrance, the mid-boss hold, the
## landmark chamber and the boss lair are fixed; the rest draw from
## the wandering pool. Names come from the theme.
static func _assign_roles(layout: DungeonLayout, dungeon: DungeonDefinition,
		rng: RandomNumberGenerator):
	var names: Dictionary = ROLE_NAMES.get(dungeon.theme, ROLE_NAMES["forest"])
	var n = layout.rooms.size()
	var mid = n / 2
	# The landmark stands in a quiet room past the midpoint when the
	# dungeon is long enough, else just before the middle.
	layout.landmark_room = clampi(mid + 2, 1, n - 2) if n >= 6 else maxi(1, mid - 1)
	if layout.landmark_room == mid:
		layout.landmark_room = maxi(1, mid - 1)
	var pool := ["guard_post", "hall", "storeroom", "shrine", "warren"]
	for i in n:
		var role: String
		if i == 0:
			role = "entrance"
		elif i == n - 1:
			role = "boss"
		elif i == mid:
			role = "mid_boss"
		elif i == layout.landmark_room:
			role = "landmark"
		else:
			role = pool[rng.randi_range(0, pool.size() - 1)]
		layout.room_roles.append(role)
		layout.room_names.append(names.get(role, "Room %d" % (i + 1)))

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
			var court = dungeon.boss_pack.duplicate()
			court.append_array(_roll(dungeon, room_no, rng, -2))
			layout.packs.append({"room": room_no, "center": center,
				"templates": court, "elite": false, "link": -1})
			continue
		if i == mid:
			# The mid-boss: the dungeon's named elite when it has one,
			# else the farmable identity grown up.
			var elite_pack = dungeon.mid_boss.duplicate() \
				if not dungeon.mid_boss.is_empty() else dungeon.guaranteed.duplicate()
			elite_pack.append_array(_roll(dungeon, room_no, rng, -3))
			layout.packs.append({"room": room_no, "center": center,
				"templates": elite_pack, "elite": true, "link": -1})
			continue
		# The opening is scripted, not rolled: room two fields exactly
		# the farmable pair, room three adds one. A new delver's first
		# fight is a lesson, never an ambush.
		if room_no == 2:
			layout.packs.append({"room": room_no, "center": center,
				"templates": dungeon.guaranteed.duplicate(), "elite": false,
				"link": -1})
			continue
		if room_no == 3:
			var opening = dungeon.guaranteed.duplicate()
			opening.append_array(_roll(dungeon, room_no, rng,
				-(opening.size() + 1)))
			layout.packs.append({"room": room_no, "center": center,
				"templates": opening.slice(0, 3), "elite": false,
				"link": -1})
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
