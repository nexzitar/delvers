# Changelog

Notable changes per pull request. Newest first.

## PR #12 — Guild Engineering & the Sunken Workshop *(open)*

### Added
- **Sculpted gear models arrive** (TripoAI): `starter_helm.glb` and
  `starter_chest.glb` mount on the skeleton through a worn-model
  registry keyed by slot — helm fitted with the face open, chest
  wrapping the torso. Slots without a sculpted model keep their
  procedural boxes; per-gear-id models (iron vs starter vs chitin)
  are the natural next step of the same table.
- **The Guild Animator saves** (`save_tuning` toggle acts as a
  button): the sit values write to `resources/tuning/pose_tuning.json`
  and the game reads that file — tune, save, done, no screenshots.
  The knobs load from the file on start, sit knobs ARE the tuning
  (single source of truth), and the owner's latest session ships as
  the defaults.
- **The Guild Animator** (`capture/guild_animator.tscn`, formerly the
  pose tuner): any pose, scrub/play, live sword-grip fitting,
  per-joint degree offsets — and now a **free camera**: left-drag
  orbits, wheel zooms, middle-drag (or shift+drag) pans.
- **The camp camera orbits**: right-drag circles the fire, the wheel
  zooms — inspect the party from any angle; left-click hero picking
  is untouched. The menu stays scripted.
- **Camp scene polish round three**: the menu camera pans left so
  seated delvers never hide behind the panel; the resting shield
  leans against the log instead of standing on it; the lap-sword
  angle improved; and `capture/pose_tuner.tscn` lets the owner tune
  the sit pose live — run it, open the Remote scene tree, drag the
  exported sliders, report the numbers.
- **Crowd navigation** (playtest, the big one): paths are
  crowd-aware — tiles held by other units cost extra, so attackers
  **fan out around a queue** instead of forming one, and a unit
  heading for a target behind a blocker **flanks instead of
  bulldozing** (measured: six swarmers now land five in range where
  they used to queue; a blocker is displaced 12px instead of shoved
  across the field). Stall detection forces a fresh path when a unit
  is walking but going nowhere.
- **Pose corrections round two**: helmet turned around (the nose
  guard was at the nape) and fitted; the head-lift sign flipped (he
  was looking *more* down); the swing crest lowered and tilted
  outward so the blade clears the head; the lap-sword lies flatter;
  and at the campfire **the shield comes off the arm** and leans
  beside him while he tends the blade.
- **The delvers get dressed** (worn gear on imported models): every
  worn slot mounts on the skeleton — helmet (fitted), pauldrons,
  chest plate, gold-buckled belt, gauntlets, bracers, greaves, boots,
  the bow in the archer's grip — reading the exact same opt keys the
  procedural rigs dress with. The **cloak is a SpringTail**: it sways
  with movement, exactly as promised.
- **The campfire polish**: seated with a sword, the blade now rests
  across the lap and the off hand works it in slow strokes — the
  guild's quietest storytelling.
- **Wren's hair moves** (`SpringTail`): a verlet spring chain hangs
  from her head bone — the ponytail trails her movement, swings
  through on stops, and settles under gravity, never glued to the
  skull. Presentation-only physics (the sim never sees it), and the
  same system will drive cloaks.
- **Wren has a body** (`delver_female.glb`): her export came as a
  bare rig, so the adapter grew an **animation donor** system — she
  borrows the male's clips, retargeted onto her skeleton by bone name
  (one animation set can drive the whole same-skeleton cast; future
  models need no animation export at all). Companions carry their
  bodies by name (Wren and Kessa are women), persisted in the save,
  backfilled for pre-model saves.
- **Pose corrections** (playtest): the sit folds the legs *forward*
  (they were tucked behind, through the log), the sword rests
  forward-and-up from the fist instead of hanging straight down, the
  shield angles toward the line of advance, and every pose lifts the
  chin — he no longer studies the ground.
