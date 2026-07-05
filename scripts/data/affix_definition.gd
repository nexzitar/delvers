extends Resource
class_name AffixDefinition

## A learnable enchantment recipe: permanent knowledge that lets any
## compatible base item be crafted with this affix, for extra
## materials. "Virulent Hunter Bow" = Hunter Bow recipe + Virulent
## affix + the poison to back it up.

@export var affix_id: String
## Name prefix: "Virulent" makes a "Virulent Hunter Bow".
@export var affix_name: String
## Provenance: the artifact this knowledge was recovered as
## ("Spider Venom Treatise"). Worldbuilding for the drop screen.
@export var tome_name: String = ""
@export var icon: Texture2D

## Compatibility: weapons (anything that swings or shoots) and/or
## armor (everything else, shields included).
@export var applies_to_weapons: bool = true
@export var applies_to_armor: bool = false

## Stat shaping, applied after item-level/quality scaling.
@export var damage_mult: float = 1.0
@export var attack_speed_mult: float = 1.0
@export var health_bonus_add: int = 0

## On-hit rider for weapons: "poison" (magnitude = damage/second) or
## "slow" (magnitude = speed factor), lasting on_hit_duration seconds.
@export var on_hit_status: String = ""
@export var on_hit_duration: float = 0.0
@export var on_hit_magnitude: float = 0.0

## material_id -> count, consumed on top of the base recipe's costs.
@export var costs: Dictionary = {}

func compatible_with(gear: GearDefinition) -> bool:
	var is_weapon = gear.weapon_type != GearDefinition.WeaponType.NONE
	return (is_weapon and applies_to_weapons) \
		or (not is_weapon and applies_to_armor)
