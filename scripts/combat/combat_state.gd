class_name CombatState

const MOVE_LOG_INTERVAL := 0.15
const SEPARATION_RADIUS := 24.0

var heroes: Array[CombatEntity] = []
var enemies: Array[CombatEntity] = []
var entities_by_id := {}

var arena: BattleArena
var grid: BattleGrid
var pathfinder: GridPathfinder

var combat_time: float = 0.0

var combat_log := CombatLog.new()

var combat_over: bool = false

## Deeper delve rooms field stronger foes.
var enemy_level_bonus: int = 0

var _move_log_time := {}

func update(delta: float):
	combat_time += delta

	for entity in heroes + enemies:
		if entity.alive:
			entity.update(delta, self)

	check_victory()

func add_event(event):
	combat_log.add_event(event)

	print(
		CombatFormatter.format_event(event)
	)


func entity_by_id(id):
	return entities_by_id.get(id)

func opponents_of(entity) -> Array[CombatEntity]:
	return enemies if entity.team == CombatEntity.Team.HERO else heroes

## Enemies with a threat table chase the highest-threat hero they can
## attack (a rooted enemy falls through to whoever is in range now).
## Heroes — and enemies before first blood — take the nearest opponent.
func validate_target(entity):
	if entity.team == CombatEntity.Team.ENEMY and not entity.threat_table.is_empty():
		var hero_positions = {}
		for hero in heroes:
			if hero.alive:
				hero_positions[hero.entity_id] = hero.position
		if hero_positions.is_empty():
			return
		var skill = entity.skills[0] if not entity.skills.is_empty() else null
		var pick = Threat.pick_target(
			entity, hero_positions, effective_range(entity, skill),
			func(hero_id, _pos):
				var hero = entity_by_id(hero_id)
				if hero == null or not hero.alive:
					return false
				if entity.is_rooted():
					return can_use_skill_on(entity, skill, hero)
				# Free to chase: any living hero is fair game (MVP:
				# open arena, everything is pathable).
				return true
		)
		_set_target(entity, pick)
		return

	var current = entity_by_id(entity.target_id)
	if current and current.alive:
		return
	_set_target(entity, _nearest_opponent_id(entity))

func _set_target(entity, new_target_id: int):
	if entity.target_id == new_target_id:
		return
	entity.target_id = new_target_id
	if new_target_id != -1:
		combat_log.add_event(
			CombatEvent.create_target(entity.entity_id, new_target_id, combat_time)
		)

## Applies a timed status and logs BUFF_APPLIED for the theater.
## Re-applying the same status id refreshes it instead of stacking
## (on-hit effects would otherwise pile up every swing).
func apply_status(target, kind, duration: float, magnitude: float, status_id: String, source_id := -1):
	for existing in target.statuses:
		if existing.id == status_id:
			existing.remaining = maxf(existing.remaining, duration)
			existing.magnitude = maxf(existing.magnitude, magnitude)
			existing.source_id = source_id
			return

	var status = StatusEffect.new()
	status.kind = kind
	status.remaining = duration
	status.magnitude = magnitude
	status.id = status_id
	status.source_id = source_id
	target.statuses.append(status)

	var event = CombatEvent.new()
	event.type = CombatEvent.EventType.BUFF_APPLIED
	event.time = combat_time
	event.entity_id = target.entity_id
	event.target_id = target.entity_id
	event.target_name = target.entity_name
	event.status_id = status_id
	combat_log.add_event(event)

## Weapon affixes bite on every landed hit: poison ticks damage over
## time, frost chills movement.
func apply_on_hit(attacker, weapon, target):
	if weapon == null or weapon.affix_id == "" or not target.alive:
		return
	var path = RosterSave.AFFIX_PATHS.get(weapon.affix_id)
	if path == null:
		return
	var affix = load(path)
	match affix.on_hit_status:
		"poison":
			apply_status(
				target, StatusEffect.Kind.POISON,
				affix.on_hit_duration, affix.on_hit_magnitude,
				"poison_" + affix.affix_id, attacker.entity_id
			)
		"slow":
			apply_status(
				target, StatusEffect.Kind.SLOW,
				affix.on_hit_duration, affix.on_hit_magnitude,
				"slow_" + affix.affix_id, attacker.entity_id
			)

