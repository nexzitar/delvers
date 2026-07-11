# Changelog

Notable changes per pull request. Newest first.

## The Continuous Dungeon — Phase A *(open)*

### Added
- **Battle camera orbit**: right-drag turns the bearing, the wheel
  zooms (0.55x-1.9x) - the follow framing keeps tracking the fight
  underneath, so you orbit the battle, not a fixed point. Same feel
  as the camp camera.
- **Creature attacks own their sounds**: slimes lunge with a wet
  stretchy squelch and land gooey slaps (no more sword whooshes from
  a blob), spiders snap their mandibles on attack and on hit. The
  attacker's family picks both the wind-up and the impact sound.
- **THE AUDIO LIBRARY** (ElevenLabs batch, the Tripo pattern for
  sound - audio_batch.py): 24 SFX + 3 per-theme ambience beds
  generated in one sweep. The theater now plays: per-theme looping
  ambience (wind through firs / cavern drips / dead machinery),
  a danger sting plus the family's own voice on every pull (goblin
  barks, spider hisses, slime squelches), family death cries, sword
  swing/hit variants with block clangs and crit crunches, bowstring
  and arrow impacts, heal chimes, loot chimes, banner whooshes, and
  victory/defeat stings. Every hook is guarded - a missing file
  falls back to the old wavs or silence.
- **THE GOBLIN FAMILY** (enemy families, not more enemies): Scout
  (fast, slippery, drops the hood recipe), Shaman (heals its pack -
  pinned by test; teaches Flaming), and Chief (armored elite, teaches
  Priority and the pauldron recipe) join Warrior and Archer. Same
  proportions, same equipment language, five silhouettes: a
  civilization. Scout runs with the core pool, Shaman joins the deep
  pool, and the Chief anchors the mid-boss room via the new
  DungeonDefinition.mid_boss field.
- **PLACES WITH PURPOSE**: every room draws a role (entrance, guard
  post, hall, storeroom, shrine, warren, landmark, mid-boss hold,
  boss lair) with themed names - banners and clear-toasts now say
  "The Warren cleared - pressing on..." instead of "Room 2".
- **LANDMARKS**: each dungeon theme owns a Tripo hero piece - the
  Darkwood's moss-swallowed Warden statue, the Nest's web-wrapped
  spider idol, the Workshop's dead brass colossus - placed in its
  own named room with a warm accent light. Players remember "the
  room with the statue," never "the third corridor."
- **ECOLOGY IS EVIDENCE**: packs seed their surroundings before a
  single enemy moves - spider packs hang webs and egg sacs, slime
  packs leave gel pools, goblin packs camp around a stone fire ring
  with charred logs. The kit compiler grew Web/EggSac/GelPool/
  Campfire pieces with EcoSilk/EcoGel materials.
- **Enemies get the treatment: modeled goblins** - a headless Tripo
  character pipeline (gen_character.py: text -> model -> rig ->
  preset animations -> one GLB) generated the Goblin Warrior and
  Goblin Archer with the SAME skeleton as the delvers, so sockets,
  pose functions and clip conventions work unchanged. EnemyTemplate
  gains model_scene; modeled enemies ride AnimatedActor in battle
  (weapon flags live on the model config). Slimes and spiders stay
  procedural by choice - blobs and arachnids animate better as code.
- **Weapons are held properly**: the socket convention changed to
  the thumb line (a fist holds the handle ACROSS the palm, not along
  the fingers) - the sword now continues the arm mid-swing; the
  procedural bow socket-mounts upright with the string toward the
  archer (it hung upside down from the finger line); the procedural
  sword shares the same grip through a new _socket_mount_node used
  by worn models and built props alike.
