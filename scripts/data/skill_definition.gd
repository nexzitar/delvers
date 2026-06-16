extends Resource
class_name SkillDefinition

enum SkillType {
	ATTACK,
	SPELL,
	SUPPORT
}

enum CastType {
	INSTANT,
	CAST_TIME,
	CHANNELED
}

enum CastDisruptionType {
	NONE,
	DELAY,
	INTERRUPT
}

enum TargetingType {
	SINGLE,
	CLEAVE,
	AOE,
	RANDOM,
	CHAIN
}

enum DeliveryType {
	MELEE,
	PROJECTILE
}

@export var skill_id: String
@export var skill_name: String
@export var quality: ItemQuality.Tier = ItemQuality.Tier.COMMON
@export var icon: Texture2D
@export var animation_id: String
@export var sfx_id: String
@export var tags: Array[String]
@export var behavior_script: Script

@export var skill_type: SkillType
@export var cast_type: CastType
@export var passive: bool = false

@export var delivery_type: DeliveryType = DeliveryType.MELEE
@export var projectile_scene: PackedScene

@export var range: float = 1.5
@export var mana_cost: int = 0
@export var base_min_damage: int
@export var base_max_damage: int
@export var threat_modifier: float = 1.0

@export var cooldown: float = 0.0
@export var gcd_duration: float = 0.0
@export var uses_attack_interval: bool = false

@export var cast_disruption: CastDisruptionType

@export var targeting_type: TargetingType
@export var target_count: int = 1
