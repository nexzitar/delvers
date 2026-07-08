extends Node

## Autoloaded game state: the heroes the player has unlocked and the
## party's progress. Shared by the camp scenes and the battle theater.

const DEFAULT_DELVER = preload("res://resources/heroes/default_delver.tres")
const AUTO_ATTACK = preload("res://resources/skills/auto_attack.tres")
const ARROW_SHOT = preload("res://resources/skills/arrow_shot.tres")
const FROST_NOVA = preload("res://resources/skills/frost_nova.tres")
const HAMSTRING = preload("res://resources/skills/hamstring.tres")
const CHARGE = preload("res://resources/skills/charge.tres")
const HEAL = preload("res://resources/skills/heal.tres")

const SWORD = preload("res://resources/gear/starter_sword.tres")
const BOW = preload("res://resources/gear/starter_bow.tres")
const SHIELD = preload("res://resources/gear/starter_shield.tres")
const HELMET = preload("res://resources/gear/starter_helmet.tres")
const ARMOR = preload("res://resources/gear/starter_armor.tres")
const FAST_DAGGER = preload("res://resources/gear/fast_dagger.tres")
const HEAVY_AXE = preload("res://resources/gear/heavy_axe.tres")

var heroes: Array = []

## Loadout edits write straight to disk; tests that build throwaway
## rosters turn this off so they never touch the player's save.
var autosave := true

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
	FROST_NOVA,
	HAMSTRING,
	CHARGE,
	HEAL,
	preload("res://resources/skills/cleave.tres"),
	preload("res://resources/skills/whirlwind.tres"),
	preload("res://resources/skills/renew.tres"),
	preload("res://resources/skills/shield_wall.tres"),
	preload("res://resources/skills/thunderclap.tres"),
	preload("res://resources/skills/multishot.tres"),
	preload("res://resources/skills/piercing_shot.tres"),
	preload("res://resources/skills/battle_shout.tres"),
	preload("res://resources/skills/rally.tres"),
]

## Materials are consumed; knowledge is permanent. The camp grows more
## knowledgeable with every recipe or affix brought home.
var material_stash := {}
var known_recipes: Array = ["iron_sword"]
var known_affixes: Array = []
## Recovered history (expedition logs etc.) — pure memory, shelved in
## the camp library.
var known_lore: Array = []
## Battlefield doctrines recovered (tactic ids). A fresh guild knows
## only how to strike the nearest foe.
var known_tactics: Array = ["nearest"]
## Engineering knowledge (doctrine capacity tiers, future Engineer's
## Notebooks). No capacity, no custom doctrine: zero nodes.
var known_engineering: Array = []

func has_tool(tool_id: String) -> bool:
	return known_engineering.has(tool_id)

func doctrine_capacity() -> int:
	# The Slate is the editor itself and holds four marks; the
	# Battlefield Doctrine tomes extend what it can carry.
	if not has_tool("engineers_slate"):
		return 0
	var nodes := 4
	for entry_id in known_engineering:
		if Doctrines.CAPACITY.has(entry_id):
			nodes = maxi(nodes, int(Doctrines.CAPACITY[entry_id].nodes))
	return nodes
## Guild restoration purchases (see GuildUnlocks). The "restoration"
## marker records the free first-victory companion.
var purchased_unlocks: Array = []
## Dungeons the guild holds maps for; delves target current_dungeon.
var unlocked_dungeons: Array = ["darkwood"]
var current_dungeon := "darkwood"
## Chosen difficulty for the current delve, and the highest tier
## cleared per dungeon (clearing tier N unlocks N+1, up to MAX_TIER).
## Old dungeons never go stale: higher tiers scale foes AND spoils.
var current_tier := 1
var dungeon_progress := {}

const MAX_TIER := 5

func highest_cleared(dungeon_id: String) -> int:
	return int(dungeon_progress.get(dungeon_id, 0))

func available_tier(dungeon_id: String) -> int:
	return mini(highest_cleared(dungeon_id) + 1, MAX_TIER)

func record_clear(dungeon_id: String, tier: int):
	if tier > highest_cleared(dungeon_id):
		dungeon_progress[dungeon_id] = tier
## Party focus order (enemy_ids, first = kill first) for the
## "priority" and "spread" tactics.
var enemy_priority: Array = []
## Enemies the guild has faced — the focus order only lists these.
## No spoilers: the Broodmother isn't a name until she's a memory.
var seen_enemies: Array = []
## Cleared rooms since the last knowledge drop: three dry rooms
## guarantee a recipe (short failed runs still make progress).
var rooms_since_knowledge := 0
## One-shot camp line for arrivals ("You're not alone anymore.").
var arrival_message := ""

