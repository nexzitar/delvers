extends Node

## Frost Nova roots, Hamstring slows, Charge closes and stuns, Heal
## restores and splits threat across in-combat enemies.

const FrostNova = preload("res://scripts/combat/skills/frost_nova.gd")
const Hamstring = preload("res://scripts/combat/skills/hamstring.gd")
const Charge = preload("res://scripts/combat/skills/charge.gd")
const Heal = preload("res://scripts/combat/skills/heal.gd")

func _ready():
	var delver = load("res://resources/heroes/default_delver.tres")
	var slime_t = load("res://resources/enemies/green_slime.tres")

	var combat = CombatState.new()
	combat.setup_combat([delver, delver], [slime_t, slime_t])
	var hero = combat.heroes[0]
	var buddy = combat.heroes[1]
	var slime_a = combat.enemies[0]
	var slime_b = combat.enemies[1]

	# --- Frost Nova: roots everything in the radius -------------------
	var nova = load("res://resources/skills/frost_nova.tres")
	slime_a.position = hero.position + Vector2(50, 0)
	slime_b.position = hero.position + Vector2(0, 60)
	assert(FrostNova.try_use(combat, hero, nova), "nova fires")
	assert(slime_a.is_rooted() and slime_b.is_rooted(), "nova roots both")
	assert(
		combat.combat_log.events.any(
			func(e): return e.type == CombatEvent.EventType.TELEGRAPH
		),
		"nova telegraphs"
	)
	assert(
		slime_a.threat_table.get(hero.entity_id, 0.0) > 0.0,
		"debuff generates threat"
	)

	# --- Hamstring: melee hit plus a slow ------------------------------
	var hamstring = load("res://resources/skills/hamstring.tres")
	slime_a.position = hero.position + Vector2(40, 0)
	hero.target_id = slime_a.entity_id
	var hp_before = slime_a.current_health
	assert(Hamstring.try_use(combat, hero, hamstring), "hamstring lands")
	assert(slime_a.current_health < hp_before, "hamstring damages")
	assert(slime_a.move_speed_multiplier() < 0.9, "hamstring slows")
	assert(
		not Hamstring.try_use(combat, hero, hamstring),
		"no re-hamstring while slowed"
	)

	# --- Charge: gap close, contact stop, stun -------------------------
	var charge = load("res://resources/skills/charge.tres")
	slime_b.statuses = []
	slime_b.position = hero.position + Vector2(300, 0)
	hero.target_id = slime_b.entity_id
	assert(Charge.try_use(combat, hero, charge), "charge fires")
	assert(
		hero.position.distance_to(slime_b.position) < 60.0,
		"charge closes to contact"
	)
	assert(slime_b.is_stunned(), "charge stuns")
	assert(
		not Charge.try_use(combat, hero, charge),
		"no charge at point blank"
	)

	# --- Heal: restores the injured ally, threat split on the healer ---
	var heal = load("res://resources/skills/heal.tres")
	buddy.position = hero.position + Vector2(0, 40)
	buddy.current_health = buddy.max_health - 20
	for enemy in combat.enemies:
		enemy.in_combat = true
		enemy.threat_table.erase(buddy.entity_id)
	assert(Heal.try_use(combat, buddy, heal), "self-party heal fires")
	var healed = combat.combat_log.events.filter(
		func(e): return e.type == CombatEvent.EventType.HEAL
	)
	assert(healed.size() == 1, "HEAL event logged")
	assert(healed[0].amount > 0, "heal restored health")
	var share_a = slime_a.threat_table.get(buddy.entity_id, 0.0)
	var share_b = slime_b.threat_table.get(buddy.entity_id, 0.0)
	assert(share_a > 0.0 and is_equal_approx(share_a, share_b), "heal threat split evenly")
	assert(
		is_equal_approx(share_a + share_b, float(healed[0].amount)),
		"threat totals the heal amount"
	)

	# --- Full sim smoke: a skilled party finishes a battle -------------
	var skilled = delver.duplicate(true)
	skilled.bonus_skills = [
		load("res://resources/skills/charge.tres"),
		load("res://resources/skills/hamstring.tres"),
	]
	var combat2 = CombatState.new()
	combat2.setup_combat([skilled], [slime_t])
	var steps := 0
	while not combat2.combat_over:
		combat2.update(0.1)
		steps += 1
		assert(steps < 2000, "skilled battle completes")
	assert(
		combat2.combat_log.events.any(
			func(e): return e.type == CombatEvent.EventType.BUFF_APPLIED
		),
		"skills fired during the battle"
	)

	print("PASS mvp skills")
	get_tree().quit()
