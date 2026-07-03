# Spatial Combat — Implementation Plan (Phase 1 MVP)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace formation-slot combat with tile-based spatial movement, range/LoS-gated attacks, threat targeting, and real-time theater replay from an extended event log — MVP on an open arena with 2–6 enemies and Frost Nova / Hamstring / Charge / Heal skills.

**Architecture:** A headless **`BattleArena`** tile map drives **`GridPathfinder`** (A*) and **`LineOfSight`**. **`CombatEntity`** gains position, path, statuses, and threat tables; **`CombatState.update`** ticks movement + separation then actions. Meaningful changes append to **`CombatLog`** (`MOVE`, `TARGET`, `CAST_*`, `TELEGRAPH`, etc.). **`TheaterController`** lerps actors between logged positions, drops melee jump-to-target, and draws target arrows + AoE telegraphs. See `docs/superpowers/specs/2026-07-03-spatial-combat-design.md`.

**Tech Stack:** Godot 4.6, GDScript. Headless tests via `capture/test_*.tscn` (`PASS`/`FAIL`, no screenshots).

---

## Conventions

- **Godot:** `GODOT=/Applications/Godot.app/Contents/MacOS/Godot`
- **Run test:** `$GODOT --headless --path . capture/<name>.tscn 2>&1 | rg "PASS|FAIL|SCRIPT ERROR"`
- **Sim step:** `0.1` s (keep `CombatSimulator.SIMULATION_STEP` in sync)
- **Coordinates:** world pixels; `tile_size = 32`; tile `(tx, ty)` → pixel `(tx * 32 + 16, ty * 32 + 16)`

---

## File map (Phase 1)

| File | Responsibility |
|------|----------------|
| `scripts/combat/battle_arena.gd` | Arena dimensions, blocked tiles, spawn rects |
| `scripts/combat/battle_grid.gd` | Walkability, world↔tile, LoS ray |
| `scripts/combat/grid_pathfinder.gd` | A* on grid |
| `scripts/combat/separation.gd` | Soft collision offsets |
| `scripts/combat/threat.gd` | Threat add/sort/pick target |
| `scripts/combat/combat_entity.gd` | Spatial state, statuses, action loop |
| `scripts/combat/combat_state.gd` | Arena, path requests, aggro scope |
| `scripts/combat/combat_event.gd` | New event fields/types |
| `scripts/data/gear_definition.gd` | `reach: float` for weapons |
| `scripts/data/skill_definition.gd` | `requires_stationary`, `aoe_radius`, etc. |
| `scripts/theater/theater_controller.gd` | Real-time replay, no melee jump |
| `scripts/theater/move_replay.gd` | Lerp between MOVE events |
| `scripts/theater/target_arrow.gd` | Foot arrow overlay |
| `resources/arenas/open_arena.tres` | MVP open battlefield |
| `scenes/theater/battle_theater.tscn` | Arena ref, camera, drop formation markers |

---

### Task 1: BattleArena resource

**Files:**
- Create: `scripts/combat/battle_arena.gd`
- Create: `resources/arenas/open_arena.tres`
- Test: `capture/test_arena.gd`, `capture/test_arena.tscn`

- [ ] **Step 1: Write the failing test**

```gdscript
extends Node

func _ready():
	var arena = load("res://resources/arenas/open_arena.tres")
	assert(arena.width == 30 and arena.height == 20, "arena size")
	assert(arena.blocked_tiles.is_empty(), "MVP open")
	print("PASS arena loads")
	get_tree().quit()
```

- [ ] **Step 2: Run test — expect FAIL** (missing resource)

Run: `$GODOT --headless --path . capture/test_arena.tscn 2>&1 | rg "PASS|FAIL|ERROR"`

- [ ] **Step 3: Implement `BattleArena`**

```gdscript
extends Resource
class_name BattleArena

@export var arena_id: String = "open"
@export var width: int = 30
@export var height: int = 20
@export var tile_size: int = 32
@export var blocked_tiles: Array[Vector2i] = []
@export var hero_spawn_center: Vector2i = Vector2i(4, 10)
@export var enemy_spawn_center: Vector2i = Vector2i(25, 10)
```

Create `open_arena.tres` in editor or with minimal `.tres` text referencing the script.

- [ ] **Step 4: Run test — expect PASS**

- [ ] **Step 5: Commit**