var battles_fought := 0
var adventures_completed := 0
var last_battle_won := false

## Bonus skill slots per hero beyond the weapon attack. Grows through
## meta progression (unlocks, not raw power).
var bonus_skill_slots := 1

## A delve is a run of up to DELVE_LENGTH rooms ending at the boss.
## Loot accumulates in the pouch and only banks into the stash (and
## the save) when the delve ends — victory or death. Health carries
## between rooms: delve_health maps hero index -> hp entering the next
## room (missing = full; 0 = down for the rest of the delve).
const DELVE_LENGTH := 10
var delve_room := 0
var delve_loot: Array = []
var delve_materials := {}
var delve_recipes: Array = []
var delve_affixes: Array = []
var delve_lore: Array = []
var delve_maps: Array = []
var delve_doctrines: Array = []
## Disciplines practiced this delve (rust skips them at banking).
var delve_trained := {}
var delve_health := {}

func start_delve(dungeon_id := "", tier := 1):
	if dungeon_id != "" and unlocked_dungeons.has(dungeon_id):
		current_dungeon = dungeon_id
	current_tier = clampi(tier, 1, available_tier(current_dungeon))
	delve_room = 1
	delve_loot = []
	delve_materials = {}
	delve_recipes = []
	delve_affixes = []
	delve_lore = []
	delve_maps = []
	delve_doctrines = []
	delve_trained = {}
	delve_health = {}

func bank_delve_loot():
	gear_stash.append_array(delve_loot)
	for material_id in delve_materials:
		material_stash[material_id] = (
			material_stash.get(material_id, 0) + delve_materials[material_id]
		)
	for recipe_id in delve_recipes:
		if not known_recipes.has(recipe_id):
			known_recipes.append(recipe_id)
	for affix_id in delve_affixes:
		if not known_affixes.has(affix_id):
			known_affixes.append(affix_id)
	for lore_id in delve_lore:
		if not known_lore.has(lore_id):
			known_lore.append(lore_id)
	for doctrine_id in delve_doctrines:
		if Doctrines.CAPACITY.has(doctrine_id) or Doctrines.TOOLS.has(doctrine_id):
			if not known_engineering.has(doctrine_id):
				known_engineering.append(doctrine_id)
		elif not known_tactics.has(doctrine_id):
			known_tactics.append(doctrine_id)
	# Rust: what this delve didn't practice, fades a little. The best
	# mark never moves.
	for hero in heroes:
		Mastery.rust(hero, delve_trained.keys())
	for dungeon_id in delve_maps:
		if RosterSave.DUNGEON_PATHS.has(dungeon_id) \
				and not unlocked_dungeons.has(dungeon_id):
			unlocked_dungeons.append(dungeon_id)
			var found = load(RosterSave.DUNGEON_PATHS[dungeon_id])
			arrival_message = "A weathered map. %s is marked." % found.dungeon_name
	delve_loot = []
	delve_materials = {}
	delve_recipes = []
	delve_affixes = []
	delve_lore = []
	delve_maps = []
	delve_doctrines = []
	delve_room = 0
	sort_gear_stash()
	check_milestones()
	if autosave:
		RosterSave.save(self)

## First victory raises the banner — and someone sees it. The first
## companion arrives free: the Restoration of the Guild.
func check_milestones():
	if adventures_completed >= 1 \
			and not purchased_unlocks.has(GuildUnlocks.RESTORATION):
		purchased_unlocks.append(GuildUnlocks.RESTORATION)
		recruit_hero(["starter_bow", "starter_helmet"])
		arrival_message = "You're not alone anymore."
		if autosave:
			RosterSave.save(self)

## A new delver answers the fire, wearing their own worn basics.
func recruit_hero(kit_ids: Array):
	var hero = DEFAULT_DELVER.duplicate(true)
	var used = heroes.map(func(h): return h.hero_name)
	for candidate in GuildUnlocks.COMPANION_NAMES:
		if not used.has(candidate):
			hero.hero_name = candidate
			break
	hero.bonus_skills = [null, null, null, null, null]
	var kit := []
	for gear_id in kit_ids:
		kit.append(LootTable.materialize(gear_id, 1, ItemQuality.Tier.COMMON))
	_seed_loadout(hero, kit)
	heroes.append(hero)
	_sync_role(hero)

