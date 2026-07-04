# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

**Delvers** is a party-based dungeon-crawler built with **Godot 4.6** (Forward Plus renderer, GDScript only, no external dependencies). You lead heroes ("delvers") into battle; combat is resolved by a headless simulation and replayed as an animated "theater" scene. See `README.md` for the design vision, current content tables, and roadmap.

## Running & testing

There is no build step. Godot is the toolchain. The editor binary is `/Applications/Godot.app/Contents/MacOS/Godot`.

- **Run the game:** open `project.godot` in Godot and press F5. Main scene is `scenes/menus/menu.tscn`.
- **Headless test scenes** live in `capture/` as `test_*.gd` + `test_*.tscn` pairs (e.g. `test_pathfinder`, `test_threat`, `test_grid_los`, `test_separation`, `test_status`, `test_equip`, `test_dualwield`, `test_arena`, `test_combat_events`). Run one headlessly:
  ```bash
  /Applications/Godot.app/Contents/MacOS/Godot --headless --path . res://capture/test_pathfinder.tscn
  ```
  Convention: a scene test `extends Node`, uses `assert(cond, "msg")`, prints `PASS <name>` on success, then calls `get_tree().quit()`. Add a matching pair when adding a system.
- **`SceneTree` script tests** (e.g. `capture/logic_test.gd`) `extends SceneTree` with an `_init()` and run via `--script`:
  ```bash
  /Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://capture/logic_test.gd
  ```
  Note: **autoloads do not run under a bare `SceneTree` script** — instantiate what you need by hand (see how `logic_test.gd` builds a `PlayerRoster`).
- **Screenshot/render harnesses** (`capture/shots.*`, `capture/cast.*`, `capture/loadout_shot.*`) regenerate the README images into `docs/screenshots/`. `capture/` is not shipped game content; it's the test + tooling folder.

## Core architecture: simulation is separated from presentation

This is the single most important thing to understand. Combat runs to completion **headlessly and instantly**, producing a serializable event log; the visuals are a **replay** of that log. The two layers only ever communicate through `CombatEvent` objects.

```
CombatState (fast tick sim) → CombatLog (Array[CombatEvent]) → TheaterController (real-time replay)
```

- **`scripts/combat/`** — the simulation. `CombatState` (`combat_state.gd`) owns `heroes`/`enemies` arrays of `CombatEntity`, ticks everyone via `update(delta)` in fixed steps (`SIMULATION_STEP = 0.1`), and loops `while not combat.combat_over`. Every meaningful action appends a `CombatEvent` to `combat_log`. `build_result()` returns a `CombatResult`.
- **`scripts/theater/`** — the presentation. `TheaterController` reads the log and plays events back ordered by `event.time`, waiting `event.time - last_time` between them, spawning actors and animations.
- **Rule:** the sim must never depend on theater/scene nodes, and anything the theater needs to draw must travel through a field on `CombatEvent`. When you add a combat behavior, you usually (1) add/extend an `EventType` and a `create_*` factory on `combat_event.gd`, (2) emit it from the sim, (3) handle it in the theater.

## Data-driven content (no code to add units)

Units, gear, and skills are Godot `Resource` `.tres` files under `resources/`, backed by `class_name` scripts in `scripts/data/`:

- `HeroTemplate` / `EnemyTemplate` — stats, `preferred_row`, linked actor scene, `starting_skills`.
- `GearDefinition` — slot, weapon type, damage range, `attack_speed` (swing speed), bonuses; `roll_weapon_damage()`.
- `SkillDefinition` — `delivery_type` (MELEE / PROJECTILE), damage range, range, cast flags.
- `Equip` / `ItemQuality` — equip-position and rarity enums/helpers.

Adding content: make an actor scene in `scenes/theater/actors/`, a template `.tres` in `resources/heroes|enemies/`, skills in `resources/skills/`, then reference them in combat setup. `CombatState.setup_combat(hero_templates, enemy_templates)` builds entities from templates: rolls enemy level/power, claims formation slots, and derives hero stats from equipped gear (main-hand weapon speed sets `attack_interval`; a shield in the off hand is not treated as a weapon).

## Autoloads (global singletons, see `project.godot [autoload]`)

- **`PlayerRoster`** (`scripts/game/player_roster.gd`) — the player's heroes and shared `gear_stash`. **Gear is physical:** each stash entry is one object; equipping moves it onto a hero, unequipping returns the displaced item. `_sync_role()` is the source of truth for combat role: a bow ⇒ Arrow Shot + back row; anything else ⇒ Slash + front row. Loadout edits are read off the template by the next battle and persist for the session only (no save yet).
- **`SceneFlow`** (`scripts/game/scene_flow.gd`) — use `SceneFlow.change_scene(path)` instead of `change_scene_to_file`; it adds the next scene before freeing the old one to avoid a black flash frame.
- **`GameSettings`** — fullscreen + volume, persisted to disk. **`UiSounds`** — procedural SFX and buses (`default_bus_layout.tres`: Master/Music/SFX/Ambience).

## In-progress: spatial combat migration (branch `feat/spatial-combat`)

The repo is mid-migration from **formation-slot, side-view hop-to-target** combat to **free movement on a 2D tile grid** (Zelda-style angled top-down). Design and plan docs: `docs/superpowers/specs/2026-07-03-spatial-combat-design.md` and `docs/superpowers/plans/`. Read the spec before touching combat.

State of play: the spatial primitives exist and are unit-tested but are **not yet wired into `CombatState.update()`**, which still runs the old attack-timer/formation model.

- Present & tested: `BattleArena`/`BattleGrid` (tile grid + `world_to_tile`), `GridPathfinder` (A*), `Threat` (`pick_target` by threat with in-range fallback), `separation.gd` (soft steering), `StatusEffect` (root/stun/slow), grid LoS. `CombatEntity` already carries `position`, `facing`, `move_speed`, `path`, `target_id`, `threat_table`, `in_combat`, `statuses`, casting fields, `weapon_reach`. `CombatEvent` already has `MOVE`/`FACE`/`TARGET`/`TELEGRAPH`/`CAST_*`/`BUFF_*` types and their factories.
- Not yet done: entities don't path or move in `update()` yet; targeting still goes through `Formation` front-row rules in `get_target_for()`. Expect `formation_slot` to be retired for combat as the migration completes.

## 3D art direction prototype (`capture/proto3d/`)

A procedural low-poly 3D exploration the owner likes as a possible future art direction. Everything is built from Godot primitives in code (`delver_builder.gd`, `delver_rig.gd`, `slime_rig.gd`) with deterministic pose-function animation (`pose_walk/swing/shoot(t)` — the same replay-friendly shape as the theater layer). Runnable demos: `proto3d_anim.tscn`, `proto3d_archer.tscn`, `proto3d_battle.tscn`; `*_shot.tscn` harnesses render stills/filmstrips into `renders/`. Rig convention: character faces local +Z, so its anatomical left is +X (sword = right hand at -X, shield/bow = left at +X); positive X rotation swings a hanging limb backward. Run capture scenes from the project root — `--path .` fails silently from subdirectories.

## Conventions

- **GDScript with `class_name`** for combat/data types (referenced globally, no `preload` needed); autoloads and scene scripts use `extends Node`. Indentation is **tabs** (see `.editorconfig`).
- Prefer functional array ops (`filter`/`all`/`pick_random`) as in `combat_state.gd`.
- `.gd.uid` / `.import` sidecar files are Godot-generated — commit them, don't hand-edit.
- Keep comments at the level already in the code: short intent-explaining notes above non-obvious logic, not narration.
