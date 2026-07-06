# Changelog

Notable changes per pull request. Newest first.

## PR #9 — The Spider Nest, Tactics, and a sharper Forge *(open)*

### Added
- **The Brood Tender** — the Nest's lesson made flesh: a swollen
  spider that births spiderlings into the fight (real mid-combat
  SPAWN events, capped brood), anchored in every nest room and beside
  the Broodmother. Kill the spawner first or drown: focus order and
  AoE are the curriculum.
- **Difficulty tiers** (per dungeon, clearing tier N unlocks N+1, up
  to V): higher tiers raise enemy levels AND the spoils — loot band
  +4 item levels per tier, better rarity odds, bigger material hauls.
  Old dungeons never go stale; the picker chooses the tier, the room
  banner wears it (The Darkwood III).
- **The multi-enemy toolkit** (playtest: "5–6 enemies and no way to
  deal with it"): five new skills — **Cleave** (carries into two foes
  beside the target), **Whirlwind** (hits everything around you; holds
  until 2+ are close), **Renew** (instant heal-over-time), **Shield
  Wall** (near-halves incoming damage when hurt and pressed), and
  **Thunderclap** (small AoE that dazes enemy attack speed and
  generates triple threat — the tank button, ready for the second
  delver).
- Three gear slots come alive: craftable **Iron-Shod Boots**,
  **Goblin-Work Gauntlets**, and **Studded Belt** (new recipes with
  tomes, taught by spiders, archers, and warriors).
- **Salvaging**: drag gear onto the salvage bin in the Gear tab —
  materials come back (about half the recipe bill, plus a rare-quality
  bonus), and **studying an unknown enchantment teaches that affix
  forever**.
- **Boss trophies are always enchanted**: a random affix, possibly one
  the guild hasn't learned — wield it, or salvage it to study it.
  Normal enemies drop no finished gear at all (playtest: starter-gear
  flukes and affixless trophies both felt pointless).
- **The Spider Nest** — second dungeon, unlocked by a Weathered Map
  Fragment the Slime King guards (dropped once, ever). Dungeons are
  data now (`DungeonDefinition`): pools, guaranteed enemy, boss pack,
  loot band, theme, and lore series per dungeon.
- Nest inhabitants: Nest Spiderling, Web Weaver (its silk roots you —
  "Webbed!"), armored Chitin Crawler, and **the Broodmother** (boss).
