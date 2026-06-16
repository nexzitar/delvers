# WoW-style Loadout, Weapon Speed & Dual-Wield — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Expand the hero loadout to a full WoW-style slot set (Layout A), add weapon attack speed and dual-wielding, and unify the two starting heroes into one Default Delver whose role is decided by gear.

**Architecture:** A new `Equip` helper defines 16 equip *positions* and maps them to/from the 14 gear *categories* in `GearDefinition.Slot`. The hero loadout becomes a position-keyed dictionary (`equipped`) on the runtime `HeroTemplate`, replacing the "array searched by slot" model. Combat derives a hero's attack interval from the main-hand weapon's `attack_speed` and adds a second off-hand attack timer (50% damage) when a one-handed weapon is dual-wielded. The loadout screen is rebuilt into two slot columns flanking the live preview, a weapon row, and a 6-slot skill row, with a tabbed Gear/Skills panel on the right.

**Tech Stack:** Godot 4.6, GDScript. Tests are headless `.gd` scripts run via the Godot binary that print `PASS`/`FAIL` and `quit()`.

---

## Conventions for this plan

- **Godot binary:** `/Applications/Godot.app/Contents/MacOS/Godot` (referred to below as `$GODOT`). Define once: `GODOT=/Applications/Godot.app/Contents/MacOS/Godot`.
- **Run a test:** `$GODOT --headless --path . capture/<name>.tscn`. Headless hangs if a script awaits `RenderingServer.frame_post_draw`, so **logic tests must never take screenshots** — they only assert and `quit()`.
- **Test harness pattern:** each test is a `Node` script with a `.tscn` that has only that script attached. It prints `PASS <label>` / `FAIL <label>` and calls `get_tree().quit()` at the end. Wrap runs so a hung process is killed:
  ```bash
  ( $GODOT --headless --path . capture/<name>.tscn 2>&1; echo "EXIT=$?" ) | rg -i "PASS|FAIL|error|EXIT" & sleep 15; pkill -f <name>.tscn 2>/dev/null; wait
  ```
- A run is green only if every line is `PASS` and there is no `FAIL` / script error.
- `ObjectDB instances leaked at exit` warnings are expected when calling `quit()` mid-scene; ignore them.

---

## Task 1: Equip positions + GearDefinition categories & attack_speed

**Files:**
- Create: `scripts/data/equip.gd`
- Modify: `scripts/data/gear_definition.gd`
- Test: `capture/test_equip.gd`, `capture/test_equip.tscn`

- [ ] **Step 1: Extend `GearDefinition` with the full category set and `attack_speed`**

Replace the `Slot` enum (keep 0–3 stable so existing `.tres` stay valid) and add `attack_speed`:

```gdscript
extends Resource
class_name GearDefinition

# Indices 0-3 are frozen: existing .tres files store slot = 2 (MAIN_HAND),
# slot = 3 (OFF_HAND). New categories are appended.
enum Slot {
	HEAD = 0,
	CHEST = 1,
	MAIN_HAND = 2,
	OFF_HAND = 3,
	NECK,
	SHOULDER,
	BACK,
	WRIST,
	HANDS,
	WAIST,
	LEGS,
	FEET,
	RING,
	TRINKET,
}

enum WeaponType {
	NONE,
	ONE_HANDED,
	TWO_HANDED,
	BOW
}

@export var gear_id: String
@export var gear_name: String
@export var slot: Slot
@export var weapon_type: WeaponType = WeaponType.NONE

@export_group("Visuals")
## Sprite drawn on the character (paper-doll layer).
@export var texture: Texture2D
## Inventory/selection icon. Falls back to texture when unset.
@export var icon: Texture2D
## Offset and scale are in the body sprite's local pixel space.
@export var offset: Vector2
@export var scale: float = 1.0
@export var rotation_degrees: float = 0.0

@export_group("Stats")
@export var attack_bonus: int = 0
@export var health_bonus: int = 0
## Seconds per swing. Only meaningful for weapons; 0 elsewhere.
@export var attack_speed: float = 0.0
```

- [ ] **Step 2: Create the `Equip` position helper**

```gdscript
class_name Equip

## Equip POSITIONS (where an item physically sits). Distinct from
## GearDefinition.Slot, which is the item's CATEGORY. Rings and trinkets
## are the only categories with two positions.
enum Position {
	HEAD, NECK, SHOULDER, BACK, CHEST, WRIST, HANDS,
	WAIST, LEGS, FEET, RING_1, RING_2, TRINKET_1, TRINKET_2,
	MAIN_HAND, OFF_HAND,
}

## Display columns for Layout A (top to bottom).
const COLUMN_LEFT := [
	Position.HEAD, Position.NECK, Position.SHOULDER, Position.BACK,
	Position.CHEST, Position.WRIST, Position.HANDS,
]
const COLUMN_RIGHT := [
	Position.WAIST, Position.LEGS, Position.FEET, Position.RING_1,
	Position.RING_2, Position.TRINKET_1, Position.TRINKET_2,
]
const WEAPON_ROW := [Position.MAIN_HAND, Position.OFF_HAND]

const ALL := [
	Position.HEAD, Position.NECK, Position.SHOULDER, Position.BACK,
	Position.CHEST, Position.WRIST, Position.HANDS, Position.WAIST,
	Position.LEGS, Position.FEET, Position.RING_1, Position.RING_2,
	Position.TRINKET_1, Position.TRINKET_2, Position.MAIN_HAND,
	Position.OFF_HAND,
]

const LABELS := {
	Position.HEAD: "Head", Position.NECK: "Neck", Position.SHOULDER: "Shoulder",
	Position.BACK: "Back", Position.CHEST: "Chest", Position.WRIST: "Wrist",
	Position.HANDS: "Hands", Position.WAIST: "Waist", Position.LEGS: "Legs",
	Position.FEET: "Feet", Position.RING_1: "Ring", Position.RING_2: "Ring",
	Position.TRINKET_1: "Trinket", Position.TRINKET_2: "Trinket",
	Position.MAIN_HAND: "Main Hand", Position.OFF_HAND: "Off Hand",
}

static func label(pos: int) -> String:
	return LABELS.get(pos, "?")

## The category that lives in a position.
static func category_of(pos: int) -> int:
	match pos:
		Position.RING_1, Position.RING_2:
			return GearDefinition.Slot.RING
		Position.TRINKET_1, Position.TRINKET_2:
			return GearDefinition.Slot.TRINKET
		Position.HEAD: return GearDefinition.Slot.HEAD
		Position.NECK: return GearDefinition.Slot.NECK
		Position.SHOULDER: return GearDefinition.Slot.SHOULDER
		Position.BACK: return GearDefinition.Slot.BACK
		Position.CHEST: return GearDefinition.Slot.CHEST
		Position.WRIST: return GearDefinition.Slot.WRIST
		Position.HANDS: return GearDefinition.Slot.HANDS
		Position.WAIST: return GearDefinition.Slot.WAIST
		Position.LEGS: return GearDefinition.Slot.LEGS
		Position.FEET: return GearDefinition.Slot.FEET
		Position.MAIN_HAND: return GearDefinition.Slot.MAIN_HAND
		Position.OFF_HAND: return GearDefinition.Slot.OFF_HAND
	return GearDefinition.Slot.HEAD

## Positions an item of this category can occupy (before weapon rules).
static func positions_for(category: int) -> Array:
	match category:
		GearDefinition.Slot.RING:
			return [Position.RING_1, Position.RING_2]
		GearDefinition.Slot.TRINKET:
			return [Position.TRINKET_1, Position.TRINKET_2]
	for pos in ALL:
		if category_of(pos) == category:
			return [pos]
	return []

## Positions an actual gear item accepts, applying the dual-wield rule:
## a one-handed weapon may also go in the off hand.
static func accepted_positions(gear: GearDefinition) -> Array:
	var positions = positions_for(gear.slot)
	if gear.slot == GearDefinition.Slot.MAIN_HAND \
			and gear.weapon_type == GearDefinition.WeaponType.ONE_HANDED:
		positions = positions.duplicate()
		positions.append(Position.OFF_HAND)
	return positions
```

