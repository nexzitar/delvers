extends Node

func _ok(label, cond):
	print(("PASS " if cond else "FAIL ") + label)

func _make_hero(main_weapon):
	var t = preload("res://resources/heroes/default_delver.tres").duplicate(true)
	t.equipped = {}
	if main_weapon:
		t.equipped[Equip.Position.MAIN_HAND] = main_weapon
	return t

func _ready():
	var sword = preload("res://resources/gear/starter_sword.tres")
	var hero_t = _make_hero(sword)

	var state = CombatState.new()
	var enemy_t = preload("res://resources/enemies/green_slime.tres")
	state.setup_combat([hero_t], [enemy_t])

	var hero = state.heroes[0]
	_ok("interval = sword speed", is_equal_approx(hero.attack_interval, 2.6))
	_ok("attack power excludes weapon roll",
		hero.attack_power == hero_t.base_attack)

	# Unarmed falls back to template interval.
	var unarmed_t = _make_hero(null)
	var state2 = CombatState.new()
	state2.setup_combat([unarmed_t], [enemy_t])
	_ok("unarmed uses template interval",
		is_equal_approx(state2.heroes[0].attack_interval,
			unarmed_t.base_attack_interval))

	get_tree().quit()
