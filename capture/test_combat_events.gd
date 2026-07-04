extends Node

const CombatEvent = preload("res://scripts/combat/combat_event.gd")

func _ready():
	var move = CombatEvent.create_move(3, 1.5, Vector2(100, 200), Vector2(10, 0))
	assert(move.type == CombatEvent.EventType.MOVE)
	assert(move.entity_id == 3)
	assert(move.time == 1.5)
	assert(move.position == Vector2(100, 200))
	assert(move.velocity == Vector2(10, 0))

	var target = CombatEvent.create_target(1, 2, 0.5)
	assert(target.type == CombatEvent.EventType.TARGET)
	assert(target.source_id == 1 and target.target_id == 2)

	var tele = CombatEvent.create_telegraph(4, 2.0, Vector2(50, 50), 80.0, 0.4)
	assert(tele.type == CombatEvent.EventType.TELEGRAPH)
	assert(tele.telegraph_radius == 80.0)
	assert(tele.telegraph_duration == 0.4)

	var face = CombatEvent.create_face(1, 0.1, Vector2.LEFT)
	assert(face.type == CombatEvent.EventType.FACE)
	assert(face.facing == Vector2.LEFT)

	print("PASS combat events")
	get_tree().quit()