## Breaks a stash item down: materials come back (roughly half the
## recipe bill), and an unfamiliar enchantment is STUDIED — salvaging
## an unknown-affix trophy teaches that affix forever.
func salvage(gear: GearDefinition) -> Dictionary:
	var index = gear_stash.find(gear)
	if index == -1:
		return {}
	gear_stash.remove_at(index)

	var yields := {}
	for recipe_id in RosterSave.RECIPE_PATHS:
		var recipe = load(RosterSave.RECIPE_PATHS[recipe_id])
		if recipe.result_gear_id != gear.gear_id:
			continue
		for material_id in recipe.costs:
			var back = maxi(1, int(recipe.costs[material_id] / 2.0))
			yields[material_id] = yields.get(material_id, 0) + back
		break
	if yields.is_empty():
		# No known pattern: scrap by kind.
		yields["iron_scrap" if gear.weapon_type != GearDefinition.WeaponType.NONE
			else "leather"] = 1
	if gear.quality >= ItemQuality.Tier.RARE:
		yields["corrosion_core"] = yields.get("corrosion_core", 0) + 1

	for material_id in yields:
		material_stash[material_id] = material_stash.get(material_id, 0) + yields[material_id]

	if gear.affix_id != "" and not known_affixes.has(gear.affix_id):
		known_affixes.append(gear.affix_id)
		yields["__learned"] = gear.affix_id

	if autosave:
		RosterSave.save(self)
	return yields

# --- Crafting ---------------------------------------------------------

## Affixes the camp knows that can enchant this recipe's result.
func compatible_affixes(recipe: RecipeDefinition) -> Array:
	var base = load(RosterSave.GEAR_PATHS[recipe.result_gear_id])
	var out := []
	for affix_id in known_affixes:
		if not RosterSave.AFFIX_PATHS.has(affix_id):
			continue
		if load(RosterSave.AFFIX_PATHS[affix_id]).compatible_with(base):
			out.append(affix_id)
	return out

## Combined material bill: the base recipe plus the chosen affix.
func craft_costs(recipe: RecipeDefinition, affix_id := "") -> Dictionary:
	var costs = recipe.costs.duplicate()
	if affix_id != "" and RosterSave.AFFIX_PATHS.has(affix_id):
		var affix = load(RosterSave.AFFIX_PATHS[affix_id])
		for material_id in affix.costs:
			costs[material_id] = costs.get(material_id, 0) + affix.costs[material_id]
	return costs

func can_craft(recipe: RecipeDefinition, affix_id := "") -> bool:
	if not known_recipes.has(recipe.recipe_id):
		return false
	if affix_id != "":
		if not known_affixes.has(affix_id):
			return false
		if not compatible_affixes(recipe).has(affix_id):
			return false
	var costs = craft_costs(recipe, affix_id)
	for material_id in costs:
		if material_stash.get(material_id, 0) < costs[material_id]:
			return false
	return true

## Consumes materials and forges the recipe's item — optionally
## enchanted ("Virulent Hunter Bow") — into the stash.
func craft(recipe: RecipeDefinition, affix_id := "") -> GearDefinition:
	if not can_craft(recipe, affix_id):
		return null
	var costs = craft_costs(recipe, affix_id)
	for material_id in costs:
		material_stash[material_id] -= costs[material_id]
		if material_stash[material_id] <= 0:
			material_stash.erase(material_id)
	var gear = LootTable.materialize(
		recipe.result_gear_id, recipe.result_item_level,
		recipe.result_quality, affix_id
	)
	# Crafted items carry the recipe's name, not the base item's.
	var affix_prefix := ""
	if affix_id != "":
		affix_prefix = load(RosterSave.AFFIX_PATHS[affix_id]).affix_name + " "
	gear.gear_name = affix_prefix + recipe.recipe_name
	gear_stash.append(gear)
	sort_gear_stash()
	if autosave:
		RosterSave.save(self)
	return gear

## Seat assignments (seat node name -> hero index) from the last
## campfire stage. When keep_seating is set, the next stage reuses
## them, so the party stays put during the menu-to-camp transition.
var saved_seating := {}
var keep_seating := false

func _ready():
	if RosterSave.load_into(self):
		return
	_build_heroes()
	_build_stash()
	if autosave:
		RosterSave.save(self)

## You start with a single sword-and-board Default Delver; more delvers
## come from meta progression later.
func _build_heroes():
	var melee = DEFAULT_DELVER.duplicate(true)
	melee.equipped = {}
	melee.bonus_skills = [null, null, null, null, null]
	_seed_loadout(melee, [SWORD.duplicate(), SHIELD.duplicate(),
		HELMET.duplicate(), ARMOR.duplicate()])

	heroes = [melee]
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
	# A new guild owns nothing beyond what it wears. Anything else is
	# found in the delve or built at the Forge.
	gear_stash = []