## A poison tick dealt damage: log it (flagged as a dot so the theater
## shows the number without swinging anyone's arm) and feed threat.
func log_dot(victim, status, amount: int, died: bool):
	var source = entity_by_id(status.source_id)
	var event = CombatEvent.new()
	event.time = combat_time
	event.type = CombatEvent.EventType.DAMAGE
	event.dot = true
	event.source_id = status.source_id
	event.source_name = source.entity_name if source else "Poison"
	event.target_id = victim.entity_id
	event.target_name = victim.entity_name
	event.remaining_health = victim.current_health
	event.max_health = victim.max_health
	event.skill_name = "Poison"
	event.amount = amount
	add_event(event)

	if source and victim.team == CombatEntity.Team.ENEMY:
		Threat.add_damage(victim.threat_table, status.source_id, float(amount))

	if died:
		var death = CombatEvent.new()
		death.time = combat_time
		death.type = CombatEvent.EventType.DEATH
		death.target_id = victim.entity_id
		death.target_name = victim.entity_name
		add_event(death)

func log_buff_expired(entity, status):
	var event = CombatEvent.new()
	event.type = CombatEvent.EventType.BUFF_EXPIRED
	event.time = combat_time
	event.entity_id = entity.entity_id
	event.target_id = entity.entity_id
	event.status_id = status.id
	combat_log.add_event(event)

func log_heal(source, target, skill, amount: int):
	var event = CombatEvent.new()
	event.type = CombatEvent.EventType.HEAL
	event.time = combat_time
	event.source_id = source.entity_id
	event.source_name = source.entity_name
	event.target_id = target.entity_id
	event.target_name = target.entity_name
	event.skill = skill
	event.skill_name = skill.skill_name if skill else ""
	event.amount = amount
	event.remaining_health = target.current_health
	event.max_health = target.max_health
	event.current_mana = source.current_mana
	event.max_mana = source.max_mana
	combat_log.add_event(event)

## Displacement skills (charge) teleport in the sim; the theater tweens
## along the logged jump.
func log_forced_move(entity):
	_log_move(entity, true)

## Called on every landed hit: pulls the pack into combat and accrues
## threat on the struck enemy, scaled by the skill's threat modifier.
func register_damage(source, target, skill, amount):
	for enemy in enemies:
		enemy.in_combat = true
	if target.team == CombatEntity.Team.ENEMY:
		var multiplier = skill.threat_modifier if skill else 1.0
		Threat.add_damage(target.threat_table, source.entity_id, amount * multiplier)

func _nearest_opponent_id(entity) -> int:
	var best_id := -1
	var best := INF
	for other in opponents_of(entity):
		if not other.alive:
			continue
		var d = entity.position.distance_squared_to(other.position)
		if d < best:
			best = d
			best_id = other.entity_id
	return best_id

func effective_range(attacker, skill) -> float:
	var skill_range = skill.range if skill else 0.0
	return maxf(skill_range, attacker.weapon_reach)

## Attack validity: within range, and projectiles need line of sight.
func can_use_skill_on(attacker, skill, target) -> bool:
	var dist = attacker.position.distance_to(target.position)
	if dist > effective_range(attacker, skill):
		return false
	if skill and skill.delivery_type == SkillDefinition.DeliveryType.PROJECTILE:
		return grid.has_los(attacker.position, target.position)
	return true

func in_attack_range(attacker, target) -> bool:
	var skill = attacker.skills[0] if not attacker.skills.is_empty() else null
	return can_use_skill_on(attacker, skill, target)

## Where movement stops. Ranged units stop as soon as they can shoot;
## melee closes to well inside reach so strikes read as contact instead
## of edge-of-range pokes (and corpses in between don't look blocking).
func within_stop_range(attacker, target) -> bool:
	var skill = attacker.skills[0] if not attacker.skills.is_empty() else null
	if skill and skill.delivery_type == SkillDefinition.DeliveryType.PROJECTILE:
		return can_use_skill_on(attacker, skill, target)
	var dist = attacker.position.distance_to(target.position)
	return dist <= effective_range(attacker, skill) * 0.7

## Turns a stationary attacker toward its target (movement handles
## facing while walking), logging FACE when the direction meaningfully
## changes so the theater turns with it.
func face_target(entity, target):
	var dir = target.position - entity.position
	if dir.length_squared() < 1.0:
		return
	entity.facing = dir.normalized()
	if entity.facing.dot(entity.last_logged_facing) < 0.95:
		entity.last_logged_facing = entity.facing
		combat_log.add_event(
			CombatEvent.create_face(entity.entity_id, combat_time, entity.facing)
		)

# --- Movement ---------------------------------------------------------

func stop_movement(entity):
	entity.path = PackedVector2Array()
	entity.path_index = 0
	if entity.moving:
		entity.moving = false
		_log_move(entity, true)

