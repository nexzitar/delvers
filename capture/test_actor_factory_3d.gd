extends Node

## The 3D actor factory maps loadouts and enemy templates to rigs.

func _ready():
	var sword = load("res://resources/gear/starter_sword.tres")
	var shield = load("res://resources/gear/starter_shield.tres")
	var helmet = load("res://resources/gear/starter_helmet.tres")
	var bow = load("res://resources/gear/starter_bow.tres")

	var opts = ActorFactory3D.hero_opts({
		Equip.Position.MAIN_HAND: sword,
		Equip.Position.OFF_HAND: shield,
		Equip.Position.HEAD: helmet,
	})
	assert(opts.get("sword", false), "sword mapped")
	assert(opts.get("shield", false), "shield mapped")
	assert(opts.get("helmet", false), "helmet mapped")
	assert(not opts.get("bow", false), "no bow")

	var knight = ActorFactory3D.build_hero({
		Equip.Position.MAIN_HAND: sword,
		Equip.Position.OFF_HAND: shield,
	})
	assert(knight.sword != null, "knight rig carries a sword")
	assert(knight.shield != null, "knight rig carries a shield")
	knight.pose_death(1.0)

	var archer = ActorFactory3D.build_hero({Equip.Position.MAIN_HAND: bow})
	assert(archer.bow != null, "archer rig carries a bow")

	var dagger = load("res://resources/gear/fast_dagger.tres")
	var duelist = ActorFactory3D.build_hero({
		Equip.Position.MAIN_HAND: sword,
		Equip.Position.OFF_HAND: dagger,
	})
	assert(duelist.sword != null, "duelist main-hand blade")
	assert(duelist.off_sword != null, "duelist off-hand blade")
	assert(duelist.shield == null, "no shield when dual wielding")
	duelist.pose_swing_off(0.5)
	duelist.free()

	var slime = ActorFactory3D.build_enemy(
		load("res://resources/enemies/green_slime.tres")
	)
	assert(slime.body != null, "slime rig built")
	slime.pose_death(1.0)

	var goblin = ActorFactory3D.build_enemy(
		load("res://resources/enemies/goblin_archer.tres")
	)
	assert(goblin.bow != null, "goblin carries a bow")
	assert(goblin.scale.x < 1.0, "goblin runs small")

	for rig in [knight, archer, slime, goblin]:
		rig.free()

	# Regression: a sword hero casting (Heal) enters the shoot clock
	# with no bow — must fall back to the spellcast pose, not crash.
	var caster = ActorFactory3D.build_hero({
		Equip.Position.MAIN_HAND: load("res://resources/gear/starter_sword.tres"),
	})
	assert(caster.bow == null, "sword hero carries no bow")
	caster.pose_shoot(0.7)
	assert(caster.arm_l.rotation.x < -0.5, "spellcast raises the arms")
	caster.free()

	print("PASS actor factory 3d")
	get_tree().quit()