## Stash display order: equipment category, then rarity (high first), then item level.
func sort_gear_stash() -> void:
	gear_stash.sort_custom(func(a: GearDefinition, b: GearDefinition) -> bool:
		if a.slot != b.slot:
			return a.slot < b.slot
		if a.quality != b.quality:
			return a.quality > b.quality
		if a.power_score() != b.power_score():
			return a.power_score() > b.power_score()
		return a.gear_name < b.gear_name
	)

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

## First empty unlocked bonus-skill slot (1-based), or -1 if full.
func first_empty_bonus_skill_slot(hero_index: int) -> int:
	var hero = heroes[hero_index]
	for i in range(bonus_skill_slots):
		if i >= hero.bonus_skills.size() or hero.bonus_skills[i] == null:
			return i + 1
	return -1

## Burn the ledger: delete the save and return the guild to its
## founding day. The camp reloads around the lone delver.
func reset_save():
	var path = ProjectSettings.globalize_path(RosterSave.SAVE_PATH)
	if FileAccess.file_exists(RosterSave.SAVE_PATH):
		DirAccess.remove_absolute(path)
	battles_fought = 0
	adventures_completed = 0
	last_battle_won = false
	bonus_skill_slots = 1
	gear_stash = []
	material_stash = {}
	known_recipes = ["iron_sword"]
	known_affixes = []
	known_lore = []
	known_tactics = ["nearest"]
	known_engineering = []
	purchased_unlocks = []
	unlocked_dungeons = ["darkwood"]
	current_dungeon = "darkwood"
	current_tier = 1
	dungeon_progress = {}
	enemy_priority = []
	seen_enemies = []
	rooms_since_knowledge = 0
	arrival_message = ""
	delve_room = 0
	delve_loot = []
	delve_materials = {}
	delve_recipes = []
	delve_affixes = []
	delve_lore = []
	delve_maps = []
	delve_doctrines = []
	delve_trained = {}
	delve_health = {}
	_build_heroes()
	_build_stash()

## Practice: every cleared room trains each fielded hero's active
## disciplines. Returns star-up announcements for the spoils toast.
func train_party(hero_indices: Array, amount: int) -> Array:
	var unlocked := []
	for i in hero_indices:
		var hero = heroes[i]
		for discipline in Mastery.active_disciplines(hero):
			delve_trained[discipline] = true
			for gain in Mastery.train(hero, discipline, amount):
				gain["hero"] = hero.hero_name
				unlocked.append(gain)
	if autosave:
		RosterSave.save(self)
	return unlocked

## Called when a battle begins: whatever walks out of the dark is
## seen, win or lose.
func record_seen(enemy_ids: Array):
	var changed := false
	for enemy_id in enemy_ids:
		if not seen_enemies.has(enemy_id):
			seen_enemies.append(enemy_id)
			changed = true
	if changed and autosave:
		RosterSave.save(self)

func set_tactic(hero_index: int, tactic: String):
	if not known_tactics.has(tactic):
		return
	heroes[hero_index].tactic = tactic
	if autosave:
		RosterSave.save(self)

func equip_bonus_skill(hero_index: int, skill: SkillDefinition, slot: int) -> bool:
	# Core techniques are owned by mastery: a whirlwind needs a sword
	# in hand and the stars to back it, not a slot.
	if skill != null and Mastery.is_core(skill.skill_id):
		return false
	# One technique, one slot: no doubling up on Heal.
	if skill != null:
		var hero = heroes[hero_index]
		for i in hero.bonus_skills.size():
			if i != slot and hero.bonus_skills[i] is SkillDefinition \
					and hero.bonus_skills[i].skill_id == skill.skill_id:
				return false
	if slot < 1 or slot > bonus_skill_slots:
		return false
	var hero = heroes[hero_index]
	while hero.bonus_skills.size() < 5:
		hero.bonus_skills.append(null)
	hero.bonus_skills[slot - 1] = skill
	if autosave:
		RosterSave.save(self)
	return true

func unequip_bonus_skill(hero_index: int, slot: int) -> void:
	if slot < 1 or slot > 5:
		return
	var hero = heroes[hero_index]
	if slot - 1 < hero.bonus_skills.size():
		hero.bonus_skills[slot - 1] = null
		if autosave:
			RosterSave.save(self)

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

	sort_gear_stash()
	if autosave:
		RosterSave.save(self)
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
	sort_gear_stash()
	if autosave:
		RosterSave.save(self)

func rename_hero(hero_index: int, new_name: String) -> void:
	var trimmed = new_name.strip_edges()
	if not trimmed.is_empty():
		heroes[hero_index].hero_name = trimmed
		if autosave:
			RosterSave.save(self)

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
