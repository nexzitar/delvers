# Delvers

Delvers is a roguelite guild-building RPG where you recruit adventurers, craft equipment from monster materials, discover permanent recipes, and send your party into dangerous multi-room expeditions. Every expedition strengthens your camp—not through endless stat inflation, but through new knowledge, new heroes, and new possibilities.

A crafting-driven dungeon crawler built with [Godot 4.6](https://godotengine.org/). Lead your delvers through escalating dungeon rooms, hunt monsters for **materials and recipes**, and grow your camp's knowledge — combat resolves in a headless simulation and replays as a low-poly 3D theater scene built entirely from procedural rigs.

## Trailer

**[Watch: Delvers — Chapter One: The Darkwood (vertical slice)](https://youtu.be/40jkvYQuu3A)**

[![Delvers — Chapter One: The Darkwood](https://img.youtube.com/vi/40jkvYQuu3A/maxresdefault.jpg)](https://youtu.be/40jkvYQuu3A)

Fifty-six seconds, captured entirely from the live game: the abandoned camp, the Darkwood, poison and arrows, a recovered treatise, the Virulent Iron Sword forged, the Slime King slain, the banner rising — and a stranger at the fire. (Re-render it anytime: `capture/trailer_shot.tscn`, then `capture/make_trailer.sh`.)

## Screenshots

| Main menu | The camp |
|-----------|----------|
| ![Main menu](docs/screenshots/main_menu.png) | ![The camp](docs/screenshots/camp.png) |

![Combat theater](docs/screenshots/battle.png)

| Hero loadout | Item tooltip |
|--------------|--------------|
| ![Hero loadout](docs/screenshots/loadout_open.png) | ![Item tooltip](docs/screenshots/loadout_tooltip.png) |

| Two-handed weapon blocks the off-hand | Dual-wield |
|---------------------------------------|------------|
| ![Bow equipped](docs/screenshots/loadout_equipped_bow.png) | ![Dual-wield](docs/screenshots/loadout_dualwield.png) |

| Click-to-carry an item |
|------------------------|
| ![Carrying an item](docs/screenshots/loadout_carry.png) |

## In Motion

**From the menu into camp** — the camera glides from the title framing down to the fire:

![Menu to camp](docs/gifs/menu_to_camp.gif)

**A delve room** — pathfinding around pillars, target arrows, swings landing on the damage beat, floating numbers, slimes hopping in:

![Battle](docs/gifs/battle.gif)

## Meet the Cast

| Default Delver (melee) | Default Delver (archer) | Goblin Archer | Goblin Warrior | Green Slime | Venomous Spider | Slime King |
|:--:|:--:|:--:|:--:|:--:|:--:|:--:|
| <img src="docs/screenshots/cast_delver.png" height="170" alt="Default Delver melee"> | <img src="docs/screenshots/cast_delver_archer.png" height="170" alt="Default Delver archer"> | <img src="docs/screenshots/cast_goblin_archer.png" height="150" alt="Goblin Archer"> | <img src="docs/screenshots/cast_goblin_warrior.png" height="150" alt="Goblin Warrior"> | <img src="docs/screenshots/cast_green_slime.png" height="110" alt="Green Slime"> | <img src="docs/screenshots/cast_venomous_spider.png" height="110" alt="Venomous Spider"> | <img src="docs/screenshots/cast_slime_king.png" height="150" alt="Slime King"> |
| Sword-and-board melee | Bow-wielding ranged | Owns wood & strings | Owns iron & leather | Owns gel & ooze | Owns poison; its bite envenoms | Boss of the first delve |

## Features

- **Spatial combat simulation** — Heroes and enemies fight on a tile-based battlefield: units path toward their targets (A* + soft separation), attacks are gated on weapon/skill range and line of sight, ranged attacks wind up standing still, and enemies pick targets from threat tables. Combat runs headlessly and produces a full event log.
- **3D theater playback** — Combat results replay in a low-poly 3D battle scene built entirely from procedural primitive-mesh rigs: units walk (or hop) along their logged paths, melee swings land on the damage beat, archers draw and loose visible arrows, deaths crumple into corpses, and target arrows + floating damage numbers keep it readable. A camera follows the fight.
- **Battle UI** — Side panels show each team's units (portrait, name, health and mana) plus a live damage/DPS meter, keeping the battlefield itself free of floating nameplates.
- **Data-driven units** — Heroes and enemies are defined as Godot resources (`.tres`) with stats, skills, and linked actor scenes.
- **Full game loop** — Main menu → camp → battle → back to camp. The camp and menu share a campfire stage where your unlocked heroes sit at random seats around a smoldering, animated fire that grows with the party's deeds. Soft ground shadows sit under every actor at camp and in battle. Entering camp from the menu plays a zoom-and-fade transition, and the party keeps their seats across it.
- **Hero loadout** — Hover a hero at camp for a golden outline and nameplate, then click to open their loadout: a live paper-doll preview with flanking equipment columns, a weapon row, and a skill row; tabbed gear and skill catalogs; and a shared stash sorted by slot and rarity. Head gear layers cleanly — full helms hide the hero's hair, open pieces like circlets leave it visible. Off-hand weapons render on a mirrored pivot beside the body (separate from the main-hand arm). Move items by drag-and-drop or click-to-carry (handy on a trackpad). Dropping gear on the hero panel auto-equips it; right-click equips from the stash or unequips worn gear. Weapons show a damage range, swing speed, and average DPS in a two-column tooltip, with equipped-gear comparison in a separate panel. Dual-wielding a one-handed weapon in each hand adds off-hand swings at 50% damage. A bow or two-hander blocks the off-hand slot with a dimmed ghost. Equipping a bow turns a hero into a back-row archer; melee weapons keep them in the front row — changes that carry straight into the next battle — and persist to disk.
- **Sound** — Procedurally synthesized placeholder audio: looping menu and combat themes, fire-crackle ambience, a creaking sign, UI hover/click feedback, and combat hits, swings, and bow shots. Mixed through Master/Music/SFX/Ambience buses.
- **Settings** — Fullscreen toggle and four volume sliders, persisted to disk and applied on startup.

## Game Design

### Vision

Delvers is a party-based dungeon crawler where you send heroes — your *delvers* — into dangerous places and watch them fight. You're running and growing an adventurers' guild: **materials are consumed, knowledge is permanent**, and every expedition brings home resources to build with or recipes that permanently expand what the camp can create. Tactical depth comes from party composition, gear/skill combinations, and crafting toward specific builds rather than direct real-time control — power comes from good combinations, not grinding.

### Core Loop (planned)

1. **Camp** — Recruit and equip delvers at the campfire hub.
2. **Delve** — Enter a dungeon and encounter enemy groups.
3. **Combat** — Battles resolve automatically via the simulation engine.
4. **Theater** — Results play back as a staged battle scene.
5. **Rewards** — Collect loot, experience, and progress deeper.

The loop is playable: you start with a single delver (one bonus skill slot — more through future meta progression) and embark on a **delve of ten escalating rooms** ending at the **Slime King's lair**, health carrying between rooms, each room flowing into the next automatically. **Monsters drop resources and knowledge, not equipment**: every enemy has a material identity (goblins carry ash wood and bow strings, slimes ooze gel and acid), recipes drop rarely as permanent unlocks, and finished gear is a memorable fluke — or a boss trophy. Back at camp, the **Forge** turns materials plus known recipes into intentional equipment (item level and quality set by the recipe). Materials are consumed; knowledge is permanent. Everything persists to disk.

### Combat Design

Combat is **auto-battler** style: units act on attack timers rather than player input. Each entity has:

- **Health and mana** — Base stats from their template resource; health carries between delve rooms (attrition).
- **Attack interval** — How often they swing. For heroes, the main-hand weapon's swing speed sets this interval when equipped.
- **Position and movement** — A spot on the battle grid; units path toward targets with A* and soft separation, and stop at striking distance.
- **Skills** — Data-driven abilities with ranges, cooldowns, status effects, and behavior scripts (Frost Nova roots, Hamstring slows, Charge gap-closes, Heal mends).

Damage is rolled as `base_attack + random(skill.min_damage, skill.max_damage)` for skills, plus a per-swing weapon damage roll for equipped weapons. Combat ends when one side is wiped out.

**Spatial targeting** — Attacks are gated on weapon/skill range and line of sight: melee closes in before swinging, archers stop and wind up in place, and nobody shoots through pillars. Enemies pick targets from **threat tables** (damage and heals generate threat; a rooted enemy falls through to whoever is in range), while heroes engage the nearest foe.

**The delve** — Ten rooms of escalating packs and enemy levels across an arena pool (open field, pillared hall, choke-point wall, scattered rocks), ending at the Slime King. Every enemy rolls a level that scales its health and attack, shown in its name (e.g. *Green Slime Lv 2*). Rooms flow into each other automatically; death or triumph banks the spoils either way.

**Loadout and roles** — A hero's combat role is driven by what they wield. Equipping a bow assigns the Arrow Shot skill and a back-row slot; equipping a one-handed weapon assigns Slash and a front-row slot, and bows/two-handers free the off-hand. Gear lives in a shared stash (each item is a single physical object), skills are a known catalog, and every change a hero makes is read directly off its template by the next battle. Everything persists to disk.

**Weapon speed and dual-wield** — Each weapon has a damage range (e.g. 1–3) and a swing speed in seconds. Per-hit damage is rolled from that range; listed DPS uses the average. Faster weapons hit more often with smaller rolls; slower weapons hit harder per swing. Weapons are tuned so similar item levels land in a comparable DPS band, leaving room for future trade-offs (armor stats, procs, etc.). A one-handed weapon in the off hand swings on the same timer at 50% of its rolled damage, so dual-wielding trades shield or stat slots for extra attacks. In the theater replay, off-hand strikes jump to melee range and play a quick mirrored swing from the off-hand weapon — independent of the main-hand animation.

A key architectural choice is **separating simulation from presentation**:

```
CombatState (simulate) → CombatLog / CombatResult → TheaterController (replay)
```

This lets combat run instantly in the background (useful for fast-forward, AI testing, or server-side resolution) while the player watches a polished replay. The two layers communicate only through serializable events (`SPAWN`, `DAMAGE`, `DEATH`), keeping them independent.

### Content Pipeline

New units and abilities are added without code changes:

1. Create an **actor scene** in `scenes/theater/actors/` (sprite, animations, HP bar).
2. Define a **template resource** in `resources/heroes/` or `resources/enemies/` (stats, skills, actor link).
3. Define **skills** in `resources/skills/` (damage, targeting, behavior script).
4. Reference them in combat setup or future dungeon encounter tables.

The `SkillDefinition` class already supports attack/spell/support types, cast times, AoE targeting, cooldowns, and custom behavior scripts — most of these are wired up for future skills beyond the current auto-attack.

### Current State vs. Roadmap

| Area | Status |
|------|--------|
| Spatial combat simulation (movement, range/LoS, threat, skills) | Working |
| 3D theater playback (procedural low-poly rigs) | Working |
| ~~Formation slots~~ | Replaced by spatial positioning |
| Game loop (menu → camp → battle → camp) | Working |
| Hero loadout (equipment, skills, naming) | Working (session-only, no save yet) |
| Camp upgrades / recruiting | Not started |
| Delve (10 escalating rooms, arena variety) | Working |
| Loot drops + spoils screen | Working |
| Save / persistence | Working |
| Crafting (materials, recipes, the Forge) | Working (slice 1 — affixes and salvaging planned) |
| Dungeon boss (Slime King) | Working |
| Skills (root/slow/charge/heal + auto-attacks) | Working, equippable via loadout |
| Sound | Procedural placeholder audio with settings (no composed music yet) |
| Settings | Fullscreen + volume sliders working |

## Requirements

- [Godot 4.6](https://godotengine.org/download) (Forward Plus renderer)
- No external dependencies

## Getting Started

1. Clone the repository:

   ```bash
   git clone https://github.com/nexzitar/delvers.git
   cd delvers
   ```

2. Open the project in Godot (`project.godot`).

3. Press **F5** (or click Play) to run. The main scene is the menu at `scenes/menus/menu.tscn`.

### Test Scenes

| Scene | Path | What it does |
|-------|------|--------------|
| Combat simulation | `scenes/combat/combat_simulation.tscn` | Runs a headless fight and prints the combat log |
| Battle theater | `scenes/theater/battle_theater_3d.tscn` | Simulates a fight and plays it back in the 3D battle scene |
| Screenshot capture | `capture/shots.tscn`, `capture/cast.tscn`, `capture/loadout_shot.tscn` | Regenerates the README screenshots and unit renders into `docs/screenshots/` |

## Project Structure

```
delvers/
├── art/              # Sprites, UI textures, gear/skill icons, empty-slot art, shaders, fonts
├── audio/            # Procedurally synthesized sounds and music loops
├── capture/          # Harnesses that regenerate the README screenshots
├── docs/             # README screenshots and unit renders (not imported by Godot)
├── resources/        # Hero, enemy, gear, skill, material, recipe, and arena definitions (.tres)
├── scenes/
│   ├── camp/         # Camp scene, campfire stage, animated fire
│   ├── combat/       # Headless combat simulation scene
│   ├── menus/        # Main menu
│   └── theater/      # 3D battle theater scene and 2D actor scenes (camp/loadout)
└── scripts/
    ├── camp/         # Camp, campfire stage, fire, and hero-loadout screen
    ├── combat/       # Simulation, entities, events, and results
    ├── data/         # Template classes for heroes, enemies, gear, and skills
    ├── game/         # Autoloads: roster/loadout, settings, sounds, scene flow
    ├── theater/      # 2D actor visuals still used by the camp and loadout
    └── theater3d/    # 3D battle theater: procedural rigs, replay, overlays
```

## How Combat Works

Combat is split into two layers:

1. **Simulation** (`scripts/combat/`) — `CombatState` runs the fight in discrete time steps on a tile grid (`BattleArena`). Units acquire targets (threat tables for enemies, nearest for heroes), path toward them with A* and separation steering, and attack only in range with line of sight — melee on weapon-speed timers, ranged via stationary casts, plus cooldown skills (Frost Nova, Hamstring, Charge, Heal). Every action is recorded as a `CombatEvent` in a `CombatLog`; when one side is eliminated, a `CombatResult` is built.

2. **Theater** (`scripts/theater3d/`) — `TheaterController3D` replays the combat log in real time in a 3D scene: procedural rigs spawn from templates/loadouts, `MOVE` events drive walking, melee swings are cued so contact lands on the `DAMAGE` beat, casts draw and release arrows, statuses and heals float up as text, and the side panels (unit health/mana and damage meters) track everything live.

## Current Content

| Type   | ID             | Name           | Stats |
|--------|----------------|----------------|-------|
| Hero   | Default Delver | Default Delver | 100 HP, 10 mana, 1 ATK; weapon speed sets interval; front or back row by loadout |
| Enemy  | green_slime    | Green Slime    | 25 HP, 1 ATK, 4.0s interval, front row |
| Enemy  | goblin_archer  | Goblin Archer  | 20 HP, 2 ATK, 3.5s interval, back row, ranged |
| Skill  | auto_attack    | Slash          | 0–9 bonus damage, melee |
| Skill  | arrow_shot     | Arrow Shot     | 1–7 bonus damage, projectile |
| Skill  | frost_nova     | Frost Nova     | Roots everything within 96px for 3s, 10s cooldown |
| Skill  | hamstring      | Hamstring      | Melee strike, slows 50% for 6s, 8s cooldown |
| Skill  | charge         | Charge         | Gap-closer up to 400px, stuns 1.5s, 12s cooldown |
| Skill  | heal           | Heal           | Restores 8–12 to the most injured ally in sight, 6s cooldown |
| Gear   | starter_sword  | Starter Sword  | Main hand, one-handed, 1–3 dmg, 2.6s speed |
| Gear   | starter_bow    | Starter Bow    | Main hand, bow, 1–4 dmg, 2.8s speed |
| Gear   | fast_dagger    | Fast Dagger    | Main hand, one-handed, 1–2 dmg, 1.5s speed |
| Gear   | heavy_axe      | Heavy Axe      | Main hand, two-handed, 4–9 dmg, 3.4s speed |
| Gear   | starter_shield | Starter Shield | Off hand, +10 HP |
| Gear   | starter_helmet | Starter Helmet | Head, +5 HP |
| Gear   | starter_armor  | Starter Armor  | Chest, +15 HP |
| Enemy  | goblin_warrior | Goblin Warrior | Melee bruiser; drops iron scrap and leather |
| Enemy  | venomous_spider | Venomous Spider | Fast skitterer from room 3; venom bite poisons, drops poison sacs |
| Enemy  | slime_king     | Slime King     | Boss of room 10: crowned, royal purple, always drops rare |

## License

This project is licensed under the [MIT License](LICENSE).
