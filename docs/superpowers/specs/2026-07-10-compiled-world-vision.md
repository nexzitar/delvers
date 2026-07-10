# The Compiled World — the long-term vision of Delvers

*Owner doctrine, 2026-07-10. This supersedes feature-thinking: every
future system answers to this document.*

## The thesis

**The world should be compiled, not assembled.**

The Garment Construction Engine was never about jackets. It was the
first proof that we can stop generating assets and instead generate
systems: describe the grammar of garments, and the engine compiles
infinitely many coherent garments from those rules. That philosophy
becomes the foundation of the entire game. Future content is never
hand-built dungeons with hand-made enemies and manual loot tables —
every piece of content derives from a small set of coherent rules,
starting from a seed as small as *"Create a dungeon inhabited by an
ancient Black Dragon brood."*

## The generation hierarchy

```
Theme → Lore → Ecology → Architecture → Encounter Grammar
      → Equipment Grammar → Visual Language → Audio Language
      → Dungeon Layout → Gameplay
```

Gameplay is almost the final consequence. **Nothing exists because
"the generator rolled it." Everything exists because something above
it logically required it.** Constraint inheritance is what makes
generated content feel authored; independent rolls are what make it
feel procedural.

### The owner's worked example (The Ashen Brood)

Theme: The Ashen Brood → Lore: an ancient Black Dragon brood
protecting forbidden knowledge → Ecology: Black Dragons, Brood
Guardians, Acid Elementals, Ancient Archivists → Architecture:
collapsed libraries, stone bridges, hatcheries, acid pools → Combat
rules: acid breath, acid permanently damages armor, young dragons
flee toward nests, fleeing enemies pull packs, some groups chain
intentionally → Equipment family: Dragon Scale, Obsidian Steel, Ash
Leather, Brood Bone → Construction grammar: large overlapping
scales, broad shoulders, heavy collars, dark hardware, layered
construction → Music: low choir, industrial percussion, deep drones
→ Layout: long connected spaces, no teleporting, continuous
believable movement.

## The generalization

| Instead of generating... | ...generate |
|---|---|
| rooms | architectural grammar |
| monsters | ecological grammar |
| loot | equipment construction grammar |
| quests | cultural and historical grammar |

**The asset is always the consequence of the grammar.**

## The standing question

Whenever a new system is added, ask **"What grammar are we actually
discovering?"** — never "what asset are we creating?" The goal state:
the owner says *"Generate the next dungeon"* and the result feels
handcrafted because every system derives from the same concept.

## Engineering corollaries (agreed 2026-07-10)

1. **Grammars are discovered in the second instance, not designed in
   the first.** The engine's best rules (base shell, layer ladder,
   fabric-forgets-anatomy) came from failures against a reference.
   Pattern: handcraft the second thing, extract the grammar, compile
   the third. Darkwood + Spider Nest + Sunken Workshop = three
   hand-authored dungeons; the dungeon grammar is now extractable.

2. **Quality is multiplicative down the chain; the taste gate is
   architecture.** Each layer compiles to a cheaply-judgeable
   artifact (a lore page, an enemy roster, a lineup render) and the
   owner's verdict gates the layers below. The render-critique-re-rule
   loop is a permanent component, not scaffolding.

3. **The mechanical layer composes a bounded atom vocabulary.** The
   sim's atoms (DoTs, statuses, threat, roots, flee-toward-ally,
   spawning, stat modification...) are the legal vocabulary the
   ecology layer may demand. Grammars compose atoms; inventing new
   atoms stays human work. A catalogue of existing atoms is a
   prerequisite for the encounter grammar.

4. **The two-tier practicality rule generalizes.** Heavy grammar
   compilation happens offline (Blender, authoring passes, taste
   gates); the game assembles compiled artifacts instantly at
   runtime. This is how "10,000 items quickly" scales to "the next
   dungeon overnight."

5. **Delvers is already halfway there, unnamed.** Threat/lesson/answer
   per dungeon = encounter grammar seed. Per-enemy material and
   recipe identity = ecology→economy inheritance. Tome provenance =
   lore grammar. Doctrines as recovered knowledge = cultural grammar.
   Recolor trim channel = tier visual language. The migration is
   naming and connecting these layers, not rewriting them.

## Likely first concrete step (when the owner calls for it)

A `ThemeDefinition` — the compiled dungeon spec — with the three
existing dungeons retrofitted as instances. The spec is the dungeon,
exactly as the spec is the item. That proves the top of the hierarchy
the way the jacket proved the bottom.