- **Model animation polish** (playtest): the idle scrubs only its
  calm first stretch (the 15s capture had wandering feet), the walk
  runs at stride pacing (the theater's radian phase was cycling the
  clip seven times a second), and the wood-chop is retired from
  combat — the one-handed swing is now **authored directly on the
  skeleton** (probe-verified bone axes: windup overhead, cut to a
  forward strike, contact on the theater's beat), the same
  deterministic pose-function shape as the procedural rigs. The camp
  went imported too: models reach the fire and **sit** via an
  authored bone pose (hips folded, hands on knees, gentle sway).
- **The first TripoAI delver walks** (`resources/models/delver_male.glb`):
  the male delver model is live in battle — clips identified by
  render-inspection and mapped explicitly (idle/walk/run/chop/defeat/
  cast; Tripo strips names to NlaTrack_*), geometry-decal eyes placed
  on the head bone via a marker-sweep render (the texture's ghost
  eyes, answered), sword and shield gripped by the hand bones (the
  same meshes the procedural rigs carry), scale and facing tuned to
  the world. Procedural rigs remain for everyone else — the two cast
  systems coexist per-actor.
- **Imported-model landing zone** (for the TripoAI delvers): heroes
  can carry a glTF `model_scene` on their template; the path travels
  through the SPAWN event, and a new `AnimatedActor` wraps the
  imported scene to speak the exact pose contract the procedural rigs
  do — clips discovered by name (walk/attack/idle/death), driven by
  deterministic scrubbing (replay-safe), missing clips borrowing
  gracefully. No model set = procedural rig, unchanged. Drop a GLB
  in, point a template at it, done.
- **The Sunken Workshop** (dungeon three): the old guild's flooded
  engine-halls, below the Nest — the Broodmother guards the map. Its
  threat: constructs whose **Piston Strikes pierce armor entirely**
  ("DO NOT BE WHERE IT LANDS"); its answer, found inside: the evasion
  set (Oiled Leathers, Sprung Boots, Engineer's Goggles — dodge slips
  a piston whole); its lesson: don't trade blows with machines.
  Scrap Sentinels, Oil Slicks (Gum Strike slows your swings), Cog
  Throwers, Rust Mite swarms, and **The Foreman**, who walks the
  assembly floor still and teaches the Engineer's Slate, then
  Battlefield Doctrine II and III. Brass-and-oil theater theme, four
  workshop-log fragments, three new materials and recipes.
- **The Engineer's Slate** IS the Doctrine Editor now (owner call:
  capacity before the editor was backwards): no custom doctrine at
  all until the Foreman teaches the Slate, which opens the editor as
  snap-together colored blocks — gold WHEN, blue target, violet cast,
  green move — holding four marks. Battlefield Doctrine II (8 nodes)
  and III (16) follow from the same teacher, in order.
- **Movement joins the doctrine engine**: trees gained a move channel
  ("A melee foe closes in" → "Move: Keep Distance"), the sim gained
  real kiting (fall back to open ground, shoot from the new range —
  classic stutter-kite), and the **Skirmisher's Step** doctrine
  teaches it as a built-in tactic — recovered from the Cog Thrower,
  who has always fought that way. *"Loose, step, loose. The ground
  you give away is ammunition."*
- **The Engineer's Annotations** (recovered knowledge, data-complete):
  adds the **View Code** button — the doctrine shown as the Python it
  always was ("The blocks were always words."). Its teacher waits in
  a dungeon not yet mapped.

## PR #11 — The Doctrine Editor *(open)*

