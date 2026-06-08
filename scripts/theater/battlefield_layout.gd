extends Node2D
class_name BattlefieldLayout

@onready var hero_slots = $HeroSlots.get_children()
@onready var enemy_slots = $EnemySlots.get_children()

func _ready():
	hero_slots.sort_custom(
		unc(a, b): return a.name < b.name
	)

	enemy_slots.sort_custom(
		func(a, b): return a.name < b.name
	)

func hero_slot(index):

	if index < 0 or index >= hero_slots.size():
		push_error("Invalid hero slot: %d" % index)
		return Vector2.ZERO

	return hero_slots[index].global_position

func enemy_slot(index):

	if index < 0 or index >= enemy_slots.size():
		push_error("Invalid enemt slot: %d" % index)
		return Vector2.ZERO

	return enemy_slots[index].global_position