- Nest materials (Silk Thread, Chitin Plate, Broodmother's Silk),
  three nest recipes with tomes and lore, and a second expedition-log
  series continuing the Black Hollow trail.
- **Tactics v1**: per-hero targeting directives — Nearest Foe, Finish
  the Wounded, Focus Order, Spread the Venom — plus a party-wide
  sortable focus order in a new Tactics tab. The focus order lists
  only enemies the guild has actually faced (no spoilers).
- **Knowledge pity**: three cleared rooms without a knowledge drop
  guarantee a recipe from the slain enemies' pools; the counter
  persists across delves.
- Dungeon picker on Embark once the guild holds more than one map.
- Webbed-cavern battle theming (stalagmites, silk wraps, egg sacs).
- Trailer v2 pipeline: Godot Movie Maker mode — true 30 fps and the
  procedural soundtrack captured (the first render exposed that the
  local settings file had master volume saved at 0).

### Changed
- **Combat readability**: status badges (poison drop, daze spiral,
  stun star, web, snowflake, renew cross, shield) ride above heads
  while a status runs; damage numbers are team-colored (hits on your
  party glow red, your hits read pale gold, crits gold/red by side);
  floating text lanes key on the entity so bursts on one body never
  overlap; Whirlwind spins the rig with arms flung wide and
  Thunderclap stamps an expanding shockwave ring.
- Forge layout scales to a full recipe book: compact one-line recipe
  rows with color-coded costs; the full bill with hunting grounds
  lives in the pinned selection tooltip.
- Overlapping floating combat texts fan out into side lanes.
- Renew visibly casts (healer raises hands, a soft green ring blooms
  on the target); the Whirlwind spin and Thunderclap shockwave cues
  actually fire (the timeline patch had silently missed); the Forge
  no longer clips Craft buttons or the material shelf.
- Nest loot band: item levels +10; rare unlocked from normals (4%);
  boss epic at 6%.

### Fixed
- Facing whipsaw while approaching: re-paths no longer walk units
  backward to stale tile-center waypoints, and facing samples the
  walked path before separation nudges.
- Perfectly stacked units burst apart instead of freezing merged:
  separation now also runs while standing, and dead-center overlaps
  (zero push vector) resolve along per-entity bearings.
- Dual wielding with equal-speed weapons animates both arms: the
  off-hand starts half a beat out of phase, so strikes alternate.
- Theater victory saves respect `PlayerRoster.autosave` (capture
  harnesses can no longer clobber a real save).
- **Encounters ballooned within a session**: Array(typed) shares the
  resource buffer, so every encounter roll leaked its picks into the
  cached dungeon resource — rooms grew warrior-stuffed over a play
  session (a major hidden source of the iron flood and difficulty
  spikes). Rolls duplicate properly now, with a pristine-resource
  regression test.

### Balanced
- **The Spider Nest tuned for a real party** (playtest: post-Darkwood
  duo with double Virulent one-shot it): nest enemies harder across
  the board (Broodmother 260 HP / 8 attack / 3 armor), packs run one
  body deeper, and the boss brings a second spiderling — clearing it
  should now want nest-tier gear and the second skill slot.
- Standing separation spread brawls out (packed warriors all reach
  the front line).
- **Material flow rebalanced** (playtest: 92 iron vs 3 gel): every
  enemy's materials now drop reliably (100%), warriors lost their
  bulk multiplier and double pool slot, and each dungeon anchors TWO
  farmable enemies per room — the Darkwood fields a warrior (iron)
  and a slime (gel). The economy sim now measures both and asserts
  iron never exceeds 3x the binder.


## PR #8 — Affix recipes, the menagerie, and the Restoration *(merged)*

### Added
- **Affixes as learnable recipes**: Virulent (poison damage-over-time
  on hit), Frostforged (chill on hit), Flaming (+25% damage), Quick
  (15% faster swings), Guarding (+health) — themed drops, applied at
  craft time via a Forge affix picker ("Virulent Iron Sword").
- **Goblin Warrior** and **Venomous Spider** (its bite poisons):
  every material gained one clear owner. Leather + Leather Hood.
- **Secondary stats**: armor, block, dodge, crit, spell power — on
  gear and enemies, with Dodge!/blocked/crit floating feedback.
- **Knowledge provenance**: recipes and affixes drop as named tomes
  ("Spider Venom Treatise — Teaches: Virulent") with lore fragments;
  the **Library** tab shelves everything recovered; the Black Hollow
  **Expedition Logs** drop in order across delves.
- **The Restoration of the Guild**: first victory raises the banner
  and the first companion (Wren) sits down at the fire, free. The
  camp Guild panel sells Training Grounds (second skill slot) and
  Another Voice at the Fire (third delver — costs Royal Jelly).
- **The Darkwood**: moonlit-forest battle theming, the room banner
  names the dungeon, and the first delver has a name: **Garrick**.
- Empty starter stash: a new guild owns only what it wears.
- Forge UX: click-to-select recipes with a pinned crafted-item
  preview and equipped comparison; affix effects spelled out; affix
  chips show descriptions with provenance on hover.
- Chapter One vertical-slice trailer (56s), rendered entirely from
  the live game by a staged capture harness.

### Fixed
- Sword heroes casting Heal froze the session (the theater played the
  archer pose on a rig with no bow); bow-less rigs now cast properly.
- Heal reworked: 4 mana + 1.4s cast instead of a cooldown; fizzles
  refund; mana regenerates slowly.

### Balanced
- Iron economy, measured end-to-end (simulation test): warriors
  always drop materials, haul 2–3 pieces, table tilted 3:1 iron over
  leather, and every room fields a warrior.
- Knowledge redistributed: spiders teach Virulent, archers Quick,
  warriors Guarding, slimes Frostforged, the King keeps Flaming.

## PR #7 — README refresh *(merged)*

- 3D cast gallery rendered from the actual rigs, gameplay GIFs
  (menu→camp, a delve room), and design sections rewritten for
  spatial combat, the delve, and the crafting loop.

## PR #6 — The delve, persistence, and the crafting pivot *(merged)*

### Added
- Camp and main menu rebuilt in 3D; the 2D battle theater retired.
- Save system (schema-versioned JSON; items rebuild deterministically
  from id/level/quality).
- **The delve**: ten escalating rooms ending at the **Slime King**;
  one starting delver, one bonus skill slot, health carrying between
  rooms; rooms auto-advance with a spoils toast.
- **Crafting pivot** ("monsters drop resources and knowledge, not
  equipment"): per-enemy material identities, recipes as rare
  permanent unlocks, the Forge tab, finished gear reduced to boss
  trophies and 2% flukes.
- Frost Nova, Hamstring, Charge, and Heal equippable from the loadout.
- Battle sidebars and the loadout preview render from the 3D rigs.

### Fixed
- Units could freeze forever on an unreachable path (failed searches
  cached until the goal tile changed); pathfinding resolves to
  nearest-walkable, retries, and positions clamp to the arena.

## PR #5 — Spatial combat and the 3D pivot *(merged)*

- Tile-grid battlefield: A* pathfinding, Bresenham line of sight,
  soft separation, threat tables, stationary ranged casts, cooldown
  skills with behavior scripts.
- Low-poly 3D battle theater on procedural primitive rigs, replaying
  the headless sim's event log with cue-scheduled animation.
