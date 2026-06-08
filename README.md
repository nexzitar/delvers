# Delvers

A dungeon-crawler style game built with [Godot 4.6](https://godotengine.org/). Lead your delvers into battle against monsters, with combat resolved by a simulation engine and replayed as animated theater scenes.

## Features

- **Combat simulation** — Heroes and enemies fight using timed auto-attacks, skills, and formation slots. Combat runs headlessly and produces a full event log.
- **Theater playback** — Combat results are replayed visually: actors spawn on the battlefield, attack animations play, damage numbers float up, and deaths are shown.
- **Data-driven units** — Heroes and enemies are defined as Godot resources (`.tres`) with stats, skills, and linked actor scenes.
- **Main menu** — Campfire-themed menu with Enter and Exit actions.

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

## Project Structure

```
delvers/
├── art/              # Sprites, UI textures, effects, fonts, backgrounds
├── resources/        # Hero, enemy, and skill definitions (.tres)
├── scenes/
│   ├── menus/        # Main menu
│   ├── theater/      # Battlefield and actor scenes
│   └── testscenes/   # Combat and theater test scenes
└── scripts/
    ├── combat/       # Simulation, entities, events, and results
    ├── data/         # Template classes for heroes, enemies, and skills
    └── theater/      # Visual playback of combat events
```

## How Combat Works

Combat is split into two layers:

1. **Simulation** (`scripts/combat/`) — `CombatState` runs the fight in discrete time steps. Entities attack on intervals, damage is rolled from skill definitions, and every action is recorded as a `CombatEvent` in a `CombatLog`. When one side is eliminated, a `CombatResult` is built.

2. **Theater** (`scripts/theater/`) — `TheaterController` reads the combat log and plays it back: spawning actors via `ActorFactory`, triggering attack/hit/death animations, showing HP bars, and spawning floating damage numbers.

Test scenes let you run each layer independently:

- `scenes/testscenes/combat_test.tscn` — Run a combat simulation and print the result.
- `scenes/theater/theater_test.tscn` — Play back a combat result on the battlefield.

## Current Content

| Type   | ID             | Name           |
|--------|----------------|----------------|
| Hero   | Default Delver | Default Delver |
| Enemy  | green_slime    | Green Slime    |
| Skill  | auto_attack    | Auto Attack    |

## License

All rights reserved. Add a license here if you plan to open-source the project.
