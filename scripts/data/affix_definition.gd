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
## A fragment of the world recovered along with the technique — shown
## in the library, never narrated.
@export_multiline var tome_lore: String = ""
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

## Human-readable effect summary, for item tooltips and the library.
func effect_lines() -> Array:
	var out := []
	if damage_mult != 1.0:
		out.append("+%d%% weapon damage" % roundi((damage_mult - 1.0) * 100))
	if attack_speed_mult != 1.0:
		out.append("%d%% faster swings" % roundi((1.0 - attack_speed_mult) * 100))
	if health_bonus_add != 0:
		out.append("+%d Health" % health_bonus_add)
	match on_hit_status:
		"poison":
			out.append("Poisons on hit: %.1f damage/s for %ds" % [
				on_hit_magnitude, int(on_hit_duration)])
		"slow":
			out.append("Chills on hit: %d%% slower for %ds" % [
				roundi((1.0 - on_hit_magnitude) * 100), int(on_hit_duration)])
	return out

func compatible_with(gear: GearDefinition) -> bool:
	var is_weapon = gear.weapon_type != GearDefinition.WeaponType.NONE
	return (is_weapon and applies_to_weapons) \
		or (not is_weapon and applies_to_armor)
