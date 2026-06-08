class_name CombatFormatter

static func format_event(event: CombatEvent) -> String:

	match event.type:

		CombatEvent.EventType.DAMAGE:
			return (
				event.source_name +
				" (" +
				str(event.source_id) +
				") " +
				" casts " +
				event.skill_name +
				" on " +
				event.target_name +
				" (" +
				str(event.target_id) +
				") " +
				" for " +
				str(event.amount) +
				" damage. " + 
				str(event.remaining_health) +
				" hp remaining."
				
			)

		CombatEvent.EventType.DEATH:
			return event.target_name + " dies!"

	return "Unknown Event"
