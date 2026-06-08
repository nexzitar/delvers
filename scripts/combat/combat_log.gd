class_name CombatLog

var events: Array[CombatEvent] = []

func add_event(event: CombatEvent):
	events.append(event)
	
func add_spawn(entity):
	var event = CombatEvent.new()

	event.type = CombatEvent.EventType.SPAWN

	event.entity_id = entity.entity_id
	event.entity_name = entity.entity_name
	event.formation_slot = entity.formation_slot

	event.current_health = entity.current_health
	event.max_health = entity.max_health

	event.template_id = entity.template.id
	event.team = entity.team

	add_event(event) 