- [ ] **Step 3: Write the failing test**

`capture/test_equip.gd`:

```gdscript
extends Node

func _ok(label, cond):
	print(("PASS " if cond else "FAIL ") + label)

func _ready():
	# Frozen category indices.
	_ok("HEAD=0", GearDefinition.Slot.HEAD == 0)
	_ok("MAIN_HAND=2", GearDefinition.Slot.MAIN_HAND == 2)
	_ok("OFF_HAND=3", GearDefinition.Slot.OFF_HAND == 3)

	# Rings map to two positions; head to one.
	_ok("ring -> 2 positions",
		Equip.positions_for(GearDefinition.Slot.RING).size() == 2)
	_ok("head -> 1 position",
		Equip.positions_for(GearDefinition.Slot.HEAD).size() == 1)
	_ok("ring_2 category is RING",
		Equip.category_of(Equip.Position.RING_2) == GearDefinition.Slot.RING)

	# One-handed weapon accepts main and off hand; a bow does not.
	var sword = GearDefinition.new()
	sword.slot = GearDefinition.Slot.MAIN_HAND
	sword.weapon_type = GearDefinition.WeaponType.ONE_HANDED
	_ok("1H accepts main+off", Equip.accepted_positions(sword).size() == 2)

	var bow = GearDefinition.new()
	bow.slot = GearDefinition.Slot.MAIN_HAND
	bow.weapon_type = GearDefinition.WeaponType.BOW
	_ok("bow accepts only main", Equip.accepted_positions(bow).size() == 1)

	_ok("16 positions total", Equip.ALL.size() == 16)
	get_tree().quit()
```

`capture/test_equip.tscn`:

```
[gd_scene load_steps=2 format=3 uid="uid://b1equip0test001"]
[ext_resource type="Script" path="res://capture/test_equip.gd" id="1_t"]
[node name="TestEquip" type="Node"]
script = ExtResource("1_t")
```

- [ ] **Step 4: Run the test**

Run:
```bash
GODOT=/Applications/Godot.app/Contents/MacOS/Godot
( $GODOT --headless --path . capture/test_equip.tscn 2>&1; echo EXIT=$? ) | rg -i "PASS|FAIL|error|EXIT" & sleep 12; pkill -f test_equip.tscn 2>/dev/null; wait
```
Expected: 8 `PASS`, no `FAIL`.

- [ ] **Step 5: Commit**

```bash
git add scripts/data/equip.gd scripts/data/gear_definition.gd capture/test_equip.gd capture/test_equip.tscn
git commit -m "Add full gear category set, equip positions, and weapon attack_speed"
```

---

## Task 2: Set attack_speed on existing weapons (no behavior change yet)

**Files:**
- Modify: `resources/gear/starter_sword.tres`, `resources/gear/starter_bow.tres`
- Test: covered by Task 4's combat test (no separate test here; this is data only).

- [ ] **Step 1: Add `attack_speed` to the sword**

In `resources/gear/starter_sword.tres`, under `[resource]`, add a line after `attack_bonus = 1`:
```
attack_speed = 2.6
```

- [ ] **Step 2: Add `attack_speed` to the bow**

In `resources/gear/starter_bow.tres`, under `[resource]`, add after `attack_bonus = 2`:
```
attack_speed = 2.8
```

- [ ] **Step 3: Sanity-load the project headlessly**

Run:
```bash
GODOT=/Applications/Godot.app/Contents/MacOS/Godot
( $GODOT --headless --path . --quit 2>&1; echo EXIT=$? ) | rg -i "error|EXIT"
```
Expected: `EXIT=0`, no parse/load errors.

- [ ] **Step 4: Commit**

```bash
git add resources/gear/starter_sword.tres resources/gear/starter_bow.tres
git commit -m "Give starter weapons attack speeds (sword 2.6s, bow 2.8s)"
```

---

## Task 3: Position-keyed loadout in PlayerRoster

Replace the "array searched by slot" model with a position-keyed `equipped` dictionary on the runtime hero template. `starting_gear` stays as the seed list; the roster builds `equipped` from it.

**Files:**
- Modify: `scripts/data/hero_template.gd`
- Modify: `scripts/game/player_roster.gd`
- Test: `capture/test_loadout.gd`, `capture/test_loadout.tscn`

- [ ] **Step 1: Add a runtime `equipped` dict to `HeroTemplate`**

Append to `scripts/data/hero_template.gd`:
```gdscript
## Runtime, position-keyed loadout (Equip.Position -> GearDefinition).
## Built by PlayerRoster from starting_gear; not exported/saved.
var equipped := {}
```

- [ ] **Step 2: Rewrite the loadout layer in `PlayerRoster`**

Replace the block from `func _build_stash():` through `_sync_role` (everything from the stash builder to the end of file) with the position-keyed implementation below. Constants/vars at the top of the file (heroes, stash, catalog, preloads) stay as they are, except `heroes` and `_ready` change as shown.

Change `heroes` initialization and `_ready`:
```gdscript
var heroes: Array = []

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
```

Replace `equipped_item`, `attack_skill`, `is_ranged`, `equip_gear`, `unequip_gear`, `_main_hand_two_handed`, and `_sync_role` with position-aware versions, and remove the old slot-array `equipped_item`:

```gdscript
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
```

Note: `set_attack_skill` is removed (the attack is weapon-driven now; the skill-slot is read-only in the UI). `fire_intensity` and the saved-seating vars are unchanged.

- [ ] **Step 3: Write the failing test**

