# Spatial Combat — Design

Date: 2026-07-03

## Overview

Replace the current **formation-slot, side-view hop-to-target** combat model with **free movement on a 2D tile battlefield**. Units path toward targets, attack only when in range (weapon/skill range), and respect line of sight for ranged attacks and heals. Combat still **simulates headlessly at high speed** and **replays through the theater in real time** via an extended event log.

Presentation shifts to a **Zelda-style angled top-down** view with **4-directional** character art. Dungeons are **tile-based** with obstacles and LoS blockers; MVP uses an **open arena** built on the same tile/nav infrastructure so larger rooms ship quickly later.

## Goals

- Units have `(x, y)` positions on a battle grid; melee closes distance, ranged stops to shoot.
- Simulation remains deterministic enough to log/replay; theater interpolates movement smoothly.
- Threat-driven enemy targeting with readable target indicators in the theater.
- Ranged skills require **standing still** (baseline); gap-close and CC skills support kiting counter-play.
- Retrofit existing heroes, enemies, and auto-attack skills with minimal content churn.
- Normal encounters: **2–6 enemies**; architecture supports **100+** units in special rooms (Phase 2 content).

## Non-Goals (Phase 1)

- Full dungeon floor generation, multi-room exploration, or trap-triggered swarms.
- Player-authored AI scripts.
- Save/load of battle state mid-fight.
- Full 4-dir bespoke animation sets (Phase 1 may ship with 2 facings + flips until art catches up).
- Threat decay, elaborate proc systems, or full skill catalog beyond MVP set.

---

## Architecture Decision: Simulation vs Theater

**Chosen: D — extended event-log replay**

```
BattleArena + CombatState (fast tick sim) → CombatLog → TheaterController (real-time replay)
```

- Sim step: **0.1 s** (unchanged). Can run thousands of steps per second headlessly.
- Theater consumes events ordered by `event.time`, waiting `delta = event.time - last_time` between events (real-time playback).
- Movement is **continuous inside the sim**; the log records **position updates** and **state transitions** the theater can tween between.

### Why not bidirectional Dijkstra (Google Maps style)?

For arenas of ~40×40 tiles and ≤20 active path requests per tick, **A\* on a tile grid** is sufficient and simpler to keep headless. Precompute a **walkability bitmap** from the arena; reuse paths when target tile unchanged. Phase 2 can add **flow-field caching** for swarm rooms if profiling demands it.

### Soft collision / separation

Units **may overlap paths** but apply **separation steering** so groups surround targets instead of stacking:

- Each entity has a **personal radius** (e.g. 0.4 tiles).
- While moving, add a small repulsion vector from nearby allies/enemies (same team only for pack surround, or both for clarity — tune in implementation).
- Pathfinding grid treats cells as walkable; separation handles visual spacing.

---

## Battlefield & Coordinates

### Tile grid

- **`BattleArena`** resource (new): `width`, `height`, `tile_size_px` (e.g. 32), `blocked_tiles: Array[Vector2i]`, optional `hero_spawn_rect`, `enemy_spawn_rect`.
- Sim positions are **`Vector2` in tile space** (float, sub-tile movement allowed) or **world pixels** derived from tile coords — pick one; plan uses **world pixels** with `tile_size = 32` for Godot alignment.
- **Line of sight**: Bresenham / grid raycast on blocked tiles. No shooting or healing through pillars.

### MVP arena

- Open rectangle, no obstacles, ~30×20 tiles.
- Hero spawn: west side; enemy spawn: east side.
- **Soft formation preference**: spawn melee slightly forward, ranged slightly back (offsets from spawn centroid, not hard slots).

### Phase 2

- Tile layers from dungeon rooms, doors, pillars, chokepoints.
- Camera pan/zoom when battlefield exceeds viewport (theater already has large backdrop; add `Camera2D` bounds).

---

## Entity Model Changes

### `CombatEntity` (extend)

| Field | Purpose |
|-------|---------|
| `position: Vector2` | World position |
| `facing: Vector2` or enum `Dir4` | N/E/S/W for art |
| `move_speed: float` | Tiles per second |
| `target_id: int` | Current attack/chase target |
| `threat_table: Dictionary` | `{hero_entity_id: float}` for enemies |
| `in_combat: bool` | Party aggro scope for heal threat |
| `statuses: Array` | root, slow, stun timers |
| `cast_state` | idle / casting / channeling |
| `weapon_range: float` | From main-hand gear |
| `path: PackedVector2Array` | Current path waypoints |

Retire **`formation_slot`** for combat (keep deprecated on SPAWN event for UI migration if needed, or replace with spawn index).

### Entity update loop (per tick)

1. Tick status effects (stun → skip actions; root → skip movement; slow → speed multiplier).
2. If casting and skill requires stationary → no movement until cast finishes.
3. Pick/validate target (threat rules below).
4. If target out of range or no LoS → request path, move along path up to `move_speed * dt`.
5. Apply separation offset.
6. If in range and GCD/attack timer ready → perform attack skill.
7. Emit events for meaningful changes.

---

## Range & Skills

### Range sources

- **`GearDefinition.reach`** (new, pixels): default melee weapon reach (sword 48, bow 400).
- **`SkillDefinition.range`** (existing, retune to pixels): skill override — e.g. thrown sword > melee slash.
- Attack validity: `distance <= effective_range` AND (melee OR has LoS).

### Casting & movement