```bash
git add scripts/combat/battle_arena.gd resources/arenas/open_arena.tres capture/test_arena.gd capture/test_arena.tscn
git commit -m "Add BattleArena resource for tile-based combat"
```

---

### Task 2: BattleGrid walkability and line of sight

**Files:**
- Create: `scripts/combat/battle_grid.gd`
- Test: `capture/test_grid_los.gd`, `capture/test_grid_los.tscn`

- [ ] **Step 1: Write failing tests**

```gdscript
extends Node

func _ready():
	var arena = load("res://resources/arenas/open_arena.tres")
	var grid = BattleGrid.new(arena)
	assert(grid.is_walkable(Vector2i(5, 5)), "open cell")
	arena.blocked_tiles = [Vector2i(5, 5)]
	grid = BattleGrid.new(arena)
	assert(not grid.is_walkable(Vector2i(5, 5)), "blocked")

	var arena2 = load("res://resources/arenas/open_arena.tres")
	arena2.blocked_tiles = [Vector2i(10, 5), Vector2i(10, 6)]
	grid = BattleGrid.new(arena2)
	assert(not grid.has_los(Vector2(9 * 32, 5 * 32), Vector2(11 * 32, 5 * 32)), "pillar blocks")
	assert(grid.has_los(Vector2(9 * 32, 4 * 32), Vector2(11 * 32, 4 * 32)), "clear row")
	print("PASS grid los")
	get_tree().quit()
```

- [ ] **Step 2: Run — expect FAIL**

- [ ] **Step 3: Implement `BattleGrid`**

```gdscript
class_name BattleGrid

var _arena: BattleArena
var _blocked: Dictionary = {}

func _init(arena: BattleArena):
	_arena = arena
	for t in arena.blocked_tiles:
		_blocked[t] = true

func is_walkable(cell: Vector2i) -> bool:
	if cell.x < 0 or cell.y < 0 or cell.x >= _arena.width or cell.y >= _arena.height:
		return false
	return not _blocked.has(cell)

func world_to_tile(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x / _arena.tile_size), floori(p.y / _arena.tile_size))

func tile_to_world(cell: Vector2i) -> Vector2:
	var ts = _arena.tile_size
	return Vector2(cell.x * ts + ts * 0.5, cell.y * ts + ts * 0.5)

func has_los(from: Vector2, to: Vector2) -> bool:
	var a = world_to_tile(from)
	var b = world_to_tile(to)
	for cell in _bresenham(a, b):
		if _blocked.has(cell):
			return false
	return true

func _bresenham(a: Vector2i, b: Vector2i) -> Array[Vector2i]:
	# Standard Bresenham; include both endpoints.
	var points: Array[Vector2i] = []
	var dx = absi(b.x - a.x)
	var dy = -absi(b.y - a.y)
	var sx = 1 if a.x < b.x else -1
	var sy = 1 if a.y < b.y else -1
	var err = dx + dy
	var x = a.x
	var y = a.y
	while true:
		points.append(Vector2i(x, y))
		if x == b.x and y == b.y:
			break
		var e2 = 2 * err
		if e2 >= dy:
			err += dy
			x += sx
		if e2 <= dx:
			err += dx
			y += sy
	return points
```

- [ ] **Step 4: Run — expect PASS**

- [ ] **Step 5: Commit**

---

### Task 3: GridPathfinder (A*)

**Files:**
- Create: `scripts/combat/grid_pathfinder.gd`
- Test: `capture/test_pathfinder.gd`, `capture/test_pathfinder.tscn`

- [ ] **Step 1: Test path around pillar**

```gdscript
extends Node

func _ready():
	var arena = load("res://resources/arenas/open_arena.tres")
	arena.blocked_tiles = [Vector2i(10, 10), Vector2i(10, 11), Vector2i(10, 12)]
	var grid = BattleGrid.new(arena)
	var pf = GridPathfinder.new(grid)
	var path = pf.find_path(Vector2i(8, 11), Vector2i(12, 11))
	assert(not path.is_empty(), "path exists")
	for cell in path:
		assert(cell != Vector2i(10, 11), "avoids pillar")
	print("PASS pathfinder")
	get_tree().quit()
```

- [ ] **Step 2: Run — expect FAIL**

- [ ] **Step 3: Implement A* with 4-neighbor grid**

