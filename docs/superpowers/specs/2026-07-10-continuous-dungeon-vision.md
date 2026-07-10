# The Continuous Dungeon — one place, walked end to end

*Owner vision, 2026-07-10. The next major arc. Read together with
2026-07-10-compiled-world-vision.md — this is the Architecture and
Dungeon Layout layers of the hierarchy becoming real.*

## The vision

Today a delve is ten "rooms" teleported between. It should be **one
dungeon**: the party walks from encounter to encounter inside a
single believable place — the feel of watching someone run a World
of Warcraft dungeon. Consequences the owner named:

- **Walking is real**: no teleports; travel between packs is part of
  the replay.
- **Pulls are real**: a fleeing enemy can reach the next group and
  bring it; a stray arrow (Wren...) can pull a pack too early;
  some groups intentionally chain (Ashen Brood rule).
- **Rooms hold more than one pack**, sometimes patrols, sometimes
  **mid-bosses** — not just the end boss.
- **Elevation matters** eventually: height differences, maybe rooms
  stacked above each other.

## Sim implications (assessment)

The sim stays headless and deterministic; scope grows from
one-battle to one-dungeon.

1. **One arena, dormant packs**: the whole dungeon is one grid;
   enemy packs spawn dormant with a perception radius, a leash, and
   a social-link group id. Combat is not a mode switch but an
   emergent state (any pack aggroed).
2. **Travel**: out-of-combat the party follows the dungeon spine
   (leader pathing + formation follow). The event log grows walk
   segments; the theater replays them — that IS the WoW feel.
3. **The pull grammar** (encounter atoms): proximity aggro; chain
   aggro via flee-toward-ally (the Workshop kiting atom, reused);
   projectile overshoot pulls; linked-pack ids; patrol routes
   crossing the spine.
4. **Elevation is 2.5D, not 3D physics**: a height value per tile,
   ramps as traversal, LoS respecting height. WoW dungeons are
   navmeshes with height, not free 3D. Stacked floors = multiple
   grids joined by stair nodes (a graph of grids), rendered
   physically stacked in the theater.

### Staging

- **Phase A — the continuous flat dungeon**: one grid, dormant
  packs, travel, pulls, multi-pack rooms, mid-bosses. Darkwood
  retrofitted as the proof.
- **Phase B — the heightfield**: per-tile elevation, ramps, LoS
  with height, theater maps height to Y.
- **Phase C — stacked floors**: grid graph + stairs, only if B
  earns it.

## Asset strategy

Two-tier rule applies:
- **Blender compiles the architecture grammar** (the garment engine
  pattern at room scale): a modular kit — floors, walls, arches,
  pillars, bridges, stairs, door frames, rubble — generated
  procedurally per theme, solid two-tone materials, dyed per theme
  at runtime exactly like garments.
- **Tripo generates the organic hero pieces** (statues, dragon
  bones, roots, shrines) — one-offs the grammar can't derive.

## Audio direction

Audio is a grammar too: per-theme **stem sets** (drone bed,
percussion loop, pad/choir, stinger set, ambience bed) assembled at
runtime on the existing Music/SFX/Ambience buses, with vertical
layering driven by state (explore stems ↔ combat stems crossfade;
boss adds a layer). Stems are compiled offline; the runtime only
mixes. Generation candidates: ElevenLabs (official MCP; SFX +
ambience textures), Stable Audio API (music stems, commercial
license), MusicGen via Replicate (loops; check weight licensing).
Procedural in-Godot ambience (wind, drips) already has precedent in
UiSounds.
