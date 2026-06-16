extends Node

## Autoloaded game state: the heroes the player has unlocked and the
## party's progress. Shared by the camp scenes and the battle theater.

const DEFAULT_DELVER = preload("res://resources/heroes/default_delver.tres")
const RANGER_DELVER = preload("res://resources/heroes/ranger_delver.tres")

const AUTO_ATTACK = preload("res://resources/skills/auto_attack.tres")
const ARROW_SHOT = preload("res://resources/skills/arrow_shot.tres")

const SWORD = preload("res://resources/gear/starter_sword.tres")
const BOW = preload("res://resources/gear/starter_bow.tres")
const SHIELD = preload("res://resources/gear/starter_shield.tres")
const HELMET = preload("res://resources/gear/starter_helmet.tres")
const ARMOR = preload("res://resources/gear/starter_armor.tres")

var heroes: Array = [
	DEFAULT_DELVER,
	RANGER_DELVER,
]

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
	_build_stash()

func _build_stash():
	# Distinct duplicates so a stash spare is its own physical item,
	# separate from whatever a hero already has equipped.
	gear_stash = [
		SWORD.duplicate(),
		BOW.duplicate(),
		SHIELD.duplicate(),
		HELMET.duplicate(),
		ARMOR.duplicate(),
	]

## How lively the camp fire burns, 0..1. Starts as smoldering coals
## and grows with the party's size and completed adventures.
func fire_intensity() -> float:
	return clampf(
		0.08 + heroes.size() * 0.03 + adventures_completed * 0.08,
		0.0,
		1.0
	)

# --- Loadout editing -------------------------------------------------
#
# Heroes store their loadout directly on the (shared, in-memory) hero
# template. Combat reads `starting_gear` / `starting_skills` /
# `preferred_row` straight off the template, so edits here take effect
# on the next battle. Changes last for the session only.

func equipped_item(hero_index: int, slot: int) -> GearDefinition:
	for item in heroes[hero_index].starting_gear:
		if item.slot == slot:
			return item
	return null

func attack_skill(hero_index: int) -> SkillDefinition:
	var skills = heroes[hero_index].starting_skills
	return skills[0] if not skills.is_empty() else null

func is_ranged(hero_index: int) -> bool:
	var skill = attack_skill(hero_index)
	return skill != null \
		and skill.delivery_type == SkillDefinition.DeliveryType.PROJECTILE

## Moves a stash item onto a hero. The displaced same-slot item (if
## any) returns to the stash. Two-handed/bow main hands clear the
## off-hand. Returns false if the move isn't allowed.
func equip_gear(hero_index: int, gear: GearDefinition) -> bool:

	if not gear_stash.has(gear):
		return false

	var hero = heroes[hero_index]

	# Can't strap an off-hand on while wielding a bow or two-hander.
	if gear.slot == GearDefinition.Slot.OFF_HAND and _main_hand_two_handed(hero):
		return false

	var displaced = equipped_item(hero_index, gear.slot)
	if displaced:
		hero.starting_gear.erase(displaced)
		gear_stash.append(displaced)

	gear_stash.erase(gear)
	hero.starting_gear.append(gear)

	if gear.slot == GearDefinition.Slot.MAIN_HAND:
		if gear.weapon_type in [
			GearDefinition.WeaponType.TWO_HANDED,
			GearDefinition.WeaponType.BOW,
		]:
			var off = equipped_item(hero_index, GearDefinition.Slot.OFF_HAND)
			if off:
				hero.starting_gear.erase(off)
				gear_stash.append(off)
		_sync_role(hero)

	return true

## Removes the item in a slot and returns it to the stash.
func unequip_gear(hero_index: int, slot: int) -> void:

	var hero = heroes[hero_index]
	var item = equipped_item(hero_index, slot)
	if item == null:
		return

	hero.starting_gear.erase(item)
	gear_stash.append(item)

	if slot == GearDefinition.Slot.MAIN_HAND:
		_sync_role(hero)

## Assigns a known skill as the hero's primary attack and aligns the
## formation row to its delivery type (ranged drifts to the back row).
func set_attack_skill(hero_index: int, skill: SkillDefinition) -> void:

	var hero = heroes[hero_index]

	var skills: Array[SkillDefinition] = []
	skills.append(skill)
	hero.starting_skills = skills

	hero.preferred_row = (
		Formation.Row.BACK
		if skill.delivery_type == SkillDefinition.DeliveryType.PROJECTILE
		else Formation.Row.FRONT
	)

func rename_hero(hero_index: int, new_name: String) -> void:
	var trimmed = new_name.strip_edges()
	if not trimmed.is_empty():
		heroes[hero_index].hero_name = trimmed

func _main_hand_two_handed(hero) -> bool:
	for item in hero.starting_gear:
		if item.slot == GearDefinition.Slot.MAIN_HAND:
			return item.weapon_type in [
				GearDefinition.WeaponType.TWO_HANDED,
				GearDefinition.WeaponType.BOW,
			]
	return false

## Keeps combat behaviour consistent with the equipped weapon: a bow
## makes the hero a back-row archer, anything else a front-row fighter.
func _sync_role(hero) -> void:

	var main: GearDefinition = null
	for item in hero.starting_gear:
		if item.slot == GearDefinition.Slot.MAIN_HAND:
			main = item
			break

	var skills: Array[SkillDefinition] = []

	if main != null and main.weapon_type == GearDefinition.WeaponType.BOW:
		skills.append(ARROW_SHOT)
		hero.preferred_row = Formation.Row.BACK
	else:
		skills.append(AUTO_ATTACK)
		hero.preferred_row = Formation.Row.FRONT

	hero.starting_skills = skills
