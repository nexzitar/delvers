extends Resource
class_name GearDefinition

# Indices 0-3 are frozen: existing .tres files store slot = 2 (MAIN_HAND),
# slot = 3 (OFF_HAND). New categories are appended.
enum Slot {
	HEAD = 0,
	CHEST = 1,
	MAIN_HAND = 2,
	OFF_HAND = 3,
	NECK,
	SHOULDER,
	BACK,
	WRIST,
	HANDS,
	WAIST,
	LEGS,
	FEET,
	RING,
	TRINKET,
}

enum WeaponType {
	NONE,
	ONE_HANDED,
	TWO_HANDED,
	BOW
}

## How head-slot gear interacts with the actor's hair.
enum HeadStyle {
	OPEN,  # circlet, halo, crown — hair stays visible
	FULL,  # enclosing helm — swap to the actor's bald body texture
}

@export var gear_id: String
@export var gear_name: String
@export var slot: Slot
@export var weapon_type: WeaponType = WeaponType.NONE
@export var quality: ItemQuality.Tier = ItemQuality.Tier.COMMON
## Drop level: stats scale from the authored (level 1) values via
## LootTable.materialize. Higher item level = stronger item.
@export var item_level: int = 1
## Applied enchantment (AffixDefinition id), baked in at craft time.
@export var affix_id: String = ""

@export_group("Visuals")
## Sprite drawn on the character (paper-doll layer).
@export var texture: Texture2D
## Inventory/selection icon. Falls back to texture when unset.
@export var icon: Texture2D
## Offset and scale are in the body sprite's local pixel space.
@export var offset: Vector2
@export var scale: float = 1.0
@export var rotation_degrees: float = 0.0
## Head-slot only: OPEN keeps hair, FULL uses the actor's bald body under the piece.
@export var head_style: HeadStyle = HeadStyle.FULL

@export_group("Stats")
## Flat attack bonus for armor and accessories. Weapons use damage_min/max.
@export var attack_bonus: int = 0
@export var health_bonus: int = 0
## Weapon hit range. When unset, weapons fall back to attack_bonus for both ends.
@export var damage_min: int = 0
@export var damage_max: int = 0
## Seconds per swing. Only meaningful for weapons; 0 elsewhere.
@export var attack_speed: float = 0.0
## Attack reach in world pixels. 0 derives a default from weapon_type.
@export var reach: float = 0.0

func effective_reach() -> float:
	if reach > 0.0:
		return reach
	match weapon_type:
		WeaponType.BOW:
			return 320.0
		WeaponType.TWO_HANDED:
			return 56.0
		WeaponType.ONE_HANDED:
			return 48.0
	return 0.0

func effective_damage_min() -> int:
	if damage_max > 0 or damage_min > 0:
		return mini(damage_min, damage_max)
	return attack_bonus

func effective_damage_max() -> int:
	if damage_max > 0 or damage_min > 0:
		return maxi(damage_min, damage_max)
	return attack_bonus

func damage_average() -> float:
	return (float(effective_damage_min()) + float(effective_damage_max())) * 0.5

func roll_weapon_damage() -> int:
	return randi_range(effective_damage_min(), effective_damage_max())

func weapon_dps() -> float:
	if attack_speed <= 0.0:
		return 0.0
	return damage_average() / attack_speed

## Draw order for paper-doll pieces on the body sprite. Higher draws in front.
static func paper_doll_layer(category: Slot) -> int:
	match category:
		Slot.BACK:
			return -1
		Slot.CHEST, Slot.WRIST, Slot.HANDS, Slot.WAIST, Slot.LEGS, Slot.FEET:
			return 0
		Slot.RING, Slot.TRINKET:
			return 0
		Slot.NECK:
			return 1
		Slot.SHOULDER:
			return 2
		Slot.HEAD:
			return 3
		Slot.MAIN_HAND, Slot.OFF_HAND:
			return 1
		_:
			return 0

## Rough power rating from stats (for stash sorting).
func power_score() -> int:
	var score := 1
	if attack_speed > 0.0:
		score += int(round(damage_average() * 2.0))
		score += int(round(weapon_dps() * 6.0))
	else:
		score += attack_bonus * 2
	score += health_bonus
	return maxi(1, score)
