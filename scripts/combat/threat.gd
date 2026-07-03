class_name Threat

static func add_damage(table: Dictionary, hero_id: int, amount: float) -> void:
	table[hero_id] = table.get(hero_id, 0.0) + amount


static func add_heal_split(
		table: Dictionary,
		healer_id: int,
		amount: float,
		enemy_count_in_combat: int,
	) -> void:
	if enemy_count_in_combat <= 0:
		return
	var share = amount / float(enemy_count_in_combat)
	table[healer_id] = table.get(healer_id, 0.0) + share


static func add_aoe(
		table: Dictionary,
		hero_id: int,
		base_amount: float,
		multiplier: float = 1.0,
	) -> void:
	table[hero_id] = table.get(hero_id, 0.0) + base_amount * multiplier


static func pick_target(
		enemy,
		hero_positions: Dictionary,
		_attack_range: float,
		can_attack_fn: Callable,
	) -> int:
	var order: Array = enemy.threat_table.keys()
	order.sort_custom(func(a, b): return enemy.threat_table[a] > enemy.threat_table[b])

	for hero_id in order:
		if hero_id not in hero_positions:
			continue
		if can_attack_fn.call(hero_id, hero_positions[hero_id]):
			return hero_id

	return _nearest_hero(enemy.position, hero_positions)


static func _nearest_hero(from: Vector2, hero_positions: Dictionary) -> int:
	var best_id := -1
	var best_dist := INF
	for hero_id in hero_positions:
		var dist = from.distance_to(hero_positions[hero_id])
		if dist < best_dist:
			best_dist = dist
			best_id = hero_id
	return best_id