- **THE ARCHITECTURE KIT** (the garment engine pattern at room
  scale): a Blender compiler (arch_kit.py) generates a modular
  masonry kit from a construction grammar - coursed stone walls in
  three variants (wandering joints, proud capstones, one jutting
  stone so nothing is flush), pillars with base and capital, arches
  spanning every corridor mouth, rubble piles where rooms settled.
  Solid Arch* materials dye per dungeon theme at runtime exactly like
  garment surfaces (forest moss, nest silk, workshop brass). The
  layout now records rooms and doorways; walls render as per-variant
  MultiMeshes; freestanding masonry becomes pillars automatically.
- **One dungeon, walked end to end**: no more teleporting between
  rooms. DungeonLayout compiles a DungeonDefinition into one place -
  rooms carved along a winding spine with L-corridors and pillars -
  and the whole delve is ONE simulation: packs spawn dormant where
  they live, the party walks the spine between fights, and the replay
  shows all of it (the spec is the dungeon).
- **The pull grammar**: packs wake when a hero enters perception,
  when damage reaches a sleeper, or when an already-woken enemy
  blunders into them - a fleeing enemy chains the next pack. Some
  double-pack rooms are LINKED and pull together. An elite mid-boss
  pack (+2 levels) holds the middle room; the boss keeps the end.
- **Loot banks mid-run**: PACK_DEFEATED events roll and toast each
  pack's drops during the replay ("Room N cleared - pressing on...");
  training, knowledge pity and autosave follow the same cadence. The
  enemy sidebar reveals packs only when they wake, so it always reads
  as the current fight.
- **test_pulls** pins the contracts: sleep at distance, travel when
  quiet, chain aggro, linked pulls, walkable spine, and a full
  compiled Darkwood terminating. Deterministic (seeded).

### Changed
- Dungeon-scale walls render as one MultiMesh (shell tiles only);
  clearing dressing (treeline, scatter) stays for single arenas.
- Enemy spawning refactored into spawn_enemy_entity (shared by
  arenas, packs, reinforcements) with per-pack depth bonuses.
- Harnesses with forced_arena_path keep the single-arena flow.

## Item overhaul — compiled garments become the items *(open)*

### Added
- **GARMENT ENGINE v6 — convergence on believable equipment** (owner
  reference-render analysis): the face partition no longer IS the
  garment; it decorates one. New grammar rules: (1) BASE SHELL first —
  one watertight draped surface, so seams can never gap and skin can
  never peek; (2) OVERLAYS — the partition pieces sit proud of the
  base at defined altitudes (the layer ladder: base < panels < straps
  < pads); (3) CHUNKY FACETS — limited-dissolve planarization turns
  body triangulation into deliberate low-poly planes; (4) FABRIC
  FORGETS ANATOMY — a torso-scoped cast-to-cylinder (the torso's own
  mean radius) drapes cloth across the belly instead of shrink-
  wrapping abs (a Laplacian smooth pass shredded open shells — dead
  end recorded); (5) TERMINATION BANDS — cuffs at wrists/elbows and
  waistbands with buckles, because hems are what make fabric read as
  clothing; (6) FEW BOLD HARDWARE — a studded baldric, pillowed
  two-layer shoulder pads, a hardware size floor.
- **Solid two-tone garment materials end the texture noise era**: the
  engine assigns GarmentPrimary/GarmentSecondary solid materials (no
  body texture), and `_recolor` now dyes **per surface** — garments
  tint directly, textured sculpts keep the chroma shader, hardware
  keeps its leather and steel. Kills the waistband mottle, the
  skin-toned sleeves, and Wren's painted-on abs in one move; GLBs
  drop ~40% (no embedded texture copies).
- **The socket system — weapons are finally HELD**: bodies carry
  named sockets (grip_main in the right palm, grip_off in the left,
  back and hip_l/hip_r for future quivers, backpacks and potion
  pouches), items carry grip points, and the mount places the grip
  exactly on the socket in every pose — the sword now hangs from a
  fist wrapped around its handle instead of floating beside the arm.
  The **Socket Workshop** (capture/socket_workshop.tscn, editor-only
  like the Fitting Room) shows both marker families in the Scene
  dock for standard-gizmo placement; save_sockets writes
  pose_tuning.json. New bows will add a second grip on the string
  for the draw hand, plus a draw animation — the schema is ready.