func tick_movement(entity, target, delta):
	if entity.is_rooted():
		return

	# Re-path when the target moved to a different tile, when the path
	# was walked to the end but we're still out of range (separation
	# pushed us off), or when a failed search's retry delay elapsed —
	# a stall must never cache forever.
	var goal = grid.world_to_tile(target.position)
	var consumed = not entity.path.is_empty() \
		and entity.path_index >= entity.path.size()
	var retry = entity.path.is_empty() and combat_time >= entity.path_retry_at
	if entity.path_goal != goal or consumed or retry:
		entity.path = pathfinder.find_path(
			grid.world_to_tile(entity.position), goal
		)
		entity.path_index = 0
		entity.path_goal = goal
		if entity.path.is_empty():
			entity.path_retry_at = combat_time + 0.5
	if entity.path.is_empty():
		return

	var before = entity.position
	var budget = entity.move_speed * entity.move_speed_multiplier() * delta
	while budget > 0.0 and entity.path_index < entity.path.size():
		var waypoint = entity.path[entity.path_index]
		var dist = entity.position.distance_to(waypoint)
		if dist <= budget:
			entity.position = waypoint
			entity.path_index += 1
			budget -= dist
		else:
			entity.position += (waypoint - entity.position) / dist * budget
			budget = 0.0

	# Soft collision: paths may overlap, bodies should not stack. The
	# push must never shove anyone off the field.
	entity.position += Separation.compute_offset(
		entity.position, _other_positions(entity), SEPARATION_RADIUS, 1.0
	)
	entity.position = grid.clamp_world(entity.position)

	var moved = entity.position - before
	if moved.length_squared() > 0.01:
		entity.facing = moved.normalized()
		var started = not entity.moving
		entity.moving = true
		_log_move(entity, started)

func _other_positions(entity) -> Array:
	var out := []
	for other in heroes + enemies:
		if other != entity and other.alive:
			out.append(other.position)
	return out

## MOVE events are throttled; start/stop always log. FACE piggybacks
## when the direction changed appreciably since the last log.
func _log_move(entity, force := false):
	var last = _move_log_time.get(entity.entity_id, -INF)
	if not force and combat_time - last < MOVE_LOG_INTERVAL:
		return
	_move_log_time[entity.entity_id] = combat_time
	combat_log.add_event(
		CombatEvent.create_move(entity.entity_id, combat_time, entity.position)
	)
	if entity.facing.dot(entity.last_logged_facing) < 0.9:
		entity.last_logged_facing = entity.facing
		combat_log.add_event(
			CombatEvent.create_face(entity.entity_id, combat_time, entity.facing)
		)

func check_victory():

	var heroes_alive = false
	var enemies_alive = false

	for hero in heroes:
		if hero.alive:
			heroes_alive = true
			break

	for enemy in enemies:
		if enemy.alive:
			enemies_alive = true
			break

	if not heroes_alive or not enemies_alive:
		combat_over = true

## Most foes are common rabble; an occasional veteran shows up.
func roll_enemy_level() -> int:
	return [1, 1, 2, 2, 2, 3].pick_random() + enemy_level_bonus

## Stat multiplier for a level, with a touch of individual variance
## so two enemies of the same level aren't perfectly identical.
func level_power(level) -> float:
	return (1.0 + 0.3 * (level - 1)) * randf_range(0.9, 1.1)

## Appends a numeral when the same template appears more than once,
## so the log and nameplates can tell duplicates apart.
func unique_name(base_name, used_names):

	const NUMERALS = ["", " II", " III", " IV", " V", " VI"]

	var count = used_names.get(base_name, 0)
	used_names[base_name] = count + 1

	return base_name + NUMERALS[min(count, NUMERALS.size() - 1)]

## Places a unit near its side's spawn center: front-row units one tile
## toward the enemy, back-row one tile away, spreading across lanes.
## forward is +1 for heroes (enemies lie east), -1 for enemies.
func _spawn_position(center: Vector2i, index: int, preferred_row, forward: int) -> Vector2:
	var depth = 1 if preferred_row == Formation.Row.FRONT else -1
	var lane = (index % 3) - 1
	var rank = index / 3
	var cell = center + Vector2i(forward * (depth - rank), lane)
	return grid.tile_to_world(cell)