`capture/test_loadout.gd`:
```gdscript
extends Node

func _ok(label, cond):
	print(("PASS " if cond else "FAIL ") + label)

func _ready():
	var roster = preload("res://scripts/game/player_roster.gd").new()
	add_child(roster)  # triggers _ready -> _build_heroes/_build_stash

	# Two independent heroes from the same base.
	_ok("two heroes", roster.heroes.size() == 2)
	_ok("hero loadouts independent",
		roster.heroes[0].equipped != roster.heroes[1].equipped)

	# Hero 0 is melee with a sword in the main hand; hero 1 ranged (bow).
	var h0_main = roster.equipped_item(0, Equip.Position.MAIN_HAND)
	_ok("hero0 has main-hand weapon", h0_main != null)
	_ok("hero0 melee", not roster.is_ranged(0))
	_ok("hero1 ranged", roster.is_ranged(1))

	# Equip a stash sword into hero0's OFF hand (dual wield).
	var spare_sword = null
	for g in roster.gear_stash:
		if g.slot == GearDefinition.Slot.MAIN_HAND \
				and g.weapon_type == GearDefinition.WeaponType.ONE_HANDED:
			spare_sword = g
			break
	_ok("found spare 1H sword", spare_sword != null)
	var ok = roster.equip_gear(0, spare_sword, Equip.Position.OFF_HAND)
	_ok("equipped 1H in off hand", ok)
	_ok("off hand holds the sword",
		roster.equipped_item(0, Equip.Position.OFF_HAND) == spare_sword)

	# A bow in the main hand should clear the off hand.
	var bow = null
	for g in roster.gear_stash:
		if g.weapon_type == GearDefinition.WeaponType.BOW:
			bow = g
			break
	roster.equip_gear(0, bow, Equip.Position.MAIN_HAND)
	_ok("bow cleared off hand",
		roster.equipped_item(0, Equip.Position.OFF_HAND) == null)
	_ok("bow flips hero0 to ranged", roster.is_ranged(0))

	get_tree().quit()
```

`capture/test_loadout.tscn`:
```
[gd_scene load_steps=2 format=3 uid="uid://b2loadout0test01"]
[ext_resource type="Script" path="res://capture/test_loadout.gd" id="1_t"]
[node name="TestLoadout" type="Node"]
script = ExtResource("1_t")
```

- [ ] **Step 4: Run the test**

```bash
GODOT=/Applications/Godot.app/Contents/MacOS/Godot
( $GODOT --headless --path . capture/test_loadout.tscn 2>&1; echo EXIT=$? ) | rg -i "PASS|FAIL|error|EXIT" & sleep 14; pkill -f test_loadout.tscn 2>/dev/null; wait
```
Expected: all `PASS`, no `FAIL`.

- [ ] **Step 5: Commit**

```bash
git add scripts/data/hero_template.gd scripts/game/player_roster.gd capture/test_loadout.gd capture/test_loadout.tscn
git commit -m "Switch hero loadout to a position-keyed model with dual-wield support"
```

---

## Task 4: Weapon speed drives the hero attack interval

**Files:**
- Modify: `scripts/combat/combat_state.gd` (hero branch of `setup_combat`)
- Modify: `scripts/combat/combat_entity.gd` (store main/off weapon + computed fields)
- Test: `capture/test_combat_speed.gd`, `capture/test_combat_speed.tscn`

- [ ] **Step 1: Add weapon/attack fields to `CombatEntity`**

In `scripts/combat/combat_entity.gd`, add fields near the other vars (after `var skills := []`):
```gdscript
# Per-hand attack model. base_attack_power excludes weapon damage so the
# off-hand swing can be computed independently.
var base_attack_power: int = 0
var main_weapon: GearDefinition = null
var off_weapon: GearDefinition = null
var off_attack_timer: float = 0.0
const OFF_HAND_FACTOR := 0.5
const UNARMED_INTERVAL := 2.0
```

- [ ] **Step 2: Build the hero's attack stats from the loadout**

In `scripts/combat/combat_state.gd`, replace the hero stat block. Find:
```gdscript
		hero.gear = hero_template.starting_gear.duplicate()

		hero.max_health = hero_template.base_health
		hero.attack_power = hero_template.base_attack

		for item in hero.gear:
			hero.max_health += item.health_bonus
			hero.attack_power += item.attack_bonus

		hero.current_health = hero.max_health
		hero.current_mana = hero_template.base_mana

		hero.attack_interval = hero_template.base_attack_interval
		hero.attack_timer = hero.attack_interval
```
Replace with:
```gdscript
		var loadout = hero_template.equipped.values()
		hero.gear = loadout.duplicate()

		hero.main_weapon = hero_template.equipped.get(
			Equip.Position.MAIN_HAND, null)
		hero.off_weapon = hero_template.equipped.get(
			Equip.Position.OFF_HAND, null)
		# A shield (no attack_speed) is not a weapon.
		if hero.off_weapon and hero.off_weapon.attack_speed <= 0.0:
			hero.off_weapon = null

		hero.max_health = hero_template.base_health
		for item in loadout:
			hero.max_health += item.health_bonus

		# Attack power excluding weapons, then add the main-hand weapon.
		hero.base_attack_power = hero_template.base_attack
		for item in loadout:
			if item != hero.main_weapon and item != hero.off_weapon:
				hero.base_attack_power += item.attack_bonus

		hero.attack_power = hero.base_attack_power
		if hero.main_weapon:
			hero.attack_power += hero.main_weapon.attack_bonus

		hero.current_health = hero.max_health
		hero.current_mana = hero_template.base_mana

		# Main-hand weapon speed sets the interval; unarmed falls back.
		hero.attack_interval = (
			hero.main_weapon.attack_speed if hero.main_weapon
			and hero.main_weapon.attack_speed > 0.0
			else hero_template.base_attack_interval
		)
		hero.attack_timer = hero.attack_interval
		hero.off_attack_timer = hero.off_weapon.attack_speed if hero.off_weapon else 0.0
```

- [ ] **Step 3: Write the failing test**

`capture/test_combat_speed.gd`:
```gdscript
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
	_ok("attack power includes weapon",
		hero.attack_power == hero_t.base_attack + sword.attack_bonus)

	# Unarmed falls back to template interval.
	var unarmed_t = _make_hero(null)
	var state2 = CombatState.new()
	state2.setup_combat([unarmed_t], [enemy_t])
	_ok("unarmed uses template interval",
		is_equal_approx(state2.heroes[0].attack_interval,
			unarmed_t.base_attack_interval))

	get_tree().quit()
```

`capture/test_combat_speed.tscn`:
```
[gd_scene load_steps=2 format=3 uid="uid://b3speed0test001"]
[ext_resource type="Script" path="res://capture/test_combat_speed.gd" id="1_t"]
[node name="TestSpeed" type="Node"]
script = ExtResource("1_t")
```

