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

@export var gear_id: String
@export var gear_name: String
@export var slot: Slot
@export var weapon_type: WeaponType = WeaponType.NONE

@export_group("Visuals")
## Sprite drawn on the character (paper-doll layer).
@export var texture: Texture2D
## Inventory/selection icon. Falls back to texture when unset.
@export var icon: Texture2D
## Offset and scale are in the body sprite's local pixel space.
@export var offset: Vector2
@export var scale: float = 1.0
@export var rotation_degrees: float = 0.0

@export_group("Stats")
@export var attack_bonus: int = 0
@export var health_bonus: int = 0
## Seconds per swing. Only meaningful for weapons; 0 elsewhere.
@export var attack_speed: float = 0.0
