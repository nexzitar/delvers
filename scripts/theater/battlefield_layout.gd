extends Node2D
class_name BattlefieldLayout

@onready var hero_slots = $HeroSlots
@onready var enemy_slots = $EnemySlots

func hero_slot(slot: int) -> Vector2:
	return _slot_position(hero_slots, slot)

func enemy_slot(slot: int) -> Vector2:
	return _slot_position(enemy_slots, slot)

func _slot_position(container: Node2D, slot: int) -> Vector2:

	var node_name = Formation.SLOT_NODE_NAMES.get(slot)

	if node_name == null:
		push_error("Invalid formation slot: %d" % slot)
		return Vector2.ZERO

	var marker = container.get_node_or_null(NodePath(node_name))

	if marker == null:
		push_error(
			"Missing slot marker '%s' under %s" % [node_name, container.name]
		)
		return Vector2.ZERO

	return marker.global_position
