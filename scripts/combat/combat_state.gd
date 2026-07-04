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

## Keeps the current target while it lives; otherwise picks the nearest
## living opponent. (Threat-based enemy targeting lands in Task 10.)
func validate_target(entity):
	var current = entity_by_id(entity.target_id)
	if current and current.alive:
		return
	entity.target_id = _nearest_opponent_id(entity)

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

## Task 8 gate: melee reach only. Task 9 folds in skill range and LoS.
func in_attack_range(attacker, target) -> bool:
	return attacker.position.distance_to(target.position) <= attacker.weapon_reach

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

	# Re-path only when the target has moved to a different tile.
	var goal = grid.world_to_tile(target.position)
	if entity.path.is_empty() or entity.path_goal != goal:
		entity.path = pathfinder.find_path(
			grid.world_to_tile(entity.position), goal
		)
		entity.path_index = 0
		entity.path_goal = goal
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

	# Soft collision: paths may overlap, bodies should not stack.
	entity.position += Separation.compute_offset(
		entity.position, _other_positions(entity), SEPARATION_RADIUS, 1.0
	)

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

## Picks the first free slot, trying the preferred row first.
func claim_slot(preferred_row, occupied_slots):

	for slot in Formation.fill_order(preferred_row):
		if not occupied_slots.has(slot):
			occupied_slots[slot] = true
			return slot

	push_error("No free formation slot left")
	return Formation.Slot.FRONT_CENTER

## Most foes are common rabble; an occasional veteran shows up.
func roll_enemy_level() -> int:
	return [1, 1, 2, 2, 2, 3].pick_random()

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

func setup_combat(hero_templates, enemy_templates, battle_arena: BattleArena = null):

	arena = battle_arena if battle_arena else load("res://resources/arenas/open_arena.tres")
	grid = BattleGrid.new(arena)
	pathfinder = GridPathfinder.new(grid)

	var next_entity_id = 1
	var used_names = {}
	var hero_slots_taken = {}
	var enemy_slots_taken = {}

	for hero_template in hero_templates:

		var hero = CombatEntity.new()

		hero.entity_id = next_entity_id
		next_entity_id += 1


		hero.team = CombatEntity.Team.HERO

		hero.template = hero_template
		hero.entity_name = unique_name(
			hero_template.hero_name, used_names
		)
		hero.formation_slot = claim_slot(
			hero_template.preferred_row, hero_slots_taken
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

		hero.current_health = hero.max_health
		hero.current_mana = hero_template.base_mana

		# Main-hand weapon speed sets the interval; unarmed falls back.
		hero.attack_interval = (
			hero.main_weapon.attack_speed if hero.main_weapon
			and hero.main_weapon.attack_speed > 0.0
			else hero_template.base_attack_interval
		)
		hero.attack_timer = hero.attack_interval
		hero.off_attack_timer = hero.off_weapon.attack_speed if hero.off_weapon else 0.0

		hero.skills = hero_template.starting_skills.duplicate()

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
		enemy.formation_slot = claim_slot(
			enemy_template.preferred_row, enemy_slots_taken
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

		enemy.attack_interval = enemy_template.base_attack_interval
		enemy.attack_timer = enemy.attack_interval

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
