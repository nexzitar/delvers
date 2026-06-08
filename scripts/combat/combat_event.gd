class_name CombatEvent

enum EventType {
	DAMAGE,
	HEAL,
	DEATH,
	CAST_START,
	CAST_FINISH,
	BUFF_APPLIED,
	BUFF_EXPIRED,
	SPAWN
}
var entity : CombatEntity
var template: Resource
var current_health: int
var entity_id: int


var time: float
var type: EventType

var source_name: String
var target_name: String

var source_id : int
var target_id : int
var formation_slot: int

var skill_name: String
var remaining_health: int
var max_health: int

var amount: int 
var entity_name: String

var team: int


static func create_spawn(combat_entity):

	var event = CombatEvent.new()

	event.type = EventType.SPAWN

	event.template = combat_entity.template

	event.entity_id = combat_entity.entity_id
	event.entity_name = combat_entity.entity_name

	event.team = combat_entity.team
	event.formation_slot = combat_entity.formation_slot

	event.current_health = combat_entity.current_health
	event.max_health = combat_entity.template.base_health

	return event
