extends Resource
class_name HeroTemplate

@export var hero_id: String
@export var hero_name: String
@export var template_id : String
@export var actor_scene : PackedScene

@export var base_health: int
@export var base_mana: int
@export var base_attack: int
@export var base_attack_interval: float
## World pixels per second on the battle grid.
@export var move_speed: float = 120.0

@export var portrait: Texture2D
@export var starting_skills: Array[SkillDefinition]
@export var starting_gear: Array[GearDefinition]
@export var preferred_row: Formation.Row = Formation.Row.FRONT

## Runtime, position-keyed loadout (Equip.Position -> GearDefinition).
## Built by PlayerRoster from starting_gear; not exported/saved.
var equipped := {}

## Optional skills in loadout slots 2-6 (indices 0-4). Slot 1 is weapon-driven.
var bonus_skills: Array = []