Use Manhattan heuristic, max nodes `width * height`. Return `PackedVector2Array` of **world** waypoints via `grid.tile_to_world`.

- [ ] **Step 4: Run — expect PASS**

- [ ] **Step 5: Commit**

---

### Task 4: Extend CombatEvent for spatial replay

**Files:**
- Modify: `scripts/combat/combat_event.gd`
- Test: `capture/test_combat_events.gd`, `capture/test_combat_events.tscn`

- [ ] **Step 1: Add fields and factory helpers**

Extend enum with `MOVE`, `FACE`, `TARGET`, `TELEGRAPH` (some exist unused — wire them up).

New fields on `CombatEvent`:

```gdscript
var position: Vector2 = Vector2.ZERO
var facing: Vector2 = Vector2.RIGHT
var velocity: Vector2 = Vector2.ZERO  # optional for theater
var telegraph_radius: float = 0.0
var telegraph_duration: float = 0.0
var status_id: String = ""
```

Add static factories: `create_move(entity, time, pos)`, `create_target(source_id, target_id, time)`, `create_telegraph(...)`.

- [ ] **Step 2: Test factories set type and fields**

- [ ] **Step 3: Commit**

---

### Task 5: CombatEntity spatial state and statuses

**Files:**
- Modify: `scripts/combat/combat_entity.gd`
- Create: `scripts/combat/status_effect.gd`
- Test: `capture/test_status.gd`, `capture/test_status.tscn`

- [ ] **Step 1: Add `StatusEffect`**

```gdscript
class_name StatusEffect
enum Kind { ROOT, SLOW, STUN }
var kind: Kind
var remaining: float
var magnitude: float = 1.0  # slow = 0.5 means half speed
```

- [ ] **Step 2: Extend `CombatEntity`**

```gdscript
var position: Vector2 = Vector2.ZERO
var facing: Vector2 = Vector2.RIGHT
var move_speed: float = 120.0  # px/s
var path: PackedVector2Array = []
var path_index: int = 0
var target_id: int = -1
var threat_table: Dictionary = {}
var in_combat: bool = false
var statuses: Array[StatusEffect] = []
var is_casting: bool = false
var cast_remaining: float = 0.0
var weapon_reach: float = 48.0

func is_rooted() -> bool:
	for s in statuses:
		if s.kind == StatusEffect.Kind.ROOT or s.kind == StatusEffect.Kind.STUN:
			if s.remaining > 0.0:
				return true
	return false

func move_speed_multiplier() -> float:
	var m = 1.0
	for s in statuses:
		if s.kind == StatusEffect.Kind.SLOW:
			m = minf(m, s.magnitude)
	return m
```

- [ ] **Step 3: Test root blocks movement flag**

- [ ] **Step 4: Commit**

---

### Task 6: Separation (soft collision)

**Files:**
- Create: `scripts/combat/separation.gd`
- Test: `capture/test_separation.gd`, `capture/test_separation.tscn`

- [ ] **Step 1: Test two units at same point push apart**

```gdscript
extends Node

func _ready():
	var a = Vector2(100, 100)
	var b = Vector2(100, 100)
	var offset = Separation.compute_offset(a, [b], 24.0, 1.0)
	assert(offset.length() > 0.1, "pushes apart")
	print("PASS separation")
	get_tree().quit()
```

- [ ] **Step 2: Implement inverse-distance repulsion capped per frame**

```gdscript
class_name Separation
const MAX_PUSH := 8.0

static func compute_offset(pos: Vector2, others: Array, radius: float, strength: float) -> Vector2:
	var push = Vector2.ZERO
	for o in others:
		var d = pos - o
		var dist = d.length()
		if dist < radius and dist > 0.01:
			push += d.normalized() * (radius - dist) * strength
	if push.length() > MAX_PUSH:
		push = push.normalized() * MAX_PUSH
	return push
```

- [ ] **Step 3: Run — PASS**

- [ ] **Step 4: Commit**

---

### Task 7: Threat helpers

**Files:**
- Create: `scripts/combat/threat.gd`
- Test: `capture/test_threat.gd`, `capture/test_threat.tscn`

- [ ] **Step 1: Tests for damage, heal split, pick target**

