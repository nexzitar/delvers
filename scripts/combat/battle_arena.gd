extends Resource
class_name BattleArena

@export var arena_id: String = "open"
@export var width: int = 30
@export var height: int = 20
@export var tile_size: int = 32
@export var blocked_tiles: Array[Vector2i] = []
## Per-tile elevation in LEVELS (float; ramps use fractions). Tiles
## absent from the map stand at 0. One level is a ledge no one walks
## up without a ramp.
@export var heights: Dictionary = {}
@export var hero_spawn_center: Vector2i = Vector2i(4, 10)
@export var enemy_spawn_center: Vector2i = Vector2i(25, 10)
