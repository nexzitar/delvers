class_name Mastery

## Discipline mastery: delvers grow into their roles by practicing
## them. Equipment decides what trains; stars unlock core techniques
## and small passives; rust lowers current stars but never the highest
## earned - relearning is fast. Personal knowledge, never lost.

## Cumulative XP needed for each star (index = star).
const THRESHOLDS := [0, 8, 24, 48, 90, 140]
const MAX_STARS := 5

## Rust: XP lost per completed delve in each untrained discipline.
const RUST_PER_DELVE := 2
## Relearning below your best is this much faster.
const RELEARN_MULT := 3

## Core technique tracks. "skill" entries auto-join combat at that
## star (no slot cost); "passive" entries shape stats at setup.
const DISCIPLINES := {
	"sword": {
		"name": "Sword",
		"track": {
			2: {"skill": "cleave"},
			3: {"passive": {"attack_speed_mult": 0.95}, "label": "Weapon Familiarity"},
			4: {"skill": "hamstring"},
			5: {"skill": "whirlwind"},
		},
	},
	"shield": {
		"name": "Shield",
		"track": {
			2: {"skill": "shield_wall"},
			3: {"passive": {"block_add": 0.05}, "label": "Braced Stance"},
			4: {"skill": "thunderclap"},
			5: {"passive": {"armor_add": 1}, "label": "Iron Discipline"},
		},
	},
	"bow": {
		"name": "Bow",
		"track": {
			2: {"skill": "multishot"},
			3: {"passive": {"crit_add": 0.05}, "label": "Steady Hand"},
			4: {"skill": "piercing_shot"},
			5: {"passive": {"crit_add": 0.1}, "label": "Deadly Aim"},
		},
	},
	"dualwield": {
		"name": "Dual Wield",
		"track": {
			2: {"passive": {"attack_speed_mult": 0.96}, "label": "Ambidexterity"},
			3: {"passive": {"crit_add": 0.04}, "label": "Twin Fangs"},
			4: {"passive": {"attack_speed_mult": 0.94}, "label": "Off-Hand Training"},
			5: {"passive": {"crit_add": 0.06}, "label": "Blade Dance"},
		},
	},
	"restoration": {
		"name": "Restoration",
		"track": {
			2: {"skill": "renew"},
			3: {"passive": {"spell_power_add": 2}, "label": "Mender's Touch"},
			4: {"skill": "frost_nova"},
			5: {"passive": {"spell_power_add": 3}, "label": "Life-Warden"},
		},
	},
}

static func stars_for_xp(xp: int) -> int:
	var stars := 0
	for star in range(1, MAX_STARS + 1):
		if xp >= THRESHOLDS[star]:
			stars = star
	return stars

static func stars(hero, discipline: String) -> int:
	return stars_for_xp(int(hero.mastery.get(discipline, {}).get("xp", 0)))

static func best_stars(hero, discipline: String) -> int:
	return stars_for_xp(int(hero.mastery.get(discipline, {}).get("best_xp", 0)))

## What this loadout practices: weapons train their discipline, a
## shield trains shield, slotted healing trains restoration.
static func active_disciplines(hero) -> Array:
	var active := []
	var main = hero.equipped.get(Equip.Position.MAIN_HAND)
	if main:
		if main.weapon_type == GearDefinition.WeaponType.BOW:
			active.append("bow")
		else:
			active.append("sword")
	var off = hero.equipped.get(Equip.Position.OFF_HAND)
	if off and off.attack_speed <= 0.0:
		active.append("shield")
	elif off and off.attack_speed > 0.0:
		active.append("dualwield")
	for skill in hero.bonus_skills:
		if skill is SkillDefinition and skill.skill_id in ["heal", "renew"]:
			active.append("restoration")
			break
	return active

## Adds XP to a discipline (triple while rusty). Returns the names of
## techniques/passives newly unlocked, for the spoils toast.
static func train(hero, discipline: String, amount: int) -> Array:
	if not DISCIPLINES.has(discipline):
		return []
	var entry = hero.mastery.get(discipline, {"xp": 0, "best_xp": 0})
	var before = stars_for_xp(int(entry.xp))
	var gain = amount
	if int(entry.xp) < int(entry.best_xp):
		gain *= RELEARN_MULT
	entry.xp = int(entry.xp) + gain
	entry.best_xp = maxi(int(entry.best_xp), int(entry.xp))
	hero.mastery[discipline] = entry
	var after = stars_for_xp(int(entry.xp))

	var unlocked := []
	var track = DISCIPLINES[discipline].track
	for star in range(before + 1, after + 1):
		if not track.has(star):
			continue
		var step = track[star]
		if step.has("skill"):
			var skill = load(RosterSave.SKILL_PATHS[step.skill])
			unlocked.append({"discipline": discipline, "star": star,
				"label": skill.skill_name})
		else:
			unlocked.append({"discipline": discipline, "star": star,
				"label": step.label})
	return unlocked

## Rust: every completed delve, untrained disciplines lose a little
## current XP. The best-ever mark never moves.
static func rust(hero, trained: Array):
	for discipline in hero.mastery:
		if trained.has(discipline):
			continue
		var entry = hero.mastery[discipline]
		entry.xp = maxi(0, int(entry.xp) - RUST_PER_DELVE)
		hero.mastery[discipline] = entry

## The kit mastery grants for combat: auto-included core techniques
## (ids) and stat passives, from the disciplines currently practiced.
static func kit(hero) -> Dictionary:
	var skills := []
	var passives := {"attack_speed_mult": 1.0, "crit_add": 0.0,
		"block_add": 0.0, "armor_add": 0, "spell_power_add": 0}
	for discipline in active_disciplines(hero):
		var track = DISCIPLINES[discipline].track
		var star_count = stars(hero, discipline)
		for star in range(2, star_count + 1):
			if not track.has(star):
				continue
			var step = track[star]
			if step.has("skill"):
				skills.append(step.skill)
			else:
				for key in step.passive:
					if key == "attack_speed_mult":
						passives[key] *= step.passive[key]
					else:
						passives[key] += step.passive[key]
	return {"skills": skills, "passives": passives}

## Core techniques belong to their discipline: they cannot be slotted,
## only earned — and they only fight when the discipline is in hand.
static func core_requirement(skill_id: String):
	for discipline in DISCIPLINES:
		var track = DISCIPLINES[discipline].track
		for star in track:
			if track[star].get("skill", "") == skill_id:
				return {"discipline": discipline, "star": star}
	return null

static func is_core(skill_id: String) -> bool:
	return core_requirement(skill_id) != null