```gdscript
extends Node

func _ready():
	var table = {}
	Threat.add_damage(table, 1, 10.0)
	assert(table[1] == 10.0, "damage threat")
	table = {}
	# Heal 10 split across 5 enemies in combat → 2 threat each on healer (hero 5)
	Threat.add_heal_split(table, 5, 10.0, 5)
	assert(is_equal_approx(table[5], 2.0), "heal split by enemy count")
	var enemy = CombatEntity.new()
	enemy.threat_table = {1: 50.0, 2: 30.0}
	var heroes = {1: Vector2(0, 0), 2: Vector2(500, 0)}
	var pick = Threat.pick_target(enemy, heroes, 80.0, func(_id, _pos): return false)
	assert(pick == 2, "rooted fallback to in-range")
	print("PASS threat")
	get_tree().quit()
```

Implement `Threat.add_damage`, `add_heal_split(healer_id, amount, enemy_count_in_combat)`, `add_aoe`, `pick_target(enemy, hero_positions, attack_range, can_attack_fn)`.

`pick_target`: sort by threat; return first where `can_attack_fn(hero_id, hero_pos)`; else nearest.

- [ ] **Step 2: Run — PASS**

- [ ] **Step 3: Commit**

---

### Task 8: CombatState — arena, spawns, movement tick

**Files:**
- Modify: `scripts/combat/combat_state.gd`
- Modify: `scripts/combat/combat_simulator.gd`
- Test: `capture/test_spatial_move.gd`, `capture/test_spatial_move.tscn`

- [ ] **Step 1: Add arena to CombatState**

```gdscript
var arena: BattleArena
var grid: BattleGrid
var pathfinder: GridPathfinder
var _move_log_cooldown: Dictionary = {}  # entity_id -> time

func setup_combat(hero_templates, enemy_templates, battle_arena: BattleArena = null):
	arena = battle_arena if battle_arena else load("res://resources/arenas/open_arena.tres")
	grid = BattleGrid.new(arena)
	pathfinder = GridPathfinder.new(grid)
	# ... existing spawn logic ...
```

- [ ] **Step 2: Replace formation slots with spawn offsets**

```gdscript
func _spawn_position(center: Vector2i, index: int, preferred_row: int) -> Vector2:
	var row_off = -1 if preferred_row == Formation.Row.FRONT else 1
	var col = index % 3
	var row = index / 3
	var cell = center + Vector2i(col - 1, row_off + row - 1)
	return grid.tile_to_world(cell)
```

- [ ] **Step 3: Add `_tick_movement(entity, delta)`**

- Advance along `path` up to `move_speed * move_speed_multiplier() * delta`.
- Apply `Separation.compute_offset` from nearby same-team positions.
- Emit `MOVE` event if moved and cooldown elapsed (0.15 s).
- Update `facing` from velocity.

- [ ] **Step 4: Test — melee hero far from slime; after several ticks, distance decreases before any DAMAGE**

- [ ] **Step 5: Commit**

---

### Task 9: Range, LoS, and attack gating

**Files:**
- Modify: `scripts/combat/combat_entity.gd`
- Modify: `scripts/data/gear_definition.gd`
- Modify: `scripts/data/skill_definition.gd`
- Test: `capture/test_range_los.gd`, `capture/test_range_los.tscn`

- [ ] **Step 1: Add `GearDefinition.reach`**

```gdscript
@export var reach: float = 0.0  # 0 = derive from weapon_type defaults
```

- [ ] **Step 2: Add skill flags**

```gdscript
@export var requires_stationary: bool = true
@export var aoe_radius: float = 0.0
@export var telegraph_duration: float = 0.0
```

- [ ] **Step 3: Implement `_can_use_skill_on(state, skill, target) -> bool`**

Distance ≤ `max(skill.range, weapon_reach)` (in pixels; retune existing `range` values from abstract 1.5 to e.g. 400 for bow).

Ranged/projectile: `state.grid.has_los(self.position, target.position)`.

- [ ] **Step 4: Refactor `_strike` — only called when in range; remove implicit targeting without movement**

- [ ] **Step 5: Test — archer does not damage through pillar fixture**

- [ ] **Step 6: Commit**

---

### Task 10: Threat-driven targeting and aggro

**Files:**
- Modify: `scripts/combat/combat_state.gd`
- Modify: `scripts/combat/combat_entity.gd`
- Test: `capture/test_threat_targeting.gd`, `capture/test_threat_targeting.tscn`

- [ ] **Step 1: On DAMAGE, call `Threat.add_damage(enemy.threat_table, source_id, amount * skill.threat_multiplier)`**