- **Fixed: pose seeks reverted weapon fits** — every pose seek
  stomped the sword back to fit defaults (why Fitting Room sword
  fits never seemed to stick). Mounts now remember their transform
  and poses restore it. Pinned by test_sockets.
- **Wren wears a headband, not a helmet**: her recruit kit swaps the
  Starter Helmet for a Starter Headband (leather, HEAD, open — hair
  and ponytail physics stay visible; "Keeps the hair out of the
  bowstring"). The band is built by a new Blender harness that
  measures the wearer's own skull at brow height — snug elliptical
  band, knot and trailing ends at the back — compiled per body like
  the garments (male + `_f`). Goblin Archers drop it.
- **Garments compile per body — and Wren gets a shirt**: recruit kits
  now include Starter Armor (Wren arrived with bow and helmet only),
  and the jacket, plain jacket and trousers are compiled from the
  female body too (same specs, her mesh, `_f` GLB variants picked by
  the actor's body). The purchasable third delver's kit gains a chest
  piece as well.
- **The full basic starter set**: Starter Trousers, Boots, Gloves and
  Belt — zero-stat leather basics dropped by Darkwood normals, so a
  fresh delver can finish dressing without power creep. Delvers still
  BEGIN without trousers; the trousers' flavor line explains the
  guild's first provision ("ever since the founder was recovered from
  a hedge maze wearing nothing at all") — a nod to a certain
  outworlder.
- **Gear flavor lines**: GearDefinition gains a `flavor` field shown
  at the foot of the loadout tooltip — a lore channel on the item
  itself.
- **Real items wear the engine's garments**: Starter Armor is a newly
  compiled plain jacket (low volume, short collar, five clasps, no
  belt — humble through CONSTRUCTION, not color), Oiled Leathers is
  the clasp-ladder showcase jacket in a dark oiled palette, and the
  new **Leather Trousers** (LEGS, leather, craftable — recipe taught
  by Goblin Warriors, "The Walker's Second Hide") wear the compiled
  pants. The demo-only ids (leather_jacket, showcase_robe, derived_*)
  are gone; the spec-is-the-item philosophy now points at the loot
  table.
- **Every worn slot mounts its fitted model in real battles**: hero
  opts now carry all worn gear ids, so boots, greaves, bracers and
  gauntlets mount their sculpted models in gameplay (previously only
  capture harnesses did); procedural box fallbacks only fire when no
  fitted model covers the region.

### Changed
- Starter/oiled palettes tuned darker and lower-contrast so the
  recolor classifier's texture noise stays invisible (per-piece
  material slots from the engine are the recorded proper fix).
- `sprung_boots` fixed from WAIST to FEET, with a save-load guard
  that re-routes misfiled items to the stash.

### Removed
- The dead 2D layer: campfire scenes, the 2D TheaterActor chain, the
  superseded 2D cast harness, and the unread `actor_scene` template
  field.
- ~30 MB of superseded models: the Tripo leather chest and robe
  one-offs (replaced by compiled jackets), the v4 derived vest/skirt/
  sleeves set, and the orphaned derived_chest.glb.
- Committed editor backups (`*.png~`), orphaned `.gd.uid` sidecars,
  and art/audio orphaned by the 2D layer removal.

## PR #13 — The generated armory *(merged)*

### Added
- **Armor design language** (owner doctrine, spec:
  2026-07-10-armor-design-language.md): the pipeline works, the
  design doesn't — armor needs CONSTRUCTION (panels, thickness,
  straps, layers, broken silhouettes), each material has a
  shape-language not a color, and Delvers armor is explorer-built:
  repaired, mismatched, asymmetric. Derive v2 will build
  construction pieces from the body instead of inflated shells.
