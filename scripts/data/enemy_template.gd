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

@export var portrait: Texture2D

@export var skills: Array[SkillDefinition]
@export var preferred_slots : Array[int]