- [ ] **Step 2: Mark `in_combat` on all enemies when any enemy takes damage from heroes**

- [ ] **Step 3: Replace `get_target_for` for enemies with `Threat.pick_target`**

Pass `can_attack_fn` that checks range/LoS/root fallback rules from design spec.

- [ ] **Step 4: Emit `TARGET` event when `target_id` changes**

- [ ] **Step 5: Test — two heroes; high-threat hero out of range while rooted enemy hits second hero**

- [ ] **Step 6: Commit**

---

### Task 11: Stationary casting for ranged

**Files:**
- Modify: `scripts/combat/combat_entity.gd`
- Test: `capture/test_stationary_cast.gd`, `capture/test_stationary_cast.tscn`

- [ ] **Step 1: Before ranged `_strike`, if `skill.requires_stationary`:**

Set `is_casting = true`, `cast_remaining = cast_time` (0.5 s default for MVP if `cast_type == INSTANT` use 0.3 wind-up).

Do not move while `is_casting`.

Emit `CAST_START` / `CAST_FINISH`.

- [ ] **Step 2: Test — position unchanged for 0.3s before Arrow Shot DAMAGE**

- [ ] **Step 3: Commit**

---

### Task 12: MVP skills — Frost Nova, Hamstring, Charge, Heal

**Files:**
- Create: `resources/skills/frost_nova.tres`, `hamstring.tres`, `charge.tres`, `heal.tres`
- Create: `scripts/combat/skills/frost_nova.gd`, `hamstring.gd`, `charge.gd`, `heal.gd`
- Modify: hero/enemy templates as needed
- Test: `capture/test_mvp_skills.gd`, `capture/test_mvp_skills.tscn`

- [ ] **Step 1: Frost Nova — AoE around caster, `BUFF_APPLIED` root 3s, `TELEGRAPH` 0.4s**

- [ ] **Step 2: Hamstring — melee skill, applies SLOW 50% for 6s**

- [ ] **Step 3: Charge — displacement toward target, stop on contact, STUN 1.5s, `displacement` flag**

Charge path: ray/step toward target up to max distance; first enemy within radius stops movement.

- [ ] **Step 4: Heal — single ally, requires LoS, stationary cast; emits `HEAL` event; threat = `heal_amount / enemies_in_combat` on each in-combat enemy toward healer**

- [ ] **Step 5: Assign Charge to default delver; assign Heal to second hero for threat testing**

- [ ] **Step 6: Test each skill applies expected effect (including heal threat split)**

- [ ] **Step 7: Commit**

---

### Task 13: Theater — real-time replay clock

**Files:**
- Modify: `scripts/theater/theater_controller.gd`
- Create: `scripts/theater/replay_clock.gd`

- [ ] **Step 1: Replace sequential fixed waits with time-based playback**

```gdscript
var _replay_time: float = 0.0

func play(result: CombatResult):
	for event in result.combat_log.events:
		var wait = maxf(0.0, event.time - _replay_time)
		if wait > 0.0:
			await get_tree().create_timer(wait).timeout
		_replay_time = event.time
		await play_event(event)
```

- [ ] **Step 2: Manual smoke — battle theater plays at real-time pace**

- [ ] **Step 3: Commit**

---

### Task 14: Theater — movement replay, remove melee jump

**Files:**
- Modify: `scripts/theater/theater_controller.gd`
- Modify: `scripts/theater/actors/theater_actor.gd`
- Test: visual (battle_theater); logic: `capture/test_replay_move.gd`

- [ ] **Step 1: Handle `CombatEvent.EventType.MOVE` — tween actor to `event.position` over 0.15s**

- [ ] **Step 2: Handle `FACE` — set facing / flip sprite**

- [ ] **Step 3: Remove `jump_to` from `play_melee_attack`; call `play_attack()` in place**

- [ ] **Step 4: SPAWN uses `event.position` instead of `BattlefieldLayout` slot**

- [ ] **Step 5: Commit**

---

### Task 15: Target arrows overlay

**Files:**
- Create: `scripts/theater/target_arrow.gd`
- Create: `scenes/theater/target_arrow.tscn`
- Modify: `scripts/theater/theater_controller.gd`

- [ ] **Step 1: Scene — small arrow sprite at actor feet, rotatable**

- [ ] **Step 2: On `TARGET` event, update arrow for `source_id` to point at `target_id` actor**

