extends Resource
class_name EnemyDefinition

@export var enemy_id: String
@export var enemy_name: String
@export var template_id : String
@export var actor_scene : PackedScene

@export var base_health: int
@export var base_mana: int
@export var base_attack: int

@export var base_attack_interval: float
## World pixels per second on the battle grid.
@export var move_speed: float = 100.0

@export var portrait: Texture2D

@export var skills: Array[SkillDefinition]
@export var preferred_row: Formation.Row = Formation.Row.FRONT

## What this enemy can drop (gear ids from the save registry) and how
## often it drops anything at all. Bosses always drop, and roll from
## the rare end of the quality table.
@export var loot_ids: Array[String] = []
@export var drop_chance: float = 0.1
@export var is_boss: bool = false
