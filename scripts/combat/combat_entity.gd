class_name CombatEntity

const StatusEffect = preload("res://scripts/combat/status_effect.gd")

var entity_id: int

enum Team {
	HERO,
	ENEMY
}

var template: Resource
var entity_name: String
var level := 1
var current_health: int
var max_health: int
var current_mana: int
var attack_power: int
var formation_slot: int
var gear := []
var equipped := {}

var position: Vector2 = Vector2.ZERO
var facing: Vector2 = Vector2.RIGHT
var move_speed: float = 120.0
var path: PackedVector2Array = []
var path_index: int = 0
var target_id: int = -1
var threat_table: Dictionary = {}
var in_combat: bool = false
var statuses: Array = []
var is_casting: bool = false
var cast_remaining: float = 0.0
var weapon_reach: float = 48.0

var team: Team

var attack_interval: float
var attack_timer = attack_interval
var combat_log := []

var skills := []

# Per-hand attack model. base_attack_power excludes weapon damage so the
# off-hand swing can be computed independently.
var base_attack_power: int = 0
var main_weapon: GearDefinition = null
var off_weapon: GearDefinition = null
var off_attack_timer: float = 0.0
const OFF_HAND_FACTOR := 0.5

var alive := true

func is_rooted() -> bool:
	for s in statuses:
		if s.remaining <= 0.0:
			continue
		if s.kind == StatusEffect.Kind.ROOT or s.kind == StatusEffect.Kind.STUN:
			return true
	return false

func move_speed_multiplier() -> float:
	var m := 1.0
	for s in statuses:
		if s.kind == StatusEffect.Kind.SLOW and s.remaining > 0.0:
			m = minf(m, s.magnitude)
	return m

func update(delta, combat_state):
	attack_timer -= delta
	if attack_timer <= 0:
		perform_auto_attack(combat_state)
		attack_timer = attack_interval

	if off_weapon:
		off_attack_timer -= delta
		if off_attack_timer <= 0:
			perform_off_hand_attack(combat_state)
			off_attack_timer = off_weapon.attack_speed


func perform_auto_attack(combat_state):
	var weapon_hit := 0
	if main_weapon:
		weapon_hit = main_weapon.roll_weapon_damage()
	var damage = attack_power + weapon_hit + randi_range(
		skills[0].base_min_damage, skills[0].base_max_damage)
	_strike(combat_state, skills[0], damage)

func perform_off_hand_attack(combat_state):
	var weapon_hit := 0
	if off_weapon:
		weapon_hit = off_weapon.roll_weapon_damage()
	var raw = base_attack_power + weapon_hit + randi_range(
		skills[0].base_min_damage, skills[0].base_max_damage)
	var damage = maxi(1, floori(OFF_HAND_FACTOR * raw))
	_strike(combat_state, skills[0], damage, true)

func _strike(combat_state, skill, damage, off_hand := false):
	var target = combat_state.get_target_for(self, skill)
	if target == null:
		return

	var died = target.take_damage(damage)

	var event = CombatEvent.new()
	event.time = combat_state.combat_time
	event.type = CombatEvent.EventType.DAMAGE
	event.source_id = entity_id
	event.target_id = target.entity_id
	event.source_name = entity_name
	event.target_name = target.entity_name
	event.remaining_health = target.current_health
	event.max_health = target.max_health
	event.skill_name = skill.skill_name
	event.skill = skill
	event.amount = damage
	event.off_hand = off_hand
	combat_state.add_event(event)

	if died:
		var death = CombatEvent.new()
		death.time = combat_state.combat_time
		death.type = CombatEvent.EventType.DEATH
		death.target_id = target.entity_id
		death.target_name = target.entity_name
		combat_state.add_event(death)


func take_damage(amount):

	current_health -= amount

	if current_health <= 0 and alive:

		current_health = 0
		alive = false

		return true

	return false