## hero_health: optional hero-array-index -> current hp (delve
## attrition); missing entries enter at full health.
func setup_combat(hero_templates, enemy_templates, battle_arena: BattleArena = null, hero_health := {}):

	arena = battle_arena if battle_arena else load("res://resources/arenas/open_arena.tres")
	grid = BattleGrid.new(arena)
	pathfinder = GridPathfinder.new(grid)

	var next_entity_id = 1
	var used_names = {}

	for hero_template in hero_templates:

		var hero = CombatEntity.new()

		hero.entity_id = next_entity_id
		next_entity_id += 1


		hero.team = CombatEntity.Team.HERO

		hero.template = hero_template
		hero.entity_name = unique_name(
			hero_template.hero_name, used_names
		)

		var loadout = hero_template.equipped.values()
		hero.equipped = hero_template.equipped.duplicate()
		hero.gear = loadout.duplicate()

		hero.main_weapon = hero_template.equipped.get(
			Equip.Position.MAIN_HAND, null)
		hero.off_weapon = hero_template.equipped.get(
			Equip.Position.OFF_HAND, null)
		# A shield (no attack_speed) is not a weapon.
		if hero.off_weapon and hero.off_weapon.attack_speed <= 0.0:
			hero.off_weapon = null

		hero.max_health = hero_template.base_health
		for item in loadout:
			hero.max_health += item.health_bonus

		# Attack power excluding weapons, then add the main-hand weapon.
		hero.base_attack_power = hero_template.base_attack
		for item in loadout:
			if item != hero.main_weapon and item != hero.off_weapon:
				hero.base_attack_power += item.attack_bonus

		hero.attack_power = hero.base_attack_power

		hero.current_health = clampi(
			hero_health.get(heroes.size(), hero.max_health), 1, hero.max_health
		)
		hero.current_mana = hero_template.base_mana
		hero.max_mana = hero_template.base_mana

		# Secondary stats come off the whole loadout.
		for item in loadout:
			hero.armor += item.armor
			hero.block_chance += item.block_rating
			hero.dodge_chance += item.dodge_rating
			hero.crit_chance += item.crit_rating
			hero.spell_power += item.spell_power

		# Main-hand weapon speed sets the interval; unarmed falls back.
		hero.attack_interval = (
			hero.main_weapon.attack_speed if hero.main_weapon
			and hero.main_weapon.attack_speed > 0.0
			else hero_template.base_attack_interval
		)
		if hero.main_weapon:
			hero.weapon_reach = hero.main_weapon.effective_reach()
		hero.move_speed = hero_template.move_speed
		hero.attack_timer = hero.attack_interval
		hero.off_attack_timer = hero.off_weapon.attack_speed if hero.off_weapon else 0.0

		hero.skills = hero_template.starting_skills.duplicate()
		# Loadout skill slots feed straight into combat.
		for extra in hero_template.bonus_skills:
			if extra is SkillDefinition:
				hero.skills.append(extra)

		hero.position = _spawn_position(
			arena.hero_spawn_center, heroes.size(),
			hero_template.preferred_row, 1
		)
		hero.facing = Vector2.RIGHT

		heroes.append(hero)
		entities_by_id[hero.entity_id] = hero
		combat_log.add_event(CombatEvent.create_spawn(hero))

	for enemy_template in enemy_templates:

		var enemy = CombatEntity.new()

		enemy.entity_id = next_entity_id
		next_entity_id += 1

		enemy.team = CombatEntity.Team.ENEMY
		enemy.level = roll_enemy_level()
		enemy.entity_name = (
			unique_name(enemy_template.enemy_name, used_names)
			+ " Lv %d" % enemy.level
		)

		enemy.template = enemy_template

		var power = level_power(enemy.level)
		enemy.max_health = maxi(
			1, roundi(enemy_template.base_health * power)
		)
		enemy.attack_power = maxi(
			1, roundi(enemy_template.base_attack * power)
		)

		enemy.current_health = enemy.max_health
		enemy.current_mana = enemy_template.base_mana
		enemy.max_mana = enemy_template.base_mana
		enemy.armor = enemy_template.armor
		enemy.block_chance = enemy_template.block_rating
		enemy.dodge_chance = enemy_template.dodge_rating
		enemy.crit_chance = enemy_template.crit_rating

		enemy.attack_interval = enemy_template.base_attack_interval
		enemy.attack_timer = enemy.attack_interval
		enemy.move_speed = enemy_template.move_speed

		enemy.skills = enemy_template.skills.duplicate()

		enemy.position = _spawn_position(
			arena.enemy_spawn_center, enemies.size(),
			enemy_template.preferred_row, -1
		)
		enemy.facing = Vector2.LEFT

		enemies.append(enemy)
		entities_by_id[enemy.entity_id] = enemy
		combat_log.add_event(CombatEvent.create_spawn(enemy))
	
func build_result() -> CombatResult:

	var result = CombatResult.new()

	result.victory = enemies.all(func(e): return !e.alive)
	result.duration = combat_time
	
	result.heroes = heroes.duplicate()
	result.enemies = enemies.duplicate()
	result.participants = []
	result.participants.append_array(result.heroes)
	result.participants.append_array(result.enemies)

	result.combat_log = combat_log

	for hero in heroes:
		if hero.alive:
			result.surviving_heroes.append(hero)

	for enemy in enemies:
		if enemy.alive:
			result.surviving_enemies.append(enemy)

	return result