- [ ] **Step 4: Run the test**

```bash
GODOT=/Applications/Godot.app/Contents/MacOS/Godot
( $GODOT --headless --path . capture/test_combat_speed.tscn 2>&1; echo EXIT=$? ) | rg -i "PASS|FAIL|error|EXIT" & sleep 14; pkill -f test_combat_speed.tscn 2>/dev/null; wait
```
Expected: all `PASS`.

- [ ] **Step 5: Commit**

```bash
git add scripts/combat/combat_entity.gd scripts/combat/combat_state.gd capture/test_combat_speed.gd capture/test_combat_speed.tscn
git commit -m "Derive hero attack interval and power from equipped weapons"
```

---

## Task 5: Dual-wield off-hand attack (second timer, 50% damage)

**Files:**
- Modify: `scripts/combat/combat_entity.gd`
- Test: `capture/test_dualwield.gd`, `capture/test_dualwield.tscn`

- [ ] **Step 1: Tick the off-hand timer and add an off-hand swing**

In `scripts/combat/combat_entity.gd`, replace `func update(delta, combat_state):` and add an off-hand swing method:
```gdscript
func update(delta, combat_state):
	attack_timer -= delta
	if attack_timer <= 0:
		perform_auto_attack(combat_state)
		attack_timer = attack_interval

	if off_weapon:
		off_attack_timer -= delta
		if off_attack_timer <= 0:
			perform_off_hand_attack(combat_state)
			off_attack_timer = off_weapon.attack_speed
```

Refactor `perform_auto_attack` to share damage emission. Replace the existing
`perform_auto_attack` with a version that delegates to a common striker:
```gdscript
func perform_auto_attack(combat_state):
	var damage = attack_power + randi_range(
		skills[0].base_min_damage, skills[0].base_max_damage)
	_strike(combat_state, skills[0], damage)

func perform_off_hand_attack(combat_state):
	# Off hand uses base power (no main-hand weapon) + its own weapon, halved.
	var raw = base_attack_power + off_weapon.attack_bonus + randi_range(
		skills[0].base_min_damage, skills[0].base_max_damage)
	var damage = maxi(1, floori(OFF_HAND_FACTOR * raw))
	_strike(combat_state, skills[0], damage)

func _strike(combat_state, skill, damage):
	var target = combat_state.get_target_for(self, skill)
	if target == null:
		return

	var died = target.take_damage(damage)

	var event = CombatEvent.new()
	event.time = combat_state.combat_time
	event.type = CombatEvent.EventType.DAMAGE
	event.source_id = entity_id
	event.target_id = target.entity_id
	event.source_name = entity_name
	event.target_name = target.entity_name
	event.remaining_health = target.current_health
	event.max_health = target.max_health
	event.skill_name = skill.skill_name
	event.skill = skill
	event.amount = damage
	combat_state.add_event(event)

	if died:
		var death = CombatEvent.new()
		death.time = combat_state.combat_time
		death.type = CombatEvent.EventType.DEATH
		death.target_id = target.entity_id
		death.target_name = target.entity_name
		combat_state.add_event(death)
```

- [ ] **Step 2: Write the failing test**

`capture/test_dualwield.gd`:
```gdscript
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
```

(Verified: `CombatLog` exposes its array as `events`, so `state.combat_log.events` is correct.)

`capture/test_dualwield.tscn`:
```
[gd_scene load_steps=2 format=3 uid="uid://b4dual0test0001"]
[ext_resource type="Script" path="res://capture/test_dualwield.gd" id="1_t"]
[node name="TestDual" type="Node"]
script = ExtResource("1_t")
```

- [ ] **Step 3: Run the test**

```bash
GODOT=/Applications/Godot.app/Contents/MacOS/Godot
( $GODOT --headless --path . capture/test_dualwield.tscn 2>&1; echo EXIT=$? ) | rg -i "PASS|FAIL|error|EXIT" & sleep 14; pkill -f test_dualwield.tscn 2>/dev/null; wait
```
Expected: all `PASS`.

- [ ] **Step 4: Commit**

```bash
git add scripts/combat/combat_entity.gd capture/test_dualwield.gd capture/test_dualwield.tscn
git commit -m "Add dual-wield off-hand attack on its own timer at 50% damage"
```

---

## Task 6: Remove the Ranger Delver template

The roster already builds both heroes from `DEFAULT_DELVER` (Task 3), so the ranger resource and its constant are now unused.

**Files:**
- Delete: `resources/heroes/ranger_delver.tres` (and its `.import`/`.uid` siblings if present)
- Modify: `scripts/game/player_roster.gd` (remove `RANGER_DELVER` const)
- Grep: confirm no other references.

- [ ] **Step 1: Find all references**

Run (use ripgrep, not find):
```bash
rg -n "ranger_delver|RANGER_DELVER" --hidden
```
Expected after edits: zero matches outside this plan/spec/README history.

- [ ] **Step 2: Remove the constant**

In `scripts/game/player_roster.gd`, delete the line:
```gdscript
const RANGER_DELVER = preload("res://resources/heroes/ranger_delver.tres")
```

- [ ] **Step 3: Delete the resource files**

```bash
rm -f resources/heroes/ranger_delver.tres resources/heroes/ranger_delver.tres.uid
```
(If a `.import` file exists, remove it too. Verify with `rg`/`ls` first.)

- [ ] **Step 4: Sanity-load + re-run the loadout test**

