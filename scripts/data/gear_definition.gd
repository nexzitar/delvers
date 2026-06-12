extends Resource
class_name GearDefinition

enum Slot {
	HEAD,
	CHEST,
	MAIN_HAND,
	OFF_HAND
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
