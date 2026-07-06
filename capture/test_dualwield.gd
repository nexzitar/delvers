extends Node

func _ok(label, cond):
	print(("PASS " if cond else "FAIL ") + label)

func _count_hero_swings(state, hero_id) -> int:
	var n = 0
	for event in state.combat_log.events:
		if event.type == CombatEvent.EventType.DAMAGE and event.source_id == hero_id:
			n += 1
	return n

func _make_hero(off_hand):
	var sword = preload("res://resources/gear/starter_sword.tres")
	var t = preload("res://resources/heroes/default_delver.tres").duplicate(true)
	if off_hand:
		t.equipped = {
			Equip.Position.MAIN_HAND: sword,
			Equip.Position.OFF_HAND: sword,  # dual-wield same blade for the test
		}
	else:
		t.equipped = {
			Equip.Position.MAIN_HAND: sword,
		}
	return t

func _ready():
	# A slime that cannot die during the measurement window, so combat never
	# ends early and the swing count depends purely on the number of hands.
	var slime = preload("res://resources/enemies/green_slime.tres").duplicate(true)
	slime.base_health = 100000

	# Sim A: single hand (main only).
	var single_state = CombatState.new()
	single_state.setup_combat([_make_hero(false)], [slime])
	var single_hero = single_state.heroes[0]
	for i in range(200):  # 200 * 0.05 = 10s
		single_state.update(0.05)
	var single_swings = _count_hero_swings(single_state, single_hero.entity_id)

	# Sim B: dual-wield (main + off).
	var dual_state = CombatState.new()
	dual_state.setup_combat([_make_hero(true)], [slime])
	var dual_hero = dual_state.heroes[0]

	# Seed checks must happen before the timer is ticked down by the loop.
	var sword = preload("res://resources/gear/starter_sword.tres")
	_ok("off weapon recognised", dual_hero.off_weapon == sword)
	_ok("off timer seeded half a beat out of phase", is_equal_approx(dual_hero.off_attack_timer, sword.attack_speed * 0.5))

	for i in range(200):
		dual_state.update(0.05)
	var dual_swings = _count_hero_swings(dual_state, dual_hero.entity_id)

	print("single_swings=%d dual_swings=%d" % [single_swings, dual_swings])
	_ok("off hand strictly adds swings", dual_swings > single_swings)
	# Both hands share the 2.6s sword speed and the enemy never dies, so the
	# off hand exactly doubles the swing count over the same window.
	_ok("dual-wield doubles swings", dual_swings == single_swings * 2)

	# Equal-speed dual wield: main and off-hand strikes alternate, never
	# landing on the same tick (the theater can only animate one arm per
	# frame, and a flurry reads better anyway).
	var twin = load("res://resources/heroes/default_delver.tres").duplicate(true)
	twin.equipped = {
		Equip.Position.MAIN_HAND: LootTable.materialize("starter_sword", 1, 0),
		Equip.Position.OFF_HAND: LootTable.materialize("starter_sword", 1, 0),
	}
	var combat_twin = CombatState.new()
	combat_twin.setup_combat([twin], [load("res://resources/enemies/green_slime.tres")])
	var twin_hero = combat_twin.heroes[0]
	combat_twin.enemies[0].position = twin_hero.position + Vector2(40, 0)
	combat_twin.enemies[0].current_health = 999
	combat_twin.enemies[0].max_health = 999
	for i in 80:
		combat_twin.update(0.1)
	var main_times := []
	var off_times := []
	for event in combat_twin.combat_log.events:
		if event.type == CombatEvent.EventType.DAMAGE \
				and event.source_id == twin_hero.entity_id:
			if event.off_hand:
				off_times.append(event.time)
			else:
				main_times.append(event.time)
	assert(main_times.size() >= 2 and off_times.size() >= 2, "both hands strike")
	for t in off_times:
		assert(not main_times.has(t), "hands never land on the same tick")
	print("PASS dual wield alternates")

	get_tree().quit()