```bash
GODOT=/Applications/Godot.app/Contents/MacOS/Godot
( $GODOT --headless --path . capture/test_loadout.tscn 2>&1; echo EXIT=$? ) | rg -i "PASS|FAIL|error|EXIT" & sleep 14; pkill -f test_loadout.tscn 2>/dev/null; wait
```
Expected: all `PASS` (proves the roster no longer needs the ranger).

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "Unify heroes on Default Delver; remove Ranger Delver template"
```

---

## Task 7: New weapons + empty-slot and skill placeholder art

**Files:**
- Create art (via the image tool): `art/gear/fast_dagger.png`, `art/gear/heavy_axe.png`, and `art/ui/slots/empty_<category>.png` for each category, plus `art/ui/slots/empty_skill.png`.
- Create: `resources/gear/fast_dagger.tres`, `resources/gear/heavy_axe.tres`
- Modify: `scripts/game/player_roster.gd` (`_build_stash` to add the new weapons)
- Test: visual (Task 10 screenshot) + the loadout test still green.

- [ ] **Step 1: Generate the weapon art**

Generate two pixel-art weapon sprites consistent with `art/gear/starter_sword.png` (side-on, transparent background), sized to match. A short fast dagger and a large two-handed axe. Save as `art/gear/fast_dagger.png` and `art/gear/heavy_axe.png`. Trim transparent margins.

- [ ] **Step 2: Generate empty-slot silhouette icons**

Generate faint, uniform silhouette icons (dark, ~40% opacity look) on the same square frame for each category: head (helm), neck (amulet), shoulder (pauldron), back (cloak), chest (breastplate), wrist (bracer), hands (gauntlet), waist (belt), legs (greaves), feet (boot), ring, trinket, main hand (sword), off hand (shield), and a skill slot (rune/star). Save to `art/ui/slots/empty_<category>.png` and `art/ui/slots/empty_skill.png`. Keep them stylistically matched and same dimensions (e.g. 128×128).

- [ ] **Step 3: Author the weapon resources**

`resources/gear/fast_dagger.tres` (one-handed, fast/soft — DPS ≈ sword):
```
[gd_resource type="Resource" script_class="GearDefinition" format=3]
[ext_resource type="Script" path="res://scripts/data/gear_definition.gd" id="1_gear"]
[ext_resource type="Texture2D" path="res://art/gear/fast_dagger.png" id="2_tex"]
[resource]
resource_name = "Fast Dagger"
script = ExtResource("1_gear")
gear_id = "fast_dagger"
gear_name = "Fast Dagger"
slot = 2
weapon_type = 1
texture = ExtResource("2_tex")
icon = ExtResource("2_tex")
offset = Vector2(68, 65)
scale = 0.3
rotation_degrees = 90.0
attack_bonus = 1
attack_speed = 1.5
```
(Tuning note: sword does ~`attack_bonus 1 / 2.6s`; dagger ~`1 / 1.5s` is slightly higher DPS but lower per hit — adjust `attack_bonus` to 0 or keep 1 after the combat sanity check in Step 6; pick the value that keeps per-second contribution closest to the sword.)

`resources/gear/heavy_axe.tres` (two-handed, slow/hard):
```
[gd_resource type="Resource" script_class="GearDefinition" format=3]
[ext_resource type="Script" path="res://scripts/data/gear_definition.gd" id="1_gear"]
[ext_resource type="Texture2D" path="res://art/gear/heavy_axe.png" id="2_tex"]
[resource]
resource_name = "Heavy Axe"
script = ExtResource("1_gear")
gear_id = "heavy_axe"
gear_name = "Heavy Axe"
slot = 2
weapon_type = 2
texture = ExtResource("2_tex")
icon = ExtResource("2_tex")
offset = Vector2(60, 60)
scale = 0.5
rotation_degrees = 90.0
attack_bonus = 5
attack_speed = 3.4
```

- [ ] **Step 4: Add the new weapons to the stash**

In `scripts/game/player_roster.gd`, add preloads near the other gear consts:
```gdscript
const DAGGER = preload("res://resources/gear/fast_dagger.tres")
const AXE = preload("res://resources/gear/heavy_axe.tres")
```
And extend `_build_stash`:
```gdscript
func _build_stash():
	gear_stash = [
		SWORD.duplicate(),
		BOW.duplicate(),
		SHIELD.duplicate(),
		HELMET.duplicate(),
		ARMOR.duplicate(),
		DAGGER.duplicate(),
		AXE.duplicate(),
	]
```

- [ ] **Step 5: Sanity-load + loadout test**

```bash
GODOT=/Applications/Godot.app/Contents/MacOS/Godot
( $GODOT --headless --path . capture/test_loadout.tscn 2>&1; echo EXIT=$? ) | rg -i "PASS|FAIL|error|EXIT" & sleep 14; pkill -f test_loadout.tscn 2>/dev/null; wait
```
Expected: all `PASS`.

- [ ] **Step 6: DPS sanity (optional, informative)**

Temporarily print the per-second contribution (`attack_bonus / attack_speed`) for sword/dagger/axe in a scratch script or compute by hand; nudge `attack_bonus` so they're within ~15% of each other. Then re-run Step 5.

- [ ] **Step 7: Commit**

```bash
git add art/gear/fast_dagger.png art/gear/heavy_axe.png art/ui/slots resources/gear/fast_dagger.tres resources/gear/heavy_axe.tres scripts/game/player_roster.gd
git commit -m "Add fast dagger, heavy axe, and empty slot/skill placeholder icons"
```

---

## Task 8: Rebuild the loadout screen to Layout A

Rebuild `loadout_screen.gd`'s left panel into two slot columns flanking the preview, a weapon row, and a 6-slot skill row; make the right side a tabbed Gear/Skills panel; show empty-slot icons; and update the tooltip (weapon speed + both hands).

**Files:**
- Modify: `scripts/camp/loadout/loadout_screen.gd`
- Reference: `scripts/camp/loadout/drop_target.gd`, `scripts/camp/loadout/loadout_icon.gd` (Task 9 wires these to positions)
- Test: `capture/test_loadout_ui.gd`, `capture/test_loadout_ui.tscn` (headless build check, no screenshot)

- [ ] **Step 1: Replace slot constants with positions**

In `loadout_screen.gd`, remove `SLOT_ORDER` and `SLOT_LABELS` (the 4-slot constants) and add:
```gdscript
const EMPTY_ICONS := {
	GearDefinition.Slot.HEAD: preload("res://art/ui/slots/empty_head.png"),
	GearDefinition.Slot.NECK: preload("res://art/ui/slots/empty_neck.png"),
	GearDefinition.Slot.SHOULDER: preload("res://art/ui/slots/empty_shoulder.png"),
	GearDefinition.Slot.BACK: preload("res://art/ui/slots/empty_back.png"),
	GearDefinition.Slot.CHEST: preload("res://art/ui/slots/empty_chest.png"),
	GearDefinition.Slot.WRIST: preload("res://art/ui/slots/empty_wrist.png"),
	GearDefinition.Slot.HANDS: preload("res://art/ui/slots/empty_hands.png"),
	GearDefinition.Slot.WAIST: preload("res://art/ui/slots/empty_waist.png"),
	GearDefinition.Slot.LEGS: preload("res://art/ui/slots/empty_legs.png"),
	GearDefinition.Slot.FEET: preload("res://art/ui/slots/empty_feet.png"),
	GearDefinition.Slot.RING: preload("res://art/ui/slots/empty_ring.png"),
	GearDefinition.Slot.TRINKET: preload("res://art/ui/slots/empty_trinket.png"),
	GearDefinition.Slot.MAIN_HAND: preload("res://art/ui/slots/empty_main_hand.png"),
	GearDefinition.Slot.OFF_HAND: preload("res://art/ui/slots/empty_off_hand.png"),
}
const EMPTY_SKILL := preload("res://art/ui/slots/empty_skill.png")
const SKILL_SLOTS := 6

