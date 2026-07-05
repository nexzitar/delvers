# Delvers Design Refactor — From Gear Loot to Knowledge & Materials

Date: 2026-07-05 (owner design document)

## Goal

Refactor Delvers away from ARPG-style equipment drops into a
**crafting-driven progression game**: players hunt monsters for
**materials** and **recipes**, then intentionally craft the equipment
they want.

> Monsters drop resources and knowledge, not equipment.
> Equipment primarily comes from crafting.

## The two currencies

- **Materials are consumed** (wood, iron, silk, poison glands, crystals).
- **Knowledge is permanent** (recipes, affixes, forging techniques,
  alchemy formulas).

The camp — the heart of the game — becomes more *knowledgeable* over
time. Delvers is about running and growing an adventurers' guild, not
chasing item levels.

## Design goals

- Reduce inventory clutter; eliminate vendor trash (everything retains value).
- Give every dungeon a permanent purpose (unique material identity).
- Players work toward specific builds instead of hoping for RNG.
- Recipes are exciting permanent unlocks, stored in the save.
- Crafting ties directly into camp progression.

## Loot philosophy

**Normal enemies** drop materials, monster-specific resources, and
crafting components. Finished equipment becomes very rare.
Each enemy has its own material identity, e.g.:

| Enemy | Drops |
|-------|-------|
| Goblin Archer | Ash Wood, Bow String, Poison Sac |
| Goblin Warrior | Iron, Leather |
| Goblin Shaman | Arcane Dust, Totem Fragment |
| Slime | Gel, Acidic Ooze, Corrosion Core |

**Recipes** are the exciting reward — permanent once learned.
Categories: weapons (Iron Sword, Hunter Bow, Reinforced Shield),
affixes (Virulent, Flaming, Frostforged, Guarding, Quick), armor
(Leather Hood, Iron Helm, Mage Robes).

**Crafting** is the primary source of equipment: gather materials +
essences + recipes, then craft intentionally. Affix recipes apply to
any compatible base ("Virulent Hunter Bow" = Hunter Bow recipe +
Virulent recipe + Poison Essence + materials).

**Finished equipment** comes only from dungeon bosses, special
encounters, rare treasure rooms, or extremely low-probability drops —
finding one should feel memorable. Unwanted finds are **salvaged**
into materials/essences/components.

## Dungeon identity & difficulty

Every dungeon has a unique material identity (Goblin Woods: poison/
leather/wood; Spider Nest: silk/venom/chitin; Frozen Caverns: frost
crystals/ice essence; Ancient Crypt: iron/bone/holy). Older dungeons
never become obsolete.

Rising difficulty tiers per dungeon increase material quantity, recipe
drop chance, unlock higher-rarity materials, and improve crafting
efficiency.

## Camp integration & meta progression

Materials also fund camp development — players choose between crafting
equipment, unlocking camp buildings, new Delvers, additional skill
slots, and new crafting stations.

Meta progression unlocks **options, not raw power**: new classes,
skill slots, recipes, buildings, dungeon types. Never permanent stat
bonuses or infinite scaling.

## The loop

Camp → prepare party → choose dungeon → fight through rooms → gather
materials → occasionally discover recipes → return to camp → craft →
expand the camp → unlock new possibilities → repeat.

## Design principle

The player should think **"I need Poison Essence"**, not "I hope a
poison sword drops". **"I finally found the Virulent recipe!"** should
beat "another random rare sword".

---

## Implementation status

- **2026-07-05 (slice 1)**: materials + per-enemy material tables,
  recipes as rare permanent drops (saved as knowledge), Forge tab in
  the loadout for crafting, finished gear reduced to boss drops +
  2% from normals, rooms auto-advance (no Delve Deeper click).
- **2026-07-05 (slice 2)**: affix recipes — Virulent (poison DoT on
  hit), Frostforged (chill on hit), Flaming (+damage), Quick (faster
  swings), Guarding (+health) — learnable from themed enemy pools
  (the Slime King teaches Flaming), applied at craft time via a Forge
  affix picker with combined material costs ("Virulent Iron Sword").
  The sim gained POISON damage-over-time with attribution, on-hit
  weapon riders, and refresh-not-stack statuses. Save schema v4.
- **2026-07-05 (slice 3)**: the menagerie grows so every material has
  one clear owner — Goblin Warrior (iron scrap ×2, leather; teaches
  Guarding + the new Leather Hood recipe), Venomous Spider (poison
  sac ×2, bow string; from room 3; its Venom Bite applies the real
  poison DoT; teaches Virulent), slimes own gel/ooze/cores, archers
  own wood/strings. New spider rig (fanned two-segment legs, rear-up
  bite attack) and helmeted warrior goblin.
- **2026-07-05 (slice 4)**: knowledge provenance — recipes and affixes
  drop as named tomes ("Spider Venom Treatise — Teaches: Virulent",
  "Ancient Goblin Forging Manual"); Forge quality-of-life — hover a
  recipe to preview the exact crafted item with equipped comparison,
  cost lines name the enemy that owns each material; secondary stats —
  armor (flat reduction), block (shields, halves), dodge (avoids),
  crit (150%), spell power (heals) on gear and enemies, with
  Dodge!/blocked/crit! floating feedback; Heal reworked to a mana cast
  (4 mana, 1.4s wind-up, no cooldown, fizzles refund) with slow mana
  regen (0.4/s).
- **Deferred**: salvaging, camp buildings & material spending beyond
  crafting, essences as a distinct material class, multiple dungeons
  with material identity, difficulty tiers, crafting stations, gear
  with spell power (stat is wired, no sources yet).
