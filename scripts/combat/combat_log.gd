class_name CombatLog

var events: Array[CombatEvent] = []

func add_event(event: CombatEvent):
	events.append(event)
