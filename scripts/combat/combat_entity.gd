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
var gear := []
var equipped := {}

var position: Vector2 = Vector2.ZERO
var facing: Vector2 = Vector2.RIGHT
var move_speed: float = 120.0
var path: PackedVector2Array = []
var path_index: int = 0
var path_goal: Vector2i = Vector2i(-9999, -9999)
## Failed searches retry after a short delay instead of caching forever.
var path_retry_at: float = 0.0
var moving: bool = false
var last_logged_facing: Vector2 = Vector2.RIGHT
var target_id: int = -1
var threat_table: Dictionary = {}
var in_combat: bool = false
var statuses: Array = []
var is_casting: bool = false
var cast_remaining: float = 0.0
var casting_skill: SkillDefinition = null
var weapon_reach: float = 48.0

var team: Team

var attack_interval: float
var attack_timer = attack_interval
var combat_log := []

var skills := []
## skill_id -> combat_time when the skill comes off cooldown.
var skill_ready_at := {}

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

func is_stunned() -> bool:
	for s in statuses:
		if s.kind == StatusEffect.Kind.STUN and s.remaining > 0.0:
			return true
	return false

func tick_statuses(delta, combat_state):
	for s in statuses:
		s.remaining -= delta
		if s.kind == StatusEffect.Kind.POISON and alive:
			s.accum += s.magnitude * delta
			if s.accum >= 1.0:
				var dmg = int(s.accum)
				s.accum -= dmg
				var died = take_damage(dmg)
				combat_state.log_dot(self, s, dmg, died)
		if s.remaining <= 0.0:
			combat_state.log_buff_expired(self, s)
	statuses = statuses.filter(func(s): return s.remaining > 0.0)

func move_speed_multiplier() -> float:
	var m := 1.0
	for s in statuses:
		if s.kind == StatusEffect.Kind.SLOW and s.remaining > 0.0:
			m = minf(m, s.magnitude)
	return m

## Per-tick loop: statuses, target, close distance, then attack when
## in range. Stun skips everything; root skips only movement.
func update(delta, combat_state):
	tick_statuses(delta, combat_state)
	if is_stunned():
		return

	# A cast in flight locks the caster in place until it resolves.
	if is_casting:
		cast_remaining -= delta
		if cast_remaining <= 0.0:
			is_casting = false
			_finish_cast(combat_state)
		return

	combat_state.validate_target(self)
	var target = combat_state.entity_by_id(target_id)
	if target == null:
		return

	# Special skills fire on their own cooldowns and take the beat.
	if _try_special_skills(combat_state):
		return

	# Attacks fire anywhere inside range, but melee keeps closing to
	# comfortable striking distance before settling.
	var in_range = combat_state.in_attack_range(self, target)
	if combat_state.within_stop_range(self, target):
		combat_state.stop_movement(self)
		combat_state.face_target(self, target)
	else:
		combat_state.tick_movement(self, target, delta)

	# Timers run while closing so the strike lands on arrival, but a
	# swing only fires (and resets the timer) in range.
	attack_timer -= delta
	if attack_timer <= 0.0 and in_range:
		var skill = skills[0]
		if (
			skill
			and skill.requires_stationary
			and skill.delivery_type == SkillDefinition.DeliveryType.PROJECTILE
		):
			_start_cast(combat_state, skill)
		else:
			perform_auto_attack(combat_state, target)
		attack_timer = attack_interval

	if off_weapon:
		off_attack_timer -= delta
		if off_attack_timer <= 0.0 and in_range:
			perform_off_hand_attack(combat_state, target)
			off_attack_timer = off_weapon.attack_speed


## Skills beyond the auto-attack (skills[0]) carry behavior scripts and
## fire whenever their conditions hold and the cooldown has elapsed.
func _try_special_skills(combat_state) -> bool:
	for i in range(1, skills.size()):
		var skill = skills[i]
		if skill == null or skill.behavior_script == null:
			continue
		if combat_state.combat_time < skill_ready_at.get(skill.skill_id, 0.0):
			continue
		if skill.behavior_script.try_use(combat_state, self, skill):
			skill_ready_at[skill.skill_id] = combat_state.combat_time + skill.cooldown
			return true
	return false

## Ranged wind-up: instants get a short draw, real casts a longer one.
func _start_cast(combat_state, skill):
	is_casting = true
	casting_skill = skill
	cast_remaining = (
		0.3 if skill.cast_type == SkillDefinition.CastType.INSTANT else 0.5
	)
	combat_state.stop_movement(self)
	combat_state.combat_log.add_event(CombatEvent.create_cast_start(
		entity_id, target_id, combat_state.combat_time, skill
	))

func _finish_cast(combat_state):
	var skill = casting_skill
	casting_skill = null
	combat_state.combat_log.add_event(CombatEvent.create_cast_finish(
		entity_id, combat_state.combat_time, skill
	))
	var target = combat_state.entity_by_id(target_id)
	if target == null or not target.alive:
		return
	# The target may have broken range or line of sight mid-cast.
	if not combat_state.can_use_skill_on(self, skill, target):
		return
	perform_auto_attack(combat_state, target)

func perform_auto_attack(combat_state, target):
	var weapon_hit := 0
	if main_weapon:
		weapon_hit = main_weapon.roll_weapon_damage()
	var damage = attack_power + weapon_hit + randi_range(
		skills[0].base_min_damage, skills[0].base_max_damage)
	_strike(combat_state, skills[0], target, damage)

func perform_off_hand_attack(combat_state, target):
	var weapon_hit := 0
	if off_weapon:
		weapon_hit = off_weapon.roll_weapon_damage()
	var raw = base_attack_power + weapon_hit + randi_range(
		skills[0].base_min_damage, skills[0].base_max_damage)
	var damage = maxi(1, floori(OFF_HAND_FACTOR * raw))
	_strike(combat_state, skills[0], target, damage, true)

func _strike(combat_state, skill, target, damage, off_hand := false):
	if target == null:
		return

	var died = target.take_damage(damage)
	combat_state.register_damage(self, target, skill, damage)
	# Weapon affixes (poison, chill) bite on the landed hit.
	combat_state.apply_on_hit(
		self, off_weapon if off_hand else main_weapon, target
	)

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
