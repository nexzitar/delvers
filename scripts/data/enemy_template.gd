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

## Monsters drop resources and knowledge, not equipment. Materials are
## this enemy's identity (goblins carry wood and strings, slimes ooze);
## recipes are rare permanent unlocks; finished gear is a memorable
## fluke outside of bosses.
@export var material_loot: Array[String] = []
@export var material_drop_chance: float = 0.65
@export var recipe_loot: Array[String] = []
@export var recipe_drop_chance: float = 0.05
## Affix knowledge this enemy can teach (rarer than base recipes).
@export var affix_loot: Array[String] = []
@export var affix_drop_chance: float = 0.03
@export var loot_ids: Array[String] = []
@export var drop_chance: float = 0.02
@export var is_boss: bool = false

## Defensive/offensive secondary stats (see GearDefinition for the
## hero-side equivalents).
@export var armor: int = 0
@export var block_rating: float = 0.0
@export var dodge_rating: float = 0.0
@export var crit_rating: float = 0.0