### Added
- Undiscovered doctrines are truly hidden now (the "?????  recover
  the..." hints were spoilers) — instead, the expedition logs
  foreshadow them: *"Captain Aldric shouted something they called the
  Shield-Line. I never learned what it meant."* Recover the doctrine
  later and remember where you heard the name.
- **Reset Save** in the settings panel: two clicks (the second one
  honest — "Really? Everything is lost!", disarming after four
  seconds), then the ledger burns: save deleted, guild returned to
  its founding day, back to the main menu.
- **The Doctrine Editor** (Phase 3 of the long tutorial): invisible
  until the guild recovers its first Battlefield Doctrine tome, then
  a rule builder in the Tactics tab — WHEN [condition, with numeric
  parameters] THEN [target selector or cast] — with a live node
  counter against the guild's recovered capacity, reordering,
  deletion, and instant persistence. Target selectors are the
  recovered tactics; castable actions are what the hero can actually
  field (mastery kit + slotted techniques). The editor writes the
  same behaviour trees the built-in tactics are made of — Scratch
  and the Engineer's Python will simply be richer faces over this.

## PR #10 — Mastery: identity through practice *(open)*

### Added
- **Doctrine Complexity is knowledge**: custom doctrine is measured
  in nodes (one per rule, one per condition) and capacity is
  recovered like everything else — Battlefield Doctrine I (4 nodes,
  the Slime King teaches it), II (8, the Broodmother). A fresh guild
  holds zero capacity; over-budget doctrine falls back to the
  pre-authored tactic. A veteran guild literally thinks in longer
  plans.
- **The shared behaviour-tree engine** (`BehaviorTree`): built-in
  tactics are now pre-authored trees — plain JSON rule lists with a
  targeting channel and a casting channel ("IF enemy count >= 4 THEN
  Thunderclap") — full parity with the old scorer, and entities carry
  an optional custom tree: the exact data Scratch and the Engineer's
  Python will write. **Protect the Healer** ships as the first
  composite tree (hunts whatever hunts the mender), taught by the
  Brood Tender.
- **Battlefield Doctrines** (first slice of the recovered-knowledge
  progression, spec: 2026-07-07-recovered-knowledge-progression.md):
  tactics are knowledge now, not menu options. A fresh guild knows
  only Nearest Foe; the rest drop as doctrine tomes from their
  practitioners — warriors teach the Shield-Line (Guard), archers the
  Culling Shot (Finish the Wounded), spiders the Creeping Venom
  (Spread), bosses the Marked Prey (Focus Order). Doctrines shelve in
  the Library with their lore; unrecovered ones show as hints in the
  Tactics tab; veteran saves keep everything.
- **Discipline Mastery** (design: docs/superpowers/specs/
  2026-07-06-mastery-identity-training.md): no classes — the worn
  loadout decides what trains (Sword, Shield, Bow; slotted healing
  trains Restoration). Every cleared room is practice; the boss room
  counts fourfold.
- **Stars unlock techniques, not numbers**: Sword ★★ Cleave, ★★★
  Weapon Familiarity, ★★★★ Hamstring, ★★★★★ Whirlwind (each
  discipline has its track). Core techniques join combat
  automatically — no slot cost; the Guild's Technique Slots remain
  free customization on top.
- **Rusty, not forgotten**: unpracticed disciplines fade a little per
  delve, but the highest mastery ever earned never moves — and
  relearning below your best is three times faster. The loadout shows
  each delver's history: filled stars current, hollow gold dormant,
  dim empty.
- Star-ups announce themselves in the spoils toast ("Garrick: Sword
  ★★ — Cleave!"). Veteran saves seed their current kit at two stars.
- **Tanking tools**: Battle Shout is LOUD — it generates threat on
  every engaged enemy (10 per ally emboldened, split across the
  pack), making it Garrick's AoE aggro opener. And the new **Guard
  the Line** tactic strikes whoever holds the least threat toward
  this delver, so the tank actively keeps every eye on themselves.
- **Guild techniques for everyone**: Battle Shout (the whole party
  hits harder for a while — new EMPOWER status with a badge) and
  Rally (a heartening cry that mends the whole party) join Charge and
  Heal in the slot catalog — a back-row archer finally has real
  choices. One technique, one slot: doubling up on Heal is refused.
- **Mastery owns the core techniques**: Cleave, Whirlwind, Multishot,
  Shield Wall and kin cannot be slotted — a whirlwind needs a sword
  in hand and the stars to back it. Technique Slots hold guild
  techniques (Charge, Heal); the catalog dims core entries and their
  tooltips name the discipline and star that earn them. Old saves
  that slotted core techniques come back clean.

## PR #9 — The Spider Nest, Tactics, and a sharper Forge *(open)*

### Added
- **The Brood Tender** — the Nest's lesson made flesh: a swollen
  spider that births spiderlings into the fight (real mid-combat
  SPAWN events, capped brood), anchored in every nest room and beside
  the Broodmother. Kill the spawner first or drown: focus order and
  AoE are the curriculum.
- **Difficulty tiers** (per dungeon, clearing tier N unlocks N+1, up
  to V): higher tiers raise enemy levels and pay in materials, rarity
  odds, and **tier-gated recipes** — never in raw item level. Power
  comes from covering more slots with the dungeon's answer.
- **Every dungeon has an answer, found inside it**: the Darkwood's
  threat is steel and its gear is armor; the Nest's poison ignores
  armor, so nest gear carries the new **Poison Resist** stat
  (Silk-Lined Hood, Chitin Shield/Armor get their own bases). Higher
  tiers teach more coverage: Iron Greaves (Darkwood II), Warden's
  Pauldrons (III), Silk-Wrapped Bracers (Nest II), Weaver's Cloak
  (III) — four new slots come alive.
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
- **The archer kit**: Multishot (a fan of arrows into the nearest
  foes — held for 2+ targets) and Piercing Shot (a heavy arrow that
  ignores armor — the answer to chitin walls), both scaling with bow
  damage, with quick-draw animations and arrow streaks.
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
- **Worn gear shows on the body**: shoulders, cloak, chest plate,
  belt (with buckle), gauntlets, bracers, greaves, and boots all
  render on the rig, colored by gear family — a kitted delver finally
  looks the part (basic now, detailed later).
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
- Knowledge pity leaked tier-gated recipes at tier 1 (playtest:
  greaves and pauldrons from a Darkwood I run) — pity honors
  min_tier like every other drop now.
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