| Skill class | Move while casting? |
|-------------|---------------------|
| Standard ranged / spell | **No** |
| Melee auto-attack | **No** (must be in range; no lunge) |
| `quick_shot` tag (future) | Yes |
| Blink / dash | Displacement skill, not a cast |

`SkillDefinition` additions:

- `@export var requires_stationary: bool = true`
- `@export var displacement: bool = false` (charge, blink)
- `@export var aoe_radius: float = 0`
- `@export var telegraph_duration: float = 0` (theater + optional sim wind-up)
- `@export var threat_multiplier: float = 1.0` (passives stack in behavior)

### MVP skills

| Skill | Effect |
|-------|--------|
| Slash (existing) | Melee auto, weapon range |
| Arrow Shot (existing) | Ranged projectile, stationary, LoS |
| Frost Nova | AoE around caster, root X seconds |
| Hamstring | Single target melee, slow Y% |
| Charge | Gap close, stops on first enemy contact, short stun |
| Heal | Single-target heal, LoS to ally, stationary; threat split across enemies in combat |

---

## Threat System

### Per-enemy table

Each enemy maintains `threat_table: { hero_id: float }`.

**Target selection:**

1. Sort heroes by threat descending.
2. Pick highest-threat hero the enemy **can attack** (in range + LoS for ranged, or can path toward).
3. If rooted and highest-threat out of range, fall through to next highest **currently in range**.
4. If table empty → nearest hero (fallback).

No passive decay in Phase 1. **Taunt** sets threat to top; **threat reset** zeros or swaps — Phase 1 stub hooks, full skills Phase 2.

### Threat generation rules

| Action | Threat |
|--------|--------|
| Deal `D` damage to enemy E | `D * skill.threat_multiplier` on **E only** |
| AoE hits enemies `{E1..En}` each for `D` | Each `Ei` gets `D * multiplier` |
| Heal ally for `H` | Each enemy **in combat with the party** gets `H / enemy_party_size_in_combat` on the **healer** |
| AoE debuff (no damage) base `T` | Each affected enemy gets `T * multiplier` on caster |

Example: 10 damage to 5 enemies → 10 threat each. Heal 10 with 5 enemies in combat → 2 threat each on healer. Debuff 10 with 1.5× passive → 15 each.

Hero passives (data-driven later) multiply outgoing threat for specific skill tags.

---

## Event Log Extensions

New / extended `CombatEvent.EventType` values:

| Event | When |
|-------|------|
| `SPAWN` | + `position`, `facing` |
| `MOVE` | Position sync while moving (throttled) |
| `FACE` | Facing changed |
| `TARGET` | `source_id`, `target_id` — for threat arrows |
| `CAST_START` / `CAST_FINISH` | Cast bar / animation |
| `DAMAGE` / `DEATH` | unchanged semantics |
| `BUFF_APPLIED` / `BUFF_EXPIRED` | CC statuses |
| `TELEGRAPH` | AoE wind-up (position, radius, duration) |

**MOVE throttling:** emit at most every **0.15 s** per entity while moving, plus on **start/stop** and **direction change**. Theater lerps between samples.

---

## Theater Changes

### Camera & layout

- Angled view: battlefield centered; **`y_sort_enabled`** on actors (already present).
- Remove **`jump_to` melee close-in**; actors **walk** along replayed positions.
- **`MELEE_STRIKE_DISTANCE`** removed; attacks play **in place** when `DAMAGE` fires.

### Animations

- Walk cycle while moving (4-dir when art ready; interim **2-dir + flip**).
- Ranged: windup → release at `CAST_FINISH`; entity stationary.
- Charge: fast tween along logged displacement path.

### Readability overlays

- **Target arrow** at unit's feet pointing toward current target (heroes and enemies).
- **AoE telegraph**: filled circle fades in before `DAMAGE` / `BUFF_APPLIED`.

---

## Content & Encounters

| Phase | Encounters |
|-------|------------|
| MVP | 2–6 enemies, open arena, 1–2 melee + 1–2 ranged heroes |
| Phase 2 | Larger groups, multi-pull, 100-enemy rooms, traps |
| Phase 3 | Player AI, advanced skill interactions |

Existing `.tres` templates gain: `move_speed`, `weapon reach` / skill ranges retuned, spawn preferences (`preferred_row` → soft spawn offset).

---

## Testing Strategy

Headless tests (no screenshots):

- Grid pathfinding around pillar fixture.
- LoS blocked vs clear.
- Melee must move before first damage event.
- Ranged does not emit damage while position changing during cast.
- Threat: damage adds to one enemy; heal splits across in-combat enemies.
- Root: enemy switches to in-range target if top threat out of range.
- Event log replay: total damage unchanged vs live sim sample.

---

## Phased Delivery

| Phase | Deliverable |
|-------|-------------|
| **1 — MVP** | Grid, pathing, movement, range, LoS, threat, 3 CC skills, theater walk replay, target arrows |
| **2 — Dungeons & swarms** | Obstacle rooms, camera bounds, telegraphs, 100-unit perf pass |
| **3 — Player AI & traps** | Custom AI hooks, pull mechanics, trap releases |

Phase 1 is the subject of the implementation plan.

## Open Questions (defer)

- Exact tile size and arena pixel dimensions (tune in Task 1 prototype).
- GCD / global cooldown interaction with dual-wield off-hand timer.
- Whether heal threat uses all living enemies or only enemies that have damaged/been damaged by party ("in combat" definition) — plan uses **any enemy with `in_combat` flag set on first hostile action**.
