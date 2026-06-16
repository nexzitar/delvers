extends Node

func _ok(label, cond):
	print(("PASS " if cond else "FAIL ") + label)

func _ready():
	var sword = preload("res://resources/gear/starter_sword.tres")
	var t = preload("res://resources/heroes/default_delver.tres").duplicate(true)
	t.equipped = {
		Equip.Position.MAIN_HAND: sword,
		Equip.Position.OFF_HAND: sword,  # dual-wield same blade for the test
	}

	var state = CombatState.new()
	state.setup_combat([t], [preload("res://resources/enemies/green_slime.tres")])
	var hero = state.heroes[0]

	_ok("off weapon recognised", hero.off_weapon == sword)
	_ok("off timer seeded", is_equal_approx(hero.off_attack_timer, sword.attack_speed))

	# Run enough time for both hands to swing at least once; count DAMAGE
	# events sourced by the hero.
	var swings = 0
	for i in range(200):  # 200 * 0.05 = 10s
		state.update(0.05)
	for event in state.combat_log.events:
		if event.type == CombatEvent.EventType.DAMAGE \
				and event.source_id == hero.entity_id:
			swings += 1
	# At ~2.6s each, two hands over ~10s => clearly more than one hand alone.
	_ok("dual-wield produces extra swings", swings >= 5)

	get_tree().quit()
