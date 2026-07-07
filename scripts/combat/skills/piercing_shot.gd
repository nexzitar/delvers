## Piercing Shot: a single heavy arrow that punches straight through
## armor — the archer's answer to the chitin wall.

static func try_use(state, caster, skill) -> bool:
	if caster.main_weapon == null \
			or caster.main_weapon.weapon_type != GearDefinition.WeaponType.BOW:
		return false
	var target = state.entity_by_id(caster.target_id)
	if target == null or not target.alive:
		return false
	if not state.can_use_skill_on(caster, skill, target):
		return false
	# Only worth the beat against real armor or real health.
	if target.armor < 2 and target.current_health < target.max_health / 2:
		return false

	var damage = caster.attack_power \
		+ caster.main_weapon.roll_weapon_damage() \
		+ caster.main_weapon.roll_weapon_damage()
	caster._strike(state, skill, target, damage, false, true)
	return true