# Position -> DropTarget panel.
var _equip_slots := {}
# The 6 skill slot panels.
var _skill_slots := []
```

- [ ] **Step 2: Rebuild `_build_left_panel` for Layout A**

Replace `_build_left_panel` with the flanking-columns layout. The panel is the auto-equip `DROP` target (as today); decorative children stay `MOUSE_FILTER_IGNORE`:
```gdscript
func _build_left_panel():
	var panel = DROP.new()
	panel.screen = self
	panel.target_kind = "auto"
	panel.add_theme_stylebox_override("panel", _panel_style())
	_place(panel, 40, 50, 640, -40, 0, 0, 0, 1)

	var vbox = VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 10)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(vbox)

	vbox.add_child(_title("Hero"))

	_name_edit = LineEdit.new()
	_name_edit.add_theme_font_override("font", FONT)
	_name_edit.add_theme_font_size_override("font_size", 24)
	_name_edit.add_theme_color_override("font_color", PARCHMENT)
	_name_edit.add_theme_stylebox_override("normal", _slot_style())
	_name_edit.add_theme_stylebox_override("focus", _panel_style())
	_name_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_edit.custom_minimum_size = Vector2(0, 40)
	_name_edit.text_submitted.connect(_on_name_submitted)
	_name_edit.focus_exited.connect(func(): _on_name_submitted(_name_edit.text))
	vbox.add_child(_name_edit)

	# Columns flanking the preview.
	var mid = HBoxContainer.new()
	mid.add_theme_constant_override("separation", 10)
	mid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(mid)

	mid.add_child(_build_slot_column(Equip.COLUMN_LEFT))

	_preview_holder = Control.new()
	_preview_holder.custom_minimum_size = Vector2(190, 300)
	_preview_holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_preview_holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_preview_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mid.add_child(_preview_holder)

	mid.add_child(_build_slot_column(Equip.COLUMN_RIGHT))

	_role_label = Label.new()
	_role_label.add_theme_font_override("font", FONT)
	_role_label.add_theme_font_size_override("font_size", 20)
	_role_label.add_theme_color_override("font_color", PARCHMENT)
	_role_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_role_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(_role_label)

	# Weapon row.
	var weapons = HBoxContainer.new()
	weapons.alignment = BoxContainer.ALIGNMENT_CENTER
	weapons.add_theme_constant_override("separation", 14)
	weapons.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(weapons)
	for pos in Equip.WEAPON_ROW:
		weapons.add_child(_build_equip_slot(pos))

	# Skill row (6 slots; only slot 0 is active for now).
	vbox.add_child(_title("Skills"))
	var skills = HBoxContainer.new()
	skills.alignment = BoxContainer.ALIGNMENT_CENTER
	skills.add_theme_constant_override("separation", 8)
	skills.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(skills)
	_skill_slots.clear()
	for i in range(SKILL_SLOTS):
		var slot = _make_slot("skill_view")  # read-only: rejects drops
		slot.custom_minimum_size = Vector2(64, 64)
		_skill_slots.append(slot)
		skills.add_child(slot)

func _build_slot_column(positions: Array) -> VBoxContainer:
	var col = VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for pos in positions:
		col.add_child(_build_equip_slot(pos))
	return col

func _build_equip_slot(position: int) -> Control:
	var slot = _make_slot("equip:%d" % position)
	slot.custom_minimum_size = Vector2(64, 64)
	_equip_slots[position] = slot
	return slot
```

Update `_make_slot` to keep returning a `DROP`; no signature change needed.

- [ ] **Step 3: Rebuild the right side as tabs (Gear + Skills)**

Replace `_build_skills_panel` and `_build_gear_panel` with a single `_build_right_tabs`:
```gdscript
func _build_right_tabs():
	var tabs = TabContainer.new()
	tabs.add_theme_font_override("font", FONT)
	_place(tabs, -480, 50, -40, -40, 1, 0, 1, 1)

	# Gear tab: the stash grid in a scroll.
	var gear_tab = ScrollContainer.new()
	gear_tab.name = "Gear"
	gear_tab.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tabs.add_child(gear_tab)
	var bin = DROP.new()
	bin.screen = self
	bin.target_kind = "gear_stash"
	bin.add_theme_stylebox_override("panel", _slot_style())
	bin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	gear_tab.add_child(bin)
	_gear_grid = GridContainer.new()
	_gear_grid.columns = 4
	_gear_grid.add_theme_constant_override("h_separation", 10)
	_gear_grid.add_theme_constant_override("v_separation", 10)
	_gear_grid.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_gear_grid.offset_left = 10
	_gear_grid.offset_top = 10
	bin.add_child(_gear_grid)

	# Skills tab: the known catalog (sparse for now).
	var skills_tab = ScrollContainer.new()
	skills_tab.name = "Skills"
	tabs.add_child(skills_tab)
	var skill_box = VBoxContainer.new()
	skill_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	skills_tab.add_child(skill_box)
	var note = Label.new()
	note.text = "Active skills coming soon. Your attack follows your weapon."
	note.add_theme_color_override("font_color", DIM)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	skill_box.add_child(note)
	var grid = GridContainer.new()
	grid.columns = 4
	skill_box.add_child(grid)
	for skill in PlayerRoster.skill_catalog:
		grid.add_child(_make_icon("skill", skill, "catalog"))
```

Update `_build` to call `_build_left_panel()`, `_build_right_tabs()`, `_build_tooltip()`, `_build_close_button()` (drop the old two calls).

- [ ] **Step 4: Rewrite `refresh` + slot fillers for positions and empty icons**

```gdscript
func refresh():
	if hero_index < 0:
		return
	var hero = PlayerRoster.heroes[hero_index]
	_name_edit.text = hero.hero_name
	_role_label.text = _role_text()
	for pos in _equip_slots.keys():
		_fill_equip_slot(pos)
	_fill_skill_slots()
	_fill_gear_grid()
	_update_preview()

func _fill_equip_slot(position: int):
	var slot = _equip_slots[position]
	_clear(slot)
	var item = PlayerRoster.equipped_item(hero_index, position)
	if item:
		_inset_icon(slot, _make_icon("gear", item, "equipped:%d" % position))
		return
	# Two-handed ghost in the off hand.
	if position == Equip.Position.OFF_HAND and _offhand_blocked():
		var main = PlayerRoster.equipped_item(hero_index, Equip.Position.MAIN_HAND)
		var ghost = _make_icon("twohand", main, "twohand")
		ghost.draggable = false
		ghost.modulate.a = 0.32
		_inset_icon(slot, ghost)
		return
	# Empty-slot silhouette.
	var hint = TextureRect.new()
	hint.texture = EMPTY_ICONS[Equip.category_of(position)]
	hint.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	hint.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	hint.modulate.a = 0.35
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_inset_icon(slot, hint)

