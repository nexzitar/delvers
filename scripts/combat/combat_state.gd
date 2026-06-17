class_name CombatState

var heroes: Array[CombatEntity] = []
var enemies: Array[CombatEntity] = []

var combat_time: float = 0.0

var combat_log := CombatLog.new()

var combat_over: bool = false

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


func get_target_for(attacker, skill):

	var possible_targets

	if attacker.team == CombatEntity.Team.HERO:
		possible_targets = enemies
	else:
		possible_targets = heroes

	var living = possible_targets.filter(
		func(target): return target.alive
	)

	if living.is_empty():
		return null

	# Melee attacks have to go through the front row while it stands.
	# Ranged attacks can pick a target from either row.
	if skill.delivery_type == SkillDefinition.DeliveryType.MELEE:

		var front_row = living.filter(
			func(target):
				return (
					Formation.row_of(target.formation_slot)
					== Formation.Row.FRONT
				)
		)

		if not front_row.is_empty():
			return front_row.pick_random()

	return living.pick_random()
	
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

func setup_combat(hero_templates, enemy_templates):

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

		heroes.append(hero)
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

		enemies.append(enemy)
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
