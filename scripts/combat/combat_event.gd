class_name CombatEvent

enum EventType {
	DAMAGE,
	HEAL,
	DEATH,
	CAST_START,
	CAST_FINISH,
	BUFF_APPLIED,
	BUFF_EXPIRED,
	SPAWN,
	MOVE,
	FACE,
	TARGET,
	TELEGRAPH,
}

var entity: CombatEntity
var template: Resource
var current_health: int
var entity_id: int

var time: float
var type: EventType

var current_mana: int
var max_mana: int

var source_name: String
var target_name: String

var source_id: int
var target_id: int

var skill_name: String
var skill: SkillDefinition
var remaining_health: int
var max_health: int

var amount: int
var entity_name: String

var team: int

var gear := []
var equipped := {}
var off_hand := false

var position: Vector2 = Vector2.ZERO
var facing: Vector2 = Vector2.RIGHT
var velocity: Vector2 = Vector2.ZERO
var telegraph_radius: float = 0.0
var telegraph_duration: float = 0.0
var status_id: String = ""


static func create_spawn(combat_entity):

	var event = CombatEvent.new()

	event.type = EventType.SPAWN

	event.template = combat_entity.template

	event.entity_id = combat_entity.entity_id
	event.entity_name = combat_entity.entity_name

	event.team = combat_entity.team

	event.current_health = combat_entity.current_health
	event.max_health = combat_entity.max_health
	event.current_mana = combat_entity.current_mana
	event.max_mana = combat_entity.template.base_mana
	event.gear = combat_entity.gear
	event.equipped = combat_entity.equipped

	event.position = combat_entity.position
	event.facing = combat_entity.facing

	return event


static func create_move(entity_id: int, sim_time: float, pos: Vector2, vel := Vector2.ZERO) -> CombatEvent:
	var event = CombatEvent.new()
	event.type = EventType.MOVE
	event.entity_id = entity_id
	event.time = sim_time
	event.position = pos
	event.velocity = vel
	return event


static func create_face(entity_id: int, sim_time: float, dir: Vector2) -> CombatEvent:
	var event = CombatEvent.new()
	event.type = EventType.FACE
	event.entity_id = entity_id
	event.time = sim_time
	event.facing = dir
	return event


static func create_target(source_id: int, target_id: int, sim_time: float) -> CombatEvent:
	var event = CombatEvent.new()
	event.type = EventType.TARGET
	event.source_id = source_id
	event.target_id = target_id
	event.time = sim_time
	return event


static func create_cast_start(source_id: int, target_id_: int, sim_time: float, skill_: SkillDefinition) -> CombatEvent:
	var event = CombatEvent.new()
	event.type = EventType.CAST_START
	event.source_id = source_id
	event.entity_id = source_id
	event.target_id = target_id_
	event.time = sim_time
	event.skill = skill_
	event.skill_name = skill_.skill_name if skill_ else ""
	return event


static func create_cast_finish(source_id: int, sim_time: float, skill_: SkillDefinition) -> CombatEvent:
	var event = CombatEvent.new()
	event.type = EventType.CAST_FINISH
	event.source_id = source_id
	event.entity_id = source_id
	event.time = sim_time
	event.skill = skill_
	event.skill_name = skill_.skill_name if skill_ else ""
	return event


static func create_telegraph(
		source_id: int,
		sim_time: float,
		pos: Vector2,
		radius: float,
		duration: float,
	) -> CombatEvent:
	var event = CombatEvent.new()
	event.type = EventType.TELEGRAPH
	event.source_id = source_id
	event.time = sim_time
	event.position = pos
	event.telegraph_radius = radius
	event.telegraph_duration = duration
	return event
