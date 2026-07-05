extends Resource
class_name DungeonDefinition

## A dungeon: its enemies, its boss, its material identity, its look,
## and its loot band. Old dungeons never become obsolete — each owns
## materials nothing else drops.

@export var dungeon_id: String
@export var dungeon_name: String
## One line for the embark picker.
@export var flavor: String = ""
@export var length: int = 10

## Encounter composition: core pool always draws, the deep pool joins
## from deep_from onward, and one guaranteed enemy anchors every room
## (the farmable identity — warriors in the Darkwood).
@export var pool_core: Array[EnemyDefinition] = []
@export var pool_deep: Array[EnemyDefinition] = []
@export var deep_from: int = 3
@export var guaranteed: EnemyDefinition
@export var boss_pack: Array[EnemyDefinition] = []

## Loot band: item level = room + level_offset. Depth unlocks rarity:
## normals here can roll rare at rare_chance; the boss rolls epic at
## boss_epic_chance.
@export var level_offset: int = 0
@export var rare_chance: float = 0.01
@export var boss_epic_chance: float = 0.03

## Theater dressing: "forest" (moonlit firs) or "nest" (webbed cavern).
@export var theme: String = "forest"

## This dungeon's expedition-log series, recovered in order.
@export var lore_ids: Array[String] = []
