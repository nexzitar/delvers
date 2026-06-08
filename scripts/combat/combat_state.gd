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


func get_target_for(attacker):

	var possible_targets

	if attacker.team == CombatEntity.Team.HERO:
		possible_targets = enemies
	else:
		possible_targets = heroes

	for target in possible_targets:
		if target.alive:
			return target

	return null
	
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

func setup_combat(hero_templates, enemy_templates):

	var next_entity_id = 1
	var formation_slot = 0

	for hero_template in hero_templates:

		var hero = CombatEntity.new()

		hero.entity_id = next_entity_id
		next_entity_id += 1


		hero.team = CombatEntity.Team.HERO

		hero.template = hero_template
		hero.entity_name = hero_template.hero_name
		hero.formation_slot = formation_slot
		formation_slot += 1

		hero.current_health = hero_template.base_health
		hero.current_mana = hero_template.base_mana

		hero.attack_interval = hero_template.base_attack_interval
		hero.attack_timer = hero.attack_interval

		hero.skills = hero_template.starting_skills.duplicate()

		heroes.append(hero)
		combat_log.add_event(CombatEvent.create_spawn(hero))
		
	formation_slot = 0

	for enemy_template in enemy_templates:

		var enemy = CombatEntity.new()

		enemy.entity_id = next_entity_id
		next_entity_id += 1

		enemy.team = CombatEntity.Team.ENEMY
		enemy.entity_name = enemy_template.enemy_name
		enemy.formation_slot = formation_slot
		formation_slot += 1

		enemy.template = enemy_template

		enemy.current_health = enemy_template.base_health
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