- **Leather trousers prove the engine**: `{"garment": "pants"}` —
  same grammar, different garment: thigh and calf panels, waistband,
  knee pads with straps, a thigh pouch; the `Legs` body part hides
  beneath. The delvers are fully dressed, head to toe, in compiled
  clothing.
- **THE GARMENT CONSTRUCTION ENGINE** (v5): garments are compiled
  from a spec ({volume, collar, shoulder_layers, buckles, sleeves,
  belt, hem_flaps}) into ASSEMBLED construction — face-partitioned
  panels (front-left/front-right/back/yoke/sleeves, each with its
  own thickness and bevel, sharing one drape so seams align),
  layered shoulder flanges, a clasp ladder in rhythm, waist
  compression with flare, asymmetric sleeves, and per-part culling.
  Items can store the spec instead of the mesh: procedural loot
  where every garment is genuinely unique. Iterations en route:
  inflated shell → constructed vest → skinned jacket → sealed →
  draped → assembled.
- **Body-derived armor works end to end**: the first chest piece is
  Garrick's own torso — spine-weighted faces duplicated in Blender,
  inflated off the skin, solidified, exported, rest-aligned onto his
  skeleton, and dyed leather by the recolor shader. Perfect fit by
  construction; every future body revision regenerates its wardrobe
  by re-running scripts. (Three bugs on the way: Blender's exporter
  silently drops the importer's glTF_not_exported collection, a stray
  icosphere artifact lives inside the Tripo body, and skin-textured
  shells need luma-flattened dyeing.)
- **Split-part hiding**: both delver GLBs carry separate
  Body/Hair/Feet/Hands meshes (Blender surgery); helms hide hair,
  boots hide feet, gauntlets hide hands.
- **The batch**: eight more generated pieces in one session — shield
  (wood and iron boss, replacing the procedural disc everywhere,
  including the campfire lean), arming sword (replacing the
  procedural blade), boots, greaves, bracers, gauntlets, a leather
  jerkin (the leather chest silhouette), and a cloth robe (the cloth
  silhouette) — all fitted, all recolorable. The guild portrait
  (docs/screenshots/guild_portrait.png): Warden in plate, Vanguard
  in chitin, Scout in oiled leather, Mystic in pale silk.
- **Claude generates gear now**: the Tripo API pipeline is wired end
  to end (SDK in a local venv, Blender addon + MCP bridge installed
  for interactive work). First generated asset: **iron pauldrons** —
  prompt → GLB → paired shoulder mounts (mirrored) → fitted, in
  minutes. The Warden's Pauldrons wear them.

## PR #12 — Guild Engineering & the Sunken Workshop *(open)*

### Added
- **The leather belt** (`leather_belt.glb`): the studded belt wears a
  sculpted model on the waist bone. Design rule recorded: belts are
  leather, whatever the rest of the set — a belt of plate is a
  strange object.
- **Armor types** (owner design: armor shapes HOW you fight, never
  what you may wear): every armor piece is Plate, Leather, or Cloth.
  Per piece worn — Plate: +6% threat, +8% stagger resistance (stuns
  and gum shrug off sooner), −1.5% dodge, −3% speed. Leather: +1%
  crit, +2% swing speed, +1.5% move. Cloth: +2 mana, 5% faster casts,
  +1 spell power. A paladin in plate is a different caster, not a
  worse one; plate on a healer is a build, not an error. Armor
  Proficiency mastery (Plate Training I/II, Plate Master) and the
  tier visual language (common→legendary silhouettes) are recorded
  design, coming later.
- **Gear recolor shader** (one sculpt, many armors): a palette-swap
  shader classifies each texel of a gear model against its three
  source materials (by chroma, ignoring baked shading) and remaps to
  a primary/secondary/trim palette per gear id — Chitin Armor now
  wears the chest sculpt in dark chitin with pale silk trim. Leather
  and cloth silhouettes still need their own sculpts.
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