func _fill_skill_slots():
	var skill = PlayerRoster.attack_skill(hero_index)
	for i in range(_skill_slots.size()):
		var slot = _skill_slots[i]
		_clear(slot)
		if i == 0 and skill:
			var icon = _make_icon("skill", skill, "skill_view")
			icon.draggable = false
			_inset_icon(slot, icon)
		else:
			var hint = TextureRect.new()
			hint.texture = EMPTY_SKILL
			hint.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			hint.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			hint.modulate.a = 0.3
			hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_inset_icon(slot, hint)

func _offhand_blocked() -> bool:
	var main = PlayerRoster.equipped_item(hero_index, Equip.Position.MAIN_HAND)
	return main != null and main.weapon_type in [
		GearDefinition.WeaponType.TWO_HANDED, GearDefinition.WeaponType.BOW,
	]
```

Keep `_inset_icon`, `_fill_gear_grid`, `_clear`, `_role_text`, `_update_preview` as they are (preview still calls `actor.equip_gear(hero.equipped.values())` — update that one call to pass `hero.equipped.values()` instead of `hero.starting_gear`).

- [ ] **Step 5: Update the tooltip (weapon speed + both hands)**

Replace `_tooltip_gear` so weapons show speed and DPS, and the weapon block shows both hands:
```gdscript
func _tooltip_gear(gear: GearDefinition):
	_tip_line(gear.gear_name, GOLD, 26)
	_tip_line(_gear_subtitle(gear), DIM, 17)
	if gear.attack_bonus != 0:
		_tip_line("+%d Attack" % gear.attack_bonus)
	if gear.health_bonus != 0:
		_tip_line("+%d Health" % gear.health_bonus)
	if gear.attack_speed > 0.0:
		_tip_line("Speed: %.1fs" % gear.attack_speed, PARCHMENT, 18)
		_tip_line("(~%.1f dmg/s from the weapon)" %
			(float(gear.attack_bonus) / gear.attack_speed), DIM, 15)
	_divider()
	# For weapons, show what's in BOTH hands right now.
	if gear.slot == GearDefinition.Slot.MAIN_HAND \
			or gear.weapon_type == GearDefinition.WeaponType.ONE_HANDED:
		var main = PlayerRoster.equipped_item(hero_index, Equip.Position.MAIN_HAND)
		var off = PlayerRoster.equipped_item(hero_index, Equip.Position.OFF_HAND)
		_tip_line("Main hand: %s" % (main.gear_name if main else "empty"), PARCHMENT, 18)
		if not _offhand_blocked():
			_tip_line("Off hand: %s%s" % [
				off.gear_name if off else "empty",
				"  (50% dmg)" if off and off.attack_speed > 0.0 else "",
			], PARCHMENT, 18)
		else:
			_tip_line("Off hand: occupied (two-handed)", DIM, 16)
	else:
		var equipped = _first_equipped_of_category(gear.slot)
		if equipped:
			_tip_line("Equipped (%s):" % _category_label(gear.slot), DIM, 16)
			_tip_line("%s   %s" % [equipped.gear_name, _stat_summary(equipped)], PARCHMENT, 18)
		else:
			_tip_line("%s: empty" % _category_label(gear.slot), DIM, 16)

func _first_equipped_of_category(category: int) -> GearDefinition:
	for pos in Equip.positions_for(category):
		var item = PlayerRoster.equipped_item(hero_index, pos)
		if item:
			return item
	return null

func _category_label(category: int) -> String:
	for pos in Equip.positions_for(category):
		return Equip.label(pos)
	return "?"
```

Update `_gear_subtitle` to use `_category_label(gear.slot)` instead of the old `SLOT_LABELS`. Keep `_tooltip_twohand`, `_tooltip_skill`, `_stat_summary` as they are.

- [ ] **Step 6: Headless build check**

`capture/test_loadout_ui.gd` — instantiates the camp + loadout, opens hero 0, refreshes, asserts the slots dictionary is fully built. **No screenshot** (headless-safe):
```gdscript
extends Node

func _ok(label, cond):
	print(("PASS " if cond else "FAIL ") + label)

func _ready():
	var camp = load("res://scenes/camp/camp.tscn").instantiate()
	add_child(camp)
	await get_tree().process_frame
	await get_tree().process_frame
	var loadout = camp.loadout
	loadout.open(0)
	await get_tree().process_frame
	_ok("16 equip slots built", loadout._equip_slots.size() == 16)
	_ok("6 skill slots built", loadout._skill_slots.size() == 6)
	_ok("main hand slot exists",
		loadout._equip_slots.has(Equip.Position.MAIN_HAND))
	_ok("hero name shown", loadout._name_edit.text != "")
	get_tree().quit()
```
`capture/test_loadout_ui.tscn`:
```
[gd_scene load_steps=2 format=3 uid="uid://b5loadui0test01"]
[ext_resource type="Script" path="res://capture/test_loadout_ui.gd" id="1_t"]
[node name="TestLoadUI" type="Node"]
script = ExtResource("1_t")
```
Run:
```bash
GODOT=/Applications/Godot.app/Contents/MacOS/Godot
( $GODOT --headless --path . capture/test_loadout_ui.tscn 2>&1; echo EXIT=$? ) | rg -i "PASS|FAIL|error|EXIT" & sleep 16; pkill -f test_loadout_ui.tscn 2>/dev/null; wait
```
Expected: all `PASS`.

- [ ] **Step 7: Commit**

```bash
git add scripts/camp/loadout/loadout_screen.gd capture/test_loadout_ui.gd capture/test_loadout_ui.tscn
git commit -m "Rebuild loadout screen to WoW-style Layout A with tabbed gear/skills"
```

---

## Task 9: Wire drag / click-carry / auto-drop to positions

Update the drag data and drop policy so they speak in positions, route ring/trinket to a free position, and keep the read-only skill slots inert.

**Files:**
- Modify: `scripts/camp/loadout/loadout_screen.gd` (`can_accept`, `accept_drop`, carry routing)
- Modify: `scripts/camp/loadout/loadout_icon.gd` (origin string already carries position from Task 8's `"equipped:%d"`)
- Test: `capture/test_loadout.gd` extended + manual headless drop test `capture/test_drop_routing.gd`

- [ ] **Step 1: Update `can_accept` / `accept_drop` to positions**

Replace the body of `can_accept` and `accept_drop`:
```gdscript
func can_accept(target_kind, data) -> bool:
	if target_kind == "skill_view":
		return false  # skill slots are read-only for now
	if target_kind == "gear_stash":
		return data.kind == "gear" and String(data.origin).begins_with("equipped")
	if target_kind == "auto":
		if data.kind != "gear" or data.origin != "stash":
			return false
		return PlayerRoster.default_position(hero_index, data.res) != -1
	if target_kind.begins_with("equip:"):
		if data.kind != "gear" or data.origin != "stash":
			return false
		var pos = int(target_kind.split(":")[1])
		return PlayerRoster.acceptable_positions(hero_index, data.res).has(pos)
	return false

