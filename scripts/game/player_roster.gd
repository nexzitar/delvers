extends Node

## Autoloaded game state: the heroes the player has unlocked and the
## party's progress. Shared by the camp scenes and the battle theater.

const DEFAULT_DELVER = preload("res://resources/heroes/default_delver.tres")
const AUTO_ATTACK = preload("res://resources/skills/auto_attack.tres")
const ARROW_SHOT = preload("res://resources/skills/arrow_shot.tres")

const SWORD = preload("res://resources/gear/starter_sword.tres")
const BOW = preload("res://resources/gear/starter_bow.tres")
const SHIELD = preload("res://resources/gear/starter_shield.tres")
const HELMET = preload("res://resources/gear/starter_helmet.tres")
const ARMOR = preload("res://resources/gear/starter_armor.tres")
const FAST_DAGGER = preload("res://resources/gear/fast_dagger.tres")
const HEAVY_AXE = preload("res://resources/gear/heavy_axe.tres")

var heroes: Array = []

## Spare gear the player can drag onto heroes. Each entry is a single
## physical item: equipping it moves it onto a hero, unequipping puts
## the displaced item back here. Seeded with a few spares so the party
## can re-tool (e.g. turn the ranger into a sworder, or vice versa).
var gear_stash: Array = []

## Skills the player knows. Unlike gear these are not consumed when
## assigned, so any hero can take any known skill.
var skill_catalog: Array = [
	AUTO_ATTACK,
	ARROW_SHOT,
]

var battles_fought := 0
var adventures_completed := 0
var last_battle_won := false

## Seat assignments (seat node name -> hero index) from the last
## campfire stage. When keep_seating is set, the next stage reuses
## them, so the party stays put during the menu-to-camp transition.
var saved_seating := {}
var keep_seating := false

func _ready():
	_build_heroes()
	_build_stash()

## Both starting heroes are the same Default Delver, told apart only by
## the gear they hold. Duplicated so their loadouts are independent.
func _build_heroes():
	var melee = DEFAULT_DELVER.duplicate(true)
	melee.equipped = {}
	_seed_loadout(melee, [SWORD.duplicate(), SHIELD.duplicate(),
		HELMET.duplicate(), ARMOR.duplicate()])

	var archer = DEFAULT_DELVER.duplicate(true)
	archer.equipped = {}
	_seed_loadout(archer, [BOW.duplicate(), HELMET.duplicate(),
		ARMOR.duplicate()])

	heroes = [melee, archer]
	for hero in heroes:
		_sync_role(hero)

## Places seed items into their first accepted free position.
func _seed_loadout(hero, items: Array):
	hero.equipped = {}
	for item in items:
		for pos in Equip.accepted_positions(item):
			if not hero.equipped.has(pos):
				hero.equipped[pos] = item
				break

func _build_stash():
	# Distinct duplicates so a stash spare is its own physical item,
	# separate from whatever a hero already has equipped.
	gear_stash = [
		SWORD.duplicate(),
		BOW.duplicate(),
		SHIELD.duplicate(),
		HELMET.duplicate(),
		ARMOR.duplicate(),
		FAST_DAGGER.duplicate(),
		HEAVY_AXE.duplicate(),
	]

## How lively the camp fire burns, 0..1. Starts as smoldering coals
## and grows with the party's size and completed adventures.
func fire_intensity() -> float:
	return clampf(
		0.08 + heroes.size() * 0.03 + adventures_completed * 0.08,
		0.0,
		1.0
	)

# --- Loadout queries -------------------------------------------------

func equipped_item(hero_index: int, position: int) -> GearDefinition:
	return heroes[hero_index].equipped.get(position, null)

func attack_skill(hero_index: int) -> SkillDefinition:
	var skills = heroes[hero_index].starting_skills
	return skills[0] if not skills.is_empty() else null

func is_ranged(hero_index: int) -> bool:
	var skill = attack_skill(hero_index)
	return skill != null \
		and skill.delivery_type == SkillDefinition.DeliveryType.PROJECTILE

## Positions a stash item may go into right now (off hand is blocked by a
## two-hander/bow in the main hand).
func acceptable_positions(hero_index: int, gear: GearDefinition) -> Array:
	var hero = heroes[hero_index]
	var out := []
	for pos in Equip.accepted_positions(gear):
		if pos == Equip.Position.OFF_HAND and _main_hand_two_handed(hero):
			continue
		out.append(pos)
	return out

## Best position for a "drop anywhere" gesture: first free acceptable
## position, else the first acceptable one (to swap).
func default_position(hero_index: int, gear: GearDefinition) -> int:
	var options = acceptable_positions(hero_index, gear)
	if options.is_empty():
		return -1
	for pos in options:
		if not heroes[hero_index].equipped.has(pos):
			return pos
	return options[0]

# --- Loadout edits ---------------------------------------------------

## Moves a stash item onto a hero at a position (or its default position).
## Displaced item returns to the stash. Returns false if not allowed.
func equip_gear(hero_index: int, gear: GearDefinition, position := -1) -> bool:
	if not gear_stash.has(gear):
		return false

	var hero = heroes[hero_index]

	if position == -1:
		position = default_position(hero_index, gear)
	if position == -1:
		return false
	if not acceptable_positions(hero_index, gear).has(position):
		return false

	var displaced = hero.equipped.get(position, null)
	if displaced:
		hero.equipped.erase(position)
		gear_stash.append(displaced)

	gear_stash.erase(gear)
	hero.equipped[position] = gear

	# A two-handed/bow main hand clears the off hand.
	if position == Equip.Position.MAIN_HAND and gear.weapon_type in [
		GearDefinition.WeaponType.TWO_HANDED, GearDefinition.WeaponType.BOW,
	]:
		var off = hero.equipped.get(Equip.Position.OFF_HAND, null)
		if off:
			hero.equipped.erase(Equip.Position.OFF_HAND)
			gear_stash.append(off)

	if position in [Equip.Position.MAIN_HAND, Equip.Position.OFF_HAND]:
		_sync_role(hero)

	return true

func unequip_gear(hero_index: int, position: int) -> void:
	var hero = heroes[hero_index]
	var item = hero.equipped.get(position, null)
	if item == null:
		return
	hero.equipped.erase(position)
	gear_stash.append(item)
	if position in [Equip.Position.MAIN_HAND, Equip.Position.OFF_HAND]:
		_sync_role(hero)

func rename_hero(hero_index: int, new_name: String) -> void:
	var trimmed = new_name.strip_edges()
	if not trimmed.is_empty():
		heroes[hero_index].hero_name = trimmed

func _main_hand_two_handed(hero) -> bool:
	var main = hero.equipped.get(Equip.Position.MAIN_HAND, null)
	return main != null and main.weapon_type in [
		GearDefinition.WeaponType.TWO_HANDED, GearDefinition.WeaponType.BOW,
	]

## Combat behaviour follows the main-hand weapon: a bow makes a back-row
## archer; anything else a front-row fighter.
func _sync_role(hero) -> void:
	var main = hero.equipped.get(Equip.Position.MAIN_HAND, null)
	var skills: Array[SkillDefinition] = []
	if main != null and main.weapon_type == GearDefinition.WeaponType.BOW:
		skills.append(ARROW_SHOT)
		hero.preferred_row = Formation.Row.BACK
	else:
		skills.append(AUTO_ATTACK)
		hero.preferred_row = Formation.Row.FRONT
	hero.starting_skills = skills
