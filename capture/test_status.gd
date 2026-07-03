extends Node

const StatusEffect = preload("res://scripts/combat/status_effect.gd")
const CombatEntity = preload("res://scripts/combat/combat_entity.gd")

func _ready():
	var entity = CombatEntity.new()
	assert(not entity.is_rooted(), "no statuses")

	var root = StatusEffect.new()
	root.kind = StatusEffect.Kind.ROOT
	root.remaining = 2.0
	entity.statuses.append(root)
	assert(entity.is_rooted(), "root blocks movement")

	root.remaining = 0.0
	assert(not entity.is_rooted(), "expired root")

	var slow = StatusEffect.new()
	slow.kind = StatusEffect.Kind.SLOW
	slow.remaining = 3.0
	slow.magnitude = 0.5
	entity.statuses.append(slow)
	assert(is_equal_approx(entity.move_speed_multiplier(), 0.5), "slow halves speed")

	print("PASS status")
	get_tree().quit()