func accept_drop(target_kind, data):
	if target_kind == "gear_stash":
		# origin is "equipped:<pos>"
		var pos = int(String(data.origin).split(":")[1])
		PlayerRoster.unequip_gear(hero_index, pos)
	elif target_kind == "auto":
		PlayerRoster.equip_gear(hero_index, data.res)  # default position
	elif target_kind.begins_with("equip:"):
		var pos = int(target_kind.split(":")[1])
		PlayerRoster.equip_gear(hero_index, data.res, pos)
	hide_tooltip()
	refresh()
	hero_changed.emit(hero_index)
```

- [ ] **Step 2: Update carry placement routing**

In `_ancestor_target_kind` nothing changes (it returns the slot's `target_kind`). In `place_on`, `can_accept`/`accept_drop` already handle positions. The equipped-icon origin is now `"equipped:<pos>"`; confirm `loadout_icon.gd` passes `origin` through unchanged (it does). No code change beyond Step 1 unless a test fails.

- [ ] **Step 3: Drop-routing test**

`capture/test_drop_routing.gd`:
```gdscript
extends Node

func _ok(label, cond):
	print(("PASS " if cond else "FAIL ") + label)

func _ready():
	var camp = load("res://scenes/camp/camp.tscn").instantiate()
	add_child(camp)
	await get_tree().process_frame
	await get_tree().process_frame
	var loadout = camp.loadout
	loadout.open(0)
	await get_tree().process_frame

	# Auto-drop a stash bow -> equips into main hand, flips to ranged.
	var bow = null
	for g in PlayerRoster.gear_stash:
		if g.weapon_type == GearDefinition.WeaponType.BOW:
			bow = g
			break
	var bdata = {"kind": "gear", "res": bow, "origin": "stash"}
	_ok("auto accepts bow", loadout.can_accept("auto", bdata))
	loadout.accept_drop("auto", bdata)
	await get_tree().process_frame
	_ok("bow equipped -> ranged", PlayerRoster.is_ranged(0))

	# Skill slots reject drops.
	var any_skill = PlayerRoster.skill_catalog[0]
	_ok("skill slot read-only",
		not loadout.can_accept("skill_view",
			{"kind": "skill", "res": any_skill, "origin": "catalog"}))

	get_tree().quit()
```
`capture/test_drop_routing.tscn`:
```
[gd_scene load_steps=2 format=3 uid="uid://b6drop0route0001"]
[ext_resource type="Script" path="res://capture/test_drop_routing.gd" id="1_t"]
[node name="TestDrop" type="Node"]
script = ExtResource("1_t")
```
Run:
```bash
GODOT=/Applications/Godot.app/Contents/MacOS/Godot
( $GODOT --headless --path . capture/test_drop_routing.tscn 2>&1; echo EXIT=$? ) | rg -i "PASS|FAIL|error|EXIT" & sleep 16; pkill -f test_drop_routing.tscn 2>/dev/null; wait
```
Expected: all `PASS`.

- [ ] **Step 4: Delete the now-obsolete `auto_drop_test`**

The old `capture/auto_drop_test.*` exercised the 4-slot API and will fail to compile against the new model. Remove it (its coverage is replaced by `test_loadout` + `test_drop_routing`):
```bash
rm -f capture/auto_drop_test.gd capture/auto_drop_test.gd.uid capture/auto_drop_test.tscn
```

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "Route loadout drag/carry/auto-drop through equip positions"
```

---

## Task 10: README, screenshots, full verification

**Files:**
- Modify: `README.md`
- Modify: `capture/loadout_shot.gd` (use positions; capture new Layout A)
- Verify: run every headless test once.

- [ ] **Step 1: Update `capture/loadout_shot.gd` to the new API**

Replace `_equip_slots[GearDefinition.Slot.MAIN_HAND]` usages with `_equip_slots[Equip.Position.MAIN_HAND]`, and any `show_tooltip("gear", PlayerRoster.BOW)` stays valid. Keep it windowed (it screenshots). Capture `loadout_open` (Layout A) and `loadout_dualwield` (equip a 1H sword into the off hand and snap).

- [ ] **Step 2: Generate screenshots (windowed)**

```bash
GODOT=/Applications/Godot.app/Contents/MacOS/Godot
( $GODOT --path . capture/loadout_shot.tscn 2>&1; echo EXIT=$? ) | rg -i "EXIT|error" & sleep 25; pkill -f loadout_shot.tscn 2>/dev/null; wait
ls -la docs/screenshots/loadout_*.png
```
Inspect the new `loadout_open.png` shows the flanking columns + skill row.

- [ ] **Step 3: Update the README**

- Refresh the loadout screenshot row to the Layout A shot.
- Update the **Features** "Hero loadout" bullet to mention the full slot set, weapon speed, and dual-wielding.
- Update **Game Design → Loadout and roles** to describe weapon speed (DPS-normalized, future armor/proc trade-offs) and dual-wield at 50% off-hand damage.
- Update **Current Content** table: remove Ranger Delver row; add Fast Dagger / Heavy Axe with speeds; add `attack_speed` to weapon rows.
- Update **Project Structure** if `art/ui/slots/` is new.

- [ ] **Step 4: Run the full headless test sweep**

```bash
GODOT=/Applications/Godot.app/Contents/MacOS/Godot
for t in test_equip test_loadout test_combat_speed test_dualwield test_loadout_ui test_drop_routing; do
  echo "=== $t ==="
  ( $GODOT --headless --path . capture/$t.tscn 2>&1; echo EXIT=$? ) | rg -i "PASS|FAIL|error|EXIT" & sleep 16; pkill -f $t.tscn 2>/dev/null; wait
done
```
Expected: every test all-`PASS`, no `FAIL`.

- [ ] **Step 5: Commit**

```bash
git add README.md capture/loadout_shot.gd docs/screenshots
git commit -m "Update README and screenshots for WoW-style loadout and weapon speed"
```

---

## Self-Review notes (already applied)

- **Spec coverage:** slot set (T1/T8), category-vs-position (T1), position-keyed loadout (T3), weapon speed → interval (T4), DPS-normalized tuning (T7), dual-wield 50% (T5), unified hero (T3/T6), tabbed gear/skills (T8), read-only skill slot + empties (T8), empty-slot art (T7), tooltip both-hands + speed (T8), drop routing incl. ring/trinket (T9), tests + screenshots (all + T10).
- **Type consistency:** `Equip.Position`, `GearDefinition.Slot`, `equipped` dict, `equip_gear(hero, gear, position)`, `_equip_slots`/`_skill_slots`, `target_kind` values (`equip:<pos>`, `auto`, `gear_stash`, `skill_view`) and `origin` (`stash`, `equipped:<pos>`, `catalog`) are used consistently across tasks.
- **Verified dependency:** `CombatLog.events` is the correct array name for Task 5's test.
```