- [ ] **Step 3: Show arrows for all units with valid `target_id`; hide on death**

- [ ] **Step 4: Commit**

---

### Task 16: AoE telegraph

**Files:**
- Create: `scripts/theater/aoe_telegraph.gd`
- Modify: `scripts/theater/theater_controller.gd`

- [ ] **Step 1: On `TELEGRAPH`, spawn fading circle at position/radius**

- [ ] **Step 2: On `BUFF_APPLIED` / DAMAGE AoE, clear telegraph**

- [ ] **Step 3: Commit**

---

### Task 17: Retrofit content

**Files:**
- Modify: `resources/gear/starter_sword.tres`, `starter_bow.tres`, etc.
- Modify: `resources/skills/*.tres`, hero/enemy templates
- Modify: `resources/heroes/default_delver.tres`, `resources/enemies/*.tres`

- [ ] **Step 1: Set weapon `reach` (sword 48, bow 320, dagger 40)**

- [ ] **Step 2: Retune skill `range` to pixels (Slash 48, Arrow Shot 320)**

- [ ] **Step 3: Add `move_speed` to templates (hero 120, slime 80, goblin 100)**

- [ ] **Step 4: Run full headless sim — combat completes, no errors**

Run: `$GODOT --headless --path . scenes/combat/combat_simulation.tscn`

- [ ] **Step 5: Commit**

---

### Task 18: Wire battle theater to open arena

**Files:**
- Modify: `scenes/theater/battle_theater.tscn`
- Modify: `scripts/theater/battlefield_layout.gd` (deprecate or adapt)
- Add: `Camera2D` with limits matching arena pixel size

- [ ] **Step 1: Pass `open_arena.tres` into combat setup from theater bootstrap**

- [ ] **Step 2: Draw debug tile grid optional `@export var show_debug_grid`**

- [ ] **Step 3: Remove dependency on HeroSlots/EnemySlots markers for spawn**

- [ ] **Step 4: Commit**

---

### Task 19: Integration tests and README note

**Files:**
- Create: `capture/test_spatial_combat.gd`, `capture/test_spatial_combat.tscn`
- Modify: `README.md` (Combat Design section)

- [ ] **Step 1: Integration test — 2 heroes vs 3 slimes, sim finishes, min 1 MOVE event, no DAMAGE before MOVE for melee**

- [ ] **Step 2: Update README combat section to describe spatial model**

- [ ] **Step 3: Run all tests**

```bash
for t in test_arena test_grid_los test_pathfinder test_threat test_spatial_move test_range_los test_spatial_combat; do
  echo "=== $t ==="
  $GODOT --headless --path . capture/$t.tscn 2>&1 | rg "PASS|FAIL|ERROR" || true
done
```

- [ ] **Step 4: Commit**

---

## Phase 2 roadmap (separate plan later)

- Obstacle dungeon rooms loaded from tile maps
- Camera pan/zoom for off-screen swarms
- 100-enemy perf pass (MOVE throttling, spatial hash, optional flow fields)
- Multi-group pull, trap releases
- Taunt / threat reset skills
- Full 4-dir walk/attack art set (Zelda-style)

## Phase 3 roadmap

- Player-configurable AI reacting to telegraphs
- Heal threat "in combat" refinement
- Room templates (pure AoE farm, boss + adds)

---

## Spec coverage self-review

| Spec requirement | Task |
|------------------|------|
| Event-log fast sim + real-time theater | 13, 14 |
| Tile grid + open arena MVP | 1, 2, 18 |
| A* pathfinding | 3 |
| Soft separation | 6 |
| Weapon + skill range | 9 |
| LoS ranged/heals | 2, 9 |
| Threat tables + rules | 7, 10 |
| Stationary ranged | 11 |
| Frost Nova / Hamstring / Charge / Heal | 12 |
| No melee lunge | 14 |
| Target arrows | 15 |
| AoE telegraph | 16 |
| 2–6 enemy groups | 17 (content), 19 |
| Retrofit templates | 17 |

## Execution handoff

Plan complete and saved to `docs/superpowers/plans/2026-07-03-spatial-combat.md`.

**Two execution options:**

1. **Subagent-Driven (recommended)** — fresh subagent per task, review between tasks  
2. **Inline Execution** — implement task-by-task in session with checkpoints

Which approach do you want?
